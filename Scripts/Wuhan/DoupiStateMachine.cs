using ProjectCake.Data;
using Godot;

namespace ProjectCake.Wuhan;

public enum DoupiState { Empty, Batter, SkinCooking, ReadyToFlip, Flipped, SecondCooking, ReadyToCut, Overbrowned, Burnt, Cut, Cutting, Spreading }
public enum DoupiQuality { Normal, Overbrowned, Burnt }

public sealed class DoupiInventory
{
    public const int Capacity = 16;
    public readonly record struct Piece(DoupiQuality Quality, int Tile);
    private readonly Queue<Piece> _items = new();
    public Piece PieceAt(int index) => _items.ElementAt(index);
    public long HeadGeneration { get; private set; }
    public int Count => _items.Count;
    public bool TryAddBatch(int amount, DoupiQuality quality = DoupiQuality.Normal, int firstTile = 0) { if (amount <= 0 || Count + amount > Capacity) return false; for (int i = 0; i < amount; i++) _items.Enqueue(new Piece(quality, (firstTile + i) % 8)); return true; }
    public bool TryPeek(out DoupiQuality quality) { if (_items.Count == 0) { quality = DoupiQuality.Normal; return false; } quality = _items.Peek().Quality; return true; }
    public bool TryTake(int amount, out DoupiQuality quality) { quality = DoupiQuality.Normal; if (amount <= 0 || Count < amount) return false; for (int i = 0; i < amount; i++) quality = _items.Dequeue().Quality; HeadGeneration++; return true; }
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
    // Presentation reads the same cooking clock; these values never advance production.
    internal float SkinCookProgress => State == DoupiState.SkinCooking
        ? (float)Math.Clamp(_seconds / _data.StageSeconds, 0, 1)
        : State == DoupiState.ReadyToFlip ? 1 : 0;
    internal float HeatStress => !_data.CanBurn ? 0 : State switch
    {
        DoupiState.ReadyToFlip => (float)Math.Clamp((_seconds - _data.StageSeconds) / Math.Max(.01, _data.BurnSeconds - _data.StageSeconds), 0, 1),
        DoupiState.ReadyToCut or DoupiState.Overbrowned => (float)Math.Clamp((_seconds - _data.SecondStageReadySeconds) / Math.Max(.01, _data.SecondStageBurnSeconds - _data.SecondStageReadySeconds), 0, 1),
        DoupiState.Burnt => 1,
        _ => 0,
    };
    public float BrowningProgress => State == DoupiState.SecondCooking
        ? (float)Math.Clamp(_seconds / _data.SecondStageReadySeconds, 0, 1)
        : State is DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting or DoupiState.Cut ? 1 : 0;

    private readonly bool[] _coverage = new bool[DoupiInteraction.CoverageWidth * DoupiInteraction.CoverageHeight];
    public float Coverage => (float)_coverage.Count(x => x) / _coverage.Length;
    public bool IsCovered(int x, int y) => _coverage[y * DoupiInteraction.CoverageWidth + x];
    public int CoverageRevision { get; private set; }
    public bool Spread(Vector2 from, Vector2 to, float surfaceAspect)
    {
        if (State != DoupiState.Spreading || !from.IsFinite() || !to.IsFinite() || !float.IsFinite(surfaceAspect) || surfaceAspect <= 0) return false;
        // Clip before measuring distance: a brush entirely outside the food must not paint its edge.
        Vector2 delta = to - from;
        float enter = 0, leave = 1;
        for (int axis = 0; axis < 2; axis++)
        {
            float a = from[axis], d = delta[axis];
            if (Math.Abs(d) < .00001f) { if (a < 0 || a > 1) return false; continue; }
            float t0 = -a / d, t1 = (1 - a) / d;
            enter = Math.Max(enter, Math.Min(t0, t1)); leave = Math.Min(leave, Math.Max(t0, t1));
        }
        if (leave < enter) return false;
        Vector2 scale = new(Math.Max(1, surfaceAspect), Math.Max(1, 1 / surfaceAspect));
        Vector2 aPoint = (from + delta * enter) * scale, bPoint = (from + delta * leave) * scale;
        bool changed = false;
        for (int y = 0; y < DoupiInteraction.CoverageHeight; y++)
        for (int x = 0; x < DoupiInteraction.CoverageWidth; x++)
        {
            int index = y * DoupiInteraction.CoverageWidth + x;
            Vector2 center = new Vector2((x + .5f) / DoupiInteraction.CoverageWidth, (y + .5f) / DoupiInteraction.CoverageHeight) * scale;
            if (!_coverage[index] && center.DistanceTo(Geometry2D.GetClosestPointToSegment(center, aPoint, bPoint)) <= DoupiInteraction.BrushRadius)
            { _coverage[index] = true; changed = true; }
        }
        if (changed) CoverageRevision++;
        if (Coverage >= DoupiInteraction.CoverageTarget)
        { Array.Fill(_coverage, true); CoverageRevision++; State = DoupiState.SecondCooking; _seconds = 0; }
        return changed;
    }

    public DoupiStateMachine(DoupiGriddleLevelData data) => _data = data;
    public bool TryPourBatter() { if (State != DoupiState.Empty) return false; State = DoupiState.Batter; return true; }
    public bool TryAddEgg() { if (State != DoupiState.Batter) return false; State = DoupiState.SkinCooking; _seconds = 0; return true; }
    public bool TryFlip()
    {
        if (State != DoupiState.ReadyToFlip) return false;
        State = DoupiState.Flipped; _seconds = 0; return true;
    }
    public bool TryAddFilling() { if (State != DoupiState.Flipped) return false; State = DoupiState.Spreading; _seconds = 0; return true; }
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
    public bool TryCut(DoupiCutLine direction)
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
        if (!inventory.TryAddBatch(amount, Quality, FirstRemainingPiece)) return 0;
        Generation++; // Even a partial transfer invalidates a drag of the old batch.
        RemainingPieces -= amount;
        if (RemainingPieces == 0) Reset();
        return amount;
    }
    public void Discard() => Reset();
    private void Reset() { Generation++; State = DoupiState.Empty; Quality = DoupiQuality.Normal; _seconds = 0; _cuts.Clear(); RemainingPieces = 0; Array.Clear(_coverage); CoverageRevision++; }
}
