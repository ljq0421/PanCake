using Godot;

namespace ProjectCake.Interaction;

public enum DragCompletion
{
    Accepted,
    Missed,
    Rejected,
    Cancelled,
}

public readonly record struct DragResult(string PayloadId, DragCompletion Completion, DropZone? Zone = null);

public partial class DragService : Node
{
    private readonly List<DropZone> _zones = new();
    private Control? _overlay;
    private PanelContainer? _proxy;
    private string _payloadId = string.Empty;
    private Vector2 _sourceCenter;
    private bool _returning;
    private Tween? _motionTween;

    public event Action<string>? DragStarted;
    public event Action<DragResult>? DragEnded;

    public bool IsDragging => _proxy is not null;

    public void Configure(Control overlay)
    {
        _overlay = overlay;
    }

    public void RegisterZone(DropZone zone)
    {
        if (!_zones.Contains(zone))
        {
            _zones.Add(zone);
        }
    }

    public void BeginDrag(Control source, string payloadId, string displayName, Color color, DragVisualSpec? visual = null)
    {
        if (_overlay is null || IsDragging)
        {
            return;
        }

        _payloadId = payloadId;
        _sourceCenter = source.GetGlobalRect().GetCenter();
        _returning = false;
        _proxy = new PanelContainer
        {
            CustomMinimumSize = visual?.DisplaySize ?? new Vector2(150, 58),
            MouseFilter = Control.MouseFilterEnum.Ignore,
            ZIndex = 1000,
        };
        if (visual is DragVisualSpec art)
        {
            _proxy.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
            _proxy.AddChild(new TextureRect
            {
                Texture = art.Texture,
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
                MouseFilter = Control.MouseFilterEnum.Ignore,
            });
            _overlay.AddChild(_proxy);
            MoveProxy(source.GetGlobalMousePosition());
            SetProcessInput(true);
            UpdateHighlights(source.GetGlobalMousePosition());
            DragStarted?.Invoke(payloadId);
            return;
        }
        var style = new StyleBoxFlat
        {
            BgColor = color,
            CornerRadiusTopLeft = 16,
            CornerRadiusTopRight = 16,
            CornerRadiusBottomLeft = 16,
            CornerRadiusBottomRight = 16,
            BorderWidthLeft = 3,
            BorderWidthTop = 3,
            BorderWidthRight = 3,
            BorderWidthBottom = 3,
            BorderColor = color.Lightened(0.35f),
        };
        _proxy.AddThemeStyleboxOverride("panel", style);
        var label = new Label
        {
            Text = displayName,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        label.AddThemeFontSizeOverride("font_size", 22);
        label.AddThemeColorOverride("font_color", new Color("#211A15"));
        _proxy.AddChild(label);
        _overlay.AddChild(_proxy);
        MoveProxy(source.GetGlobalMousePosition());
        SetProcessInput(true);
        UpdateHighlights(source.GetGlobalMousePosition());
        DragStarted?.Invoke(payloadId);
    }

    public override void _Input(InputEvent @event)
    {
        if (!IsDragging || _returning)
        {
            return;
        }

        if (@event is InputEventMouseMotion motion)
        {
            MoveProxy(motion.Position);
            UpdateHighlights(motion.Position);
            GetViewport().SetInputAsHandled();
        }
        else if (@event is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false } release)
        {
            CompleteDrag(release.Position);
            GetViewport().SetInputAsHandled();
        }
        else if (@event is InputEventKey { Keycode: Key.Escape, Pressed: true })
        {
            CancelDrag();
            GetViewport().SetInputAsHandled();
        }
    }

    public void CancelDrag()
    {
        if (!IsDragging)
        {
            return;
        }

        string payload = _payloadId;
        ClearDrag();
        DragEnded?.Invoke(new DragResult(payload, DragCompletion.Cancelled));
    }

    private void CompleteDrag(Vector2 position)
    {
        DropZone? zone = _zones.FirstOrDefault(candidate =>
            candidate.IsVisibleInTree()
            && candidate.GetGlobalRect().HasPoint(position));
        string payload = _payloadId;
        if (zone?.CanAccept(_payloadId) == true)
        {
            AnimateAccept(zone, payload);
            return;
        }

        if (zone is not null) zone.PulseRejected();
        AnimateReturn(payload, zone is null ? DragCompletion.Missed : DragCompletion.Rejected, zone);
    }

    private void MoveProxy(Vector2 position)
    {
        if (_proxy is not null)
        {
            _proxy.GlobalPosition = position - _proxy.Size * 0.5f;
        }
    }

    private void UpdateHighlights(Vector2 position)
    {
        foreach (DropZone zone in _zones)
        {
            if (!zone.IsVisibleInTree())
            {
                zone.SetDragState(DropZoneVisualState.Idle);
                continue;
            }
            bool hovered = zone.GetGlobalRect().HasPoint(position);
            bool valid = zone.CanAccept(_payloadId);
            zone.SetDragState(hovered
                ? valid ? DropZoneVisualState.HoverValid : DropZoneVisualState.HoverInvalid
                : valid ? DropZoneVisualState.Eligible : DropZoneVisualState.Idle);
        }
    }

    private void ClearDrag()
    {
        _motionTween?.Kill();
        _motionTween = null;
        foreach (DropZone zone in _zones)
        {
            zone.SetDragState(DropZoneVisualState.Idle);
        }

        _proxy?.QueueFree();
        _proxy = null;
        _payloadId = string.Empty;
        _returning = false;
        SetProcessInput(false);
    }

    private void AnimateReturn(string payload, DragCompletion completion, DropZone? zone = null)
    {
        if (_proxy is null)
        {
            return;
        }

        _returning = true;
        SetProcessInput(false);
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _motionTween = tween;
        double duration = ReducedMotion ? 0.10 : 0.18;
        tween.TweenProperty(_proxy, "global_position", _sourceCenter - _proxy.Size * 0.5f, duration);
        tween.Finished += () =>
        {
            if (_motionTween != tween) return;
            _motionTween = null;
            ClearDrag();
            DragEnded?.Invoke(new DragResult(payload, completion, zone));
        };
    }

    private void AnimateAccept(DropZone zone, string payload)
    {
        if (_proxy is null) return;
        _returning = true;
        SetProcessInput(false);
        foreach (DropZone candidate in _zones) candidate.SetDragState(DropZoneVisualState.Idle);

        Vector2 target = zone.ResolveSnapGlobalCenter(payload) - _proxy.Size * 0.5f;
        if (ReducedMotion)
        {
            zone.Accept(payload);
            ClearDrag();
            if (IsInstanceValid(zone)) zone.PulseAccepted();
            DragEnded?.Invoke(new DragResult(payload, DragCompletion.Accepted, zone));
            return;
        }

        _proxy.PivotOffset = _proxy.Size * 0.5f;
        Tween tween = CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.InOut);
        _motionTween = tween;
        tween.TweenProperty(_proxy, "global_position", target, 0.14);
        tween.TweenProperty(_proxy, "scale", new Vector2(0.94f, 0.94f), 0.14);
        tween.Finished += () =>
        {
            if (_motionTween != tween) return;
            _motionTween = null;
            if (!IsInstanceValid(zone) || !zone.IsVisibleInTree() || !zone.CanAccept(payload))
            {
                if (IsInstanceValid(zone)) zone.PulseRejected();
                AnimateReturn(payload, DragCompletion.Rejected, zone);
                return;
            }
            zone.Accept(payload);
            ClearDrag();
            if (IsInstanceValid(zone)) zone.PulseAccepted();
            DragEnded?.Invoke(new DragResult(payload, DragCompletion.Accepted, zone));
        };
    }

    private static bool ReducedMotion => ProjectSettings.HasSetting("accessibility/reduce_motion")
        && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();
}
