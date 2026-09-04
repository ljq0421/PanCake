using Godot;

namespace ProjectCake.Interaction;

public partial class DragService : Node
{
    private readonly List<DropZone> _zones = new();
    private Control? _overlay;
    private PanelContainer? _proxy;
    private string _payloadId = string.Empty;
    private Vector2 _sourceCenter;
    private bool _returning;

    public event Action<string>? DragStarted;
    public event Action<string, bool>? DragEnded;

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
        DragEnded?.Invoke(payload, false);
    }

    private void CompleteDrag(Vector2 position)
    {
        DropZone? zone = _zones.FirstOrDefault(candidate =>
            candidate.IsVisibleInTree()
            && candidate.GetGlobalRect().HasPoint(position)
            && candidate.CanAccept(_payloadId));
        string payload = _payloadId;
        if (zone is not null)
        {
            zone.Accept(payload);
            ClearDrag();
            DragEnded?.Invoke(payload, true);
            return;
        }

        AnimateReturn(payload);
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
            bool hovered = zone.IsVisibleInTree() && zone.GetGlobalRect().HasPoint(position);
            zone.SetDragHighlight(hovered, hovered && zone.CanAccept(_payloadId));
        }
    }

    private void ClearDrag()
    {
        foreach (DropZone zone in _zones)
        {
            zone.SetDragHighlight(false, false);
        }

        _proxy?.QueueFree();
        _proxy = null;
        _payloadId = string.Empty;
        _returning = false;
        SetProcessInput(false);
    }

    private void AnimateReturn(string payload)
    {
        if (_proxy is null)
        {
            return;
        }

        _returning = true;
        SetProcessInput(false);
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(_proxy, "global_position", _sourceCenter - _proxy.Size * 0.5f, 0.22);
        tween.Finished += () =>
        {
            ClearDrag();
            DragEnded?.Invoke(payload, false);
        };
    }
}
