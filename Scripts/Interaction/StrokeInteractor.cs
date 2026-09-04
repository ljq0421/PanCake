using Godot;

namespace ProjectCake.Interaction;

public enum StrokeMode
{
    None,
    Spread,
    Sauce,
}

public partial class StrokeInteractor : Control
{
    private readonly CoverageTracker _spread = new(23);
    private readonly CoverageTracker _sauce = new(16);
    private StrokeMode _activeMode;
    private bool _dragging;
    private Vector2 _lastPoint;

    public Func<StrokeMode>? ResolveMode { get; set; }
    public Action<StrokeMode>? StrokeStarted { get; set; }
    public Action<StrokeMode, double>? StrokeProgressed { get; set; }
    public Action<StrokeMode>? StrokeCompleted { get; set; }
    public Action? InvalidStroke { get; set; }
    public float PancakeRadius { get; set; } = 180;

    public double SpreadProgress => _spread.Progress;
    public double SauceProgress => _sauce.Progress;

    public override void _Ready()
    {
        MouseDefaultCursorShape = CursorShape.Cross;
    }

    public override void _GuiInput(InputEvent @event)
    {
        switch (@event)
        {
            case InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true } press:
                BeginStroke(press.Position);
                AcceptEvent();
                break;
            case InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false }:
                _dragging = false;
                _activeMode = StrokeMode.None;
                AcceptEvent();
                break;
            case InputEventMouseMotion motion when _dragging:
                ContinueStroke(motion.Position);
                AcceptEvent();
                break;
        }
    }

    public void CancelStroke()
    {
        _dragging = false;
        _activeMode = StrokeMode.None;
    }

    public void ResetCoverage()
    {
        CancelStroke();
        _spread.Reset();
        _sauce.Reset();
    }

    private void BeginStroke(Vector2 position)
    {
        StrokeMode mode = ResolveMode?.Invoke() ?? StrokeMode.None;
        if (mode == StrokeMode.None)
        {
            InvalidStroke?.Invoke();
            return;
        }

        _activeMode = mode;
        _dragging = true;
        _lastPoint = position - Size * 0.5f;
        StrokeStarted?.Invoke(mode);
        ContinueStroke(position);
    }

    private void ContinueStroke(Vector2 position)
    {
        Vector2 current = position - Size * 0.5f;
        CoverageTracker tracker = _activeMode == StrokeMode.Spread ? _spread : _sauce;
        tracker.AddSegment(_lastPoint, current, PancakeRadius);
        _lastPoint = current;
        StrokeProgressed?.Invoke(_activeMode, tracker.Progress);

        if (!tracker.IsComplete)
        {
            return;
        }

        StrokeMode completedMode = _activeMode;
        _dragging = false;
        _activeMode = StrokeMode.None;
        StrokeCompleted?.Invoke(completedMode);
    }
}
