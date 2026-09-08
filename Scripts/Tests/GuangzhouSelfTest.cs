using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Guangzhou;
using ProjectCake.Interaction;
using ProjectCake.Orders;

namespace ProjectCake.Tests;

public partial class GuangzhouSelfTest : Node
{
    private int _passed, _failed;
    public override void _Ready()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        try { TestData(catalog); TestCooking(catalog); TestInventory(catalog); TestEvaluation(catalog); TestQueue(catalog); TestSave(catalog); SimulateDays(catalog); }
        catch (Exception e) { Check(false, e.ToString()); }
        GD.Print($"GUANGZHOU_TEST_RESULT passed={_passed} failed={_failed}"); GetTree().Quit(_failed == 0 ? 0 : 1);
    }
    private void Check(bool value, string message)
    { if (value) _passed++; else { _failed++; GD.PushError("FAIL " + message); } }
    private static DayPlan Plan(DataCatalog c, DayConfig d) => new OrderGenerator().Generate(d, c.RecipesById, c.ProductsById, c.CustomersById);
    private void TestData(DataCatalog c)
    {
        Check(c.IsValid, "全量目录有效：" + string.Join(";", c.ValidationIssues));
        int[] durations = { 60, 70, 80, 90, 95, 105, 110, 120, 130, 140, 150, 165 }, counts = { 6, 7, 8, 10, 10, 12, 13, 14, 16, 18, 20, 24 };
        Check(c.GetDays(StableIds.Cities.Guangzhou).Count == 12, "十二天均加载");
        Check(c.GuangzhouEquipment.Values.Sum(e => e.UpgradePrice) == 1460, "升级总价1460");
        foreach (var d in c.GetDays(StableIds.Cities.Guangzhou).Values)
        {
            Check(d.DurationSeconds == durations[d.Day - 1] && d.CustomerCount == counts[d.Day - 1], $"Day{d.Day}时长和客流");
            var a = Plan(c, d); var b = Plan(c, d);
            Check(JsonSerializer.Serialize(a) == JsonSerializer.Serialize(b), "固定种子完全复现");
            int seed = d.RandomSeed;
            try
            {
                for (int n = 0; n < 30; n++)
                {
                    d.RandomSeed = 4000 + n * 31 + d.Day; var p = Plan(c, d);
                    var cq = OrderGenerator.AllocateByLargestRemainder(d.CustomerCount, d.CustomerWeights.Values.ToArray());
                    Check(d.CustomerWeights.Keys.Select((id, i) => p.Customers.Count(x => x.CustomerTypeId == id) == cq[i]).All(x => x), "顾客精确配额");
                    var oq = OrderGenerator.AllocateByLargestRemainder(d.CustomerCount, d.OrderTypeWeights.Values.ToArray());
                    Check(d.OrderTypeWeights.Keys.Select((id, i) => p.Customers.Count(x => x.Order.OrderTypeId == id) == oq[i]).All(x => x), "订单精确配额");
                    Check(!p.Customers.Zip(p.Customers.Skip(1)).Any(x => x.First.CustomerTypeId == "gz_family" && x.Second.CustomerTypeId == "gz_family"), "大单不连续");
                    foreach (var customer in p.Customers)
                    {
                        var order = customer.Order;
                        Check(order.Lines.All(l => d.AvailableProductKinds.Contains(l.ProductKind) && (l.ProductKind != ProductKind.RiceRoll || d.AvailableRecipeIds.Contains(l.DefinitionId))), "订单不越过商品解锁");
                        Check(order.BasePrice == order.Lines.Sum(l => l.Quantity * (l.ProductKind == ProductKind.RiceRoll ? c.RecipesById[l.DefinitionId].Price : c.ProductsById[l.DefinitionId].UnitPrice)), "订单价格按实际商品求和");
                        if (customer.CustomerTypeId == "gz_family") Check(order.OrderTypeId == "gz_f" && order.Lines.Where(l => l.ProductKind == ProductKind.RiceRoll).Sum(l => l.Quantity) == 2 && order.Lines.Sum(l => l.Quantity) == 4, "家庭固定两肠粉蒸点茶");
                    }
                }
            }
            finally { d.RandomSeed = seed; }
        }
        var day9 = c.GetDays(StableIds.Cities.Guangzhou)[9]; var old = day9.MaxWaitingCustomers;
        day9.MaxWaitingCustomers = 5;
        Check(GuangzhouCatalogValidator.Validate(c.GetDays(StableIds.Cities.Guangzhou).Values.ToArray(), c.RecipesById.Values.Where(r => GuangzhouRules.Recipes.Contains(r.Id)).ToArray(),
            c.ProductsById.Values.Where(p => p.Id.StartsWith("gz_")).ToArray(), c.CustomersById.Values.Where(t => t.Id.StartsWith("gz_")).ToArray(), c.GuangzhouEquipment.Values.ToArray()).Count > 0, "错误上限被校验器拒绝");
        day9.MaxWaitingCustomers = old;
    }
    private static RiceRollStateMachine Started(DataCatalog c, int level = 1)
    {
        var t = new RiceRollStateMachine(c.GetGuangzhouEquipment(GuangzhouRules.Stove, level));
        t.TryPour(new(8, .8)); t.Spread(.8); t.TryPush(); return t;
    }
    private void TestCooking(DataCatalog c)
    {
        var batter = new GuangzhouStock(8, .8); var egg = new GuangzhouStock(6, .8);
        var t = new RiceRollStateMachine(c.GetGuangzhouEquipment(GuangzhouRules.Stove, 1));
        Check(t.TryPour(batter) && !t.TryPour(batter) && batter.Count == 7, "米浆仅扣一次");
        t.Spread(.64); Check(!t.TryPush() && !t.TryAdd(GuangzhouRules.Egg, egg), "低于65%不可推进加料");
        t.Spread(.01); Check(t.TryAdd(GuangzhouRules.Egg, egg) && !t.TryAdd(GuangzhouRules.Egg, egg) && egg.Count == 5, "65%可加料，重复不扣库存");
        t.Spread(.15); Check(t.SpreadProgress == 1, "80%吸附铺满");
        Check(t.TryPush() && !t.TryAdd(GuangzhouRules.Pork, egg), "推进锁配料");
        t.Tick(2.49); Check(!t.TryPull(), "未熟不可拉出"); t.Tick(.01); Check(t.Cooked && t.Quality == RiceRollQuality.Perfect, "2.5秒熟");
        t.Tick(2); Check(t.Quality == RiceRollQuality.Perfect, "4.5秒仍最佳"); t.Tick(.001); Check(t.Quality == RiceRollQuality.Normal, "超过4.5秒普通");
        t.Tick(1.499); Check(t.Quality == RiceRollQuality.Normal, "6秒边界仍普通"); t.Tick(.001); Check(t.Quality == RiceRollQuality.Dry, "超过6秒Dry");
        Check(t.TryPull(), "过蒸仍可取出"); double seconds = t.SteamSeconds; t.Tick(100); Check(t.SteamSeconds == seconds, "拉出冻结熟度");
        t.Roll(.74); Check(!t.TryCut(), "低于75%不可切"); t.Roll(.75); Check(t.TryCut() && t.Broken && !t.TryTake(), "75%可提前切且必须淋汁");
        var sauce = new GuangzhouStock(10, .8); Check(t.TrySauce(sauce) && !t.TrySauce(sauce) && sauce.Count == 9 && t.TryTake() && t.State == RiceRollState.Empty, "淋汁一次并可交付");
        var lv2 = Started(c, 2); lv2.Tick(100); Check(lv2.Cooked && lv2.Quality == RiceRollQuality.Perfect && !lv2.PoppedOut && lv2.State == RiceRollState.Steaming, "Lv2恒温仍需手拉");
        var lv3 = Started(c, 3); lv3.Tick(1.79); Check(!lv3.Cooked, "Lv3未到1.8秒"); lv3.Tick(.01); Check(lv3.PoppedOut, "Lv3熟后弹出");
        lv3.TryPull(); lv3.Roll(.85); Check(lv3.RollProgress == 1 && lv3.TryCut() && !lv3.Broken, "85%自动完整卷起");
        var city = SaveService.NewGuangzhouProgress(); city.EquipmentLevels[GuangzhouRules.Stove] = 2;
        var session = new GuangzhouSession(c, city, c.GetDays(StableIds.Cities.Guangzhou)[9]);
        session.Trays[0].TryPour(session.Ingredients[GuangzhouRules.Batter]); session.Trays[0].Spread(.8); session.Trays[0].TryPush(); session.Tick(1);
        session.Trays[1].TryPour(session.Ingredients[GuangzhouRules.Batter]); session.Trays[1].Spread(.8); session.Trays[1].TryPush(); session.Tick(1.5);
        Check(session.Trays[0].Cooked && !session.Trays[1].Cooked, "双屉独立计时");
        session.Ingredients[GuangzhouRules.Batter].TryRefill(); session.Tea!.TryPour(); session.Paused = true; session.Tick(10);
        Check(session.Trays[1].SteamSeconds == 1.5 && session.Tea.PourRemaining == .3 && session.Ingredients[GuangzhouRules.Batter].RefillRemaining == .8, "暂停冻结各生产线");
        var early = new GuangzhouSession(c, city, c.GetDays(StableIds.Cities.Guangzhou)[1]);
        Check(early.Trays.Count == 2 && early.Cabinet is null && early.Tea is null && !early.IngredientUnlocked(GuangzhouRules.Egg), "重玩使用设备但商品按日限制");
        var gesture = new RiceRollGesture(); Check(!gesture.Begin(RiceRollGestureMode.Roll, new(.5f, .5f)), "刮卷必须从边缘开始");
        gesture.Begin(RiceRollGestureMode.Roll, new(.05f, .5f)); Check(gesture.Move(new(.95f, .5f)) > .85, "一次单向手势能完成");
        gesture.Begin(RiceRollGestureMode.Spread, new(.1f, .5f)); gesture.Move(new(1.2f, .5f)); Check(gesture.Mode == RiceRollGestureMode.None, "出界取消手势不跨区累计");
    }
    private void TestInventory(DataCatalog c)
    {
        var stock = new DimSumInventory(); var cabinet = new DimSumCabinet(c.GetGuangzhouEquipment(GuangzhouRules.Cabinet, 1));
        Check(cabinet.TryLoad(0, GuangzhouRules.SiuMai) && cabinet.TryLoad(1, GuangzhouRules.HarGow) && !cabinet.TryLoad(0, GuangzhouRules.SiuMai), "共享柜逐笼装载");
        cabinet.Tick(4.99); Check(!cabinet.TryStock(0, stock), "生蒸点不可入库"); cabinet.Tick(.01); Check(cabinet.Baskets[0].Cooked && !cabinet.Baskets[1].Cooked, "两品种蒸熟时间不同");
        cabinet.Tick(3); Check(cabinet.Baskets[0].Quality == DimSumQuality.Perfect, "烧卖8秒仍最佳"); cabinet.Tick(.01); Check(cabinet.Baskets[0].Quality == DimSumQuality.Normal, "最佳窗口后普通");
        cabinet.Tick(1.99); Check(cabinet.Baskets[0].Quality == DimSumQuality.Normal, "10秒普通边界"); cabinet.Tick(.01); Check(cabinet.Baskets[0].Quality == DimSumQuality.Oversteamed, "超过10秒过蒸");
        for (int i = 0; i < 4; i++) stock.TryAdd(GuangzhouRules.SiuMai, i == 0 ? DimSumQuality.Normal : DimSumQuality.Perfect);
        Check(!cabinet.TryStock(0, stock) && !cabinet.Baskets[0].Empty && !stock.TryAdd(GuangzhouRules.SiuMai, DimSumQuality.Perfect), "满库留在柜中");
        Check(stock.TryPeek(GuangzhouRules.SiuMai, out var quality) && quality == DimSumQuality.Normal && stock.TryTake(GuangzhouRules.SiuMai), "先进先出保留品质");
        Check(cabinet.TryStock(0, stock) && stock.Count(GuangzhouRules.SiuMai) == 4, "腾出容量可取柜中成品");
        foreach (int level in new[] { 2, 3 })
        {
            var e = c.GetGuangzhouEquipment(GuangzhouRules.Cabinet, level); var m = new DimSumCabinet(e); m.TryLoad(0, GuangzhouRules.SiuMai); m.TryLoad(1, GuangzhouRules.HarGow);
            m.Tick(4.3); Check(m.Baskets[0].Cooked && !m.Baskets[1].Cooked && m.Baskets.Count == 4, "Lv2/3四层快蒸");
            m.Tick(100); Check(m.Baskets[0].Quality == (level == 3 ? DimSumQuality.Perfect : DimSumQuality.Oversteamed) && !m.Baskets[0].Empty, "仅Lv3自动保温且仍需手取");
        }
        var tea = new GuangzhouTea(); Check(tea.TryPour() && !tea.TryPour() && tea.Stock.Count == 5, "取茶仅扣一次"); tea.Tick(.29); Check(!tea.TryTakeCup(), "取茶需要0.3秒"); tea.Tick(.01); Check(tea.HasCup && tea.TryTakeCup(), "茶可取用");
        Check(tea.Stock.TryRefill() && !tea.Stock.TryRefill(), "不能重复补茶"); tea.Tick(.5); Check(tea.Stock.Count == 6, "0.5秒补满茶");
        var ingredients = new GuangzhouStock(8, .8); ingredients.TryTake(); ingredients.TryRefill(); Check(!ingredients.TryTake(), "补货容器不可使用"); ingredients.Tick(.8); Check(ingredients.Count == 8, "0.8秒补满配料");
    }
    private static DeliveredItem Roll(string id, RiceRollQuality quality = RiceRollQuality.Perfect, bool broken = false) => new(ProductKind.RiceRoll, id, GuangzhouQuality: new(true, quality, broken));
    private static OrderData Order(params OrderLineData[] lines) => new()
    { OrderId = "gz-test", CityId = StableIds.Cities.Guangzhou, OrderTypeId = "gz_f", CustomerTypeId = "gz_normal", Lines = lines, BasePrice = 30, PatienceSeconds = 50 };
    private void TestEvaluation(DataCatalog c)
    {
        var p = new OrderProgress(Order(new(ProductKind.RiceRoll, "gz_egg", 1), new(ProductKind.RiceRoll, "gz_pork", 1), new(ProductKind.SiuMai, GuangzhouRules.SiuMai, 1)));
        Check(p.TryAccept(Roll("gz_pork")).Accepted && p.GetDeliveredQuantity(1) == 1 && !p.HasRecipeMismatch, "多配方优先正确行");
        Check(!p.TryAccept(new(ProductKind.HarGow, GuangzhouRules.HarGow, GuangzhouQuality: new(true, DimSum: DimSumQuality.Perfect))).Accepted, "错误蒸点拒收");
        Check(!p.TryAccept(new(ProductKind.RiceRoll, "gz_egg")).Accepted, "不完整肠粉拒收");
        p.TryAccept(Roll("gz_plain", RiceRollQuality.Dry, true)); p.TryAccept(new(ProductKind.SiuMai, GuangzhouRules.SiuMai, GuangzhouQuality: new(true, DimSum: DimSumQuality.Oversteamed)));
        var evaluator = new OrderEvaluator(); var result = evaluator.EvaluateCompletedGuangzhou(p, .7, c.CustomersById["gz_normal"]);
        Check(result.SatisfactionScore == 45 && result.SaleRevenue == 21 && result.Tip == 0 && result.Grade == DeliveryGrade.Incorrect, "多缺陷叠加且错配整单七折");
        var duplicate = new OrderProgress(Order(new OrderLineData(ProductKind.RiceRoll, "gz_pork", 2)));
        duplicate.TryAccept(Roll("gz_plain", RiceRollQuality.Dry, true)); duplicate.TryAccept(Roll("gz_plain", RiceRollQuality.Dry, true));
        Check(evaluator.EvaluateCompletedGuangzhou(duplicate, 0, c.CustomersById["gz_normal"]).SatisfactionScore == 65, "同类缺陷每单只扣一次");
        foreach (var (ratio, expected) in new[] { (0.3, 100), (.3001, 95), (.6, 95), (.6001, 85), (.8399, 85), (.84, 70) })
        {
            var good = new OrderProgress(Order(new OrderLineData(ProductKind.RiceRoll, "gz_pork", 1))); good.TryAccept(Roll("gz_pork"));
            Check(evaluator.EvaluateCompletedGuangzhou(good, ratio, c.CustomersById["gz_normal"]).SatisfactionScore == expected, "等待扣分边界");
        }
        var normal = new OrderProgress(Order(new OrderLineData(ProductKind.RiceRoll, "gz_pork", 1))); normal.TryAccept(Roll("gz_pork", RiceRollQuality.Normal));
        result = evaluator.EvaluateCompletedGuangzhou(normal, 0, c.CustomersById["gz_normal"]);
        Check(result.SatisfactionScore == 100 && result.SaleRevenue == 30 && result.Grade == DeliveryGrade.Correct, "轻微过蒸原价无扣分但非Perfect");
        var best = new OrderProgress(Order(new OrderLineData(ProductKind.RiceRoll, "gz_pork", 1))); best.TryAccept(Roll("gz_pork"));
        Check(evaluator.EvaluateCompletedGuangzhou(best, 0, c.CustomersById["gz_office"]).Tip == 6 && evaluator.EvaluateCompletedGuangzhou(best, 0, c.CustomersById["gz_normal"]).Tip == 3, "小费无浮点多取整");
        var ledger = new DayLedger(1, 6, SatisfactionAverageMode.CompletedCustomers); ledger.RecordLost(); ledger.RecordDelivery(new(DeliveryGrade.Correct, 10, 0, 80, "")); Check(ledger.Build().Satisfaction == 80, "离店不参与满意度平均");
    }
    private void TestQueue(DataCatalog c)
    {
        PlannedCustomer Make(int i, string type = "gz_normal") => new() { CustomerId = "q" + i, CustomerTypeId = type, ArrivalTime = i * .1,
            Order = new OrderData { OrderId = "o" + i, CityId = StableIds.Cities.Guangzhou, CustomerTypeId = type, OrderTypeId = "gz_f", PatienceSeconds = 50, Lines = new[] { new OrderLineData(ProductKind.SiuMai, GuangzhouRules.SiuMai, 1) }, BasePrice = 6 } };
        var q = new CustomerQueue(new() { Customers = new[] { Make(0), Make(1), Make(2), Make(3), Make(4) } }, c.CustomersById, 1, 4, 2, 4);
        q.Tick(0, .01, true); q.Tick(.1, .1, true); q.Tick(.2, .1, true); Check(q.Slots.Count == 2 && q.AppliedPressureDelay == 2, "两复杂单延迟2秒");
        q.Tick(2.2, 2, true); Check(q.Slots.Count == 2 && q.AppliedPressureDelay == 4, "累计最大4秒"); q.Tick(4.2, 2, true); Check(q.Slots.Count == 3, "4秒后放行"); q.Tick(8.3, 4.1, true); q.Tick(12.4, 4.1, true); Check(q.Slots.Count <= 4, "等待硬上限4");
        var family = new CustomerQueue(new() { Customers = new[] { Make(0, "gz_family"), Make(1) } }, c.CustomersById, 1, 4, 2, 4);
        family.Tick(0, .01, true); family.Tick(.1, .1, true); Check(family.Slots.Count == 2, "一个家庭不自我重复触发压力");
        var d = c.GetDays(StableIds.Cities.Guangzhou)[9]; int protectedHar = 0, baseHar = 0;
        for (int i = 0; i < 1000; i++)
        {
            if (GuangzhouOrderProtection.Choose(d, "gz_normal", i, _ => 0, _ => 0) == GuangzhouRules.HarGow) baseHar++;
            if (GuangzhouOrderProtection.Choose(d, "gz_normal", i, _ => 0, id => id == GuangzhouRules.HarGow ? 2 : 0) == GuangzhouRules.HarGow) protectedHar++;
        }
        Check(protectedHar < baseHar / 2 && protectedHar > 0, "库存保护降低而非清零权重");
        var controller = new DayController(); AddChild(controller); controller.TryPrepareDay(StableIds.Cities.Guangzhou, 9, c, out _);
        controller.GuangzhouStockCount = _ => 0; controller.TryStartDay(out _); controller.Tick(3); controller.Tick(2);
        var active = controller.CustomerQueue!.Slots.FirstOrDefault(); Check(active is not null, "入场生成广州顾客");
        if (active is not null)
        {
            string json = JsonSerializer.Serialize(active.Order); controller.GuangzhouStockCount = _ => 4; controller.Tick(.1);
            Check(JsonSerializer.Serialize(active.Order) == json, "已展示订单不随库存改变");
            int count = 1; controller.IsPaused = true;
            var rejected = controller.TryDeliverGuangzhouTo(active.Id, Roll("gz_plain"), () => { count--; return true; });
            Check(!rejected.ItemAccepted && count == 1, "暂停拒绝交付且不扣库存");
        }
        controller.AbandonDay(); Check(controller.Ledger is null && controller.CustomerQueue is null, "放弃清除本局不结算"); controller.QueueFree();
    }
    private void TestSave(DataCatalog c)
    {
        string path = Path.Combine(Path.GetTempPath(), "guangzhou-save-" + Guid.NewGuid().ToString("N") + ".json");
        var save = new SaveService(); save.UsePathForTests(path); AddChild(save);
        try
        {
            var city = save.Data.Guangzhou; save.Data.Coins = 2000;
            Check(!save.Data.UnlockedCityIds.Contains(StableIds.Cities.Guangzhou), "临时进度不解锁正式城市");
            var d3 = c.GetDays(StableIds.Cities.Guangzhou)[3]; var d4 = c.GetDays(StableIds.Cities.Guangzhou)[4];
            Check(!save.TryPurchase(StableIds.Cities.Guangzhou, "equipment:guangzhou_station_lv2", c, out _), "日期未开放不能购买");
            var r = new DayResult { Day = 3, CompletedCustomers = 8, SaleRevenue = 75, Satisfaction = 100 }; var p = Plan(c, d3);
            Check(save.CommitDay(r, p, d3).PermanentCoinGain == 75 && save.CommitDay(r, p, d3).PermanentCoinGain == 0, "重复结算不重复收入");
            Check(save.TryPurchase(StableIds.Cities.Guangzhou, "equipment:guangzhou_station_lv2", c, out _) && save.Data.PurchasedIngredientStationLevel == 1, "广州购买不改天津设备");
            Check(!save.TryPurchase(StableIds.Cities.Guangzhou, "equipment:guangzhou_station_lv2", c, out _), "重复购买拒绝");
            city.UnlockedContentIds.Add("equipment:guangzhou_stove_lv3"); Check(!save.TryPurchase(StableIds.Cities.Guangzhou, "equipment:guangzhou_stove_lv3", c, out _), "不能跳级购买");
            save.CommitDay(new() { Day = 4, SaleRevenue = 90 }, Plan(c, d4), d4); save.TryPurchase(StableIds.Cities.Guangzhou, "equipment:guangzhou_stove_lv2", c, out _);
            var d5 = c.GetDays(StableIds.Cities.Guangzhou)[5]; save.ApplyStartUnlocks(d5, out _); Check(save.Data.Guangzhou.EquipmentLevels[GuangzhouRules.Cabinet] == 1, "Day5免费开放蒸柜");
            var d12 = c.GetDays(StableIds.Cities.Guangzhou)[12];
            Check(SaveService.EvaluateStars(new() { CompletedCustomers = 18, Satisfaction = 70 }, d12) == 1
                && SaveService.EvaluateStars(new() { CompletedCustomers = 21, Satisfaction = 82 }, d12) == 2
                && SaveService.EvaluateStars(new() { CompletedCustomers = 23, Satisfaction = 90, PerfectOrders = 13 }, d12) == 2
                && SaveService.EvaluateStars(new() { CompletedCustomers = 23, Satisfaction = 90, PerfectOrders = 14 }, d12) == 3, "最终日星级边界");
            save.CommitDay(new() { Day = 12, CompletedCustomers = 23, Satisfaction = 90, PerfectOrders = 14, SaleRevenue = 410 }, Plan(c, d12), d12);
            int money = save.Data.Coins; save.Load(); Check(save.Data.Coins == money && save.Data.Guangzhou.Completed && save.Data.Guangzhou.BestStars == 3 && save.Data.Guangzhou.LastDayPlan?.Customers.Count == 24, "v3广州存档完整往返");
            save.Data.Cities.Remove(StableIds.Cities.Guangzhou); save.Data.Xian.Completed = true; save.Data.Xian.BestStars = 1; save.TrySave(out _); save.Load();
            Check(!save.HasLoadError && save.Data.UnlockedCityIds.Contains(StableIds.Cities.Guangzhou) && save.Data.Guangzhou.HighestUnlockedDay == 1 && save.Data.Coins == money, "旧v3已通关西安自动开放广州");
        }
        finally { save.QueueFree(); if (File.Exists(path)) File.Delete(path); }
    }
}
