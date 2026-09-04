using ProjectCake.Data;

namespace ProjectCake.Orders;

public sealed class OrderGenerator
{
    public const double ArrivalJitterSeconds = 1.5;
    private const int CandidateAttempts = 10;

    public DayPlan Generate(
        DayConfig config,
        IReadOnlyDictionary<string, RecipeData> recipes,
        IReadOnlyDictionary<string, ProductData>? products = null,
        IReadOnlyDictionary<string, CustomerTypeData>? customers = null)
    {
        var random = new DeterministicRandom(config.RandomSeed);
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
