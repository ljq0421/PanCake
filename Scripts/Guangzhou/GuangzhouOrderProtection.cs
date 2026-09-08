using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Guangzhou;

public static class GuangzhouOrderProtection
{
    public static string Choose(DayConfig config, string customer, int ordinal, Func<string, int> stock, Func<string, int> waiting)
    {
        var settings = config.Guangzhou!;
        var weights = settings.DimSumWeights.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p =>
        {
            double weight = p.Value;
            if (customer == "gz_tourist" && p.Key == GuangzhouRules.HarGow || customer == "gz_regular" && p.Key == GuangzhouRules.SiuMai) weight *= 2;
            if (stock(p.Key) == 0 && waiting(p.Key) >= settings.WaitingOrdersThreshold) weight *= settings.EmptyStockWeightMultiplier;
            return (Id: p.Key, Weight: weight);
        }).ToArray();
        if (weights.Length == 0) throw new InvalidOperationException("当前未开放蒸点。");
        var random = new DeterministicRandom(unchecked(config.RandomSeed * 397 ^ (ordinal + 1) * 7919));
        double sample = random.NextDouble() * weights.Sum(w => w.Weight);
        foreach (var w in weights) { sample -= w.Weight; if (sample < 0) return w.Id; }
        return weights[^1].Id;
    }

    public static OrderData Resolve(PlannedCustomer planned, int ordinal, DayConfig config,
        IReadOnlyList<CustomerRuntime> waiting, Func<string, int> stock, IReadOnlyDictionary<string, ProductData> products)
    {
        var order = planned.Order;
        if (!GuangzhouRules.HasDimSum(order.OrderTypeId)) return order;
        int WaitingOrders(string id) => waiting.Count(c => c.State is not (CustomerState.Leaving or CustomerState.Served or CustomerState.Left)
            && c.Order.Lines.Select((l, i) => l.DefinitionId == id && c.Progress.GetRemainingQuantity(i) > 0).Any(x => x));
        string selected = Choose(config, planned.CustomerTypeId, ordinal, stock, WaitingOrders);
        var old = order.Lines.Single(l => l.ProductKind is ProductKind.SiuMai or ProductKind.HarGow);
        var lines = order.Lines.Select(l => l == old ? new OrderLineData(GuangzhouRules.DimSumKind(selected), selected, l.Quantity) : l).ToArray();
        return new OrderData
        {
            OrderId = order.OrderId, CityId = order.CityId, CustomerTypeId = order.CustomerTypeId, OrderTypeId = order.OrderTypeId,
            CreatedTime = order.CreatedTime, PatienceSeconds = order.PatienceSeconds, Status = order.Status, Lines = lines,
            BasePrice = order.BasePrice + old.Quantity * (products[selected].UnitPrice - products[old.DefinitionId].UnitPrice),
        };
    }
}
