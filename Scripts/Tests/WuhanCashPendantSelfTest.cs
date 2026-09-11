using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class CoinCollectionSelfTest
{
    private async Task TestWuhanCashPendant(WuhanDayScreen screen, DayController controller, SaveService save,
        DataCatalog catalog, int width, bool reduced)
    {
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
            if (day < 4) save.Data.Wuhan.EquipmentLevels.Remove("doupi_griddle");
            else save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
            screen.Initialize(catalog, save, controller, day);
            screen.BeginDay(); controller.Tick(3.1);
            screen._Notification((int)NotificationApplicationFocusIn);
        }
        foreach (int day in new[] { 1, 8 })
        {
            Init(day);
            controller.CustomerQueue!.Tick(1000, .4, true);
            screen.RefreshForCapture(); await Frames();
            Check(controller.CustomerQueue.Slots.Count == 5, "Wuhan retains five occupied customer slots");
            Check(screen.GetNode<TextureRect>("WorkbenchBackground").Texture.ResourcePath.EndsWith(day == 1 ? "武汉-热干面.png" : "武汉-热干面-豆皮.png"), "Wuhan new background matches unlock stage");
            Check(!screen.CoinTray.IsVisibleInTree() && !screen.CoinTray.TryCollect(), "Wuhan old collection control is hidden and inert");
            var bubbles = screen.FindChildren("*", "", true, false).OfType<OrderBubbleView>().Where(b => b.IsVisibleInTree()).ToArray();
            Check(bubbles.Length == 5 && bubbles.All(b => !b.GetGlobalRect().Intersects(screen.CashPendant.GetGlobalRect())), "Wuhan five bubbles leave pendant unobscured");
            Check(bubbles.SelectMany((a, i) => bubbles.Skip(i + 1).Select(b => !a.GetGlobalRect().Intersects(b.GetGlobalRect()))).All(v => v), "Wuhan order bubbles do not overlap");
            if (Capture && !reduced) await Shot($"wuhan-pendant-{width}-day{day}-five-customers");
            screen.Cooker.TryStart(0); screen._Process(.15);
            double cooked = screen.Cooker.Baskets[0].CookSeconds;
            float motion = screen.Workstation.MotionProgress("basket0");
            Click(screen.CashPendant); await Frames();
            Check(screen.BusinessDetails.Visible && controller.IsPaused, "Wuhan real pendant click opens and pauses business");
            if (Capture && !reduced && day == 1) await Shot($"wuhan-pendant-{width}-empty");
            double time = controller.DayElapsedSeconds;
            var patience = controller.CustomerQueue.Slots.Select(c => c.WaitSeconds).ToArray();
            screen._Process(5);
            Check(screen.Cooker.Baskets[0].CookSeconds == cooked && screen.Workstation.MotionProgress("basket0") == motion,
                "Wuhan modal freezes cooking and production animation");
            Check(controller.DayElapsedSeconds == time && controller.CustomerQueue.Slots.Select((c, i) => c.WaitSeconds == patience[i]).All(v => v), "Wuhan modal freezes clock and patience");
            Click(screen.CashPendant);
            Check(screen.BusinessDetails.Visible, "Wuhan modal absorbs background clicks");
            for (int i = 0; i < 5; i++)
            {
                KeyPress(Key.Tab);
                Check(screen.BusinessDetails.IsAncestorOf(GetViewport().GuiGetFocusOwner()), "Wuhan modal contains keyboard focus");
            }
            KeyPress(Key.Escape); await Frames();
            Check(!screen.BusinessDetails.Visible && !controller.IsPaused, "Wuhan Esc resumes business");
            Click(screen.CashPendant); screen._Notification((int)NotificationApplicationFocusOut);
            screen.CloseBusinessDetails();
            Check(controller.IsPaused, "Wuhan closing details preserves focus pause");
            screen._Notification((int)NotificationApplicationFocusIn);
            screen.OpenBusinessDetails(); controller.IsPaused = true; screen.CloseBusinessDetails();
            Check(controller.IsPaused, "Wuhan closing details preserves independent pause");
            controller.IsPaused = false;
        }
        Init(8);
        screen.DeliveryDrag.BeginDrag(screen.Workstation, "wuhan:HotDryNoodles", "热干面", Colors.White);
        screen._Process(.00001); Click(screen.CashPendant); screen.OpenBusinessDetails();
        Check(!screen.BusinessDetails.Visible, "Wuhan dragging cannot open details");
        screen.Workstation.CancelInput();
        foreach (var planned in controller.CurrentPlan!.Customers)
            planned.Order = new OrderData { OrderId = planned.Order.OrderId, CityId = StableIds.Cities.Wuhan,
                CustomerTypeId = planned.CustomerTypeId, BasePrice = 20, PatienceSeconds = 100,
                Lines = new[] { new OrderLineData(ProductKind.HotDryNoodles, StableIds.Recipes.HotDryNoodlesClassic, 1),
                    new OrderLineData(ProductKind.Doupi, StableIds.Products.Doupi, 2) } };
        controller.CustomerQueue!.Tick(1000, .4, true); screen.RefreshForCapture();
        foreach (var customer in controller.CustomerQueue.Slots.Take(3).ToArray())
        {
            int records = controller.BusinessRecords.Count;
            int coins = screen.PaymentCoins.Count;
            int incomeBefore = controller.Ledger!.Build().TotalRevenue;
            screen.Bowl.Reset(); screen.Bowl.TryAddNoodles(records == 0 ? NoodleQuality.Optimal : NoodleQuality.Overcooked);
            screen.Bowl.TryAddBaseSeasoning();
            if (records == 2) screen.Bowl.TryAddTopping(StableIds.Ingredients.WuhanScallion);
            screen.Bowl.AddMixDistance(1000);
            screen.Workstation.CancelAnimations(); screen.RefreshForCapture();
            Check(screen.DeliverToCustomer(customer.Id, ProductKind.HotDryNoodles), "Wuhan accepts noodle portion");
            Check(controller.BusinessRecords.Count == records && screen.PaymentCoins.Count == coins && controller.Ledger.Build().TotalRevenue == incomeBefore, "Wuhan partial delivery produces no record, income or flight");
            screen.DoupiStock.TryAddBatch(8); screen.Workstation.CancelAnimations(); screen.RefreshForCapture();
            Check(screen.DeliverToCustomer(customer.Id, ProductKind.Doupi), "Wuhan final doupi delivery completes order");
            Check(controller.BusinessRecords.Count == records + 1 && controller.BusinessRecords.Last().Lines.Count == 2, "Wuhan captures actual multi-item order once");
            Check(!screen.DeliverToCustomer(customer.Id, ProductKind.Doupi) && controller.BusinessRecords.Count == records + 1, "Wuhan duplicate delivery cannot duplicate outcome");
        }
        Check(controller.BusinessRecords[0].Evaluation!.Grade == DeliveryGrade.Perfect
            && controller.BusinessRecords[1].Evaluation!.Grade == DeliveryGrade.Correct
            && controller.BusinessRecords[2].Evaluation!.Grade == DeliveryGrade.Incorrect, "Wuhan preserves Perfect, correct and incorrect grades");
        int income = controller.Ledger!.Build().TotalRevenue;
        Check(controller.BusinessRecords.Sum(r => r.Evaluation?.TotalRevenue ?? 0) == income, "Wuhan record income matches ledger");
        Check(reduced ? screen.PaymentCoins.Count == 0 : screen.PaymentCoins.Count > 0, "Wuhan payment respects reduced motion");
        screen.OpenBusinessDetails();
        var positions = screen.PaymentCoins.ToDictionary(c => c, c => c.Position);
        await ToSignal(GetTree().CreateTimer(.15), SceneTreeTimer.SignalName.Timeout);
        Check(positions.All(p => p.Key.Position == p.Value), "Wuhan details freeze in-flight payments");
        screen.CloseBusinessDetails();
        await ToSignal(GetTree().CreateTimer(.5), SceneTreeTimer.SignalName.Timeout);
        if (Capture && !reduced) await Shot($"wuhan-pendant-{width}-payment");
        await ToSignal(GetTree().CreateTimer(.5), SceneTreeTimer.SignalName.Timeout);
        Check(screen.PaymentCoins.Count == 0, "Wuhan flight completes and cleans up");
        for (int i = 0; i < 20; i++)
        {
            foreach (var customer in controller.CustomerQueue.Slots.Where(c => !c.WasServed)) customer.WaitSeconds = customer.LeaveAtSeconds;
            controller.CustomerQueue.Tick(1000, .5, true);
        }
        Check(controller.BusinessRecords.Count(r => r.Lost) == controller.Ledger.LostCustomers && controller.Ledger.LostCustomers > 0, "Wuhan lost customers have individual records");
        Check(controller.Ledger.Build().Satisfaction == controller.BusinessRecords.Where(r => !r.Lost).Average(r => r.Evaluation!.SatisfactionScore), "Wuhan lost customers excluded from satisfaction");
        screen.RefreshForCapture(); Click(screen.CashPendant); await Frames();
        Check(screen.BusinessDetails.Visible && controller.Ledger.Build().TotalRevenue == income && save.Data.Coins == 0, "Wuhan details never settle money twice");
        var scroll = screen.BusinessDetails.FindChildren("*", "ScrollContainer", true, false).OfType<ScrollContainer>().Single();
        Check(scroll.GetVScrollBar().MaxValue > scroll.Size.Y, "Wuhan long record list is scrollable");
        if (Capture && !reduced) await Shot($"wuhan-pendant-{width}-records");
        scroll.ScrollVertical = 10000; await Frames();
        if (Capture && !reduced) await Shot($"wuhan-pendant-{width}-records-bottom");
        Click(screen.BusinessDetails.CloseButton); await Frames();
        Check(!controller.IsPaused && !screen.BusinessDetails.Visible, "Wuhan close button resumes business");
        screen.OpenBusinessDetails(); screen.Hide();
        Check(!screen.BusinessDetails.Visible && screen.PaymentCoins.Count == 0, "Wuhan hiding clears modal and coins");
        screen.Show(); Init(8);
        Check(controller.BusinessRecords.Count == 0 && controller.Ledger!.Build().TotalRevenue == 0, "Wuhan restart clears session");
        controller.AbandonDay();
        Check(controller.BusinessRecords.Count == 0, "Wuhan abandonment clears records");
    }
}
