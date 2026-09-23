using Godot;

namespace ProjectCake.UI;

/// <summary>The finished tray's closed ink rim, isolated below the fryer feet.</summary>
internal static class TianjinYoutiaoTrayContour
{
    // Measured on both 1672 x 941 backgrounds. The shadow is outside the ink rim;
    // the fryer feet end above this crop and must never deform the tray highlight.
    internal static readonly Rect2I SourceBounds = new(16, 709, 373, 125);
    private static readonly Dictionary<Texture2D, Texture2D> Masks = new();

    public static void Draw(CanvasItem canvas, Texture2D background, InteractionHighlightState state)
    {
        if (!Masks.TryGetValue(background, out Texture2D? mask))
        {
            using Image pixels = background.GetImage();
            using Image silhouette = Extract(pixels);
            Masks[background] = mask = ImageTexture.CreateFromImage(silhouette);
        }
        Rect2I bounds = SourceBounds;
        DrawnArtContour.Draw(canvas, mask,
            TianjinWorkbenchLayout.FromSource(bounds.Position.X, bounds.Position.Y, bounds.Size.X, bounds.Size.Y), state);
    }

    internal static Image Extract(Image source)
    {
        int width = SourceBounds.Size.X, height = SourceBounds.Size.Y;
        byte[] rgba = new byte[width * height * 4];
        // The rim encloses one uninterrupted span on each scanline. Fill between
        // its actual left/right ink pixels, retaining the rounded corners and
        // front wall instead of fitting a spline or following the cast shadow.
        for (int y = 0; y < height; y++)
        {
            int first = width, last = -1;
            for (int x = 0; x < width; x++)
            {
                Color pixel = source.GetPixel(SourceBounds.Position.X + x, SourceBounds.Position.Y + y);
                float luma = pixel.R * .299f + pixel.G * .587f + pixel.B * .114f;
                if (luma >= .42f) continue;
                first = Math.Min(first, x);
                last = x;
            }
            for (int x = first; x <= last; x++)
            {
                int p = (y * width + x) * 4;
                rgba[p] = rgba[p + 1] = rgba[p + 2] = rgba[p + 3] = 255;
            }
        }
        return Image.CreateFromData(width, height, false, Image.Format.Rgba8, rgba);
    }
}
