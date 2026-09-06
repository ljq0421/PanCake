namespace ProjectCake.Data;

public static class WuhanCatalogValidator
{
    private const double Tolerance = 0.0001;

    public static IReadOnlyList<ValidationIssue> Validate(
        IReadOnlyList<DayConfig> days,
        IReadOnlyList<RecipeData> recipes,
        IReadOnlyList<CustomerTypeData> customers,
        IReadOnlyList<NoodleCookerLevelData> cookers,
        IReadOnlyList<DoupiGriddleLevelData> griddles,
        IReadOnlyList<WuhanIngredientStationLevelData> stations)
    {
        var issues = new List<ValidationIssue>();
        int[] numbers = days.Select(day => day.Day).OrderBy(day => day).ToArray();
        if (!numbers.SequenceEqual(Enumerable.Range(1, 12))) Add(issues, "res://Data/Days/Wuhan", "day", "武汉章节必须包含连续的 Day 1～12。");
        if (Math.Abs(days.Sum(day => day.DurationSeconds) - 1400) > Tolerance) Add(issues, "res://Data/Days/Wuhan", "durationSeconds", "武汉 12 天营业时长合计必须为 1400 秒。");
        if (days.Sum(day => day.ExpectedRevenue) != 2389) Add(issues, "res://Data/Days/Wuhan", "expectedRevenue", "武汉预计基础收入合计必须为 2389。");

        var knownRecipes = recipes.Select(item => item.Id).ToHashSet(StringComparer.Ordinal);
        var knownCustomers = customers.Select(item => item.Id).ToHashSet(StringComparer.Ordinal);
        foreach (DayConfig day in days)
        {
            string source = string.IsNullOrWhiteSpace(day.SourcePath) ? $"<Wuhan Day {day.Day}>" : day.SourcePath;
            ValidateWeights(day.CustomerWeights, knownCustomers, source, "customerWeights", issues);
            ValidateWeights(day.OrderTypeWeights, StableIds.OrderTypeIds, source, "orderTypeWeights", issues);
            ValidateWeights(day.RecipeWeights, knownRecipes, source, "recipeWeights", issues);
            if (day.MaxWaitingCustomers != 4) Add(issues, source, "maxWaitingCustomers", "武汉同屏未完成顾客硬上限必须为 4。");
            if (day.SatisfactionAverageMode != SatisfactionAverageMode.CompletedCustomers) Add(issues, source, "satisfactionAverageMode", "武汉满意度必须只统计已完成订单。");
        }
        DayConfig? day12 = days.FirstOrDefault(day => day.Day == 12);
        if (day12 is null || day12.StarGoals.Count != 3) Add(issues, "res://Data/Days/Wuhan/day_12.json", "starGoals", "武汉 Day 12 必须配置三个星级目标。");
        ValidateLevels(cookers.Select(item => item.Level), "res://Data/Equipment/Wuhan/NoodleCookers", issues);
        ValidateLevels(griddles.Select(item => item.Level), "res://Data/Equipment/Wuhan/DoupiGriddles", issues);
        ValidateLevels(stations.Select(item => item.Level), "res://Data/Equipment/Wuhan/IngredientStations", issues);
        int totalPrice = cookers.Sum(item => item.UpgradePrice) + griddles.Sum(item => item.UpgradePrice) + stations.Sum(item => item.UpgradePrice);
        if (totalPrice != 2000) Add(issues, "res://Data/Equipment/Wuhan", "upgradePrice", "武汉付费升级价格合计必须为 2000。");
        return issues;
    }

    private static void ValidateWeights(IReadOnlyDictionary<string, double> weights, IEnumerable<string> allowedIds, string source, string field, List<ValidationIssue> issues)
    {
        var allowed = allowedIds.ToHashSet(StringComparer.Ordinal);
        if (weights.Count == 0 || Math.Abs(weights.Values.Sum() - 1) > Tolerance) Add(issues, source, field, "权重不能为空且合计必须为 1.0。");
        foreach ((string id, double weight) in weights) if (!allowed.Contains(id) || weight <= 0) Add(issues, source, $"{field}.{id}", "权重 ID 必须已注册且数值大于 0。");
    }

    private static void ValidateLevels(IEnumerable<int> levels, string source, List<ValidationIssue> issues)
    {
        if (!levels.OrderBy(value => value).SequenceEqual(new[] { 1, 2, 3 })) Add(issues, source, "level", "设备等级必须为连续的 Lv1～Lv3。");
    }

    private static void Add(List<ValidationIssue> issues, string source, string field, string message) => issues.Add(new ValidationIssue(source, field, message));
}
