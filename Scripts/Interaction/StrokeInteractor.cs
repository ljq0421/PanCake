using Godot;

namespace ProjectCake.Interaction;

public enum StrokeMode
{
    None,
    Spread,
    Sauce,
}

public readonly record struct EllipseGeometry(Vector2 Center, Vector2 Radii);

public partial class StrokeInteractor : Control
{
    private readonly CircularStrokeTracker _spread = new();
    private readonly CoverageTracker _sauce = new(16);
    private StrokeMode _activeMode;
    private bool _dragging;
    private bool _pointerInside;
    private Vector2 _lastPoint;
    private bool _toolVisible;
    private Vector2 _toolPosition;
    private float _toolRotation;

    public Func<StrokeMode>? ResolveMode { get; set; }
    public Action<StrokeMode>? StrokeStarted { get; set; }
    public Action<StrokeMode, double>? StrokeProgressed { get; set; }
    public Action<StrokeMode>? StrokeCompleted { get; set; }
    public Action? InvalidStroke { get; set; }
    public Func<EllipseGeometry>? ResolveSpreadGeometry { get; set; }
    public Texture2D? SpreadToolTexture { get; set; }
    public float PancakeRadius { get; set; } = 180;

    public double SpreadProgress => _spread.Progress;
    public double SauceProgress => _sauce.Progress;

    public override void _Ready()
    {
        MouseDefaultCursorShape = CursorShape.Cross;
        MouseEntered += () =>
        {
            _pointerInside = true;
            RefreshVisualState();
        };
        MouseExited += () =>
        {
            _pointerInside = false;
            SetToolVisible(false);
        };
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
                _spread.EndStroke();
                _activeMode = StrokeMode.None;
                AcceptEvent();
                break;
            case InputEventMouseMotion motion when _dragging:
                ContinueStroke(motion.Position);
                AcceptEvent();
                break;
            case InputEventMouseMotion motion:
                UpdateTool(motion.Position);
                break;
        }
    }

    public void CancelStroke()
    {
        _dragging = false;
        _spread.EndStroke();
        _activeMode = StrokeMode.None;
        SetToolVisible(false);
    }

    public void ResetCoverage()
    {
        CancelStroke();
        _spread.Reset();
        _sauce.Reset();
        QueueRedraw();
    }

    public void RefreshVisualState()
    {
        bool show = _pointerInside && ResolveMode?.Invoke() == StrokeMode.Spread;
        SetToolVisible(show);
        if (show)
        {
            UpdateTool(GetLocalMousePosition());
        }
        QueueRedraw();
    }

    public override void _ExitTree()
    {
        SetToolVisible(false);
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
        if (mode == StrokeMode.Spread)
        {
            EllipseGeometry geometry = GetSpreadGeometry();
            _spread.BeginStroke(position, geometry.Center, geometry.Radii);
            UpdateTool(position);
        }
        else
        {
            _lastPoint = position - Size * 0.5f;
        }
        StrokeStarted?.Invoke(mode);
        ContinueStroke(position);
    }

    private void ContinueStroke(Vector2 position)
    {
        bool complete;
        double progress;
        if (_activeMode == StrokeMode.Spread)
        {
            EllipseGeometry geometry = GetSpreadGeometry();
            _spread.AddPoint(position, geometry.Center, geometry.Radii);
            progress = _spread.Progress;
            complete = _spread.IsComplete;
            UpdateTool(position);
            QueueRedraw();
        }
        else
        {
            Vector2 current = position - Size * 0.5f;
            _sauce.AddSegment(_lastPoint, current, PancakeRadius);
            _lastPoint = current;
            progress = _sauce.Progress;
            complete = _sauce.IsComplete;
        }
        StrokeProgressed?.Invoke(_activeMode, progress);

        if (!complete)
        {
            return;
        }

        StrokeMode completedMode = _activeMode;
        _dragging = false;
        _spread.EndStroke();
        _activeMode = StrokeMode.None;
        SetToolVisible(false);
        QueueRedraw();
        StrokeCompleted?.Invoke(completedMode);
    }

    public override void _Draw()
    {
        if (ResolveMode?.Invoke() != StrokeMode.Spread)
        {
            return;
        }

        EllipseGeometry geometry = GetSpreadGeometry();
        DrawPolyline(EllipsePoints(geometry, -Mathf.Pi / 2.0f, Mathf.Tau, 72), new Color(1.0f, 0.91f, 0.65f, 0.58f), 7.0f, true);
        if (_spread.Progress > 0)
        {
            float direction = _spread.SignedTravel < 0 ? -1.0f : 1.0f;
            float sweep = Mathf.Tau * (float)_spread.Progress * direction;
            DrawPolyline(EllipsePoints(geometry, -Mathf.Pi / 2.0f, sweep, Math.Max(8, Mathf.CeilToInt(72 * (float)_spread.Progress))), new Color("#F5B83D"), 10.0f, true);
        }
        DrawSpreadTool();
    }

    private EllipseGeometry GetSpreadGeometry() => ResolveSpreadGeometry?.Invoke()
        ?? new EllipseGeometry(Size * 0.5f, new Vector2(PancakeRadius, PancakeRadius * 0.62f));

    private void UpdateTool(Vector2 position)
    {
        if (!_toolVisible)
        {
            return;
        }

        EllipseGeometry geometry = GetSpreadGeometry();
        Vector2 normalized = new(
            (position.X - geometry.Center.X) / Math.Max(1.0f, geometry.Radii.X),
            (position.Y - geometry.Center.Y) / Math.Max(1.0f, geometry.Radii.Y));
        float angle = Mathf.Atan2(normalized.Y, normalized.X);
        _toolPosition = position;
        _toolRotation = angle + Mathf.Pi / 2.0f - 0.18f;
        QueueRedraw();
    }

    private void SetToolVisible(bool visible)
    {
        _toolVisible = visible;
        QueueRedraw();
        if (visible)
        {
            Input.MouseMode = Input.MouseModeEnum.Hidden;
        }
        else if (Input.MouseMode == Input.MouseModeEnum.Hidden)
        {
            Input.MouseMode = Input.MouseModeEnum.Visible;
        }
    }

    private void DrawSpreadTool()
    {
        if (!_toolVisible || SpreadToolTexture is null)
        {
            return;
        }

        Vector2 toolSize = new(116, 116);
        Vector2 contactAnchor = new(47, 79);
        DrawSetTransform(_toolPosition, _toolRotation, Vector2.One);
        DrawTextureRect(SpreadToolTexture, new Rect2(-contactAnchor, toolSize), false);
        DrawSetTransform(Vector2.Zero, 0, Vector2.One);
    }

    private static Vector2[] EllipsePoints(EllipseGeometry geometry, float start, float sweep, int segments)
    {
        var points = new Vector2[segments + 1];
        for (int index = 0; index <= segments; index++)
        {
            float angle = start + sweep * index / segments;
            points[index] = geometry.Center + new Vector2(Mathf.Cos(angle) * geometry.Radii.X, Mathf.Sin(angle) * geometry.Radii.Y);
        }
        return points;
    }
}
