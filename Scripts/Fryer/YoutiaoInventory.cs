namespace ProjectCake.Fryer;

public sealed class YoutiaoInventory
{
    private readonly Queue<YoutiaoQuality> _items = new();

    public YoutiaoInventory(int capacity)
    {
        if (capacity <= 0) throw new ArgumentOutOfRangeException(nameof(capacity));
        Capacity = capacity;
    }

    public event Action? Changed;
    public int Capacity { get; private set; }
    public int Count => _items.Count;
    public int FreeSpace => Capacity - Count;
    public bool IsEmpty => _items.Count == 0;
    public IReadOnlyList<YoutiaoQuality> Items => _items.ToArray();

    public int CountQuality(YoutiaoQuality quality) => _items.Count(item => item == quality);

    public bool CanStore(int quantity) => quantity > 0 && quantity <= FreeSpace;

    public bool TryStore(int quantity, YoutiaoQuality quality)
    {
        if (quality == YoutiaoQuality.Burnt || !CanStore(quantity)) return false;
        for (int index = 0; index < quantity; index++) _items.Enqueue(quality);
        Changed?.Invoke();
        return true;
    }

    public bool TryTake(out YoutiaoQuality quality)
    {
        if (_items.Count == 0)
        {
            quality = default;
            return false;
        }

        quality = _items.Dequeue();
        Changed?.Invoke();
        return true;
    }

    public bool TryPeek(out YoutiaoQuality quality)
    {
        if (_items.TryPeek(out quality)) return true;
        quality = default;
        return false;
    }

    public bool TrySwitchCapacity(int capacity)
    {
        if (capacity <= 0 || _items.Count > capacity) return false;
        Capacity = capacity;
        Changed?.Invoke();
        return true;
    }

    public void Clear()
    {
        if (_items.Count == 0) return;
        _items.Clear();
        Changed?.Invoke();
    }
}
