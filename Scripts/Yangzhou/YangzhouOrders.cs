namespace ProjectCake.Yangzhou;

public sealed record YangzhouPlannedOrder(int Id, double Arrival, string CustomerId, string TemplateId);

public static class YangzhouOrderGenerator
{
    public static List<YangzhouPlannedOrder> Generate(YangzhouCatalog catalog, YangzhouDay day, int? seed = null)
    {
        var random = new Random(seed ?? day.Seed);
        // Largest remainder fixes the day's group count, then shuffles it. Preferences own template choice.
        var counts = day.CustomerWeights.ToDictionary(w => w.Key, w => (int)Math.Floor(w.Value * day.Customers / 100d));
        foreach (string id in day.CustomerWeights.OrderByDescending(w => w.Value * day.Customers / 100d - counts[w.Key]).ThenBy(w => w.Key).Take(day.Customers - counts.Values.Sum()).Select(w => w.Key)) counts[id]++;
        var types = counts.SelectMany(c => Enumerable.Repeat(c.Key, c.Value)).ToList();
        for (int i = types.Count - 1; i > 0; i--) { int j = random.Next(i + 1); (types[i], types[j]) = (types[j], types[i]); }
        var result = new List<YangzhouPlannedOrder>(); int large = 0, complex = 0; bool bunSeen = false;
        for (int i = 0; i < types.Count; i++)
        {
            var type = catalog.Customer(types[i]);
            var source = type.Preferences.Count == 0 ? day.Weights : type.Preferences;
            var pool = source.Where(w => w.Value > 0 && catalog.Template(w.Key).Items.All(p => catalog.Product(p.Key).UnlockDay <= day.Day)
                && (w.Key != "L" || day.Day >= 8 && type.Id == "group" && large < day.MaxLarge)
                && (day.Day != 3 || !catalog.Template(w.Key).Complex || complex < 2)
                && (day.Day != 5 || result.Count == 0 || !catalog.Template(w.Key).MixedSteam || !catalog.Template(result[^1].TemplateId).MixedSteam)
                && (day.Day != 5 || result.Count < 2 || w.Key != "K" || result[^2].TemplateId != "H" || result[^1].TemplateId != "I")).ToDictionary(w => w.Key, w => w.Value);
            string template = Pick(pool, random);
            if (day.Day == 3 && catalog.Template(template).Items.ContainsKey("B01") && !bunSeen) template = "C";
            if (catalog.Template(template).Items.ContainsKey("B01")) bunSeen = true;
            if (template == "L") large++;
            if (catalog.Template(template).Complex) complex++;
            bool peak = day.Day is 6 or 11 or 12;
            double quantile = (i + .5) / day.Customers;
            double a = peak ? .15 : .2, b = peak ? .8 : .75;
            double ta = peak ? .2 : .25, tb = peak ? .8 : .75;
            double time = quantile < a ? quantile / a * ta : quantile < b ? ta + (quantile - a) / (b - a) * (tb - ta) : tb + (quantile - b) / (1 - b) * (1 - tb);
            result.Add(new(i + 1, Math.Round(time * day.Duration, 3), type.Id, template));
        }
        // The first steamer lesson must actually occur, even with an unlucky all-A seed.
        if (day.Day == 3 && !bunSeen) result[0] = result[0] with { TemplateId = "C" };
        return result;
    }
    private static string Pick(Dictionary<string, int> weights, Random random)
    {
        int total = weights.Values.Sum();
        if (total <= 0) throw new InvalidDataException("扬州订单保护过滤后没有合法模板。");
        int roll = random.Next(total);
        foreach (var item in weights) { roll -= item.Value; if (roll < 0) return item.Key; }
        throw new InvalidOperationException();
    }
}

public sealed class YangzhouOrder
{
    public YangzhouOrder(YangzhouPlannedOrder plan, YangzhouCatalog catalog, bool tutorial)
    {
        Plan = plan; Template = catalog.Template(plan.TemplateId); Type = catalog.Customer(plan.CustomerId);
        Patience = Type.Patience * (tutorial ? 1.2 : 1); Price = catalog.Price(Template);
    }
    public YangzhouPlannedOrder Plan { get; }
    public YangzhouTemplate Template { get; }
    public YangzhouCustomerType Type { get; }
    public double Patience { get; }
    public int Price { get; }
    public double Wait { get; private set; }
    public double WaitRatio => Wait / Patience;
    public string Mood => WaitRatio <= .3 ? "开心" : WaitRatio <= .6 ? "等待" : WaitRatio <= .84 ? "不耐烦" : "生气";
    private readonly List<YangzhouFood> _stagedItems = new();
    public IReadOnlyList<YangzhouFood> StagedItems => _stagedItems;
    public int Mistakes { get; private set; }
    public bool Resolved { get; private set; }
    public bool Served { get; private set; }
    public int Count(string product) => _stagedItems.Count(p => p.ProductId == product);
    public bool Needs(string product) => !Resolved && Template.Items.GetValueOrDefault(product) > Count(product);
    public bool Complete => Template.Items.All(i => Count(i.Key) == i.Value);
    public void Tick(double seconds, bool tutorial)
    {
        if (Resolved) return;
        Wait += seconds;
        if (tutorial) Wait = Math.Min(Wait, Patience * .3);
    }
    public bool Stage(string product, YangzhouKitchen kitchen)
    {
        if (Resolved || !kitchen.HasFood(product)) return false;
        if (!Needs(product)) { Mistakes++; return false; }
        if (!kitchen.TryTake(product, out var item)) return false;
        // Staging is kitchen preparation, not partial delivery; it never restores patience.
        _stagedItems.Add(item); return true;
    }
    public int Satisfaction => Math.Clamp(100 - (WaitRatio <= .3 ? 0 : WaitRatio <= .6 ? 5 : WaitRatio <= .84 ? 15 : 30)
        - Mistakes * 20 - _stagedItems.Sum(i => i.Quality == YangzhouQuality.Perfect ? 0 : i.Quality == YangzhouQuality.Good ? 5 : 10), 0, 100);
    public bool Perfect => Complete && Mistakes == 0 && WaitRatio <= .3 && _stagedItems.All(i => i.Quality == YangzhouQuality.Perfect);
    public int Tip => Perfect ? ProjectCake.Orders.TipCalculator.Calculate(Price, Type.TipRate) : 0;
    public bool Serve() { if (Resolved || !Complete) return false; Resolved = Served = true; return true; }
    public void Lose() { if (Resolved) return; Resolved = true; _stagedItems.Clear(); }
}
