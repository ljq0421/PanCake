using ProjectCake.Data;

namespace ProjectCake.Inventory;

public enum IngredientStockStatus
{
    Normal,
    Low,
    Empty,
    Refilling,
}

public sealed class IngredientInventory
{
    private static readonly string[] SupportedIngredients =
    {
        StableIds.Ingredients.Batter,
        StableIds.Ingredients.Egg,
        StableIds.Ingredients.Sauce,
        StableIds.Ingredients.Crispy,
        StableIds.Ingredients.Scallion,
        StableIds.Ingredients.Ham,
    };

    private readonly Dictionary<string, int> _quantities = new(StringComparer.Ordinal);
    private readonly Dictionary<string, double> _refillRemaining = new(StringComparer.Ordinal);

    public IngredientInventory(IngredientStationLevelData levelData)
    {
        LevelData = levelData;
        FillAll();
    }

    public event Action? Changed;

    public IngredientStationLevelData LevelData { get; private set; }

    public bool IsAnyRefilling => _refillRemaining.Count > 0;

    public IReadOnlyDictionary<string, int> Quantities => _quantities;

    public bool CanSwitchLevel => !IsAnyRefilling;

    public int GetQuantity(string ingredientId) =>
        _quantities.TryGetValue(ingredientId, out int quantity) ? quantity : 0;

    public int GetCapacity(string ingredientId) => LevelData.GetCapacity(ingredientId);
    public bool IsUnlimited(string ingredientId) => LevelData.IsUnlimited(ingredientId);
    public bool HasAvailable(string ingredientId, int amount = 1) => amount > 0 && !IsRefilling(ingredientId)
        && (IsUnlimited(ingredientId) || GetQuantity(ingredientId) >= amount);

    public bool IsRefilling(string ingredientId) => _refillRemaining.ContainsKey(ingredientId);

    public IngredientStockStatus GetStatus(string ingredientId)
    {
        if (IsUnlimited(ingredientId)) return IngredientStockStatus.Normal;
        if (IsRefilling(ingredientId))
        {
            return IngredientStockStatus.Refilling;
        }

        int quantity = GetQuantity(ingredientId);
        if (quantity <= 0)
        {
            return IngredientStockStatus.Empty;
        }

        return quantity <= LevelData.LowStockThreshold
            ? IngredientStockStatus.Low
            : IngredientStockStatus.Normal;
    }

    public bool CanRefill(string ingredientId) =>
        SupportedIngredients.Contains(ingredientId, StringComparer.Ordinal)
        && !IsUnlimited(ingredientId)
        && !IsRefilling(ingredientId)
        && GetQuantity(ingredientId) < GetCapacity(ingredientId);

    public double GetRefillProgress(string ingredientId)
    {
        if (!_refillRemaining.TryGetValue(ingredientId, out double remaining))
        {
            return 0;
        }

        return Math.Clamp(1.0 - remaining / LevelData.RefillSeconds, 0, 1);
    }

    public bool TryConsume(string ingredientId, int amount = 1)
    {
        if (!HasAvailable(ingredientId, amount))
        {
            return false;
        }

        if (IsUnlimited(ingredientId)) return true;
        _quantities[ingredientId] -= amount;
        Changed?.Invoke();
        return true;
    }

    public bool TryBeginRefill(string ingredientId)
    {
        if (!CanRefill(ingredientId))
        {
            return false;
        }

        _refillRemaining[ingredientId] = LevelData.RefillSeconds;
        Changed?.Invoke();
        return true;
    }

    public void Tick(double deltaSeconds)
    {
        if (deltaSeconds <= 0 || _refillRemaining.Count == 0)
        {
            return;
        }

        var completed = new List<string>();
        foreach (string ingredientId in _refillRemaining.Keys.ToArray())
        {
            double remaining = _refillRemaining[ingredientId] - deltaSeconds;
            if (remaining <= 0)
            {
                completed.Add(ingredientId);
            }
            else
            {
                _refillRemaining[ingredientId] = remaining;
            }
        }

        foreach (string ingredientId in completed)
        {
            _refillRemaining.Remove(ingredientId);
            _quantities[ingredientId] = GetCapacity(ingredientId);
        }

        Changed?.Invoke();
    }

    public bool TrySwitchLevel(IngredientStationLevelData levelData)
    {
        if (!CanSwitchLevel)
        {
            return false;
        }

        LevelData = levelData;
        FillAll();
        Changed?.Invoke();
        return true;
    }

    public void FillAll()
    {
        _refillRemaining.Clear();
        foreach (string ingredientId in SupportedIngredients)
        {
            _quantities[ingredientId] = GetCapacity(ingredientId);
        }
    }
}
