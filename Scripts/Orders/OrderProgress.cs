using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Pancake;

namespace ProjectCake.Orders;

public sealed record OrderItemAcceptance(bool Accepted, bool OrderComplete, string Message)
{
    public static OrderItemAcceptance Reject(string message) => new(false, false, message);
    public static OrderItemAcceptance Accept(bool complete, string message) => new(true, complete, message);
}

public sealed class OrderProgress
{
    private readonly int[] _fulfilled;
    private readonly List<DeliveredItem> _delivered = new();

    public OrderProgress(OrderData order)
    {
        Order = order;
        _fulfilled = new int[order.Lines.Count];
    }

    public OrderData Order { get; }
    public IReadOnlyList<DeliveredItem> DeliveredItems => _delivered;
    public bool HasRecipeMismatch { get; private set; }
    public bool HasQualityIssue { get; private set; }
    public bool IsComplete => Order.Lines.Select((line, index) => _fulfilled[index] >= line.Quantity).All(done => done);

    public int GetDeliveredQuantity(int lineIndex) => lineIndex >= 0 && lineIndex < _fulfilled.Length ? _fulfilled[lineIndex] : 0;
    public int GetRemainingQuantity(int lineIndex) => lineIndex >= 0 && lineIndex < _fulfilled.Length
        ? Math.Max(0, Order.Lines[lineIndex].Quantity - _fulfilled[lineIndex])
        : 0;

    public bool CanAccept(ProductKind kind) => FindAvailableLine(kind) >= 0;

    public bool CanAccept(DeliveredItem item, out string error)
    {
        if (IsComplete)
        {
            error = "订单已经完成。";
            return false;
        }
        if (item.PancakeQuality == PancakeQuality.Burnt || item.YoutiaoQuality == Fryer.YoutiaoQuality.Burnt)
        {
            error = "焦糊商品不能交付。";
            return false;
        }
        if (!CanAccept(item.ProductKind))
        {
            error = "这位顾客不需要更多这种商品。";
            return false;
        }
        error = string.Empty;
        return true;
    }

    public OrderItemAcceptance TryAccept(DeliveredItem item)
    {
        if (!CanAccept(item, out string error)) return OrderItemAcceptance.Reject(error);

        int lineIndex = item.ProductKind == ProductKind.Pancake
            ? FindPancakeLine(item.DefinitionId)
            : FindAvailableLine(item.ProductKind);
        if (lineIndex < 0) return OrderItemAcceptance.Reject("这位顾客不需要更多这种商品。");

        OrderLineData target = Order.Lines[lineIndex];
        _fulfilled[lineIndex]++;
        _delivered.Add(item);
        if (item.ProductKind == ProductKind.Pancake)
        {
            if (!string.Equals(target.DefinitionId, item.DefinitionId, StringComparison.Ordinal)) HasRecipeMismatch = true;
            if (item.PancakeQuality != Pancake.PancakeQuality.Perfect) HasQualityIssue = true;
            if (target.DefinitionId is StableIds.Recipes.Youtiao or StableIds.Recipes.ScallionYoutiao
                && item.InternalYoutiaoQuality != Fryer.YoutiaoQuality.Golden)
            {
                HasQualityIssue = true;
            }
        }
        else if (item.ProductKind == ProductKind.Youtiao && item.YoutiaoQuality != Fryer.YoutiaoQuality.Golden)
        {
            HasQualityIssue = true;
        }

        return OrderItemAcceptance.Accept(IsComplete, IsComplete ? "订单商品已经齐全。" : "商品已加入订单，顾客仍在等待其余内容。");
    }

    private int FindPancakeLine(string actualRecipeId)
    {
        int exact = Enumerable.Range(0, Order.Lines.Count).FirstOrDefault(
            index => Order.Lines[index].ProductKind == ProductKind.Pancake
                && _fulfilled[index] < Order.Lines[index].Quantity
                && string.Equals(Order.Lines[index].DefinitionId, actualRecipeId, StringComparison.Ordinal),
            -1);
        return exact >= 0 ? exact : FindAvailableLine(ProductKind.Pancake);
    }

    private int FindAvailableLine(ProductKind kind)
    {
        for (int index = 0; index < Order.Lines.Count; index++)
        {
            if (Order.Lines[index].ProductKind == kind && _fulfilled[index] < Order.Lines[index].Quantity) return index;
        }
        return -1;
    }
}
