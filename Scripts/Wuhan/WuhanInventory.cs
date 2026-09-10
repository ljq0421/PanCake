using ProjectCake.Data;

namespace ProjectCake.Wuhan;

public sealed class WuhanIngredientInventory
{
    private readonly WuhanIngredientStationLevelData _data;
    private int _noodles;
    public WuhanIngredientInventory(WuhanIngredientStationLevelData data)
    {
        _data = data;
        _noodles = data.NoodlesCapacity;
    }
    public int LowStockThreshold => _data.LowStockThreshold;
    public double RefillSeconds => _data.RefillSeconds;
    public bool IsUnlimited(string id) => id is StableIds.Ingredients.WuhanBaseSeasoning
        or StableIds.Ingredients.WuhanScallion or StableIds.Ingredients.WuhanChiliOil
        or StableIds.Ingredients.WuhanBraisedBeef;
    public bool CanUse(string id) => IsUnlimited(id) || (id == StableIds.Ingredients.WuhanNoodles && _noodles > 0);
    public int Count(string id) => id == StableIds.Ingredients.WuhanNoodles
        ? _noodles : throw new ArgumentException("仅生面条计量库存。", nameof(id));
    public int Capacity(string id) => _data.GetCapacity(id);
    public bool TryConsume(string id)
    {
        if (IsUnlimited(id)) return true;
        if (!CanUse(id)) return false;
        _noodles--;
        return true;
    }
    public void Refill(string id)
    {
        if (id == StableIds.Ingredients.WuhanNoodles) _noodles = _data.NoodlesCapacity;
    }
}
