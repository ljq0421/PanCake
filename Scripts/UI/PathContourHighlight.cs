using Godot;

namespace ProjectCake.UI;

/// <summary>An input-transparent contour for a visible object painted into the scene background.</summary>
public partial class PathContourHighlight : Control
{
    private Vector2[] _points = [];
    private Func<InteractionHighlightState> _resolve = null!;
    private InteractionHighlightState _state;

    public static PathContourHighlight Attach(Control source, Vector2[] points, Func<InteractionHighlightState> state)
    {
        var contour = new PathContourHighlight
        {
            Name = "ObjectContour", MouseFilter = MouseFilterEnum.Ignore,
            _points = points, _resolve = state,
        };
        source.AddChild(contour);
        return contour;
    }

    public override void _Process(double delta)
    {
        var state = IsVisibleInTree() ? _resolve() : InteractionHighlightState.None;
        if (_state == state) return;
        _state = state;
        QueueRedraw();
    }

    public override void _Draw() => InteractionHighlightPresentation.DrawPath(this, _points, _state);
}
