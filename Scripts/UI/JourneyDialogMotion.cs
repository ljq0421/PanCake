using Godot;

namespace ProjectCake.UI;

/// <summary>Native popup windows keep their focus, confirmation and cancellation semantics.</summary>
public partial class JourneyDialogMotion : Node
{
    private Window _window = null!;
    private Tween? _fade;
    private readonly Dictionary<CanvasItem, Color> _colors = new();
    private bool _shown;
    public static void Attach(Window window)
    {
        if (window.HasNode("JourneyDialogMotion")) return;
        window.AddChild(new JourneyDialogMotion { Name = "JourneyDialogMotion" });
    }
    public override void _Ready()
    {
        _window = GetParent<Window>();
        _window.VisibilityChanged += Animate;
    }
    private void Restore()
    {
        _fade?.Kill(); _fade = null;
        foreach (var (item, color) in _colors)
            if (IsInstanceValid(item)) item.Modulate = color;
        _colors.Clear();
    }
    private void Animate()
    {
        Restore();
        bool visible = _window.Visible;
        if (visible == _shown) return;
        _shown = visible;
        if (_window.GetMeta("dialog_city", "").AsString() is not ("city:tianjin" or "city:wuhan")) return;
        if (JourneyTransition.Reduced || DisplayServer.GetName() == "headless") return;
        if (!visible)
        {
            if (_window.IsInsideTree() && _window.GetParent() is not CanvasItem { Visible: false })
                JourneyTransition.For(this).Play(JourneyTransition.Effect.CloseBook,
                    bounds: new Rect2(_window.Position, _window.Size));
            return;
        }
        JourneyTransition.For(this).Finish();
        var items = _window.GetChildren(true).OfType<CanvasItem>().ToList();
        foreach (CanvasLayer layer in _window.GetChildren().OfType<CanvasLayer>())
            items.AddRange(layer.GetChildren().OfType<CanvasItem>());
        _fade = CreateTween().SetParallel();
        foreach (CanvasItem item in items)
        {
            Color color = item.Modulate; _colors[item] = color;
            item.Modulate = new Color(color, color.A * .12f);
            _fade.TweenProperty(item, "modulate", color, .22).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        }
    }
    public override void _ExitTree()
    {
        _window.VisibilityChanged -= Animate;
        Restore();
    }
}
