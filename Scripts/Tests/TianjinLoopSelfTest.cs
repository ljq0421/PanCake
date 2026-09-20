using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TianjinLoopSelfTest : Node
{
    private int _checks;
    private PancakeWorkstation _station = null!;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private const string Output = "res://artifacts/tianjin-loop";
    public override void _Process(double delta) { if (_station is not null) _station.Tick(delta); }
    private void Check(bool ok, string message)
    {
        if (!ok) throw new Exception(message);
        _checks++; GD.Print("LOOP_PASS " + message);
    }
    private async Task Wait(double time) => await ToSignal(GetTree().CreateTimer(time), SceneTreeTimer.SignalName.Timeout);
    private async Task Shot(string name)
    {
        if (!Capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage(); image.SavePng($"{Output}/{name}.png");
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests($"{Output}/settings.cfg"); InterfaceLessons.MarkAllSeen(settings);
            if (Capture) GetWindow().Position = new(-10000, -10000);
            GetWindow().Size = new(1920, 1080);
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests($"{Output}/save.json"); AddChild(save);
            save.Data.PurchasedStoveLevel = save.Data.PurchasedIngredientStationLevel = save.Data.PurchasedFryerLevel = 3;
            var controller = new DayController(); AddChild(controller);
            var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
            AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller); screen.Initialize(catalog, save, controller, 15);
            foreach (var planned in controller.CurrentPlan!.Customers.Take(5))
                planned.Order = new OrderData { OrderId = planned.Order.OrderId, CustomerTypeId = planned.CustomerTypeId,
                    Lines = new[] { new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Crispy, 1), new OrderLineData(ProductKind.SoyMilk, "soy_milk", 1) }, BasePrice = 10 };
            screen.BeginDay(); controller.Tick(3.1); controller.CustomerQueue!.Tick(1000, .4, true);
            screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
            _station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
            var drag = _station.Descendants<DragService>().Single();
            var stove = (DropZone)_station.FindChild("PancakeDropZone", true, false);
            var bagArt = (TextureRect)_station.FindChild("FinishedPancakeArt", true, false);
            var finished = _station.Descendants<DragItem>().First(i => i.PayloadId == "finished_pancake");
            await Wait(.1);
            Check(drag.ImmediateAcceptance, "Tianjin opts into immediate acceptance");
            Check(stove.FixedHitRect.HasValue, "stove hover never changes its logical target bounds");
            Check(stove.TryAccept("batter"), "place batter through real target");
            _station.CancelInput();
            _station.Machine.TryExecute(PancakeCommand.BeginSpread); _station.Machine.SetSpreadCoverage(1);
            _station.Descendants<StrokeInteractor>().Single().StrokeCompleted?.Invoke(StrokeMode.Spread);
            ((Button)_station.FindChild("IngredientInput_egg", true, false)).EmitSignal(Button.SignalName.Pressed);
            Check(_station.Machine.Runtime.HasEgg, "egg commits before visual contact");
            await Wait(.06); await Shot("egg-flight"); await Wait(.2);
            _station.Machine.Runtime.State = PancakeState.SideAReady; _station.RefreshForCapture();
            Check(_station.TryInvokeProductionShortcut(Key.F), "flip accepts input"); await Wait(.4);
            _station.Machine.Runtime.State = PancakeState.SideBReady; _station.RefreshForCapture();
            ((Button)_station.FindChild("IngredientInput_sauce", true, false)).EmitSignal(Button.SignalName.Pressed);
            _station.Machine.SetSauceCoverage(1); Check(_station.TryInvokeProductionShortcut(Key.F), "finish sauce");
            var crispy = _station.Descendants<DragItem>().First(i => i.PayloadId == "crispy");
            int stock = _station.Inventory.GetQuantity("crispy");
            crispy.TryBeginDrag();
            drag._Input(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = new Vector2(4, 1050) });
            await Wait(.22);
            Check(!drag.IsDragging && _station.Inventory.GetQuantity("crispy") == stock, "missed drop returns without consuming stock");
            crispy.TryBeginDrag();
            drag._Input(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = stove.GetGlobalRect().GetCenter() });
            Check(!drag.IsDragging && _station.Inventory.GetQuantity("crispy") == stock - 1, "release consumes once and immediately frees drag input");
            Check(_station.Machine.Runtime.ExtraIngredients.Contains("crispy"), "topping is committed before snap completes");
            await Wait(.12); await Shot("crispy-contact"); await Wait(.25);
            Check(_station.TryInvokeProductionShortcut(Key.F), "fold");
            Check(_station.TryInvokeProductionShortcut(Key.F), "bag");
            Check(_station.CanDeliverProduct("finished_pancake"), "bag is deliverable during rebound");
            Rect2 hit = finished.GetGlobalRect();
            await Wait(.06); await Shot("bag-compress");
            Check(bagArt.Scale.X > 1 && bagArt.Scale.Y < 1 && finished.GetGlobalRect() == hit, "bag deforms with stable hit area");
            await Wait(.08); await Shot("bag-rebound"); await Wait(.2);
            Check(bagArt.Scale.IsEqualApprox(Vector2.One), "bag returns to rest");
            var customer = controller.CustomerQueue.Slots.First();
            var zone = (DropZone)screen.FindChild($"CustomerDropZone{customer.SlotIndex + 1}", true, false);
            int income = controller.Ledger!.Build().TotalRevenue;
            finished.TryBeginDrag();
            drag._Input(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = zone.GetGlobalRect().GetCenter() });
            Check(!drag.IsDragging && customer.Progress.GetDeliveredQuantity(0) == 1, "real partial delivery commits at release");
            Check(controller.Ledger.Build().TotalRevenue == income, "partial delivery does not collect prematurely");
            await Wait(.06); await Shot("partial-delivery");
            var soy = _station.Descendants<DragItem>().First(i => i.PayloadId == "soy_milk_cup");
            soy.TryBeginDrag();
            drag._Input(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = zone.GetGlobalRect().GetCenter() });
            Check(controller.Ledger.Build().TotalRevenue > income && !drag.IsDragging, "complete order collects once before flights finish");
            await Wait(.06); await Shot("payment");
            int paid = controller.Ledger.Build().TotalRevenue;
            screen.OpenBusinessDetails(); await Wait(.1);
            Check(screen.PaymentCoins.Count == 0 && bagArt.Scale.IsEqualApprox(Vector2.One), "details stop all visual tails");
            screen.CloseBusinessDetails(); await Wait(.4);
            Check(controller.Ledger.Build().TotalRevenue == paid, "resume never repeats payment");
            _station.Machine.Runtime.State = PancakeState.Folded; _station.RefreshForCapture();
            Check(_station.TryInvokeProductionShortcut(Key.F), "second bag");
            finished.TryBeginDrag();
            Check(drag.IsDragging && bagArt.Scale.IsEqualApprox(Vector2.One), "pickup interrupts bag rebound immediately");
            drag.CancelDrag();
            Check(_station.CanDeliverProduct("finished_pancake"), "cancel pickup preserves prepared food");
            _station.GetNode<TianjinLoopMotion>("TianjinLoopMotion").Land(bagArt);
            await Wait(.04); ProjectSettings.SetSetting("accessibility/reduce_motion", true); await Wait(.05);
            Check(bagArt.Scale.IsEqualApprox(Vector2.One) && _station.CanDeliverProduct("finished_pancake"), "live reduced-motion switch resets bag without changing readiness");
            screen._Notification((int)NotificationApplicationFocusOut); await Wait(.1);
            Check(bagArt.Scale.IsEqualApprox(Vector2.One), "focus loss leaves no residual deformation");
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            // Shared service defaults remain deferred for every non-opted-in caller.
            var host = new Control { Size = new(1920, 1080) }; AddChild(host);
            var legacy = new DragService(); host.AddChild(legacy); legacy.Configure(host);
            var source = new Control { Size = new(50, 50) }; host.AddChild(source);
            var target = new DropZone { Position = new(100, 100), Size = new(80, 80) }; host.AddChild(target);
            int accepted = 0;
            target.Configure(_ => true, _ => accepted++); legacy.RegisterZone(target);
            legacy.BeginDrag(source, "fixture", "fixture", Colors.White);
            legacy._Input(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = new(140, 140) });
            Check(accepted == 0 && legacy.IsDragging, "shared default retains pre-existing delayed acceptance");
            legacy.CancelDrag(); await Wait(.2);
            Check(accepted == 0, "cancelled legacy tween cannot commit");
            legacy.ImmediateAcceptance = true;
            target.ConfigureResult(_ => true, _ => false);
            legacy.BeginDrag(source, "fixture", "fixture", Colors.White);
            legacy._Input(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = new(140, 140) });
            await Wait(.22);
            Check(!legacy.IsDragging && accepted == 0, "failed commit returns instead of accepting presentation");
            GD.Print($"TIANJIN_LOOP_TEST: {_checks} passed, 0 failed"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
