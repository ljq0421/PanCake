using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Fryer;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class CoinCollectionSelfTest
{
    private async Task TestCashPendant(TianjinDayScreen screen, DayController controller, SaveService save,
        DataCatalog catalog, int width, bool reduced)
    {
        var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        void Click(Control control)
        {
            Vector2 p = control.GetGlobalTransformWithCanvas() * (control.Size * .5f);
            GetViewport().PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
            foreach (bool pressed in new[] { true, false })
                GetViewport().PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = pressed }, true);
        }
        void KeyPress(Key key) => GetViewport().PushInput(new InputEventKey { Keycode = key, Pressed = true }, true);
        void Init(int day)
        {
            screen.Initialize(catalog, save, controller, day); screen.BeginDay(); controller.Tick(3.1);
            screen._Notification((int)NotificationApplicationFocusIn);
        }
        foreach (int day in new[] { 1, 5, 9 })
        {
            Init(day);
            // Admit all five slots without advancing patience or the day clock.
            controller.CustomerQueue!.Tick(1000, .4, true);
            screen.RefreshForCapture(true); await Frames();
            Check(controller.CustomerQueue.Slots.Count == 5, "pendant preserves five physical customer slots");
            string suffix = day == 1 ? "天津-煎饼.png" : day == 5 ? "天津-煎饼-炸锅.png" : "天津-煎饼-炸锅-豆浆.png";
            Check(screen.GetNode<TextureRect>("ShopBackground").Texture.ResourcePath.EndsWith(suffix), "correct new stage background: " + day);
            Check(!station.CoinTray!.IsVisibleInTree() && !station.CoinTray.TryCollect(), "old Tianjin collection control stays hidden and inert");
            Check(screen.FindChildren("OrderBubble", "", true, false).OfType<OrderBubbleView>()
                .All(b => !b.GetGlobalRect().Intersects(screen.CashPendant.GetGlobalRect())), "five customer bubbles leave the pendant unobscured");
            if (Capture && !reduced) await Shot($"tianjin-pendant-{width}-day{day}-five-customers");
            Click(screen.CashPendant); await Frames();
            Check(screen.BusinessDetails.Visible && controller.IsPaused && station.Paused, "real pendant click opens modal and pauses production");
            if (Capture && !reduced && day == 1) await Shot($"tianjin-pendant-{width}-empty");
            double time = controller.DayElapsedSeconds;
            double[] patience = controller.CustomerQueue.Slots.Select(c => c.WaitSeconds).ToArray();
            screen._Process(5);
            Check(controller.DayElapsedSeconds == time && controller.CustomerQueue.Slots.Select((c, i) => c.WaitSeconds == patience[i]).All(x => x), "detail view freezes clock and customer patience");
            Click(screen.CashPendant); Check(screen.BusinessDetails.Visible, "modal blocks background clicks");
            KeyPress(Key.F); KeyPress(Key.G);
            for (int i = 0; i < 8; i++)
            {
                KeyPress(Key.Tab);
                Check(screen.BusinessDetails.IsAncestorOf(GetViewport().GuiGetFocusOwner()), "Tab remains in business modal");
            }
            KeyPress(Key.Escape); await Frames();
            Check(!screen.BusinessDetails.Visible && !controller.IsPaused, "Esc closes and resumes business");
            Click(screen.CashPendant); screen._Notification((int)NotificationApplicationFocusOut);
            screen.CloseBusinessDetails();
            Check(controller.IsPaused && station.Paused, "closing details cannot override focus pause");
            screen._Notification((int)NotificationApplicationFocusIn);
        }

        Init(11);
        var drag = station.FindChildren("*", "", true, false).OfType<DragService>().Single();
        drag.BeginDrag(station, "soy_milk_cup", "豆浆", Colors.White);
        screen._Process(.00001);
        Click(screen.CashPendant);
        screen.OpenBusinessDetails();
        Check(!screen.BusinessDetails.Visible, "dragging over the pendant cannot open details");
        station.CancelInput();
        await Frames();
        screen._Process(.00001);
        screen.OpenBusinessDetails();
        screen.FindButton("暂停").EmitSignal(Button.SignalName.Pressed);
        screen.CloseBusinessDetails();
        Check(controller.IsPaused && station.Paused, "closing details preserves an independent manual pause");
        screen.FindButton("继续营业").EmitSignal(Button.SignalName.Pressed);
        Init(11);
        foreach (PlannedCustomer planned in controller.CurrentPlan!.Customers)
            planned.Order = new OrderData { OrderId = planned.Order.OrderId, CustomerTypeId = planned.CustomerTypeId,
                Lines = new[] { new OrderLineData(ProductKind.Youtiao, StableIds.Products.Youtiao, 2),
                    new OrderLineData(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1) }, BasePrice = 7 };
        controller.CurrentPlan.Customers[2].Order = new OrderData { OrderId = "wrong-pancake", CustomerTypeId = controller.CurrentPlan.Customers[2].CustomerTypeId,
            Lines = new[] { new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Crispy, 1) }, BasePrice = 10 };
        controller.CustomerQueue!.Tick(1000, .4, true);
        screen.RefreshForCapture(true); await Frames();
        Check(controller.BusinessRecords.Count == 0, "new business has no outcome snapshots");
        foreach (CustomerRuntime customer in controller.CustomerQueue.Slots.Take(2).ToArray())
        {
            var zone = (DropZone)screen.FindChild($"CustomerDropZone{customer.SlotIndex + 1}", true, false);
            int count = controller.BusinessRecords.Count;
            Check(!zone.TryAccept("invalid_product") && controller.BusinessRecords.Count == count, "rejected delivery creates no record");
            for (int i = 0; i < 2; i++)
            {
                station.FryerMachine!.Inventory.TryStore(1, count == 0 ? YoutiaoQuality.Golden : YoutiaoQuality.Light);
                Check(zone.TryAccept("stored_youtiao"), "partial order accepts youtiao");
                Check(controller.BusinessRecords.Count == count, "partial delivery creates no completed record");
            }
            station.SoyMilkTray!.Tick(.3);
            Check(zone.TryAccept("soy_milk_cup"), "final item completes order");
            Check(controller.BusinessRecords.Count == count + 1, "completion creates exactly one snapshot");
            BusinessOrderRecord record = controller.BusinessRecords.Last();
            Check(record.OrderId == customer.Order.OrderId && record.Lines.Count == 2 && record.Evaluation!.CompletesOrder,
                "snapshot captures actual customer, order lines and evaluation");
            Check(!zone.TryAccept("soy_milk_cup") && controller.BusinessRecords.Count == count + 1, "duplicate delivery cannot duplicate records");
            screen.RefreshForCapture(true);
        }
        var third = controller.CustomerQueue.Slots[2];
        var wrong = new PreparedPancake(PancakeQuality.Perfect, new HashSet<string> { "invalid-test-ingredient" });
        Check(controller.TryDeliverPreparedPancakeTo(third.Id, wrong, catalog, () => true).Grade == DeliveryGrade.Incorrect,
            "wrong recipe completes with real incorrect evaluation");
        Check(controller.BusinessRecords[0].Evaluation!.Grade == DeliveryGrade.Perfect
            && controller.BusinessRecords[1].Evaluation!.Grade == DeliveryGrade.Correct
            && controller.BusinessRecords[2].Evaluation!.Grade == DeliveryGrade.Incorrect, "records preserve all three completed grades");
        int income = controller.Ledger!.Build().TotalRevenue;
        Check(controller.BusinessRecords.Sum(r => r.Evaluation?.TotalRevenue ?? 0) == income, "snapshot income matches authoritative ledger");
        Check(reduced ? screen.PaymentCoins.Count == 0 : screen.PaymentCoins.Count > 0, "payment flight respects reduced motion");
        screen.OpenBusinessDetails();
        var positions = screen.PaymentCoins.ToDictionary(c => c, c => c.Position);
        await ToSignal(GetTree().CreateTimer(.15), SceneTreeTimer.SignalName.Timeout);
        Check(positions.All(p => p.Key.Position == p.Value), "detail modal pauses in-flight payments");
        screen.CloseBusinessDetails();
        foreach (var customer in controller.CustomerQueue.Slots.Where(c => !c.WasServed)) customer.WaitSeconds = customer.LeaveAtSeconds;
        controller.CustomerQueue.Tick(1000, .1, false);
        Check(controller.BusinessRecords.Count(r => r.Lost) == controller.Ledger.LostCustomers && controller.Ledger.LostCustomers == 2,
            "lost customers produce individual records");
        Check(controller.Ledger.Build().Satisfaction == controller.BusinessRecords.Where(r => !r.Lost).Average(r => r.Evaluation!.SatisfactionScore),
            "lost records do not enter satisfaction average");
        // Finish the rest of the queue as lost to exercise a full scrollable session.
        for (int i = 0; i < 20; i++)
        {
            controller.CustomerQueue.Tick(1000, .5, true);
            foreach (var customer in controller.CustomerQueue.Slots.Where(c => !c.WasServed)) customer.WaitSeconds = customer.LeaveAtSeconds;
        }
        screen.RefreshForCapture(true); await Frames();
        Click(screen.CashPendant); await Frames();
        Check(screen.BusinessDetails.Visible && controller.Ledger.Build().TotalRevenue == income && save.Data.Coins == 0,
            "opening detailed records never changes session or permanent money");
        var scroll = screen.BusinessDetails.FindChildren("*", "ScrollContainer", true, false).OfType<ScrollContainer>().Single();
        Check(scroll.GetVScrollBar().MaxValue > scroll.Size.Y, "all session records are reachable by scrolling");
        if (Capture && !reduced) await Shot($"tianjin-pendant-{width}-records");
        scroll.ScrollVertical = 10000; await Frames();
        if (Capture && !reduced) await Shot($"tianjin-pendant-{width}-records-bottom");
        Click(screen.BusinessDetails.CloseButton); await Frames();
        Check(!screen.BusinessDetails.Visible && !controller.IsPaused, "real close button resumes business");
        screen.OpenBusinessDetails(); screen.Hide();
        Check(!screen.BusinessDetails.Visible && screen.PaymentCoins.Count == 0, "hiding clears modal and flight nodes");
        screen.Show(); Init(11);
        Check(controller.BusinessRecords.Count == 0 && controller.Ledger!.Build().TotalRevenue == 0 && !screen.BusinessDetails.Visible,
            "restart clears records and income without modifying save format");
    }
}
