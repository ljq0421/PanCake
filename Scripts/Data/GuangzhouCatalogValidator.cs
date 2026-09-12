using ProjectCake.Guangzhou;

namespace ProjectCake.Data;

public static class GuangzhouCatalogValidator
{
    public static IReadOnlyList<ValidationIssue> Validate(IReadOnlyList<DayConfig> days, IReadOnlyList<RecipeData> recipes,
        IReadOnlyList<ProductData> products, IReadOnlyList<CustomerTypeData> customers, IReadOnlyList<GuangzhouEquipmentData> equipment)
    {
        var issues = new List<ValidationIssue>();
        const string root = "res://Data/Days/Guangzhou";
        void Check(bool valid, string path, string field, string text) { if (!valid) issues.Add(new(path, field, text)); }
        Check(days.Select(d => d.Day).Order().SequenceEqual(Enumerable.Range(1, 12)), root, "day", "广州必须包含连续且不重复的12天。");
        Check(recipes.Count == 5 && recipes.Select(r => r.Id).ToHashSet().SetEquals(GuangzhouRules.Recipes), root, "recipes", "广州必须包含G0～G4。");
        int[] prices = { 7, 8, 10, 12, 11 };
        string[][] extras = { Array.Empty<string>(), new[] { GuangzhouRules.Egg }, new[] { GuangzhouRules.Pork }, new[] { GuangzhouRules.Shrimp }, new[] { GuangzhouRules.Egg, GuangzhouRules.Pork } };
        for (int i = 0; i < 5; i++)
            Check(recipes.Any(r => r.Id == GuangzhouRules.Recipes[i] && r.Price == prices[i] && r.ExtraIngredients.ToHashSet().SetEquals(extras[i])), root, "recipes", "肠粉价格或配料不符合策划。");
        Check(products.Count == 3 && products.Any(p => p.Id == GuangzhouRules.SiuMai && p.Kind == ProductKind.SiuMai && p.UnitPrice == 6)
            && products.Any(p => p.Id == GuangzhouRules.HarGow && p.Kind == ProductKind.HarGow && p.UnitPrice == 8)
            && products.Any(p => p.Id == GuangzhouRules.Tea && p.Kind == ProductKind.MorningTea && p.UnitPrice == 3), root, "products", "蒸点和茶商品配置错误。");
        Check(customers.Count == 5 && customers.Select(c => c.Id).ToHashSet().SetEquals(GuangzhouRules.Customers), root, "customers", "广州需要五类顾客。");
        foreach (var c in customers)
            Check(c.LeaveAtSeconds > c.ImpatientUntilSeconds && c.ImpatientUntilSeconds > c.NormalUntilSeconds && c.NormalUntilSeconds > c.HappyUntilSeconds && c.HappyUntilSeconds > 0 && c.PerfectTipRate > 0, c.ResourcePath, "patience", "顾客耐心和小费配置无效。");
        Check(equipment.Count == 9 && equipment.Sum(e => e.UpgradePrice) == 1460, root, "equipment", "广州设备需要9项配置，升级总价1460。");
        foreach (string id in GuangzhouRules.Equipment)
            Check(equipment.Where(e => e.EquipmentId == id).Select(e => e.Level).Order().SequenceEqual(new[] { 1, 2, 3 }), root, "equipment", "每种设备必须有连续三级。");
        foreach (var e in equipment)
            Check(e.UpgradePrice >= 0 && e.UnlockAfterDay >= 0 && (e.EquipmentId == GuangzhouRules.Station
                ? new[] { e.BatterCapacity, e.EggCapacity, e.PorkCapacity, e.ShrimpCapacity, e.SauceCapacity }.All(n => n > 0)
                : e.Capacity > 0 && e.CookSeconds > 0 && e.BestWindowSeconds > 0 && e.NormalWindowSeconds > 0 && (e.EquipmentId != GuangzhouRules.Cabinet || e.HarGowCookSeconds > 0)), e.ResourcePath, "equipment", "设备容量、时间或价格无效。");
        var knownUnlocks = GuangzhouRules.Recipes.Select(r => $"recipe:{r}").Concat(products.Select(p => $"product:{p.Id}"))
            .Concat(equipment.Select(e => $"equipment:{e.EquipmentId}_lv{e.Level}")).ToHashSet();
        foreach (var d in days)
        {
            void Weights(Dictionary<string, double> values, IEnumerable<string> allowed, string field) => Check(values.Count > 0
                && Math.Abs(values.Values.Sum() - 1) < .00001 && values.All(p => double.IsFinite(p.Value) && p.Value > 0 && allowed.Contains(p.Key)), d.SourcePath, field, "权重必须为已开放ID、正值且总和为1。");
            Check(d.Day is >= 1 and <= 12 && d.CityId == StableIds.Cities.Guangzhou && d.DurationSeconds > 0 && d.CustomerCount > 0
                && d.MaxWaitingCustomers == 5 && d.SatisfactionAverageMode == SatisfactionAverageMode.CompletedCustomers && d.RandomSeed > 0 && d.PatienceMultiplier == 1, d.SourcePath, "day", "广州营业配置无效。");
            var unlocked = GuangzhouRules.Recipes.Where((_, i) => GuangzhouRules.RecipeUnlockDay(i) <= d.Day).ToArray();
            Weights(d.RecipeWeights, unlocked, "recipeWeights");
            Check(d.AvailableRecipeIds.Count == unlocked.Length && d.AvailableRecipeIds.ToHashSet().SetEquals(unlocked), d.SourcePath, "availableRecipeIds", "配方未按日开放。");
            var kinds = new List<ProductKind> { ProductKind.RiceRoll };
            if (d.Day >= 5) kinds.Add(ProductKind.SiuMai); if (d.Day >= 8) kinds.Add(ProductKind.MorningTea); if (d.Day >= 9) kinds.Add(ProductKind.HarGow);
            Check(d.AvailableProductKinds.Count == kinds.Count && d.AvailableProductKinds.ToHashSet().SetEquals(kinds), d.SourcePath, "availableProductKinds", "商品未按日开放。");
            Weights(d.CustomerWeights, GuangzhouRules.Customers.Take(d.Day < 7 ? 1 : d.Day < 8 ? 2 : d.Day < 9 ? 3 : d.Day < 10 ? 4 : 5), "customerWeights");
            Weights(d.OrderTypeWeights, GuangzhouRules.Orders.Where(o => (!GuangzhouRules.HasDimSum(o) || d.Day >= 5) && (!GuangzhouRules.HasTea(o) || d.Day >= 8)), "orderTypeWeights");
            Check(d.Guangzhou is not null && d.Guangzhou.EmptyStockWeightMultiplier is > 0 and < 1 && d.Guangzhou.WaitingOrdersThreshold == 2, d.SourcePath, "guangzhou", "缺少库存保护配置。");
            if (d.Day >= 5 && d.Guangzhou is not null) Weights(d.Guangzhou.DimSumWeights, d.Day < 9 ? new[] { GuangzhouRules.SiuMai } : new[] { GuangzhouRules.SiuMai, GuangzhouRules.HarGow }, "dimSumWeights");
            Check(d.StartUnlocks.Concat(d.CompletionUnlocks).All(knownUnlocks.Contains), d.SourcePath, "unlocks", "未知广州解锁ID。");
            Check(d.ArrivalSegments.Count == 3 && Math.Abs(d.ArrivalSegments.Sum(s => s.CustomerRatio) - 1) < .00001
                && d.ArrivalSegments.All(s => s.Start >= 0 && s.End <= 1 && s.End > s.Start && s.CustomerRatio > 0), d.SourcePath, "arrivalSegments", "客流分段无效。");
            Check(d.Constraints.MaxBigOrderCustomers == (d.Day < 10 ? 0 : d.Day < 12 ? 2 : 4) && d.Constraints.PressureDelaySeconds == 2 && d.Constraints.MaxPressureDelaySeconds == 4, d.SourcePath, "constraints", "大单或压力限制无效。");
            Check(d.Day == 12 ? d.StarGoals.Select(g => g.Stars).Order().SequenceEqual(new[] { 1, 2, 3 }) : d.StarGoals.Count == 0, d.SourcePath, "starGoals", "仅最终日配置三档星级。");
        }
        return issues;
    }
}
