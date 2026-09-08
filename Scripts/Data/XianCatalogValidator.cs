using ProjectCake.Xian;

namespace ProjectCake.Data;

public static class XianCatalogValidator
{
    public static IReadOnlyList<ValidationIssue> Validate(IReadOnlyList<DayConfig> days,
        IReadOnlyList<XianRecipeData> recipes, IReadOnlyList<ProductData> products,
        IReadOnlyList<CustomerTypeData> customers, IReadOnlyList<XianEquipmentData> equipment)
    {
        var issues = new List<ValidationIssue>();
        void Check(bool condition, string source, string field, string message)
        { if (!condition) issues.Add(new ValidationIssue(source, field, message)); }
        const string root = "res://Data/Days/Xian";
        Check(days.Select(x => x.Day).Order().SequenceEqual(Enumerable.Range(1, 12)), root, "day", "西安需要连续12天且不能重复。");
        Check(recipes.Count == 4 && recipes.Select(x => x.Id).ToHashSet().SetEquals(XianRules.Recipes), root, "recipes", "西安需要四种明确配方。");
        foreach (var r in recipes)
            Check(r.MeatPortions is 1 or 2 && r.Id == XianRules.RecipeId(r.MeatPortions, r.HasJuice) && r.Price == (r.MeatPortions == 2 ? 14 : 10) + (r.HasJuice ? 1 : 0), r.ResourcePath, "recipe", "肉量、腊汁、价格与配方不匹配。");
        Check(products.Count == 1 && products[0].Kind == ProductKind.Hulatang && products[0].UnitPrice == 6, root, "products", "胡辣汤必须为6元。");
        Check(customers.Count == 4 && customers.Select(c => c.Id).Distinct().Count() == 4, root, "customers", "需要四类不同西安顾客。");
        foreach (var c in customers)
            Check(c.LeaveAtSeconds > c.ImpatientUntilSeconds && c.ImpatientUntilSeconds > c.NormalUntilSeconds && c.NormalUntilSeconds > c.HappyUntilSeconds && c.HappyUntilSeconds > 0, c.ResourcePath, "patience", "耐心阈值必须递增。");
        foreach (string id in new[] { XianRules.Oven, XianRules.Board, XianRules.Soup })
            Check(equipment.Where(e => e.EquipmentId == id).Select(e => e.Level).Order().SequenceEqual(new[] { 1, 2, 3 }), root, "equipment", $"{id}必须包含三级。");
        Check(equipment.Sum(e => e.UpgradePrice) == 1530, root, "price", "升级总价应为1530。");
        foreach (var e in equipment)
        {
            bool valid = e.UpgradePrice >= 0 && e.UnlockAfterDay >= 0 && (e.EquipmentId switch
            {
                XianRules.Oven => e.Capacity > 0 && e.StockCapacity >= e.Capacity && e.ActionSeconds > 0 && (!e.Automatic || e.BurnProof),
                XianRules.Board => e.StockCapacity >= 2 && e.IngredientCapacity >= 2 && e.WorkMultiplier > 0 && !e.Automatic,
                XianRules.Soup => e.Capacity > 0 && e.ActionSeconds > 0 && e.RefillSeconds > 0,
                _ => false,
            });
            Check(valid, e.ResourcePath, "equipment", "设备参数无效。");
        }
        foreach (var d in days)
        {
            void Weights(Dictionary<string, double> weights, IEnumerable<string> allowed, string name)
            { Check(weights.Count > 0 && Math.Abs(weights.Values.Sum() - 1) < .00001 && weights.All(p => double.IsFinite(p.Value) && p.Value > 0 && allowed.Contains(p.Key)), d.SourcePath, name, "权重必须使用已开放ID，正值且合计1。"); }
            Check(d.CityId == StableIds.Cities.Xian && d.DurationSeconds is >= 75 and <= 180 && d.CustomerCount > 0 && d.MaxWaitingCustomers == 4 && d.SatisfactionAverageMode == SatisfactionAverageMode.CompletedCustomers, d.SourcePath, "day", "西安日期、时长、顾客或满意度模式无效。");
            var unlocked = XianRules.Recipes.Take(d.Day >= 7 ? 4 : d.Day >= 5 ? 3 : d.Day >= 2 ? 2 : 1).ToArray();
            Weights(d.RecipeWeights, unlocked, "recipeWeights");
            Check(d.AvailableRecipeIds.ToHashSet().SetEquals(unlocked), d.SourcePath, "availableRecipeIds", "配方必须遵守逐日开放。");
            Weights(d.OrderTypeWeights, new[] { "xian_a", "xian_b", "xian_c", "xian_d", "xian_e" }.Take(d.Day >= 9 ? 5 : d.Day >= 6 ? 3 : 1), "orderTypeWeights");
            Weights(d.CustomerWeights, customers.Select(c => c.Id), "customerWeights");
            Check(d.AvailableProductKinds.ToHashSet().SetEquals(d.Day >= 6 ? new[] { ProductKind.Roujiamo, ProductKind.Hulatang } : new[] { ProductKind.Roujiamo }), d.SourcePath, "availableProductKinds", "胡辣汤Day 6才开放。");
            Check(d.ArrivalSegments.Count == 3 && Math.Abs(d.ArrivalSegments.Sum(x => x.CustomerRatio) - 1) < .00001 && d.ArrivalSegments.All(x => x.Start >= 0 && x.End <= 1 && x.Start < x.End), d.SourcePath, "arrivalSegments", "来客分段无效。");
            Check(d.StartUnlocks.Concat(d.CompletionUnlocks).All(StableIds.UnlockIds.Contains), d.SourcePath, "unlocks", "未知解锁ID。");
            Check(d.Constraints.MaxConsecutiveComplexOrders == 2 && d.Constraints.MaxSimultaneousDoubleOrders == (d.Day < 9 ? 0 : d.Day == 9 ? 1 : 2) && d.Constraints.WaitingPressureThreshold == 4 && d.Constraints.AdditionalPressureThreshold == 5 && d.Constraints.MaxPressureDelaySeconds == 4, d.SourcePath, "constraints", "西安压力保护参数无效。");
            Check(d.Day != 12 || d.StarGoals.Count == 3 && d.StarGoals.SingleOrDefault(g => g.Stars == 3)?.MaximumIncorrectOrders == 2, d.SourcePath, "starGoals", "最终日需要三级目标，三星错误订单最多2。");
        }
        return issues;
    }
}
