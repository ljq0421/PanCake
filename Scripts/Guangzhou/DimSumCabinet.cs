using ProjectCake.Data;

namespace ProjectCake.Guangzhou;

public sealed class DimSumBasket
{
    public string ProductId { get; internal set; } = "";
    public double Seconds { get; internal set; }
    public double CookSeconds { get; internal set; }
    public bool Empty => ProductId.Length == 0;
    public bool Cooked => !Empty && Seconds + 1e-8 >= CookSeconds;
    public DimSumQuality Quality { get; internal set; }
}

public sealed class DimSumCabinet
{
    private readonly GuangzhouEquipmentData _equipment;
    public DimSumCabinet(GuangzhouEquipmentData equipment)
    {
        _equipment = equipment;
        Baskets = Enumerable.Range(0, equipment.Capacity).Select(_ => new DimSumBasket()).ToArray();
    }
    public IReadOnlyList<DimSumBasket> Baskets { get; }
    public bool KeepWarm => _equipment.KeepWarm;
    public bool TryLoad(int index, string id)
    {
        if (index < 0 || index >= Baskets.Count || !Baskets[index].Empty || id is not (GuangzhouRules.SiuMai or GuangzhouRules.HarGow)) return false;
        var b = Baskets[index]; b.ProductId = id; b.Seconds = 0; b.Quality = DimSumQuality.Perfect;
        b.CookSeconds = id == GuangzhouRules.HarGow ? _equipment.HarGowCookSeconds : _equipment.CookSeconds;
        return true;
    }
    public void Tick(double delta)
    {
        if (delta <= 0) return;
        foreach (var b in Baskets.Where(b => !b.Empty))
        {
            b.Seconds += delta;
            if (_equipment.KeepWarm) { b.Seconds = Math.Min(b.Seconds, b.CookSeconds); continue; }
            double bestEnd = b.CookSeconds + _equipment.BestWindowSeconds;
            b.Quality = b.Seconds > bestEnd + _equipment.NormalWindowSeconds + 1e-8 ? DimSumQuality.Oversteamed
                : b.Seconds > bestEnd + 1e-8 ? DimSumQuality.Normal : DimSumQuality.Perfect;
        }
    }
    public bool TryStock(int index, DimSumInventory stock)
    {
        if (index < 0 || index >= Baskets.Count) return false;
        var b = Baskets[index];
        if (!b.Cooked || !stock.TryAdd(b.ProductId, b.Quality)) return false;
        b.ProductId = ""; b.Seconds = 0; return true;
    }
}
