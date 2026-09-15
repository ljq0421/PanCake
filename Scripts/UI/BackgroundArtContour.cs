using Godot;
using System.Globalization;
using System.Text;

namespace ProjectCake.UI;

/// <summary>Derives a dense silhouette matte from the painted outer ink edge.
/// Authored points only identify the object; they are not used as the rendered outline.</summary>
public static class BackgroundArtContour
{
    private sealed record Matte(Texture2D Texture, Rect2 Bounds);
    private sealed record Pixels(byte[] Data, int Width, int Height);
    private static readonly Dictionary<(Texture2D, string), Matte> Mattes = new();
    private static readonly Dictionary<Texture2D, Pixels> Images = new();

    public static void Draw(CanvasItem canvas, Texture2D background, Vector2[] guide,
        Rect2 backgroundRect, InteractionHighlightState state, bool preferDarkInk = false, int edgeSearchRadius = 10)
    {
        if (state == InteractionHighlightState.None || guide.Length < 3) return;
        var matte = Resolve(background, guide, backgroundRect, preferDarkInk, edgeSearchRadius);
        DrawnArtContour.Draw(canvas, matte.Texture, matte.Bounds, state);
    }

    internal static (Texture2D Texture, Rect2 Bounds) Resolve(Texture2D background, Vector2[] guide,
        Rect2 backgroundRect, bool preferDarkInk = false, int edgeSearchRadius = 10)
    {
        Vector2 imageSize = background.GetSize();
        Vector2[] source = guide.Select(p => (p - backgroundRect.Position) / backgroundRect.Size * imageSize).ToArray();
        string identity = string.Join(';', source.Select(p => $"{MathF.Round(p.X, 2).ToString(CultureInfo.InvariantCulture)},{MathF.Round(p.Y, 2).ToString(CultureInfo.InvariantCulture)}"));
        if (preferDarkInk) identity += ";dark-ink";
        identity += ";radius:" + edgeSearchRadius;
        if (!Mattes.TryGetValue((background, identity), out Matte? matte))
            Mattes[(background, identity)] = matte = Build(background, source, preferDarkInk, edgeSearchRadius);
        Vector2 scale = backgroundRect.Size / imageSize;
        return (matte.Texture, new Rect2(backgroundRect.Position + matte.Bounds.Position * scale, matte.Bounds.Size * scale));
    }

    private static Matte Build(Texture2D texture, Vector2[] guide, bool preferDarkInk, int edgeSearchRadius)
    {
        if (!Images.TryGetValue(texture, out Pixels? image))
        {
            using Image original = texture.GetImage(); original.Convert(Image.Format.Rgba8);
            Images[texture] = image = new Pixels(original.GetData(), original.GetWidth(), original.GetHeight());
        }
        var samples = new List<Vector2>();
        // A smooth search ribbon avoids bias towards the corners of the old guide polygon.
        for (int i = 0; i < guide.Length; i++)
        {
            Vector2 a = guide[(i + guide.Length - 1) % guide.Length], b = guide[i];
            Vector2 c = guide[(i + 1) % guide.Length], d = guide[(i + 2) % guide.Length];
            int steps = Math.Max(3, (int)MathF.Ceiling(b.DistanceTo(c) * 1.5f));
            for (int j = 0; j < steps; j++)
            {
                float t = (float)j / steps;
                // Tangents are capped at the local segment length around narrow spoon handles.
                Vector2 m0 = (c - a).LimitLength(b.DistanceTo(c)) * .5f;
                Vector2 m1 = (d - b).LimitLength(b.DistanceTo(c)) * .5f;
                samples.Add((2*t*t*t-3*t*t+1)*b + (t*t*t-2*t*t+t)*m0 +
                    (-2*t*t*t+3*t*t)*c + (t*t*t-t*t)*m1);
            }
        }
        Vector2[] points = samples.ToArray();
        float area = 0;
        for (int i = 0; i < points.Length; i++) area += points[i].Cross(points[(i + 1) % points.Length]);
        Vector2[] normals = new Vector2[points.Length];
        for (int i = 0; i < points.Length; i++)
        {
            Vector2 tangent = (points[(i + 2) % points.Length] - points[(i + points.Length - 2) % points.Length]).Normalized();
            normals[i] = new Vector2(tangent.Y, -tangent.X) * MathF.Sign(area);
        }
        int count = Math.Clamp(edgeSearchRadius, 0, 10) * 4 + 1; // Half-pixel intervals.
        float[,] scores = new float[points.Length, count];
        for (int i = 0; i < points.Length; i++)
        for (int k = 0; k < count; k++)
        {
            float offset = (k - count / 2) * .5f;
            Vector2 p = points[i] + normals[i] * offset;
            float inside = Luma(image, p - normals[i] * 1.5f), outside = Luma(image, p + normals[i] * 1.5f);
            // Seek the outside edge of the dark ink, not the pale rim inside the object.
            // A pale rim may have a stronger inner edge than its true outer edge
            // (especially under painted steam). Once an edge is credible, prefer
            // the outermost one instead of jumping between those two boundaries.
            float edge = Mathf.Clamp((outside - inside) / .12f, 0, 1);
            // Stay in the authored object's boundary band: a neighbouring tray can
            // also have a credible ink edge, but is not part of this silhouette.
            scores[i, k] = edge + offset * .025f - offset * offset * .012f
                - Math.Max(0, inside - .65f) * .2f;
            // Tianjin's pale trays cast a second, light-brown edge just outside
            // their ink. Favor the dark side of the ink transition over that shadow.
            if (preferDarkInk)
                // The calibrated tray guide is already on the ink. A wider search
                // can pick up fryer feet above the rack or the adjacent tray lip.
                scores[i, k] = Math.Abs(offset) > 2 ? -1000
                    : edge - offset * offset * .012f - Math.Max(0, inside - .32f) * 3f;
        }
        // Solve a continuous edge around three turns, retaining the middle one so the seam is continuous.
        int length = points.Length * 3;
        byte[,] previous = new byte[length, count];
        float[] costs = new float[count], next = new float[count];
        for (int i = 0; i < length; i++)
        {
            int row = i % points.Length;
            for (int k = 0; k < count; k++)
            {
                float best = float.NegativeInfinity; int from = k;
                for (int j = Math.Max(0, k - 3); j <= Math.Min(count - 1, k + 3); j++)
                {
                    float candidate = costs[j] - .075f * (j-k) * (j-k);
                    if (candidate > best) { best = candidate; from = j; }
                }
                next[k] = best + scores[row, k]; previous[i, k] = (byte)from;
            }
            (costs, next) = (next, costs);
        }
        int at = Array.IndexOf(costs, costs.Max());
        var offsets = new float[length];
        for (int i = length - 1; i >= 0; i--) { offsets[i] = (at - count/2) * .5f; at = previous[i, at]; }
        for (int i = 0; i < points.Length; i++)
        {
            int n = i + points.Length;
            float offset = (offsets[n-1] + offsets[n]*2 + offsets[n+1]) / 4;
            points[i] += normals[i] * offset;
        }
        // Remove sampling noise along a single ink edge before rasterization.
        // This operates on the subpixel trace, not on the coarse authored polygon.
        Vector2[] traced = (Vector2[])points.Clone();
        for (int i = 0; i < points.Length; i++)
        {
            Vector2 sum = Vector2.Zero; float weight = 0;
            for (int j = -6; j <= 6; j++)
            {
                float w = 7 - Math.Abs(j);
                sum += traced[(i + j + points.Length) % points.Length] * w; weight += w;
            }
            points[i] = sum / weight;
        }
        Vector2 min = points.Aggregate(new Vector2(float.MaxValue, float.MaxValue), (a,p) => a.Min(p)).Floor() - Vector2.One * 2;
        Vector2 max = points.Aggregate(new Vector2(float.MinValue, float.MinValue), (a,p) => a.Max(p)).Ceil() + Vector2.One * 2;
        Rect2 bounds = new(min, max - min);
        var path = new StringBuilder();
        foreach (Vector2 point in points) path.Append(path.Length == 0 ? 'M' : 'L').Append((point.X-min.X).ToString("F2", CultureInfo.InvariantCulture))
            .Append(' ').Append((point.Y-min.Y).ToString("F2", CultureInfo.InvariantCulture));
        path.Append('Z');
        string svg = FormattableString.Invariant($"<svg xmlns='http://www.w3.org/2000/svg' width='{bounds.Size.X*2}' height='{bounds.Size.Y*2}' viewBox='0 0 {bounds.Size.X} {bounds.Size.Y}'><path d='{path}' fill='white'/></svg>");
        using var mask = new Image();
        if (mask.LoadSvgFromString(svg) != Error.Ok) throw new InvalidOperationException("Unable to rasterize artwork silhouette");
        return new Matte(ImageTexture.CreateFromImage(mask), bounds);
    }

    private static float Luma(Pixels image, Vector2 point)
    {
        float x = Math.Clamp(point.X, 0, image.Width - 1.001f), y = Math.Clamp(point.Y, 0, image.Height - 1.001f);
        int ix = (int)x, iy = (int)y;
        float Pixel(int xx, int yy)
        {
            int p = (yy * image.Width + xx) * 4;
            return (image.Data[p] * .299f + image.Data[p+1] * .587f + image.Data[p+2] * .114f) / 255;
        }
        return Mathf.Lerp(Mathf.Lerp(Pixel(ix,iy), Pixel(ix+1,iy), x-ix),
            Mathf.Lerp(Pixel(ix,iy+1), Pixel(ix+1,iy+1), x-ix), y-iy);
    }
}
