namespace ProjectCake.Data;

public static class CatalogValidator
{
    private const double WeightTolerance = 0.0001;

    public static IReadOnlyList<ValidationIssue> ValidateAll(
        IReadOnlyList<RecipeData> recipes,
        IReadOnlyList<PancakeStoveLevelData> stoves,
        IReadOnlyList<IngredientStationLevelData> ingredientStations,
        IReadOnlyList<FryerLevelData> fryers,
        IReadOnlyList<ProductData> products,
        IReadOnlyList<CustomerTypeData> customers,
        IReadOnlyList<DayConfig> days)
    {
        var issues = new List<ValidationIssue>();
        ValidateRecipes(recipes, issues);
        ValidateStoves(stoves, issues);
        ValidateIngredientStations(ingredientStations, issues);
        ValidateFryers(fryers, issues);
        ValidateProducts(products, issues);
        ValidateCustomers(customers, issues);
        ValidateDays(days, recipes, issues);
        if (days.Count != 15 || days.Select(day => day.Day).OrderBy(day => day).LastOrDefault() != 15)
            Add(issues, "res://Data/Days/Tianjin", "day", "天津章节必须包含连续的 Day 1～15。" );
        var knownCustomers = customers.Select(customer => customer.Id).ToHashSet(StringComparer.Ordinal);
        foreach (DayConfig day in days)
        {
            foreach (string id in day.CustomerWeights.Keys.Where(id => !knownCustomers.Contains(id)))
            {
                Add(issues, day.SourcePath, $"customerWeights.{id}", $"未加载顾客类型资源：{id}。");
            }
        }
        return issues;
    }

    private static void ValidateProducts(IReadOnlyList<ProductData> products, List<ValidationIssue> issues)
    {
        var ids = new HashSet<string>(StringComparer.Ordinal);
        var kinds = new HashSet<ProductKind>();
        foreach (ProductData product in products)
        {
            string source = SourceOf(product.ResourcePath, "ProductData");
            if (string.IsNullOrWhiteSpace(product.Id) || !ids.Add(product.Id))
            {
                Add(issues, source, "Id", "商品 ID 不能为空或重复。");
            }
            else if (!StableIds.Products.All.Contains(product.Id))
            {
                Add(issues, source, "Id", $"商品 ID 未在稳定 ID 目录注册：{product.Id}。");
            }
            if (product.Kind == ProductKind.Pancake || !kinds.Add(product.Kind))
            {
                Add(issues, source, "Kind", "独立商品类型必须是唯一的油条或豆浆。");
            }
            if (string.IsNullOrWhiteSpace(product.DisplayName)) Add(issues, source, "DisplayName", "商品显示名不能为空。");
            if (product.UnitPrice <= 0) Add(issues, source, "UnitPrice", "商品单价必须大于 0。");
        }
    }

    private static void ValidateFryers(IReadOnlyList<FryerLevelData> fryers, List<ValidationIssue> issues)
    {
        var levels = new HashSet<int>();
        foreach (FryerLevelData fryer in fryers)
        {
            string source = SourceOf(fryer.ResourcePath, "FryerLevelData");
            if (fryer.Level <= 0 || !levels.Add(fryer.Level)) Add(issues, source, "Level", "油条锅等级必须大于 0 且不能重复。");
            if (fryer.Capacity <= 0) Add(issues, source, "Capacity", "油条锅容量必须大于 0。");
            if (fryer.GoldenStartSeconds <= 0 || fryer.GoldenEndSeconds <= fryer.GoldenStartSeconds)
                Add(issues, source, "GoldenSeconds", "油条金黄区间必须严格递增且大于 0。");
            if (fryer.DrainSeconds <= 0) Add(issues, source, "DrainSeconds", "沥油时间必须大于 0。");
            if (fryer.UpgradePrice < 0) Add(issues, source, "UpgradePrice", "升级价格不能为负数。");
            if (fryer.AutoRaise)
            {
                if (fryer.AutoRaiseAtSeconds < fryer.GoldenStartSeconds || fryer.AutoRaiseAtSeconds > fryer.GoldenEndSeconds)
                    Add(issues, source, "AutoRaiseAtSeconds", "自动抬篮时间必须位于金黄区间内。");
                if (fryer.BurnAtSeconds != 0) Add(issues, source, "BurnAtSeconds", "自动抬篮油条锅的焦糊时间必须为 0。");
            }
            else if (fryer.AutoRaiseAtSeconds != 0 || fryer.BurnAtSeconds <= fryer.GoldenEndSeconds)
            {
                Add(issues, source, "BurnAtSeconds", "手动油条锅必须在金黄区间后设置焦糊时间，且自动抬篮时间为 0。");
            }
        }

        int[] ordered = levels.OrderBy(level => level).ToArray();
        for (int index = 0; index < ordered.Length; index++)
        {
            if (ordered[index] != index + 1)
            {
                Add(issues, "res://Data/Equipment/Fryers", "Level", $"油条锅等级必须从 Lv1 连续排列；缺少 Lv{index + 1}。");
                break;
            }
        }
    }

    private static void ValidateCustomers(IReadOnlyList<CustomerTypeData> customers, List<ValidationIssue> issues)
    {
        var ids = new HashSet<string>(StringComparer.Ordinal);
        foreach (CustomerTypeData customer in customers)
        {
            string source = SourceOf(customer.ResourcePath, "CustomerTypeData");
            if (string.IsNullOrWhiteSpace(customer.Id) || !ids.Add(customer.Id))
            {
                Add(issues, source, "Id", "顾客类型 ID 不能为空或重复。");
            }
            else if (!StableIds.CustomerTypeIds.Contains(customer.Id))
            {
                Add(issues, source, "Id", $"顾客类型 ID 未在稳定 ID 目录注册：{customer.Id}。" );
            }
            if (string.IsNullOrWhiteSpace(customer.DisplayName))
            {
                Add(issues, source, "DisplayName", "顾客类型显示名不能为空。");
            }
            if (customer.HappyUntilSeconds <= 0
                || customer.NormalUntilSeconds <= customer.HappyUntilSeconds
                || customer.ImpatientUntilSeconds <= customer.NormalUntilSeconds
                || customer.LeaveAtSeconds <= customer.ImpatientUntilSeconds)
            {
                Add(issues, source, "PatienceThresholds", "顾客耐心阈值必须严格递增且大于 0。");
            }
            if (customer.PerfectTipRate < 0)
            {
                Add(issues, source, "PerfectTipRate", "Perfect 小费率不能为负数。");
            }
        }
    }

    private static void ValidateIngredientStations(
        IReadOnlyList<IngredientStationLevelData> stations,
        List<ValidationIssue> issues)
    {
        var levels = new HashSet<int>();
        foreach (IngredientStationLevelData station in stations)
        {
            string source = SourceOf(station.ResourcePath, "IngredientStationLevelData");
            if (station.Level <= 0)
            {
                Add(issues, source, "Level", "配料台等级必须大于 0。");
            }
            else if (!levels.Add(station.Level))
            {
                Add(issues, source, "Level", $"配料台等级重复：Lv{station.Level}。");
            }

            var capacities = new Dictionary<string, int>
            {
                ["BatterCapacity"] = station.BatterCapacity,
                ["EggCapacity"] = station.EggCapacity,
                ["SauceCapacity"] = station.SauceCapacity,
                ["CrispyCapacity"] = station.CrispyCapacity,
                ["ScallionCapacity"] = station.ScallionCapacity,
                ["HamCapacity"] = station.HamCapacity,
            };
            foreach ((string field, int capacity) in capacities)
            {
                if (capacity <= 0)
                {
                    Add(issues, source, field, "食材容量必须大于 0。");
                }
            }

            if (station.RefillSeconds <= 0)
            {
                Add(issues, source, "RefillSeconds", "补料时间必须大于 0。");
            }

            if (station.UpgradePrice < 0)
            {
                Add(issues, source, "UpgradePrice", "升级价格不能为负数。");
            }
        }

        int[] orderedLevels = levels.OrderBy(level => level).ToArray();
        for (int index = 0; index < orderedLevels.Length; index++)
        {
            int expected = index + 1;
            if (orderedLevels[index] != expected)
            {
                Add(issues, "res://Data/Equipment/IngredientStations", "Level",
                    $"配料台等级必须从 Lv1 连续排列；缺少 Lv{expected}。");
                break;
            }
        }
    }

    public static IReadOnlyList<ValidationIssue> ValidateDays(
        IReadOnlyList<DayConfig> days,
        IReadOnlyList<RecipeData> recipes)
    {
        var issues = new List<ValidationIssue>();
        ValidateDays(days, recipes, issues);
        return issues;
    }

    public static IReadOnlyList<ValidationIssue> ValidateRecipes(IReadOnlyList<RecipeData> recipes)
    {
        var issues = new List<ValidationIssue>();
        ValidateRecipes(recipes, issues);
        return issues;
    }

    private static void ValidateRecipes(IReadOnlyList<RecipeData> recipes, List<ValidationIssue> issues)
    {
        var ids = new HashSet<string>(StringComparer.Ordinal);

        foreach (RecipeData recipe in recipes)
        {
            string source = SourceOf(recipe.ResourcePath, "RecipeData");
            if (string.IsNullOrWhiteSpace(recipe.Id))
            {
                Add(issues, source, "Id", "配方 ID 不能为空。");
                continue;
            }

            if (!ids.Add(recipe.Id))
            {
                Add(issues, source, "Id", $"配方 ID 重复：{recipe.Id}。");
            }

            if (!StableIds.Recipes.All.Contains(recipe.Id))
            {
                Add(issues, source, "Id", $"配方 ID 未在稳定 ID 目录注册：{recipe.Id}。");
            }

            if (string.IsNullOrWhiteSpace(recipe.DisplayName))
            {
                Add(issues, source, "DisplayName", "配方显示名不能为空。");
            }

            if (recipe.Price <= 0)
            {
                Add(issues, source, "Price", "配方价格必须大于 0。" );
            }

            var ingredients = new HashSet<string>(StringComparer.Ordinal);
            foreach (string ingredientId in recipe.ExtraIngredients)
            {
                if (!ingredients.Add(ingredientId))
                {
                    Add(issues, source, "ExtraIngredients", $"配料重复：{ingredientId}。");
                }

                if (!StableIds.IngredientIds.Contains(ingredientId))
                {
                    Add(issues, source, "ExtraIngredients", $"未知配料 ID：{ingredientId}。");
                }
            }
        }
    }

    private static void ValidateStoves(IReadOnlyList<PancakeStoveLevelData> stoves, List<ValidationIssue> issues)
    {
        var levels = new HashSet<int>();

        foreach (PancakeStoveLevelData stove in stoves)
        {
            string source = SourceOf(stove.ResourcePath, "PancakeStoveLevelData");
            if (stove.Level <= 0)
            {
                Add(issues, source, "Level", "设备等级必须大于 0。");
            }
            else if (!levels.Add(stove.Level))
            {
                Add(issues, source, "Level", $"设备等级重复：Lv{stove.Level}。");
            }

            if (stove.SideAReadySeconds <= 0 || stove.SideBReadySeconds <= 0)
            {
                Add(issues, source, "ReadySeconds", "两面的熟制时间都必须大于 0。");
            }

            if (stove.UpgradePrice < 0)
            {
                Add(issues, source, "UpgradePrice", "升级价格不能为负数。");
            }

            if (stove.CanBurn)
            {
                if (stove.SideAOverdoneSeconds <= stove.SideAReadySeconds
                    || stove.SideAOverdoneSeconds >= stove.SideABurnSeconds)
                {
                    Add(issues, source, "SideAOverdoneSeconds", "第一面偏焦时点必须位于熟制和焦糊时点之间。");
                }

                if (stove.SideABurnSeconds <= stove.SideAReadySeconds)
                {
                    Add(issues, source, "SideABurnSeconds", "第一面焦糊时点必须晚于熟制时点。");
                }

                if (stove.SideBBurnSeconds <= stove.SideBReadySeconds)
                {
                    Add(issues, source, "SideBBurnSeconds", "第二面焦糊时点必须晚于熟制时点。");
                }
            }
            else if (stove.SideAOverdoneSeconds != 0 || stove.SideABurnSeconds != 0 || stove.SideBBurnSeconds != 0)
            {
                Add(issues, source, "BurnSeconds", "不会焦的炉具必须将两面的焦糊时点设为 0。");
            }
        }

        int[] orderedLevels = levels.OrderBy(level => level).ToArray();
        for (int index = 0; index < orderedLevels.Length; index++)
        {
            int expected = index + 1;
            if (orderedLevels[index] != expected)
            {
                Add(issues, "res://Data/Equipment", "Level", $"设备等级必须从 Lv1 连续排列；缺少 Lv{expected}。");
                break;
            }
        }
    }

    private static void ValidateDays(
        IReadOnlyList<DayConfig> days,
        IReadOnlyList<RecipeData> recipes,
        List<ValidationIssue> issues)
    {
        var knownRecipes = recipes
            .Where(recipe => !string.IsNullOrWhiteSpace(recipe.Id))
            .GroupBy(recipe => recipe.Id, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);
        var dayNumbers = new HashSet<int>();
        var unlockedIds = new HashSet<string>(StringComparer.Ordinal);
        var unlockedRecipes = new HashSet<string>(StringComparer.Ordinal);
        var unlockedProductKinds = new HashSet<ProductKind> { ProductKind.Pancake };

        foreach (DayConfig day in days.OrderBy(day => day.Day))
        {
            string source = SourceOf(day.SourcePath, $"Day {day.Day}");

            if (day.Day <= 0)
            {
                Add(issues, source, "day", "日期必须大于 0。");
            }
            else if (!dayNumbers.Add(day.Day))
            {
                Add(issues, source, "day", $"日期重复：Day {day.Day}。");
            }

            ValidatePositive(day.DurationSeconds, source, "durationSeconds", "营业时长", issues);
            ValidatePositive(day.CustomerCount, source, "customerCount", "顾客数", issues);
            ValidateNonNegative(day.ExpectedRevenue, source, "expectedRevenue", "预期收入", issues);
            ValidatePositive(day.PatienceMultiplier, source, "patienceMultiplier", "耐心倍率", issues);
            ValidatePositive(day.MaxWaitingCustomers, source, "maxWaitingCustomers", "最大等待人数", issues);
            ValidatePositive(day.RandomSeed, source, "randomSeed", "随机种子", issues);

            ValidateUnlockList(day.StartUnlocks, source, "startUnlocks", unlockedIds, unlockedRecipes, issues);
            ApplyProductUnlocks(day.StartUnlocks, unlockedProductKinds);
            ValidateWeights(day.CustomerWeights, source, "customerWeights", StableIds.CustomerTypeIds, issues);
            ValidateWeights(day.OrderTypeWeights, source, "orderTypeWeights", StableIds.OrderTypeIds, issues);
            ValidateWeights(day.RecipeWeights, source, "recipeWeights", knownRecipes.Keys, issues);
            ValidateArrivalSegments(day.ArrivalSegments, source, issues);

            var availableRecipes = new HashSet<string>(StringComparer.Ordinal);
            foreach (string recipeId in day.AvailableRecipeIds)
            {
                if (!availableRecipes.Add(recipeId))
                {
                    Add(issues, source, "availableRecipeIds", $"可用配方重复：{recipeId}。");
                }

                if (!knownRecipes.ContainsKey(recipeId))
                {
                    Add(issues, source, "availableRecipeIds", $"未知配方 ID：{recipeId}。");
                }

                if (!unlockedRecipes.Contains(recipeId))
                {
                    Add(issues, source, "availableRecipeIds", $"配方在解锁前被引用：{recipeId}。");
                }
            }

            if (!availableRecipes.SetEquals(unlockedRecipes))
            {
                Add(issues, source, "availableRecipeIds", "可用配方必须与截至当日开店时已解锁的配方完全一致。");
            }

            foreach (string recipeId in day.RecipeWeights.Keys)
            {
                if (!availableRecipes.Contains(recipeId))
                {
                    Add(issues, source, "recipeWeights", $"配方权重引用了当日不可用配方：{recipeId}。");
                }
            }

            if (day.AvailableProductKinds.Count == 0)
            {
                Add(issues, source, "availableProductKinds", "至少需要一种可用商品类型。");
            }
            else if (day.AvailableProductKinds.Count != day.AvailableProductKinds.Distinct().Count())
            {
                Add(issues, source, "availableProductKinds", "可用商品类型不能重复。");
            }
            else if (!day.AvailableProductKinds.ToHashSet().SetEquals(unlockedProductKinds))
            {
                Add(issues, source, "availableProductKinds", "可用商品类型必须与截至当日开店时已解锁商品完全一致。");
            }

            bool hasYoutiao = day.AvailableProductKinds.Contains(ProductKind.Youtiao);
            bool hasSoyMilk = day.AvailableProductKinds.Contains(ProductKind.SoyMilk);
            foreach (string orderType in day.OrderTypeWeights.Keys)
            {
                if (!hasYoutiao && orderType is "youtiao" or "pancake_youtiao" or "full_combo")
                    Add(issues, source, $"orderTypeWeights.{orderType}", "订单在油条解锁前被引用。" );
                if (!hasSoyMilk && orderType is "soy_milk" or "pancake_soy_milk" or "full_combo")
                    Add(issues, source, $"orderTypeWeights.{orderType}", "订单在豆浆解锁前被引用。" );
            }

            bool hasBigOrderWeight = day.CustomerWeights.ContainsKey("big_order");
            if (hasBigOrderWeight != (day.Constraints.MaxBigOrderCustomers > 0))
                Add(issues, source, "constraints.maxBigOrderCustomers", "大订单顾客权重与每日数量上限必须同时启用或同时关闭。" );
            if (day.Constraints.MaxBigOrderCustomers > day.CustomerCount)
                Add(issues, source, "constraints.maxBigOrderCustomers", "大订单顾客上限不能超过当日顾客数。" );

            if (day.Day is 5 or 7 or 9 && day.Constraints.SimpleNewProductOrders < 2)
                Add(issues, source, "constraints.simpleNewProductOrders", "教学日必须为前两份固定教学订单保留名额。" );

            ValidateConstraints(day.Constraints, source, issues);
            ValidateStarGoals(day, source, issues);
            ValidateUnlockList(day.CompletionUnlocks, source, "completionUnlocks", unlockedIds, unlockedRecipes, issues);
            ApplyProductUnlocks(day.CompletionUnlocks, unlockedProductKinds);
        }

        int[] orderedDays = dayNumbers.OrderBy(day => day).ToArray();
        for (int index = 0; index < orderedDays.Length; index++)
        {
            int expected = index + 1;
            if (orderedDays[index] != expected)
            {
                Add(issues, "res://Data/Days/Tianjin", "day", $"每日配置必须从 Day 1 连续排列；缺少 Day {expected}。");
                break;
            }
        }
    }

    private static void ApplyProductUnlocks(IEnumerable<string> unlocks, HashSet<ProductKind> productKinds)
    {
        foreach (string unlock in unlocks)
        {
            if (unlock == "product:youtiao") productKinds.Add(ProductKind.Youtiao);
            else if (unlock == "product:soy_milk") productKinds.Add(ProductKind.SoyMilk);
        }
    }

    private static void ValidateStarGoals(DayConfig day, string source, List<ValidationIssue> issues)
    {
        if (day.Day != 15 && day.StarGoals.Count > 0)
        {
            Add(issues, source, "starGoals", "只有 Day 15 可以配置天津章节星级。");
        }
        if (day.Day == 15 && day.StarGoals.Count != 3)
        {
            Add(issues, source, "starGoals", "Day 15 必须配置一至三星三个目标。");
        }

        for (int index = 0; index < day.StarGoals.Count; index++)
        {
            StarGoalConfig goal = day.StarGoals[index];
            if (goal.Stars != index + 1) Add(issues, source, $"starGoals[{index}].stars", "星级必须从 1 连续排列。");
            if (goal.MinimumCompletedCustomers < 0 || goal.MinimumCompletedCustomers > day.CustomerCount)
                Add(issues, source, $"starGoals[{index}].minimumCompletedCustomers", "完成顾客数必须位于当日顾客数范围内。");
            if (goal.MinimumSatisfaction is < 0 or > 100)
                Add(issues, source, $"starGoals[{index}].minimumSatisfaction", "满意度必须位于 0～100。");
            if (goal.MinimumPerfectOrders < 0 || goal.MinimumPerfectOrders > day.CustomerCount)
                Add(issues, source, $"starGoals[{index}].minimumPerfectOrders", "Perfect 数必须位于当日顾客数范围内。");
        }
    }

    private static void ValidateUnlockList(
        IReadOnlyList<string> unlocks,
        string source,
        string field,
        HashSet<string> unlockedIds,
        HashSet<string> unlockedRecipes,
        List<ValidationIssue> issues)
    {
        foreach (string unlockId in unlocks)
        {
            if (!StableIds.UnlockIds.Contains(unlockId))
            {
                Add(issues, source, field, $"未知解锁 ID：{unlockId}。");
                continue;
            }

            if (!unlockedIds.Add(unlockId))
            {
                Add(issues, source, field, $"解锁 ID 重复出现：{unlockId}。");
            }

            const string recipePrefix = "recipe:";
            if (unlockId.StartsWith(recipePrefix, StringComparison.Ordinal))
            {
                unlockedRecipes.Add(unlockId[recipePrefix.Length..]);
            }
        }
    }

    private static void ValidateWeights(
        IReadOnlyDictionary<string, double> weights,
        string source,
        string field,
        IEnumerable<string> allowedIds,
        List<ValidationIssue> issues)
    {
        if (weights.Count == 0)
        {
            Add(issues, source, field, "权重表不能为空。");
            return;
        }

        var allowed = new HashSet<string>(allowedIds, StringComparer.Ordinal);
        double sum = 0;
        foreach ((string id, double weight) in weights)
        {
            if (!allowed.Contains(id))
            {
                Add(issues, source, field, $"权重引用未知 ID：{id}。");
            }

            if (weight <= 0)
            {
                Add(issues, source, field, $"{id} 的权重必须大于 0。");
            }

            sum += weight;
        }

        if (Math.Abs(sum - 1.0) > WeightTolerance)
        {
            Add(issues, source, field, $"权重合计必须为 1.0，当前为 {sum:0.####}。");
        }
    }

    private static void ValidateArrivalSegments(
        IReadOnlyList<ArrivalSegmentConfig> segments,
        string source,
        List<ValidationIssue> issues)
    {
        if (segments.Count == 0)
        {
            Add(issues, source, "arrivalSegments", "到店时段不能为空。");
            return;
        }

        double previousEnd = 0;
        double ratioSum = 0;
        for (int index = 0; index < segments.Count; index++)
        {
            ArrivalSegmentConfig segment = segments[index];
            string field = $"arrivalSegments[{index}]";

            if (segment.Start < 0 || segment.End > 1 || segment.Start >= segment.End)
            {
                Add(issues, source, field, "时段必须满足 0 ≤ start < end ≤ 1。");
            }

            if (Math.Abs(segment.Start - previousEnd) > WeightTolerance)
            {
                Add(issues, source, field, $"时段必须连续覆盖；预期从 {previousEnd:0.####} 开始。" );
            }

            if (segment.CustomerRatio <= 0)
            {
                Add(issues, source, $"{field}.customerRatio", "顾客比例必须大于 0。");
            }

            previousEnd = segment.End;
            ratioSum += segment.CustomerRatio;
        }

        if (Math.Abs(previousEnd - 1.0) > WeightTolerance)
        {
            Add(issues, source, "arrivalSegments", "时段必须连续覆盖到 1.0。");
        }

        if (Math.Abs(ratioSum - 1.0) > WeightTolerance)
        {
            Add(issues, source, "arrivalSegments", $"顾客比例合计必须为 1.0，当前为 {ratioSum:0.####}。");
        }
    }

    private static void ValidateConstraints(DayConstraintConfig constraints, string source, List<ValidationIssue> issues)
    {
        ValidateNonNegative(constraints.MaxBigOrderCustomers, source, "constraints.maxBigOrderCustomers", "大订单顾客上限", issues);
        ValidateNonNegative(constraints.SimpleNewProductOrders, source, "constraints.simpleNewProductOrders", "新商品简单订单数", issues);
        ValidatePositive(constraints.MaxConsecutiveYoutiaoOrders, source, "constraints.maxConsecutiveYoutiaoOrders", "连续油条订单上限", issues);
        ValidatePositive(constraints.MaxPancakesPerCustomer, source, "constraints.maxPancakesPerCustomer", "每位顾客煎饼上限", issues);
    }

    private static void ValidatePositive(double value, string source, string field, string displayName, List<ValidationIssue> issues)
    {
        if (value <= 0)
        {
            Add(issues, source, field, $"{displayName}必须大于 0。");
        }
    }

    private static void ValidateNonNegative(double value, string source, string field, string displayName, List<ValidationIssue> issues)
    {
        if (value < 0)
        {
            Add(issues, source, field, $"{displayName}不能为负数。");
        }
    }

    private static string SourceOf(string source, string fallback) =>
        string.IsNullOrWhiteSpace(source) ? $"<memory:{fallback}>" : source;

    private static void Add(List<ValidationIssue> issues, string source, string field, string message) =>
        issues.Add(new ValidationIssue(source, field, message));
}
