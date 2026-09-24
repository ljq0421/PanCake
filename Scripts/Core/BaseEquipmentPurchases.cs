using ProjectCake.Data;

namespace ProjectCake.Core;

/// <summary>Purchase eligibility is based on the business day; availability is based on ownership.</summary>
public static class BaseEquipmentPurchases
{
    public const string Fryer = "equipment:fryer_lv1";
    public const string SoyTray = "equipment:soy_milk_tray_lv1";
    public const string DoupiGriddle = "equipment:doupi_griddle_lv1";

    public static (string City, string Equipment, string Product, int Day, int Price, string Name) Describe(string id) => id switch
    {
        Fryer => (StableIds.Cities.Tianjin, "fryer", "product:youtiao", 3, 80, "油条锅"),
        SoyTray => (StableIds.Cities.Tianjin, "soy_milk_tray", "product:soy_milk", 5, 100, "豆浆托盘"),
        DoupiGriddle => (StableIds.Cities.Wuhan, "doupi_griddle", "product:doupi", 4, 280, "豆皮锅"),
        _ => (string.Empty, string.Empty, string.Empty, 0, 0, string.Empty),
    };

    public static DayConfig ForOwnedEquipment(DayConfig original, CityProgressData progress)
    {
        if (original.CityId is not (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan)) return original;
        bool fryer = progress.EquipmentLevels.GetValueOrDefault("fryer") > 0;
        bool soy = progress.EquipmentLevels.GetValueOrDefault("soy_milk_tray") > 0
            || progress.UnlockedContentIds.Contains("product:soy_milk") && !progress.EquipmentLevels.ContainsKey("soy_milk_tray");
        bool doupi = progress.EquipmentLevels.GetValueOrDefault("doupi_griddle") > 0;
        var config = original.ForBusinessDay(original.Day);
        bool Allowed(string id) => !(!fryer && id.Contains("youtiao", StringComparison.OrdinalIgnoreCase))
            && !(!soy && (id.Contains("soy_milk", StringComparison.OrdinalIgnoreCase) || id.Contains("soyMilk", StringComparison.OrdinalIgnoreCase)))
            && !(!doupi && id.Contains("doupi", StringComparison.OrdinalIgnoreCase));
        config.OrderTypeWeights = original.OrderTypeWeights.Where(pair => Allowed(pair.Key)).ToDictionary(pair => pair.Key, pair => pair.Value);
        config.RecipeWeights = original.RecipeWeights.Where(pair => Allowed(pair.Key)).ToDictionary(pair => pair.Key, pair => pair.Value);
        Normalize(config.OrderTypeWeights);
        Normalize(config.RecipeWeights);
        config.AvailableRecipeIds = original.AvailableRecipeIds.Where(Allowed).ToList();
        config.AvailableProductKinds = original.AvailableProductKinds.Where(kind => Allowed(kind.ToString())).ToList();
        bool Learned(string id) => id switch
        {
            "product:youtiao" => progress.LearnedWorkbenchActions.Contains("deliver:stored_youtiao"),
            "product:soy_milk" => progress.LearnedWorkbenchActions.Contains("deliver:soy_milk_cup"),
            "product:doupi" => progress.LearnedWorkbenchActions.Contains("deliver:doupi"),
            _ => false,
        };
        config.StartUnlocks = original.StartUnlocks.Where(id => (Allowed(id) || id is Fryer or DoupiGriddle) && !Learned(id)).ToList();
        foreach (string id in original.CityId == StableIds.Cities.Tianjin
            ? new[] { Fryer, SoyTray } : new[] { DoupiGriddle })
        {
            var item = Describe(id);
            if (progress.EquipmentLevels.GetValueOrDefault(item.Equipment) > 0
                && progress.BaseEquipmentPurchaseDays.GetValueOrDefault(item.Equipment) == config.Day
                && !Learned(item.Product)
                && !config.StartUnlocks.Contains(item.Product, StringComparer.Ordinal))
                config.StartUnlocks.Add(item.Product);
        }
        return config;
    }

    private static void Normalize(Dictionary<string, double> weights)
    {
        double total = weights.Values.Sum();
        if (total <= 0) return;
        foreach (string key in weights.Keys.ToArray()) weights[key] /= total;
    }
}
