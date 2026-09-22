using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TianjinFoldSelfTest : Node
{
    private const string Output = "res://artifacts/tianjin-fold-20260922";
    private int _checks;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private void Check(bool value, string message)
    {
        if (!value) throw new Exception(message);
        _checks++; GD.Print("FOLD_PASS " + message);
    }
    private async Task Frames(int count = 3)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    private async Task Shot(string name)
    {
        if (!Capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage();
        image.SavePng($"{Output}/{name}.png");
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            Input.UseAccumulatedInput = false;
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests($"{Output}/settings.cfg");
            InterfaceLessons.MarkAllSeen(settings);
            if (Capture) GetWindow().Position = new Vector2I(-10000, -10000);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var screenScene = GD.Load<PackedScene>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                var save = new SaveService(); save.UsePathForTests($"{Output}/save-{width}.json"); AddChild(save);
                save.Data.PurchasedStoveLevel = 3; save.Data.PurchasedIngredientStationLevel = 3;
                save.Data.PurchasedFryerLevel = 3;
                var controller = new DayController(); AddChild(controller);
                var screen = screenScene.Instantiate<TianjinDayScreen>();
                AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller);
                screen.Initialize(catalog, save, controller, width == 1920 ? 1 : 15);
                screen.BeginDay(); controller.Tick(3.1);
                screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
                await Frames();
                var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
                var canvas = station.Descendants<PancakeCanvas>().Single();
                station.ConfigureTutorial(null);
                int learnedFolds = 0;
                station.WorkbenchActionLearned += action => { if (action == "fold") learnedFolds++; };
                Vector2 Point(float x, float y = .5f) => GetViewport().GetFinalTransform() * canvas.GetGlobalTransformWithCanvas()
                    * (canvas.GetSurfaceRect().Position + canvas.GetSurfaceRect().Size * new Vector2(x, y));
                void Mouse(float x, bool pressed, float y = .5f) => Input.ParseInputEvent(new InputEventMouseButton
                    { ButtonIndex = MouseButton.Left, Pressed = pressed, Position = Point(x, y) });
                void Move(float x) => Input.ParseInputEvent(new InputEventMouseMotion
                    { Position = Point(x), ButtonMask = MouseButtonMask.Left });
                void Ready(PancakeState state = PancakeState.Toppings)
                {
                    station.CancelInput(); station.Machine.TryExecute(PancakeCommand.Discard);
                    station.Machine.Runtime.State = state;
                    station.Machine.Runtime.HasEgg = true; station.Machine.Runtime.HasSauce = true;
                    station.Machine.Runtime.SauceCoverage = 1;
                    station.Machine.Runtime.AddIngredient("crispy"); station.Machine.Runtime.AddIngredient("scallion");
                    station.RefreshForCapture();
                }
                Ready(); await Frames(); await Shot($"ready-{width}");
                var guidance = station.ResolveFocus(Array.Empty<TutorialOrder>(), (_, _) => Array.Empty<TutorialFocusTarget>());
                Check(guidance is { ActionId: "fold" } && guidance.Text.Contains("拖动")
                    && guidance.Targets.Single().Owner == station, "fold guidance targets the stove and explains dragging");
                Check(!((Button)station.FindChild("PancakeFoldAction", true, false)).Visible, "Tianjin fold button replaced");
                Mouse(.1f, true); await Frames();
                Check(station.IsFoldDragging, "real left input grabs the pancake edge");
                Move(.3f); await Frames(); await Shot($"lift-{width}");
                if (Capture)
                {
                    var snapshot = (SubViewport)canvas.FindChild("FoldFoodSnapshot", true, false);
                    using var foodImage = snapshot.GetTexture().GetImage();
                    foodImage.SavePng($"{Output}/food-layers-{width}.png");
                }
                Check(station.Machine.Runtime.State == PancakeState.Toppings, "lifting does not commit prematurely");
                Check(!station.TryInvokeProductionShortcut(Key.F), "held gesture cannot also trigger F");
                Check(!station.TryBeginTrashDrag(GetViewport().GetFinalTransform().AffineInverse() * Point(.5f)), "held food cannot be picked up twice");
                Mouse(.3f, false); await ToSignal(GetTree().CreateTimer(.25), SceneTreeTimer.SignalName.Timeout);
                Check(station.Machine.Runtime.State == PancakeState.Toppings && !canvas.FoldPreviewVisible,
                    "short drag returns without changing recipe");
                Check(learnedFolds == 0, "cancelled gesture does not teach folding");
                Mouse(.1f, true); await Frames();
                if (Capture && width == 1920)
                {
                    for (int frame = 0; frame <= 30; frame++)
                    {
                        Move(.1f + .52f * frame / 30);
                        await Frames(1); await Shot($"soft-drag-{frame:D3}");
                    }
                }
                else Move(.62f);
                await Frames(); await Shot($"cover-{width}");
                Mouse(.62f, false);
                if (Capture && width == 1920)
                    for (int frame = 31; frame <= 48; frame++) { await Frames(1); await Shot($"soft-drag-{frame:D3}"); }
                await ToSignal(GetTree().CreateTimer(.25), SceneTreeTimer.SignalName.Timeout);
                Check(station.Machine.Runtime.State == PancakeState.Folded && !station.IsFoldDragging,
                    "crossing center and releasing folds once");
                Check(learnedFolds == 1, "successful gesture records the existing fold lesson exactly once");
                Check(station.Machine.Runtime.HasEgg && station.Machine.Runtime.HasSauce
                    && station.Machine.Runtime.ExtraIngredients.SetEquals(new[] { "crispy", "scallion" }), "fold preserves filling and sauce");
                await Shot($"folded-{width}");
                Check(station.TryInvokeProductionShortcut(Key.F), "bag follows successful gesture");
                Ready(); Mouse(.9f, true); Move(.38f); Mouse(.38f, false);
                Check(station.Machine.Runtime.State == PancakeState.Folded, $"right edge also folds toward opposite side (state={station.Machine.Runtime.State}, held={station.IsFoldDragging}, day={controller.State}, paused={station.Paused})");
                Ready(); Mouse(.1f, true); Mouse(.1f, false);
                Check(station.Machine.Runtime.State == PancakeState.Toppings, "tap never folds");
                Ready(); Mouse(.1f, true); Move(.7f); Mouse(.7f, false, 2);
                Check(station.Machine.Runtime.State == PancakeState.Toppings, "release far outside cancels");
                Ready(); Mouse(.1f, true); Move(.7f); Move(.2f); Mouse(.2f, false);
                Check(station.Machine.Runtime.State == PancakeState.Toppings, "dragging back below threshold cancels");
                Ready(); Mouse(.1f, true); Move(.4f); screen.OpenBusinessDetails(); await Frames();
                Check(!station.IsFoldDragging && !canvas.FoldPreviewVisible, "details cancel unfinished fold");
                screen.CloseBusinessDetails(); screen.RefreshForCapture(true);
                Ready(); Mouse(.1f, true); Move(.4f); screen._Notification((int)NotificationApplicationFocusOut);
                Check(!station.IsFoldDragging && !canvas.FoldPreviewVisible, "focus loss clears preview");
                screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
                Ready(); Mouse(.1f, true); Move(.4f);
                Input.ParseInputEvent(new InputEventKey { Keycode = Key.Escape, Pressed = true });
                Check(!station.IsFoldDragging && station.Machine.Runtime.State == PancakeState.Toppings, "Escape cancels without committing");
                Ready(PancakeState.SideAReady); Mouse(.1f, true); Move(.7f); Mouse(.7f, false);
                Check(station.Machine.Runtime.State != PancakeState.Folded && !station.IsFoldDragging, "cannot fold before sauce (inward drag now flips)");
                Ready(); ProjectSettings.SetSetting("accessibility/reduce_motion", true); await Frames();
                Mouse(.1f, true); Move(.7f); Mouse(.7f, false);
                Check(station.Machine.Runtime.State == PancakeState.Folded && !canvas.FoldPreviewVisible, $"reduced motion commits without tail (state={station.Machine.Runtime.State}, held={station.IsFoldDragging}, preview={canvas.FoldPreviewVisible}, paused={station.Paused})");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                Ready(); Check(station.TryInvokeProductionShortcut(Key.F), "F accessibility shortcut retained");
                Ready(); Mouse(.1f, true); Move(.4f); station.ResetForDay(); await Frames();
                Check(!station.IsFoldDragging && !canvas.FoldPreviewVisible && station.Machine.Runtime.State == PancakeState.Empty, "reset clears fold");
                Ready(); Mouse(.1f, true); screen.Hide(); await Frames();
                Check(!station.IsFoldDragging && !canvas.FoldPreviewVisible, "hiding clears fold");
                screen.QueueFree(); controller.QueueFree(); save.QueueFree(); await Frames();
            }
            GD.Print($"TIANJIN_FOLD_TEST: {_checks} passed, 0 failed"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
