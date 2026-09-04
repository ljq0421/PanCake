using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Inventory;
using ProjectCake.Orders;
using ProjectCake.Pancake;

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
            TestFryers(catalog);
            TestSoyMilk();
            TestOrderProgress(catalog);
            TestGenerator(catalog);
            TestAllDaysCompletable(catalog);
            TestFullChapterController(catalog);
            TestStarsAndSave(catalog);
            TestScenes();
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
        Check(catalog.ProductsById.Count == 2 && catalog.ProductsById[StableIds.Products.Youtiao].UnitPrice == 2
            && catalog.ProductsById[StableIds.Products.SoyMilk].UnitPrice == 3, "油条与豆浆商品价格准确");
        Check(catalog.FryersByLevel.Count == 3 && catalog.FryersByLevel[1].Capacity == 6
            && catalog.FryersByLevel[2].Capacity == 8 && catalog.FryersByLevel[3].AutoRaise, "三级油条锅资源准确");
        Check(catalog.CustomersById.Count == 4, "四类顾客资源齐全");
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
        Check(save.MigratedLegacySave && save.Data.Version == 2 && save.Data.Coins == 500 && save.Data.HighestUnlockedDay == 5
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

    private void TestScenes()
    {
        foreach (string path in new[] { "res://Scenes/Main/Main.tscn", "res://Scenes/UI/TianjinMapScreen.tscn", "res://Scenes/Gameplay/TianjinDayScreen.tscn" })
            Check(ResourceLoader.Load<PackedScene>(path) is not null, $"阶段 4 场景可加载：{path.GetFile()}");
        Node main = ResourceLoader.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate();
        Check(main.HasNode("UI/TianjinMapScreen"), "Main 接入天津完成与武汉占位地图");
        main.Free();
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
