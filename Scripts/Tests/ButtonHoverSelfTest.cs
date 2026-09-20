using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class ButtonHoverSelfTest : Node
{
    private const string Output = "res://artifacts/button-hover";
    private SubViewport _viewport = null!;
    private int _checks;
    private void Require(bool value, string message)
    { if (!value) throw new Exception(message); _checks++; }
    private async Task Frames(int count = 5)
    { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Settle()
    { await ToSignal(GetTree().CreateTimer(.22), SceneTreeTimer.SignalName.Timeout); await Frames(); }
    private void Move(Vector2 point) => _viewport.PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point }, true);
    private async Task Shot(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = _viewport.GetTexture().GetImage();
        Require(image.SavePng(ProjectSettings.GlobalizePath(Output + "/" + name + ".png")) == Error.Ok, "capture " + name);
    }
    private async Task CheckHover(BaseButton button, string name, Control? visual = null)
    {
        visual ??= button;
        Require(button.GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is not null, name + " attached");
        button.ReleaseFocus(); Move(new(1918, 1078)); await Settle();
        Vector2 rest = visual.Scale, position = visual.Position;
        Vector2 center = visual.GetGlobalTransform() * (visual.Size * .5f);
        Move(button.GetGlobalTransform() * (button.Size * .5f)); await Settle();
        Require(button.IsHovered(), name + " receives native hover");
        Require(visual.Scale.IsEqualApprox(rest * 1.04f), name + " grows uniformly");
        Require(visual.Position.IsEqualApprox(position), name + " does not move up");
        Require((visual.GetGlobalTransform() * (visual.Size * .5f)).DistanceTo(center) < .05f, name + " center fixed");
        await Shot(name + "-hover");
        // Interrupt the animation repeatedly, then leave; no accumulation or stale tween.
        for (int i = 0; i < 4; i++) { Move(new(1918, 1078)); await Frames(1); Move(button.GetGlobalRect().GetCenter()); await Frames(1); }
        Move(new(1918, 1078)); await Settle();
        Require(visual.Scale.IsEqualApprox(rest), name + " exit restores scale");
        button.GrabFocus(); await Settle();
        Require(visual.Scale.IsEqualApprox(rest * 1.04f), name + " keyboard focus");
        button.Disabled = true; await Frames();
        Require(visual.Scale.IsEqualApprox(rest), name + " disabled resets");
        button.Disabled = false; button.ReleaseFocus(); await Settle();
    }

    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            GetWindow().Position = new(-10000, -10000);
            var save = GetNode<SaveService>("/root/SaveService");
            save.UsePathForTests(Output + "/fixture.json"); Require(save.ResetProgress(out _), "isolated save");
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(ProjectSettings.GlobalizePath(Output + "/settings.cfg"));
            InterfaceLessons.MarkAllSeen(settings);
            save.Data.Coins = 10000;
            foreach (string city in new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" })
            { string id = "city:" + city; if (!save.Data.UnlockedCityIds.Contains(id)) save.Data.UnlockedCityIds.Add(id); save.Data.GetCity(id).HighestUnlockedDay = 1; }
            Require(save.TrySave(out _), "fixture saved");
            _viewport = new SubViewport { Size = new(1920, 1080), GuiEmbedSubwindows = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport); _viewport.NotifyMouseEntered();
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            _viewport.AddChild(main);
            var start = main.GetNode<StartScreen>("UI/StartScreen"); start.PresentHome(); await Settle();
            var home = start.Descendants<Button>().First(b => b.Name == "Continue");
            home.ReleaseFocus(); Move(new(1918, 1078)); await Settle(); await Shot("home-rest");
            await CheckHover(home, "home");
            var settingsButton = start.Descendants<Button>().First(b => b.Name == "Settings");
            settingsButton.EmitSignal(BaseButton.SignalName.Pressed); await Settle();
            await CheckHover(start.Descendants<Button>().First(b => b.Name == "Windowed"), "settings");
            start.Descendants<Button>().First(b => b.Name == "Close" && b.IsVisibleInTree()).EmitSignal(BaseButton.SignalName.Pressed);
            foreach (string city in new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" })
            {
                Require(main.StartCityBusiness("city:" + city, 1), city + " started"); await Settle();
                var screen = main.GetNode<Control>("UI/" + char.ToUpperInvariant(city[0]) + city[1..] + "DayScreen");
                screen._Notification((int)NotificationApplicationFocusIn);
                await Settle();
                screen.SetProcess(false);
                main.GetNode<DayController>("DayController").SetProcess(false);
                var hud = screen.Descendants<BusinessHud>().First();
                var pause = hud.PauseButton.IsVisibleInTree() ? hud.PauseButton
                    : screen.Descendants<Button>().First(b => b.IsVisibleInTree() && b.Text == "暂停");
                await CheckHover(pause, city + "-pause");
                if (screen is TianjinDayScreen t)
                {
                    await CheckHover(t.CashPendant, "tianjin-pendant", t.GetNode<Control>("LivingWorkbench/PendantHover"));
                    main.GetNode<DayController>("DayController").Tick(3.1);
                    t.RefreshForCapture(true);
                    var living = t.GetNode<TianjinLivingWorkbench>("LivingWorkbench");
                    Move(t.CashPendant.GetGlobalRect().GetCenter()); await Settle();
                    living.ReceivePayment();
                    await ToSignal(GetTree().CreateTimer(.06), SceneTreeTimer.SignalName.Timeout);
                    Require(Math.Abs(living.PendantRotation) > .01f && Math.Abs(living.PendantRotation) <= 4.01f, "payment swing coexists with hover");
                    Require(living.GetNode<Control>("PendantHover").Scale.IsEqualApprox(Vector2.One * 1.04f), "payment preserves hover scale");
                    await ToSignal(GetTree().CreateTimer(.5), SceneTreeTimer.SignalName.Timeout);
                    Require(Math.Abs(living.PendantRotation) < .01f, "payment swing settles");
                }
                if (screen is WuhanDayScreen w)
                    Require(w.CashPendant.GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is null, "Wuhan retains highlight only");
                Require(!screen.Descendants<ProjectCake.Interaction.ClickInteractable>().Any(b => b.GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is not null), city + " ingredients unchanged");
            }
            GD.Print($"BUTTON_HOVER_SELF_TEST_OK checks={_checks}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
