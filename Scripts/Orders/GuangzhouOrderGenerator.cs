using ProjectCake.Data;
using ProjectCake.Guangzhou;

namespace ProjectCake.Orders;

public sealed partial class OrderGenerator
{
    private DayPlan GenerateGuangzhou(DayConfig config, IReadOnlyDictionary<string, RecipeData> recipes,
        IReadOnlyDictionary<string, ProductData>? products, IReadOnlyDictionary<string, CustomerTypeData>? customers)
    {
        var random = new DeterministicRandom(config.RandomSeed);
        var arrivals = GenerateArrivals(config, random);
        var people = BuildQuotaBag(config.CustomerWeights, config.CustomerCount, random);
        int families = people.Count(p => p == "gz_family");
        if (families > config.Constraints.MaxBigOrderCustomers) throw new InvalidOperationException("家庭顾客配额超过每日上限。");
        people.RemoveAll(p => p == "gz_family");
        var gaps = Enumerable.Range(0, people.Count + 1).ToList(); Shuffle(gaps, random);
        foreach (int index in gaps.Take(families).OrderDescending()) people.Insert(index, "gz_family");
        var bag = BuildQuotaBag(config.OrderTypeWeights, config.CustomerCount, random);
        var types = new string[people.Count];
        foreach (string person in new[] { "gz_family", "gz_tourist", "gz_regular", "gz_office", "gz_normal" })
            for (int i = 0; i < people.Count; i++)
            {
                if (people[i] != person) continue;
                string[] preferred = person switch
                {
                    "gz_family" => new[] { "gz_f" },
                    "gz_tourist" => new[] { "gz_f", "gz_e", "gz_d" },
                    "gz_regular" => new[] { "gz_f", "gz_b", "gz_c", "gz_d", "gz_e" },
                    "gz_office" => new[] { "gz_a", "gz_c", "gz_d", "gz_b" },
                    _ => Array.Empty<string>(),
                };
                if (person == "gz_family" && !bag.Contains("gz_f")) throw new InvalidOperationException("全套餐配额不足以容纳家庭大单。");
                types[i] = TakePreferred(bag, preferred.FirstOrDefault(bag.Contains) ?? "", random);
            }
        int Portions(int i) => GuangzhouRules.HasRiceRoll(types[i]) ? people[i] == "gz_family" ? 2 : 1 : 0;
        var recipeBag = BuildQuotaBag(config.RecipeWeights, Enumerable.Range(0, people.Count).Sum(Portions), random);
        var assigned = people.Select(_ => new List<string>()).ToArray();
        // Prefer signature recipes without exceeding the day's recipe quota.
        foreach (string person in new[] { "gz_tourist", "gz_regular", "gz_office", "gz_family", "gz_normal" })
            for (int i = 0; i < people.Count; i++)
                if (people[i] == person)
                    while (assigned[i].Count < Portions(i)) assigned[i].Add(TakePreferred(recipeBag, person switch
                    { "gz_tourist" => "gz_shrimp", "gz_regular" => "gz_pork", "gz_office" => "gz_egg", _ => "" }, random));
        var planned = new List<PlannedCustomer>();
        for (int i = 0; i < people.Count; i++)
        {
            var lines = assigned[i].GroupBy(id => id).Select(g => new OrderLineData(ProductKind.RiceRoll, g.Key, g.Count())).ToList();
            if (GuangzhouRules.HasDimSum(types[i]))
            {
                string id = GuangzhouOrderProtection.Choose(config, people[i], i, _ => 0, _ => 0);
                lines.Add(new(GuangzhouRules.DimSumKind(id), id, 1));
            }
            if (GuangzhouRules.HasTea(types[i])) lines.Add(new(ProductKind.MorningTea, GuangzhouRules.Tea, 1));
            var order = new OrderData
            {
                OrderId = $"G{config.Day:D2}-O{i + 1:D3}", CityId = config.CityId, CustomerTypeId = people[i], OrderTypeId = types[i],
                Lines = lines, BasePrice = lines.Sum(l => l.Quantity * (l.ProductKind == ProductKind.RiceRoll ? recipes[l.DefinitionId].Price : products![l.DefinitionId].UnitPrice)),
                CreatedTime = arrivals[i], PatienceSeconds = ResolveLeaveSeconds(people[i], customers) * config.PatienceMultiplier,
            };
            planned.Add(new() { CustomerId = $"G{config.Day:D2}-C{i + 1:D3}", CustomerTypeId = people[i], ArrivalTime = arrivals[i], Order = order });
        }
        return new() { Day = config.Day, RandomSeed = config.RandomSeed, Customers = planned };
    }
}
