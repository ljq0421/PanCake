using ProjectCake.Data;

namespace ProjectCake.Core;

public partial class DataCatalog
{
    private readonly Dictionary<string, GuangzhouEquipmentData> _guangzhouEquipment = new(StringComparer.Ordinal);
    public IReadOnlyDictionary<string, GuangzhouEquipmentData> GuangzhouEquipment => _guangzhouEquipment;
    public GuangzhouEquipmentData GetGuangzhouEquipment(string id, int level) => _guangzhouEquipment[$"{id}_lv{level}"];

    private void LoadGuangzhou(List<RecipeData> recipes, List<ProductData> products, List<CustomerTypeData> customers, List<DayConfig> days, DayConfigLoader loader)
    {
        _guangzhouEquipment.Clear();
        var r = LoadResources<RecipeData>("res://Data/Recipes/Guangzhou", _validationIssues);
        var p = LoadResources<ProductData>("res://Data/Products/Guangzhou", _validationIssues);
        var c = LoadResources<CustomerTypeData>("res://Data/Customers/Guangzhou", _validationIssues);
        var e = LoadResources<GuangzhouEquipmentData>("res://Data/Equipment/Guangzhou", _validationIssues);
        var d = new List<DayConfig>();
        foreach (var result in loader.LoadDirectory("res://Data/Days/Guangzhou"))
        {
            _validationIssues.AddRange(result.Issues);
            if (result.Config is not null) d.Add(result.Config);
        }
        _validationIssues.AddRange(GuangzhouCatalogValidator.Validate(d, r, p, c, e));
        recipes.AddRange(r); products.AddRange(p); customers.AddRange(c); days.AddRange(d);
        foreach (var equipment in e) _guangzhouEquipment.TryAdd($"{equipment.EquipmentId}_lv{equipment.Level}", equipment);
    }
}
