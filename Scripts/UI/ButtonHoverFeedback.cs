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
    private BaseButton _button = null!;
    private Control? _visual;
    private Vector2 _restScale;
    private Tween? _tween;
    private bool _held;
    private float _target = 1;

    public static void Attach(BaseButton button, Control? visual = null)
    {
        if (button.GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is not null) return;
        button.AddChild(new ButtonHoverFeedback { Name = "ButtonHoverFeedback", _visual = visual });
    }

    public override void _Ready()
    {
        _button = GetParent<BaseButton>();
        ProcessMode = ProcessModeEnum.Always;
        // Containers finish laying out their children after Ready.
        CallDeferred(nameof(Configure));
    }

    private void Configure()
    {
        if (!IsInsideTree() || _button.IsQueuedForDeletion()) return;
        _visual ??= _button;
        _restScale = _visual.Scale;
        _button.MouseEntered += Refresh;
        _button.MouseExited += Refresh;
        _button.FocusEntered += Refresh;
        _button.FocusExited += Refresh;
        _button.ButtonDown += Down;
        _button.ButtonUp += Up;
        _button.VisibilityChanged += Refresh;
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
            if (_held && !_button.IsPressed()) _held = false;
            Refresh();
        }
    }

    private void Refresh()
    {
        bool available = _button.IsVisibleInTree() && !_button.Disabled
            && _button.MouseFilter != Control.MouseFilterEnum.Ignore;
        if (!available)
        {
            _held = false; _target = 1;
            _tween?.Kill(); _tween = null;
            if (!_visual!.Scale.IsEqualApprox(_restScale)) _visual.Scale = _restScale;
            return;
        }
        float target = _held ? .98f
            : _button.IsHovered() || _button.HasFocus() ? 1.04f : 1;
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
