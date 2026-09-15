using Godot;

namespace ProjectCake.UI;

/// <summary>Interaction outline for controls whose visible artwork is their authored rounded button.</summary>
public partial class ButtonContourHighlight : Control
{
    private Button _source = null!;
    private Func<InteractionHighlightState>? _state;
    private InteractionHighlightState _drawnState;
    private Vector2 _drawnSize;
    private Transform2D _drawnTransform;

    public static ButtonContourHighlight Attach(Button source, Func<InteractionHighlightState>? state = null)
    {
        RemoveBorders(source);
        var highlight = new ButtonContourHighlight
        {
            Name = "InteractionContour",
            MouseFilter = MouseFilterEnum.Ignore,
            _source = source,
            _state = state,
        };
        source.AddChild(highlight);
        highlight.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        return highlight;
    }

    public static void RemoveBorders(Button source)
    {
        foreach (string state in new[] { "normal", "hover", "pressed", "hover_pressed", "disabled", "focus" })
        {
            if (source.GetThemeStylebox(state) is not StyleBoxFlat original) continue;
            var style = (StyleBoxFlat)original.Duplicate();
            foreach (Side side in new[] { Side.Left, Side.Top, Side.Right, Side.Bottom })
                style.SetContentMargin(side, original.GetContentMargin(side));
            style.SetBorderWidthAll(0);
            style.ShadowSize = 0;
            if (state == "focus") style.BgColor = new Color(0.35f, 0.55f, 0.35f, 0.08f);
            source.AddThemeStyleboxOverride(state, style);
        }
    }

    public override void _Process(double delta)
    {
        var state = ResolveState();
        Transform2D transform = InteractionHighlightPresentation.PixelTransform(this);
        if (state == _drawnState && Size == _drawnSize && transform == _drawnTransform
            && !InteractionHighlightTheme.Applies(this, state)) return;
        _drawnTransform = transform;
        _drawnState = state;
        _drawnSize = Size;
        QueueRedraw();
    }

    public InteractionHighlightState ResolveState()
    {
        if (_source.Disabled || !_source.IsVisibleInTree()) return InteractionHighlightState.None;
        var state = _state?.Invoke() ?? InteractionHighlightState.None;
        if (state != InteractionHighlightState.None) return state;
        if (_source.IsPressed()) return InteractionHighlightState.Selected;
        return _source.IsHovered() || _source.HasFocus() ? InteractionHighlightState.Hover : InteractionHighlightState.None;
    }

    public override void _Draw()
    {
        var state = ResolveState();
        if (state == InteractionHighlightState.None || _source.GetThemeStylebox("normal") is not StyleBoxFlat source) return;
        DrawContour(this, source, new Rect2(Vector2.Zero, Size), state);
    }

    internal static Vector2[] ContourPoints(StyleBoxFlat source, Rect2 rect)
    {
            var points = new List<Vector2>();
            int[] radii = { source.CornerRadiusTopLeft, source.CornerRadiusTopRight,
                source.CornerRadiusBottomRight, source.CornerRadiusBottomLeft };
            for (int corner = 0; corner < 4; corner++)
            {
                float radius = Math.Min(radii[corner], Math.Min(rect.Size.X, rect.Size.Y) / 2);
                Vector2 center = corner switch {
                    0 => rect.Position + new Vector2(radius, radius),
                    1 => new Vector2(rect.End.X - radius, rect.Position.Y + radius),
                    2 => rect.End - new Vector2(radius, radius),
                    _ => new Vector2(rect.Position.X + radius, rect.End.Y - radius),
                };
                for (int i = 0; i <= 12; i++)
                    points.Add(center + Vector2.FromAngle(Mathf.Pi + corner * Mathf.Pi / 2 + i * Mathf.Pi / 24) * radius);
            }
        return points.ToArray();
    }

    public static void DrawContour(CanvasItem canvas, StyleBoxFlat source, Rect2 rect, InteractionHighlightState state)
    {
        if (state == InteractionHighlightState.None) return;
        if (InteractionHighlightTheme.Applies(canvas, state))
        {
            // Build the original rounded silhouette, then dilate only its exterior.
            DrawnArtContour.DrawPolygon(canvas, ContourPoints(source, rect), state);
            return;
        }
        var outline = (StyleBoxFlat)source.Duplicate();
        int width = Math.Max(1, (int)MathF.Round(InteractionHighlightPresentation.LocalWidthFor(canvas, state)));
        outline.DrawCenter = false;
        outline.SetBorderWidthAll(width);
        outline.BorderColor = InteractionHighlightPresentation.ColorFor(state);
        outline.ShadowSize = 0;
        canvas.DrawStyleBox(outline, rect);
    }
}
