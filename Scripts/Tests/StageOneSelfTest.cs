using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.Tests;

public partial class StageOneSelfTest : Node
{
    private int _passed;
    private int _failed;

    public override void _Ready()
    {
        RunCatalogTests();
        RunFailureDiagnosticTests();
        RunSceneTests();

        GD.Print($"阶段 1 自测完成：{_passed} 项通过，{_failed} 项失败。");
        GetTree().Quit(_failed == 0 ? 0 : 1);
    }

    private void RunCatalogTests()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        Check(catalog.IsValid, "生产数据目录通过完整校验", FormatIssues(catalog.ValidationIssues));
        Check(catalog.RecipesById.Count == 8, "加载 8 个配方", $"实际 {catalog.RecipesById.Count}");
        Check(catalog.StovesByLevel.Count == 3, "加载 3 级煎饼炉", $"实际 {catalog.StovesByLevel.Count}");
        Check(catalog.IngredientStationsByLevel.Count == 3, "加载 3 级配料台", $"实际 {catalog.IngredientStationsByLevel.Count}");
        Check(catalog.CustomersById.Count == 4, "加载 4 类顾客", $"实际 {catalog.CustomersById.Count}");
        Check(catalog.DaysByNumber.Count == 15, "加载 Day 1～15", $"实际 {catalog.DaysByNumber.Count}");

        var expectedRecipes = new Dictionary<string, (int Price, string[] Ingredients)>(StringComparer.Ordinal)
        {
            [StableIds.Recipes.Basic] = (7, Array.Empty<string>()),
            [StableIds.Recipes.Crispy] = (8, new[] { "crispy" }),
            [StableIds.Recipes.Scallion] = (8, new[] { "scallion" }),
            [StableIds.Recipes.ScallionCrispy] = (9, new[] { "scallion", "crispy" }),
            [StableIds.Recipes.Ham] = (9, new[] { "ham" }),
            [StableIds.Recipes.HamCrispy] = (10, new[] { "ham", "crispy" }),
            [StableIds.Recipes.Youtiao] = (9, new[] { "youtiao" }),
            [StableIds.Recipes.ScallionYoutiao] = (10, new[] { "scallion", "youtiao" }),
        };

        foreach ((string id, (int price, string[] ingredients)) in expectedRecipes)
        {
            bool found = catalog.TryGetRecipe(id, out RecipeData recipe);
            Check(found, $"配方存在：{id}");
            if (found)
            {
                Check(recipe.Price == price, $"配方价格正确：{id}", $"预期 {price}，实际 {recipe.Price}");
                Check(recipe.ExtraIngredients.SequenceEqual(ingredients), $"配方加料正确：{id}",
                    $"预期 [{string.Join(",", ingredients)}]，实际 [{string.Join(",", recipe.ExtraIngredients)}]");
            }
        }

        CheckStove(catalog, 1, true, 2.2f, 1.1f, 4.2f, 5.2f, 3.3f, 0);
        CheckStove(catalog, 2, false, 2.2f, 1.1f, 0, 0, 0, 120);
        CheckStove(catalog, 3, false, 1.65f, 0.8f, 0, 0, 0, 300);

        CheckDay(catalog, 1, 60, 6, 42, 1.20, 1001,
            new Dictionary<string, double> { [StableIds.Recipes.Basic] = 1.0 });
        CheckDay(catalog, 2, 70, 7, 52, 1.16, 1002,
            new Dictionary<string, double>
            {
                [StableIds.Recipes.Basic] = 0.60,
                [StableIds.Recipes.Crispy] = 0.40,
            });
        CheckDay(catalog, 3, 80, 8, 64, 1.10, 1003,
            new Dictionary<string, double>
            {
                [StableIds.Recipes.Basic] = 0.30,
                [StableIds.Recipes.Crispy] = 0.30,
                [StableIds.Recipes.Scallion] = 0.20,
                [StableIds.Recipes.ScallionCrispy] = 0.20,
            });
        CheckDay(catalog, 4, 90, 10, 82, 1.06, 1004,
            new Dictionary<string, double>
            {
                [StableIds.Recipes.Basic] = 0.20,
                [StableIds.Recipes.Crispy] = 0.30,
                [StableIds.Recipes.Scallion] = 0.20,
                [StableIds.Recipes.ScallionCrispy] = 0.30,
            });

        Check(catalog.GetDayOrThrow(3).CompletionUnlocks.SequenceEqual(new[] { "equipment:ingredient_station_lv2" }),
            "Day 3 结算解锁配料台 Lv2");
        Check(catalog.GetDayOrThrow(4).CompletionUnlocks.SequenceEqual(new[] { "equipment:pancake_stove_lv2" }),
            "Day 4 结算解锁煎饼炉 Lv2");

        var dayController = new DayController();
        AddChild(dayController);
        for (int dayNumber = 1; dayNumber <= 4; dayNumber++)
        {
            bool prepared = dayController.TryPrepareDay(dayNumber, catalog, out string error);
            Check(prepared
                && dayController.State == DayState.Preparing
                && dayController.CurrentConfig?.Day == dayNumber,
                $"DayController 可切换至 Day {dayNumber}",
                error);
        }
        RemoveChild(dayController);
        dayController.Free();
    }

    private void RunFailureDiagnosticTests()
    {
        var loader = new DayConfigLoader();
        DayConfigLoadResult unknownProperty = loader.LoadFile("res://Tests/Fixtures/invalid_unknown_property.json");
        Check(!unknownProperty.IsSuccess && unknownProperty.Issues.Count > 0,
            "未知 JSON 字段被拒绝并返回定位",
            FormatIssues(unknownProperty.Issues));

        DayConfigLoadResult invalidSemantics = loader.LoadFile("res://Tests/Fixtures/invalid_semantics.json");
        Check(invalidSemantics.IsSuccess, "语义错误样例可以完成 JSON 反序列化", FormatIssues(invalidSemantics.Issues));

        if (invalidSemantics.Config is not null)
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            IReadOnlyList<ValidationIssue> issues = CatalogValidator.ValidateDays(
                new[] { invalidSemantics.Config },
                catalog.RecipesById.Values.ToArray());

            RequireIssue(issues, "recipeWeights", "权重合计", "检测权重合计错误");
            RequireIssue(issues, "recipeWeights", "未知 ID", "检测未知配方引用");
            RequireIssue(issues, "arrivalSegments", "连续覆盖", "检测到店时段缺口");
            RequireIssue(issues, "startUnlocks", "未知解锁", "检测未知解锁 ID");
            RequireIssue(issues, "availableRecipeIds", "解锁前", "检测解锁前配方引用");
        }

        var duplicateA = new RecipeData { Id = StableIds.Recipes.Basic, DisplayName = "A", Price = 7 };
        var duplicateB = new RecipeData { Id = StableIds.Recipes.Basic, DisplayName = "B", Price = 7 };
        IReadOnlyList<ValidationIssue> duplicateIssues = CatalogValidator.ValidateRecipes(new[] { duplicateA, duplicateB });
        RequireIssue(duplicateIssues, "Id", "重复", "检测重复配方 ID");
    }

    private void RunSceneTests()
    {
        PackedScene? mainResource = ResourceLoader.Load<PackedScene>("res://Scenes/Main/Main.tscn");
        Check(mainResource is not null, "Main 场景可加载");
        if (mainResource is not null)
        {
            Node main = mainResource.Instantiate();
            Check(main.HasNode("DayController"), "Main 包含 DayController");
            Check(main.HasNode("ShopRoot/TianjinShop"), "Main 包含天津店铺实例");
            Check(main.HasNode("UI/DataDebugPanel"), "Main 包含数据调试面板");
            Check(main.HasNode("UI/PancakeLab"), "Main 包含煎饼实验台");
            Check(main.HasNode("UI/MorningHub"), "Main 包含营业准备大厅");
            Check(main.HasNode("UI/TianjinDayScreen"), "Main 包含正式营业界面");
            main.Free();
        }

        PackedScene? shopResource = ResourceLoader.Load<PackedScene>("res://Scenes/Shop/TianjinShop.tscn");
        Check(shopResource is not null, "TianjinShop 场景可加载");
        if (shopResource is not null)
        {
            Node shop = shopResource.Instantiate();
            string[] requiredNodes =
            {
                "Workbench/FryerStation",
                "Workbench/PancakeStation",
                "Workbench/IngredientArea/BatterTray",
                "Workbench/SoyMilkTray",
                "Workbench/DeliveryZone",
                "Customers/QueueSlot1",
                "Customers/QueueSlot5",
                "InteractionLayer",
                "Effects",
            };
            foreach (string nodePath in requiredNodes)
            {
                Check(shop.HasNode(nodePath), $"TianjinShop 包含 {nodePath}");
            }

            shop.Free();
        }
    }

    private void CheckStove(
        DataCatalog catalog,
        int level,
        bool canBurn,
        float sideAReady,
        float sideBReady,
        float sideAOverdone,
        float sideABurn,
        float sideBBurn,
        int price)
    {
        bool found = catalog.TryGetStove(level, out PancakeStoveLevelData stove);
        Check(found, $"煎饼炉 Lv{level} 存在");
        if (!found)
        {
            return;
        }

        bool matches = stove.CanBurn == canBurn
            && IsClose(stove.SideAReadySeconds, sideAReady)
            && IsClose(stove.SideBReadySeconds, sideBReady)
            && IsClose(stove.SideAOverdoneSeconds, sideAOverdone)
            && IsClose(stove.SideABurnSeconds, sideABurn)
            && IsClose(stove.SideBBurnSeconds, sideBBurn)
            && stove.UpgradePrice == price;
        Check(matches, $"煎饼炉 Lv{level} 数值正确");
    }

    private void CheckDay(
        DataCatalog catalog,
        int dayNumber,
        double duration,
        int customers,
        int revenue,
        double patience,
        int seed,
        IReadOnlyDictionary<string, double> expectedWeights)
    {
        bool found = catalog.TryGetDay(dayNumber, out DayConfig day);
        Check(found, $"Day {dayNumber} 存在");
        if (!found)
        {
            return;
        }

        bool basicsMatch = IsClose(day.DurationSeconds, duration)
            && day.CustomerCount == customers
            && day.ExpectedRevenue == revenue
            && IsClose(day.PatienceMultiplier, patience)
            && day.MaxWaitingCustomers == 5
            && day.RandomSeed == seed;
        Check(basicsMatch, $"Day {dayNumber} 基础数值正确");

        bool weightsMatch = day.RecipeWeights.Count == expectedWeights.Count
            && expectedWeights.All(expected =>
                day.RecipeWeights.TryGetValue(expected.Key, out double actual) && IsClose(actual, expected.Value));
        Check(weightsMatch, $"Day {dayNumber} 配方权重正确");

        bool arrivalMatches = day.ArrivalSegments.Count == 3
            && IsClose(day.ArrivalSegments[0].CustomerRatio, 0.20)
            && IsClose(day.ArrivalSegments[1].CustomerRatio, 0.60)
            && IsClose(day.ArrivalSegments[2].CustomerRatio, 0.20);
        Check(arrivalMatches, $"Day {dayNumber} 到店分段正确");
    }

    private void RequireIssue(
        IReadOnlyList<ValidationIssue> issues,
        string fieldFragment,
        string messageFragment,
        string testName)
    {
        ValidationIssue? match = issues.FirstOrDefault(issue =>
            issue.Field.Contains(fieldFragment, StringComparison.OrdinalIgnoreCase)
            && issue.Message.Contains(messageFragment, StringComparison.Ordinal));
        Check(match is not null, testName, FormatIssues(issues));
    }

    private void Check(bool condition, string name, string details = "")
    {
        if (condition)
        {
            _passed++;
            GD.Print($"[PASS] {name}");
            return;
        }

        _failed++;
        GD.PushError($"[FAIL] {name}{(string.IsNullOrWhiteSpace(details) ? string.Empty : $"：{details}")}");
    }

    private static bool IsClose(double left, double right) => Math.Abs(left - right) <= 0.0001;

    private static string FormatIssues(IReadOnlyList<ValidationIssue> issues) =>
        issues.Count == 0 ? "没有返回错误信息" : string.Join(" | ", issues.Select(issue => issue.ToString()));
}
