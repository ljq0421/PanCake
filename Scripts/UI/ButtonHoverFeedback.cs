using Godot;

namespace ProjectCake.UI;

/// <summary>Centered, interruptible feedback for interface buttons.</summary>
public partial class ButtonHoverFeedback : Node
{
    public static void AttachTree(Node root)
    {
        if (root is BaseButton button) Attach(button);
        foreach (Node child in root.GetChildren()) AttachTree(child);
    }
    private Control _source = null!;
    private Func<bool>? _canInteract;
    private Control? _visual;
    private Vector2 _restScale;
    private Tween? _tween;
    private bool _held;
    private bool _focusAlsoScales;
    private float _target = 1;

    public static void Attach(Control source, Control? visual = null, Func<bool>? canInteract = null)
    {
        if (source.GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is { } existing)
        {
            if (visual is not null && existing._restScale == Vector2.Zero) existing._visual = visual;
            return;
        }
        source.AddChild(new ButtonHoverFeedback { Name = "ButtonHoverFeedback", _visual = visual, _canInteract = canInteract });
    }

    public override void _Ready()
    {
        _source = GetParent<Control>();
        ProcessMode = ProcessModeEnum.Always;
        // Containers finish laying out their children after Ready.
        CallDeferred(nameof(Configure));
    }

    private void Configure()
    {
        if (!IsInsideTree() || _source.IsQueuedForDeletion()) return;
        _visual ??= _source;
        _restScale = _visual.Scale;
        // This follow-up explicitly excludes Xi'an city screens. Preserve their prior feedback.
        for (Node? owner = _source; owner is not null; owner = owner.GetParent())
            if (owner is ProjectCake.Gameplay.XianDayScreen or XianHub) _focusAlsoScales = true;
        _source.MouseEntered += Refresh;
        _source.MouseExited += Refresh;
        if (_focusAlsoScales) { _source.FocusEntered += Refresh; _source.FocusExited += Refresh; }
        if (_source is BaseButton button)
        {
            button.ButtonDown += Down;
            button.ButtonUp += Up;
        }
        _source.VisibilityChanged += Refresh;
        _visual.Resized += Center;
        Center();
        Refresh();
    }

    private void Center() => _visual!.PivotOffset = _visual.Size * .5f;
    private void Down() { _held = true; Refresh(); }
    private void Up() { _held = false; Refresh(); }

    public override void _Process(double delta)
    {
        // Disabled has no change signal; also catch focus loss during a press.
        if (_restScale != Vector2.Zero)
        {
            if (_held && _source is BaseButton { } button && !button.IsPressed()) _held = false;
            Refresh();
        }
    }

    private void Refresh()
    {
        bool available = _source.IsVisibleInTree() && _source is not BaseButton { Disabled: true }
            && _source.MouseFilter != Control.MouseFilterEnum.Ignore && (_canInteract?.Invoke() ?? true);
        if (!available)
        {
            _held = false; _target = 1;
            _tween?.Kill(); _tween = null;
            if (!_visual!.Scale.IsEqualApprox(_restScale)) _visual.Scale = _restScale;
            return;
        }
        Control? hovered = _source.GetViewport().GuiGetHoveredControl();
        bool over = _source is BaseButton b ? b.IsHovered()
            : hovered == _source || (hovered is not null && _source.IsAncestorOf(hovered));
        // Default focus and post-click focus must never consume the hover transition.
        // Keyboard focus keeps the authored outline; only pointer hover enlarges the art.
        float target = _held ? .98f : over || (_focusAlsoScales && _source.HasFocus()) ? 1.04f : 1;
        if (Mathf.IsEqualApprox(target, _target)) return;
        _target = target;
        _tween?.Kill();
        Center();
        if (ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool())
        { _visual!.Scale = _restScale * target; return; }
        _tween = CreateTween().SetPauseMode(Tween.TweenPauseMode.Process);
        _tween.TweenProperty(_visual, "scale", _restScale * target, .14)
            .SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
    }

    public override void _ExitTree() => _tween?.Kill();
}
