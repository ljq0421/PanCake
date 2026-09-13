using ProjectCake.Data;

namespace ProjectCake.Wuhan;

public enum DoupiState { Empty, Batter, SkinCooking, ReadyToFlip, Flipped, SecondCooking, ReadyToCut, Overbrowned, Burnt, Cut, Cutting }
public enum DoupiQuality { Normal, Overbrowned, Burnt }

public sealed class DoupiInventory
{
    public const int Capacity = 8;
    public readonly record struct Piece(DoupiQuality Quality, int Tile);
    private readonly Queue<(Piece Piece, int Slot)> _items = new();
    private readonly bool[] _occupied = new bool[Capacity];
    public Piece PieceAt(int index) => _items.ElementAt(index).Piece;
    // FIFO delivery order and physical tray positions are independent. Surviving pieces never move.
    public int SlotAt(int index) => _items.ElementAt(index).Slot;
    public long HeadGeneration { get; private set; }
    public int Count => _items.Count;
    public bool TryAddBatch(int amount, DoupiQuality quality = DoupiQuality.Normal, int firstTile = 0)
    {
        if (amount <= 0 || Count + amount > Capacity) return false;
        for (int i=0;i<amount;i++)
        {
            int slot = Array.IndexOf(_occupied,false);
            _occupied[slot] = true;
            _items.Enqueue((new Piece(quality,(firstTile+i)%8),slot));
        }
        return true;
    }
    public bool TryPeek(out DoupiQuality quality)
    {
        quality = DoupiQuality.Normal;
        if (_items.Count==0) return false;
        quality = _items.Peek().Piece.Quality; return true;
    }
    public bool TryTake(int amount, out DoupiQuality quality)
    {
        quality = DoupiQuality.Normal;
        if (amount<=0 || Count<amount) return false;
        for (int i=0;i<amount;i++)
        {
            var item = _items.Dequeue(); _occupied[item.Slot]=false; quality=item.Piece.Quality;
        }
        HeadGeneration++; return true;
    }
}

public sealed class DoupiStateMachine
{
    private readonly DoupiGriddleLevelData _data;
    private double _seconds;
    private readonly HashSet<DoupiCutLine> _cuts = new();
    public long Generation { get; private set; }
    public DoupiState State { get; private set; }
    public DoupiQuality Quality { get; private set; }
    public int RequiredCuts => 4;
    public int CompletedCuts => _cuts.Count;
    public IReadOnlySet<DoupiCutLine> CutLines => _cuts;
    public int RemainingPieces { get; private set; }
    public int FirstRemainingPiece => _data.BatchYield - RemainingPieces;
    public bool HasEgg { get; private set; }
    public bool HasFilling { get; private set; }
    public bool SecondSide { get; private set; }
    private double _ingredientSeconds;
    public const double MinimumIngredientSeconds = 1;
    public bool IsHeating => State is not (DoupiState.Empty or DoupiState.Burnt or DoupiState.Cutting or DoupiState.Cut);
    internal double SideSeconds => _seconds;
    internal double IngredientSeconds => _ingredientSeconds;
    internal float SkinCookProgress => !SecondSide && State != DoupiState.Empty
        ? (float)Math.Clamp(_seconds / _data.StageSeconds, 0, 1) : 0;
    public float BrowningProgress => SecondSide ? (float)Math.Clamp(_seconds / _data.SecondStageReadySeconds, 0, 1) : 0;
    internal float HeatStress => State == DoupiState.Burnt ? 1 : !_data.CanBurn || !IsHeating ? 0
        : (float)Math.Clamp((_seconds - (SecondSide ? _data.SecondStageReadySeconds : _data.StageSeconds))
            / Math.Max(.01, (SecondSide ? _data.SecondStageBurnSeconds - _data.SecondStageReadySeconds : _data.BurnSeconds - _data.StageSeconds)), 0, 1);

    public DoupiStateMachine(DoupiGriddleLevelData data) => _data = data;
    public bool TryPourBatter()
    {
        if (State != DoupiState.Empty) return false;
        State = DoupiState.Batter; _seconds = 0; return true;
    }
    public bool TryAddEgg()
    {
        if (State != DoupiState.Batter) return false;
        HasEgg = true; _ingredientSeconds = 0; State = DoupiState.SkinCooking; return true;
    }
    public bool TryFlip()
    {
        if (State != DoupiState.ReadyToFlip) return false;
        SecondSide = true; State = DoupiState.Flipped; _seconds = 0; _ingredientSeconds = 0; return true;
    }
    public bool TryAddFilling()
    {
        if (State != DoupiState.Flipped || HasFilling) return false;
        HasFilling = true; _ingredientSeconds = 0; State = DoupiState.SecondCooking; return true;
    }
    public void Tick(double delta)
    {
        if (!double.IsFinite(delta) || delta <= 0 || !IsHeating) return;
        double speed = Math.Max(.01, _data.SpeedMultiplier);
        // Split at automatic flip so a long frame carries its remaining heat into side two.
        if (!SecondSide && _data.AutoFlip && HasEgg)
        {
            double untilFlip = Math.Max(Math.Max(0, (_data.StageSeconds - _seconds) / speed),
                Math.Max(0, MinimumIngredientSeconds - _ingredientSeconds));
            if (delta + 1e-9 >= untilFlip)
            {
                AdvanceHeat(untilFlip, speed);
                if (State == DoupiState.ReadyToFlip && TryFlip())
                    AdvanceHeat(Math.Max(0, delta - untilFlip), speed);
                return;
            }
        }
        AdvanceHeat(delta, speed);
    }
    private void AdvanceHeat(double delta, double speed)
    {
        _seconds += delta * speed;
        if (SecondSide ? HasFilling : HasEgg) _ingredientSeconds += delta;
        // Burn takes precedence over newly reached ingredient/readiness requirements.
        if (_data.CanBurn && _seconds > (SecondSide ? _data.SecondStageBurnSeconds : _data.BurnSeconds) + 1e-9)
        { State = DoupiState.Burnt; Quality = DoupiQuality.Burnt; return; }
        if (SecondSide && _data.CanBurn && _seconds > _data.SecondStageOverbrownedSeconds + 1e-9)
            Quality = DoupiQuality.Overbrowned;
        bool ready = _ingredientSeconds + 1e-9 >= MinimumIngredientSeconds
            && _seconds + 1e-9 >= (SecondSide ? _data.SecondStageReadySeconds : _data.StageSeconds);
        State = SecondSide
            ? !HasFilling ? DoupiState.Flipped : !ready ? DoupiState.SecondCooking
                : Quality == DoupiQuality.Overbrowned ? DoupiState.Overbrowned : DoupiState.ReadyToCut
            : !HasEgg ? DoupiState.Batter : ready ? DoupiState.ReadyToFlip : DoupiState.SkinCooking;
    }
    public bool TryCut(DoupiCutLine direction)
    {
        if (!Enum.IsDefined(direction) || State is not (DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting) || !_cuts.Add(direction)) return false;
        // One vertical gesture cuts all three columns; counts remain physical knife marks.
        if (direction != DoupiCutLine.Horizontal)
        {
            _cuts.Add(DoupiCutLine.Left);
            _cuts.Add(DoupiCutLine.Center);
            _cuts.Add(DoupiCutLine.Right);
        }
        State = DoupiState.Cutting;
        if (_cuts.Count == RequiredCuts) { State = DoupiState.Cut; RemainingPieces = _data.BatchYield; }
        return true;
    }
    public int TransferAvailable(DoupiInventory inventory)
    {
        if (State != DoupiState.Cut) return 0;
        int amount = Math.Min(RemainingPieces, DoupiInventory.Capacity - inventory.Count);
        if (!inventory.TryAddBatch(amount, Quality, FirstRemainingPiece)) return 0;
        Generation++; // Even a partial transfer invalidates a drag of the old batch.
        RemainingPieces -= amount;
        if (RemainingPieces == 0) Reset();
        return amount;
    }
    public void Discard() => Reset();
    private void Reset() { Generation++; State = DoupiState.Empty; Quality = DoupiQuality.Normal; _seconds = 0; _cuts.Clear(); RemainingPieces = 0; HasEgg = HasFilling = SecondSide = false; _ingredientSeconds = 0; }
}
