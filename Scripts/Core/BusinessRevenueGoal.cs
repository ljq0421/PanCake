using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Core;

public static class BusinessRevenueGoal
{
    public static bool Applies(string city) => city is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan;

    // Integer revenue must reach at least 70%; retain the current run's actual order prices.
    public static int Target(DayConfig config, DayPlan plan) => Applies(config.CityId)
        ? checked((int)((plan.Customers.Sum(customer => (long)customer.Order.BasePrice) * 7 + 9) / 10)) : 0;

    public static int Preview(DataCatalog catalog, string city, int day, CityProgressData progress)
    {
        if (!Applies(city) || !catalog.TryGetDay(city, day, out var original)) return 0;
        var config = BaseEquipmentPurchases.ForOwnedEquipment(original, progress);
        return Target(config, new OrderGenerator().Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById));
    }
}
