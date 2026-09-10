using Godot;

namespace ProjectCake.Interaction;

/// <summary>A short click activates once; holding repeats until released or unavailable.</summary>
public partial class PressRepeatGesture : Control
{
    public const double HoldSeconds = .45;
    public const double RepeatSeconds = .15;
    public bool ActivateOnTap { get; set; } = true;
    public Func<bool> CanActivate { get; set; } = () => false;
    public Func<Vector2, bool>? Contains { get; set; }
    public Action? Activate { get; set; }
    public Action? Rejected { get; set; }
    private bool _pressed;
    private bool _repeating;
    private double _remaining;

    public PressRepeatGesture() { MouseDefaultCursorShape = CursorShape.PointingHand; }

    public override void _Ready()
    {
        MouseExited += Cancel;
        VisibilityChanged += () => { if (!IsVisibleInTree()) Cancel(); };
    }

    public override bool _HasPoint(Vector2 point) =>
        new Rect2(Vector2.Zero, Size).HasPoint(point) && (Contains?.Invoke(point) ?? true);

    public override void _GuiInput(InputEvent input)
    {
        if (input is not InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true }) return;
        AcceptEvent();
        Cancel();
        if (!CanActivate()) { Rejected?.Invoke(); return; }
        _pressed = true;
        _remaining = HoldSeconds;
    }

    public override void _Input(InputEvent input)
    {
        if (!_pressed) return;
        if (!CanActivate() || !IsVisibleInTree()) { Cancel(); return; }
        if (input is InputEventMouseMotion motion)
        {
            if (!_HasPoint(GetGlobalTransformWithCanvas().AffineInverse() * motion.Position)) Cancel();
        }
        else if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false } release)
        {
            bool tap = !_repeating && _HasPoint(GetGlobalTransformWithCanvas().AffineInverse() * release.Position);
            Cancel();
            if (tap && ActivateOnTap) Activate?.Invoke();
            GetViewport().SetInputAsHandled();
        }
        else if (input is InputEventKey { Keycode: Key.Escape, Pressed: true }) Cancel();
    }

    public void Tick(double delta)
    {
        if (!_pressed) return;
        if (!CanActivate() || !IsVisibleInTree()) { Cancel(); return; }
        _remaining -= Math.Max(0, delta);
        while (_pressed && _remaining <= 1e-9)
        {
            _repeating = true;
            _remaining += RepeatSeconds;
            Activate?.Invoke();
            if (!CanActivate()) Cancel();
        }
    }

    public void Cancel()
    {
        _pressed = false;
        _repeating = false;
        _remaining = 0;
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) Cancel();
    }

    public override void _ExitTree() => Cancel();
}
