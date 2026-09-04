using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Pancake;

namespace ProjectCake.Tests;

public partial class StageTwoSelfTest : Node
{
    private int _passed;
    private int _failed;

    public override void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            RunEquipmentAndInventoryTests(catalog);
            RunCoverageTests();
            RunStateMachineTests(catalog);
            RunRecipeAndPracticeTests(catalog);
            RunSceneTests();
        }
        catch (Exception exception)
        {
            _failed++;
            GD.PushError($"[FAIL] 阶段 2 自测发生未处理异常：{exception}");
        }

        GD.Print($"阶段 2 自测完成：{_passed} 项通过，{_failed} 项失败。");
        GetTree().Quit(_failed == 0 ? 0 : 1);
    }

    private void RunEquipmentAndInventoryTests(DataCatalog catalog)
    {
        Check(catalog.IngredientStationsByLevel.Count == 3, "加载 3 级配料台");
        CheckStation(catalog, 1, 10, 10, 12, 6, 6, 4, 0);
        CheckStation(catalog, 2, 16, 16, 18, 10, 10, 8, 60);
        CheckStation(catalog, 3, 24, 24, 28, 16, 16, 12, 180);

        catalog.TryGetIngredientStation(1, out IngredientStationLevelData levelOne);
        var inventory = new IngredientInventory(levelOne);
        for (int index = 0; index < levelOne.BatterCapacity; index++)
        {
            Check(inventory.TryConsume(StableIds.Ingredients.Batter), $"面糊第 {index + 1} 次消耗成功");
        }

        Check(!inventory.TryConsume(StableIds.Ingredients.Batter), "库存不会减为负数");
        inventory.TryConsume(StableIds.Ingredients.Egg);
        Check(inventory.TryBeginRefill(StableIds.Ingredients.Batter), "面糊可独立开始补料");
        Check(inventory.TryBeginRefill(StableIds.Ingredients.Egg), "鸡蛋可同时开始补料");
        inventory.Tick(0.5);
        Check(inventory.IsRefilling(StableIds.Ingredients.Batter) && inventory.IsRefilling(StableIds.Ingredients.Egg), "多个料盒同时计时");
        Check(!inventory.TryConsume(StableIds.Ingredients.Batter), "补料中不能消耗");
        inventory.Tick(0.5);
        Check(inventory.GetQuantity(StableIds.Ingredients.Batter) == levelOne.BatterCapacity, "面糊 1 秒后补满");
        Check(inventory.GetQuantity(StableIds.Ingredients.Egg) == levelOne.EggCapacity, "鸡蛋 1 秒后补满");

        inventory.TryConsume(StableIds.Ingredients.Sauce);
        inventory.TryBeginRefill(StableIds.Ingredients.Sauce);
        catalog.TryGetIngredientStation(2, out IngredientStationLevelData levelTwo);
        Check(!inventory.TrySwitchLevel(levelTwo), "补料时禁止切换配料台");
        inventory.Tick(1);
        Check(inventory.TrySwitchLevel(levelTwo), "补料结束后可以切换配料台");
        Check(inventory.GetQuantity(StableIds.Ingredients.Crispy) == levelTwo.CrispyCapacity, "切换配料台后按新容量补满");
    }

    private void RunCoverageTests()
    {
        var spread = new CoverageTracker(23);
        MarkCells(spread, 23, 200);
        Check(spread.CoveredCells == 23 && spread.IsComplete, "摊饼达到 23/32 自动完成");

        var sauce = new CoverageTracker(16);
        MarkCells(sauce, 15, 200);
        Check(!sauce.IsComplete, "抹酱 15/32 尚未完成");
        MarkCell(sauce, 15, 200);
        Check(sauce.IsComplete, "抹酱达到 16/32 自动完成");

        Vector2? assisted = CoverageTracker.GetAssistedPoint(new Vector2(220, 0), 200);
        Check(assisted.HasValue && assisted.Value.Length() < 200.01f, "边缘 32 像素内吸附回圆内");
        Check(CoverageTracker.GetAssistedPoint(new Vector2(233, 0), 200) is null, "超过边缘辅助距离时暂停累计");

        var fast = new CoverageTracker(32);
        fast.AddSegment(new Vector2(-190, 0), new Vector2(190, 0), 200);
        Check(fast.CoveredCells >= 6, "快速轨迹按 12 像素插值，不跳过中间区域", $"覆盖 {fast.CoveredCells} 格");
    }

    private void RunStateMachineTests(DataCatalog catalog)
    {
        catalog.TryGetStove(1, out PancakeStoveLevelData levelOne);
        var machine = new PancakeStateMachine(levelOne);
        Check(!machine.TryExecute(PancakeCommand.Flip).Success, "空炉拒绝跳步翻面");
        AdvanceToSideACooking(machine);
        Check(!machine.TryExecute(PancakeCommand.Flip).Success, "第一面未熟拒绝翻面");
        machine.Tick(2.2);
        Check(machine.Runtime.State == PancakeState.SideAReady && machine.Runtime.Quality == PancakeQuality.Perfect, "Lv1 第一面 2.2 秒进入熟成");
        machine.Tick(2.0);
        Check(machine.Runtime.State == PancakeState.SideAOverdone && machine.Runtime.Quality == PancakeQuality.Overdone, "Lv1 第一面 4.2 秒进入偏焦");
        machine.Tick(1.0);
        Check(machine.Runtime.State == PancakeState.Burnt && machine.Runtime.Quality == PancakeQuality.Burnt, "Lv1 第一面 5.2 秒进入焦糊");
        Check(!machine.TryExecute(PancakeCommand.AddIngredient, StableIds.Ingredients.Crispy).Success, "焦糊后拒绝继续加料");

        var sideB = new PancakeStateMachine(levelOne);
        AdvanceToSideACooking(sideB);
        sideB.Tick(2.2);
        sideB.TryExecute(PancakeCommand.Flip);
        sideB.Tick(1.1);
        Check(sideB.Runtime.State == PancakeState.SideBReady, "第二面 1.1 秒进入熟成");
        sideB.Tick(2.2);
        Check(sideB.Runtime.State == PancakeState.Burnt, "第二面 3.3 秒直接焦糊，无未定义偏焦态");

        foreach (int level in new[] { 2, 3 })
        {
            catalog.TryGetStove(level, out PancakeStoveLevelData stove);
            var safe = new PancakeStateMachine(stove);
            AdvanceToSideACooking(safe);
            safe.Tick(30);
            Check(safe.Runtime.State == PancakeState.SideAReady && Close(safe.Runtime.CookingSeconds, stove.SideAReadySeconds), $"Lv{level} 第一面熟成后钳制且不会焦");
            Check(!safe.TrySwitchStove(levelOne), $"炉面非空时不能切换 Lv{level} 炉具");
        }
    }

    private void RunRecipeAndPracticeTests(DataCatalog catalog)
    {
        catalog.TryGetStove(2, out PancakeStoveLevelData safeStove);
        RecipeData[] recipes =
        {
            catalog.RecipesById[StableIds.Recipes.Basic],
            catalog.RecipesById[StableIds.Recipes.Crispy],
            catalog.RecipesById[StableIds.Recipes.Scallion],
            catalog.RecipesById[StableIds.Recipes.ScallionCrispy],
        };

        foreach (RecipeData recipe in recipes)
        {
            var machine = new PancakeStateMachine(safeStove);
            MakeBagged(machine, recipe.ExtraIngredients);
            Check(machine.TryDeliver(recipe).Success, $"{recipe.DisplayName} 可完整制作并正确识别");
        }

        var missing = new PancakeStateMachine(safeStove);
        MakeBagged(missing, Array.Empty<string>());
        Check(!missing.TryDeliver(recipes[1]).Success, "缺少薄脆的配方被拒绝");
        var rejectedSession = new PracticeSession(new[] { recipes[1] }, 1);
        Check(!rejectedSession.TryDeliver(missing).Success && rejectedSession.CompletedCount == 0 && rejectedSession.ErrorCount == 1,
            "错误配方不推进目标并单独记录错误");
        var extra = new PancakeStateMachine(safeStove);
        MakeBagged(extra, new[] { StableIds.Ingredients.Crispy });
        Check(!extra.TryDeliver(recipes[0]).Success, "多余配料的配方被拒绝");

        var duplicate = new PancakeStateMachine(safeStove);
        AdvanceToSauced(duplicate);
        duplicate.TryExecute(PancakeCommand.AddIngredient, StableIds.Ingredients.Crispy);
        Check(duplicate.TryExecute(PancakeCommand.AddIngredient, StableIds.Ingredients.Crispy).Error == PancakeActionError.DuplicateIngredient, "重复配料被拒绝且不重复消费");

        var session = new PracticeSession(recipes, 30);
        for (int index = 0; index < 30; index++)
        {
            RecipeData expected = recipes[index % 4];
            Check(session.CurrentTarget.Id == expected.Id, $"第 {index + 1} 张目标循环正确");
            var machine = new PancakeStateMachine(safeStove);
            MakeBagged(machine, expected.ExtraIngredients);
            PancakeDeliveryResult result = session.TryDeliver(machine);
            Check(result.Success, $"第 {index + 1} 张确定性模拟交付成功");
        }

        Check(session.IsFinished && session.CompletedCount == 30 && session.PerfectCount == 30, "30 张练习完成且统计无残留");
        Check(session.CurrentTarget.Id == recipes[2].Id, "完成后目标索引仍按循环确定");

        catalog.TryGetStove(1, out PancakeStoveLevelData burnable);
        var overdoneMachine = new PancakeStateMachine(burnable);
        AdvanceToSideACooking(overdoneMachine);
        overdoneMachine.Tick(4.2);
        overdoneMachine.TryExecute(PancakeCommand.Flip);
        overdoneMachine.Tick(1.1);
        FinishFromSideBReady(overdoneMachine, Array.Empty<string>());
        var overdoneSession = new PracticeSession(new[] { recipes[0] }, 1);
        Check(overdoneSession.TryDeliver(overdoneMachine).Success && overdoneSession.OverdoneCount == 1 && overdoneSession.PerfectCount == 0,
            "偏焦正确配方计入完成但不计完美");
    }

    private void RunSceneTests()
    {
        PackedScene? labScene = ResourceLoader.Load<PackedScene>("res://Scenes/Gameplay/PancakeLab.tscn");
        Check(labScene is not null, "PancakeLab 场景可加载");
        if (labScene is not null)
        {
            Node lab = labScene.Instantiate();
            Check(lab is PancakeLab, "PancakeLab 根节点脚本正确");
            lab.Free();
        }

        PackedScene? mainScene = ResourceLoader.Load<PackedScene>("res://Scenes/Main/Main.tscn");
        Check(mainScene is not null, "Main 场景仍可加载");
        if (mainScene is not null)
        {
            Node main = mainScene.Instantiate();
            Check(main.HasNode("UI/PancakeLab") && main.HasNode("UI/DataDebugPanel"), "Main 同时包含实验台与数据调试台");
            main.Free();
        }
    }

    private static void AdvanceToSideACooking(PancakeStateMachine machine)
    {
        machine.TryExecute(PancakeCommand.PlaceBatter);
        machine.TryExecute(PancakeCommand.BeginSpread);
        machine.SetSpreadCoverage(1);
        machine.TryExecute(PancakeCommand.CompleteSpread);
        machine.TryExecute(PancakeCommand.AddEgg);
    }

    private static void AdvanceToSauced(PancakeStateMachine machine)
    {
        AdvanceToSideACooking(machine);
        machine.Tick(machine.Stove.SideAReadySeconds);
        machine.TryExecute(PancakeCommand.Flip);
        machine.Tick(machine.Stove.SideBReadySeconds);
        machine.TryExecute(PancakeCommand.BeginSauce);
        machine.SetSauceCoverage(1);
        machine.TryExecute(PancakeCommand.CompleteSauce);
    }

    private static void FinishFromSideBReady(PancakeStateMachine machine, IEnumerable<string> ingredients)
    {
        machine.TryExecute(PancakeCommand.BeginSauce);
        machine.SetSauceCoverage(1);
        machine.TryExecute(PancakeCommand.CompleteSauce);
        foreach (string ingredient in ingredients)
        {
            machine.TryExecute(PancakeCommand.AddIngredient, ingredient);
        }
        machine.TryExecute(PancakeCommand.Fold);
        machine.TryExecute(PancakeCommand.Bag);
    }

    private static void MakeBagged(PancakeStateMachine machine, IEnumerable<string> ingredients)
    {
        AdvanceToSideACooking(machine);
        machine.Tick(machine.Stove.SideAReadySeconds);
        machine.TryExecute(PancakeCommand.Flip);
        machine.Tick(machine.Stove.SideBReadySeconds);
        FinishFromSideBReady(machine, ingredients);
    }

    private static void MarkCells(CoverageTracker tracker, int count, float radius)
    {
        for (int cell = 0; cell < count; cell++)
        {
            MarkCell(tracker, cell, radius);
        }
    }

    private static void MarkCell(CoverageTracker tracker, int cell, float radius)
    {
        int ring = cell / CoverageTracker.SectorCount;
        int sector = cell % CoverageTracker.SectorCount;
        float distance = (ring + 0.5f) / CoverageTracker.RingCount * radius;
        float angle = (sector + 0.5f) / CoverageTracker.SectorCount * Mathf.Tau;
        Vector2 point = Vector2.FromAngle(angle) * distance;
        tracker.AddSegment(point, point, radius);
    }

    private void CheckStation(DataCatalog catalog, int level, int batter, int egg, int sauce, int crispy, int scallion, int ham, int price)
    {
        bool found = catalog.TryGetIngredientStation(level, out IngredientStationLevelData station);
        Check(found, $"配料台 Lv{level} 存在");
        if (!found)
        {
            return;
        }

        Check(station.BatterCapacity == batter && station.EggCapacity == egg && station.SauceCapacity == sauce
            && station.CrispyCapacity == crispy && station.ScallionCapacity == scallion && station.HamCapacity == ham
            && Close(station.RefillSeconds, 1) && station.UpgradePrice == price,
            $"配料台 Lv{level} 数值准确");
    }

    private void Check(bool condition, string name, string details = "")
    {
        if (condition)
        {
            _passed++;
            GD.Print($"[PASS] {name}");
        }
        else
        {
            _failed++;
            GD.PushError($"[FAIL] {name}{(string.IsNullOrEmpty(details) ? string.Empty : $"：{details}")}");
        }
    }

    private static bool Close(double left, double right) => Math.Abs(left - right) < 0.0001;
}
