using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Pancake;

namespace ProjectCake.Tests;

public partial class StageThreeSelfTest : Node
{
    private int _passed;
    private int _failed;

    public override void _Ready()
    {
        try
        {
            DataCatalog catalog = GetNode<DataCatalog>("/root/DataCatalog");
            TestCatalog(catalog);
            TestGenerator(catalog);
            TestCustomers(catalog);
            TestDeliveryAndLedger(catalog);
            TestSharedSettlementRules(catalog);
            TestDayController(catalog);
            TestSave(catalog);
            TestScenes();
        }
        catch (Exception exception)
        {
            Fail("阶段 3 自测未处理异常", exception.ToString());
        }
        GD.Print($"阶段 3 自测完成：{_passed} 项通过，{_failed} 项失败。");
        GetTree().Quit(_failed == 0 ? 0 : 1);
    }

    private void TestCatalog(DataCatalog catalog)
    {
        Check(catalog.IsValid, "阶段 3 数据目录通过校验");
        bool found = catalog.TryGetCustomer("normal", out CustomerTypeData normal);
        Check(new[] { "normal", "office_worker", "regular", "big_order", "wuhan_normal", "wuhan_office_worker", "wuhan_regular", "wuhan_tourist", "wuhan_big_order" }.All(catalog.CustomersById.ContainsKey) && found, "加载天津与武汉共九类顾客");
        if (!found) return;
        Check(Close(normal.HappyUntilSeconds, 15) && Close(normal.NormalUntilSeconds, 30) && Close(normal.ImpatientUntilSeconds, 42) && Close(normal.LeaveAtSeconds, 50) && Close(normal.PerfectTipRate, .1), "普通顾客耐心与小费数值正确");
    }

    private void TestGenerator(DataCatalog catalog)
    {
        var generator = new OrderGenerator();
        foreach (DayConfig config in catalog.DaysByNumber.Values)
        {
            DayPlan plan = generator.Generate(config, catalog.RecipesById);
            int[] counts = OrderGenerator.AllocateByLargestRemainder(config.CustomerCount,
                config.ArrivalSegments.Select(segment => segment.CustomerRatio).ToArray());
            double shortestInterval = config.ArrivalSegments.Select((segment, index) => counts[index] == 0
                ? double.PositiveInfinity : (segment.End - segment.Start) * config.DurationSeconds / counts[index]).Min();
            Check(plan.Customers.Zip(plan.Customers.Skip(1), (a, b) => b.ArrivalTime - a.ArrivalTime)
                .All(gap => gap >= shortestInterval * .8 - .0002), $"Day {config.Day} 相邻顾客保持间隔，跨时段也不会扎堆");
        }
        foreach (DayConfig config in catalog.DaysByNumber.Values.Where(day => day.Day <= 4).OrderBy(day => day.Day))
        {
            DayPlan first = generator.Generate(config, catalog.RecipesById);
            DayPlan second = generator.Generate(config, catalog.RecipesById);
            Check(Fingerprint(first) == Fingerprint(second), $"Day {config.Day} 相同种子逐字段复现");
            Check(first.Customers.Count == config.CustomerCount, $"Day {config.Day} 生成顾客数准确");
            Check(first.Customers.Select(customer => customer.CustomerId).Distinct().Count() == config.CustomerCount, $"Day {config.Day} 顾客 ID 唯一");
            Check(first.Customers.SequenceEqual(first.Customers.OrderBy(customer => customer.ArrivalTime)), $"Day {config.Day} 到店时间有序");
            Check(first.Customers.All(customer => customer.ArrivalTime > 0 && customer.ArrivalTime < config.DurationSeconds), $"Day {config.Day} 到店时间位于营业期内");
            Check(first.Customers.All(customer => config.AvailableRecipeIds.Contains(customer.Order.PancakeRecipeId)), $"Day {config.Day} 只引用可用配方");
            Check(first.Customers.All(customer => customer.CustomerTypeId == "normal" && customer.Order.Lines.Count == 1 && customer.Order.Lines[0].Quantity == 1), $"Day {config.Day} 仅生成普通顾客单张煎饼");
            int[] expected = OrderGenerator.AllocateByLargestRemainder(config.CustomerCount, config.ArrivalSegments.Select(segment => segment.CustomerRatio).ToArray());
            int[] actual = config.ArrivalSegments.Select(segment => first.Customers.Count(customer => customer.ArrivalTime >= segment.Start * config.DurationSeconds && customer.ArrivalTime < segment.End * config.DurationSeconds)).ToArray();
            Check(actual.SequenceEqual(expected), $"Day {config.Day} 时段人数按最大余数分配", $"预期 {string.Join(',', expected)}，实际 {string.Join(',', actual)}");
        }
    }

    private void TestCustomers(DataCatalog catalog)
    {
        CustomerTypeData normal = catalog.CustomersById["normal"];
        DayPlan plan = MakePlan(6, normal.Id, catalog.RecipesById[StableIds.Recipes.Basic]);
        var queue = new CustomerQueue(plan, catalog.CustomersById, 1.2, 5);
        int lostEvents = 0; queue.CustomerLost += _ => lostEvents++;
        queue.Tick(0, 0.01, true);
        Check(queue.Slots.Count == 5 && queue.DoorQueue.Count == 1, "可见顾客不超过五人");
        queue.Tick(0, 3.0, false);
        CustomerRuntime door = queue.DoorQueue.Single();
        Check(door.State == CustomerState.DoorWaiting && Close(door.WaitSeconds, 0), "满员延迟 3 秒后门外候场且不扣耐心");
        queue.Tick(0, .35, false);
        Check(queue.Slots.All(customer => customer.State == CustomerState.Happy), "进店 0.35 秒后进入 Happy");
        CustomerRuntime first = queue.Slots[0];
        var originalSlots = queue.Slots.ToDictionary(customer => customer.Id, customer => customer.SlotIndex);
        Check(queue.Slots.Select(customer => customer.SlotIndex).SequenceEqual(Enumerable.Range(0, 5)), "首批顾客按 1–5 号固定站位");
        queue.Tick(0, 18, false);
        Check(first.State == CustomerState.Normal, "Day 1 倍率后 18 秒进入 Normal");
        queue.Tick(0, 18, false);
        Check(first.State == CustomerState.Impatient, "Day 1 倍率后 36 秒进入 Impatient");
        queue.Tick(0, 14.4, false);
        Check(first.State == CustomerState.Angry, "Day 1 倍率后 50.4 秒进入 Angry");
        Check(queue.TrySelect(first.Id), "可选择等待顾客");
        Check(queue.TryMarkServed(first.Id) && queue.SelectedCustomerId is null, "出餐后取消顾客选择");
        queue.Tick(0, .45, false);
        Check(queue.Slots.Count == 5 && queue.Slots[^1].Id == door.Id, "离场 0.45 秒后门外顾客 FIFO 补位");
        Check(queue.CustomerAtSlot(0) == door && queue.Slots.Where(customer => customer != door)
            .All(customer => customer.SlotIndex == originalSlots[customer.Id]), "新顾客补入 1 号空位，其余顾客保持原位");
        CustomerRuntime middle = queue.CustomerAtSlot(2)!;
        Check(queue.TryMarkServed(middle.Id), "中间位置顾客可正常出餐离场");
        queue.Tick(0, .45, false);
        Check(queue.CustomerAtSlot(2) is null && queue.CustomerAtSlot(3)?.SlotIndex == 3
            && queue.CustomerAtSlot(4)?.SlotIndex == 4, "中间空位保留，右侧顾客不会向前挤位");

        CustomerRuntime leave = queue.Slots.First(customer => customer.Id != door.Id);
        queue.Tick(0, 60, false);
        Check(lostEvents >= 1 && leave.Order.Status == OrderStatus.Lost, "超过倍率化离店时间触发 Lost");
        queue.ForceLoseAll();
        Check(queue.IsResolved, "强制收尾后队列完全清空");
    }

    private void TestDeliveryAndLedger(DataCatalog catalog)
    {
        RecipeData basic = catalog.RecipesById[StableIds.Recipes.Basic];
        RecipeData crispy = catalog.RecipesById[StableIds.Recipes.Crispy];
        var evaluator = new OrderEvaluator();
        OrderData order = MakeOrder("test", basic, 7);
        DeliveryEvaluation perfect = evaluator.Evaluate(order, CustomerState.Happy, new PreparedPancake(PancakeQuality.Perfect, new HashSet<string>()), basic);
        Check(perfect.Grade == DeliveryGrade.Perfect && perfect.SaleRevenue == 7 && perfect.Tip == 1 && perfect.SatisfactionScore == 100, "Perfect 获得全价与四舍五入 10% 小费");
        DeliveryEvaluation late = evaluator.Evaluate(order, CustomerState.Normal, new PreparedPancake(PancakeQuality.Perfect, new HashSet<string>()), basic);
        Check(late.Grade == DeliveryGrade.Correct && late.SaleRevenue == 7 && late.Tip == 0, "离开 Happy 后正确订单无 Perfect");
        DeliveryEvaluation overdone = evaluator.Evaluate(order, CustomerState.Happy, new PreparedPancake(PancakeQuality.Overdone, new HashSet<string>()), basic);
        Check(overdone.Grade == DeliveryGrade.Correct, "偏焦正确配方评为 Correct");
        DeliveryEvaluation wrong = evaluator.Evaluate(order, CustomerState.Happy, new PreparedPancake(PancakeQuality.Perfect, new HashSet<string> { StableIds.Ingredients.Crispy }), basic);
        Check(wrong.Grade == DeliveryGrade.Incorrect && wrong.SaleRevenue == 5 && wrong.Tip == 0 && wrong.SatisfactionScore == 55, "¥7 错单按 70% 半数向上结算为 ¥5");

        var ledger = new DayLedger(1, 4); ledger.RecordDelivery(perfect); ledger.RecordDelivery(late); ledger.RecordDelivery(wrong); ledger.RecordLost(); DayResult result = ledger.Build();
        Check(result.TotalRevenue == 20 && result.CompletedCustomers == 3 && result.LostCustomers == 1, "营业收入和完成流失统计准确");
        Check(result.HighestCorrectStreak == 2 && Close(result.Satisfaction, 80), "连击和 100/85/55 满意度平均准确，流失不计入");
        _ = crispy;
    }

    private void TestSharedSettlementRules(DataCatalog catalog)
    {
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou })
        {
            Check(catalog.GetDays(city).Values.All(day => day.SatisfactionAverageMode == SatisfactionAverageMode.CompletedCustomers),
                $"{city} 全部关卡满意度排除流失顾客");
            var controller = new DayController(); AddChild(controller);
            Check(controller.TryPrepareDay(city, 1, catalog, out _), $"{city} 准备结算规则测试");
            controller.Ledger!.RecordLost();
            Check(controller.Ledger.Build().Satisfaction == 0, $"{city} 无完成顾客时满意度为零");
            controller.Ledger.RecordDelivery(new(DeliveryGrade.Correct, 10, 0, 80, ""));
            Check(controller.Ledger.Build().Satisfaction == 80 && controller.Ledger.Build().LostCustomers == 1,
                $"{city} 流失单独统计且不降低满意度");
            controller.Free();
        }
        var evaluator = new OrderEvaluator();
        var recipe = catalog.RecipesById[StableIds.Recipes.Basic];
        using var type = new CustomerTypeData();
        foreach (var (price, rate, expected) in new[] { (10, .14f, 1), (10, .25f, 3), (10, .26f, 3), (25, .7f, 18), (4, .1f, 0) })
        {
            type.PerfectTipRate = rate;
            var order = MakeOrder("rounding", recipe, price);
            var progress = new OrderProgress(order);
            progress.TryAccept(new DeliveredItem(ProductKind.Pancake, recipe.Id, PancakeQuality.Perfect));
            Check(new[] {
                evaluator.EvaluateCompleted(progress, CustomerState.Happy, type).Tip,
                evaluator.EvaluateCompletedWuhan(progress, 0, type).Tip,
                evaluator.EvaluateCompletedXian(progress, 0, type).Tip,
                evaluator.EvaluateCompletedGuangzhou(progress, 0, type).Tip,
                evaluator.Evaluate(order, CustomerState.Happy, new PreparedPancake(PancakeQuality.Perfect, new HashSet<string>()), recipe, (double)(decimal)rate).Tip,
                TipCalculator.Calculate(price, (double)(decimal)rate)
            }.All(tip => tip == expected), $"所有结算入口小费 {price}×{rate} 四舍五入为 {expected}");
        }
    }
    private void TestDayController(DataCatalog catalog)
    {
        var controller = new DayController(); AddChild(controller);
        Check(controller.TryPrepareDay(1, catalog, out _) && controller.State == DayState.Preparing, "Day 1 可进入 Preparing");
        Check(controller.TryStartDay(out _) && controller.State == DayState.Opening, "点击开店进入 Opening");
        controller.Tick(2.99); Check(controller.State == DayState.Opening, "3 秒倒计时结束前保持 Opening");
        controller.Tick(.01); Check(controller.State == DayState.Running, "3 秒倒计时后进入 Running");
        controller.Tick(60); Check(controller.State == DayState.Closing, "营业计时归零进入 Closing");
        controller.Tick(14.99); Check(controller.State == DayState.Closing, "15 秒保护期结束前保持 Closing");
        controller.Tick(.01); Check(controller.State == DayState.Results && controller.Ledger!.Build().LostCustomers == 6, "15 秒结束强制流失并结算");

        controller.TryPrepareDay(2, catalog, out _); controller.TryStartDay(out _); controller.Tick(3); controller.AbandonDay();
        Check(controller.State == DayState.Preparing && controller.Ledger is null, "中途放弃整日结果作废");
        controller.QueueFree();

        foreach (int day in Enumerable.Range(1, 4))
        {
            DayResult simulated = SimulateCompleteDay(catalog, day);
            Check(simulated.CompletedCustomers == catalog.DaysByNumber[day].CustomerCount && simulated.LostCustomers == 0,
                $"Day {day} 可从开店完整服务至结算");
        }
    }

    private void TestSave(DataCatalog catalog)
    {
        string relative = $"res://.tmp/stage3-selftest-{Guid.NewGuid():N}.json";
        string absolute = ProjectSettings.GlobalizePath(relative);
        var save = new SaveService(); AddChild(save); save.UsePathForTests(relative);
        DayConfig day1 = catalog.DaysByNumber[1]; DayPlan plan = new OrderGenerator().Generate(day1, catalog.RecipesById);
        DayResult first = Result(1, 50); DayCommitResult firstCommit = save.CommitDay(first, plan, day1);
        Check(firstCommit.PermanentCoinGain == 50 && save.Data.Coins == 50 && save.Data.HighestUnlockedDay == 2, "首次结算获得全额并解锁下一天");
        DayCommitResult replay = save.CommitDay(Result(1, 45), plan, day1);
        Check(replay.PermanentCoinGain == 0 && save.Data.Coins == 50, "较低重玩成绩不重复发金币");
        DayCommitResult improved = save.CommitDay(Result(1, 63), plan, day1);
        Check(improved.PermanentCoinGain == 13 && save.Data.Coins == 63, "提高最佳成绩只补发差额");

        save.CommitDay(Result(3, 100), new OrderGenerator().Generate(catalog.DaysByNumber[3], catalog.RecipesById), catalog.DaysByNumber[3]);
        Check(save.Data.UnlockedUpgradeIds.Contains("equipment:ingredient_station_lv2"), "Day 3 结算开放配料台 Lv2");
        int beforePurchase = save.Data.Coins;
        Check(save.TryPurchase("equipment:ingredient_station_lv2", catalog, out _) && save.Data.PurchasedIngredientStationLevel == 2 && save.Data.Coins == beforePurchase - 60, "购买配料台扣款并永久保存");

        save.CommitDay(Result(4, 200), new OrderGenerator().Generate(catalog.DaysByNumber[4], catalog.RecipesById), catalog.DaysByNumber[4]);
        Check(save.Data.UnlockedUpgradeIds.Contains("equipment:pancake_stove_lv2") && save.Data.HighestUnlockedDay == 5, "Day 4 结算开放煎饼炉并解锁 Day 5");
        Check(save.TryPurchase("equipment:pancake_stove_lv2", catalog, out _) && save.Data.PurchasedStoveLevel == 2, "购买煎饼炉 Lv2 并永久保存");

        var loaded = new SaveService(); AddChild(loaded); loaded.UsePathForTests(relative);
        Check(loaded.Data.Coins == save.Data.Coins && loaded.Data.PurchasedIngredientStationLevel == 2 && loaded.Data.PurchasedStoveLevel == 2 && loaded.Data.LastDayPlan?.RandomSeed == 1004, "存档往返保留金币、设备和最近 DayPlan");

        File.WriteAllText(absolute, "{ invalid save }");
        loaded.Load();
        Check(loaded.HasLoadError && File.Exists(loaded.CorruptBackupPath), "损坏存档备份并阻止静默覆盖");
        Check(!loaded.TrySave(out _), "未确认重置前禁止覆盖损坏存档");
        Check(loaded.ConfirmCreateNewAfterCorruption(out _) && !loaded.HasLoadError && loaded.Data.Coins == 0, "确认后可建立全新存档");

        save.QueueFree(); loaded.QueueFree();
        if (File.Exists(absolute)) File.Delete(absolute);
        foreach (string backup in Directory.GetFiles(Path.GetDirectoryName(absolute)!, Path.GetFileName(absolute) + ".corrupt-*.bak")) File.Delete(backup);
    }

    private void TestScenes()
    {
        string[] productionScenes =
        {
            "res://Scenes/UI/MorningHub.tscn",
            "res://Scenes/UI/WuhanHub.tscn",
            "res://Scenes/UI/XianHub.tscn",
            "res://Scenes/UI/GuangzhouHub.tscn",
            "res://Scenes/UI/YangzhouHub.tscn",
            "res://Scenes/UI/TianjinMapScreen.tscn",
            "res://Scenes/UI/DataDebugPanel.tscn",
            "res://Scenes/UI/OrderBubbleView.tscn",
            "res://Scenes/UI/CustomerPortraitView.tscn",
            "res://Scenes/UI/CoinTrayView.tscn",
            "res://Scenes/UI/CoinCollectionFeedback.tscn",
            "res://Scenes/Gameplay/TianjinDayScreen.tscn",
            "res://Scenes/Gameplay/WuhanDayScreen.tscn",
            "res://Scenes/Gameplay/XianDayScreen.tscn",
            "res://Scenes/Gameplay/GuangzhouDayScreen.tscn",
            "res://Scenes/Gameplay/YangzhouDayScreen.tscn",
            "res://Scenes/Gameplay/PancakeLab.tscn",
            "res://Scenes/Gameplay/PancakeWorkstation.tscn",
            "res://Scenes/Gameplay/PancakeLabWorkstation.tscn",
            "res://Scenes/Shop/TianjinShop.tscn",
            "res://Scenes/Main/Main.tscn",
        };
        foreach (string path in productionScenes)
        {
            Check(ResourceLoader.Load<PackedScene>(path) is not null, $"场景可加载：{path.GetFile()}");
        }
        foreach (string path in productionScenes.Where(path => !path.EndsWith("Main.tscn", StringComparison.Ordinal)))
            CheckStaticSceneArchitecture(path);
        CheckStaticUiSourceGuard();

        PackedScene mainScene = ResourceLoader.Load<PackedScene>("res://Scenes/Main/Main.tscn"); Node main = mainScene.Instantiate();
        Check(main.HasNode("UI/MorningHub") && main.HasNode("UI/WuhanHub") && main.HasNode("UI/XianHub")
            && main.HasNode("UI/GuangzhouHub") && main.HasNode("UI/YangzhouHub")
            && main.HasNode("UI/TianjinDayScreen") && main.HasNode("UI/WuhanDayScreen")
            && main.HasNode("UI/XianDayScreen") && main.HasNode("UI/GuangzhouDayScreen")
            && main.HasNode("UI/YangzhouDayScreen") && main.HasNode("UI/PancakeLab")
            && main.HasNode("UI/DataDebugPanel"), "Main 固定包含五城首页、五城营业页、实验台和数据调试入口");
        main.Free();

        string relative = $"res://.tmp/stage3-screen-{Guid.NewGuid():N}.json";
        string absolute = ProjectSettings.GlobalizePath(relative);
        var save = new SaveService(); AddChild(save); save.UsePathForTests(relative);
        var controller = new DayController(); AddChild(controller);
        var screen = ResourceLoader.Load<PackedScene>("res://Scenes/Gameplay/TianjinDayScreen.tscn").Instantiate<TianjinDayScreen>(); AddChild(screen);
        screen.ConnectController(controller); screen.Initialize(GetNode<DataCatalog>("/root/DataCatalog"), save, controller, 1);
        controller.TryStartDay(out _); controller.Tick(3); controller.Tick(60); controller.Tick(15);
        Check(controller.State == DayState.Results && save.Data.DayBestRecords.ContainsKey(1), "正式营业界面可接收结算并写入存档");
        screen.QueueFree(); controller.QueueFree(); save.QueueFree(); if (File.Exists(absolute)) File.Delete(absolute);
    }

    private void CheckStaticSceneArchitecture(string path)
    {
        PackedScene scene = ResourceLoader.Load<PackedScene>(path);
        Node first = scene.Instantiate();
        Node second = scene.Instantiate();
        string[] firstSignature = SceneSignature(first).ToArray();
        string[] secondSignature = SceneSignature(second).ToArray();
        Check(firstSignature.SequenceEqual(secondSignature), $"场景重复实例化结构稳定：{path.GetFile()}");
        second.Free();

        AddChild(first);
        Node[] unexpected = Descendants(first)
            .Where(node => node.Owner is null && !HasDynamicAncestor(node, first))
            .ToArray();
        Check(unexpected.Length == 0, $"场景就绪后无未登记的 ownerless 固定节点：{path.GetFile()}",
            string.Join(", ", unexpected.Select(node => first.GetPathTo(node))));
        RemoveChild(first);
        first.Free();
    }

    private void CheckStaticUiSourceGuard()
    {
        string[] pageSources =
        {
            "res://Scripts/UI/MorningHub.cs", "res://Scripts/UI/WuhanHub.cs",
            "res://Scripts/UI/XianHub.cs", "res://Scripts/UI/GuangzhouHub.cs",
            "res://Scripts/UI/YangzhouHub.cs", "res://Scripts/UI/TianjinMapScreen.cs",
            "res://Scripts/UI/DataDebugPanel.cs", "res://Scripts/UI/TianjinLedger.cs",
            "res://Scripts/UI/WuhanLedger.cs", "res://Scripts/Gameplay/TianjinDayScreen.cs",
            "res://Scripts/Gameplay/WuhanDayScreen.cs", "res://Scripts/Gameplay/XianDayScreen.cs",
            "res://Scripts/Gameplay/GuangzhouDayScreen.cs", "res://Scripts/Gameplay/YangzhouDayScreen.cs",
            "res://Scripts/Gameplay/PancakeLab.cs",
        };
        string[] forbiddenStaticBuilders =
        {
            "private void Build(", "BuildHud(", "BuildCustomers(",
            "new Button {", "new PanelContainer", "new VBoxContainer",
            "new HBoxContainer", "new GridContainer", "new MarginContainer",
        };
        foreach (string path in pageSources)
        {
            string source = Godot.FileAccess.GetFileAsString(path);
            string[] found = forbiddenStaticBuilders.Where(source.Contains).ToArray();
            Check(found.Length == 0, $"页面源码不再搭建固定 UI：{path.GetFile()}", string.Join(", ", found));
        }

        string controller = Godot.FileAccess.GetFileAsString("res://Scripts/Core/GameController.cs");
        string[] forbiddenController = { "PackedScene", ".Instantiate(", "new GuangzhouHub", "new YangzhouHub", ".AddChild(" };
        string[] controllerFound = forbiddenController.Where(controller.Contains).ToArray();
        Check(controllerFound.Length == 0, "GameController 仅引用 Main 预建页面", string.Join(", ", controllerFound));

        string slot = Godot.FileAccess.GetFileAsString("res://Scripts/UI/WorkstationSlotView.cs");
        Check(!slot.Contains("_ingredientAnchor.AddChild", StringComparison.Ordinal),
            "库存视觉使用 .tscn 预建节点池，不在 C# 中扩容");

        string pancakeWorkstation = Godot.FileAccess.GetFileAsString("res://Scripts/Gameplay/PancakeWorkstation.cs");
        string[] runtimeDragAppearance = { "_storedYoutiao.Configure(", "item.Configure(_drag", "_finished.Configure(", "_soyCup.Configure(" };
        Check(runtimeDragAppearance.All(token => !pancakeWorkstation.Contains(token, StringComparison.Ordinal)),
            "正式工作台与实验台的拖拽外观由各自场景变体声明");

        string wuhanWorkstation = Godot.FileAccess.GetFileAsString("res://Scripts/UI/WuhanWorkstationView.cs");
        string wuhanGestures = Godot.FileAccess.GetFileAsString("res://Scripts/UI/WuhanWorkstationGestures.cs");
        Check(!wuhanWorkstation.Contains("source.Position =", StringComparison.Ordinal)
              && !wuhanWorkstation.Contains("source.Size =", StringComparison.Ordinal)
              && !wuhanGestures.Contains("button.Position =", StringComparison.Ordinal),
            "武汉交付热区与补货按钮坐标只保存在场景中");

        string dragItem = Godot.FileAccess.GetFileAsString("res://Scripts/Interaction/DragItem.cs");
        Check(!dragItem.Contains("MouseDefaultCursorShape =", StringComparison.Ordinal),
            "固定拖拽光标样式由场景声明");
    }

    private static IEnumerable<Node> Descendants(Node root)
    {
        foreach (Node child in root.GetChildren())
        {
            yield return child;
            foreach (Node descendant in Descendants(child)) yield return descendant;
        }
    }

    private static IEnumerable<string> SceneSignature(Node root)
    {
        yield return $".:{root.GetClass()}";
        foreach (Node node in Descendants(root)) yield return $"{root.GetPathTo(node)}:{node.GetClass()}";
    }

    private static bool HasDynamicAncestor(Node node, Node sceneRoot)
    {
        for (Node? current = node.GetParent(); current is not null && current != sceneRoot; current = current.GetParent())
            if (current.HasMeta("_dynamic_children") && current.GetMeta("_dynamic_children").AsBool()) return true;
        return false;
    }

    private static DayPlan MakePlan(int count, string typeId, RecipeData recipe)
    {
        var customers = Enumerable.Range(1, count).Select(index => new PlannedCustomer { CustomerId = $"C{index}", CustomerTypeId = typeId, ArrivalTime = 0, Order = MakeOrder($"O{index}", recipe, recipe.Price) }).ToArray();
        return new DayPlan { Day = 1, RandomSeed = 1, Customers = customers };
    }
    private static OrderData MakeOrder(string id, RecipeData recipe, int price) => new() { OrderId = id, CustomerTypeId = "normal", Lines = new[] { new OrderLineData(ProductKind.Pancake, recipe.Id, 1) }, BasePrice = price, PatienceSeconds = 50 };
    private static DayResult Result(int day, int total) => new() { Day = day, PlannedCustomers = 1, SaleRevenue = total, CompletedCustomers = 1, Satisfaction = 100 };
    private DayResult SimulateCompleteDay(DataCatalog catalog, int day)
    {
        var controller = new DayController();
        AddChild(controller);
        DayResult? finished = null;
        controller.DayFinished += result => finished = result;
        controller.TryPrepareDay(day, catalog, out _);
        controller.TryStartDay(out _);
        controller.Tick(3);
        var machine = new PancakeStateMachine(catalog.StovesByLevel[2]);
        bool checkedNoSelection = false;
        for (int step = 0; step < 20000 && controller.State != DayState.Results; step++)
        {
            controller.Tick(.05);
            CustomerRuntime? customer = controller.CustomerQueue?.Slots.FirstOrDefault(candidate => candidate.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry);
            if (customer is null) continue;
            if (!checkedNoSelection)
            {
                Check(controller.TryDeliverSelected(machine, catalog).Grade == DeliveryGrade.Rejected, "未选择顾客时拒绝交付");
                checkedNoSelection = true;
            }
            controller.CustomerQueue!.TrySelect(customer.Id);
            RecipeData recipe = catalog.RecipesById[customer.Order.PancakeRecipeId];
            SaucePreference sauce = customer.Order.Lines.First(line => line.ProductKind == ProductKind.Pancake).Sauce;
            MakeBagged(machine, recipe.ExtraIngredients, sauce == SaucePreference.Light ? .25 : sauce == SaucePreference.Extra ? 1.25 : .75);
            DeliveryEvaluation evaluation = controller.TryDeliverSelected(machine, catalog);
            Check(evaluation.CompletesOrder, $"Day {day} 顾客 {customer.Id} 交付成功");
            machine.TryExecute(PancakeCommand.Discard);
        }
        controller.QueueFree();
        return finished ?? throw new InvalidOperationException($"Day {day} 确定性模拟未进入结算。");
    }
    private static void MakeBagged(PancakeStateMachine machine, IEnumerable<string> ingredients, double sauceAmount = 1)
    {
        machine.TryExecute(PancakeCommand.PlaceBatter);
        machine.TryExecute(PancakeCommand.BeginSpread);
        machine.SetSpreadCoverage(1);
        machine.TryExecute(PancakeCommand.CompleteSpread);
        machine.TryExecute(PancakeCommand.AddEgg);
        machine.Tick(machine.Stove.SideAReadySeconds);
        machine.TryExecute(PancakeCommand.Flip);
        machine.Tick(machine.Stove.SideBReadySeconds);
        machine.TryExecute(PancakeCommand.BeginSauce);
        machine.SetSauceCoverage(sauceAmount);
        machine.TryExecute(PancakeCommand.CompleteSauce);
        foreach (string ingredient in ingredients) machine.TryExecute(PancakeCommand.AddIngredient, ingredient);
        machine.TryExecute(PancakeCommand.Fold);
        machine.TryExecute(PancakeCommand.Bag);
    }
    private static string Fingerprint(DayPlan plan) => JsonSerializer.Serialize(plan);
    private void Check(bool condition, string name, string details = "") { if (condition) { _passed++; GD.Print($"[PASS] {name}"); } else Fail(name, details); }
    private void Fail(string name, string details) { _failed++; GD.PushError($"[FAIL] {name}{(string.IsNullOrEmpty(details) ? string.Empty : $"：{details}")}"); }
    private static bool Close(double left, double right) => Math.Abs(left - right) < .001;
}
