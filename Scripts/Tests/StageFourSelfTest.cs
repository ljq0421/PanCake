using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest : Node
{
    private int _passed;
    private int _failed;

    public override void _Ready()
    {
        try
        {
            DataCatalog catalog = GetNode<DataCatalog>("/root/DataCatalog");
            TestCatalog(catalog);
            TestArtCatalog();
            TestCustomerAppearances(catalog);
            TestFryers(catalog);
            TestSoyMilk();
            TestOrderProgress(catalog);
            TestGenerator(catalog);
            TestAllDaysCompletable(catalog);
            TestFullChapterController(catalog);
            TestStarsAndSave(catalog);
            TestScenes(catalog);
        }
        catch (Exception exception)
        {
            Fail("阶段 4 自测未处理异常", exception.ToString());
        }

        GD.Print($"阶段 4 自测完成：{_passed} 项通过，{_failed} 项失败。");
        GetTree().Quit(_failed == 0 ? 0 : 1);
    }

    private void TestCatalog(DataCatalog catalog)
    {
        Check(catalog.IsValid, "完整天津数据目录通过校验", string.Join(" | ", catalog.ValidationIssues));
        Check(catalog.DaysByNumber.Count == 15, "Day 1～15 连续加载");
        Check(catalog.ProductsById.Count == 4 && catalog.ProductsById[StableIds.Products.Youtiao].UnitPrice == 2
            && catalog.ProductsById[StableIds.Products.SoyMilk].UnitPrice == 3
            && catalog.ProductsById[StableIds.Products.Doupi].UnitPrice == 5
            && catalog.ProductsById[StableIds.Products.EggRiceWine].UnitPrice == 4, "天津与武汉独立商品价格准确");
        Check(catalog.FryersByLevel.Count == 3 && catalog.FryersByLevel[1].Capacity == 6
            && catalog.FryersByLevel[2].Capacity == 8 && catalog.FryersByLevel[3].AutoRaise, "三级油条锅资源准确");
        Check(catalog.CustomersById.Count == 9, "天津与武汉顾客资源齐全");
        CheckCustomer(catalog, "office_worker", 10.8, 21.6, 30.24, 36, .2);
        CheckCustomer(catalog, "regular", 18, 36, 50.4, 60, .1);
        CheckCustomer(catalog, "big_order", 20.4, 40.8, 57.12, 68, .1);

        int expectedTotal = catalog.DaysByNumber.Values.Sum(day => day.ExpectedRevenue);
        Check(expectedTotal == 2328, "15 天累计预期收入为 ¥2328", expectedTotal.ToString());
        int upgradeTotal = catalog.IngredientStationsByLevel.Values.Where(item => item.Level > 1).Sum(item => item.UpgradePrice)
            + catalog.StovesByLevel.Values.Where(item => item.Level > 1).Sum(item => item.UpgradePrice)
            + catalog.FryersByLevel.Values.Where(item => item.Level > 1).Sum(item => item.UpgradePrice);
        Check(upgradeTotal == 1140, "全部升级总价为 ¥1140", upgradeTotal.ToString());

        int[] seconds = { 90, 100, 110, 115, 120, 130, 130, 140, 150, 165, 180 };
        int[] customers = { 10, 11, 13, 14, 14, 16, 16, 18, 20, 22, 26 };
        int[] revenues = { 76, 94, 126, 132, 148, 184, 188, 224, 260, 300, 356 };
        for (int day = 5; day <= 15; day++)
        {
            DayConfig config = catalog.DaysByNumber[day]; int index = day - 5;
            Check(Close(config.DurationSeconds, seconds[index]) && config.CustomerCount == customers[index]
                && config.ExpectedRevenue == revenues[index] && config.RandomSeed == 1000 + day, $"Day {day} 基线数值准确");
        }
    }

    private void TestArtCatalog()
    {
        var art = new TianjinArtCatalog();
        Check(art.MissingRequiredAssets().Count == 0, "天津第一章美术映射全部可加载", string.Join(" | ", art.MissingRequiredAssets()));
        Check(art.Stove(1) != art.Stove(2) && art.Stove(2) != art.Stove(3), "煎饼炉 Lv1～Lv3 使用独立图片");
        Check(art.Fryer(1) != art.Fryer(2) && art.Fryer(2) != art.Fryer(3), "油条锅 Lv1～Lv3 使用独立图片");
        Check(art.FryerBasket(1) != art.FryerBasket(2) && ReferenceEquals(art.FryerBasket(2), art.FryerBasket(3)), "Lv1 使用 6 根滤篮，Lv2/Lv3 共用 8 根滤篮");
        Check(FryerVisualView.SlotCountForLevel(1) == 6 && FryerVisualView.SlotCountForLevel(2) == 8
            && FryerVisualView.SlotCountForLevel(3) == 8, "Lv1 使用六槽布局，Lv2/Lv3 使用八槽布局");
        Check(Enumerable.Range(1, 3).All(FryerVisualView.LayoutMeetsConstraints), "炸锅槽位位置、角度、缩放与绘制顺序满足视觉约束");
        Check(Enumerable.Range(1, 3).All(FryerVisualView.LoweredBasketFitsInnerFrame), "下锅后滤篮外框与各级炸锅内框对齐且下边缘不越界");
        Check(!ReferenceEquals(art.FoldedPancake, art.FinishedPancake), "折叠煎饼与装袋成品使用独立素材");
        Check(art.PancakeBurntOverlay.GetWidth() > 0 && art.BurntYoutiao.GetWidth() > 0, "煎饼和油条焦糊状态素材可加载");
        Check(art.ServingTray.GetWidth() > 0 && art.YoutiaoRack.GetWidth() > 0 && art.Trash.GetWidth() > 0, "出餐、沥油和垃圾桶功能素材可加载");
        Check(art.MapBackground.GetWidth() == 1672 && art.MapBackground.GetHeight() == 941
            && art.TianjinMapNode.GetWidth() > 0 && art.LockedMapNode.GetWidth() > 0, "地图背景与城市节点素材可加载");
        Check(CustomerAppearanceCatalog.All.Count == 24 && CustomerAppearanceCatalog.All.Select(item => item.Id).Distinct().Count() == 24,
            "天津顾客目录包含 24 套唯一外观");
        Check(CustomerAppearanceCatalog.CandidatesFor("normal").Count == 24
            && CustomerAppearanceCatalog.CandidatesFor("office_worker").Count == 9
            && CustomerAppearanceCatalog.CandidatesFor("regular").Count == 9
            && CustomerAppearanceCatalog.CandidatesFor("big_order").Count == 6, "普通与三类特殊顾客外观池数量准确");
        foreach (CustomerAppearanceDefinition appearance in CustomerAppearanceCatalog.All)
        {
            CustomerPortraitVisual[] portraits = Enum.GetValues<CustomerExpression>().Select(expression => art.CustomerPortrait(appearance.Id, expression)).ToArray();
            Check(portraits.All(portrait => ReferenceEquals(portrait.Body, portraits[0].Body))
                && portraits.Select(portrait => portrait.Head).Distinct().Count() == 4, $"{appearance.DisplayName} 固定身体并切换四张完整头部");
            Check(portraits.All(portrait => portrait.Body.GetWidth() == 1086 && portrait.Body.GetHeight() == 1448
                && portrait.Head.GetWidth() == 1086 && portrait.Head.GetHeight() == 1448), $"{appearance.DisplayName} 分层素材画布统一为 1086×1448");
        }
        Check(ReferenceEquals(art.CustomerBody("young_woman"), art.CustomerBody("missing_appearance"))
            && ReferenceEquals(art.CustomerHead("young_woman", CustomerExpression.Normal), art.CustomerHead("missing_appearance", CustomerExpression.Normal)),
            "缺失顾客外观稳定回退到年轻女性");
        Check(TianjinArtCatalog.ResolveCustomerExpression(CustomerState.Entering) == CustomerExpression.Normal
            && TianjinArtCatalog.ResolveCustomerExpression(CustomerState.Happy) == CustomerExpression.Happy
            && TianjinArtCatalog.ResolveCustomerExpression(CustomerState.Normal) == CustomerExpression.Normal
            && TianjinArtCatalog.ResolveCustomerExpression(CustomerState.Impatient) == CustomerExpression.Impatient
            && TianjinArtCatalog.ResolveCustomerExpression(CustomerState.Angry) == CustomerExpression.Angry,
            "顾客等待状态逐一映射到完整头部表情");
        Check(TianjinArtCatalog.ResolveCustomerExpression(CustomerState.Leaving, true) == CustomerExpression.Happy
            && TianjinArtCatalog.ResolveCustomerExpression(CustomerState.Leaving, false) == CustomerExpression.Angry,
            "成功离场保持开心，流失离场保持生气");
        Check(art.Background.GetWidth() == 1920 && art.Background.GetHeight() == 1080, "营业背景运行版本固定为 1920×1080");
        Check(art.StoveVisual(3).DisplaySize.X > 0 && art.ProductVisual(ProductKind.SoyMilk).DisplaySize.Y > 0, "设备与商品映射包含独立显示规格");
        var secondCatalog = new TianjinArtCatalog();
        Check(ReferenceEquals(art.Ingredient(StableIds.Ingredients.Ham), secondCatalog.Ingredient(StableIds.Ingredients.Ham)), "多界面共享已裁切纹理缓存");
    }

    private void TestCustomerAppearances(DataCatalog catalog)
    {
        IReadOnlyList<string> office = CustomerAppearanceCatalog.CandidatesFor("office_worker");
        IReadOnlyList<string> regular = CustomerAppearanceCatalog.CandidatesFor("regular");
        IReadOnlyList<string> bigOrder = CustomerAppearanceCatalog.CandidatesFor("big_order");
        Check(office.Contains("delivery_rider") && office.Contains("taxi_driver") && office.Contains("tianjin_port_worker"),
            "赶时间顾客池包含通勤与工作身份");
        Check(regular.Contains("morning_elder") && regular.Contains("culture_street_shopkeeper") && regular.Contains("kite_artisan"),
            "熟客池包含社区与传统手艺身份");
        Check(bigOrder.Contains("female_office") && bigOrder.Contains("tourist") && bigOrder.Contains("culture_street_owner"),
            "大订单顾客池包含已确认身份");
        Check(CustomerAppearanceCatalog.Select("missing_type", 1001, "C001") == CustomerAppearanceCatalog.DefaultAppearanceId,
            "未知顾客类型回退到年轻女性外观");

        string[] first = BuildAppearanceSequence(catalog, 1001);
        string[] second = BuildAppearanceSequence(catalog, 1001);
        Check(first.SequenceEqual(second), "相同种子与队列流程复现相同外观序列");
        Check(first.Distinct(StringComparer.Ordinal).Count() == first.Length, "五名同屏顾客外观互不重复");
    }

    private void TestFryers(DataCatalog catalog)
    {
        var level1 = new FryerStateMachine(catalog.FryersByLevel[1]);
        for (int index = 0; index < 6; index++) Check(level1.TryExecute(FryerCommand.LoadOne).Success, $"Lv1 装入第 {index + 1} 根油条");
        Check(!level1.TryExecute(FryerCommand.LoadOne).Success, "Lv1 容量严格限制为 6 根");
        Check(level1.TryExecute(FryerCommand.LowerBasket).Success, "炸篮可下锅");
        level1.Tick(5.99); Check(level1.Runtime.Quality == YoutiaoQuality.Light, "6 秒前为偏浅");
        level1.Tick(.01); Check(level1.Runtime.Quality == YoutiaoQuality.Golden, "6 秒进入金黄");
        level1.Tick(2.51); Check(level1.Runtime.Quality == YoutiaoQuality.Deep, "8.5 秒后进入偏深");
        Check(level1.TryExecute(FryerCommand.RaiseBasket).Success && level1.Runtime.State == FryerState.Draining, "手动抬篮开始沥油");
        level1.Tick(.59); Check(level1.Inventory.Count == 0, "0.6 秒前尚未入沥油库存");
        level1.Tick(.01); Check(level1.Inventory.Count == 6 && level1.Inventory.CountQuality(YoutiaoQuality.Deep) == 6, "整批偏深品质写入库存");

        var burnt = new FryerStateMachine(catalog.FryersByLevel[1]);
        burnt.TryExecute(FryerCommand.LoadOne); burnt.TryExecute(FryerCommand.LowerBasket); burnt.Tick(11.01);
        Check(burnt.Runtime.State == FryerState.Burnt && !burnt.TryExecute(FryerCommand.RaiseBasket).Success, "超过 11 秒焦糊且不能入库");
        Check(burnt.TryExecute(FryerCommand.Discard).Success && burnt.Runtime.State == FryerState.Empty, "焦糊批次只能清理");

        var fifo = new YoutiaoInventory(3);
        fifo.TryStore(1, YoutiaoQuality.Light); fifo.TryStore(1, YoutiaoQuality.Golden); fifo.TryStore(1, YoutiaoQuality.Deep);
        fifo.TryTake(out YoutiaoQuality first); fifo.TryTake(out YoutiaoQuality second); fifo.TryTake(out YoutiaoQuality third);
        Check(first == YoutiaoQuality.Light && second == YoutiaoQuality.Golden && third == YoutiaoQuality.Deep, "沥油库存按单根品质 FIFO 取用");
        Check(!fifo.TryStore(1, YoutiaoQuality.Burnt), "焦糊油条不能入库存");

        var blocked = new FryerStateMachine(catalog.FryersByLevel[1]);
        blocked.Inventory.TryStore(6, YoutiaoQuality.Golden);
        blocked.TryExecute(FryerCommand.LoadOne); blocked.TryExecute(FryerCommand.LowerBasket); blocked.Tick(6); blocked.TryExecute(FryerCommand.RaiseBasket);
        Check(blocked.Runtime.State == FryerState.Raised, "沥油区满时炸篮保持抬起");
        blocked.Inventory.TryTake(out _); blocked.Tick(.01); Check(blocked.Runtime.State == FryerState.Draining, "腾出容量后自动开始沥油");

        var level3 = new FryerStateMachine(catalog.FryersByLevel[3]);
        level3.TryExecute(FryerCommand.LoadOne); level3.TryExecute(FryerCommand.LowerBasket); level3.Tick(5.49);
        Check(level3.Runtime.State == FryerState.Frying, "Lv3 自动抬篮时点前继续炸制");
        level3.Tick(.01); Check(level3.Runtime.State == FryerState.Draining && Close(level3.Runtime.FrySeconds, 5.5)
            && level3.Runtime.Quality == YoutiaoQuality.Golden, "Lv3 在 5.5 秒自动抬篮并停止熟制");
        level3.Tick(.6); Check(level3.Inventory.Count == 1, "Lv3 自动沥油后入库");
    }

    private void TestSoyMilk()
    {
        var tray = new SoyMilkTrayRuntime();
        Check(tray.Capacity == 6 && tray.Quantity == 6, "豆浆托盘容量为 6 杯");
        Check(tray.TryConsumeForDelivery() && tray.Quantity == 5 && tray.IsTaking, "合法交付立即扣除一杯");
        tray.Tick(.29); Check(tray.IsTaking, "取杯反馈持续 0.3 秒"); tray.Tick(.01); Check(!tray.IsTaking, "取杯反馈按时结束");
        Check(tray.TryBeginRefill(), "未满托盘可开始补货"); tray.Tick(.59); Check(tray.Quantity == 5, "0.6 秒前不补满"); tray.Tick(.01);
        Check(tray.Quantity == 6 && !tray.IsRefilling, "0.6 秒后补满豆浆");
    }

    private void TestOrderProgress(DataCatalog catalog)
    {
        OrderData combo = Order("combo", "office_worker", 16,
            Pancake(StableIds.Recipes.ScallionCrispy), Youtiao(2), SoyMilk());
        var progress = new OrderProgress(combo);
        Check(progress.TryAccept(new DeliveredItem(ProductKind.Pancake, StableIds.Recipes.ScallionCrispy, PancakeQuality.Perfect)).Accepted
            && !progress.IsComplete, "多件订单先交煎饼返回 Incomplete 状态");
        progress.TryAccept(new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, null, YoutiaoQuality.Golden));
        progress.TryAccept(new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, null, YoutiaoQuality.Golden));
        Check(!progress.IsComplete, "尚缺豆浆时订单不结算");
        Check(progress.TryAccept(new DeliveredItem(ProductKind.SoyMilk, StableIds.Products.SoyMilk)).OrderComplete, "最后一件商品补齐订单");
        DeliveryEvaluation perfect = new OrderEvaluator().EvaluateCompleted(progress, CustomerState.Happy, catalog.CustomersById["office_worker"]);
        Check(perfect.Grade == DeliveryGrade.Perfect && perfect.SaleRevenue == 16 && perfect.Tip == 4, "上班族完美套餐获得 20% 向上取整小费");
        Check(!progress.TryAccept(new DeliveredItem(ProductKind.SoyMilk, StableIds.Products.SoyMilk)).Accepted, "完整订单拒绝额外商品");

        OrderData wrongOrder = Order("wrong", "normal", 10, Pancake(StableIds.Recipes.Basic), SoyMilk());
        var wrong = new OrderProgress(wrongOrder);
        Check(wrong.TryAccept(new DeliveredItem(ProductKind.Pancake, StableIds.Recipes.Crispy, PancakeQuality.Perfect)).Accepted
            && wrong.HasRecipeMismatch && !wrong.IsComplete, "错误煎饼占用未完成需求并继续等待");
        wrong.TryAccept(new DeliveredItem(ProductKind.SoyMilk, StableIds.Products.SoyMilk));
        DeliveryEvaluation incorrect = new OrderEvaluator().EvaluateCompleted(wrong, CustomerState.Happy, catalog.CustomersById["normal"]);
        Check(incorrect.Grade == DeliveryGrade.Incorrect && incorrect.SaleRevenue == 7 && incorrect.Tip == 0, "错件整单按 70% 结算");

        OrderData internalOrder = Order("internal", "normal", 9, Pancake(StableIds.Recipes.Youtiao));
        var internalProgress = new OrderProgress(internalOrder);
        internalProgress.TryAccept(new DeliveredItem(ProductKind.Pancake, StableIds.Recipes.Youtiao, PancakeQuality.Perfect, null, YoutiaoQuality.Light));
        DeliveryEvaluation internalQuality = new OrderEvaluator().EvaluateCompleted(internalProgress, CustomerState.Happy, catalog.CustomersById["normal"]);
        Check(internalQuality.Grade == DeliveryGrade.Correct, "P6/P7 内部偏浅油条把整单品质限制为 Correct");
    }

    private void TestGenerator(DataCatalog catalog)
    {
        var generator = new OrderGenerator();
        foreach (int day in Enumerable.Range(5, 11))
        {
            DayConfig config = catalog.DaysByNumber[day];
            DayPlan first = generator.Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
            DayPlan second = generator.Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
            Check(JsonSerializer.Serialize(first) == JsonSerializer.Serialize(second), $"Day {day} 同种子逐字段一致");
            Check(first.Customers.Count == config.CustomerCount && first.Customers.All(item => item.ArrivalTime > 0 && item.ArrivalTime < config.DurationSeconds), $"Day {day} 顾客数与到店边界合法");
            Check(first.Customers.Count(item => item.CustomerTypeId == "big_order") <= config.Constraints.MaxBigOrderCustomers, $"Day {day} 大订单不超过上限");
            Check(MaxYoutiaoRun(first) <= 2, $"Day {day} 最多连续两单含油条");
            Check(first.Customers.All(item => item.Order.Lines.Where(line => line.ProductKind == ProductKind.Pancake).Sum(line => line.Quantity) <= config.Constraints.MaxPancakesPerCustomer), $"Day {day} 单客煎饼数符合上限");
        }

        DayPlan day5 = Generate(catalog, 5);
        OrderData[] youtiaoOrders = day5.Customers.Select(item => item.Order).Where(order => order.Lines.Any(line => line.ProductKind == ProductKind.Youtiao)).Take(2).ToArray();
        Check(youtiaoOrders.Length == 2 && IsOnlyYoutiao(youtiaoOrders[0], 1) && IsOnlyYoutiao(youtiaoOrders[1], 2), "Day 5 前两份油条单固定为 1 根、2 根");
        DayPlan day7 = Generate(catalog, 7);
        string[] internalRecipes = day7.Customers.SelectMany(item => item.Order.Lines).Where(line => line.ProductKind == ProductKind.Pancake
            && line.DefinitionId is StableIds.Recipes.Youtiao or StableIds.Recipes.ScallionYoutiao).Select(line => line.DefinitionId).Take(2).ToArray();
        Check(internalRecipes.SequenceEqual(new[] { StableIds.Recipes.Youtiao, StableIds.Recipes.ScallionYoutiao }), "Day 7 前两份内部油条煎饼固定为 P6、P7");
        DayPlan day9 = Generate(catalog, 9);
        OrderData[] soyOrders = day9.Customers.Select(item => item.Order).Where(order => order.Lines.Any(line => line.ProductKind == ProductKind.SoyMilk)).Take(2).ToArray();
        Check(soyOrders.Length == 2 && soyOrders[0].Lines.Count == 1 && soyOrders[0].Lines[0].ProductKind == ProductKind.SoyMilk
            && soyOrders[1].Lines.Any(line => line.ProductKind == ProductKind.Pancake && line.DefinitionId == StableIds.Recipes.Basic), "Day 9 前两份豆浆单固定为单杯、P0＋豆浆");

        foreach (PlannedCustomer regular in Generate(catalog, 15).Customers.Where(item => item.CustomerTypeId == "regular"))
            Check(regular.Order.Lines.Count == 2 && regular.Order.Lines.Any(line => line.DefinitionId == StableIds.Recipes.ScallionCrispy)
                && regular.Order.Lines.Any(line => line.ProductKind == ProductKind.SoyMilk), "老顾客固定点 P3＋豆浆");
    }

    private void TestAllDaysCompletable(DataCatalog catalog)
    {
        var evaluator = new OrderEvaluator();
        int completed = 0;
        foreach (int day in Enumerable.Range(1, 15))
        {
            DayPlan plan = Generate(catalog, day);
            foreach (PlannedCustomer customer in plan.Customers)
            {
                var progress = new OrderProgress(customer.Order);
                foreach (OrderLineData line in customer.Order.Lines)
                {
                    for (int quantity = 0; quantity < line.Quantity; quantity++)
                    {
                        DeliveredItem item = line.ProductKind switch
                        {
                            ProductKind.Pancake => new DeliveredItem(ProductKind.Pancake, line.DefinitionId, PancakeQuality.Perfect, null,
                                line.DefinitionId is StableIds.Recipes.Youtiao or StableIds.Recipes.ScallionYoutiao ? YoutiaoQuality.Golden : null),
                            ProductKind.Youtiao => new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, null, YoutiaoQuality.Golden),
                            _ => new DeliveredItem(ProductKind.SoyMilk, StableIds.Products.SoyMilk),
                        };
                        Check(progress.TryAccept(item).Accepted, $"Day {day} 计划商品可逐件交付");
                    }
                }
                DeliveryEvaluation result = evaluator.EvaluateCompleted(progress, CustomerState.Happy, catalog.CustomersById[customer.CustomerTypeId]);
                Check(progress.IsComplete && result.Grade == DeliveryGrade.Perfect, $"Day {day} 订单可无残留完成");
                completed++;
            }
        }
        Check(completed == catalog.DaysByNumber.Values.Sum(day => day.CustomerCount), "全 15 天确定性模拟覆盖所有计划顾客");
    }

    private void TestFullChapterController(DataCatalog catalog)
    {
        foreach (int day in Enumerable.Range(1, 15))
        {
            var controller = new DayController(); AddChild(controller);
            DayResult? result = null; controller.DayFinished += value => result = value;
            controller.TryPrepareDay(day, catalog, out _); controller.TryStartDay(out _); controller.Tick(3);
            var pancake = new PancakeStateMachine(catalog.StovesByLevel[3]);
            var youtiao = new YoutiaoInventory(32);
            var soy = new SoyMilkTrayRuntime(32);
            int maximumSteps = (int)((catalog.DaysByNumber[day].DurationSeconds + 20) / .05);
            for (int step = 0; step < maximumSteps && controller.State != DayState.Results; step++)
            {
                controller.Tick(.05); soy.Tick(.05);
                CustomerRuntime? customer = controller.CustomerQueue?.Slots.FirstOrDefault(item => item.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry);
                if (customer is null) continue;
                controller.CustomerQueue!.TrySelect(customer.Id);
                for (int lineIndex = 0; lineIndex < customer.Order.Lines.Count; lineIndex++)
                {
                    OrderLineData line = customer.Order.Lines[lineIndex];
                    for (int quantity = customer.Progress.GetDeliveredQuantity(lineIndex); quantity < line.Quantity; quantity++)
                    {
                        if (line.ProductKind == ProductKind.Pancake)
                        {
                            MakeBagged(pancake, catalog.RecipesById[line.DefinitionId]);
                            DeliveryEvaluation delivery = controller.TryDeliverSelected(pancake, catalog);
                            Check(delivery.Grade != DeliveryGrade.Rejected, $"Day {day} 营业闭环接收煎饼");
                            pancake.TryExecute(PancakeCommand.Discard);
                        }
                        else if (line.ProductKind == ProductKind.Youtiao)
                        {
                            youtiao.TryStore(1, YoutiaoQuality.Golden);
                            Check(controller.TryDeliverYoutiaoSelected(youtiao).Grade != DeliveryGrade.Rejected, $"Day {day} 营业闭环接收独立油条");
                        }
                        else
                        {
                            if (!soy.CanStartDrag) soy.Tick(.3);
                            Check(controller.TryDeliverSoyMilkSelected(soy).Grade != DeliveryGrade.Rejected, $"Day {day} 营业闭环接收豆浆");
                        }
                    }
                }
            }
            Check(result is not null && result.CompletedCustomers == catalog.DaysByNumber[day].CustomerCount && result.LostCustomers == 0,
                $"Day {day} 从开店、逐件出餐到结算完整闭环");
            controller.QueueFree();
        }
    }

    private void TestStarsAndSave(DataCatalog catalog)
    {
        DayConfig day15 = catalog.DaysByNumber[15];
        Check(SaveService.EvaluateStars(Result(15, 18, 70, 0), day15) == 1, "Day 15 一星边界准确");
        Check(SaveService.EvaluateStars(Result(15, 22, 82, 0), day15) == 2, "Day 15 二星边界准确");
        Check(SaveService.EvaluateStars(Result(15, 24, 90, 15), day15) == 3, "Day 15 三星边界准确");
        Check(SaveService.EvaluateStars(Result(15, 24, 89.9, 15), day15) == 2, "未满足三星满意度时不越级");

        string current = $"user://stage4-v2-{Guid.NewGuid():N}.json";
        string legacy = $"user://stage4-v1-{Guid.NewGuid():N}.json";
        string legacyAbsolute = ProjectSettings.GlobalizePath(legacy);
        Directory.CreateDirectory(Path.GetDirectoryName(legacyAbsolute)!);
        File.WriteAllText(legacyAbsolute, "{\"Version\":1,\"Coins\":500,\"HighestUnlockedDay\":4,\"PurchasedStoveLevel\":2,\"PurchasedIngredientStationLevel\":2,\"UnlockedUpgradeIds\":[],\"DayBestRecords\":{\"4\":{\"TotalRevenue\":82,\"CompletedCustomers\":10,\"PerfectOrders\":5,\"HighestCorrectStreak\":3,\"Satisfaction\":90,\"YoutiaoUsed\":0,\"YoutiaoBurnt\":0}},\"LastDayPlan\":null}");
        var save = new SaveService(); AddChild(save); save.UsePathsForTests(current, legacy);
        Check(save.MigratedLegacySave && save.Data.Version == SaveService.CurrentVersion && save.Data.Coins == 500 && save.Data.HighestUnlockedDay == 5
            && save.Data.PurchasedFryerLevel == 1, "v1 存档自动迁移并保留阶段 3 进度");
        Check(File.Exists(save.CorruptBackupPath), "迁移前保留带时间戳的 v1 备份");

        foreach (int day in new[] { 7, 10, 11, 12 })
            save.CommitDay(Result(day, 1, 100, 1), Generate(catalog, day), catalog.DaysByNumber[day]);
        Check(save.Data.UnlockedUpgradeIds.Contains("equipment:fryer_lv2") && save.Data.UnlockedUpgradeIds.Contains("equipment:ingredient_station_lv3")
            && save.Data.UnlockedUpgradeIds.Contains("equipment:pancake_stove_lv3") && save.Data.UnlockedUpgradeIds.Contains("equipment:fryer_lv3"), "Day 7/10/11/12 按顺序开放三级升级");

        save.CommitDay(Result(15, 24, 90, 15, 356), Generate(catalog, 15), day15);
        Check(save.Data.TianjinCompleted && save.Data.TianjinBestStars == 3 && save.Data.UnlockedCityIds.Contains("city:wuhan"), "Day 15 三星点亮天津并开放武汉占位");
        save.CommitDay(Result(15, 18, 70, 0, 100), Generate(catalog, 15), day15);
        Check(save.Data.TianjinBestStars == 3, "重玩低星级不会降低历史最高星级");

        save.QueueFree();
        DeleteIfExists(ProjectSettings.GlobalizePath(current)); DeleteIfExists(legacyAbsolute);
        foreach (string backup in Directory.GetFiles(Path.GetDirectoryName(legacyAbsolute)!, Path.GetFileName(legacyAbsolute) + ".v1-backup-*.bak")) DeleteIfExists(backup);
    }

    private void TestScenes(DataCatalog catalog)
    {
        var hub = new MorningHub();
        Check(!hub.DeveloperToolsVisible, "正式启动参数不显示煎饼实验台与 Day 数据入口");
        hub.Free();
        foreach (string path in new[] { "res://Scenes/Main/Main.tscn", "res://Scenes/UI/TianjinMapScreen.tscn", "res://Scenes/Gameplay/TianjinDayScreen.tscn" })
            Check(ResourceLoader.Load<PackedScene>(path) is not null, $"阶段 4 场景可加载：{path.GetFile()}");
        Node main = ResourceLoader.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate();
        Check(main.HasNode("UI/TianjinMapScreen"), "Main 接入天津完成与武汉占位地图");
        main.Free();

        var dayLayout = new TianjinDayScreen();
        AddChild(dayLayout);
        var customerStrip = dayLayout.FindChild("CustomerStrip", true, false) as HBoxContainer;
        var feedbackPanel = dayLayout.FindChild("FeedbackPanel", true, false) as Control;
        float customerContentWidth = customerStrip?.GetChildren().OfType<Button>()
            .Sum(button => button.CustomMinimumSize.X) ?? float.MaxValue;
        int visibleSlotGaps = Math.Max(0, (customerStrip?.GetChildCount() ?? 0) - 1) * 12;
        Check(customerStrip is { Position.Y: 160, Size.X: 1812, Size.Y: 415 }
            && customerStrip.Position.Y + customerStrip.Size.Y == 575
            && customerContentWidth + visibleSlotGaps <= customerStrip.Size.X, "顾客区延伸至桌面上沿且五个顾客槽不会横向溢出");
        var firstCustomerSlot = customerStrip?.GetChildren().OfType<Button>().FirstOrDefault();
        var customerColumn = firstCustomerSlot?.FindChild("CustomerColumn", true, false) as Control;
        var portraitStack = firstCustomerSlot?.FindChild("PortraitStack", true, false) as Control;
        var portrait = portraitStack?.GetChildren().OfType<CustomerPortraitView>().FirstOrDefault();
        var patience = portraitStack?.GetChildren().OfType<ProgressBar>().FirstOrDefault();
        Check(firstCustomerSlot is { CustomMinimumSize.Y: 415 }
            && customerColumn is { AnchorBottom: 1, OffsetBottom: 0 }
            && portraitStack is { ClipContents: true, SizeFlagsVertical: Control.SizeFlags.ExpandFill }
            && portrait is { AnchorBottom: 1 }
            && patience is { AnchorTop: 1, AnchorBottom: 1, OffsetTop: -14, OffsetBottom: 0 },
            "人物视窗占满桌沿区域且耐心条叠加在人物底部");
        Check(customerStrip is not null && feedbackPanel is not null
            && feedbackPanel.Position.Y < customerStrip.Position.Y + customerStrip.Size.Y
            && feedbackPanel.ZIndex > customerStrip.ZIndex, "短时反馈以更高层级覆盖顾客下半身");
        dayLayout.QueueFree();

        var workstation = new PancakeWorkstation();
        AddChild(workstation);
        workstation.Initialize(catalog, 1, 1, 1, catalog.DaysByNumber[5], new TianjinArtCatalog());
        Check(workstation.FindChild("FryerVisual", true, false) is FryerVisualView, "工作台使用锅体与滤篮分层的炸锅视图");
        Check(workstation.FindChild("FryerStack", true, false) is Control { Size: var fryerSize }
            && fryerSize.X == 340 && fryerSize.Y == 340, "桌面炸锅收进紧凑的左侧生产闭环");
        Check(workstation.FindChild("FinishedYoutiaoArea", true, false) is VBoxContainer
            && workstation.FindChild("FinishedYoutiaoStock", true, false) is Label
            && workstation.FindChild("FinishedYoutiaoDrag", true, false) is DragItem, "成品油条库存与拖拽入口合并显示且不再使用独立沥油架");
        Check(workstation.FindChild("TrashZone", true, false) is not null, "工作台接入可拖放垃圾桶");
        string[] framelessAreas = { "FryerArea", "StoveArea", "IngredientArea", "DeliveryArea" };
        Check(framelessAreas.All(name => workstation.FindChild(name, true, false) is Control and not PanelContainer), "四个设备区域使用无框场景容器");
        WorkstationSlotView[] ingredientSlots = workstation.FindChildren("IngredientSlot_*", "Control", true, false)
            .OfType<WorkstationSlotView>().ToArray();
        Check(ingredientSlots.Length == 6, "六个配料槽统一使用工作台槽位组件");
        Check(ingredientSlots.All(slot => slot.IngredientIsInsideTray(4)), "六个配料图片均位于托盘安全边界内");
        var rawSlot = workstation.FindChild("RawYoutiaoSlot", true, false) as WorkstationSlotView;
        Check(rawSlot is not null && rawSlot.IngredientIsInsideTray(8), "生油条缩小并居中收进托盘安全边界");
        Check(ingredientSlots.All(slot => slot.ClickBounds.Size.X >= 48 && slot.ClickBounds.Size.Y >= 48)
            && rawSlot is not null && rawSlot.ClickBounds.Size.X >= 48 && rawSlot.ClickBounds.Size.Y >= 48, "食材与生油条槽位点击区域不小于 48×48");
        var utilityArea = workstation.FindChild("DeliveryArea", true, false) as Control;
        var ingredientArea = workstation.FindChild("IngredientArea", true, false) as Control;
        var deliveryZone = workstation.FindChild("DeliveryDropZone", true, false) as DropZone;
        var finishedSlot = workstation.FindChild("FinishedPancakeSlot", true, false) as Control;
        var soyMilkSlot = workstation.FindChild("SoyMilkSlot", true, false) as Control;
        var trashZone = workstation.FindChild("TrashZone", true, false) as DropZone;
        var servingTrayArt = workstation.FindChild("ServingTrayArt", true, false) as TextureRect;
        var trashArt = workstation.FindChild("TrashArt", true, false) as TextureRect;
        var trashButton = workstation.FindChild("TrashButton", true, false) as Button;
        string utilityLayoutDetails = string.Join(" | ", new Control?[] { utilityArea, deliveryZone, finishedSlot, soyMilkSlot, trashZone }
            .Select(control => control is null ? "null" : $"{control.Name}@{control.Position}/{control.Size}"));
        Check(utilityArea is { Position: var utilityPosition, Size: var utilitySize }
            && utilityPosition == new Vector2(1218, 578) && utilitySize == new Vector2(666, 112),
            "出餐、豆浆与丢弃辅助区使用加高后的固定工作台区域");
        Check(utilityArea is not null && ingredientArea is not null
            && utilityArea.Position.Y + utilityArea.Size.Y <= ingredientArea.Position.Y
            && ingredientArea.Position.Y + ingredientArea.Size.Y <= 1080, "右侧辅助区与配料区上下分区且不越界");
        Check(deliveryZone is { Position: var deliveryPosition, Size: var deliverySize }
            && deliveryPosition == new Vector2(33, 2) && deliverySize == new Vector2(174, 108)
            && finishedSlot is { Position: var finishedPosition, Size: var finishedSize }
            && finishedPosition == new Vector2(215, 10) && finishedSize == new Vector2(138, 92)
            && soyMilkSlot is { Position: var soyPosition, Size: var soySize }
            && soyPosition == new Vector2(361, 10) && soySize == new Vector2(144, 92)
            && trashZone is { Position: var trashPosition, Size: var trashSize }
            && trashPosition == new Vector2(513, 2) && trashSize == new Vector2(120, 108),
            "辅助槽按出餐、成品、豆浆、丢弃顺序使用固定尺寸和位置", utilityLayoutDetails);
        Check(deliveryZone is not null && finishedSlot is not null && soyMilkSlot is not null && trashZone is not null
            && deliveryZone.Position.X + deliveryZone.Size.X + 8 == finishedSlot.Position.X
            && finishedSlot.Position.X + finishedSlot.Size.X + 8 == soyMilkSlot.Position.X
            && soyMilkSlot.Position.X + soyMilkSlot.Size.X + 8 == trashZone.Position.X,
            "四个辅助槽保持 8px 横向间距且互不重叠", utilityLayoutDetails);
        Control?[] utilitySlots = { deliveryZone, finishedSlot, soyMilkSlot, trashZone };
        Check(utilityArea is not null && utilitySlots.All(slot => slot is not null
            && slot.Position.X >= 0 && slot.Position.Y >= 0
            && slot.Position.X + slot.Size.X <= utilityArea.Size.X
            && slot.Position.Y + slot.Size.Y <= utilityArea.Size.Y),
            "四个辅助槽完整位于辅助区内", utilityLayoutDetails);
        Check(finishedSlot is { CustomMinimumSize: var finishedSlotSize }
            && finishedSlotSize == new Vector2(138, 92), "装袋成品隐藏时保留固定辅助槽位");
        Check(deliveryZone is not null && trashZone is not null
            && deliveryZone.Size.X >= 48 && deliveryZone.Size.Y >= 48
            && trashZone.Size.X >= 48 && trashZone.Size.Y >= 48,
            "出餐与垃圾桶拖放区域均不小于 48×48");
        string utilityVisualDetails = string.Join(" | ", new Control?[] { deliveryZone, servingTrayArt, trashZone, trashArt, trashButton }
            .Select(control => control is null ? "null" : $"{control.Name}@{control.GetGlobalRect()}"));
        Check(servingTrayArt is { StretchMode: TextureRect.StretchModeEnum.KeepAspectCentered, Texture: AtlasTexture servingTrayTexture }
            && servingTrayArt.CustomMinimumSize == deliveryZone!.CustomMinimumSize
            && servingTrayArt.GetGlobalRect() == deliveryZone.GetGlobalRect()
            && servingTrayTexture.Region == new Rect2(0, 224, 1536, 576),
            "出餐盘运行时裁掉无效画布并等比居中填入出餐区", utilityVisualDetails);
        Check(trashArt is { StretchMode: TextureRect.StretchModeEnum.KeepAspectCentered }
            && trashButton is not null && trashZone is not null
            && trashArt.CustomMinimumSize == trashZone.CustomMinimumSize
            && trashButton.CustomMinimumSize == trashZone.CustomMinimumSize
            && trashArt.GetGlobalRect() == trashZone.GetGlobalRect()
            && trashButton.GetGlobalRect() == trashZone.GetGlobalRect(),
            "垃圾桶保持等比居中且丢弃按钮完整覆盖拖放区域", utilityVisualDetails);
        Check(new[] { "FryerLowerAction", "FryerRaiseAction", "FryerDiscardAction", "PancakeFlipAction", "PancakeFoldAction", "PancakeBagAction", "PancakeDiscardAction" }
            .All(name => workstation.FindChild(name, true, false) is Button { Visible: false }), "空设备不显示无效操作，动作按钮由状态上下文控制");
        Check(workstation.FindChildren("IngredientRefill_*", "Button", true, false).Cast<Button>().All(button => !button.Visible), "满库存时隐藏补货入口");
        Check(workstation.FindChildren("IngredientStock_*", "ProgressBar", true, false).Cast<ProgressBar>().All(stock => stock.Visible && stock.Value == 100), "正常库存持续显示低干扰比例条");
        Check(workstation.FindChild("IngredientInput_sauce", true, false) is Control and not BaseButton,
            "酱料槽只展示库存，抹酱操作留在炉面轨迹");
        var batterStock = workstation.FindChild("IngredientStock_batter", true, false) as ProgressBar;
        var batterRefill = workstation.FindChild("IngredientRefill_batter", true, false) as Button;
        for (int index = 0; index < 5; index++) workstation.Inventory.TryConsume(StableIds.Ingredients.Batter);
        Check(batterStock is { Visible: true, Value: 50 }
            && batterRefill is { Visible: false }
            && workstation.FindChild("IngredientCount_batter", true, false) is Label { Text: "5/10" }, "正常库存使用当前/上限并隐藏补货入口");
        WorkstationSlotView? batterSlot = ingredientSlots.FirstOrDefault(slot => slot.Name.ToString() == "IngredientSlot_batter");
        for (int index = 0; index < 3; index++) workstation.Inventory.TryConsume(StableIds.Ingredients.Batter);
        Check(batterStock is { Visible: true, Value: 20 }
            && batterRefill is { Visible: true, Text: "+", Disabled: false }
            && workstation.FindChild("IngredientCount_batter", true, false) is Label { Text: "2/10" } lowCount
            && lowCount.Modulate == TianjinUi.Orange, "剩余两份进入低库存状态并显示一键补满入口");
        Check(batterSlot is not null && batterSlot.IngredientIsInsideTray(4), "库存视觉档位变化后仍位于托盘安全边界内");
        workstation.Inventory.TryConsume(StableIds.Ingredients.Batter, 2);
        Check(workstation.FindChild("IngredientCount_batter", true, false) is Label { Text: "0/10" } emptyCount
            && emptyCount.Modulate == TianjinUi.Red, "零库存数量使用红色且补料入口保持显示");
        workstation.Inventory.TryBeginRefill(StableIds.Ingredients.Batter);
        Check(batterStock is { Visible: true, Value: 0 } && batterRefill is { Text: "…", Disabled: true }
            && workstation.FindChild("IngredientCount_batter", true, false) is Label { Text: "0%" }, "补货中显示进度并禁用重复补货");
        workstation.CanSubmitToSelectedCustomer = () => false;
        MakeBagged(workstation.Machine, catalog.RecipesById[StableIds.Recipes.Basic]);
        Check(deliveryZone is not null && !deliveryZone.CanAccept("finished_pancake"), "未选择顾客时出餐口拒绝成品且不会提前消费");
        workstation.CanSubmitToSelectedCustomer = () => true;
        Check(deliveryZone?.CanAccept("finished_pancake") == true, "选择有效顾客后出餐口接收已装袋煎饼");
        workstation.QueueFree();
    }

    private static string[] BuildAppearanceSequence(DataCatalog catalog, int seed)
    {
        PlannedCustomer[] customers = Enumerable.Range(1, 5).Select(index => new PlannedCustomer
        {
            CustomerId = $"appearance-{index}",
            CustomerTypeId = "normal",
            ArrivalTime = 0,
            Order = Order($"appearance-order-{index}", "normal", 0),
        }).ToArray();
        var queue = new CustomerQueue(new DayPlan { Day = 1, RandomSeed = seed, Customers = customers }, catalog.CustomersById, 1, 5);
        queue.Tick(0, 0.01, true);
        return queue.Slots.Select(item => item.AppearanceId).ToArray();
    }

    private DayPlan Generate(DataCatalog catalog, int day) => new OrderGenerator().Generate(catalog.DaysByNumber[day], catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
    private static OrderData Order(string id, string type, int price, params OrderLineData[] lines) => new() { OrderId = id, CustomerTypeId = type, Lines = lines, BasePrice = price, PatienceSeconds = 60 };
    private static OrderLineData Pancake(string recipe) => new(ProductKind.Pancake, recipe, 1);
    private static OrderLineData Youtiao(int quantity) => new(ProductKind.Youtiao, StableIds.Products.Youtiao, quantity);
    private static OrderLineData SoyMilk() => new(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1);
    private static bool IsOnlyYoutiao(OrderData order, int quantity) => order.Lines.Count == 1 && order.Lines[0].ProductKind == ProductKind.Youtiao && order.Lines[0].Quantity == quantity;
    private static int MaxYoutiaoRun(DayPlan plan)
    {
        int current = 0, maximum = 0;
        foreach (PlannedCustomer customer in plan.Customers)
        {
            bool has = customer.Order.Lines.Any(line => line.ProductKind == ProductKind.Youtiao
                || line.ProductKind == ProductKind.Pancake && line.DefinitionId is StableIds.Recipes.Youtiao or StableIds.Recipes.ScallionYoutiao);
            current = has ? current + 1 : 0; maximum = Math.Max(maximum, current);
        }
        return maximum;
    }
    private static DayResult Result(int day, int completed, double satisfaction, int perfect, int revenue = 0) => new()
    {
        Day = day, PlannedCustomers = day == 15 ? 26 : Math.Max(1, completed), CompletedCustomers = completed,
        Satisfaction = satisfaction, PerfectOrders = perfect, SaleRevenue = revenue,
    };
    private static void MakeBagged(PancakeStateMachine machine, RecipeData recipe)
    {
        machine.TryExecute(PancakeCommand.PlaceBatter); machine.TryExecute(PancakeCommand.BeginSpread); machine.SetSpreadCoverage(1);
        machine.TryExecute(PancakeCommand.CompleteSpread); machine.TryExecute(PancakeCommand.AddEgg); machine.Tick(machine.Stove.SideAReadySeconds);
        machine.TryExecute(PancakeCommand.Flip); machine.Tick(machine.Stove.SideBReadySeconds); machine.TryExecute(PancakeCommand.BeginSauce);
        machine.SetSauceCoverage(1); machine.TryExecute(PancakeCommand.CompleteSauce);
        foreach (string ingredient in recipe.ExtraIngredients) machine.TryExecute(PancakeCommand.AddIngredient, ingredient);
        if (recipe.ExtraIngredients.Contains(StableIds.Ingredients.Youtiao)) machine.TrySetInternalYoutiaoQuality(YoutiaoQuality.Golden);
        machine.TryExecute(PancakeCommand.Fold); machine.TryExecute(PancakeCommand.Bag);
    }
    private void CheckCustomer(DataCatalog catalog, string id, double happy, double normal, double impatient, double leave, double tip)
    {
        CustomerTypeData data = catalog.CustomersById[id];
        Check(Close(data.HappyUntilSeconds, happy) && Close(data.NormalUntilSeconds, normal) && Close(data.ImpatientUntilSeconds, impatient)
            && Close(data.LeaveAtSeconds, leave) && Close(data.PerfectTipRate, tip), $"{data.DisplayName}耐心与小费准确");
    }
    private static void DeleteIfExists(string path) { if (File.Exists(path)) File.Delete(path); }
    private void Check(bool condition, string name, string details = "") { if (condition) { _passed++; GD.Print($"[PASS] {name}"); } else Fail(name, details); }
    private void Fail(string name, string details) { _failed++; GD.PushError($"[FAIL] {name}{(string.IsNullOrEmpty(details) ? string.Empty : $"：{details}")}"); }
    private static bool Close(double left, double right) => Math.Abs(left - right) < .001;
}
