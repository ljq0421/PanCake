using ProjectCake.Data;

namespace ProjectCake.Wuhan;

/// <summary>Raw noodles are unlimited; each seasoning holds eight portions, replenished one click at a time.</summary>
public sealed class WuhanIngredientInventory
{
    private static readonly Dictionary<string, int> Supply = new(StringComparer.Ordinal)
    {
        [StableIds.Ingredients.WuhanBaseSeasoning] = 8,
        [StableIds.Ingredients.WuhanScallion] = 8,
        [StableIds.Ingredients.WuhanChiliOil] = 8,
        [StableIds.Ingredients.WuhanBraisedBeef] = 8,
    };
    private readonly WuhanIngredientStationLevelData _data;
    private int _noodles;
    private readonly Dictionary<string, int> _quantities = new(StringComparer.Ordinal);
    public WuhanIngredientInventory(WuhanIngredientStationLevelData data)
    {
        _data = data;
        _noodles = data.NoodlesCapacity;
        foreach ((string id, int capacity) in Supply) _quantities[id] = capacity;
    }
    public int LowStockThreshold => _data.LowStockThreshold;
    public bool IsUnlimited(string id) => id == StableIds.Ingredients.WuhanNoodles;
    public bool IsSupported(string id) => IsUnlimited(id) || Supply.ContainsKey(id);
    public bool CanUse(string id) => IsUnlimited(id) || (_quantities.TryGetValue(id, out int count) && count > 0);
    public int Count(string id) => id == StableIds.Ingredients.WuhanNoodles
        ? _noodles : _quantities.TryGetValue(id, out int count) ? count : throw new ArgumentException("未知武汉食材。", nameof(id));
    public int Capacity(string id) => id == StableIds.Ingredients.WuhanNoodles
        ? _data.NoodlesCapacity : Supply.TryGetValue(id, out int capacity) ? capacity : throw new ArgumentException("未知武汉食材。", nameof(id));
    public bool CanRefill(string id) => Supply.ContainsKey(id) && Count(id) < Capacity(id);
    public int VisualStockState(string id) => Count(id) switch { 8 => 4, >= 6 => 3, >= 4 => 2, > 0 => 1, _ => 0 };
    public bool TryConsume(string id)
    {
        if (IsUnlimited(id)) return true;
        if (!CanUse(id)) return false;
        _quantities[id]--;
        return true;
    }
    public bool TryRefillOne(string id)
    {
        if (!CanRefill(id)) return false;
        _quantities[id]++;
        return true;
    }
}
