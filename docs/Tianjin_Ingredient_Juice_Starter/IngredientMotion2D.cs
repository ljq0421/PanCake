#nullable enable
using Godot;
using System;

/// <summary>
/// 纯视觉组件：单份食材的短程移动、落稳和轻微形变。
/// 不负责库存、配方、碰撞、订单、鼠标拖拽或制作状态。
/// 结构：IngredientMotion2D -> Visual(Node2D) -> Sprite2D。
/// Root/Visual 建议单位缩放；贴图尺寸调整放在 Sprite2D 上。
/// destinationInParent、arcHeight、reboundHeight 均使用父级的设计坐标单位。
/// </summary>
public partial class IngredientMotion2D : Node2D
{
    [Export] public Node2D? VisualNode { get; set; }
    [Export] public bool ReducedMotion { get; set; }

    // 仅用于接触音等表现，禁止在这里扣库存或确认配方。
    public event Action? VisualContact;

    private Node2D _visual = null!;
    private Vector2 _restScale;
    private Vector2 _restVisualPosition;
    private float _restRotation;
    private Tween? _tween;
    private Vector2 _destination;
    private bool _hasDestination;
    private bool _configured;

    public override void _Ready()
    {
        Node2D? visual = VisualNode ?? GetNodeOrNull<Node2D>("Visual");
        if (visual == null || visual == this || !IsAncestorOf(visual))
        {
            GD.PushError($"{Name}: 请指定子节点 Visual，或创建名为 Visual 的 Node2D。");
            return;
        }
        _visual = visual;
        _restScale = _visual.Scale;
        _restVisualPosition = _visual.Position;
        _restRotation = _visual.Rotation;
        _configured = true;
    }

    public bool PlayPlacement(
        Vector2 destinationInParent,
        double travelSeconds = 0.12,
        float arcHeight = 8.0f,
        float squash = 0.03f,
        float reboundHeight = 0.0f)
    {
        if (!_configured || !IsInsideTree() || !GodotObject.IsInstanceValid(_visual))
            return false;
        if (!destinationInParent.IsFinite() || !double.IsFinite(travelSeconds) ||
            !float.IsFinite(arcHeight) || !float.IsFinite(squash) ||
            !float.IsFinite(reboundHeight))
        {
            GD.PushWarning($"{Name}: 落料动画参数必须为有限数值。");
            return false;
        }

        KillTween(); // 从当前姿态接续；不先强制跳回原姿态。
        _destination = destinationInParent;
        _hasDestination = true;
        float duration = Mathf.Clamp((float)travelSeconds, 0.02f, 0.40f);
        float h = Mathf.Clamp(arcHeight, 0.0f, 80.0f);
        float s = Mathf.Clamp(squash, 0.0f, 0.08f);
        float bounce = Mathf.Clamp(reboundHeight, 0.0f, 4.0f);

        if (ReducedMotion)
        {
            FinishImmediately();
            VisualContact?.Invoke();
            return true;
        }

        Vector2 from = Position;
        Vector2 startScale = _visual.Scale;
        Vector2 startOffset = _visual.Position;
        float startRotation = _visual.Rotation;

        _tween = CreateTween(); // 绑定到本节点，随本节点暂停/释放。
        _tween.TweenMethod(Callable.From<float>(t =>
        {
            // 弧线端点准确，t=0.5 时向上偏移 h。
            Position = from.Lerp(destinationInParent, t)
                + Vector2.Up * (4.0f * h * t * (1.0f - t));
            _visual.Scale = startScale.Lerp(_restScale, t);
            _visual.Position = startOffset.Lerp(_restVisualPosition, t);
            _visual.Rotation = Mathf.LerpAngle(startRotation, _restRotation, t);
        }), 0.0f, 1.0f, duration).SetTrans(Tween.TransitionType.Linear);

        _tween.TweenCallback(Callable.From(() => VisualContact?.Invoke()));

        if (s > 0.0f || bounce > 0.0f)
        {
            // 接触时压缩；硬质食物把 squash 设为 0。
            _tween.TweenProperty(_visual, "scale", Pose(1.0f + s), 0.035)
                .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);

            // 轻微反向形变；只有硬质小跳动才设置 reboundHeight。
            _tween.TweenProperty(_visual, "scale", Pose(1.0f - s * 0.45f), 0.05)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
            _tween.Parallel().TweenProperty(_visual, "position",
                    _restVisualPosition + Vector2.Up * bounce, 0.05)
                .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);

            _tween.TweenProperty(_visual, "scale", _restScale, 0.095)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
            _tween.Parallel().TweenProperty(_visual, "position", _restVisualPosition, 0.095)
                .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
        }

        _tween.TweenCallback(Callable.From(() =>
        {
            Position = destinationInParent;
            RestoreVisual();
            _hasDestination = false;
            _tween = null;
        }));
        return true;
    }

    /// <summary>
    /// 将已经在业务上接受的配料立即表现到终态。
    /// 用于紧接着折叠/翻面等情况；不补播接触音、不触发业务事件。
    /// </summary>
    public void FinishImmediately()
    {
        KillTween();
        if (_hasDestination)
            Position = _destination;
        _hasDestination = false;
        RestoreVisual();
    }

    /// <summary>
    /// 取消视觉过程但不自动移动 Root。无效拖放/对象池回收时，
    /// Root 的回位和库存预留归还由外层控制器负责。
    /// </summary>
    public void CancelMotion()
    {
        KillTween();
        _hasDestination = false;
        RestoreVisual();
    }

    private Vector2 Pose(float width)
        => new(_restScale.X * width, _restScale.Y / width);

    private void RestoreVisual()
    {
        if (!_configured || !GodotObject.IsInstanceValid(_visual)) return;
        _visual.Scale = _restScale;
        _visual.Position = _restVisualPosition;
        _visual.Rotation = _restRotation;
    }

    private void KillTween()
    {
        if (_tween != null && _tween.IsValid()) _tween.Kill();
        _tween = null;
    }

    public override void _ExitTree() => CancelMotion();
}
