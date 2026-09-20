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
            await Capture("home");
            string before = File.ReadAllText(Path.Combine(fixture, "save.json"));
            _home.PresentMap();
            await Sample("page-forward", .38f);
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            Check(_home.Page == JourneyPage.Map, "keyboard blocked during page turn");
            _motion.Finish(); await Frames();
            _home.PresentHome(); await Sample("page-back", .6f); _motion.Finish(); await Frames();
            FindButton("Settings").EmitSignal(BaseButton.SignalName.Pressed);
            await Sample("settings-opening", .5f); _motion.Finish(); await Frames();
            Check(_home.ModalOpen, "settings open");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            await Sample("settings-closing", .5f); _motion.Finish();
            Check(!_home.ModalOpen, "settings close restores navigation");
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
                await Sample(city + "-business-book", .5f); _motion.Finish(); await Frames();
                if (screen is TianjinDayScreen td) td.CloseBusinessDetails();
                else ((WuhanDayScreen)screen).CloseBusinessDetails();
                await Sample(city + "-business-book-close", .5f); _motion.Finish(); await Frames();
                screen.FindChildren("HudPause", "Button", true, false).OfType<Button>().Single().EmitSignal(BaseButton.SignalName.Pressed);
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
        await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage();
        Check(image.SavePng(Path.Combine(_directory, name.Replace(':', '-') + ".png")) == Error.Ok, "capture " + name);
    }
}
