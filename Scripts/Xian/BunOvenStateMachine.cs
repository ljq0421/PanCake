using ProjectCake.Data;

namespace ProjectCake.Xian;

public sealed class BunOvenStateMachine
{
    private readonly XianEquipmentData _data;
    public BunOvenStateMachine(XianEquipmentData data) => _data = data;
    public BunOvenState State { get; private set; }
    public BunQuality Quality { get; private set; }
    public int Quantity { get; private set; }
    public double SideSeconds { get; private set; }
    public int BatchesStarted { get; private set; }
    public int BurntBuns { get; private set; }
    public bool TryStart(int quantity)
    {
        if (State != BunOvenState.Empty || quantity < 1 || quantity > _data.Capacity) return false;
        Quantity = quantity; SideSeconds = 0; Quality = BunQuality.Golden; State = BunOvenState.FirstSide; BatchesStarted++; return true;
    }
    public bool TryFlip()
    {
        if (State != BunOvenState.FirstSide || SideSeconds < _data.ActionSeconds) return false;
        State = BunOvenState.SecondSide; SideSeconds = 0; return true;
    }
    public void Tick(double delta, BunInventory stock)
    {
        if (delta <= 0 || State is BunOvenState.Empty or BunOvenState.Burnt) return;
        SideSeconds += delta;
        if (_data.Automatic && State == BunOvenState.FirstSide && SideSeconds >= _data.ActionSeconds)
        { SideSeconds -= _data.ActionSeconds; State = BunOvenState.SecondSide; }
        if (!_data.BurnProof)
        {
            if (SideSeconds > _data.ActionSeconds + 3.5)
            { Quality = BunQuality.Burnt; State = BunOvenState.Burnt; BurntBuns += Quantity; return; }
            if (SideSeconds > _data.ActionSeconds + 2) Quality = BunQuality.Overbrowned;
        }
        if (State == BunOvenState.SecondSide && SideSeconds >= _data.ActionSeconds) State = BunOvenState.Ready;
        if (_data.Automatic && State == BunOvenState.Ready) TryCollect(stock);
    }
    public bool TryCollect(BunInventory stock)
    {
        if (State != BunOvenState.Ready || !stock.TryStock(Quantity, Quality)) return false;
        Reset(); return true;
    }
    public bool TryDiscard()
    {
        if (State != BunOvenState.Burnt) return false;
        Reset(); return true;
    }
    private void Reset() { State = BunOvenState.Empty; Quantity = 0; SideSeconds = 0; Quality = BunQuality.Golden; }
}
