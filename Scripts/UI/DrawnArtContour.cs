using Godot;

namespace ProjectCake.UI;

/// <summary>Cached alpha contours for sprites rendered directly by a CanvasItem.</summary>
public static class DrawnArtContour
{
    private static readonly Dictionary<(Texture2D Texture, Rect2I Region), Vector2[][]> Cache = new();

    public static void Draw(CanvasItem canvas, Texture2D texture, Rect2 destination,
        InteractionHighlightState state, Rect2? source = null)
    {
        if (state == InteractionHighlightState.None) return;
        Rect2I region = (Rect2I)(source ?? new Rect2(Vector2.Zero, texture.GetSize()));
        if (!Cache.TryGetValue((texture, region), out Vector2[][]? contours))
        {
            using Image original = texture.GetImage();
            using Image cropped = original.GetRegion(region);
            float scale = Math.Min(1, 512f / Math.Max(cropped.GetWidth(), cropped.GetHeight()));
            if (scale < 1) cropped.Resize(Math.Max(1, (int)(cropped.GetWidth() * scale)),
                Math.Max(1, (int)(cropped.GetHeight() * scale)), Image.Interpolation.Lanczos);
            using var mask = new Bitmap();
            mask.CreateFromImageAlpha(cropped, .25f);
            Vector2 size = new(cropped.GetWidth(), cropped.GetHeight());
            contours = mask.OpaqueToPolygons(new Rect2I(Vector2I.Zero, (Vector2I)size), .8f)
                .Where(path => path.Length >= 3)
                .Select(path => path.Select(point => point / size).ToArray()).ToArray();
            Cache[(texture, region)] = contours;
        }
        float outward = InteractionHighlightPresentation.WidthFor(state) * .55f;
        foreach (Vector2[] contour in contours)
        {
            Vector2[] points = contour.Select(point => destination.Position + point * destination.Size).ToArray();
            // Offset the centre of the stroke into the transparent pixels. The source art is untouched.
            foreach (Vector2[] outer in Geometry2D.OffsetPolygon(points, outward, Geometry2D.PolyJoinType.Round))
                InteractionHighlightPresentation.DrawPath(canvas, outer, state);
        }
    }
}
