using Godot;

namespace ProjectCake.UI;

/// <summary>Raster silhouette dilation: no polygon simplification, joins, or internal mesh outlines.</summary>
public static class DrawnArtContour
{
    private const int Samples = 4;
    private readonly record struct Key(Texture2D Texture, Rect2I Region, int Width, int Height, int Stroke, bool Green);
    private static readonly Dictionary<Key, Texture2D> Cache = new();
    private static readonly Dictionary<string, (Texture2D Texture, Rect2 Bounds)> Polygons = new();

    public static void DrawPolygon(CanvasItem canvas, Vector2[] points, InteractionHighlightState state)
    {
        string key = string.Join(';', points.Select(p => $"{p.X:R},{p.Y:R}"));
        if (!Polygons.TryGetValue(key, out var mask))
        {
            Vector2 min = points.Aggregate((a, b) => a.Min(b)).Floor();
            Vector2 max = points.Aggregate((a, b) => a.Max(b)).Ceil();
            Rect2 bounds = new(min, max - min + Vector2.One);
            using Image image = Image.CreateEmpty((int)bounds.Size.X, (int)bounds.Size.Y, false, Image.Format.Rgba8);
            for (int y = 0; y < image.GetHeight(); y++)
            {
                float row = min.Y + y + .5f;
                var crossings = new List<float>();
                for (int i = 0; i < points.Length; i++)
                {
                    Vector2 a = points[i], b = points[(i + 1) % points.Length];
                    if ((a.Y > row) != (b.Y > row)) crossings.Add(a.X + (row - a.Y) * (b.X - a.X) / (b.Y - a.Y));
                }
                crossings.Sort();
                for (int i = 0; i + 1 < crossings.Count; i += 2)
                    for (int x = Math.Max(0, (int)MathF.Ceiling(crossings[i] - min.X - .5f));
                        x < Math.Min(image.GetWidth(), (int)MathF.Ceiling(crossings[i + 1] - min.X - .5f)); x++)
                        image.SetPixel(x, y, Colors.White);
            }
            if (Polygons.Count >= 96) Polygons.Clear();
            Polygons[key] = mask = (ImageTexture.CreateFromImage(image), bounds);
        }
        Draw(canvas, mask.Texture, mask.Bounds, state);
    }

    public static void Draw(CanvasItem canvas, Texture2D texture, Rect2 destination,
        InteractionHighlightState state, Rect2? source = null, bool keyGreen = false, Color? tint = null, Transform2D? drawingTransform = null)
    {
        float opacity = InteractionHighlightTheme.HoverOpacity(canvas, (texture.GetInstanceId(), destination, source), state);
        if (state == InteractionHighlightState.None || destination.Size.X <= 0 || destination.Size.Y <= 0) return;
        Transform2D transform = InteractionHighlightPresentation.PixelTransform(canvas) * (drawingTransform ?? Transform2D.Identity);
        float sx = transform.X.Length(), sy = transform.Y.Length();
        if (sx < .001f || sy < .001f) return;
        int width = Math.Max(1, (int)MathF.Ceiling(destination.Size.X * sx)) * Samples;
        int height = Math.Max(1, (int)MathF.Ceiling(destination.Size.Y * sy)) * Samples;
        int stroke = (int)InteractionHighlightPresentation.WidthFor(state, canvas) * Samples;
        Rect2I region = (Rect2I)(source ?? new Rect2(Vector2.Zero, texture.GetSize()));
        if (InteractionHighlightTheme.Applies(canvas, state))
            DrawLayer(stroke + Samples, InteractionHighlightTheme.BackingColor * new Color(1, 1, 1, opacity));
        DrawLayer(stroke, (tint ?? InteractionHighlightPresentation.ColorFor(state, canvas)) * new Color(1, 1, 1, opacity));

        void DrawLayer(int stroke, Color color)
        {
            var key = new Key(texture, region, width, height, stroke, keyGreen);
            if (!Cache.TryGetValue(key, out Texture2D? outline))
            {
                // Window resizing and moving cropped baskets must not retain unlimited raster sizes.
                if (Cache.Count >= 96) Cache.Clear();
                Cache[key] = outline = Build(key);
            }
            int pad = stroke + Samples;
            Vector2 margin = destination.Size * new Vector2((float)pad / width, (float)pad / height);
            canvas.DrawTextureRect(outline, new Rect2(destination.Position - margin, destination.Size + margin * 2),
                false, color);
        }
    }

    private static readonly Dictionary<Texture2D, Texture2D> GreenTextures = new();
    internal static Texture2D WithoutGreen(Texture2D texture)
    {
        if (GreenTextures.TryGetValue(texture, out var cached)) return cached;
        using Image image = texture.GetImage(); image.Convert(Image.Format.Rgba8); image.ClearMipmaps();
        RemoveGreen(image);
        return GreenTextures[texture] = ImageTexture.CreateFromImage(image);
    }
    private static void RemoveGreen(Image cropped)
    {
            byte[] rgba = cropped.GetData();
            for (int i = 0; i < rgba.Length; i += 4)
            {
                float excess = (rgba[i + 1] - Math.Max(rgba[i], rgba[i + 2])) / 255f;
                float t = Mathf.Clamp((excess - .08f) / .27f, 0, 1);
                rgba[i + 3] = (byte)(rgba[i + 3] * (1 - t * t * (3 - 2 * t)));
            }
            cropped.SetData(cropped.GetWidth(), cropped.GetHeight(), false, Image.Format.Rgba8, rgba);
    }

    private static Texture2D Build(Key key)
    {
        using Image original = key.Texture.GetImage();
        using Image cropped = original.GetRegion(key.Region);
        cropped.Convert(Image.Format.Rgba8);
        cropped.ClearMipmaps();
        if (key.Green)
        {
            RemoveGreen(cropped);
        }
        cropped.Resize(key.Width, key.Height, Image.Interpolation.Lanczos);
        byte[] pixels = cropped.GetData();
        int pad = key.Stroke + Samples, w = key.Width + pad * 2, h = key.Height + pad * 2;
        bool[] solid = new bool[w * h], outside = new bool[w * h], grown = new bool[w * h];
        for (int y = 0; y < key.Height; y++)
        for (int x = 0; x < key.Width; x++)
            solid[(y + pad) * w + x + pad] = pixels[(y * key.Width + x) * 4 + 3] >= 96;
        // Flood only the exterior. Holes in the filter mesh belong to the same silhouette.
        var queue = new Queue<int>(); queue.Enqueue(0); outside[0] = true;
        while (queue.TryDequeue(out int p))
        {
            int x = p % w, y = p / w;
            Visit(x - 1, y); Visit(x + 1, y); Visit(x, y - 1); Visit(x, y + 1);
            void Visit(int xx, int yy)
            {
                if (xx < 0 || xx >= w || yy < 0 || yy >= h) return;
                int i = yy * w + xx;
                if (outside[i] || solid[i]) return;
                outside[i] = true; queue.Enqueue(i);
            }
        }
        var disk = new List<(int X, int Y)>();
        for (int y = -key.Stroke; y <= key.Stroke; y++)
        for (int x = -key.Stroke; x <= key.Stroke; x++)
            if (x * x + y * y <= key.Stroke * key.Stroke) disk.Add((x, y));
        for (int y = 1; y < h - 1; y++)
        for (int x = 1; x < w - 1; x++)
        {
            int i = y * w + x;
            if (outside[i] || !(outside[i - 1] || outside[i + 1] || outside[i - w] || outside[i + w])) continue;
            foreach (var d in disk)
            {
                int xx = x + d.X, yy = y + d.Y;
                if (xx >= 0 && xx < w && yy >= 0 && yy < h) grown[yy * w + xx] = true;
            }
        }
        // Resolve subpixel coverage explicitly. Returning a binary mask at 2x
        // left stair steps whenever the scene inherited nearest filtering.
        int resolvedWidth = w / Samples, resolvedHeight = h / Samples;
        byte[] result = new byte[resolvedWidth * resolvedHeight * 4];
        for (int y = 0; y < resolvedHeight; y++)
        for (int x = 0; x < resolvedWidth; x++)
        {
            int coverage = 0;
            for (int yy = 0; yy < Samples; yy++)
            for (int xx = 0; xx < Samples; xx++)
            {
                int sample = (y * Samples + yy) * w + x * Samples + xx;
                if (grown[sample] && outside[sample]) coverage++;
            }
            int i = y * resolvedWidth + x;
            result[i * 4] = result[i * 4 + 1] = result[i * 4 + 2] = 255;
            result[i * 4 + 3] = (byte)((coverage * 255 + Samples * Samples / 2) / (Samples * Samples));
        }
        using var image = Image.CreateFromData(resolvedWidth, resolvedHeight, false, Image.Format.Rgba8, result);
        return ImageTexture.CreateFromImage(image);
    }
}
