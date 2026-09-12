using Godot;
using ProjectCake.Interaction;

namespace ProjectCake.UI;

public enum InteractionHighlightState { None, Hover, Selected, Eligible, Valid, Invalid, Attention }

/// <summary>Shared, quiet interaction colors on the artwork's own contour.</summary>
public static class InteractionHighlightPresentation
{
    public static Color ColorFor(InteractionHighlightState state) => state switch
    {
        InteractionHighlightState.Hover => new Color("#FFE7A4"),
        InteractionHighlightState.Selected => new Color("#F2C567"),
        InteractionHighlightState.Eligible => new Color(.79f, .91f, .64f, .62f),
        InteractionHighlightState.Valid => new Color("#C5E5A1"),
        InteractionHighlightState.Invalid => new Color("#EC9B7F"),
        InteractionHighlightState.Attention => new Color("#F2C567"),
        _ => Colors.Transparent,
    };

    public static float WidthFor(InteractionHighlightState state) => state switch
    {
        InteractionHighlightState.None => 0,
        InteractionHighlightState.Eligible => 1.5f,
        InteractionHighlightState.Valid or InteractionHighlightState.Selected => 2.5f,
        _ => 2f,
    };

    public static InteractionHighlightState FromDropZone(DropZoneVisualState state) => state switch
    {
        DropZoneVisualState.Eligible => InteractionHighlightState.Eligible,
        DropZoneVisualState.HoverValid => InteractionHighlightState.Valid,
        DropZoneVisualState.HoverInvalid => InteractionHighlightState.Invalid,
        _ => InteractionHighlightState.None,
    };

    public static void DrawPath(CanvasItem canvas, Vector2[] points, InteractionHighlightState state, bool closed = true)
    {
        if (state == InteractionHighlightState.None || points.Length < 2) return;
        Vector2[] line = closed ? [.. points, points[0]] : points;
        canvas.DrawPolyline(line, ColorFor(state), WidthFor(state), true);
    }

    public static void DrawEllipse(CanvasItem canvas, Rect2 rect, InteractionHighlightState state)
    {
        if (state == InteractionHighlightState.None) return;
        var points = new Vector2[64];
        for (int i = 0; i < points.Length; i++)
        {
            float angle = i * Mathf.Tau / points.Length;
            points[i] = rect.GetCenter() + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * rect.Size * .5f;
        }
        DrawPath(canvas, points, state);
    }
}
