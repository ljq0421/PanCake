using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TianjinDirectFoodSelfTest : Node
{
    private bool CaptureCursor => OS.GetCmdlineUserArgs().Contains("--pinch-cursor");
    private string Output => CaptureCursor ? "res://artifacts/pinch-cursor-20260923/direct" : "res://artifacts/tianjin-bag-stack-20260922";
    private int _checks;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private void Check(bool value, string message)
    {
        if (!value) throw new Exception(message);
        _checks++; GD.Print("DIRECT_PASS " + message);
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
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests($"{Output}/settings.cfg"); InterfaceLessons.MarkAllSeen(settings);
            if (Capture && !CaptureCursor) GetWindow().Position = new Vector2I(-10000, -10000);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var scene = GD.Load<PackedScene>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                var save = new SaveService(); save.UsePathForTests($"{Output}/save-{width}.json"); AddChild(save);
                save.Data.PurchasedStoveLevel = 3; save.Data.PurchasedIngredientStationLevel = 3; save.Data.PurchasedFryerLevel = 3;
                var controller = new DayController(); AddChild(controller);
                var screen = scene.Instantiate<TianjinDayScreen>();
                AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller);
                screen.Initialize(catalog, save, controller, width == 1920 ? 1 : 15); screen.BeginDay(); controller.Tick(3.1);
                screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true); await Frames();
                var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
                var canvas = station.Descendants<PancakeCanvas>().Single();
                station.ConfigureTutorial(null);
                var living = screen.GetNode<TianjinLivingWorkbench>("LivingWorkbench");
                int flips = 0, bags = 0;
                station.WorkbenchActionLearned += action => { if (action == "flip") flips++; if (action == "bag") bags++; };
                Vector2 Point(float x, float y = .5f) => GetViewport().GetFinalTransform() * canvas.GetGlobalTransformWithCanvas()
                    * (canvas.GetSurfaceRect().Position + canvas.GetSurfaceRect().Size * new Vector2(x, y));
                Vector2 Stack() => GetViewport().GetFinalTransform() * station.GetGlobalTransformWithCanvas() * station.BagStackBounds.GetCenter();
                Vector2 Food() => Point(.5f, .45f);
                void Mouse(Vector2 at, bool down) { Input.ParseInputEvent(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = down, Position = at }); Input.FlushBufferedEvents(); }
                void Move(Vector2 at) { Input.ParseInputEvent(new InputEventMouseMotion { Position = at, ButtonMask = MouseButtonMask.Left }); Input.FlushBufferedEvents(); }
                void Ready(PancakeState state = PancakeState.SideAReady)
                {
                    station.CancelInput(); station.Machine.TryExecute(PancakeCommand.Discard);
                    station.Machine.Runtime.State = state; station.Machine.Runtime.HasEgg = true;
                    station.Machine.Runtime.HasSauce = state == PancakeState.Folded;
                    station.Machine.Runtime.SauceCoverage = 1;
                    if (state == PancakeState.Folded) station.Machine.Runtime.AddIngredient("crispy"); station.RefreshForCapture();
                }
                Ready(); await Frames();
                if (CaptureCursor)
                {
                    GetWindow().GrabFocus();
                    Move(Point(.9f)); await Frames(8);
                    Check(station.GetNode<PancakePinchCursor>("PancakePinchCursor").Visible
                        && Input.MouseMode == Input.MouseModeEnum.Hidden, $"pinch hand appears on grabbable rim (focus={GetWindow().HasFocus()}, pointer={GetViewport().GetMousePosition()}, target={Point(.9f)}, mode={Input.MouseMode}, paused={station.Paused})");
                    await Shot($"pinch-hover-{width}");
                    Move(Point(.5f)); await Frames();
                    Check(!station.GetNode<PancakePinchCursor>("PancakePinchCursor").Visible
                        && Input.MouseMode == Input.MouseModeEnum.Visible, "center hover restores regular cursor");
                }
                Check(station.GetNode<Control>("DirectPaperBag").IsVisibleInTree(), "paper stack visible before folding");
                Mouse(Stack(), true); Mouse(Stack(), false);
                Check(!station.IsDirectDragging && station.Machine.Runtime.State == PancakeState.SideAReady, "paper pickup requires folded food");
                Check(!((Button)station.FindChild("PancakeFlipAction", true, false)).Visible, "flip button removed");
                Mouse(Point(.9f), true); await Frames(); Move(Point(.82f)); await Frames();
                Check(station.IsDirectDragging && !station.IsFlipping && station.Machine.Runtime.State == PancakeState.SideAReady, "edge lift does not commit early");
                if (CaptureCursor) Check(station.GetNode<PancakePinchCursor>("PancakePinchCursor").Visible, "pinch cursor stays visible during flip drag");
                Check(!station.TryInvokeProductionShortcut(Key.F), "held gesture blocks F");
                Check(!station.TryBeginTrashDrag(GetViewport().GetFinalTransform().AffineInverse() * Point(.5f)), "held gesture blocks trash pickup");
                await Shot($"flip-lift-{width}");
                Mouse(Point(.82f), false); station.Tick(.2); await Frames();
                Check(station.Machine.Runtime.State == PancakeState.SideAReady && canvas.FlipPickup == 0 && flips == 0, $"short drag returns without teaching (state={station.Machine.Runtime.State}, pickup={canvas.FlipPickup}, flips={flips}, held={station.IsDirectDragging})");
                foreach (float edge in new[] { .9f, .1f })
                {
                    Ready(); Mouse(Point(edge), true); Move(Point(.5f)); await Frames();
                    Check(!living.ToolsAtRest, "spatula follows picked edge");
                    Mouse(Point(.5f), false); Check(station.IsFlipping, "inward release flips");
                    station.Tick(.1); await Frames(); await Shot($"flip-air-{edge}-{width}");
                    station.Tick(.3); await Frames();
                    Check(!station.IsFlipping && station.Machine.Runtime.HasEgg && living.ToolsAtRest, "soft flip lands with egg intact");
                }
                Check(flips == 1, "successful flips record the tutorial once");
                // Previously rejected: a grip slightly inside the narrow rim,
                // a short deliberate inward pull, or a release beyond the stove.
                Ready(); Mouse(Point(.74f), true); Move(Point(.64f)); Mouse(Point(.64f), false);
                Check(station.IsFlipping, "inner edge grip and short inward pull flip"); station.Tick(.4);
                Ready(); Mouse(Point(1.06f), true); Move(Point(.96f)); Mouse(Point(.96f), false);
                Check(station.IsFlipping, "near-rim grip tolerates painted edge padding"); station.Tick(.4);
                Ready(); Mouse(Point(.9f), true); Move(Point(.65f, 1.2f)); Mouse(Point(.65f, 1.2f), false);
                Check(station.IsFlipping, "diagonal inward drag can release beyond stove"); station.Tick(.4);
                Ready(); Mouse(Point(.5f), true); Mouse(Point(.5f), false);
                Check(!station.IsDirectDragging && !station.IsFlipping, "center click does not accidentally flip");
                Ready(); Mouse(Point(.9f), true); Move(Point(1.1f)); Mouse(Point(1.1f), false);
                Check(station.Machine.Runtime.State == PancakeState.SideAReady, "outward drag does not flip");
                Ready(); Mouse(Point(.9f), true); Mouse(Point(.9f), false);
                Check(station.Machine.Runtime.State == PancakeState.SideAReady, "edge click without drag does not flip");
                Ready(); Mouse(Point(.9f), true); Move(Point(.5f)); Move(Point(.9f)); Mouse(Point(.9f), false); station.Tick(.2);
                Check(station.Machine.Runtime.State == PancakeState.SideAReady, "drag back cancels");
                Ready(PancakeState.SideACooking); Mouse(Point(.9f), true); Move(Point(.5f)); Mouse(Point(.5f), false);
                Check(!station.IsDirectDragging && station.Machine.Runtime.State == PancakeState.SideACooking, "uncooked food cannot flip");
                Ready(); Mouse(Point(.9f), true); Move(Point(.5f)); station.Machine.Runtime.State = PancakeState.Burnt; station.Tick(0); Mouse(Point(.5f), false);
                Check(!station.IsDirectDragging && canvas.FlipPickup == 0 && station.Machine.Runtime.State == PancakeState.Burnt, "burn invalidates gesture");
                Ready(PancakeState.Folded); await Frames(); await Shot($"bag-ready-{width}");
                Check(!((Button)station.FindChild("PancakeBagAction", true, false)).Visible, "bag button removed");
                Mouse(Food(), true); Move(Stack()); Mouse(Stack(), false);
                Check(!station.IsDirectDragging && !canvas.DirectFoodHidden && station.Machine.Runtime.State == PancakeState.Folded,
                    "old food-to-stack gesture cannot package or move food");
                Mouse(Stack(), true); Move(Stack() + new Vector2(-80, -80)); Mouse(Stack() + new Vector2(-80, -80), false); station.Tick(.2); await Frames();
                Check(station.Machine.Runtime.State == PancakeState.Folded && !canvas.DirectFoodHidden && bags == 0, "missed food returns paper to stack without consuming food");
                Mouse(Stack(), true); Move(Food()); await Frames(); await Shot($"bag-mouth-{width}");
                Check(station.IsDirectDragging && !canvas.DirectFoodHidden && station.Machine.Runtime.State == PancakeState.Folded, "paper hovers over stationary food without committing");
                Check(!station.TryInvokeProductionShortcut(Key.F), "held paper blocks shortcut duplication");
                Mouse(Food(), false);
                Check(bags == 1 && station.Machine.Runtime.State == PancakeState.Bagged, "bag release commits once");
                Check(!station.CanDeliverProduct("finished_pancake"), "food cannot deliver during insertion");
                station.Tick(.12); await Frames(); await Shot($"bag-insert-{width}");
                station.Tick(.2); await Frames(); await Shot($"bag-complete-{width}");
                Check(station.CanDeliverProduct("finished_pancake") && station.Machine.Runtime.ExtraIngredients.Contains("crispy"), "finished bag is deliverable with recipe preserved");
                var finished = (Control)station.FindChild("FinishedPancakeDrag", true, false);
                Check(finished.GetGlobalRect().HasPoint(GetViewport().GetFinalTransform().AffineInverse() * Food()), "finished food is picked up on stove");
                Check(!finished.GetGlobalRect().HasPoint(GetViewport().GetFinalTransform().AffineInverse() * Stack()), "paper stack is separate from delivery hit area");
                Check(station.GetNode<Control>("DirectPaperBag").Visible, "stack remains after packaging");
                Mouse(Stack(), true); Mouse(Stack(), false);
                Check(!station.IsDirectDragging && station.Machine.Runtime.State == PancakeState.Bagged, "cannot package a finished order twice");
                Mouse(Food(), true); Move(Food() + new Vector2(0, -50)); await Frames();
                Check(station.Descendants<DragService>().Single().IsDragging, "actual mouse can pick up packaged food from stove");
                Input.ParseInputEvent(new InputEventKey { Keycode = Key.Escape, Pressed = true }); Input.FlushBufferedEvents();
                Mouse(Food(), false); await Frames();
                Check(station.CanDeliverProduct("finished_pancake"), "cancelled delivery returns packaged food");
                Check(station.DeliverToCustomer("finished_pancake", () => true) && station.Machine.Runtime.State == PancakeState.Empty,
                    "successful handoff clears stove for next pancake");
                Check(station.GetNode<Control>("DirectPaperBag").Visible, "stack persists after handoff");
                Ready(); Mouse(Point(.9f), true); Move(Point(.5f)); screen.OpenBusinessDetails(); await Frames();
                Check(!station.IsDirectDragging && canvas.FlipPickup == 0, "details cancel uncommitted flip");
                screen.CloseBusinessDetails(); screen.RefreshForCapture(true);
                Ready(PancakeState.Folded); Mouse(Stack(), true); Move(Food()); screen._Notification((int)NotificationApplicationFocusOut);
                Check(!station.IsDirectDragging && !canvas.DirectFoodHidden && station.Machine.Runtime.State == PancakeState.Folded, "focus loss returns paper and keeps food on stove");
                screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
                Ready(PancakeState.Folded); Check(station.TryInvokeProductionShortcut(Key.F), "F bags with same animation");
                screen.OpenBusinessDetails(); await Frames();
                Check(station.Machine.Runtime.State == PancakeState.Bagged && !canvas.DirectFoodHidden, "pause settles committed bag");
                screen.CloseBusinessDetails(); screen.RefreshForCapture(true);
                Ready(PancakeState.Folded); Mouse(Stack(), true); Move(Food());
                Input.ParseInputEvent(new InputEventKey { Keycode = Key.Escape, Pressed = true }); Input.FlushBufferedEvents(); station.Tick(.2);
                Check(station.Machine.Runtime.State == PancakeState.Folded && !station.IsDirectDragging, "Escape returns paper");
                Mouse(Stack(), true); Move(Food());
                Input.ParseInputEvent(new InputEventMouseButton { ButtonIndex = MouseButton.Right, Pressed = true, Position = Food() }); Input.FlushBufferedEvents();
                station.Tick(.2); Mouse(Food(), false);
                Input.ParseInputEvent(new InputEventMouseButton { ButtonIndex = MouseButton.Right, Pressed = false, Position = Food() }); Input.FlushBufferedEvents();
                Check(station.Machine.Runtime.State == PancakeState.Folded && !station.IsDirectDragging && !canvas.DirectFoodHidden,
                    "right click returns paper without discarding food");
                Ready(); ProjectSettings.SetSetting("accessibility/reduce_motion", true); await Frames();
                Mouse(Point(.9f), true); Check(station.IsDirectDragging, "reduced motion still starts gesture");
                Move(Point(.5f)); Mouse(Point(.5f), false);
                Check(!station.IsFlipping && station.Machine.Runtime.State == PancakeState.SideBCooking, $"reduced motion flips immediately (state={station.Machine.Runtime.State}, paused={station.Paused}, held={station.IsDirectDragging})");
                Ready(PancakeState.Folded); Mouse(Stack(), true); Move(Food()); Mouse(Food(), false);
                Check(station.CanDeliverProduct("finished_pancake") && !canvas.DirectFoodHidden, "reduced motion bags immediately and releases stove visual");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                Ready(); Check(station.TryInvokeProductionShortcut(Key.F), "F flip retained"); station.Tick(.4);
                Ready(PancakeState.Folded); Mouse(Stack(), true); station.ResetForDay();
                Check(!station.IsDirectDragging && !canvas.DirectFoodHidden, "reset clears gesture");
                Ready(); Mouse(Point(.9f), true); screen.Hide(); await Frames();
                Check(!station.IsDirectDragging && canvas.FlipPickup == 0, "hide clears gesture");
                if (CaptureCursor) Check(Input.MouseMode == Input.MouseModeEnum.Visible, "hiding restores OS cursor");
                screen.QueueFree(); controller.QueueFree(); save.QueueFree(); await Frames();
            }
            GD.Print($"TIANJIN_DIRECT_TEST: {_checks} passed, 0 failed"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
