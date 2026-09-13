using Godot;

namespace ProjectCake.UI;

/// <summary>An input-transparent contour for a visible object painted into the scene background.</summary>
public partial class PathContourHighlight : Control
{
    private Vector2[] _points = [];
    private Func<InteractionHighlightState> _resolve = null!;
    private InteractionHighlightState _state;
    private Transform2D _drawnTransform;
    private Texture2D? _background;
    private Rect2 _backgroundRect;

    public static PathContourHighlight AttachArtwork(Control source, Texture2D background,
        Rect2 backgroundRect, Vector2[] points, Func<InteractionHighlightState> state)
    {
        var contour = Attach(source, points, state);
        contour._background = background;
        contour._backgroundRect = backgroundRect;
        return contour;
    }

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
        Transform2D transform = InteractionHighlightPresentation.PixelTransform(this);
        if (_state == state && _drawnTransform == transform) return;
        _drawnTransform = transform;
        _state = state;
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_background is not null)
            BackgroundArtContour.Draw(this, _background, _points, _backgroundRect, _state, edgeSearchRadius: 0);
        else InteractionHighlightPresentation.DrawPath(this, _points, _state);
    }
}
