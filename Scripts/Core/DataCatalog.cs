using Godot;
using ProjectCake.Data;

namespace ProjectCake.Core;

public partial class DataCatalog : Node
{
    public const string RecipeDirectory = "res://Data/Recipes";
    public const string EquipmentDirectory = "res://Data/Equipment";
    public const string IngredientStationDirectory = "res://Data/Equipment/IngredientStations";
    public const string FryerDirectory = "res://Data/Equipment/Fryers";
    public const string ProductDirectory = "res://Data/Products";
    public const string DayDirectory = "res://Data/Days/Tianjin";
    public const string CustomerDirectory = "res://Data/Customers";

    private readonly Dictionary<string, RecipeData> _recipesById = new(StringComparer.Ordinal);
    private readonly Dictionary<int, PancakeStoveLevelData> _stovesByLevel = new();
    private readonly Dictionary<int, IngredientStationLevelData> _ingredientStationsByLevel = new();
    private readonly Dictionary<int, FryerLevelData> _fryersByLevel = new();
    private readonly Dictionary<string, ProductData> _productsById = new(StringComparer.Ordinal);
    private readonly Dictionary<int, DayConfig> _daysByNumber = new();
    private readonly Dictionary<string, CustomerTypeData> _customersById = new(StringComparer.Ordinal);
    private readonly List<ValidationIssue> _validationIssues = new();

    public IReadOnlyDictionary<string, RecipeData> RecipesById => _recipesById;

    public IReadOnlyDictionary<int, PancakeStoveLevelData> StovesByLevel => _stovesByLevel;

    public IReadOnlyDictionary<int, IngredientStationLevelData> IngredientStationsByLevel => _ingredientStationsByLevel;
    public IReadOnlyDictionary<int, FryerLevelData> FryersByLevel => _fryersByLevel;
    public IReadOnlyDictionary<string, ProductData> ProductsById => _productsById;

    public IReadOnlyDictionary<int, DayConfig> DaysByNumber => _daysByNumber;
    public IReadOnlyDictionary<string, CustomerTypeData> CustomersById => _customersById;

    public IReadOnlyList<ValidationIssue> ValidationIssues => _validationIssues;

    public bool IsValid => _validationIssues.Count == 0;

    public override void _Ready()
    {
        Reload();
    }

    public void Reload()
    {
        _recipesById.Clear();
        _stovesByLevel.Clear();
        _ingredientStationsByLevel.Clear();
        _fryersByLevel.Clear();
        _productsById.Clear();
        _daysByNumber.Clear();
        _customersById.Clear();
        _validationIssues.Clear();

        var recipes = LoadResources<RecipeData>(RecipeDirectory, _validationIssues);
        var stoves = LoadResources<PancakeStoveLevelData>(EquipmentDirectory, _validationIssues);
        var ingredientStations = LoadResources<IngredientStationLevelData>(IngredientStationDirectory, _validationIssues);
        var fryers = LoadResources<FryerLevelData>(FryerDirectory, _validationIssues);
        var products = LoadResources<ProductData>(ProductDirectory, _validationIssues);
        var customers = LoadResources<CustomerTypeData>(CustomerDirectory, _validationIssues);
        var dayLoader = new DayConfigLoader();
        IReadOnlyList<DayConfigLoadResult> dayResults = dayLoader.LoadDirectory(DayDirectory);
        var days = new List<DayConfig>();

        foreach (DayConfigLoadResult result in dayResults)
        {
            _validationIssues.AddRange(result.Issues);
            if (result.Config is not null)
            {
                days.Add(result.Config);
            }
        }

        _validationIssues.AddRange(CatalogValidator.ValidateAll(recipes, stoves, ingredientStations, fryers, products, customers, days));

        foreach (RecipeData recipe in recipes)
        {
            _recipesById.TryAdd(recipe.Id, recipe);
        }

        foreach (PancakeStoveLevelData stove in stoves)
        {
            _stovesByLevel.TryAdd(stove.Level, stove);
        }

        foreach (IngredientStationLevelData station in ingredientStations)
        {
            _ingredientStationsByLevel.TryAdd(station.Level, station);
        }

        foreach (FryerLevelData fryer in fryers)
        {
            _fryersByLevel.TryAdd(fryer.Level, fryer);
        }

        foreach (ProductData product in products)
        {
            _productsById.TryAdd(product.Id, product);
        }

        foreach (DayConfig day in days)
        {
            _daysByNumber.TryAdd(day.Day, day);
        }

        foreach (CustomerTypeData customer in customers)
        {
            _customersById.TryAdd(customer.Id, customer);
        }

        if (IsValid)
        {
            GD.Print($"DataCatalog 已加载：{_recipesById.Count} 个配方，{_productsById.Count} 个商品，{_stovesByLevel.Count} 级煎饼炉，{_ingredientStationsByLevel.Count} 级配料台，{_fryersByLevel.Count} 级油条锅，{_customersById.Count} 类顾客，{_daysByNumber.Count} 天配置。");
            return;
        }

        foreach (ValidationIssue issue in _validationIssues)
        {
            GD.PushError(issue.ToString());
        }
    }

    public bool TryGetRecipe(string id, out RecipeData recipe) => _recipesById.TryGetValue(id, out recipe!);

    public bool TryGetStove(int level, out PancakeStoveLevelData stove) => _stovesByLevel.TryGetValue(level, out stove!);

    public bool TryGetIngredientStation(int level, out IngredientStationLevelData station) =>
        _ingredientStationsByLevel.TryGetValue(level, out station!);

    public bool TryGetFryer(int level, out FryerLevelData fryer) => _fryersByLevel.TryGetValue(level, out fryer!);

    public bool TryGetProduct(string id, out ProductData product) => _productsById.TryGetValue(id, out product!);

    public bool TryGetDay(int day, out DayConfig config) => _daysByNumber.TryGetValue(day, out config!);
    public bool TryGetCustomer(string id, out CustomerTypeData customer) => _customersById.TryGetValue(id, out customer!);

    public DayConfig GetDayOrThrow(int day)
    {
        if (!IsValid)
        {
            throw new InvalidOperationException("DataCatalog 存在配置错误，不能开始营业。");
        }

        if (!_daysByNumber.TryGetValue(day, out DayConfig? config))
        {
            throw new KeyNotFoundException($"找不到 Day {day} 配置。");
        }

        return config;
    }

    private static List<T> LoadResources<T>(string directoryPath, List<ValidationIssue> issues)
        where T : Resource
    {
        var resources = new List<T>();

        if (!DirAccess.DirExistsAbsolute(directoryPath))
        {
            issues.Add(new ValidationIssue(directoryPath, "$", "Resource 目录不存在。"));
            return resources;
        }

        string[] files = DirAccess.GetFilesAt(directoryPath)
            .Where(fileName => fileName.EndsWith(".tres", StringComparison.OrdinalIgnoreCase))
            .OrderBy(fileName => fileName, StringComparer.Ordinal)
            .ToArray();

        if (files.Length == 0)
        {
            issues.Add(new ValidationIssue(directoryPath, "$", "Resource 目录中没有 .tres 文件。"));
            return resources;
        }

        foreach (string fileName in files)
        {
            string path = $"{directoryPath.TrimEnd('/')}/{fileName}";
            T? resource = ResourceLoader.Load<T>(path);
            if (resource is null)
            {
                issues.Add(new ValidationIssue(path, "$", $"资源无法作为 {typeof(T).Name} 加载。"));
                continue;
            }

            resources.Add(resource);
        }

        return resources;
    }
}
