using Godot;

namespace ProjectCake.Interaction;

public enum DropZoneVisualState
{
    Idle,
    Eligible,
    HoverValid,
    HoverInvalid,
}

public partial class DropZone : PanelContainer
{
    private readonly StyleBoxFlat _style = new();
    private Func<string, bool>? _canAccept;
    private Action<string>? _accepted;
    private Func<string, Vector2>? _snapGlobalCenter;
    private DropZoneVisualState _visualState;
    private Tween? _stateTween;
    private Tween? _pulseTween;

    public DropZoneVisualState VisualState => _visualState;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        _style.BgColor = new Color(0, 0, 0, 0);
        _style.BorderWidthLeft = 3;
        _style.BorderWidthTop = 3;
        _style.BorderWidthRight = 3;
        _style.BorderWidthBottom = 3;
        _style.BorderColor = new Color(1, 1, 1, 0);
        _style.CornerRadiusTopLeft = 18;
        _style.CornerRadiusTopRight = 18;
        _style.CornerRadiusBottomLeft = 18;
        _style.CornerRadiusBottomRight = 18;
        AddThemeStyleboxOverride("panel", _style);
    }

    public void Configure(
        Func<string, bool> canAccept,
        Action<string> accepted,
        Func<string, Vector2>? snapGlobalCenter = null)
    {
        _canAccept = canAccept;
        _accepted = accepted;
        _snapGlobalCenter = snapGlobalCenter;
    }

    public bool CanAccept(string payloadId) => _canAccept?.Invoke(payloadId) == true;

    public void Accept(string payloadId) => _accepted?.Invoke(payloadId);

    public Vector2 ResolveSnapGlobalCenter(string payloadId) =>
        _snapGlobalCenter?.Invoke(payloadId) ?? GetGlobalRect().GetCenter();

    public void SetDragState(DropZoneVisualState state)
    {
        if (_visualState == state) return;
        _visualState = state;
        (_style.BorderColor, _style.BgColor) = state switch
        {
            DropZoneVisualState.Eligible => (new Color(0.47f, 0.85f, 0.58f, 0.48f), new Color(0.18f, 0.55f, 0.30f, 0.05f)),
            DropZoneVisualState.HoverValid => (new Color("#77D895"), new Color(0.18f, 0.55f, 0.30f, 0.15f)),
            DropZoneVisualState.HoverInvalid => (new Color("#E36C5B"), new Color(0.75f, 0.15f, 0.12f, 0.12f)),
            _ => (new Color(1, 1, 1, 0), new Color(0, 0, 0, 0)),
        };
        QueueRedraw();

        _stateTween?.Kill();
        if (ReducedMotion)
        {
            Scale = Vector2.One;
            return;
        }
        PivotOffset = Size * 0.5f;
        float scale = state == DropZoneVisualState.HoverValid ? 1.03f : state == DropZoneVisualState.HoverInvalid ? 1.01f : 1.0f;
        _stateTween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _stateTween.TweenProperty(this, "scale", Vector2.One * scale, 0.10);
    }

    public void PulseAccepted() => Pulse(new Color(0.65f, 1f, 0.72f, 1), 0.97f);

    public void PulseRejected() => Pulse(new Color(1f, 0.65f, 0.60f, 1), 0.98f);

    private void Pulse(Color tint, float pressedScale)
    {
        _stateTween?.Kill();
        _stateTween = null;
        _pulseTween?.Kill();
        PivotOffset = Size * 0.5f;
        _pulseTween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        if (!ReducedMotion) _pulseTween.TweenProperty(this, "scale", Vector2.One * pressedScale, 0.07);
        _pulseTween.Parallel().TweenProperty(this, "modulate", tint, 0.07);
        _pulseTween.TweenProperty(this, "scale", Vector2.One, 0.13);
        _pulseTween.Parallel().TweenProperty(this, "modulate", Colors.White, 0.13);
    }

    private static bool ReducedMotion => ProjectSettings.HasSetting("accessibility/reduce_motion")
        && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();
}
