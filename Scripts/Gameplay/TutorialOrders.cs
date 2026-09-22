using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Gameplay;

internal sealed record TutorialOrder(string CustomerId, ProductKind Kind, string DefinitionId, IReadOnlyList<string> Toppings);

internal static class TutorialOrders
{
    internal sealed record UnlockLesson(string Title, ProductKind Kind, string DefinitionId, params string[] Actions)
    {
        internal bool IsLearned(IReadOnlySet<string> learned) => Actions.All(learned.Contains);
    }

    internal static UnlockLesson? UnlockFor(DayConfig config)
    {
        var ids = config.StartUnlocks;
        if (config.CityId == StableIds.Cities.Tianjin)
        {
            if (ids.Contains("product:youtiao")) return new("油条 · 炸锅练习", ProductKind.Youtiao, StableIds.Products.Youtiao, "deliver:stored_youtiao");
            if (ids.Contains("recipe:pancake_youtiao")) return new("煎饼夹油条", ProductKind.Pancake, StableIds.Recipes.Youtiao, "lesson:pancake_youtiao");
            if (ids.Contains("product:soy_milk")) return new("豆浆 · 交付练习", ProductKind.SoyMilk, StableIds.Products.SoyMilk, "deliver:soy_milk_cup");
            if (ids.Contains("ingredient:ham")) return new("火腿煎饼", ProductKind.Pancake, StableIds.Recipes.Ham, "take:ham");
            if (ids.Contains("ingredient:crispy")) return new("薄脆与葱花", ProductKind.Pancake, StableIds.Recipes.ScallionCrispy, "take:crispy", "take:scallion");
        }
        if (config.CityId == StableIds.Cities.Wuhan)
        {
            if (ids.Contains("product:doupi")) return new("三鲜豆皮 · 新锅练习", ProductKind.Doupi, StableIds.Products.Doupi, "deliver:doupi");
            if (ids.Contains("recipe:hot_dry_noodles_beef")) return new("牛肉热干面 · 先拌后加", ProductKind.HotDryNoodles, StableIds.Recipes.HotDryNoodlesBeef, "take:" + StableIds.Ingredients.WuhanBraisedBeef);
            if (ids.Contains("recipe:hot_dry_noodles_scallion_chili") && config.Day > 1)
                return new("热干面 · 双加小料", ProductKind.HotDryNoodles, StableIds.Recipes.HotDryNoodlesScallionChili,
                    "take:" + StableIds.Ingredients.WuhanScallion, "take:" + StableIds.Ingredients.WuhanChiliOil);
        }
        return null;
    }

    internal static OrderData ExampleOrder(DayConfig config, OrderData original, DataCatalog catalog)
    {
        var lesson = UnlockFor(config);
        if (lesson is null) return original;
        var line = new OrderLineData(lesson.Kind, lesson.DefinitionId, 1);
        int price = catalog.RecipesById.TryGetValue(lesson.DefinitionId, out var recipe)
            ? recipe.Price : catalog.ProductsById[lesson.DefinitionId].UnitPrice;
        return new OrderData { OrderId = original.OrderId, CustomerTypeId = original.CustomerTypeId,
            CityId = config.CityId, OrderTypeId = lesson.Kind switch {
                ProductKind.Pancake => "pancake", ProductKind.HotDryNoodles => "hot_dry_noodles",
                ProductKind.Youtiao => "youtiao", ProductKind.SoyMilk => "soy_milk", _ => "doupi" },
            Lines = new[] { line }, CreatedTime = 0, PatienceSeconds = original.PatienceSeconds, BasePrice = price };
    }

    internal static List<TutorialOrder> Pending(DayController controller, DataCatalog catalog)
    {
        var result = new List<TutorialOrder>();
        if (controller.CustomerQueue is null) return result;
        foreach (var customer in controller.CustomerQueue.Slots)
            for (int i = 0; i < customer.Order.Lines.Count; i++)
            {
                var line = customer.Order.Lines[i];
                if (customer.Progress.GetRemainingQuantity(i) <= 0 || !controller.CanDeliverTo(customer.Id, line.ProductKind)) continue;
                result.Add(new(customer.Id, line.ProductKind, line.DefinitionId,
                    catalog.RecipesById.TryGetValue(line.DefinitionId, out var recipe) ? recipe.ExtraIngredients.ToArray() : Array.Empty<string>()));
            }
        return result;
    }
}
