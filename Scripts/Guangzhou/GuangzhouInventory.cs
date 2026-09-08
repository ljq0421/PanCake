namespace ProjectCake.Guangzhou;

public sealed class GuangzhouStock
{
    public GuangzhouStock(int capacity, double refillSeconds) { Capacity = capacity; Count = capacity; RefillSeconds = refillSeconds; }
    public int Capacity { get; }
    public int Count { get; private set; }
    public double RefillSeconds { get; }
    public double RefillRemaining { get; private set; }
    public bool Refilling => RefillRemaining > 0;
    public bool TryTake()
    {
        if (Refilling || Count <= 0) return false;
        Count--; return true;
    }
    public bool TryRefill()
    {
        if (Refilling || Count == Capacity) return false;
        RefillRemaining = RefillSeconds; return true;
    }
    public void Tick(double delta)
    {
        if (delta <= 0 || !Refilling) return;
        RefillRemaining = Math.Max(0, RefillRemaining - delta);
        if (RefillRemaining < 1e-8) RefillRemaining = 0;
        if (!Refilling) Count = Capacity;
    }
}

public sealed class GuangzhouTea
{
    public GuangzhouStock Stock { get; } = new(6, .5);
    public double PourRemaining { get; private set; }
    public bool HasCup { get; private set; }
    public bool TryPour()
    {
        if (HasCup || PourRemaining > 0 || !Stock.TryTake()) return false;
        PourRemaining = .3; return true;
    }
    public void Tick(double delta)
    {
        if (delta <= 0) return;
        Stock.Tick(delta);
        if (PourRemaining <= 0) return;
        PourRemaining = Math.Max(0, PourRemaining - delta);
        if (PourRemaining < 1e-8) PourRemaining = 0;
        if (PourRemaining == 0) HasCup = true;
    }
    public bool TryTakeCup() { if (!HasCup) return false; HasCup = false; return true; }
}

public sealed class DimSumInventory
{
    public const int Capacity = 4;
    private readonly Dictionary<string, Queue<DimSumQuality>> _stock = new()
    { [GuangzhouRules.SiuMai] = new(), [GuangzhouRules.HarGow] = new() };
    public int Count(string id) => _stock.TryGetValue(id, out var q) ? q.Count : 0;
    public bool TryAdd(string id, DimSumQuality quality)
    {
        if (!_stock.TryGetValue(id, out var q) || q.Count >= Capacity) return false;
        q.Enqueue(quality); return true;
    }
    public bool TryPeek(string id, out DimSumQuality quality)
    {
        quality = default; return _stock.TryGetValue(id, out var q) && q.TryPeek(out quality);
    }
    public bool TryTake(string id) => _stock.TryGetValue(id, out var q) && q.TryDequeue(out _);
}
