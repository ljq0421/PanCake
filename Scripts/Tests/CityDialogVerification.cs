using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class CityDialogVerification : Node
{
    private const string Output = "res://.tmp/tianjin-dialog-art/verification";
    private int _checks;
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            var save = GetNode<SaveService>("/root/SaveService");
            save.UsePathForTests(Output + "/fixture.json");
            Require(save.ResetProgress(out _), "isolated fixture initialized");
            GetNode<JourneySettings>("/root/JourneySettings").UsePathForTests(ProjectSettings.GlobalizePath(Output + "/settings.cfg"));
            InterfaceLessons.MarkAllSeen(GetNode<JourneySettings>("/root/JourneySettings"));
            save.Data.Coins = 5000;
            save.Data.Tianjin.HighestUnlockedDay = 15;
            save.Data.Wuhan.HighestUnlockedDay = save.Data.Xian.HighestUnlockedDay = 12;
            foreach (string id in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian })
                if (!save.Data.UnlockedCityIds.Contains(id)) save.Data.UnlockedCityIds.Add(id);
            save.TrySave(out _);
            foreach (int width in new[] { 1920, 1280 })
            {
                var viewport = new SubViewport { Size = new(width, width * 9 / 16), Size2DOverride = new(1920, 1080),
                    Size2DOverrideStretch = true, GuiEmbedSubwindows = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
                AddChild(viewport); viewport.NotifyMouseEntered();
                var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
                viewport.AddChild(main);
                var controller = main.GetNode<DayController>("DayController"); controller.SetProcess(false);
                foreach (var (city, id, day) in new[] { ("Tianjin", StableIds.Cities.Tianjin, 15),
                    ("Wuhan", StableIds.Cities.Wuhan, 12), ("Xian", StableIds.Cities.Xian, 12) })
                {
                    Require(main.StartCityBusiness(id, day), city + " real main navigation starts business");
                    var screen = main.GetNode<Control>("UI/" + city + "DayScreen"); screen.SetProcess(false);
                    screen._Notification((int)NotificationApplicationFocusIn);
                    controller.Tick(4);
                    switch (screen) { case TianjinDayScreen t: t.RefreshForCapture(); break;
                        case WuhanDayScreen w: w.RefreshForCapture(); break; case XianDayScreen x: x.Render(); break; }
                    await Frames();
                    var hud = (BusinessHud)screen.FindChild("BusinessHud", true, false);
                    Click(viewport, hud.PauseButton); await Frames();
                    double before = controller.DayElapsedSeconds; controller.Tick(2);
                    Require(controller.IsPaused && controller.DayElapsedSeconds == before, city + " pause freezes business");
                    await Shot(viewport, $"{city}-{width}-pause");
                    if (city == "Xian")
                    {
                        var panel = screen.GetNode<Panel>("Workbench/PauseMenu/Panel");
                        var teaching = panel.GetChildren().OfType<Label>().First(label => label.Name != "Title");
                        Click(viewport, panel.GetNode<Button>("help")); await Frames();
                        Require(teaching.Visible && panel.GetGlobalRect().Encloses(teaching.GetGlobalRect()), "Xian teaching fits the dialog");
                        Require(!teaching.GetGlobalRect().Intersects(panel.GetNode<Button>("help").GetGlobalRect()), "Xian teaching stays clear of actions");
                        await Shot(viewport, $"{city}-{width}-teaching");
                        Click(viewport, panel.GetNode<Button>("help")); await Frames();
                        Require(!teaching.Visible && panel.GetNode<Button>("resume").Position.X == 395, "Xian collapsed teaching restores centered actions");
                    }
                    if (city == "Wuhan")
                    {
                        save.Data.UnlockedCityIds.Remove(id);
                        Require(!main.OpenCity(id), "Wuhan internal navigation failure"); await Frames();
                        var internalError = main.GetNode<AcceptDialog>("NavigationError");
                        Require(((StyleBoxTexture)internalError.GetThemeStylebox("panel", "AcceptDialog")).Texture.ResourcePath
                            == "res://resource/art/Wuhan/DialogUI/dialog-panel-v1.png", "Wuhan internal prompt uses green frame");
                        await Shot(viewport, $"{city}-{width}-internal-navigation");
                        Click(internalError, internalError.GetOkButton()); await Frames();
                        save.Data.UnlockedCityIds.Add(id);
                    }
                    Control menu = city switch { "Tianjin" => (Control)screen.FindChild("PausePanel", true, false),
                        "Wuhan" => screen.GetNode<Control>("HudPauseMenu"), _ => screen.GetNode<Control>("Workbench/PauseMenu") };
                    Button abandon = menu.Descendants<Button>().First(b => b.Text.Contains("放弃") || b.Text.Contains("离开") || b.Text.Contains("返回首页"));
                    Click(viewport, abandon); await Frames();
                    var dialog = screen.Descendants<ConfirmationDialog>().First(d => d.Visible);
                    Require(dialog.Borderless && dialog.GetNode<CanvasLayer>("CityDialogHeader") != null, city + " illustrated header replaces native title bar");
                    Require(dialog.GetCancelButton().Text != "Cancel", city + " cancellation localized");
                    Require(screen.GetNodeOrNull<Control>("TianjinPauseTitleTape")?.Visible != true, "no orphan Tianjin tape");
                    var coveredPanel = city == "Tianjin" ? menu : menu.GetNode<Control>(city == "Wuhan" ? "HudPausePanel" : "Panel");
                    Require(!coveredPanel.Visible, city + " underlying pause panel hidden");
                    Require(dialog.GetThemeStylebox("panel", "AcceptDialog") is StyleBoxTexture, city + " confirmation uses artwork");
                    if (city is "Tianjin" or "Wuhan" or "Xian")
                    {
                        Require(dialog.Size == new Vector2I(1200, 630), city + " confirmation keeps its designed size after layout");
                        Require(!dialog.GetLabel().Text.Contains("\n\n"), city + " line breaks remain stable across resize callbacks");
                    }
                    controller.Tick(2); Require(controller.DayElapsedSeconds == before, city + " confirmation stays paused");
                    await Shot(viewport, $"{city}-{width}-abandon");
                    Click(dialog, dialog.GetCancelButton()); await Frames();
                    Require(!dialog.Visible && controller.IsPaused && menu.Visible, city + " cancel restores paused menu");
                    Click(viewport, abandon); await Frames();
                    var close = dialog.GetNode<Button>("CityDialogHeader/Artwork/Close");
                    if (city is "Tianjin" or "Wuhan" or "Xian")
                    {
                        Require(!close.Visible, city + " has no close icon or hit target");
                        KeyInput(viewport, Key.Escape); await Frames();
                    }
                    else
                    {
                        Require(!close.Disabled, city + " close remains enabled while business paused");
                        Click(dialog, close); await Frames();
                    }
                    Require(!dialog.Visible && coveredPanel.Visible && controller.IsPaused, city + " close restores pause panel");
                    Click(viewport, abandon); await Frames();
                    dialog.GetCancelButton().GrabFocus();
                    KeyInput(viewport, Key.Tab); await Frames();
                    Require(dialog.GetOkButton().HasFocus(), city + " Tab reaches confirmation");
                    KeyInput(viewport, Key.Escape); await Frames();
                    Require(!dialog.Visible && coveredPanel.Visible && controller.IsPaused, city + " Escape safely cancels");
                    Button resume = menu.Descendants<Button>().First(b => b.Text == "继续营业");
                    screen._Notification((int)NotificationApplicationFocusIn);
                    Click(viewport, resume); await Frames();
                    Require(!controller.IsPaused, city + " resume restores time");
                    Click(viewport, hud.PauseButton); await Frames(); Click(viewport, abandon); await Frames();
                    Click(dialog, dialog.GetOkButton()); await Frames();
                    Require(!screen.Visible && controller.State == DayState.Preparing, city + " confirm returns to hub");
                    save.Data.UnlockedCityIds.Remove(id);
                    Require(!main.OpenCity(id), city + " locked navigation fails"); await Frames();
                    var error = main.GetNode<AcceptDialog>("NavigationError");
                    Require(error.GetNode<Label>("CityDialogHeader/Artwork/Title").Text == error.Title, "navigation header uses current title");
                    Require(error.Visible && error.GetThemeStylebox("panel", "AcceptDialog") is StyleBoxTexture, city + " navigation error uses artwork");
                    if (city is "Tianjin" or "Wuhan" or "Xian")
                    {
                        var frame = (StyleBoxTexture)error.GetThemeStylebox("panel", "AcceptDialog");
                        Require(frame.Texture.ResourcePath == "res://resource/art/TianJin/DialogUI/dialog-panel-v1.png",
                            city + " home navigation retains the warm frame");
                        Require(error.GetLabel().GetThemeColor("font_color") == new Color("#542D16"),
                            city + " home navigation retains brown text");
                        Require(!error.GetNode<Control>("CityDialogHeader/Artwork/Close").Visible,
                            city + " navigation has no close icon");
                    }
                    await Shot(viewport, $"{city}-{width}-navigation");
                    Click(error, error.GetOkButton()); await Frames();
                    Require(!error.Visible, city + " navigation acknowledgment closes dialog");
                    save.Data.UnlockedCityIds.Add(id);
                }
                viewport.QueueFree(); await Frames();
            }
            GD.Print($"CITY_DIALOG_VERIFICATION_PASS checks={_checks}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print("CITY_DIALOG_VERIFICATION_FAIL"); GetTree().Quit(1); }
    }
    private void Require(bool ok, string message) { if (!ok) throw new Exception(message); _checks++; GD.Print("PASS " + message); }
    private static void Click(Viewport viewport, Control control)
    {
        Vector2 p = control.GetGlobalRect().GetCenter();
        if (viewport is Window window)
        {
            p += window.Position;
            viewport = window.GetParent().GetViewport();
        }
        viewport.PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
        viewport.PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = true }, true);
        viewport.PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = false }, true);
    }
    private static void KeyInput(Viewport viewport, Key key)
    {
        foreach (bool pressed in new[] { true, false })
            viewport.PushInput(new InputEventKey { Keycode = key, Pressed = pressed }, true);
    }
    private async Task Frames() { for (int i = 0; i < 4; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Shot(SubViewport viewport, string name)
    {
        await Frames();
        // A minimized test window does not emit FramePostDraw automatically.
        // Draw the offscreen viewport explicitly so capture remains deterministic.
        RenderingServer.ForceDraw(false);
        Require(viewport.GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath(Output + "/" + name + ".png")) == Error.Ok, "saved " + name);
    }
}
