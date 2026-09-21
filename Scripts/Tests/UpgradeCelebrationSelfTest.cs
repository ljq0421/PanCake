using Godot;
using System.Text.Json.Nodes;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class UpgradeCelebrationSelfTest : Node
{
    private int _checks;
    private string _dir = "";
    private bool _capture;
    private void Check(bool ok, string message) { if (!ok) throw new InvalidOperationException(message); _checks++; }
    private async Task Frames(int count = 3)
    { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    public override async void _Ready()
    {
        try
        {
            var args = OS.GetCmdlineUserArgs();
            _dir = args.First(a => a.StartsWith("--output=")).Substring(9);
            Directory.CreateDirectory(_dir); _capture = args.Contains("--capture");
            GetWindow().Size = args.Contains("--small") ? new(1280, 720) : new(1920, 1080);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog"); Check(catalog.IsValid, "catalog");
            foreach (bool demo in new[] { false, true }) CheckPersistence(catalog, demo);
            foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
                await CheckScreen(catalog, city);
            // Let the audio server retire stopped voices before the test process exits.
            await ToSignal(GetTree().CreateTimer(.2), SceneTreeTimer.SignalName.Timeout);
            using var sound = EquipmentUpgradeCelebration.MakeChime();
            Check(sound.Data.Length > 20000 && sound.Data.Any(b => b != 0), "nonempty upgrade cue");
            sound.SaveToWav(Path.Combine(_dir, "upgrade-chime.wav"));
            GD.Print($"UPGRADE_CELEBRATION_OK checks={_checks} demoProfile={ExperienceProfile.IsDemo}"); GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
    private SaveService Fixture(bool demo, string name)
    {
        var save = new SaveService(); string path = Path.Combine(_dir, name + ".json");
        if (demo) save.UseDemoPathForTests(path); else save.UsePathForTests(path);
        Check(save.ResetProgress(out _), "reset fixture");
        save.Data.Coins = 10000;
        save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            var progress = save.Data.GetCity(city); progress.HighestUnlockedDay = 20;
            foreach (string id in Equipment(city))
            {
                progress.EquipmentLevels[id] = 1;
                progress.UnlockedContentIds.Add($"equipment:{id}_lv2");
                progress.UnlockedContentIds.Add($"equipment:{id}_lv3");
            }
        }
        Check(save.TrySave(out _), "seed fixture"); return save;
    }
    private static string[] Equipment(string city) => city == StableIds.Cities.Tianjin
        ? new[] { "pancake_stove", "ingredient_station", "fryer" } : new[] { "noodle_cooker", "doupi_griddle" };
    private void CheckPersistence(DataCatalog catalog, bool demo)
    {
        string name = "persistence-" + demo;
        var save = Fixture(demo, name);
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            var ids = Equipment(city);
            foreach (string id in ids)
            {
                Check(save.TryPurchase(city, $"equipment:{id}_lv2", catalog, out _), "buy level 2");
                Check(save.TryPurchase(city, $"equipment:{id}_lv3", catalog, out _), "buy level 3");
            }
            save.Load();
            Check(save.Data.GetCity(city).PendingUpgradeCelebrations.Count == ids.Length
                && save.Data.GetCity(city).PendingUpgradeCelebrations.Values.All(v => v == 3), "purchase survives reload, coalesces levels");
            int coins = save.Data.Coins;
            Check(!save.TryPurchase(city, $"equipment:{ids[0]}_lv3", catalog, out _) && coins == save.Data.Coins, "failed purchase changes nothing");
            string temporary = Path.Combine(_dir, name + ".json.tmp"); Directory.CreateDirectory(temporary);
            Check(!save.TryConsumeUpgradeCelebrations(city, ids, out var failed, out _) && failed.Count == 0
                && save.Data.GetCity(city).PendingUpgradeCelebrations.Count == ids.Length, "save failure rolls back consumption");
            Directory.Delete(temporary);
            Check(save.TryConsumeUpgradeCelebrations(city, Array.Empty<string>(), out var hidden, out _) && hidden.Count == 0
                && save.Data.GetCity(city).PendingUpgradeCelebrations.Count == ids.Length, "hidden equipment waits for a visible opening");
            Check(save.TryConsumeUpgradeCelebrations(city, ids, out var pending, out _) && pending.Count == ids.Length, "consume first opening");
            save.Load();
            Check(save.TryConsumeUpgradeCelebrations(city, ids, out pending, out _) && pending.Count == 0, "no replay after restart");
        }
        string path = Path.Combine(_dir, name + ".json");
        var json = JsonNode.Parse(File.ReadAllText(path))!;
        foreach (var city in json["Cities"]!.AsObject()) city.Value!.AsObject().Remove("PendingUpgradeCelebrations");
        File.WriteAllText(path, json.ToJsonString()); save.Load();
        Check(!save.HasLoadError && save.Data.Tianjin.PendingUpgradeCelebrations.Count == 0, "old saves do not invent pending upgrades");
        Check(save.TryConsumeUpgradeCelebrations(StableIds.Cities.Xian, new[] { "xian_board" }, out var other, out _) && other.Count == 0, "other cities excluded");
        save.Free();
    }
    private async Task CheckScreen(DataCatalog catalog, string city)
    {
        var save = Fixture(ExperienceProfile.IsDemo, "screen-" + city.Replace(':', '-'));
        foreach (string id in Equipment(city)) Check(save.TryPurchase(city, $"equipment:{id}_lv2", catalog, out _), "screen purchase");
        var controller = new DayController(); AddChild(controller);
        Control screen;
        Action begin;
        if (city == StableIds.Cities.Tianjin)
        {
            var day = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(day);
            day.ConnectController(controller); Check(day.Initialize(catalog, save, controller, 8), "Tianjin initialize");
            screen = day; begin = day.BeginDay;
        }
        else
        {
            var day = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(day);
            day.ConnectController(controller); Check(day.Initialize(catalog, save, controller, 8), "Wuhan initialize");
            screen = day; begin = day.BeginDay;
        }
        screen.SetProcess(false);
        var effect = screen.GetNode<EquipmentUpgradeCelebration>("UpgradeCelebration"); effect.SetProcess(false);
        Check(save.Data.GetCity(city).PendingUpgradeCelebrations.Count == Equipment(city).Length, "prepare does not consume");
        begin(); Check(!effect.IsPlaying, "countdown does not play");
        controller.Tick(DayController.OpeningDurationSeconds);
        Check(effect.IsPlaying && save.Data.GetCity(city).PendingUpgradeCelebrations.Count == 0, "opening queues all equipment once");
        int i = 0;
        while (effect.IsPlaying)
        {
            effect._Process(.3);
            Check(effect.Visible && effect.CurrentCaption.Contains("Lv.2"), "visible level caption");
            if (_capture)
            {
                await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                Check(GetViewport().GetTexture().GetImage().SavePng(Path.Combine(_dir, $"{city.Replace(':', '-')}-{i}.png")) == Error.Ok, "capture");
            }
            effect._Process(1.1); i++;
        }
        Check(effect.PlayedCount == Equipment(city).Length, "one chime per equipment");
        Check(effect.Begin(save, controller, out _) && !effect.IsPlaying, "same day does not repeat");
        string first = Equipment(city)[0];
        Check(save.TryPurchase(city, $"equipment:{first}_lv3", catalog, out _), "later upgrade creates a fresh cue");
        Check(controller.TryPrepareTutorial(city, 1, catalog, out _), "tutorial prepare");
        controller.TryStartDay(out _); controller.Tick(DayController.OpeningDurationSeconds);
        Check(!effect.IsPlaying && save.Data.GetCity(city).PendingUpgradeCelebrations.Count == 1, "independent tutorial preserves pending cue");
        controller.TryPrepareDay(city, 8, catalog, out _); controller.TryStartDay(out _); controller.Tick(DayController.OpeningDurationSeconds);
        effect._Process(.1); Check(effect.IsPlaying && effect.CurrentCaption.Contains("Lv.3"), "later opening displays new level");
        controller.SetPauseReason("test", true); effect._Process(.01);
        Check(!effect.IsPlaying && !effect.AudioPlaying, "pause stops animation and sound");
        controller.SetPauseReason("test", false); effect._Process(.1);
        Check(!effect.IsPlaying && !effect.AudioPlaying, "resume does not replay");
        save.Data.GetCity(city).PendingUpgradeCelebrations[first] = 3;
        effect.Begin(save, controller, out _); effect._Process(.1);
        effect._Notification((int)NotificationApplicationFocusOut);
        Check(!effect.IsPlaying && !effect.AudioPlaying, "focus loss stops the cue");
        save.Data.GetCity(city).PendingUpgradeCelebrations[first] = 3;
        effect.Begin(save, controller, out _); effect._Process(.1); screen.Hide();
        Check(!effect.IsPlaying && !effect.AudioPlaying, "leaving the screen stops the cue immediately");
        screen.QueueFree(); controller.QueueFree(); await Frames();
        save.Free();
    }
}
