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
    public const double ActionSeconds = .6;
    public int BaseCups { get; private set; } = Capacity;
    public bool IsPreparing { get; private set; }
    public bool IsRefilling { get; private set; }
    public bool HasFinishedCup { get; private set; }
    public double RemainingSeconds { get; private set; }
    public bool TryStart() { if (IsPreparing || IsRefilling || HasFinishedCup || BaseCups <= 0) return false; BaseCups--; IsPreparing = true; RemainingSeconds = ActionSeconds; return true; }
    public bool TryRefill() { if (IsPreparing || IsRefilling || BaseCups >= Capacity) return false; IsRefilling = true; RemainingSeconds = ActionSeconds; return true; }
    public void Tick(double delta) { if (!IsPreparing && !IsRefilling) return; RemainingSeconds -= delta; if (RemainingSeconds <= 0) { if (IsPreparing) HasFinishedCup = true; else BaseCups = Capacity; IsPreparing = false; IsRefilling = false; } }
    public bool TryTake() { if (!HasFinishedCup) return false; HasFinishedCup = false; return true; }
    public void Refill() { BaseCups = Capacity; IsRefilling = false; }
}
