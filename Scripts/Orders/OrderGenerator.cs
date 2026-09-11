using ProjectCake.Data;
using ProjectCake.Pancake;

namespace ProjectCake.Orders;

public sealed partial class OrderGenerator
{
    public const double ArrivalJitterSeconds = 1.5;
    private const int CandidateAttempts = 10;

    public DayPlan Generate(
        DayConfig config,
        IReadOnlyDictionary<string, RecipeData> recipes,
        IReadOnlyDictionary<string, ProductData>? products = null,
        IReadOnlyDictionary<string, CustomerTypeData>? customers = null)
    {
        if (config.CityId == StableIds.Cities.Guangzhou)
            return GenerateGuangzhou(config, recipes, products, customers);
        if (config.CityId == StableIds.Cities.Xian)
            return GenerateXian(config, recipes, products, customers);
        if (config.CityId == StableIds.Cities.Wuhan)
            return GenerateWuhan(config, recipes, products, customers);

        var random = new DeterministicRandom(config.RandomSeed);
        // Keep sauce preferences independent of arrivals, recipes and tutorial assignment.
        var sauceRandom = new DeterministicRandom(config.RandomSeed ^ 0x53415543);
        IReadOnlyList<double> arrivals = GenerateArrivals(config, random);
        IReadOnlyDictionary<int, TutorialOrder> tutorials = BuildTutorialAssignments(config, random);
        var planned = new List<PlannedCustomer>(config.CustomerCount);
        int consecutiveYoutiao = 0;
        int bigOrderCount = 0;

        for (int index = 0; index < arrivals.Count; index++)
        {
            GeneratedOrder? generated = null;
            if (tutorials.TryGetValue(index, out TutorialOrder tutorial))
            {
                generated = GenerateTutorial(tutorial, recipes, products);
            }
            else
            {
                int upcomingTutorialYoutiao = CountUpcomingTutorialYoutiao(index + 1, tutorials);
                for (int attempt = 0; attempt < CandidateAttempts; attempt++)
                {
                    string customerTypeId = PickWeighted(config.CustomerWeights, random);
                    CustomerOrderProfile profile = ResolveProfile(customerTypeId, customers);
                    if (profile == CustomerOrderProfile.BigOrder && bigOrderCount >= config.Constraints.MaxBigOrderCustomers) continue;

                    GeneratedOrder candidate = GenerateForProfile(profile, customerTypeId, config, recipes, products, random);
                    if (ConflictsWithPendingTutorial(candidate, config.Day, index, tutorials)) continue;
                    if (candidate.IsYoutiaoRelated
                        && consecutiveYoutiao + 1 + upcomingTutorialYoutiao > config.Constraints.MaxConsecutiveYoutiaoOrders) continue;
                    if (candidate.PancakeQuantity > config.Constraints.MaxPancakesPerCustomer) continue;
                    generated = candidate;
                    break;
                }
            }

            generated ??= GenerateFallback(recipes);
            if (generated.PancakeQuantity > 0)
            {
                double roll = sauceRandom.NextDouble();
                SaucePreference sauce = roll < .8 ? SaucePreference.Normal
                    : roll < .9 ? SaucePreference.Light : SaucePreference.Extra;
                generated = generated with
                {
                    Lines = generated.Lines.Select(line => line.ProductKind == ProductKind.Pancake
                        ? line with { Sauce = sauce } : line).ToArray(),
                };
            }
            if (generated.CustomerTypeId == "big_order") bigOrderCount++;
            consecutiveYoutiao = generated.IsYoutiaoRelated ? consecutiveYoutiao + 1 : 0;
            string ordinal = (index + 1).ToString("D3");
            double arrival = arrivals[index];
            double patience = ResolveLeaveSeconds(generated.CustomerTypeId, customers) * config.PatienceMultiplier;
            planned.Add(new PlannedCustomer
            {
                CustomerId = $"D{config.Day:D2}-C{ordinal}",
                CustomerTypeId = generated.CustomerTypeId,
                ArrivalTime = Math.Round(arrival, 4, MidpointRounding.AwayFromZero),
                Order = new OrderData
                {
                    OrderId = $"D{config.Day:D2}-O{ordinal}",
                    CustomerTypeId = generated.CustomerTypeId,
                    CreatedTime = arrival,
                    PatienceSeconds = patience,
                    BasePrice = generated.BasePrice,
                    Lines = generated.Lines,
                },
            });
        }

        return new DayPlan { Day = config.Day, RandomSeed = config.RandomSeed, Customers = planned };
    }

    private DayPlan GenerateWuhan(
        DayConfig config,
        IReadOnlyDictionary<string, RecipeData> recipes,
        IReadOnlyDictionary<string, ProductData>? products,
        IReadOnlyDictionary<string, CustomerTypeData>? customers)
    {
        var random = new DeterministicRandom(config.RandomSeed);
        IReadOnlyList<double> arrivals = GenerateArrivals(config, random);
        List<string> customerBag = BuildQuotaBag(config.CustomerWeights, config.CustomerCount, random);
        RepairAdjacent(customerBag, "wuhan_big_order");
        List<string> orderBag = BuildQuotaBag(config.OrderTypeWeights, config.CustomerCount, random);

        var assignedTypes = new string[config.CustomerCount];
        int bigOrdinal = BigStructureOffset(config.Day);
        foreach (int index in Enumerable.Range(0, customerBag.Count).Where(index => customerBag[index] == "wuhan_big_order"))
        {
            string structure = new[] { "hot_dry_noodles", "noodles_doupi" }[bigOrdinal++ % 2];
            assignedTypes[index] = TakePreferred(orderBag, structure, random);
        }
        int regularOrdinal = 0;
        int regularCount = customerBag.Count(value => value == "wuhan_regular");
        int regularClassicCount = AllocateByLargestRemainder(regularCount, new[] { .70, .30 })[0];
        for (int index = 0; index < customerBag.Count; index++)
        {
            string customerType = customerBag[index];
            if (customerType == "wuhan_big_order") continue;
            string preferred = customerType switch
            {
                "wuhan_tourist" => "noodles_doupi",
                "wuhan_regular" => regularOrdinal++ < regularClassicCount ? "hot_dry_noodles" : "noodles_doupi",
                "wuhan_office_worker" => "hot_dry_noodles",
                _ => string.Empty,
            };
            assignedTypes[index] = TakePreferred(orderBag, preferred, random);
        }
        RepairConsecutiveOrders(assignedTypes, "noodles_doupi", 2);

        int noodlePortions = assignedTypes.Select((type, index) => NoodleQuantity(type, customerBag[index])).Sum();
        List<string> recipeBag = BuildQuotaBag(config.RecipeWeights, noodlePortions, random);
        var planned = new List<PlannedCustomer>(config.CustomerCount);
        bool forcedDay4Doupi = false;
        for (int index = 0; index < config.CustomerCount; index++)
        {
            string customerType = customerBag[index];
            string orderType = assignedTypes[index];
            int noodleQuantity = NoodleQuantity(orderType, customerType);
            var noodleRecipes = new List<string>();
            for (int item = 0; item < noodleQuantity; item++)
            {
                string desired = string.Empty;
                if (customerType == "wuhan_regular") desired = orderType == "hot_dry_noodles" ? StableIds.Recipes.HotDryNoodlesClassic : StableIds.Recipes.HotDryNoodlesScallion;
                noodleRecipes.Add(TakePreferred(recipeBag, desired, random));
            }
            int doupiQuantity = orderType switch
            {
                "doupi" => config.Day == 4 && !forcedDay4Doupi ? 1 : random.NextDouble() < .6 ? 1 : 2,
                "noodles_doupi" => customerType == "wuhan_big_order" ? 2 : 1,
                _ => 0,
            };
            if (orderType == "doupi" && config.Day == 4) forcedDay4Doupi = true;
            IReadOnlyList<OrderLineData> lines = BuildWuhanLines(orderType, noodleRecipes, doupiQuantity);
            int price = lines.Sum(line => line.ProductKind switch
            {
                ProductKind.HotDryNoodles => recipes[line.DefinitionId].Price * line.Quantity,
                ProductKind.Doupi => GetUnitPrice(products, StableIds.Products.Doupi, 5) * line.Quantity,
                _ => 0,
            });
            string ordinal = (index + 1).ToString("D3");
            double arrival = Math.Round(arrivals[index], 4, MidpointRounding.AwayFromZero);
            planned.Add(new PlannedCustomer
            {
                CustomerId = $"W{config.Day:D2}-C{ordinal}", CustomerTypeId = customerType, ArrivalTime = arrival,
                Order = new OrderData
                {
                    OrderId = $"W{config.Day:D2}-O{ordinal}", CityId = config.CityId, OrderTypeId = orderType,
                    CustomerTypeId = customerType, CreatedTime = arrival,
                    PatienceSeconds = ResolveLeaveSeconds(customerType, customers) * config.PatienceMultiplier,
                    BasePrice = price, Lines = lines,
                },
            });
        }
        return new DayPlan { Day = config.Day, RandomSeed = config.RandomSeed, Customers = planned };
    }

    private static List<string> BuildQuotaBag(IReadOnlyDictionary<string, double> weights, int total, DeterministicRandom random)
    {
        string[] ids = weights.Keys.ToArray();
        int[] counts = AllocateByLargestRemainder(total, ids.Select(id => weights[id]).ToArray());
        var bag = new List<string>(total);
        for (int index = 0; index < ids.Length; index++) for (int count = 0; count < counts[index]; count++) bag.Add(ids[index]);
        Shuffle(bag, random);
        return bag;
    }

    private static void Shuffle<T>(IList<T> values, DeterministicRandom random)
    {
        for (int index = values.Count - 1; index > 0; index--)
        {
            int swap = random.NextInt(index + 1);
            (values[index], values[swap]) = (values[swap], values[index]);
        }
    }

    private static string TakePreferred(List<string> bag, string preferred, DeterministicRandom random)
    {
        int index = preferred.Length > 0 ? bag.FindIndex(value => value == preferred) : -1;
        if (index < 0) index = random.NextInt(bag.Count);
        string value = bag[index];
        bag.RemoveAt(index);
        return value;
    }

    private static void RepairAdjacent(List<string> values, string restricted)
    {
        for (int index = 1; index < values.Count; index++)
        {
            if (values[index] != restricted || values[index - 1] != restricted) continue;
            int swap = values.FindIndex(index + 1, value => value != restricted);
            if (swap >= 0) (values[index], values[swap]) = (values[swap], values[index]);
        }
    }

    private static void RepairConsecutiveOrders(string[] values, string restricted, int maximum)
    {
        int run = 0;
        for (int index = 0; index < values.Length; index++)
        {
            run = values[index] == restricted ? run + 1 : 0;
            if (run <= maximum) continue;
            int swap = Array.FindIndex(values, index + 1, value => value != restricted);
            if (swap < 0) swap = Array.FindIndex(values, 0, index, value => value != restricted);
            if (swap >= 0) (values[index], values[swap]) = (values[swap], values[index]);
            run = values[index] == restricted ? run : 0;
        }
    }

    private static int BigStructureOffset(int day) => day switch { <= 9 => 0, 10 => 1, 11 => 3, _ => 5 };
    private static int NoodleQuantity(string orderType, string customerType) =>
        orderType is "hot_dry_noodles" or "noodles_doupi"
            ? customerType == "wuhan_big_order" ? 2 : 1 : 0;

    private static IReadOnlyList<OrderLineData> BuildWuhanLines(string orderType, IReadOnlyList<string> noodleRecipes, int doupiQuantity)
    {
        var lines = new List<OrderLineData>();
        foreach (IGrouping<string, string> group in noodleRecipes.GroupBy(value => value, StringComparer.Ordinal))
            lines.Add(new OrderLineData(ProductKind.HotDryNoodles, group.Key, group.Count()));
        if (orderType is "doupi" or "noodles_doupi") lines.Add(new OrderLineData(ProductKind.Doupi, StableIds.Products.Doupi, doupiQuantity));
        return lines;
    }

    public static int[] AllocateByLargestRemainder(int total, IReadOnlyList<double> ratios)
    {
        var result = new int[ratios.Count];
        var remainders = new List<(int Index, double Fraction)>();
        int assigned = 0;
        for (int index = 0; index < ratios.Count; index++)
        {
            double exact = total * ratios[index];
            result[index] = (int)Math.Floor(exact);
            assigned += result[index];
            remainders.Add((index, exact - result[index]));
        }

        foreach ((int index, _) in remainders.OrderByDescending(item => item.Fraction).ThenBy(item => item.Index).Take(total - assigned)) result[index]++;
        return result;
    }

    private static IReadOnlyList<double> GenerateArrivals(DayConfig config, DeterministicRandom random)
    {
        int[] segmentCounts = AllocateByLargestRemainder(config.CustomerCount, config.ArrivalSegments.Select(segment => segment.CustomerRatio).ToArray());
        var arrivals = new List<double>(config.CustomerCount);
        for (int segmentIndex = 0; segmentIndex < config.ArrivalSegments.Count; segmentIndex++)
        {
            ArrivalSegmentConfig segment = config.ArrivalSegments[segmentIndex];
            double start = segment.Start * config.DurationSeconds;
            double end = segment.End * config.DurationSeconds;
            int count = segmentCounts[segmentIndex];
            if (count == 0) continue;
            double first = Math.Min(start + 1.0, end - 0.05);
            double last = Math.Max(first, end - 0.5);
            for (int index = 0; index < count; index++)
            {
                if (config.CityId == StableIds.Cities.Tianjin)
                {
                    // Leave room at both ends of each segment so adjacent segments cannot bunch up.
                    // Daily duration and customer count determine the pace as the chapter progresses.
                    double interval = (end - start) / count;
                    double variation = Math.Min(ArrivalJitterSeconds, interval * 0.1);
                    arrivals.Add(start + (index + 0.5) * interval + random.Range(-variation, variation));
                    continue;
                }
                double normalized = count == 1 ? 0 : (double)index / (count - 1);
                double baseTime = first + (last - first) * normalized;
                double jitter = random.Range(-ArrivalJitterSeconds, ArrivalJitterSeconds);
                arrivals.Add(Math.Clamp(baseTime + jitter, start + 0.01, end - 0.01));
            }
        }
        arrivals.Sort();
        return arrivals;
    }

    private static IReadOnlyDictionary<int, TutorialOrder> BuildTutorialAssignments(DayConfig config, DeterministicRandom random)
    {
        TutorialOrder[] sequence = config.Day switch
        {
            5 => new[] { TutorialOrder.YoutiaoOne, TutorialOrder.YoutiaoTwo },
            7 => new[] { TutorialOrder.PancakeYoutiao, TutorialOrder.PancakeScallionYoutiao },
            9 => new[] { TutorialOrder.SoyMilk, TutorialOrder.BasicPancakeSoyMilk },
            _ => Array.Empty<TutorialOrder>(),
        };
        if (sequence.Length == 0) return new Dictionary<int, TutorialOrder>();

        int earlyWindow = Math.Max(sequence.Length, (int)Math.Ceiling(config.CustomerCount * 0.5));
        var positions = Enumerable.Range(0, earlyWindow).ToList();
        for (int index = positions.Count - 1; index > 0; index--)
        {
            int swap = random.NextInt(index + 1);
            (positions[index], positions[swap]) = (positions[swap], positions[index]);
        }
        positions = positions.Take(sequence.Length).OrderBy(index => index).ToList();
        return positions.Select((position, index) => (position, Order: sequence[index])).ToDictionary(pair => pair.position, pair => pair.Order);
    }

    private static int CountUpcomingTutorialYoutiao(int startIndex, IReadOnlyDictionary<int, TutorialOrder> tutorials)
    {
        int count = 0;
        while (tutorials.TryGetValue(startIndex + count, out TutorialOrder tutorial)
               && tutorial is TutorialOrder.YoutiaoOne
                   or TutorialOrder.YoutiaoTwo
                   or TutorialOrder.PancakeYoutiao
                   or TutorialOrder.PancakeScallionYoutiao)
        {
            count++;
        }

        return count;
    }

    private static bool ConflictsWithPendingTutorial(
        GeneratedOrder candidate,
        int day,
        int currentIndex,
        IReadOnlyDictionary<int, TutorialOrder> tutorials)
    {
        if (!tutorials.Keys.Any(position => position > currentIndex)) return false;
        return day switch
        {
            5 => candidate.Lines.Any(line => line.ProductKind == ProductKind.Youtiao),
            7 => candidate.Lines.Any(line => line.ProductKind == ProductKind.Pancake
                && line.DefinitionId is StableIds.Recipes.Youtiao or StableIds.Recipes.ScallionYoutiao),
            9 => candidate.Lines.Any(line => line.ProductKind == ProductKind.SoyMilk),
            _ => false,
        };
    }

    private static GeneratedOrder GenerateTutorial(TutorialOrder tutorial, IReadOnlyDictionary<string, RecipeData> recipes, IReadOnlyDictionary<string, ProductData>? products)
    {
        const string normal = "normal";
        return tutorial switch
        {
            TutorialOrder.YoutiaoOne => Build(normal, new[] { YoutiaoLine(1) }, recipes, products),
            TutorialOrder.YoutiaoTwo => Build(normal, new[] { YoutiaoLine(2) }, recipes, products),
            TutorialOrder.PancakeYoutiao => Build(normal, new[] { PancakeLine(StableIds.Recipes.Youtiao) }, recipes, products),
            TutorialOrder.PancakeScallionYoutiao => Build(normal, new[] { PancakeLine(StableIds.Recipes.ScallionYoutiao) }, recipes, products),
            TutorialOrder.SoyMilk => Build(normal, new[] { SoyMilkLine() }, recipes, products),
            _ => Build(normal, new[] { PancakeLine(StableIds.Recipes.Basic), SoyMilkLine() }, recipes, products),
        };
    }

    private static GeneratedOrder GenerateForProfile(
        CustomerOrderProfile profile,
        string customerTypeId,
        DayConfig config,
        IReadOnlyDictionary<string, RecipeData> recipes,
        IReadOnlyDictionary<string, ProductData>? products,
        DeterministicRandom random)
    {
        if (profile == CustomerOrderProfile.RegularSignature)
            return Build(customerTypeId, new[] { PancakeLine(StableIds.Recipes.ScallionCrispy), SoyMilkLine() }, recipes, products);

        if (profile == CustomerOrderProfile.BigOrder)
        {
            if (random.NextDouble() < 0.5)
            {
                string first = PickWeighted(config.RecipeWeights, random);
                string second = PickWeighted(config.RecipeWeights, random);
                IReadOnlyList<OrderLineData> lines = first == second
                    ? new[] { PancakeLine(first, 2) }
                    : new[] { PancakeLine(first), PancakeLine(second) };
                return Build(customerTypeId, lines, recipes, products);
            }
            return Build(customerTypeId, new[] { PancakeLine(PickWeighted(config.RecipeWeights, random)), YoutiaoLine(2), SoyMilkLine() }, recipes, products);
        }

        string orderType = PickWeighted(config.OrderTypeWeights, random);
        string recipe = PickWeighted(config.RecipeWeights, random);
        int youtiaoQuantity = random.NextDouble() < 0.5 ? 1 : 2;
        IReadOnlyList<OrderLineData> standard = orderType switch
        {
            "pancake" => new[] { PancakeLine(recipe) },
            "youtiao" => new[] { YoutiaoLine(youtiaoQuantity) },
            "pancake_youtiao" => new[] { PancakeLine(recipe), YoutiaoLine(youtiaoQuantity) },
            "soy_milk" => new[] { SoyMilkLine() },
            "pancake_soy_milk" => new[] { PancakeLine(recipe), SoyMilkLine() },
            "full_combo" => new[] { PancakeLine(recipe), YoutiaoLine(youtiaoQuantity), SoyMilkLine() },
            _ => new[] { PancakeLine(StableIds.Recipes.Basic) },
        };
        return Build(customerTypeId, standard, recipes, products);
    }

    private static GeneratedOrder GenerateFallback(IReadOnlyDictionary<string, RecipeData> recipes) =>
        Build("normal", new[] { PancakeLine(StableIds.Recipes.Basic) }, recipes, null);

    private static GeneratedOrder Build(
        string customerTypeId,
        IReadOnlyList<OrderLineData> lines,
        IReadOnlyDictionary<string, RecipeData> recipes,
        IReadOnlyDictionary<string, ProductData>? products)
    {
        int basePrice = lines.Sum(line => line.ProductKind switch
        {
            ProductKind.Pancake => recipes[line.DefinitionId].Price * line.Quantity,
            ProductKind.Youtiao => GetUnitPrice(products, StableIds.Products.Youtiao, 2) * line.Quantity,
            ProductKind.SoyMilk => GetUnitPrice(products, StableIds.Products.SoyMilk, 3) * line.Quantity,
            _ => 0,
        });
        bool youtiao = lines.Any(line => line.ProductKind == ProductKind.Youtiao
            || line.ProductKind == ProductKind.Pancake && line.DefinitionId is StableIds.Recipes.Youtiao or StableIds.Recipes.ScallionYoutiao);
        int pancakes = lines.Where(line => line.ProductKind == ProductKind.Pancake).Sum(line => line.Quantity);
        return new GeneratedOrder(customerTypeId, lines, basePrice, youtiao, pancakes);
    }

    private static int GetUnitPrice(IReadOnlyDictionary<string, ProductData>? products, string id, int fallback) =>
        products is not null && products.TryGetValue(id, out ProductData? product) ? product.UnitPrice : fallback;

    private static CustomerOrderProfile ResolveProfile(string customerTypeId, IReadOnlyDictionary<string, CustomerTypeData>? customers) =>
        customers is not null && customers.TryGetValue(customerTypeId, out CustomerTypeData? type) ? type.OrderProfile : CustomerOrderProfile.Standard;

    private static double ResolveLeaveSeconds(string customerTypeId, IReadOnlyDictionary<string, CustomerTypeData>? customers) =>
        customers is not null && customers.TryGetValue(customerTypeId, out CustomerTypeData? type) ? type.LeaveAtSeconds : 50;

    private static OrderLineData PancakeLine(string recipeId, int quantity = 1) => new(ProductKind.Pancake, recipeId, quantity);
    private static OrderLineData YoutiaoLine(int quantity) => new(ProductKind.Youtiao, StableIds.Products.Youtiao, quantity);
    private static OrderLineData SoyMilkLine() => new(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1);

    private static string PickWeighted(IReadOnlyDictionary<string, double> weights, DeterministicRandom random)
    {
        double value = random.NextDouble();
        double cumulative = 0;
        foreach ((string id, double weight) in weights.OrderBy(pair => pair.Key, StringComparer.Ordinal))
        {
            cumulative += weight;
            if (value < cumulative) return id;
        }
        return weights.OrderBy(pair => pair.Key, StringComparer.Ordinal).Last().Key;
    }

    private sealed record GeneratedOrder(string CustomerTypeId, IReadOnlyList<OrderLineData> Lines, int BasePrice, bool IsYoutiaoRelated, int PancakeQuantity);

    private enum TutorialOrder
    {
        YoutiaoOne,
        YoutiaoTwo,
        PancakeYoutiao,
        PancakeScallionYoutiao,
        SoyMilk,
        BasicPancakeSoyMilk,
    }
}
