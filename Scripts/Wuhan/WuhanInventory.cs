using ProjectCake.Data;

namespace ProjectCake.Wuhan;

public sealed class WuhanIngredientInventory
{
    private readonly WuhanIngredientStationLevelData _data;
    private readonly Dictionary<string, int> _counts = new(StringComparer.Ordinal);
    public WuhanIngredientInventory(WuhanIngredientStationLevelData data)
    {
        _data = data;
        foreach (string id in new[] { StableIds.Ingredients.WuhanNoodles, StableIds.Ingredients.WuhanBaseSeasoning, StableIds.Ingredients.WuhanScallion, StableIds.Ingredients.WuhanChiliOil, StableIds.Ingredients.WuhanBraisedBeef }) _counts[id] = data.GetCapacity(id);
    }
    public int Count(string id) => _counts.GetValueOrDefault(id);
    public int Capacity(string id) => _data.GetCapacity(id);
    public bool TryConsume(string id) { if (Count(id) <= 0) return false; _counts[id]--; return true; }
    public void Refill(string id) => _counts[id] = _data.GetCapacity(id);
}

public sealed class EggRiceWineRuntime
{
    public const int Capacity = 6;
    public const double RefillSeconds = .6;
    public int Count { get; private set; } = Capacity;
    public bool IsRefilling { get; private set; }
    public bool CanTake => Count > 0 && !IsRefilling;
    public double RemainingSeconds { get; private set; }

    public bool TryTake()
    {
        if (!CanTake) return false;
        Count--;
        return true;
    }
    public bool TryRefill()
    {
        if (IsRefilling || Count >= Capacity) return false;
        IsRefilling = true;
        RemainingSeconds = RefillSeconds;
        return true;
    }
    public void Tick(double delta)
    {
        if (!IsRefilling || delta <= 0) return;
        RemainingSeconds = Math.Max(0, RemainingSeconds - delta);
        if (RemainingSeconds == 0) Refill();
    }
    public void Refill()
    {
        Count = Capacity;
        IsRefilling = false;
        RemainingSeconds = 0;
    }
}
