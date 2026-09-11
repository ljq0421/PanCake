using Godot;
using ProjectCake.Customers;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Xian;

namespace ProjectCake.Tests;

public partial class XianSelfTest : Node
{
    private int _passed, _failed;
    private DataCatalog _catalog = null!;
    private readonly string _root = $"res://.tmp/xian-tests/{Guid.NewGuid():N}";
    public override void _Ready()
    {
        try
        {
            _catalog = GetNode<DataCatalog>("/root/DataCatalog");
            Check(_catalog.IsValid, "全量数据目录有效");
            TestDataAndOrders(); TestProduction(); TestScoring(); TestPressure(); TestSave(); TestFullChapter();
        }
        catch (Exception exception) { _failed++; GD.PushError(exception.ToString()); }
        GD.Print($"XIAN_TEST_RESULT passed={_passed} failed={_failed}"); GetTree().Quit(_failed == 0 ? 0 : 1);
    }
    private void Check(bool value, string name)
    {
        if (value) { _passed++; GD.Print($"PASS {name}"); }
        else { _failed++; GD.PushError($"FAIL {name}"); }
    }
    private XianEquipmentData Eq(string id, int level) => _catalog.GetXianEquipment(id, level);
    private SaveService Save(string name)
    {
        var save = new SaveService(); save.UsePathForTests($"{_root}/{name}.json"); AddChild(save); return save;
    }
    private void TestDataAndOrders()
    {
        var days = _catalog.GetDays(StableIds.Cities.Xian);
        Check(days.Count == 12 && days.Values.Sum(d => d.DurationSeconds) == 1450, "西安12天营业时间1450秒");
        Check(_catalog.XianEquipment.Values.Sum(d => d.UpgradePrice) == 1530, "三级设备总价1530");
        for (int day = 1; day <= 12; day++)
        {
            var config = days[day];
            var a = new OrderGenerator().Generate(config, _catalog.RecipesById, _catalog.ProductsById, _catalog.CustomersById);
            var b = new OrderGenerator().Generate(config, _catalog.RecipesById, _catalog.ProductsById, _catalog.CustomersById);
            string Fingerprint(DayPlan p) => System.Text.Json.JsonSerializer.Serialize(p);
            Check(Fingerprint(a) == Fingerprint(b) && a.Customers.Count == config.CustomerCount, $"Day {day}订单可重现、人数准确");
            Check(a.Customers.All(c => c.Order.Lines.Where(l => l.ProductKind == ProductKind.Roujiamo).All(l => config.AvailableRecipeIds.Contains(l.DefinitionId))), $"Day {day}不生成未解锁配方");
            Check(a.Customers.All(c => c.Order.BasePrice == c.Order.Lines.Sum(l => l.Quantity * (l.ProductKind == ProductKind.Hulatang ? 6 : _catalog.RecipesById[l.DefinitionId].Price))), $"Day {day}售价由订单计算");
            if (day == 9) Check(a.Customers.Count(c => c.Order.OrderTypeId == "xian_d") == 2 && a.Customers.Count(c => c.Order.OrderTypeId == "xian_e") == 1, "双份教学日D2单E1单");
            if (day >= 8) Check(a.Customers.Where(c => c.CustomerTypeId == "xian_regular").All(c => c.Order.OrderTypeId == "xian_c" && c.Order.Lines.Any(l => l.DefinitionId is "roujiamo_standard" or "roujiamo_juicy")), $"Day {day}熟客套餐保持常点池");
        }
        bool protectedOrders = true;
        foreach (int day in new[] { 9, 10, 11, 12 })
        {
            var config = days[day]; int seed = config.RandomSeed;
            for (int i = 0; i < 100; i++)
            {
                config.RandomSeed = 5000 + i;
                var plan = new OrderGenerator().Generate(config, _catalog.RecipesById, _catalog.ProductsById, _catalog.CustomersById);
                int run = 0;
                foreach (var c in plan.Customers) { run = XianRules.IsDouble(c.Order.OrderTypeId) ? run + 1 : 0; protectedOrders &= run <= 2; }
            }
            config.RandomSeed = seed;
        }
        Check(protectedOrders, "400种订单排列双份最多连续2单");
    }
    private void TestProduction()
    {
        for (int day = 1; day <= 2; day++)
        {
            var session = new XianSession(_catalog, SaveService.NewXianProgress(), day);
            Check(session.Oven is not null && !session.Buns.Tutorial && session.Buns.Count == 4 && session.Board.Portions == 0,
                $"Day{day}免费炉、四个熟馍和零预剁肉");
            for (int i = 0; i < 4; i++) session.Buns.TryTake(out _);
            Check(!session.Buns.TryTake(out _), $"Day{day}熟馍耗尽不再无限供应");
            session.Oven!.TryStart(4); session.Tick(3); session.Oven.TryFlip(); session.Tick(3);
            Check(session.Oven.TryCollect(session.Buns) && session.Buns.Count == 4, $"Day{day}烙制补足熟馍");
        }
        foreach (string type in new[] { "normal", "office_worker", "regular", "tourist" })
            Check(CustomerAppearanceCatalog.CandidatesFor("xian_" + type).SequenceEqual(CustomerAppearanceCatalog.CandidatesFor("wuhan_" + type)),
                $"西安{type}复用共享人物池");
        var stock = new BunInventory(6, 0); var oven = new BunOvenStateMachine(Eq(XianRules.Oven, 1));
        Check(!oven.TryStart(0) && !oven.TryStart(5) && oven.TryStart(4), "炉子校验整批数量");
        oven.Tick(2.9, stock); Check(!oven.TryFlip(), "未满3秒不能翻面"); oven.Tick(.1, stock); Check(oven.TryFlip(), "3秒翻面");
        oven.Tick(3, stock); Check(oven.State == BunOvenState.Ready && oven.Quality == BunQuality.Golden, "两面烙满进入最佳");
        oven.Tick(2, stock); Check(oven.Quality == BunQuality.Golden, "8秒仍在最佳边界"); oven.Tick(.01, stock); Check(oven.Quality == BunQuality.Overbrowned, "超过8秒偏焦");
        oven.Tick(1.5, stock); Check(oven.State == BunOvenState.Burnt && !oven.TryCollect(stock), "超过9.5秒焦糊拒收");
        Check(oven.TryDiscard() && stock.Count == 0, "焦糊只能清理");
        oven.TryStart(1); oven.Tick(5.1, stock); oven.TryFlip(); oven.Tick(3, stock);
        Check(oven.Quality == BunQuality.Overbrowned && oven.TryCollect(stock) && stock.TryTake(out var q) && q == BunQuality.Overbrowned, "晚翻面火候跨两面和库存保留");
        var safe = new BunOvenStateMachine(Eq(XianRules.Oven, 2)); safe.TryStart(6); safe.Tick(100, stock);
        Check(safe.State == BunOvenState.FirstSide && safe.TryFlip(), "Lv2等待翻面不焦"); safe.Tick(100, stock); Check(safe.Quality == BunQuality.Golden, "Lv2成熟不焦");
        var full = new BunInventory(10, 6); var auto = new BunOvenStateMachine(Eq(XianRules.Oven, 3)); auto.TryStart(6); auto.Tick(4.8, full);
        Check(auto.State == BunOvenState.Ready && full.Count == 6, "自动炉满库保留整批"); full.TryTake(out _); full.TryTake(out _); auto.Tick(.01, full);
        Check(full.Count == 10 && auto.State == BunOvenState.Empty, "腾出空间自动重试入库");
        var meat = new RefillableStock(12, .8); var board = new ChoppingStateMachine(Eq(XianRules.Board, 1), 3);
        Check(!board.TryStart(meat) && meat.Count == 12, "肉盘不足2空位不扣肉"); board.TryTake(); Check(board.TryStart(meat) && meat.Count == 10, "开剁扣2份肉一次");
        for (int i = 0; i < 1000; i++) board.AddMotion(i % 2 == 0 ? 1 : -1);
        Check(board.Progress == 0, "原地微抖不累积剁肉进度"); Chop(board);
        Check(board.Portions == 4 && board.CompletedChops == 1 && !board.IsChopping && meat.Count == 10, "一次手动剁肉产2份");
        foreach (int index in Enumerable.Range(0, 4))
        {
            var food = new RoujiamoStateMachine(); var buns = new BunInventory(6, 1); var prepared = new ChoppingStateMachine(Eq(XianRules.Board, 3), 12); var juice = new RefillableStock(12, .6);
            Check(food.TryTakeBun(buns) && !food.TryWrap() && !food.TryCut(20) && food.TryCut(80), $"X{index}切馍必须有效划动");
            for (int m = 0; m < XianRules.Meat(XianRules.Recipes[index]); m++) food.TryAddMeat(prepared, 2);
            if (XianRules.Juice(XianRules.Recipes[index])) food.TryAddJuice(juice, true);
            Check(food.TryWrap() && food.Prepared!.DefinitionId == XianRules.Recipes[index] && !food.TryAddMeat(prepared, 2) && food.TryTake() && !food.TryTake(), $"X{index}正确封装且只消费一次");
        }
        var city = SaveService.NewXianProgress(); var early = new XianSession(_catalog, city, 6);
        early.Sandwich.TryTakeBun(early.Buns); early.Sandwich.TryCut(80); early.AddMeat(); early.AddJuice();
        Check(!early.AddMeat(), "Day6加汁后不能绕过多肉加汁解锁");
        meat.TryRefill(); meat.Tick(.79); Check(meat.Count == 10 && !meat.TryConsume(1), "补货完成前不提前补满且锁定消耗"); meat.Tick(.02); Check(meat.Count == 12, "0.8秒补满肉锅");
        var soup = new HulatangRuntime(Eq(XianRules.Soup, 1), 4); soup.TryServe(); soup.Tick(.59); Check(!soup.HasBowl && soup.Stock.Count == 3, "盛汤扣一份，完成前不能取"); soup.Tick(.02);
        Check(soup.TryTake() && !soup.TryTake(), "汤碗仅可交付一次");
        city.EquipmentLevels[XianRules.Board] = 2; city.EquipmentLevels[XianRules.Oven] = 1; city.EquipmentLevels[XianRules.Soup] = 3;
        var later = new XianSession(_catalog, city, 9);
        Check(later.Buns.Count == 4 && later.Board.Portions == 6 && later.Soup!.Stock.Count == 6 && later.Meat.Capacity == 18, "Day9独立等级初始库存及肉锅容量");
        var replay = new XianSession(_catalog, city, 1); Check(!replay.Buns.Tutorial && replay.Buns.Count == 4 && replay.Board.Portions == 0 && replay.Oven is not null && replay.Soup is null, "重玩Day1保留升级但不提前开放制作线");
    }
    private static void Chop(ChoppingStateMachine board)
    {
        for (int i = 0; i < 12 && board.IsChopping; i++) board.AddMotion(i % 2 == 0 ? 50 : -50);
    }
    private OrderData Order(params OrderLineData[] lines) => new()
    { OrderId = "test", CityId = StableIds.Cities.Xian, CustomerTypeId = "xian_normal", OrderTypeId = "xian_e", Lines = lines, BasePrice = lines.Sum(l => l.Quantity * (l.ProductKind == ProductKind.Hulatang ? 6 : _catalog.RecipesById[l.DefinitionId].Price)) };
    private static DeliveredItem Item(int index, BunQuality quality = BunQuality.Golden) => new(ProductKind.Roujiamo, XianRules.Recipes[index], BunQuality: quality, MeatPortions: index / 2 + 1, HasJuice: index % 2 == 1);
    private void TestScoring()
    {
        var progress = new OrderProgress(Order(new OrderLineData(ProductKind.Roujiamo, XianRules.Recipes[0], 1), new(ProductKind.Roujiamo, XianRules.Recipes[3], 1), new(ProductKind.Hulatang, "hulatang", 1)));
        progress.TryAccept(Item(3)); progress.TryAccept(Item(0)); Check(!progress.HasRecipeMismatch && !progress.IsComplete, "双馍逆序精确匹配，缺汤继续等待");
        Check(!progress.TryAccept(Item(0)).Accepted && !progress.TryAccept(new(ProductKind.Youtiao, "youtiao")).Accepted, "多余商品和错误商品种类不被消费");
        progress.TryAccept(new(ProductKind.Hulatang, "hulatang"));
        var eval = new OrderEvaluator(); var type = _catalog.CustomersById["xian_normal"];
        Check(eval.EvaluateCompletedXian(progress, .30, type).Grade == DeliveryGrade.Perfect && eval.EvaluateCompletedXian(progress, .3001, type).SatisfactionScore == 95, "Perfect等待30%边界");
        Check(eval.EvaluateCompletedXian(progress, .6, type).SatisfactionScore == 95 && eval.EvaluateCompletedXian(progress, .6001, type).SatisfactionScore == 85 && eval.EvaluateCompletedXian(progress, .84, type).SatisfactionScore == 70, "等待扣分60%和84%边界");
        var wrong = new OrderProgress(Order(new OrderLineData(ProductKind.Roujiamo, XianRules.Recipes[0], 2)));
        wrong.TryAccept(Item(3, BunQuality.Overbrowned)); wrong.TryAccept(Item(3, BunQuality.Overbrowned));
        var error = eval.EvaluateCompletedXian(wrong, .7, type);
        Check(error.SatisfactionScore == 40 && error.SaleRevenue == 14 && error.Tip == 0, "两份错误同类只扣一次，肉汁偏焦和等待叠加，整单七折一次");
        var burnt = new OrderProgress(Order(new OrderLineData(ProductKind.Roujiamo, XianRules.Recipes[0], 1)));
        Check(!burnt.TryAccept(Item(0, BunQuality.Burnt)).Accepted && !burnt.IsComplete, "焦糊肉夹馍拒收");
        burnt.TryAccept(Item(0)); var office = eval.EvaluateCompletedXian(burnt, .1, _catalog.CustomersById["xian_office_worker"]);
        Check(office.Tip == 2, "上班族20%小费");
        var ledger = new DayLedger(12, 26, SatisfactionAverageMode.CompletedCustomers); ledger.RecordDelivery(error); ledger.RecordLost(); Check(ledger.Build().Satisfaction == 40, "离店顾客不计入满意度平均");
        var final = _catalog.GetDays(StableIds.Cities.Xian)[12];
        Check(SaveService.EvaluateStars(new DayResult { CompletedCustomers = 24, Satisfaction = 90, IncorrectOrders = 2 }, final) == 3 && SaveService.EvaluateStars(new DayResult { CompletedCustomers = 24, Satisfaction = 90, IncorrectOrders = 3 }, final) == 2, "三星错误订单2通过、3降二星");
    }
    private void TestPressure()
    {
        var type = _catalog.CustomersById["xian_normal"];
        DayPlan Plan(params string[] types) => new() { Day = 10, RandomSeed = 5, Customers = types.Select((t, i) => new PlannedCustomer { CustomerId = "p" + i, CustomerTypeId = type.Id, ArrivalTime = i, Order = new OrderData { OrderId = "o" + i, CityId = StableIds.Cities.Xian, CustomerTypeId = type.Id, OrderTypeId = t, Lines = new[] { new OrderLineData(ProductKind.Roujiamo, XianRules.Recipes[0], XianRules.IsDouble(t) ? 2 : 1) }, PatienceSeconds = 50 } }).ToArray() };
        var config = _catalog.GetDays(StableIds.Cities.Xian)[10].Constraints;
        var q = new ProjectCake.Customers.CustomerQueue(Plan("xian_e", "xian_e", "xian_a"), _catalog.CustomersById, 1, 4, 2, 4, config);
        q.Tick(1, 1, true); q.Tick(2, 1, true); Check(q.Slots.Count == 2 && q.AppliedPressureDelay == 2, "压力4.6延后2秒");
        q.Tick(4, 2, true); Check(q.Slots.Count == 3, "压力不足5不追加第二次延迟");
        var high = new ProjectCake.Customers.CustomerQueue(Plan("xian_c", "xian_e", "xian_e", "xian_a"), _catalog.CustomersById, 1, 4, 2, 4, config);
        high.Tick(2, 2, true); high.Tick(3, 1, true); high.Tick(5, 2, true); Check(high.AppliedPressureDelay == 4 && high.Slots.Count == 3, "压力5.9追加延迟，上限4秒");
        high.Tick(7, 2, true); Check(high.Slots.Count == 4, "4秒后放行，不无限追加压力等待");
        var first = new ProjectCake.Customers.CustomerQueue(Plan("xian_d", "xian_d"), _catalog.CustomersById, 1, 4, 2, 4, _catalog.GetDays(StableIds.Cities.Xian)[9].Constraints);
        first.Tick(0, .1, true); first.Tick(20, 1, true); Check(first.Slots.Count == 1, "Day9双份硬上限不受延迟上限影响");
        first.TryMarkServed("p0"); first.Tick(21, 1, false); Check(first.Slots.Count == 0 && first.HasUnscheduled, "收尾不再安排被硬限制的新客");
        Check(_catalog.GetDays(StableIds.Cities.Xian).Values.All(d => d.MaxWaitingCustomers == 5), "西安12天统一同屏五人上限");
        var five = new ProjectCake.Customers.CustomerQueue(Plan("xian_b", "xian_b", "xian_b", "xian_b", "xian_b", "xian_b"), _catalog.CustomersById, 1, 5);
        five.Tick(10, .4, true);
        Check(five.Slots.Count == 5 && five.Slots.Select(c => c.SlotIndex).Distinct().Count() == 5, "五个稳定位置入场，第六名等待");
        five.TryMarkServed("p1"); five.Tick(11, 1, false); five.Tick(12, 1, true);
        Check(five.CustomerAtSlot(2)?.Id == "p2" && five.CustomerAtSlot(1)?.Id == "p5", "离场后只补空位，其他顾客不移动");
    }
    private void TestSave()
    {
        foreach (int day in new[] { 1, 2, 3, 12 })
        {
            var legacy = Save($"free-oven-{day}"); legacy.Data.Coins = 123;
            var config = _catalog.GetDays(StableIds.Cities.Xian)[day];
            Check(legacy.ApplyStartUnlocks(config, out _) && legacy.Data.Xian.EquipmentLevels[XianRules.Oven] == 1
                && legacy.Data.Coins == 123, $"首次或旧档Day{day}免费补齐炉子");
            Check(legacy.ApplyStartUnlocks(config, out _) && legacy.Data.Xian.UnlockedContentIds.Count(id => id == "equipment:xian_oven_lv1") == 1,
                $"Day{day}重复初始化不重复解锁");
            legacy.Data.Xian.EquipmentLevels[XianRules.Oven] = 3;
            legacy.ApplyStartUnlocks(_catalog.GetDays(StableIds.Cities.Xian)[1], out _);
            legacy.TrySave(out _); legacy.Load();
            Check(legacy.Data.Xian.EquipmentLevels[XianRules.Oven] == 3 && legacy.Data.Coins == 123, "重玩与重载保留高级炉及金币");
        }
        var save = Save("compatibility"); save.Data.Coins = 700;
        save.Data.Wuhan.Completed = true; save.Data.Wuhan.BestStars = 1; save.Data.Wuhan.HighestUnlockedDay = 12;
        save.TrySave(out _); save.Load();
        Check(save.Data.UnlockedCityIds.Contains(StableIds.Cities.Xian) && save.Data.Xian.HighestUnlockedDay == 1 && save.Data.Coins == 700, "v3已通关武汉旧档无损开放西安");
        Check(!save.TryPurchase(StableIds.Cities.Xian, "equipment:xian_board_lv2", _catalog, out _), "有金币但日期未开放不可购买");
        var day2 = _catalog.GetDays(StableIds.Cities.Xian)[2]; var plan = new OrderGenerator().Generate(day2, _catalog.RecipesById, _catalog.ProductsById, _catalog.CustomersById);
        var result = new DayResult { Day = 2, SaleRevenue = 100, CompletedCustomers = 9, Satisfaction = 100 };
        save.CommitDay(result, plan, day2); Check(save.TryPurchase(StableIds.Cities.Xian, "equipment:xian_board_lv2", _catalog, out _) && save.Data.Coins == 650, "日期开放后正常付费升级");
        Check(!save.TryPurchase(StableIds.Cities.Xian, "equipment:xian_board_lv2", _catalog, out _), "不能重复购买升级");
        Check(save.CommitDay(result, plan, day2).PermanentCoinGain == 0 && save.CommitDay(new DayResult { Day = 2, SaleRevenue = 120 }, plan, day2).PermanentCoinGain == 20, "重玩仅补最佳收入差额");
        var fail = Save("failure"); string directory = ProjectSettings.GlobalizePath($"{_root}/failure.json"); Directory.CreateDirectory(directory);
        Check(!fail.ApplyStartUnlocks(day2, out _) && fail.Data.Xian.EquipmentLevels[XianRules.Oven] == 0
            && !fail.Data.Xian.UnlockedContentIds.Contains("equipment:xian_oven_lv1"), "免费炉保存失败回滚等级与解锁");
        int coins = fail.Data.Coins; bool threw = false;
        try { fail.CommitDay(result, plan, day2); } catch (IOException) { threw = true; }
        Check(threw && fail.Data.Coins == coins && fail.Data.Xian.HighestUnlockedDay == 1, "保存失败回滚金币与西安进度");
    }
    private void TestFullChapter()
    {
        var save = Save("full-chapter");
        for (int day = 1; day <= 12; day++)
        {
            var controller = new DayController(); AddChild(controller);
            var config = _catalog.GetDays(StableIds.Cities.Xian)[day]; save.ApplyStartUnlocks(config, out _);
            controller.TryPrepareDay(StableIds.Cities.Xian, day, _catalog, out _); var session = new XianSession(_catalog, save.Data.Xian, day);
            controller.TryStartDay(out _); controller.Tick(3);
            int tick = 0;
            while (controller.State != DayState.Results && tick++ < 5000)
            {
                const double dt = .05;
                if (session.Meat.Count < 2) session.Meat.TryRefill();
                if (session.Juice.Count == 0) session.Juice.TryRefill();
                if (session.Soup?.Stock.Count == 0) session.Soup.Stock.TryRefill();
                if (session.Oven is { } oven)
                {
                    if (oven.State == BunOvenState.Empty && session.Buns.Count <= 3) oven.TryStart(session.OvenData.Capacity);
                    if (oven.State == BunOvenState.FirstSide && oven.SideSeconds >= session.OvenData.ActionSeconds) oven.TryFlip();
                    if (oven.State == BunOvenState.Ready) oven.TryCollect(session.Buns);
                    if (oven.State == BunOvenState.Burnt) oven.TryDiscard();
                }
                if (session.Board.Capacity - session.Board.Portions >= 2 && !session.Board.IsChopping) session.Board.TryStart(session.Meat);
                if (session.Board.IsChopping && tick % 2 == 0) session.Board.AddMotion(tick % 4 == 0 ? 50 : -50);
                var customer = controller.CustomerQueue!.Slots.FirstOrDefault(c => c.State is ProjectCake.Customers.CustomerState.Happy or ProjectCake.Customers.CustomerState.Normal or ProjectCake.Customers.CustomerState.Impatient or ProjectCake.Customers.CustomerState.Angry);
                if (customer is not null)
                {
                    var line = customer.Order.Lines.Select((l, i) => (Line: l, Left: customer.Progress.GetRemainingQuantity(i))).FirstOrDefault(x => x.Left > 0).Line;
                    if (line?.ProductKind == ProductKind.Roujiamo)
                    {
                        var food = session.Sandwich;
                        if (food.State == RoujiamoState.Empty) food.TryTakeBun(session.Buns);
                        else if (food.State == RoujiamoState.Whole) food.TryCut(80);
                        else if (food.State == RoujiamoState.Open)
                        {
                            if (food.MeatPortions < XianRules.Meat(line.DefinitionId)) session.AddMeat();
                            else if (XianRules.Juice(line.DefinitionId) && !food.HasJuice) session.AddJuice();
                            else food.TryWrap();
                        }
                        else controller.TryDeliverXianTo(customer.Id, food.Prepared!, food.TryTake);
                    }
                    else if (line is not null && session.Soup is { } soup)
                    {
                        if (!soup.HasBowl) soup.TryServe();
                        else controller.TryDeliverXianTo(customer.Id, new(ProductKind.Hulatang, "hulatang"), soup.TryTake);
                    }
                }
                session.Tick(dt); controller.Tick(dt);
            }
            var result = controller.Ledger!.Build();
            Check(controller.State == DayState.Results && result.CompletedCustomers == config.CustomerCount && result.IncorrectOrders == 0, $"Day {day}真实库存生产至全部顾客完成");
            var commit = save.CommitDay(result, controller.CurrentPlan!, config);
            foreach (var upgrade in config.CompletionUnlocks) save.TryPurchase(StableIds.Cities.Xian, upgrade, _catalog, out _);
            GD.Print($"XIAN_SIM day={day} completed={result.CompletedCustomers} chops={session.Board.CompletedChops} no_bun={session.NoBunSeconds:0.0}s no_meat={session.NoChoppedMeatSeconds:0.0}s coins={save.Data.Coins}");
            controller.QueueFree();
        }
        Check(save.Data.Xian.Completed && save.Data.Xian.BestStars == 3 && save.Data.Xian.HighestUnlockedDay == 12, "零初始金币完整12天升级并三星点亮西安");
    }
}
