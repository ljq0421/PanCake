using Godot;

namespace ProjectCake.UI;

/// <summary>Interaction outline for controls whose visible artwork is their authored rounded button.</summary>
public partial class ButtonContourHighlight : Control
{
    private Button _source = null!;
    private Func<InteractionHighlightState>? _state;
    private InteractionHighlightState _drawnState;
    private Vector2 _drawnSize;

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
        if (state == _drawnState && Size == _drawnSize) return;
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

    public static void DrawContour(CanvasItem canvas, StyleBoxFlat source, Rect2 rect, InteractionHighlightState state)
    {
        if (state == InteractionHighlightState.None) return;
        var outline = (StyleBoxFlat)source.Duplicate();
        int width = Math.Max(1, (int)MathF.Ceiling(InteractionHighlightPresentation.WidthFor(state)));
        outline.DrawCenter = false;
        outline.SetBorderWidthAll(width);
        outline.BorderColor = InteractionHighlightPresentation.ColorFor(state);
        outline.ShadowSize = 0;
        canvas.DrawStyleBox(outline, rect);
    }
}
