using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Real rendered transitions, isolated save, input locking and clock ownership.</summary>
public partial class JourneyTransitionSelfTest : Node
{
    private GameController _main = null!;
    private StartScreen _home = null!;
    private JourneyTransition _motion = null!;
    private string _directory = "";
    private int _checks;
    public override async void _Ready()
    {
        try
        {
            _directory = ProjectSettings.GlobalizePath("res://.tmp/journey-transition");
            Directory.CreateDirectory(_directory);
            string fixture = Path.Combine(_directory, Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(fixture);
            var save = GetNode<SaveService>("/root/SaveService");
            save.UsePathForTests(Path.Combine(fixture, "save.json"));
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Path.Combine(fixture, "settings.cfg"));
            InterfaceLessons.MarkAllSeen(settings);
            Check(save.ResetProgress(out _), "isolated save ready");
            save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
            save.Data.GetCity(StableIds.Cities.Tianjin).HighestUnlockedDay = 4;
            save.Data.GetCity(StableIds.Cities.Wuhan).HighestUnlockedDay = 4;
            GetWindow().Size = new(1280, 720);
            _main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            AddChild(_main);
            _home = _main.GetNode<StartScreen>("UI/StartScreen");
            _motion = JourneyTransition.For(this);
            await Frames();
            _home.PresentHome(); await Complete();
            Check(!_motion.Active, "automatic completion releases transition");
            if (OS.GetCmdlineUserArgs().Contains("--shared-books-only"))
            {
                await SharedBookChecks(save);
                GD.Print($"SHARED_BOOKS_TEST_PASS checks={_checks}"); GetTree().Quit(); return;
            }
            if (OS.GetCmdlineUserArgs().Contains("--home-books-only"))
            {
                await HomeBookChecks(save);
                GD.Print($"HOME_BOOKS_TEST_PASS checks={_checks} demo={ExperienceProfile.IsDemo}"); GetTree().Quit(); return;
            }
            if (OS.GetCmdlineUserArgs().Contains("--settings-fold-preview"))
            {
                await SettingsFoldPreview();
                GD.Print($"SETTINGS_FOLD_PREVIEW_PASS checks={_checks}"); GetTree().Quit(); return;
            }
            if (OS.GetCmdlineUserArgs().Contains("--utility-backdrop-only"))
            {
                await UtilityBackdropChecks();
                GD.Print($"UTILITY_BACKDROP_TEST_PASS checks={_checks}"); GetTree().Quit(); return;
            }
            await Capture("home");
            string before = File.ReadAllText(Path.Combine(fixture, "save.json"));
            _home.PresentMap();
            await Sample("page-forward", .38f);
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            Check(_home.Page == JourneyPage.Map, "keyboard blocked during page turn");
            _motion.Finish(); await Frames();
            _home.PresentHome(); await Sample("page-back", .6f); _motion.Finish(); await Frames();
            FindButton("Settings").EmitSignal(BaseButton.SignalName.Pressed);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, "home settings unfolds from spine");
            await Sample("settings-opening-early", .2f);
            await Sample("settings-opening-late", .8f);
            await Sample("settings-opening", .5f); _motion.Finish(); await Frames();
            Check(_home.ModalOpen, "settings open");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            CheckEffect(JourneyTransition.Effect.SpreadClose, "home settings folds towards spine");
            await Sample("settings-closing", .5f); _motion.Finish();
            Check(!_home.ModalOpen, "settings close restores navigation");
            await Frames();
            FindButton("Help").EmitSignal(BaseButton.SignalName.Pressed);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, "help uses soft spread");
            await Sample("help-opening", .4f); _motion.Finish(); await Frames();
            FindButton("MusicCredits").EmitSignal(BaseButton.SignalName.Pressed);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, "music credits uses soft spread");
            await Complete(); Check(!_motion.Active, "paper turn finishes automatically");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            await Complete(); Check(!_home.ModalOpen && !_motion.Active, "help closes and releases overlay");
            Check(before == File.ReadAllText(Path.Combine(fixture, "save.json")), "navigation does not write gameplay save");
            foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
            {
                _home.PresentCity(city); await Complete();
                _home.PresentLedger(); await Sample(city + "-ledger", .4f); _motion.Finish();
                _home.PresentUpgrades(); await Sample(city + "-upgrades", .4f); _motion.Finish();
                _home.PresentCity(city); await Complete();
                Check(_main.StartCityBusiness(city, 4), city + " starts");
                var day = _main.GetNode<DayController>("DayController");
                await Sample(city + "-curtain-close", .30f);
                if (DisplayServer.GetName() != "headless")
                {
                    Check(day.IsPaused, "curtain pauses business");
                    double elapsed = day.DayElapsedSeconds, opening = day.OpeningRemainingSeconds;
                    await ToSignal(GetTree().CreateTimer(.12), SceneTreeTimer.SignalName.Timeout);
                    Check(day.DayElapsedSeconds == elapsed && day.OpeningRemainingSeconds == opening, "covered business clocks stay frozen");
                }
                await Sample(city + "-curtain-open", .72f); _motion.Finish(); await Frames();
                Check(!day.IsPaused, "curtain releases only its pause reason");
                day.Tick(3.1); await Frames();
                var screen = _main.GetNode<Control>(city == StableIds.Cities.Tianjin ? "UI/TianjinDayScreen" : "UI/WuhanDayScreen");
                GetWindow().GrabFocus();
                screen.Notification((int)NotificationApplicationFocusIn);
                if (screen is TianjinDayScreen tianjin) tianjin.OpenBusinessDetails();
                else ((WuhanDayScreen)screen).OpenBusinessDetails();
                CheckEffect(JourneyTransition.Effect.SpreadOpen, city + " ledger uses soft spread");
                Check(screen.FindChildren("SettlementBook", "Control", true, false).OfType<Control>()
                    .Where(b => b.IsVisibleInTree()).All(b => b.Modulate.A == 1f), city + " paper stays opaque during turn");
                await Sample(city + "-business-book", .5f); _motion.Finish(); await Frames();
                if (screen is TianjinDayScreen td) td.CloseBusinessDetails();
                else ((WuhanDayScreen)screen).CloseBusinessDetails();
                CheckEffect(JourneyTransition.Effect.SpreadClose, city + " ledger folds towards spine");
                await Sample(city + "-business-book-close", .5f); _motion.Finish(); await Frames();
                screen.FindChildren("HudPause", "Button", true, false).OfType<Button>().Single().EmitSignal(BaseButton.SignalName.Pressed);
                CheckEffect(JourneyTransition.Effect.OpenBook, city + " illustrated pause keeps existing effect");
                await Sample(city + "-pause", .6f); _motion.Finish(); await Frames();
                Check(day.IsPaused, "manual pause survives transition completion");
                var abandon = screen.GetChildren().OfType<ConfirmationDialog>().Single();
                abandon.PopupCentered(); await Complete(); await Capture(city + "-confirmation");
                abandon.GetCancelButton().EmitSignal(BaseButton.SignalName.Pressed);
                await Complete(); Check(!abandon.Visible && day.IsPaused, "cancel confirmation keeps manual pause");
                _main.OpenCity(city); await Sample(city + "-return", .7f); _motion.Finish();
                Check(_home.IsVisibleInTree(), "return reaches chapter");
            }
            ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            _home.PresentHome(); Check(!_motion.Active, "reduced motion switches immediately");
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            _home.PresentMap();
            _motion.Finish(); _motion.Finish(); Check(!_motion.Active, "repeated cancellation cleans overlay");
            GD.Print($"JOURNEY_TRANSITION_PASS checks={_checks}"); GetTree().Quit();
        }
        catch (Exception exception) { GD.PushError(exception.ToString()); GetTree().Quit(1); }
    }
    private Button FindButton(string name) => _home.FindChildren(name, "Button", true, false).OfType<Button>().First(b => b.IsVisibleInTree());
    private async Task SettingsFoldPreview()
    {
        if (DisplayServer.GetName() == "headless") throw new InvalidOperationException("Preview requires a rendered viewport.");
        _directory = ProjectSettings.GlobalizePath("res://.tmp/settings-fold-preview");
        Directory.CreateDirectory(_directory);
        FindButton("Settings").EmitSignal(BaseButton.SignalName.Pressed);
        CheckEffect(JourneyTransition.Effect.SpreadOpen, "only home settings uses new spread");
        _motion.HoldForCapture(0f);
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
        Check(_home.ModalOpen, "opening blocks accidental close");
        for (int i = 0; i <= 26; i++)
        {
            float time = i / 26f;
            _motion.HoldForCapture((1f - Mathf.Cos(time * Mathf.Pi)) * .5f);
            await Capture($"open-{i:00}");
        }
        _motion.Finish(); await Frames();
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
        CheckEffect(JourneyTransition.Effect.SpreadClose, "settings closes towards spine");
        for (int i = 0; i <= 26; i++)
        {
            float time = i / 26f;
            _motion.HoldForCapture((1f - Mathf.Cos(time * Mathf.Pi)) * .5f);
            await Capture($"close-{i:00}");
        }
        _motion.Finish(); await Frames();
        Check(!_home.ModalOpen && !_motion.Active, "close restores home input");
        FindButton("Settings").EmitSignal(BaseButton.SignalName.Pressed);
        await Complete(); Check(_home.ModalOpen && !_motion.Active, "spread completes naturally");
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
        await Complete(); Check(!_home.ModalOpen && !_motion.Active, "fold completes naturally");
        FindButton("Help").EmitSignal(BaseButton.SignalName.Pressed);
        CheckEffect(JourneyTransition.Effect.SpreadOpen, "help shares approved spread");
        _motion.Finish();
    }
    private void CheckEffect(JourneyTransition.Effect expected, string message)
    {
        if (DisplayServer.GetName() == "headless") return;
        var material = (ShaderMaterial)_motion.GetNode<TextureRect>("TransitionFrame").Material;
        Check(_motion.Active && material.GetShaderParameter("effect").AsInt32() == (int)expected, message);
    }
    private async Task HomeBookChecks(SaveService save)
    {
        foreach (var city in JourneyModel.Cities.Where(c => ExperienceProfile.IsCityAvailable(c.Id, ExperienceProfile.IsDemo)))
        {
            if (!save.Data.UnlockedCityIds.Contains(city.Id)) save.Data.UnlockedCityIds.Add(city.Id);
            save.Data.GetCity(city.Id).HighestUnlockedDay = 4;
            save.Data.LastVisitedCityId = city.Id;
            Check(save.TrySave(out _), city.Id + " fixture saved");
            _home.PresentHome(); await Complete();
            FindButton("Continue").EmitSignal(BaseButton.SignalName.Pressed);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, city.Id + " continue unfolds from spine");
            if (city.Id == StableIds.Cities.Wuhan) { await Sample("home-continue-fold", .5f); _motion.Finish(); }
            await Complete();
            foreach (var entry in new[] { ("ContinueTab", JourneyPage.City), ("LedgerTab", JourneyPage.Ledger), ("UpgradeTab", JourneyPage.Upgrades), ("ContinueTab", JourneyPage.City) })
            {
                if (_home.Page != entry.Item2)
                {
                    FindButton(entry.Item1).EmitSignal(BaseButton.SignalName.Pressed);
                    CheckEffect(JourneyTransition.Effect.SpreadOpen, city.Id + " unfolds " + entry.Item2);
                    await Complete();
                }
                Check(_home.Page == entry.Item2 && _home.SelectedCityId == city.Id, city.Id + " tab reaches " + entry.Item2);
                var book = _home.GetNode<TextureRect>("Canvas/Page/SharedBook");
                Check(book.Material is ShaderMaterial homeMaterial
                    && homeMaterial.Shader.ResourcePath == "res://resource/shaders/settings_book_decor.gdshader",
                    city.Id + " home book uses settings background " + entry.Item2);
                Check(new[] { "ContinueTab", "LedgerTab", "UpgradeTab" }.All(n => FindButton(n).IsVisibleInTree()), "three persistent bookmarks");
                Check(FindButton(entry.Item1).Disabled, "current bookmark selected");
                if (city.Id is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan) await Capture("home-" + city.Id + "-" + entry.Item2);
            }
            _home.PresentCity(city.Id); await Complete();
            if (city.Id is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan or StableIds.Cities.Xian)
                Check(_home.GetNode<TextureRect>("Canvas/Page/SharedBook").Material is ShaderMaterial, "city chapter retains its palette " + city.Id);
        }
        _home.PresentHome(); await Complete();
        foreach (string entry in new[] { "BreakfastRecords" })
        {
            FindButton(entry).EmitSignal(BaseButton.SignalName.Pressed);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, entry + " uses shared book unfolding");
            await Complete();
            _home.PresentHome();
            CheckEffect(JourneyTransition.Effect.SpreadClose, entry + " folds on return home");
            await Complete();
        }
    }
    private async Task SharedBookChecks(SaveService save)
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        foreach (string city in new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" })
        {
            save.Data.GetCity("city:" + city);
            var book = new BusinessDetailsView(); _main.GetNode("UI").AddChild(book);
            book.Open(new BusinessBookModel { CityId = city, Closing = true,
                Upgrades = city == "yangzhou" ? new BookUpgradeSource(save, ProjectCake.Yangzhou.YangzhouCatalog.Load())
                    : new BookUpgradeSource(save, catalog, "city:" + city) });
            CheckEffect(JourneyTransition.Effect.SpreadOpen, city + " business book unfolds");
            await Complete(); book.FinishAnimation(); await Frames();
            book.SelectPage(true);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, city + " detail page unfolds");
            await Complete();
            book.SelectPage(false);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, city + " summary unfolds");
            await Complete();
            book.Descendants<Button>().Single(b => b.Name == "UpgradeSticker" || b.Name == "OpenBookUpgrades").EmitSignal(BaseButton.SignalName.Pressed);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, city + " upgrades unfold");
            if (city == "yangzhou") { await Sample("shared-yangzhou-upgrades-fold", .5f); _motion.Finish(); }
            await Complete();
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            CheckEffect(JourneyTransition.Effect.SpreadOpen, city + " Escape return from upgrades unfolds");
            await Complete();
            book.Hide();
            CheckEffect(JourneyTransition.Effect.SpreadClose, city + " business book closes");
            await Complete(); book.QueueFree(); await Frames();
        }
        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        _home.PresentCity(StableIds.Cities.Tianjin, fromHome: true);
        Check(!_motion.Active, "reduced motion skips unfolding");
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
    }
    private void Check(bool condition, string message) { if (!condition) throw new InvalidOperationException(message); _checks++; GD.Print("PASS " + message); }
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Complete() { await ToSignal(GetTree().CreateTimer(.8), SceneTreeTimer.SignalName.Timeout); await Frames(); }
    private async Task Sample(string name, float value)
    {
        if (DisplayServer.GetName() == "headless") return;
        Check(_motion.Active, name + " animation started");
        _motion.HoldForCapture(value); await Capture(name);
    }
    private async Task Capture(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        await Frames();
        var drawn = ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        RenderingServer.ForceDraw();
        await drawn;
        using var image = GetViewport().GetTexture().GetImage();
        Check(image.SavePng(Path.Combine(_directory, name.Replace(':', '-') + ".png")) == Error.Ok, "capture " + name);
    }
}
