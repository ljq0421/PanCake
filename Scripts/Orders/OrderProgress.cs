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
    public bool HasMeatMismatch { get; private set; }
    public bool HasJuiceMismatch { get; private set; }
    public bool HasBunOverbrowned { get; private set; }
    public bool HasQualityIssue { get; private set; }
    public bool HasRiceRollDry { get; private set; }
    public bool HasRiceRollBroken { get; private set; }
    public bool HasDimSumOversteamed { get; private set; }
    public bool HasNoodlesSoft { get; private set; }
    public bool HasNoodlesOvercooked { get; private set; }
    public bool HasDoupiOverbrowned { get; private set; }
    public bool AllNoodlesMixed { get; private set; } = true;
    public bool IsComplete => Order.Lines.Select((line, index) => _fulfilled[index] >= line.Quantity).All(done => done);

    public int GetDeliveredQuantity(int lineIndex) => lineIndex >= 0 && lineIndex < _fulfilled.Length ? _fulfilled[lineIndex] : 0;
    public int GetRemainingQuantity(int lineIndex) => lineIndex >= 0 && lineIndex < _fulfilled.Length
        ? Math.Max(0, Order.Lines[lineIndex].Quantity - _fulfilled[lineIndex])
        : 0;

    public bool CanAccept(ProductKind kind) => FindAvailableLine(kind) >= 0;

    public bool CanAccept(DeliveredItem item, out string error)
    {
        if (ProjectCake.Guangzhou.GuangzhouRules.IsProduct(item.ProductKind))
        {
            var q = item.GuangzhouQuality;
            bool valid = Order.CityId == StableIds.Cities.Guangzhou && q?.Complete == true && (item.ProductKind switch
            {
                ProductKind.RiceRoll => q.RiceRoll is not null,
                ProductKind.SiuMai => q.DimSum is not null && item.DefinitionId == ProjectCake.Guangzhou.GuangzhouRules.SiuMai,
                ProductKind.HarGow => q.DimSum is not null && item.DefinitionId == ProjectCake.Guangzhou.GuangzhouRules.HarGow,
                ProductKind.MorningTea => item.DefinitionId == ProjectCake.Guangzhou.GuangzhouRules.Tea,
                _ => false,
            });
            if (!valid) { error = "广州商品尚未制作完整或商品类型不匹配。"; return false; }
        }
        if (IsComplete)
        {
            error = "订单已经完成。";
            return false;
        }
        if (item.BunQuality == ProjectCake.Xian.BunQuality.Burnt || item.PancakeQuality == PancakeQuality.Burnt || item.YoutiaoQuality == Fryer.YoutiaoQuality.Burnt)
        {
            error = "焦糊商品不能交付。";
            return false;
        }
        if (item.ProductKind == ProductKind.Roujiamo && (item.MeatPortions is < 1 or > 2 || item.BunQuality is null || item.DefinitionId != ProjectCake.Xian.XianRules.RecipeId(item.MeatPortions, item.HasJuice)))
        { error = "肉夹馍尚未制作完整。"; return false; }
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

        int lineIndex = item.ProductKind is ProductKind.Pancake or ProductKind.HotDryNoodles or ProductKind.Roujiamo or ProductKind.RiceRoll
            ? FindRecipeLine(item.ProductKind, item.DefinitionId)
            : FindAvailableLine(item.ProductKind);
        if (lineIndex < 0) return OrderItemAcceptance.Reject("这位顾客不需要更多这种商品。");

        OrderLineData target = Order.Lines[lineIndex];
        _fulfilled[lineIndex]++;
        _delivered.Add(item);
        if (item.ProductKind == ProductKind.RiceRoll)
        {
            var q = item.GuangzhouQuality!;
            HasRecipeMismatch |= target.DefinitionId != item.DefinitionId;
            HasRiceRollDry |= q.RiceRoll == ProjectCake.Guangzhou.RiceRollQuality.Dry;
            HasRiceRollBroken |= q.Broken;
            HasQualityIssue |= q.RiceRoll != ProjectCake.Guangzhou.RiceRollQuality.Perfect || q.Broken;
        }
        else if (item.ProductKind is ProductKind.SiuMai or ProductKind.HarGow)
        {
            var q = item.GuangzhouQuality!;
            HasDimSumOversteamed |= q.DimSum == ProjectCake.Guangzhou.DimSumQuality.Oversteamed;
            HasQualityIssue |= q.DimSum != ProjectCake.Guangzhou.DimSumQuality.Perfect;
        }
        else if (item.ProductKind == ProductKind.Roujiamo)
        {
            HasMeatMismatch |= item.MeatPortions != ProjectCake.Xian.XianRules.Meat(target.DefinitionId);
            HasJuiceMismatch |= item.HasJuice != ProjectCake.Xian.XianRules.Juice(target.DefinitionId);
            HasRecipeMismatch |= HasMeatMismatch || HasJuiceMismatch;
            HasBunOverbrowned |= item.BunQuality == ProjectCake.Xian.BunQuality.Overbrowned;
            HasQualityIssue |= HasBunOverbrowned;
        }
        else if (item.ProductKind == ProductKind.Pancake)
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
        else if (item.ProductKind == ProductKind.HotDryNoodles)
        {
            if (!string.Equals(target.DefinitionId, item.DefinitionId, StringComparison.Ordinal)) HasRecipeMismatch = true;
            WuhanFoodQuality quality = item.WuhanQuality ?? WuhanFoodQuality.None;
            HasNoodlesSoft |= quality.HasFlag(WuhanFoodQuality.NoodlesSoft);
            HasNoodlesOvercooked |= quality.HasFlag(WuhanFoodQuality.NoodlesOvercooked);
            AllNoodlesMixed &= quality.HasFlag(WuhanFoodQuality.MixedComplete);
            HasQualityIssue |= HasNoodlesSoft || HasNoodlesOvercooked || !AllNoodlesMixed;
        }
        else if (item.ProductKind == ProductKind.Doupi)
        {
            HasDoupiOverbrowned |= (item.WuhanQuality ?? WuhanFoodQuality.None).HasFlag(WuhanFoodQuality.DoupiOverbrowned);
            HasQualityIssue |= HasDoupiOverbrowned;
        }

        return OrderItemAcceptance.Accept(IsComplete, IsComplete ? "订单商品已经齐全。" : "商品已加入订单，顾客仍在等待其余内容。");
    }

    private int FindRecipeLine(ProductKind kind, string actualRecipeId)
    {
        int exact = Enumerable.Range(0, Order.Lines.Count).FirstOrDefault(
            index => Order.Lines[index].ProductKind == kind
                && _fulfilled[index] < Order.Lines[index].Quantity
                && string.Equals(Order.Lines[index].DefinitionId, actualRecipeId, StringComparison.Ordinal),
            -1);
        return exact >= 0 ? exact : FindAvailableLine(kind);
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
