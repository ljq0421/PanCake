using Godot;
using ProjectCake.Interaction;

namespace ProjectCake.UI;

public enum InteractionHighlightState { None, Hover, Selected, Eligible, Valid, Invalid, Attention }

/// <summary>Shared interaction colors and widths measured in rendered screen pixels.</summary>
public static class InteractionHighlightPresentation
{
    public static Color ColorFor(InteractionHighlightState state) => state switch
    {
        InteractionHighlightState.Hover => new Color("#FFE7A4"),
        InteractionHighlightState.Selected => new Color("#F2C567"),
        InteractionHighlightState.Eligible => new Color(.79f, .91f, .64f, .85f),
        InteractionHighlightState.Valid => new Color("#C5E5A1"),
        InteractionHighlightState.Invalid => new Color("#EC9B7F"),
        InteractionHighlightState.Attention => new Color("#F2C567"),
        _ => Colors.Transparent,
    };

    public static float WidthFor(InteractionHighlightState state) => state switch
    {
        InteractionHighlightState.None => 0,
        InteractionHighlightState.Valid or InteractionHighlightState.Invalid or InteractionHighlightState.Selected => 5f,
        _ => 4f,
    };

    public static Transform2D PixelTransform(CanvasItem canvas) =>
        canvas.GetViewportTransform() * canvas.GetGlobalTransform();

    public static float LocalWidthFor(CanvasItem canvas, InteractionHighlightState state)
    {
        Transform2D transform = PixelTransform(canvas);
        return WidthFor(state) / Math.Max(.001f, Math.Min(transform.X.Length(), transform.Y.Length()));
    }

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
        // Stroke in pixel space, including non-uniform canvas transforms. Mapping back
        // only the drawing transform leaves the artwork and input geometry untouched.
        Transform2D transform = PixelTransform(canvas);
        if (Mathf.IsZeroApprox(transform.Determinant())) return;
        Vector2[] pixels = points.Select(point => transform * point).ToArray();
        canvas.DrawSetTransformMatrix(transform.AffineInverse());
        Vector2[] line = closed ? [.. pixels, pixels[0]] : pixels;
        canvas.DrawPolyline(line, ColorFor(state), WidthFor(state), true);
        canvas.DrawSetTransformMatrix(Transform2D.Identity);
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
