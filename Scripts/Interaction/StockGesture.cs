using Godot;

namespace ProjectCake.Interaction;

/// <summary>Opt-in stock interaction. One press resolves to a tap, drag, or refill.</summary>
public partial class StockGesture : Control
{
    public const double HoldSeconds = .45;
    public const float DragDistance = 8;
    public Func<bool> CanInteract { get; set; } = () => false;
    public Func<bool> CanRefill { get; set; } = () => false;
    public Action? Refill { get; set; }
    public Action? Tap { get; set; }
    public Action? Drag { get; set; }
    public Action<double>? Progress { get; set; }
    public Func<Vector2, bool>? Contains { get; set; }
    private Vector2 _origin;
    private double _elapsed;
    private bool _pressed;
    private bool _resolved;
    public double HoldProgress => _pressed && !_resolved ? Math.Clamp(_elapsed / HoldSeconds, 0, 1) : 0;

    public StockGesture() { MouseDefaultCursorShape = CursorShape.PointingHand; }
    public override bool _HasPoint(Vector2 point) => new Rect2(Vector2.Zero, Size).HasPoint(point) && (Contains?.Invoke(point) ?? true);

    public override void _GuiInput(InputEvent input)
    {
        if (input is not InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true } mouse) return;
        AcceptEvent();
        if (!CanInteract()) return;
        _origin = mouse.Position;
        _elapsed = 0;
        _resolved = false;
        _pressed = true;
    }

    public override void _Input(InputEvent input)
    {
        if (!_pressed) return;
        if (!CanInteract() || !IsVisibleInTree()) { Cancel(); return; }
        if (input is InputEventMouseMotion motion)
        {
            Vector2 point = GetGlobalTransformWithCanvas().AffineInverse() * motion.Position;
            if (!_resolved && point.DistanceTo(_origin) > DragDistance)
            {
                // Resolve movement before bounds: a fast first motion may already be outside.
                Action? drag = Drag;
                Cancel();
                drag?.Invoke();
            }
            else if (!_HasPoint(point)) Cancel();
        }
        else if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false } release)
        {
            bool tap = !_resolved && _HasPoint(GetGlobalTransformWithCanvas().AffineInverse() * release.Position);
            Cancel();
            if (tap) Tap?.Invoke();
            GetViewport().SetInputAsHandled();
        }
        else if (input is InputEventKey { Keycode: Key.Escape, Pressed: true }) Cancel();
    }

    public void Tick(double delta)
    {
        if (!_pressed) return;
        if (!CanInteract() || !IsVisibleInTree()) { Cancel(); return; }
        if (_resolved) return;
        _elapsed += Math.Max(0, delta);
        if (_elapsed + 1e-9 >= HoldSeconds)
        {
            _resolved = true;
            Progress?.Invoke(0);
            if (CanRefill()) Refill?.Invoke();
        }
        else Progress?.Invoke(CanRefill() ? HoldProgress : 0);
    }

    public void Cancel()
    {
        _pressed = false;
        _resolved = false;
        _elapsed = 0;
        Progress?.Invoke(0);
    }

    public override void _ExitTree() => Cancel();
}
