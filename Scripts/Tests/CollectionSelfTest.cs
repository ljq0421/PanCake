using Godot;
using System.Text.Json.Nodes;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;
namespace ProjectCake.Tests;

public partial class CollectionSelfTest : Node
{
    private int _checks;
    private string _dir = "";
    private void Check(bool ok, string message) { if (!ok) throw new Exception(message); GD.Print("PASS " + message); _checks++; }
    private async Task Frames() { for (int i = 0; i < 8; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Capture(string name)
    {
        if (!OS.GetCmdlineUserArgs().Contains("--capture")) return;
        await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage(); image.SavePng(Path.Combine(_dir, name + ".png"));
    }
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--small");
            GetWindow().Size = small ? new(1280, 720) : new(1920, 1080);
            _dir = ProjectSettings.GlobalizePath("res://.tmp/collection-review/" + (small ? "1280" : "1920"));
            Directory.CreateDirectory(_dir);
            var save = GetNode<SaveService>("/root/SaveService");
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Path.Combine(_dir, "settings.cfg")); settings.SetLanguage("zh_CN");
            string path = Path.Combine(_dir, "save.json");
            save.UseDemoPathForTests(path, catalog.Demo!); Check(save.ResetProgress(out _), "isolated demo save");
            var stage = catalog.Demo!.Stages[0]; var plan = stage.Plan(catalog);
            var receipt = new DeliveryReceipt(plan.RunId, plan.StageId, new(ProductKind.Pancake, "pancake_basic", PancakeQuality.Perfect), true, true, false);
            foreach (var invalid in new[] { receipt with { Tutorial = true }, receipt with { Matched = false }, receipt with { Accepted = false }, receipt with { RunId = "stale" }, receipt with { StageId = "stale" } })
                DemoBreakfastCollection.Observe(invalid, plan);
            Check(plan.PendingBreakfastStats.Count == 0, "tutorial, wrong, rejected and stale deliveries excluded");
            for (int i = 0; i < 10; i++) DemoBreakfastCollection.Observe(receipt, plan);
            for (int i = 0; i < 10; i++) DemoBreakfastCollection.Observe(receipt with { Item = receipt.Item with { PancakeQuality = PancakeQuality.Overdone } }, plan);
            DemoBreakfastCollection.Observe(receipt with { Item = new(ProductKind.SoyMilk, "soy_milk") }, plan);
            Check(save.BreakfastStatsFor("pancake").Delivered == 0, "unsaved run has no durable counts");
            var result = new DayResult { Day = 1, CompletedCustomers = 1 };
            var config = stage.Config(catalog.RecipesById, catalog.ProductsById);
            Directory.CreateDirectory(path + ".tmp");
            bool failed = false; try { save.CommitDay(result, plan, config); } catch (IOException) { failed = true; }
            Check(failed && save.BreakfastStatsFor("pancake").Delivered == 0 && !save.BreakfastRecordDay("pancake").HasValue, "failed save rolls back counts and stamps");
            Directory.Delete(path + ".tmp");
            save.CommitDay(result, plan, config); save.CommitDay(result, plan, config); save.Load();
            var stats = save.BreakfastStatsFor("pancake");
            Check(stats.Delivered == 20 && stats.Perfect == 10 && stats.Skilled && stats.PerfectStamp, "threshold stamps persist and duplicate settlement is ignored");
            Check(save.BreakfastStatsFor("soy_milk").Delivered == 1 && save.BreakfastStatsFor("soy_milk").Perfect == 0, "soy milk does not accumulate Perfect counts");
            Check(!new BreakfastStatistics { Delivered = 19, Perfect = 9 }.Skilled && !new BreakfastStatistics { Delivered = 19, Perfect = 9 }.PerfectStamp, "below-threshold stamps remain locked");
            string earned = File.ReadAllText(path);
            var old = JsonNode.Parse(earned)!; old.AsObject().Remove("breakfastStats");
            File.WriteAllText(path, old.ToJsonString()); save.Load();
            Check(!save.HasLoadError && save.BreakfastRecordDay("pancake") == 1 && save.BreakfastStatsFor("pancake").Delivered == 0, "old saves keep first record without inventing historical counts");
            File.WriteAllText(path, earned); save.Load();
            var screen = GD.Load<PackedScene>("res://Scenes/UI/StartScreen.tscn").Instantiate<StartScreen>();
            AddChild(screen); screen.Initialize(save); screen.PresentBreakfastCollection(); await Frames();
            Check(screen.Descendants<TextureRect>().Single(t => t.Name == "CollectionBook").GetRect() == StartScreen.BookBounds
                && screen.Descendants<Control>().Single(c => c.Name == "CollectionContent").Scale == Vector2.One * (1400f / 1860f),
                "collection uses the shared 1400×800 book frame");
            Check(screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("Breakfast_")) == 3, "Wuhan remains gated before city unlock");
            await Capture("locked-cities");
            save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
            screen.PresentBreakfastCollection(); await Frames();
            Check(screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("Breakfast_")) == 5, "five demo foods and three locked future cities");
            await Capture("earned-stamps");
            screen.Descendants<Button>().Single(b => b.Name == "CollectionCity2").EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("Breakfast_")) == 2, "Wuhan filter");
            await Capture("wuhan-filter");
            screen.Descendants<Button>().Single(b => b.Name == "CollectionCity0").EmitSignal(Button.SignalName.Pressed); await Frames();
            screen.Descendants<Button>().Single(b => b.Name == "Breakfast_soy_milk").EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(!screen.Descendants<Control>().Any(c => c.Name == "PerfectStamp" || c.Name == "BreakfastPerfect"), "soy milk hides Perfect statistics and stamp");
            Check(File.ReadAllText(path) == earned, "collection browsing does not modify saved progress");
            await Capture("soy-milk");
            screen.Descendants<Button>().Single(b => b.Name == "CollectionHome").EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(screen.Page == JourneyPage.Home, "footer returns home");
            GD.Print($"COLLECTION PASS {_checks}; artifacts: {_dir}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
