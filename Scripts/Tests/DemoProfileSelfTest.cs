using System.Text.Json;
using System.Text.Json.Nodes;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;
using ProjectCake.Gameplay;
namespace ProjectCake.Tests;

public partial class DemoProfileSelfTest : Node
{
    private int _checks;
    private void Check(bool ok, string message)
    { if (!ok) throw new Exception(message); _checks++; GD.Print("PASS " + message); }
    public override void _Ready()
    {
        try
        {
            Check(ExperienceProfile.IsDemo, "Demo feature selected");
            string dir = ProjectSettings.GlobalizePath("user://demo-qa-artifacts/profile-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(dir);
            string path = Path.Combine(dir, "demo.json");
            var save = GetNode<SaveService>("/root/SaveService");
            save.UseDemoPathForTests(path);
            Check(save.ResetProgress(out _), "new isolated shared-format save");
            Check(save.ChapterLength(StableIds.Cities.Tianjin) == 15 && save.ChapterLength(StableIds.Cities.Wuhan) == 12, "27 configured chapter days, followed by endless business");
            save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
            save.Data.LastVisitedCityId = StableIds.Cities.Wuhan;
            save.Data.Coins = 987; save.Data.Tianjin.HighestUnlockedDay = 15;
            save.Data.Tianjin.Completed = true; save.Data.Tianjin.BestStars = 3;
            save.Data.Tianjin.EquipmentLevels["pancake_stove"] = 3;
            save.Data.Tianjin.UnlockedContentIds.Add("equipment:pancake_stove_lv3");
            save.Data.Tianjin.LearnedWorkbenchActions.Add("flip");
            save.Data.Wuhan.HighestUnlockedDay = 13; save.Data.Wuhan.BestStars = 2; save.Data.Wuhan.Completed = true;
            save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
            save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
            save.Data.Wuhan.DayBestRecords[12] = new() { TotalRevenue = 400, CompletedCustomers = 24, Satisfaction = 95 };
            save.Data.BreakfastRecords["doupi"] = 4;
            save.Data.BreakfastStats["doupi"] = new() { Delivered = 25, Perfect = 15 };
            string snapshot = JsonSerializer.Serialize(save.Data);
            Check(save.TrySave(out _), "Lv3 and full city fields save");
            save.Load();
            Check(!save.HasLoadError && JsonSerializer.Serialize(save.Data) == snapshot, "all shared city data round trips without loss");
            Check(save.ContinueCityId == StableIds.Cities.Wuhan && save.ContinueDay == 13, "continue uses extended city progress");
            Check(!save.Data.UnlockedCityIds.Contains(StableIds.Cities.Xian), "completed Wuhan never unlocks Demo Xian");
            string formal = Path.Combine(dir, "formal.json");
            File.WriteAllText(formal, snapshot); string formalBefore = File.ReadAllText(formal);

            foreach (int schema in new[] { 1, 2 })
            {
                var old = new DemoSaveFile { SchemaVersion = schema, ContentRevision = schema == 1 ? 1 : 3, Coins = 123, LastStartedStageId = "demo_tj_02" };
                old.CompletedStages.Add("demo_tj_01");
                old.BestRecords["demo_tj_01"] = new() { TotalRevenue = 28, CompletedCustomers = 4 };
                old.LearnedActions.Add("flip"); old.BreakfastRecords["pancake"] = "demo_tj_01";
                string original = JsonSerializer.Serialize(old, DemoCatalog.JsonOptions);
                File.WriteAllText(path, original);
                string existingBackup = path + ".before-shared-cities.bak";
                if (schema == 2) File.WriteAllText(existingBackup, "existing backup must survive");
                save.Load();
                Check(!save.HasLoadError && save.MigratedLegacySave, "recognized old schema reset " + schema);
                Check(save.Data.Coins == 0 && save.Data.Tianjin.HighestUnlockedDay == 1 && save.Data.BreakfastRecords.Count == 0
                    && save.Data.Tianjin.DayBestRecords.Count == 0 && save.Data.Tianjin.LearnedWorkbenchActions.Count == 0, "old rewards and progress do not leak");
                Check(Directory.GetFiles(dir, "*.bak").Any(p => File.ReadAllText(p) == original), "exact original bytes backed up");
                if (schema == 2) Check(File.ReadAllText(existingBackup) == "existing backup must survive", "existing backup never overwritten");
                int backups = Directory.GetFiles(dir, "*.bak").Length;
                save.Load();
                Check(!save.MigratedLegacySave && Directory.GetFiles(dir, "*.bak").Length == backups, "new format does not reset again");
            }

            string oldJson = JsonSerializer.Serialize(new DemoSaveFile { ContentRevision = 3 }, DemoCatalog.JsonOptions);
            File.WriteAllText(path, oldJson);
            Directory.CreateDirectory(path + ".migration.tmp");
            save.Load();
            Check(save.HasLoadError && File.ReadAllText(path) == oldJson, "failed migration write preserves original");
            Directory.Delete(path + ".migration.tmp");
            save.Load(); Check(!save.HasLoadError && save.MigratedLegacySave, "migration write failure can retry");
            string blocked = Path.Combine(dir, "backup-blocked.json");
            File.WriteAllText(blocked, oldJson); Directory.CreateDirectory(blocked + ".before-shared-cities.bak");
            save.UseDemoPathForTests(blocked);
            Check(save.HasLoadError && File.ReadAllText(blocked) == oldJson, "backup failure never resets original");
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); AddChild(main);
            var screen = main.GetNode<StartScreen>("UI/StartScreen"); screen.PresentHome();
            var retry = screen.Descendants<Button>().Single(b => b.Name == "RetryDemoMigration");
            Check(retry.IsVisibleInTree(), "backup failure exposes a retry on the home screen");
            Directory.Delete(blocked + ".before-shared-cities.bak");
            retry.EmitSignal(Button.SignalName.Pressed);
            Check(!save.HasLoadError && !screen.Descendants<Label>().Any(l => l.Name == "DemoScope"), "home retry restores new route without migration notice");
            main.QueueFree();
            save.UseDemoPathForTests(path);
            foreach (string invalid in new[] { "{broken", oldJson.Replace("\"schemaVersion\": 2", "\"schemaVersion\": 99"),
                oldJson.Replace("\"lastStartedStageId\": \"demo_tj_01\"", "\"lastStartedStageId\": \"unknown\"") })
            {
                File.WriteAllText(path, invalid); save.Load();
                Check(save.HasLoadError && File.ReadAllText(path) == invalid, "unknown/corrupt data never silently resets");
            }
            Check(File.ReadAllText(formal) == formalBefore, "formal file untouched");
            Check(ExperienceProfile.ProgressPath(true) != ExperienceProfile.ProgressPath(false), "profile paths are isolated");
            GD.Print($"DEMO_PROFILE_SELF_TEST_OK {_checks} artifacts={dir}"); GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
}
