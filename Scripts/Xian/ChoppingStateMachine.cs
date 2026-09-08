using ProjectCake.Data;

namespace ProjectCake.Xian;

public sealed class ChoppingStateMachine
{
    private readonly double _workMultiplier;
    private int _direction;
    private double _legDistance;
    public ChoppingStateMachine(XianEquipmentData data, int initial)
    { Capacity = data.StockCapacity; Portions = Math.Min(initial, Capacity); _workMultiplier = data.WorkMultiplier; }
    public int Capacity { get; }
    public int Portions { get; private set; }
    public int CompletedChops { get; private set; }
    public bool IsChopping { get; private set; }
    public double Progress { get; private set; }
    public bool TryStart(RefillableStock meat)
    {
        if (IsChopping || Capacity - Portions < 2 || !meat.TryConsume(2)) return false;
        IsChopping = true; Progress = 0; EndGesture(); return true;
    }
    // Only sustained strokes in the board count. Eight 32px alternating legs finish Lv1.
    public void AddMotion(double horizontalDistance)
    {
        if (!IsChopping || !double.IsFinite(horizontalDistance) || horizontalDistance == 0) return;
        int direction = Math.Sign(horizontalDistance);
        if (_direction != 0 && direction != _direction)
        {
            if (_legDistance >= 32) Progress += 12.5 / _workMultiplier;
            _legDistance = 0;
        }
        _direction = direction; _legDistance += Math.Min(80, Math.Abs(horizontalDistance));
        if (Progress >= 85)
        { Progress = 100; Portions += 2; CompletedChops++; IsChopping = false; EndGesture(); }
    }
    public void EndGesture() { _direction = 0; _legDistance = 0; }
    public bool TryTake() { if (Portions < 1) return false; Portions--; return true; }
}
