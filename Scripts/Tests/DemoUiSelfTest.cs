using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class DemoUiSelfTest : Node
{
    private int _checks;
    private StartScreen _screen = null!;
    private string _prefix = "";
    private bool _capture;
    private void Check(bool value, string message)
    { if (!value) throw new InvalidOperationException(message); _checks++; GD.Print("PASS " + message); }
    private async Task Frames(int count = 4)
    { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Click(string name)
    {
        for (int i = 0; i < 180 && JourneyTransition.For(this).Active; i++) await Frames(1);
        var button = _screen.Descendants<Button>().First(b => b.Name == name && b.IsVisibleInTree());
        Vector2 p = button.GetGlobalTransformWithCanvas() * (button.Size / 2);
        GetViewport().PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
        GetViewport().PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = true }, true);
        GetViewport().PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = false }, true);
        await Frames();
        for (int i = 0; i < 180 && JourneyTransition.For(this).Active; i++) await Frames(1);
    }
    private void CheckLanguage(string locale)
    {
        bool english = locale == "en";
        Check(_screen.Tr("新的旅程").ToString() == (english ? "New journey" : "新的旅程"),
            $"{locale} resolves visible UI text in the selected language");
        Check(_screen.Tr("天津试玩 · 已开放 2 / 3 局").ToString() == (english ? "Tianjin demo · 2 / 3 shifts open" : "天津试玩 · 已开放 2 / 3 局"),
            $"{locale} resolves dynamic text in the selected language");
    }
    private async Task Capture(string name, Node root)
    {
        await Frames(12);
        for (int i = 0; i < 180 && JourneyTransition.For(this).Active; i++) await Frames(1);
        Check(!JourneyTransition.For(this).Active, "capture waits for page transition " + name);
        var rows = root.Descendants<Control>().Where(c => c.IsVisibleInTree()).Select(c =>
        {
            string raw = c switch { Label l => l.Text, Button b => b.Text, _ => "" };
            return new { path = c.GetPath().ToString(), raw, translated = c.Tr(raw).ToString(), bounds = c.GetGlobalRect().ToString() };
        }).Where(r => r.raw.Length > 0).ToArray();
        File.WriteAllText(_prefix + "-" + name + ".json", System.Text.Json.JsonSerializer.Serialize(rows, new System.Text.Json.JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }));
        if (!_capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage(); image.SavePng(_prefix + "-" + name + ".png");
    }
    public override async void _Ready()
    {
        try
        {
            var args = OS.GetCmdlineUserArgs(); _capture = args.Contains("--capture");
            bool english = args.Contains("--english"), small = args.Contains("--small");
            GetWindow().Size = small ? new(1280, 720) : new(1920, 1080);
            string dir = ProjectSettings.GlobalizePath("res://.tmp/demo-ui-tests/" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(dir);
            _prefix = ProjectSettings.GlobalizePath($"res://.tmp/demo-implementation/ui-{(english ? "en" : "zh")}-{(small ? "720" : "1080")}");
            if (!OS.HasFeature("editor")) _prefix = ProjectSettings.GlobalizePath($"user://demo-qa-artifacts/ui-{(english ? "en" : "zh")}-{(small ? "720" : "1080")}");
            Directory.CreateDirectory(Path.GetDirectoryName(_prefix)!);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog"); var save = GetNode<SaveService>("/root/SaveService");
            save.UseDemoPathForTests(Path.Combine(dir, "save.json"));
            Check(save.ResetProgress(out _), "isolated UI progress created");
            var settings = GetNode<JourneySettings>("/root/JourneySettings"); settings.UsePathForTests(Path.Combine(dir, "settings.cfg")); settings.SetLanguage(english ? "en" : "zh_CN");
            InterfaceLessons.MarkAllSeen(settings);
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); AddChild(main);
            _screen = main.GetNode<StartScreen>("UI/StartScreen"); await Frames();
            if (args.Contains("--settings-only"))
            {
                await SettingsPageChecks.Run(_screen, save, settings, name => Capture(name, _screen));
                GD.Print("SETTINGS_DEMO_SELF_TEST_OK"); GetTree().Quit(); return;
            }
            if (args.Contains("--help-only"))
            {
                await HelpPageChecks.Run(_screen, save, settings, name => Capture(name, _screen));
                GD.Print("HELP_DEMO_SELF_TEST_OK"); GetTree().Quit(); return;
            }
            CheckLanguage(settings.Language);
            _screen.PresentHome(); await Capture("home", _screen);
            await Click("Settings"); Check(_screen.ModalOpen, "viewport click opens settings"); await Capture("settings", _screen);
            await SettingsPageChecks.SelectLanguage(_screen, english ? 0 : 1); Check(settings.Language == (english ? "zh_CN" : "en"), "viewport language choice changes locale");
            CheckLanguage(settings.Language); await Capture("language-switched", _screen);
            settings.LoadPreferences(); await Frames(); CheckLanguage(settings.Language);
            await SettingsPageChecks.SelectLanguage(_screen, english ? 1 : 0); CheckLanguage(settings.Language); await Click("Close");
            Check(main.OpenCity(StableIds.Cities.Tianjin), "Tianjin hub opens"); await Capture("hub", _screen);
            CheckContinueOverview(catalog, save, Path.Combine(dir, "save.json"));
            await Click("LedgerTab");
            Check(_screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("Date")) == save.ChapterLength(StableIds.Cities.Tianjin), "calendar exposes configured shifts");
            await Click("Date3"); Check(_screen.Descendants<Button>().Single(b => b.Name == "StartSelectedDay").Disabled, "locked shift cannot start via viewport");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Right, Pressed = true }, true);
            await Frames();
            Check(GetViewport().GuiGetFocusOwner()?.Name == "Date" + Math.Min(4, save.ChapterLength(StableIds.Cities.Tianjin)), "Demo keyboard navigation follows configured dates");
            for (int day = 1; day <= 4; day++)
            {
                catalog.TryGetDay(day, out var config);
                save.ApplyStartUnlocks(config, out _);
                save.CommitDay(new() { Day = day, SaleRevenue = new[] { 28, 46, 65, 20 }[day - 1], CompletedCustomers = config.CustomerCount },
                    new ProjectCake.Orders.OrderGenerator().Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById), config);
            }
            _screen.PresentLedger(); await Capture("ledger", _screen);
            await Click("UpgradeTab"); await Capture("upgrades", _screen);
            Check(_screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("Select_")) == (save.ChapterLength(StableIds.Cities.Tianjin) > 3 ? 3 : 2), "only configured Demo upgrades appear");
            await Click("UpgradeEquipment");
            Check(save.Data.PurchasedStoveLevel == 2 && save.Data.Coins == 79, "viewport purchase applies new 80-coin upgrade cost");
            await Capture("purchased", _screen);
            await Click("LedgerTab"); await Click("Date3"); await Click("StartSelectedDay");
            var controller = main.GetNode<DayController>("DayController"); var dayScreen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            Check(dayScreen.IsVisibleInTree() && controller.CurrentConfig!.Day == 3 && !controller.TutorialActive, "upgraded replay enters the same third stage");
            controller.Tick(DayController.OpeningDurationSeconds); await Capture("replay", dayScreen);
            var station = dayScreen.GetNode<PancakeWorkstation>("PancakeWorkstation");
            Check(!station.Machine.Stove.CanBurn && !station.Tutorial.ProtectPancakeHeat, "purchased griddle protects normal replay without lesson protection");
            controller.Tick(1000); controller.Tick(1000); dayScreen.BusinessDetails.FinishAnimation(); await Capture("settlement", dayScreen);
            Check(dayScreen.BusinessDetails.Model.Result.LostCustomers == controller.CurrentConfig!.CustomerCount, "closing does not count already timed-out customers twice");
            save.Load(); Check(save.Data.PurchasedStoveLevel == 2 && save.ContinueDay == 5, "save reload preserves purchase and replay destination");
            GD.Print($"DEMO_UI_SELF_TEST_OK {_checks}"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private void CheckContinueOverview(DataCatalog catalog, SaveService save, string savePath)
    {
        var model = new CityPageModel(catalog, save, null);
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            int total = save.ChapterLength(city);
            var progress = save.Data.GetCity(city); int highest = progress.HighestUnlockedDay;
            progress.HighestUnlockedDay = total;
            var latest = model.Overview(city, total);
            var replay = model.Overview(city, 1);
            Check(latest.TotalDays == total && replay.Day == total, "shared overview uses highest unlocked day " + city);
            Check(latest.LatestUnlocks.Select(u => u.Id).SequenceEqual(replay.LatestUnlocks.Select(u => u.Id)), "replay does not roll back latest unlock " + city);
            progress.HighestUnlockedDay = highest;
        }
        string before = File.ReadAllText(savePath);
        _screen.RefreshCityPage();
        Check(File.ReadAllText(savePath) == before, "demo overview refresh does not write progress");
    }
}
