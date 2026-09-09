using ProjectCake.Data;

namespace ProjectCake.Wuhan;

public enum DoupiState { Empty, Batter, SkinCooking, ReadyToFlip, Flipped, SecondCooking, ReadyToCut, Overbrowned, Burnt, Cut, Cutting }
public enum DoupiCutDirection { Horizontal, Vertical }
public enum DoupiQuality { Normal, Overbrowned, Burnt }

public sealed class DoupiInventory
{
    public const int Capacity = 16;
    private readonly Queue<DoupiQuality> _items = new();
    public int Count => _items.Count;
    public bool TryAddBatch(int amount, DoupiQuality quality = DoupiQuality.Normal) { if (amount <= 0 || Count + amount > Capacity) return false; for (int i = 0; i < amount; i++) _items.Enqueue(quality); return true; }
    public bool TryPeek(out DoupiQuality quality) { if (_items.Count == 0) { quality = DoupiQuality.Normal; return false; } quality = _items.Peek(); return true; }
    public bool TryTake(int amount, out DoupiQuality quality) { quality = DoupiQuality.Normal; if (amount <= 0 || Count < amount) return false; for (int i = 0; i < amount; i++) quality = _items.Dequeue(); return true; }
}

public sealed class DoupiStateMachine
{
    private readonly DoupiGriddleLevelData _data;
    private double _seconds;
    private readonly HashSet<DoupiCutDirection> _cuts = new();
    public DoupiState State { get; private set; }
    public DoupiQuality Quality { get; private set; }
    public int RequiredCuts => 2;
    public int CompletedCuts => _cuts.Count;
    public IReadOnlySet<DoupiCutDirection> CutDirections => _cuts;
    public int RemainingPieces { get; private set; }

    public DoupiStateMachine(DoupiGriddleLevelData data) => _data = data;
    public bool TryPourBatter() { if (State != DoupiState.Empty) return false; State = DoupiState.Batter; return true; }
    public bool TryAddEgg() { if (State != DoupiState.Batter) return false; State = DoupiState.SkinCooking; _seconds = 0; return true; }
    public bool TryFlip()
    {
        if (State != DoupiState.ReadyToFlip) return false;
        State = DoupiState.Flipped; _seconds = 0; return true;
    }
    public bool TryAddFilling() { if (State != DoupiState.Flipped) return false; State = DoupiState.SecondCooking; _seconds = 0; return true; }
    public void Tick(double delta)
    {
        if (delta <= 0) return;
        double speed = Math.Max(.01, _data.SpeedMultiplier);
        if (State == DoupiState.SkinCooking)
        {
            _seconds += delta * speed;
            if (_seconds >= _data.StageSeconds)
            {
                if (_data.AutoFlip) { State = DoupiState.Flipped; _seconds = 0; }
                else State = DoupiState.ReadyToFlip;
            }
        }
        else if (State == DoupiState.ReadyToFlip && _data.CanBurn)
        {
            _seconds += delta * speed;
            if (_seconds > _data.BurnSeconds) { State = DoupiState.Burnt; Quality = DoupiQuality.Burnt; }
        }
        else if (State is DoupiState.SecondCooking or DoupiState.ReadyToCut or DoupiState.Overbrowned)
        {
            _seconds += delta * speed;
            if (State == DoupiState.SecondCooking && _seconds >= _data.SecondStageReadySeconds) State = DoupiState.ReadyToCut;
            if (_data.CanBurn && _seconds > _data.SecondStageOverbrownedSeconds && State != DoupiState.Burnt) { State = DoupiState.Overbrowned; Quality = DoupiQuality.Overbrowned; }
            if (_data.CanBurn && _seconds > _data.SecondStageBurnSeconds) { State = DoupiState.Burnt; Quality = DoupiQuality.Burnt; }
        }
    }
    public bool TryCut(DoupiCutDirection direction)
    {
        if (!Enum.IsDefined(direction) || State is not (DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting) || !_cuts.Add(direction)) return false;
        State = DoupiState.Cutting;
        if (_cuts.Count == RequiredCuts) { State = DoupiState.Cut; RemainingPieces = _data.BatchYield; }
        return true;
    }
    public int TransferAvailable(DoupiInventory inventory)
    {
        if (State != DoupiState.Cut) return 0;
        int amount = Math.Min(RemainingPieces, DoupiInventory.Capacity - inventory.Count);
        if (!inventory.TryAddBatch(amount, Quality)) return 0;
        RemainingPieces -= amount;
        if (RemainingPieces == 0) Reset();
        return amount;
    }
    public void Discard() => Reset();
    private void Reset() { State = DoupiState.Empty; Quality = DoupiQuality.Normal; _seconds = 0; _cuts.Clear(); RemainingPieces = 0; }
}
