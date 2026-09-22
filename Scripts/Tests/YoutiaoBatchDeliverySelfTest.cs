using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Inventory;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class YoutiaoBatchDeliverySelfTest : Node
{
    private static void Check(bool ok, string message)
    {
        if (!ok) throw new InvalidOperationException(message);
        GD.Print("PASS " + message);
    }

    public override void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (var (stock, preDelivered, combo) in new[] { (2, 0, false), (1, 0, false), (4, 0, false), (4, 1, false), (2, 0, true), (2, 2, true), (0, 0, false) })
            {
                RunCase(catalog, stock, preDelivered, combo);
                RunSideCase(catalog, stock, preDelivered, combo, false);
                RunSideCase(catalog, stock, preDelivered, combo, true);
            }
            var tray = new SoyMilkTrayRuntime(4);
            Check(!tray.TryConsumeForDelivery(0) && !tray.TryConsumeForDelivery(5) && tray.Quantity == 4, "invalid cup batch preserves stock");
            Check(tray.TryConsumeForDelivery(2) && tray.Quantity == 2 && tray.IsTaking, "cup batch starts one take animation");
            Check(!tray.TryConsumeForDelivery() && !tray.TryBeginRefill(), "take animation blocks further actions");
            tray.Tick(SoyMilkTrayRuntime.TakeSeconds);
            Check(tray.TryBeginRefill() && !tray.TryConsumeForDelivery(2), "refill blocks delivery");
            tray.Tick(SoyMilkTrayRuntime.RefillSeconds);
            Check(tray.Quantity == 4 && tray.CanStartDrag, "refill restores available stock");
            GD.Print($"YOUTIAO_BATCH_DELIVERY_OK demo={ExperienceProfile.IsDemo}");
            GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }

    private void RunSideCase(DataCatalog catalog, int stock, int preDelivered, bool combo, bool doupi)
    {
        var controller = new DayController(); AddChild(controller);
        string city = doupi ? StableIds.Cities.Wuhan : StableIds.Cities.Tianjin;
        ProductKind kind = doupi ? ProductKind.Doupi : ProductKind.SoyMilk;
        string product = doupi ? StableIds.Products.Doupi : StableIds.Products.SoyMilk;
        Check(controller.TryPrepareDay(city, 1, catalog, out _), $"prepare {kind}");
        controller.CustomerQueue!.ResolveBeforeArrival = (planned, _) => new OrderData
        {
            OrderId = planned.Order.OrderId, CustomerTypeId = planned.CustomerTypeId, CityId = city, BasePrice = 10,
            Lines = combo ? new[] { new OrderLineData(kind, product, 2), new OrderLineData(doupi ? ProductKind.HotDryNoodles : ProductKind.Youtiao,
                doupi ? StableIds.Recipes.HotDryNoodlesClassic : StableIds.Products.Youtiao, 1) } : new[] { new OrderLineData(kind, product, 2) }
        };
        controller.TryStartDay(out _); controller.Tick(DayController.OpeningDurationSeconds);
        for (int i = 0; i < 1000 && !controller.CustomerQueue.Slots.Any(c => c.State == CustomerState.Happy); i++) controller.Tick(.1);
        var customer = controller.CustomerQueue.Slots.First(c => c.State == CustomerState.Happy);
        for (int i = 0; i < preDelivered; i++) customer.Progress.TryAccept(new DeliveredItem(kind, product));
        var tray = new SoyMilkTrayRuntime(Math.Max(1, stock));
        if (stock == 0) { tray.TryConsumeForDelivery(); tray.Tick(SoyMilkTrayRuntime.TakeSeconds); }
        var inventory = new DoupiInventory();
        for (int i = 0; i < stock; i++) inventory.TryAddBatch(1, i == 0 ? DoupiQuality.Overbrowned : DoupiQuality.Normal);
        int Stock() => doupi ? inventory.Count : tray.Quantity;
        DeliveryEvaluation Deliver(string id) => doupi ? controller.TryDeliverWuhanDoupiTo(id, inventory) : controller.TryDeliverSoyMilkTo(id, tray);
        customer.WaitSeconds = customer.LeaveAtSeconds * .7; customer.Tick(0);
        int callbacks = 0, receipts = 0;
        var cues = new List<BusinessCue>();
        controller.DeliveryCompleted += _ => callbacks++;
        controller.ItemDelivered += _ => receipts++;
        controller.Feedback.Requested += e => cues.Add(e.Cue);
        controller.IsPaused = true;
        Check(!Deliver(customer.Id).ItemAccepted && Stock() == stock, $"{kind} paused stock unchanged");
        controller.IsPaused = false;
        Check(!Deliver("missing").ItemAccepted && Stock() == stock, $"{kind} invalid target stock unchanged");
        cues.Clear();
        int expected = Math.Min(stock, 2 - preDelivered);
        var result = Deliver(customer.Id);
        bool complete = expected > 0 && expected + preDelivered == 2 && !combo;
        Check(Stock() == stock - expected && customer.Progress.GetDeliveredQuantity(0) == preDelivered + expected, $"{kind} consumes only remaining demand or available stock");
        Check(callbacks == (expected > 0 ? 1 : 0) && receipts == expected, $"{kind} one batch callback and per-piece receipts");
        Check(Math.Abs(customer.WaitSeconds / customer.LeaveAtSeconds - (.7 - .15 * expected)) < .00001, $"{kind} per-piece patience recovery");
        Check(result.CompletesOrder == complete && controller.Ledger!.Build().CompletedCustomers == (complete ? 1 : 0), $"{kind} one settlement only for complete order");
        Check(cues.Count(c => c is BusinessCue.ItemAccepted or BusinessCue.OrderCompleted or BusinessCue.DeliveryError) == 1
            && cues.Contains(expected == 0 ? BusinessCue.DeliveryError : complete ? BusinessCue.OrderCompleted : BusinessCue.ItemAccepted), $"{kind} one matching cue per drag");
        if (!doupi) Check(tray.IsTaking == (expected > 0), "soy take animation starts only on acceptance");
        if (doupi && expected > 0) Check(customer.Progress.DeliveredItems[preDelivered].WuhanQuality == WuhanFoodQuality.DoupiOverbrowned
            && customer.Progress.DeliveredItems.Skip(preDelivered + 1).All(i => i.WuhanQuality == WuhanFoodQuality.None), "doupi FIFO quality preserved");
        if (complete) Check(controller.Ledger!.Build().TotalRevenue == result.TotalRevenue, $"{kind} revenue matches settlement");
        if (expected + preDelivered == 2)
        {
            tray.Tick(SoyMilkTrayRuntime.TakeSeconds);
            Check(!Deliver(customer.Id).ItemAccepted && Stock() == stock - expected, $"{kind} duplicate delivery preserves stock");
        }
        controller.Free();
    }

    private void RunCase(DataCatalog catalog, int stock, int preDelivered, bool combo)
    {
        var controller = new DayController();
        AddChild(controller);
        Check(controller.TryPrepareDay(5, catalog, out _), "prepare current profile");
        controller.CustomerQueue!.ResolveBeforeArrival = (planned, _) => new OrderData
        {
            OrderId = planned.Order.OrderId, CustomerTypeId = planned.CustomerTypeId, BasePrice = 10,
            Lines = combo
                ? new[] { new OrderLineData(ProductKind.Youtiao, StableIds.Products.Youtiao, 2), new OrderLineData(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1) }
                : new[] { new OrderLineData(ProductKind.Youtiao, StableIds.Products.Youtiao, 2) }
        };
        controller.TryStartDay(out _);
        controller.Tick(DayController.OpeningDurationSeconds);
        for (int i = 0; i < 1000 && !controller.CustomerQueue.Slots.Any(c => c.State == CustomerState.Happy); i++) controller.Tick(.1);
        var customer = controller.CustomerQueue.Slots.First(c => c.State == CustomerState.Happy);
        for (int i = 0; i < preDelivered; i++) customer.Progress.TryAccept(new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, YoutiaoQuality: YoutiaoQuality.Golden));
        var inventory = new YoutiaoInventory(8);
        for (int i = 0; i < stock; i++) inventory.TryStore(1, i == 0 ? YoutiaoQuality.Light : YoutiaoQuality.Golden);
        customer.WaitSeconds = customer.LeaveAtSeconds * .7;
        customer.Tick(0);
        int callbacks = 0, receipts = 0;
        var cues = new List<BusinessCue>();
        controller.DeliveryCompleted += _ => callbacks++;
        controller.ItemDelivered += _ => receipts++;
        controller.Feedback.Requested += e => cues.Add(e.Cue);
        controller.IsPaused = true;
        Check(!controller.TryDeliverYoutiaoTo(customer.Id, inventory).ItemAccepted && inventory.Count == stock, "paused drag preserves stock");
        controller.IsPaused = false;
        Check(!controller.TryDeliverYoutiaoTo("missing", inventory).ItemAccepted && inventory.Count == stock, "invalid target preserves stock");
        cues.Clear();
        int expected = Math.Min(stock, 2 - preDelivered);
        var result = controller.TryDeliverYoutiaoTo(customer.Id, inventory);
        Check(inventory.Count == stock - expected && customer.Progress.GetDeliveredQuantity(0) == preDelivered + expected, "one drag delivers only remaining demand or available stock");
        Check(controller.Ledger!.YoutiaoUsed == expected && receipts == expected && callbacks == (expected > 0 ? 1 : 0), "piece receipts and usage are exact; one batch callback");
        Check(Math.Abs(customer.WaitSeconds / customer.LeaveAtSeconds - (.7 - .15 * expected)) < .00001, "patience restores 15 percent per delivered piece");
        bool complete = expected > 0 && expected + preDelivered == 2 && !combo;
        Check(result.CompletesOrder == complete && controller.Ledger.Build().CompletedCustomers == (complete ? 1 : 0), "combo waits for other products; completed order settles once");
        Check(cues.Count(c => c is BusinessCue.ItemAccepted or BusinessCue.OrderCompleted or BusinessCue.DeliveryError) == 1
            && cues.Contains(expected == 0 ? BusinessCue.DeliveryError : complete ? BusinessCue.OrderCompleted : BusinessCue.ItemAccepted), "one correct delivery sound per drag");
        if (expected > 0)
            Check(customer.Progress.DeliveredItems.Skip(preDelivered).Select(i => i.YoutiaoQuality)
                .SequenceEqual(Enumerable.Range(0, expected).Select(i => (YoutiaoQuality?)(i == 0 ? YoutiaoQuality.Light : YoutiaoQuality.Golden))), "FIFO qualities preserved");
        if (complete) Check(result.SatisfactionScore == 85 && result.Tip == 0 && controller.Ledger.Build().TotalRevenue == result.TotalRevenue, "mixed quality revenue remains accurate");
        if (expected + preDelivered == 2)
            Check(!controller.TryDeliverYoutiaoTo(customer.Id, inventory).ItemAccepted && inventory.Count == stock - expected
                && controller.Ledger.YoutiaoUsed == expected, "duplicate delivery consumes nothing");
        controller.Free();
    }
}
