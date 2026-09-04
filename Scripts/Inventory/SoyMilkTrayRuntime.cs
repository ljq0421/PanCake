namespace ProjectCake.Inventory;

public sealed class SoyMilkTrayRuntime
{
    public const int DefaultCapacity = 6;
    public const double TakeSeconds = 0.3;
    public const double RefillSeconds = 0.6;

    public event Action? Changed;
    public int Capacity { get; }
    public int Quantity { get; private set; }
    public bool IsTaking { get; private set; }
    public bool IsRefilling { get; private set; }
    public double TakingProgress { get; private set; }
    public double RefillProgress { get; private set; }
    public bool CanStartDrag => Quantity > 0 && !IsTaking && !IsRefilling;

    public SoyMilkTrayRuntime(int capacity = DefaultCapacity)
    {
        if (capacity <= 0) throw new ArgumentOutOfRangeException(nameof(capacity));
        Capacity = capacity;
        Quantity = capacity;
    }

    public bool TryConsumeForDelivery()
    {
        if (!CanStartDrag) return false;
        Quantity--;
        IsTaking = true;
        TakingProgress = 0;
        Changed?.Invoke();
        return true;
    }

    public bool TryBeginRefill()
    {
        if (Quantity >= Capacity || IsRefilling || IsTaking) return false;
        IsRefilling = true;
        RefillProgress = 0;
        Changed?.Invoke();
        return true;
    }

    public void Tick(double deltaSeconds)
    {
        if (deltaSeconds <= 0) return;
        bool changed = false;
        if (IsTaking)
        {
            TakingProgress = Math.Min(1, TakingProgress + deltaSeconds / TakeSeconds);
            if (TakingProgress >= 1) IsTaking = false;
            changed = true;
        }
        if (IsRefilling)
        {
            RefillProgress = Math.Min(1, RefillProgress + deltaSeconds / RefillSeconds);
            if (RefillProgress >= 1)
            {
                Quantity = Capacity;
                IsRefilling = false;
            }
            changed = true;
        }
        if (changed) Changed?.Invoke();
    }

    public void Reset()
    {
        Quantity = Capacity;
        IsTaking = false;
        IsRefilling = false;
        TakingProgress = 0;
        RefillProgress = 0;
        Changed?.Invoke();
    }
}
