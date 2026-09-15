using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.Gameplay;

internal sealed record TutorialOrder(string CustomerId, ProductKind Kind, string DefinitionId, IReadOnlyList<string> Toppings);

internal static class TutorialOrders
{
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
