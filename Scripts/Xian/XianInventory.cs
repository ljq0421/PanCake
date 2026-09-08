using ProjectCake.Data;

namespace ProjectCake.Xian;

public sealed class BunInventory
{
    private readonly Queue<BunQuality> _stock = new();
    public BunInventory(int capacity, int initial, bool tutorial = false)
    {
        Capacity = capacity; Tutorial = tutorial; TryStock(initial, BunQuality.Golden);
    }
    public bool Tutorial { get; }
    public int Capacity { get; }
    public int Count => _stock.Count;
    public bool TryStock(int quantity, BunQuality quality)
    {
        if (quantity < 0 || Count + quantity > Capacity || quality == BunQuality.Burnt) return false;
        for (int i = 0; i < quantity; i++) _stock.Enqueue(quality);
        return true;
    }
    public bool TryTake(out BunQuality quality)
    {
        if (Tutorial) { quality = BunQuality.Golden; return true; }
        return _stock.TryDequeue(out quality);
    }
}

public sealed class RefillableStock
{
    public RefillableStock(int capacity, double refillSeconds, int? initial = null)
    { Capacity = capacity; RefillSeconds = refillSeconds; Count = Math.Clamp(initial ?? capacity, 0, capacity); }
    public int Capacity { get; }
    public int Count { get; private set; }
    public double RefillSeconds { get; }
    public double RemainingSeconds { get; private set; }
    public bool IsRefilling => RemainingSeconds > 0;
    public bool TryConsume(int amount)
    {
        if (amount <= 0 || IsRefilling || Count < amount) return false;
        Count -= amount; return true;
    }
    public bool TryRefill()
    {
        if (IsRefilling || Count == Capacity) return false;
        RemainingSeconds = RefillSeconds; return true;
    }
    public void Tick(double delta)
    {
        if (!IsRefilling || delta <= 0) return;
        RemainingSeconds = Math.Max(0, RemainingSeconds - delta);
        if (!IsRefilling) Count = Capacity;
    }
}

public sealed class HulatangRuntime
{
    private readonly double _serveSeconds;
    public HulatangRuntime(XianEquipmentData data, int initial)
    { Stock = new RefillableStock(data.Capacity, data.RefillSeconds, initial); _serveSeconds = data.ActionSeconds; }
    public RefillableStock Stock { get; }
    public double RemainingSeconds { get; private set; }
    public bool HasBowl { get; private set; }
    public bool TryServe()
    {
        if (HasBowl || RemainingSeconds > 0 || !Stock.TryConsume(1)) return false;
        RemainingSeconds = _serveSeconds; return true;
    }
    public bool TryTake() { if (!HasBowl) return false; HasBowl = false; return true; }
    public void Tick(double delta)
    {
        Stock.Tick(delta);
        if (delta <= 0 || RemainingSeconds <= 0) return;
        RemainingSeconds = Math.Max(0, RemainingSeconds - delta);
        if (RemainingSeconds == 0) HasBowl = true;
    }
}
