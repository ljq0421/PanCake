using ProjectCake.Data;
using ProjectCake.Xian;

namespace ProjectCake.Orders;

public sealed partial class OrderGenerator
{
    private DayPlan GenerateXian(DayConfig config, IReadOnlyDictionary<string, RecipeData> recipes,
        IReadOnlyDictionary<string, ProductData>? products, IReadOnlyDictionary<string, CustomerTypeData>? customers)
    {
        var random = new DeterministicRandom(config.RandomSeed);
        var arrivals = GenerateArrivals(config, random);
        var people = BuildQuotaBag(config.CustomerWeights, config.CustomerCount, random);
        var orders = BuildQuotaBag(config.OrderTypeWeights, config.CustomerCount, random);
        if (config.Day == 9)
        {
            orders.RemoveAll(XianRules.IsDouble);
            while (orders.Count > config.CustomerCount - 3) orders.RemoveAt(orders.Count - 1);
            while (orders.Count < config.CustomerCount - 3) orders.Add("xian_a");
            orders.AddRange(new[] { "xian_d", "xian_d", "xian_e" });
        }
        var types = new string[people.Count];
        // Allocate the signature pool before other customers take its combo quota.
        for (int i = 0; i < people.Count; i++)
            if (people[i] == "xian_regular") types[i] = TakePreferred(orders, "xian_c", random);
        for (int i = 0; i < people.Count; i++)
            if (people[i] == "xian_tourist") types[i] = TakePreferred(orders, orders.Contains("xian_e") ? "xian_e" : "xian_d", random);
        for (int i = 0; i < people.Count; i++) types[i] ??= TakePreferred(orders, "", random);
        // Swap whole customer/order pairs, preserving both quotas and signature behavior.
        int consecutive = 0;
        for (int i = 0; i < types.Length; i++)
        {
            if (XianRules.IsDouble(types[i]) && consecutive == 2)
            {
                int swap = Array.FindIndex(types, i + 1, t => !XianRules.IsDouble(t));
                if (swap < 0) swap = Array.FindIndex(types, t => !XianRules.IsDouble(t));
                if (swap >= 0) { (types[i], types[swap]) = (types[swap], types[i]); (people[i], people[swap]) = (people[swap], people[i]); }
            }
            consecutive = XianRules.IsDouble(types[i]) ? consecutive + 1 : 0;
        }
        int portions = types.Sum(t => t == "xian_b" ? 0 : XianRules.IsDouble(t) ? 2 : 1);
        var recipeBag = BuildQuotaBag(config.RecipeWeights, portions, random);
        var assignedRecipes = Enumerable.Range(0, people.Count).Select(_ => new List<string>()).ToArray();
        int regularJuicy = AllocateByLargestRemainder(people.Count(p => p == "xian_regular"), new[] { .7, .3 })[0];
        int ordinal = 0;
        for (int i = 0; i < people.Count; i++)
            if (people[i] == "xian_regular" && types[i] != "xian_b")
                assignedRecipes[i].Add(TakePreferred(recipeBag, XianRules.Recipes[ordinal++ < regularJuicy ? 1 : 0], random));
        var planned = new List<PlannedCustomer>();
        for (int i = 0; i < people.Count; i++)
        {
            int quantity = types[i] == "xian_b" ? 0 : XianRules.IsDouble(types[i]) ? 2 : 1;
            while (assignedRecipes[i].Count < quantity) assignedRecipes[i].Add(TakePreferred(recipeBag, "", random));
            var lines = assignedRecipes[i].GroupBy(id => id).Select(g => new OrderLineData(ProductKind.Roujiamo, g.Key, g.Count())).ToList();
            if (types[i] is "xian_b" or "xian_c" or "xian_e") lines.Add(new OrderLineData(ProductKind.Hulatang, "hulatang", 1));
            double at = Math.Round(arrivals[i], 4, MidpointRounding.AwayFromZero);
            var order = new OrderData
            {
                OrderId = $"X{config.Day:D2}-O{i + 1:D3}", CityId = config.CityId, OrderTypeId = types[i],
                CustomerTypeId = people[i], CreatedTime = at, PatienceSeconds = ResolveLeaveSeconds(people[i], customers) * config.PatienceMultiplier,
                Lines = lines, BasePrice = lines.Sum(l => l.Quantity * (l.ProductKind == ProductKind.Roujiamo ? recipes[l.DefinitionId].Price : GetUnitPrice(products, "hulatang", 6))),
            };
            planned.Add(new PlannedCustomer { CustomerId = $"X{config.Day:D2}-C{i + 1:D3}", CustomerTypeId = people[i], ArrivalTime = at, Order = order });
        }
        return new DayPlan { Day = config.Day, RandomSeed = config.RandomSeed, Customers = planned };
    }
}
