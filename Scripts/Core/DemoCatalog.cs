using System.Text.Json;
using System.Text.Json.Serialization;
using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Core;

public sealed class DemoStage
{
    public required string Id { get; init; }
    public int Day { get; init; }
    public required string TitleZh { get; init; }
    public required string TitleEn { get; init; }
    public double DurationSeconds { get; init; }
    public double PatienceMultiplier { get; init; }
    public required double[] Arrivals { get; init; }
    public required string[] Recipes { get; init; }
    public required string[] AvailableRecipes { get; init; }
    public required string[] CompletionUnlocks { get; init; }

    public DayConfig Config(IReadOnlyDictionary<string, RecipeData> recipes) => new()
    {
        SourcePath = ExperienceProfile.ManifestPath, CityId = StableIds.Cities.Tianjin,
        Day = Day, DurationSeconds = DurationSeconds, CustomerCount = Recipes.Length,
        ExpectedRevenue = Recipes.Sum(id => recipes[id].Price), PatienceMultiplier = PatienceMultiplier,
        MaxWaitingCustomers = 5, RandomSeed = 1000 + Day,
        SatisfactionAverageMode = SatisfactionAverageMode.CompletedCustomers,
        CustomerWeights = new() { ["normal"] = 1 }, OrderTypeWeights = new() { ["pancake"] = 1 },
        AvailableProductKinds = new() { ProductKind.Pancake },
        AvailableRecipeIds = AvailableRecipes.ToList(),
        RecipeWeights = AvailableRecipes.ToDictionary(id => id, _ => 1.0),
        StartUnlocks = AvailableRecipes.Select(id => "recipe:" + id).ToList(),
        CompletionUnlocks = CompletionUnlocks.ToList(),
        Constraints = new() { MaxPancakesPerCustomer = 1 },
    };

    public DayPlan Plan(IReadOnlyDictionary<string, RecipeData> recipes, CustomerTypeData customer) => new()
    {
        Day = Day, RandomSeed = 1000 + Day, StageId = Id, RunId = Guid.NewGuid().ToString("N"),
        Customers = Recipes.Select((recipe, i) => new PlannedCustomer
        {
            CustomerId = $"{Id}:customer:{i}", CustomerTypeId = customer.Id, ArrivalTime = Arrivals[i],
            Order = new OrderData
            {
                OrderId = $"{Id}:order:{i}", CustomerTypeId = customer.Id,
                CityId = StableIds.Cities.Tianjin, OrderTypeId = "pancake",
                CreatedTime = Arrivals[i], PatienceSeconds = customer.LeaveAtSeconds * PatienceMultiplier,
                BasePrice = recipes[recipe].Price,
                Lines = new[] { new OrderLineData(ProductKind.Pancake, recipe, 1) },
            },
        }).ToArray(),
    };
}

public sealed class DemoCatalog
{
    public required string ProfileId { get; init; }
    public int ContentRevision { get; init; }
    public required DemoStage[] Stages { get; init; }
    public static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        WriteIndented = true,
    };

    public DemoStage? Stage(int day) => Stages.FirstOrDefault(stage => stage.Day == day);
    public DemoStage? Stage(string id) => Stages.FirstOrDefault(stage => stage.Id == id);

    public static DemoCatalog Parse(string json, IReadOnlyDictionary<string, RecipeData> recipes)
    {
        var catalog = JsonSerializer.Deserialize<DemoCatalog>(json, JsonOptions)
            ?? throw new InvalidDataException("Demo manifest is empty.");
        if (catalog.ProfileId != ExperienceProfile.DemoId || catalog.ContentRevision < 1
            || catalog.Stages is not { Length: > 0 })
            throw new InvalidDataException("Invalid Demo profile or content revision.");
        var ids = new HashSet<string>(StringComparer.Ordinal);
        for (int i = 0; i < catalog.Stages.Length; i++)
        {
            var stage = catalog.Stages[i];
            if (stage is null || string.IsNullOrWhiteSpace(stage.Id) || !ids.Add(stage.Id)
                || stage.Day != i + 1 || string.IsNullOrWhiteSpace(stage.TitleZh) || string.IsNullOrWhiteSpace(stage.TitleEn)
                || !double.IsFinite(stage.DurationSeconds) || stage.DurationSeconds <= 0
                || !double.IsFinite(stage.PatienceMultiplier) || stage.PatienceMultiplier <= 0
                || stage.Recipes is not { Length: > 0 } || stage.Arrivals?.Length != stage.Recipes.Length
                || stage.AvailableRecipes is not { Length: > 0 } || stage.CompletionUnlocks is null)
                throw new InvalidDataException($"Invalid Demo stage at position {i + 1}.");
            if (stage.AvailableRecipes.Distinct().Count() != stage.AvailableRecipes.Length
                || stage.AvailableRecipes.Any(id => !recipes.ContainsKey(id) || !id.StartsWith("pancake_", StringComparison.Ordinal))
                || stage.Recipes.Any(id => !stage.AvailableRecipes.Contains(id))
                || stage.CompletionUnlocks.Any(id => id is not ("equipment:ingredient_station_lv2" or "equipment:pancake_stove_lv2")))
                throw new InvalidDataException($"Invalid recipes or unlocks in {stage.Id}.");
            for (int n = 0; n < stage.Arrivals.Length; n++)
                if (!double.IsFinite(stage.Arrivals[n]) || stage.Arrivals[n] < 0 || stage.Arrivals[n] >= stage.DurationSeconds
                    || n > 0 && stage.Arrivals[n] <= stage.Arrivals[n - 1])
                    throw new InvalidDataException($"Invalid arrival time in {stage.Id}.");
        }
        return catalog;
    }
}

public partial class DataCatalog
{
    public DemoCatalog? Demo { get; private set; }

    private void ReloadDemo()
    {
        Demo = null;
        foreach (var recipe in LoadResources<RecipeData>(RecipeDirectory, _validationIssues)) _recipesById.TryAdd(recipe.Id, recipe);
        foreach (var stove in LoadResources<PancakeStoveLevelData>(EquipmentDirectory, _validationIssues)) _stovesByLevel.TryAdd(stove.Level, stove);
        foreach (var station in LoadResources<IngredientStationLevelData>(IngredientStationDirectory, _validationIssues)) _ingredientStationsByLevel.TryAdd(station.Level, station);
        foreach (var fryer in LoadResources<FryerLevelData>(FryerDirectory, _validationIssues)) _fryersByLevel.TryAdd(fryer.Level, fryer);
        foreach (var product in LoadResources<ProductData>(ProductDirectory, _validationIssues)) _productsById.TryAdd(product.Id, product);
        foreach (var customer in LoadResources<CustomerTypeData>(CustomerDirectory, _validationIssues)) _customersById.TryAdd(customer.Id, customer);
        try
        {
            if (!Godot.FileAccess.FileExists(ExperienceProfile.ManifestPath)) throw new FileNotFoundException("Demo manifest is missing.");
            Demo = DemoCatalog.Parse(Godot.FileAccess.GetFileAsString(ExperienceProfile.ManifestPath), _recipesById);
            if (!_customersById.ContainsKey("normal") || !_stovesByLevel.ContainsKey(1) || !_stovesByLevel.ContainsKey(2)
                || !_ingredientStationsByLevel.ContainsKey(1) || !_ingredientStationsByLevel.ContainsKey(2))
                throw new InvalidDataException("Demo equipment or customers are missing.");
            _daysByCity[StableIds.Cities.Tianjin] = _daysByNumber;
            foreach (var stage in Demo.Stages) _daysByNumber.Add(stage.Day, stage.Config(_recipesById));
        }
        catch (Exception e)
        {
            Demo = null; _daysByNumber.Clear(); _daysByCity.Clear();
            _validationIssues.Add(new(ExperienceProfile.ManifestPath, "$", e.Message));
        }
        foreach (var issue in _validationIssues) Godot.GD.PushError(issue.ToString());
    }
}
