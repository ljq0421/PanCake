using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Exercises live customer delivery and drag feedback without advancing the business clock.</summary>
public partial class InteractionHighlightSelfTest : Node
{
    private int _passed;
    private SubViewport _viewport = null!;
    private bool Capture => OS.GetCmdlineUserArgs().Any(arg => arg is "--capture" or "--capture-720");
    private int CaptureWidth => OS.GetCmdlineUserArgs().Contains("--capture-720") ? 1280 : 1920;

    public override async void _Ready()
    {
        string savePath = $"res://.tmp/interaction-highlight-{Guid.NewGuid():N}.json";
        bool reduced = ProjectSettings.HasSetting("accessibility/reduce_motion")
            && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath("res://.tmp"));
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            GetWindow().Size = new Vector2I(CaptureWidth, CaptureWidth * 9 / 16);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests(savePath); AddChild(save);
            var controller = new DayController(); AddChild(controller);
            // A hidden native Window has no reliable OS pointer. This viewport
            // renders the unchanged scene and accepts deterministic player input.
            _viewport = new SubViewport { Name = "InteractionTestViewport", Disable3D = true,
                Size = new Vector2I(CaptureWidth, CaptureWidth * 9 / 16),
                Size2DOverride = new Vector2I(1920, 1080), Size2DOverrideStretch = true,
                RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport);
            _viewport.NotifyMouseEntered();
            var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
            _viewport.AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller);
            screen.Initialize(catalog, save, controller, 15);

            // Three-item orders expose a progress refresh while the same customer
            // remains at the counter, which used to replay the arrival fade.
            foreach (PlannedCustomer planned in controller.CurrentPlan!.Customers)
                planned.Order = new OrderData { OrderId = planned.Order.OrderId, CustomerTypeId = planned.CustomerTypeId,
                    Lines = new[] { new OrderLineData(ProductKind.Youtiao, StableIds.Products.Youtiao, 2),
                        new OrderLineData(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1) }, BasePrice = 7 };
            screen.BeginDay(); controller.Tick(3.1);
            controller.CustomerQueue!.Tick(1000, .4, true);
            screen.RefreshForCapture(true);
            var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
            var drag = station.GetChildren().OfType<DragService>().Single();
            var source = (DragItem)station.FindChild("FinishedYoutiaoDrag", true, false);
            var slot = (Control)screen.FindChild("CustomerSlot1", true, false);
            var zone = (DropZone)screen.FindChild("CustomerDropZone1", true, false);
            var portrait = slot.FindChildren("*", "", true, false).OfType<CustomerPortraitView>().Single();
            var contour = portrait.GetChildren().OfType<ArtContourHighlight>().Single();
            TextureRect[] layers = portrait.GetChildren().OfType<TextureRect>().ToArray();
            CustomerRuntime customer = controller.CustomerQueue.CustomerAtSlot(0)!;
            Check(controller.CustomerQueue.Slots.Count == 5 && slot.Modulate.A < .999f,
                "new customers keep their normal arrival fade");
            await Wait(.30);
            Check(slot.Modulate.A > .999f, "arrival reaches full opacity");
            Material?[] materials = layers.Select(layer => layer.Material).ToArray();
            Color[] colors = layers.Select(layer => layer.Modulate).ToArray();
            Color portraitColor = portrait.Modulate;
            Rect2? hitRect = zone.FixedHitRect;
            float hitPadding = zone.HitPadding;
            Vector2[] slotPositions = screen.FindChildren("CustomerSlot*", "", true, false).OfType<Control>()
                .Select(view => view.GlobalPosition).ToArray();

            station.FryerMachine!.Inventory.TryStore(2, YoutiaoQuality.Golden);
            customer.WaitSeconds = 10;
            screen.RefreshForCapture(true);
            await Shot("tianjin-before-delivery");
            double patienceBefore = customer.WaitSeconds;
            Check(zone.TryAccept("stored_youtiao"), "first item follows the real customer delivery path");
            screen.RefreshForCapture(true);
            Check(ReferenceEquals(controller.CustomerQueue.CustomerAtSlot(0), customer)
                && customer.Progress.GetDeliveredQuantity(0) == 1 && !customer.WasServed
                && customer.WaitSeconds < patienceBefore,
                "partial delivery keeps the customer and restores patience");
            Check(slot.Modulate.A > .999f && portrait.Modulate == portraitColor,
                "partial delivery refresh does not restart the portrait fade or tint");
            await Shot("tianjin-after-partial-delivery");

            // Start through the real stock input, then move the actual drag over
            // empty counter space and onto the customer. No manual visual state.
            BeginYoutiaoDrag(source);
            Check(drag.IsDragging, "finished food starts dragging through its stock input");
            MoveDrag(drag, new Vector2(1840, 1030));
            await Wait(.13);
            Check(zone.VisualState == DropZoneVisualState.Eligible && contour.Visible,
                "a carried matching item exposes the eligible customer contour");
            Vector2 target = zone.GetGlobalRect().GetCenter();
            MoveDrag(drag, target);
            await Wait(.13);
            Check(zone.VisualState == DropZoneVisualState.HoverValid && contour.Visible,
                "moving the item over its customer strengthens the contour");
            Check(layers.Select((layer, i) => layer.Material == materials[i] && layer.Modulate == colors[i]).All(value => value)
                && portrait.Modulate == portraitColor && zone.FixedHitRect == hitRect && zone.HitPadding == hitPadding
                && zone.ContainsPoint(target, false),
                "highlighting preserves source materials, portrait color and delivery hit geometry");
            await Shot("tianjin-valid-customer-contour");
            MoveDrag(drag, new Vector2(1840, 1030));
            using (var escape = new InputEventKey { Keycode = Key.Escape, Pressed = true }) drag._Input(escape);
            await Wait(.16);
            Check(!drag.IsDragging && zone.VisualState == DropZoneVisualState.Idle && !contour.Visible
                && customer.Progress.GetDeliveredQuantity(0) == 1 && station.FryerMachine.Inventory.Count == 1,
                "Esc clears the drag contour without delivering or consuming food");

            float deliveredOpacity = -1;
            DragResult? dragResult = null;
            drag.DragEnded += result =>
            {
                dragResult = result;
                if (result.Completion != DragCompletion.Accepted) return;
                screen.RefreshForCapture(true);
                deliveredOpacity = slot.Modulate.A;
            };
            BeginYoutiaoDrag(source);
            MoveDrag(drag, target);
            using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = target })
                drag._Input(release);
            await Wait(.30);
            Check(dragResult?.Completion == DragCompletion.Accepted && deliveredOpacity > .999f
                && customer.Progress.GetDeliveredQuantity(0) == 2 && station.FryerMachine.Inventory.Count == 0
                && controller.CustomerQueue.Slots.Where(other => other != customer).All(other => other.Progress.DeliveredItems.Count == 0),
                "dropping the second item serves only the target and keeps its portrait fully visible");

            station.SoyMilkTray!.Tick(.3);
            Check(zone.TryAccept("soy_milk_cup") && customer.WasServed, "the final item completes the same customer's order");
            controller.CustomerQueue.Tick(1000, CustomerQueue.LeaveDurationSeconds + .01, false);
            screen.RefreshForCapture(true);
            Check(controller.CustomerQueue.CustomerAtSlot(0)?.Id != customer.Id
                && controller.CustomerQueue.CustomerAtSlot(0) is not null && slot.Visible && slot.Modulate.A < .999f,
                "a replacement customer still receives an entrance fade");
            Check(screen.FindChildren("CustomerSlot*", "", true, false).OfType<Control>()
                .Select(view => view.GlobalPosition).SequenceEqual(slotPositions),
                "delivery and replacement preserve all five counter positions");
            await Wait(.30);
            Check(slot.Modulate.A > .999f, "replacement customer becomes fully visible");
            await Wait(.75); // Let the completed order's celebration leave the equipment comparison.
            MovePointer(TianjinWorkbenchLayout.EmbeddedSurface.GetCenter());
            Check(_viewport.GetMousePosition().DistanceTo(TianjinWorkbenchLayout.EmbeddedSurface.GetCenter()) < 2,
                "equipment capture moves the viewport pointer onto the stove");
            await Shot("tianjin-stove-contour");
            MovePointer(TianjinWorkbenchLayout.EmbeddedIngredient(StableIds.Ingredients.Batter).GetCenter());
            await Shot("tianjin-bowl-contour");
            MovePointer(TianjinWorkbenchLayout.EmbeddedSoyTray.GetCenter());
            await Shot("tianjin-soy-contour");

            _viewport.QueueFree(); controller.QueueFree(); save.QueueFree();
            await Frames();
            GD.Print($"INTERACTION_HIGHLIGHT_TEST_RESULT passed={_passed} failed=0");
            GetTree().Quit();
        }
        catch (Exception error)
        {
            GD.PushError(error.ToString());
            GD.Print($"INTERACTION_HIGHLIGHT_TEST_RESULT passed={_passed} failed=1");
            GetTree().Quit(1);
        }
        finally
        {
            ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
            string absolute = ProjectSettings.GlobalizePath(savePath);
            if (File.Exists(absolute)) File.Delete(absolute);
        }
    }

    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++;
        GD.Print("PASS " + message);
    }

    private static void BeginYoutiaoDrag(DragItem source)
    {
        using var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true,
            Position = source.Size * .5f };
        source._GuiInput(press);
    }

    private void MoveDrag(DragService drag, Vector2 point)
    {
        MovePointer(point);
        using var motion = new InputEventMouseMotion { Position = point, GlobalPosition = point };
        drag._Input(motion);
    }

    private void MovePointer(Vector2 point)
    {
        using var motion = new InputEventMouseMotion { Position = point, GlobalPosition = point };
        _viewport.PushInput(motion, true);
    }

    private async Task Frames()
    {
        for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task Wait(double seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);

    private async Task Shot(string name)
    {
        if (!Capture) return;
        await Frames();
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string directory = ProjectSettings.GlobalizePath("res://.tmp/interaction-highlights");
        Directory.CreateDirectory(directory);
        Error saved = _viewport.GetTexture().GetImage().SavePng(Path.Combine(directory, $"{name}-{CaptureWidth}.png"));
        Check(saved == Error.Ok, "saved " + name);
    }
}
