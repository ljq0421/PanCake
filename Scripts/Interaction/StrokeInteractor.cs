using Godot;
using ProjectCake.Pancake;

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
    // Fine cells make a single sweep gradual while preserving unique-area coverage.
    internal const int SauceRings = 16, SauceSectors = 32, SauceRequiredCells = 144;
    private readonly CoverageTracker _sauce = new(SauceRequiredCells, SauceRules.MaximumAmount,
        SauceRings, SauceSectors, 1);
    private double _sauceCompletionRemaining;
    private double _completedSauceAmount;
    internal bool SauceCompletionVisible => _sauceCompletionRemaining > 0;
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
    public Action<Vector2>? SaucePainted { get; set; }
    public Action<Vector2>? SpreadPainted { get; set; }
    public Action? StrokeEnded { get; set; }
    public bool GentleSauceTool { get; set; }
    public Func<EllipseGeometry>? ResolveSpreadGeometry { get; set; }
    public Texture2D? SpreadToolTexture { get; set; }
    public bool SpreadToolOnlyDuringStroke { get; set; }
    public Vector2 SpreadToolSize { get; set; } = new(116, 116);
    public Vector2 SpreadToolContactAnchor { get; set; } = new(47, 79);
    public Texture2D? SauceToolTexture { get; set; }
    public Func<bool>? IsToolHeld { get; set; }
    public Func<double>? ResolveSauceAmount { get; set; }
    internal bool SauceMeterVisible => IsVisibleInTree() && _toolVisible
        && ResolveMode?.Invoke() == StrokeMode.Sauce && ResolveSauceAmount is not null;
    private readonly StyleBoxFlat _sauceMeterStyle = new()
    {
        BgColor = new Color("#FFF1D9"),
        CornerRadiusTopLeft = 8, CornerRadiusTopRight = 8,
        CornerRadiusBottomLeft = 8, CornerRadiusBottomRight = 8,
    };
    public float PancakeRadius { get; set; } = 180;

    public double SpreadProgress => _spread.Progress;
    public double SauceProgress => _sauce.Progress;
    public bool IsSpreading => _dragging && _activeMode == StrokeMode.Spread;

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
            StrokeEnded?.Invoke();
            RefreshVisualState();
        };
    }

    public override void _Process(double delta)
    {
        if (IsToolHeld?.Invoke() == true || _toolVisible) RefreshVisualState();
        if (_sauceCompletionRemaining > 0)
        {
            _sauceCompletionRemaining = Math.Max(0, _sauceCompletionRemaining - delta);
            ZIndex = _sauceCompletionRemaining > 0 ? 88 : 0;
            QueueRedraw();
        }
    }

    public void ShowSauceCompletion(double amount)
    {
        CancelStroke();
        _completedSauceAmount = amount;
        _sauceCompletionRemaining = 1.1;
        ZIndex = 88;
        QueueRedraw();
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
                StrokeEnded?.Invoke();
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
        StrokeEnded?.Invoke();
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
        _sauceCompletionRemaining = 0;
        QueueRedraw();
    }

    public void RefreshVisualState()
    {
        bool held = IsToolHeld?.Invoke() == true;
        StrokeMode mode = ResolveMode?.Invoke() ?? StrokeMode.None;
        if (mode != StrokeMode.Sauce) StrokeEnded?.Invoke();
        bool activeSpreadTool = SpreadToolOnlyDuringStroke && _dragging && mode == StrokeMode.Spread;
        bool show = IsVisibleInTree() && (_pointerInside || held || activeSpreadTool)
            && mode is StrokeMode.Spread or StrokeMode.Sauce
            && (!SpreadToolOnlyDuringStroke || mode != StrokeMode.Spread || _dragging);
        ZIndex = held || activeSpreadTool || SauceCompletionVisible ? 88 : 0;
        SetToolVisible(show);
        if (show && !(SpreadToolOnlyDuringStroke && _dragging))
        {
            UpdateTool(GetLocalMousePosition());
        }
        QueueRedraw();
    }

    public override void _ExitTree()
    {
        StrokeEnded?.Invoke();
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
        if (SpreadToolOnlyDuringStroke) RefreshVisualState();
        if (mode == StrokeMode.Spread)
        {
            EllipseGeometry geometry = GetSpreadGeometry();
            _spread.BeginStroke(position, geometry.Center, geometry.Radii);
            UpdateTool(position);
        }
        else
        {
            _lastPoint = SaucePoint(position);
        }
        StrokeStarted?.Invoke(mode);
        ContinueStroke(position);
    }

    private void ContinueStroke(Vector2 position)
    {
        if ((ResolveMode?.Invoke() ?? StrokeMode.None) != _activeMode || _activeMode == StrokeMode.None)
        {
            CancelStroke(); return;
        }
        bool complete;
        double progress;
        if (_activeMode == StrokeMode.Spread)
        {
            EllipseGeometry geometry = GetSpreadGeometry();
            double before = _spread.Progress;
            _spread.AddPoint(position, geometry.Center, geometry.Radii);
            if (_spread.Progress > before) SpreadPainted?.Invoke(GetGlobalTransformWithCanvas() * position);
            progress = _spread.Progress;
            complete = _spread.IsComplete;
            UpdateTool(position);
            QueueRedraw();
        }
        else
        {
            Vector2 current = SaucePoint(position);
            SaucePainted?.Invoke(GetGlobalTransform() * position);
            _sauce.AddSegment(_lastPoint, current, PancakeRadius);
            _lastPoint = current;
            progress = _sauce.Progress;
            complete = _sauce.IsComplete;
            UpdateTool(position);
            QueueRedraw();
        }
        StrokeProgressed?.Invoke(_activeMode, progress);

        if (!complete)
        {
            return;
        }

        StrokeMode completedMode = _activeMode;
        _dragging = false;
        StrokeEnded?.Invoke();
        _spread.EndStroke();
        _activeMode = StrokeMode.None;
        SetToolVisible(false);
        QueueRedraw();
        StrokeCompleted?.Invoke(completedMode);
    }

    public override void _Draw()
    {
        if (SauceCompletionVisible)
        {
            EllipseGeometry finishedGeometry = GetSpreadGeometry();
            Vector2 origin = finishedGeometry.Center - new Vector2(112, finishedGeometry.Radii.Y + 58);
            DrawStyleBox(_sauceMeterStyle, new Rect2(origin, new Vector2(224, 44)));
            DrawString(GetThemeFont("font"), origin + new Vector2(14, 29),
                $"{SauceRules.Name(SauceRules.Classify(_completedSauceAmount))}完成 · {_completedSauceAmount * 100:0}%",
                HorizontalAlignment.Center, 196, 20, new Color("#36583B"));
        }
        StrokeMode mode = ResolveMode?.Invoke() ?? StrokeMode.None;
        if (mode == StrokeMode.None)
        {
            return;
        }

        if (mode == StrokeMode.Sauce)
        {
            EllipseGeometry sauceGeometry = GetSpreadGeometry();
            DrawPolyline(EllipsePoints(sauceGeometry, -Mathf.Pi / 2.0f, Mathf.Tau, 72), new Color(0.96f, 0.49f, 0.18f, 0.62f), 6, true);
            DrawTool(SauceToolTexture, new Vector2(104, 104), new Vector2(38, 72));
            if (SauceMeterVisible) DrawSauceMeter();
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
        DrawTool(SpreadToolTexture, SpreadToolSize, SpreadToolContactAnchor);
    }

    internal Rect2 SauceMeterBounds()
    {
        Vector2 size = new(240, 106);
        // Keep the readout anchored above the pancake. It must remain readable
        // while the brush moves across the work surface.
        EllipseGeometry geometry = GetSpreadGeometry();
        Transform2D transform = GetGlobalTransformWithCanvas();
        Rect2 viewport = GetViewportRect();
        Vector2 position = transform * (geometry.Center - new Vector2(size.X * 0.5f, geometry.Radii.Y + size.Y + 20));
        position.X = Mathf.Clamp(position.X, viewport.Position.X + 12, viewport.End.X - size.X - 12);
        position.Y = Mathf.Clamp(position.Y, viewport.Position.Y + 12, viewport.End.Y - size.Y - 12);
        position = transform.AffineInverse() * position;
        return new Rect2(position, size);
    }

    private void DrawSauceMeter()
    {
        double amount = Math.Clamp(ResolveSauceAmount!(), 0, SauceRules.MaximumAmount);
        Rect2 bounds = SauceMeterBounds();
        Vector2 position = bounds.Position, size = bounds.Size;
        DrawStyleBox(_sauceMeterStyle, bounds);
        DrawString(GetThemeFont("font"), position + new Vector2(12, 26), SauceRules.Describe(amount),
            HorizontalAlignment.Left, size.X - 24, 20, new Color("#553322"));
        Rect2 track = new(position + new Vector2(12, 63), new Vector2(size.X - 24, 6));
        SaucePreference current = SauceRules.Classify(amount);
        SaucePreference[] bands = { SaucePreference.Light, SaucePreference.Normal, SaucePreference.Extra };
        for (int index = 0; index < bands.Length; index++)
        {
            bool active = current == bands[index];
            Vector2 segment = track.Position + new Vector2(index * track.Size.X / 3, 0);
            DrawRect(new Rect2(segment, new Vector2(track.Size.X / 3 - 3, track.Size.Y)),
                new Color(active ? "#A9562D" : "#D8BE99"));
            DrawString(GetThemeFont("font"), segment + new Vector2(0, -12), SauceRules.Name(bands[index]),
                HorizontalAlignment.Center, track.Size.X / 3 - 3, 18, new Color(active ? "#713717" : "#725C46"));
        }
        Vector2 pointerTip = track.Position + new Vector2(track.Size.X * (float)(amount / SauceRules.MaximumAmount), 8);
        DrawColoredPolygon(new[] { pointerTip, pointerTip + new Vector2(-5, 7), pointerTip + new Vector2(5, 7) }, new Color("#553322"));
        DrawString(GetThemeFont("font"), position + new Vector2(12, 96), "到所需档位后收刷",
            HorizontalAlignment.Center, size.X - 24, 16, new Color("#725C46"));
    }

    private EllipseGeometry GetSpreadGeometry() => ResolveSpreadGeometry?.Invoke()
        ?? new EllipseGeometry(Size * 0.5f, new Vector2(PancakeRadius, PancakeRadius * 0.62f));

    private Vector2 SaucePoint(Vector2 position)
    {
        EllipseGeometry geometry = GetSpreadGeometry();
        return new Vector2((position.X - geometry.Center.X) / Math.Max(1, geometry.Radii.X),
            (position.Y - geometry.Center.Y) / Math.Max(1, geometry.Radii.Y)) * PancakeRadius;
    }

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
        if (GentleSauceTool && (ResolveMode?.Invoke() ?? StrokeMode.None) == StrokeMode.Sauce)
            _toolRotation = Mathf.Clamp(normalized.X * .045f, -.05f, .05f);
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

    private void DrawTool(Texture2D? texture, Vector2 toolSize, Vector2 contactAnchor)
    {
        if (!_toolVisible || texture is null)
        {
            return;
        }

        DrawSetTransform(_toolPosition, _toolRotation, Vector2.One);
        DrawTextureRect(texture, new Rect2(-contactAnchor, toolSize), false);
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
