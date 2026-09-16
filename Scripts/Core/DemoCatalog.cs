using System.Text.Json;
using System.Text.Json.Serialization;
using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Core;

public sealed class DemoOrder
{
    public string CustomerTypeId { get; init; } = "normal";
    public required OrderLineData[] Lines { get; init; }
}
public sealed class DemoStage
{
    public required string Id { get; init; }
    public string CityId { get; init; } = StableIds.Cities.Tianjin;
    public int Day { get; init; }
    public required string TitleZh { get; init; }
    public required string TitleEn { get; init; }
    public double DurationSeconds { get; init; }
    public double PatienceMultiplier { get; init; }
    public required double[] Arrivals { get; init; }
    public string[] Recipes { get; init; } = Array.Empty<string>();
    public DemoOrder[] Orders { get; init; } = Array.Empty<DemoOrder>();
    public required string[] AvailableRecipes { get; init; }
    public ProductKind[] AvailableProducts { get; init; } = new[] { ProductKind.Pancake };
    public string[] StartUnlocks { get; init; } = Array.Empty<string>();
    public required string[] CompletionUnlocks { get; init; }
    public string Tutorial { get; init; } = "";
    [JsonIgnore] public DemoOrder[] ExplicitOrders => Orders.Length > 0 ? Orders : Recipes.Select(id => new DemoOrder
        { Lines = new[] { new OrderLineData(ProductKind.Pancake, id, 1) } }).ToArray();
    public DayConfig Config(IReadOnlyDictionary<string, RecipeData> recipes, IReadOnlyDictionary<string, ProductData>? products = null) => new()
    {
        SourcePath = ExperienceProfile.ManifestPath, CityId = CityId, Day = Day,
        DurationSeconds = DurationSeconds, CustomerCount = ExplicitOrders.Length,
        ExpectedRevenue = ExplicitOrders.Sum(o => Price(o, recipes, products)), PatienceMultiplier = PatienceMultiplier,
        MaxWaitingCustomers = 5, RandomSeed = (CityId == StableIds.Cities.Tianjin ? 1000 : 2000) + Day,
        SatisfactionAverageMode = SatisfactionAverageMode.CompletedCustomers,
        CustomerWeights = ExplicitOrders.Select(o => o.CustomerTypeId).Distinct().ToDictionary(id => id, _ => 1.0),
        OrderTypeWeights = new() { ["pancake"] = 1 }, AvailableProductKinds = AvailableProducts.ToList(),
        AvailableRecipeIds = AvailableRecipes.ToList(), RecipeWeights = AvailableRecipes.ToDictionary(id => id, _ => 1.0),
        StartUnlocks = AvailableRecipes.Select(id => "recipe:" + id).Concat(StartUnlocks).Distinct().ToList(),
        CompletionUnlocks = CompletionUnlocks.ToList(), Constraints = new() { MaxPancakesPerCustomer = 1 },
    };
    private static int Price(DemoOrder o, IReadOnlyDictionary<string, RecipeData> recipes, IReadOnlyDictionary<string, ProductData>? products)
        => o.Lines.Sum(l => l.Quantity * (recipes.TryGetValue(l.DefinitionId, out var r) ? r.Price : products![l.DefinitionId].UnitPrice));
    public DayPlan Plan(IReadOnlyDictionary<string, RecipeData> recipes, CustomerTypeData customer) => BuildPlan(recipes, null, _ => customer);
    public DayPlan Plan(DataCatalog catalog) => BuildPlan(catalog.RecipesById, catalog.ProductsById, id => catalog.CustomersById[id]);
    private DayPlan BuildPlan(IReadOnlyDictionary<string, RecipeData> recipes, IReadOnlyDictionary<string, ProductData>? products, Func<string, CustomerTypeData> customer) => new()
    {
        Day = Day, RandomSeed = (CityId == StableIds.Cities.Tianjin ? 1000 : 2000) + Day, StageId = Id, RunId = Guid.NewGuid().ToString("N"),
        Customers = ExplicitOrders.Select((o, i) => new PlannedCustomer
        {
            CustomerId = $"{Id}:customer:{i}", CustomerTypeId = o.CustomerTypeId, ArrivalTime = Arrivals[i],
            Order = new OrderData { OrderId = $"{Id}:order:{i}", CustomerTypeId = o.CustomerTypeId,
                CityId = CityId, OrderTypeId = OrderType(o.Lines), CreatedTime = Arrivals[i],
                PatienceSeconds = customer(o.CustomerTypeId).LeaveAtSeconds * PatienceMultiplier,
                BasePrice = Price(o, recipes, products), Lines = o.Lines },
        }).ToArray(),
    };
    private static string OrderType(OrderLineData[] lines)
    {
        var k = lines.Select(l => l.ProductKind).ToHashSet();
        if (k.Contains(ProductKind.HotDryNoodles)) return k.Contains(ProductKind.Doupi) ? "noodles_doupi" : "hot_dry_noodles";
        if (k.Contains(ProductKind.Doupi)) return "doupi";
        if (k.Contains(ProductKind.Pancake)) return k.Contains(ProductKind.SoyMilk) ? "pancake_soy_milk" : k.Contains(ProductKind.Youtiao) ? "pancake_youtiao" : "pancake";
        return k.Contains(ProductKind.Youtiao) ? k.Contains(ProductKind.SoyMilk) ? "full_combo" : "youtiao" : "soy_milk";
    }
}
public sealed class DemoCatalog
{
    public required string ProfileId { get; init; }
    public int ContentRevision { get; init; }
    public required DemoStage[] Stages { get; init; }
    public static readonly JsonSerializerOptions JsonOptions = new()
    { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow, WriteIndented = true };
    public DemoStage? Stage(int day) => Stage(StableIds.Cities.Tianjin, day);
    public DemoStage? Stage(string city, int day) => Stages.FirstOrDefault(s => s.CityId == city && s.Day == day);
    public DemoStage? Stage(string id) => Stages.FirstOrDefault(s => s.Id == id);
    public DemoStage? Next(DemoStage stage) => Stages.SkipWhile(s => s.Id != stage.Id).Skip(1).FirstOrDefault();
    public DemoStage[] CityStages(string city) => Stages.Where(s => s.CityId == city).ToArray();
    public static DemoCatalog Parse(string json, IReadOnlyDictionary<string, RecipeData> recipes,
        IReadOnlyDictionary<string, ProductData>? products = null, IReadOnlyDictionary<string, CustomerTypeData>? customers = null)
    {
        var c = JsonSerializer.Deserialize<DemoCatalog>(json, JsonOptions) ?? throw new InvalidDataException("Demo manifest is empty.");
        if (c.ProfileId != ExperienceProfile.DemoId || c.ContentRevision < 1 || c.Stages is not { Length: > 0 })
            throw new InvalidDataException("Invalid Demo profile or content revision.");
        var ids = new HashSet<string>(StringComparer.Ordinal);
        var days = new Dictionary<string, int>();
        string previousCity = StableIds.Cities.Tianjin;
        foreach (var s in c.Stages)
        {
            if (s is null || string.IsNullOrWhiteSpace(s.Id) || !ids.Add(s.Id)
                || s.CityId is not (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan)
                || previousCity == StableIds.Cities.Wuhan && s.CityId != previousCity
                || s.Day != days.GetValueOrDefault(s.CityId) + 1
                || string.IsNullOrWhiteSpace(s.TitleZh) || string.IsNullOrWhiteSpace(s.TitleEn)
                || !double.IsFinite(s.DurationSeconds) || s.DurationSeconds <= 0
                || !double.IsFinite(s.PatienceMultiplier) || s.PatienceMultiplier <= 0
                || s.Arrivals is null || s.Orders is null || s.Recipes is null
                || s.ExplicitOrders.Length == 0 || s.Arrivals.Length != s.ExplicitOrders.Length
                || s.AvailableRecipes is null || s.AvailableProducts is not { Length: > 0 }
                || s.StartUnlocks is null || s.CompletionUnlocks is null)
                throw new InvalidDataException("Invalid Demo stage.");
            previousCity = s.CityId; days[s.CityId] = s.Day;
            var allowed = s.CityId == StableIds.Cities.Tianjin
                ? new[] { ProductKind.Pancake, ProductKind.Youtiao, ProductKind.SoyMilk }
                : new[] { ProductKind.HotDryNoodles, ProductKind.Doupi };
            if (s.AvailableProducts.Any(p => !allowed.Contains(p)) || s.AvailableRecipes.Distinct().Count() != s.AvailableRecipes.Length
                || s.AvailableRecipes.Any(id => !recipes.ContainsKey(id) || id.Contains("ham") || id.Contains("beef")
                    || (s.CityId == StableIds.Cities.Tianjin ? !id.StartsWith("pancake_") : !id.StartsWith("hot_dry_noodles_")))
                || s.StartUnlocks.Concat(s.CompletionUnlocks).Any(id => !StableIds.UnlockIds.Contains(id) || id.EndsWith("_lv3")
                    || id.Contains("egg_rice_wine") || id.Contains("beef") || id.Contains("ham")))
                throw new InvalidDataException($"Invalid resources or unlocks in {s.Id}.");
            for (int i = 0; i < s.Arrivals.Length; i++)
            {
                var o = s.ExplicitOrders[i];
                if (!double.IsFinite(s.Arrivals[i]) || s.Arrivals[i] < 0 || s.Arrivals[i] >= s.DurationSeconds
                    || i > 0 && s.Arrivals[i] <= s.Arrivals[i - 1] || o is null || o.Lines is not { Length: > 0 }
                    || customers is not null && !customers.ContainsKey(o.CustomerTypeId)
                    || (s.CityId == StableIds.Cities.Wuhan) != o.CustomerTypeId.StartsWith("wuhan_")
                    || o.Lines.Any(l => l is null || l.Quantity <= 0 || !s.AvailableProducts.Contains(l.ProductKind)
                        || (l.ProductKind is ProductKind.Pancake or ProductKind.HotDryNoodles
                            ? !s.AvailableRecipes.Contains(l.DefinitionId)
                            : products is null || !products.TryGetValue(l.DefinitionId, out var product) || product.Kind != l.ProductKind)))
                    throw new InvalidDataException($"Invalid order or arrival in {s.Id}.");
            }
        }
        if (c.Stages[0].CityId != StableIds.Cities.Tianjin) throw new InvalidDataException("Demo must start in Tianjin.");
        return c;
    }
}
public partial class DataCatalog
{
    public DemoCatalog? Demo { get; private set; }
    private void ReloadDemo()
    {
        Demo = null;
        foreach (string dir in new[] { RecipeDirectory, WuhanRecipeDirectory })
            foreach (var r in LoadResources<RecipeData>(dir, _validationIssues)) _recipesById.TryAdd(r.Id, r);
        foreach (var r in LoadResources<PancakeStoveLevelData>(EquipmentDirectory, _validationIssues)) _stovesByLevel.TryAdd(r.Level, r);
        foreach (var r in LoadResources<IngredientStationLevelData>(IngredientStationDirectory, _validationIssues)) _ingredientStationsByLevel.TryAdd(r.Level, r);
        foreach (var r in LoadResources<FryerLevelData>(FryerDirectory, _validationIssues)) _fryersByLevel.TryAdd(r.Level, r);
        foreach (string dir in new[] { ProductDirectory, WuhanProductDirectory })
            foreach (var r in LoadResources<ProductData>(dir, _validationIssues)) _productsById.TryAdd(r.Id, r);
        foreach (string dir in new[] { CustomerDirectory, WuhanCustomerDirectory })
            foreach (var r in LoadResources<CustomerTypeData>(dir, _validationIssues)) _customersById.TryAdd(r.Id, r);
        foreach (var r in LoadResources<NoodleCookerLevelData>(NoodleCookerDirectory, _validationIssues)) _noodleCookersByLevel.TryAdd(r.Level, r);
        foreach (var r in LoadResources<DoupiGriddleLevelData>(DoupiGriddleDirectory, _validationIssues)) _doupiGriddlesByLevel.TryAdd(r.Level, r);
        foreach (var r in LoadResources<WuhanIngredientStationLevelData>(WuhanIngredientStationDirectory, _validationIssues)) _wuhanIngredientStationsByLevel.TryAdd(r.Level, r);
        try
        {
            if (!Godot.FileAccess.FileExists(ExperienceProfile.ManifestPath)) throw new FileNotFoundException("Demo manifest is missing.");
            Demo = DemoCatalog.Parse(Godot.FileAccess.GetFileAsString(ExperienceProfile.ManifestPath), _recipesById, _productsById, _customersById);
            if (!_customersById.ContainsKey("normal") || !_stovesByLevel.ContainsKey(1) || !_stovesByLevel.ContainsKey(2)
                || !_ingredientStationsByLevel.ContainsKey(1) || !_ingredientStationsByLevel.ContainsKey(2)
                || !_fryersByLevel.ContainsKey(1) || !_fryersByLevel.ContainsKey(2)
                || !_noodleCookersByLevel.ContainsKey(1) || !_noodleCookersByLevel.ContainsKey(2)
                || !_doupiGriddlesByLevel.ContainsKey(1) || !_doupiGriddlesByLevel.ContainsKey(2) || !_wuhanIngredientStationsByLevel.ContainsKey(1))
                throw new InvalidDataException("Demo equipment or customers are missing.");
            _daysByCity[StableIds.Cities.Tianjin] = _daysByNumber;
            foreach (var s in Demo.Stages)
            {
                if (!_daysByCity.TryGetValue(s.CityId, out var city)) _daysByCity[s.CityId] = city = new();
                city.Add(s.Day, s.Config(_recipesById, _productsById));
            }
        }
        catch (Exception e)
        {
            Demo = null; _daysByNumber.Clear(); _daysByCity.Clear();
            _validationIssues.Add(new(ExperienceProfile.ManifestPath, "$", e.Message));
        }
        foreach (var issue in _validationIssues) Godot.GD.PushError(issue.ToString());
    }
}
