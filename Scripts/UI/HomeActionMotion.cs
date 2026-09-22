using Godot;

namespace ProjectCake.UI;

/// <summary>One short gesture on entry, never a loop and never a change to the hit target.</summary>
public partial class HomeActionMotion : Node
{
    public StartScreen Screen { get; init; } = null!;
    public TextureRect Icon { get; init; } = null!;
    public bool Train { get; init; }
    private Button _button = null!;
    private Vector2 _rest;
    private Tween? _motion;
    private bool _hovered;
    private bool _hadFocus;
    private bool _focused = true;

    public override void _Ready()
    {
        _button = GetParent<Button>();
        _rest = Icon.Position;
        Icon.PivotOffset = new(Icon.Size.X * .5f, Icon.Size.Y * .85f);
    }

    public override void _Process(double delta)
    {
        bool available = _focused && Screen.IsVisibleInTree() && !Screen.ModalOpen
            && Screen.Page == JourneyPage.Home && !_button.Disabled && !JourneyTransition.Reduced;
        if (!available) { Reset(); return; }
        bool hovered = _button.IsHovered(), focused = _button.HasFocus();
        // Default keyboard focus must not consume the next pointer entry.
        bool entered = hovered && !_hovered || focused && !_hadFocus;
        bool left = !hovered && !focused && (_hovered || _hadFocus);
        _hovered = hovered; _hadFocus = focused;
        if (!entered && !left) return;
        _motion?.Kill();
        _motion = CreateTween().SetParallel();
        if (entered)
        {
            _motion.TweenProperty(Icon, "position", _rest + (Train ? new Vector2(11, -2) : new Vector2(0, -6)), .18)
                .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
            _motion.TweenProperty(Icon, "rotation_degrees", Train ? -2f : -5f, .18)
                .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
            _motion.Chain();
        }
        _motion.TweenProperty(Icon, "position", _rest, .28)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _motion.TweenProperty(Icon, "rotation_degrees", 0f, .28)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    private void Reset()
    {
        _hovered = false; _hadFocus = false;
        _motion?.Kill(); _motion = null;
        Icon.Position = _rest; Icon.Rotation = 0;
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) { _focused = false; if (_button is not null) Reset(); }
        else if (what == NotificationApplicationFocusIn) _focused = true;
    }

    public override void _ExitTree() => _motion?.Kill();
}
