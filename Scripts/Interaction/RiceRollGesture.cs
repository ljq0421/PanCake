using Godot;

namespace ProjectCake.Interaction;

public enum RiceRollGestureMode { None, Spread, Roll, Push, Pull, Sauce }

/// <summary>Normalized tray coordinates keep gesture distances independent of window size.</summary>
public sealed class RiceRollGesture
{
    private Vector2 _start, _last;
    private float _direction;
    private double _rollStart;
    private double _distance;
    public RiceRollGestureMode Mode { get; private set; }
    public bool Begin(RiceRollGestureMode mode, Vector2 point, double rollStart = 0)
    {
        Cancel();
        if (mode == RiceRollGestureMode.Roll && point.X is > .18f and < .82f && rollStart <= 0) return false;
        Mode = mode; _start = _last = point; _direction = point.X <= .5f ? 1 : -1; _rollStart = rollStart;
        return mode != RiceRollGestureMode.None;
    }
    public double Move(Vector2 point)
    {
        if (Mode == RiceRollGestureMode.None) return 0;
        // A stroke that leaves the working surface must start again; it never bridges an out-of-bounds gap.
        if (Mode is RiceRollGestureMode.Spread or RiceRollGestureMode.Roll or RiceRollGestureMode.Sauce
            && (point.X < 0 || point.X > 1 || point.Y < 0 || point.Y > 1)) { Cancel(); return 0; }
        double distance = point.DistanceTo(_last); _last = point;
        switch (Mode)
        {
            case RiceRollGestureMode.Spread: return distance / 1.5;
            case RiceRollGestureMode.Roll: return Math.Clamp(_rollStart + (point.X - _start.X) * _direction, 0, 1);
            case RiceRollGestureMode.Push: return _start.Y - point.Y;
            case RiceRollGestureMode.Pull: return point.Y - _start.Y;
            case RiceRollGestureMode.Sauce: _distance += distance; return _distance;
            default: return 0;
        }
    }
    public void Cancel() { Mode = RiceRollGestureMode.None; _distance = 0; }
}
