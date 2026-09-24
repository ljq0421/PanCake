using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

internal sealed record DayUnlockPresentation(string Id, string Name, Rect2 Bounds)
{
    internal static IReadOnlyList<DayUnlockPresentation> ForDay(DataCatalog catalog, DayConfig config)
    {
        if (config.Day <= 1 || config.CityId is not (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan))
            return Array.Empty<DayUnlockPresentation>();
        var previous = new HashSet<string>();
        for (int day = 1; day < config.Day; day++)
        {
            if (!catalog.TryGetDay(config.CityId, day, out var earlier)) continue;
            previous.UnionWith(Entities(catalog, earlier));
            // Endless days reuse the final configuration; all its entities are already known.
        }
        var added = Entities(catalog, config);
        added.ExceptWith(previous);
        var result = new List<DayUnlockPresentation>();
        void Add(string id, string name, Rect2 bounds)
        {
            bool purchasedNow = id switch
            {
                "Youtiao" => config.StartUnlocks.Contains("product:youtiao"),
                "SoyMilk" => config.StartUnlocks.Contains("product:soy_milk"),
                "Doupi" => config.StartUnlocks.Contains("product:doupi"),
                _ => false,
            };
            if (added.Contains(id) || purchasedNow) result.Add(new(id, name, bounds));
        }
        if (config.CityId == StableIds.Cities.Tianjin)
        {
            Add(StableIds.Ingredients.Crispy, "薄脆", TianjinWorkbenchLayout.EmbeddedIngredient(StableIds.Ingredients.Crispy));
            Add(StableIds.Ingredients.Scallion, "香葱", TianjinWorkbenchLayout.EmbeddedIngredient(StableIds.Ingredients.Scallion));
            Add("Youtiao", "油条锅与油条供应", TianjinWorkbenchLayout.EmbeddedFryer.Merge(TianjinWorkbenchLayout.EmbeddedYoutiaoTray));
            Add("SoyMilk", "豆浆", TianjinWorkbenchLayout.EmbeddedSoyTray);
            Add(StableIds.Ingredients.Ham, "火腿", TianjinWorkbenchLayout.EmbeddedIngredient(StableIds.Ingredients.Ham));
        }
        else
        {
            var layout = WuhanWorkbenchLayout.ForStage(config.AvailableProductKinds.Contains(ProductKind.Doupi));
            Add(StableIds.Ingredients.WuhanBraisedBeef, "牛肉", layout.Ingredient(3));
            if (added.Contains("Doupi") || config.StartUnlocks.Contains("product:doupi"))
            {
                result.Add(new("doupi_pan", "豆皮锅", layout.Pan));
                result.Add(new("doupi_batter", "豆皮面浆与舀勺", layout.Batter));
                result.Add(new("doupi_egg", "豆皮鸡蛋", layout.DoupiEgg));
                result.Add(new("doupi_filling", "豆皮馅料", layout.Filling));
                result.Add(new("doupi_knife", "豆皮切刀", layout.Knife));
                result.Add(new("doupi_stock", "熟豆皮存放区", layout.Stock));
            }
        }
        return result;
    }

    private static HashSet<string> Entities(DataCatalog catalog, DayConfig config)
    {
        var entities = config.AvailableProductKinds.Select(p => p.ToString()).ToHashSet();
        foreach (string id in config.AvailableRecipeIds)
            if (catalog.RecipesById.TryGetValue(id, out var recipe)) entities.UnionWith(recipe.ExtraIngredients);
        return entities;
    }
}
