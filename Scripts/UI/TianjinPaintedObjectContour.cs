using Godot;
using System.Globalization;
using System.Text;

namespace ProjectCake.UI;

internal enum TianjinPaintedObject { SoyTray, Trash, Pendant, Sauce }

/// <summary>Ink silhouettes shared by the visible highlight and pendant hit testing.</summary>
internal static class TianjinPaintedObjectContour
{
    internal sealed record Matte(Texture2D Texture, Image Pixels, Rect2 Bounds);
    private sealed record Part(float Threshold, Vector2[] Gate);
    private static readonly Dictionary<(Texture2D, TianjinPaintedObject), Matte> Cache = new();

    internal static Matte Get(Texture2D background, TianjinPaintedObject id)
    {
        if (Cache.TryGetValue((background, id), out Matte? matte)) return matte;
        Part[] parts = id switch
        {
            // The green bowl has its own silhouette, not a translated batter bowl.
            // Read its outer ink directly; the pale rim and cast shadow are not edges.
            TianjinPaintedObject.Sauce => [new(.42f, [new(1010,682), new(1055,689),
                new(1074,671), new(1085,669), new(1095,674), new(1097,685),
                new(1076,705), new(1090,719), new(1093,737), new(1085,776),
                new(1073,793), new(1053,805), new(1020,809), new(989,800),
                new(970,782), new(956,753), new(948,727), new(949,713),
                new(960,698), new(986,686)])],
            TianjinPaintedObject.SoyTray => [new(.42f, [new(1484,578), new(1585,578), new(1603,584),
                new(1612,597), new(1660,774), new(1662,790), new(1655,803), new(1636,809),
                new(1508,809), new(1493,802), new(1486,789), new(1460,601), new(1460,590), new(1470,582)])],
            TianjinPaintedObject.Trash => [new(.36f, [new(1020,839), new(1146,839), new(1154,845),
                new(1162,845), new(1167,851), new(1168,870), new(1161,878), new(1155,920),
                new(1149,934), new(1138,941), new(1030,941), new(1018,934), new(1011,920),
                new(1006,879), new(1000,875), new(1000,854), new(1006,845), new(1017,845)])],
            _ => [
                new(.30f, [new(1276,37), new(1288,36), new(1297,41), new(1301,50),
                    new(1297,60), new(1288,66), new(1276,65), new(1268,59), new(1266,49), new(1269,41)]),
                new(.30f, [new(1245,135), new(1307,137), new(1326,143), new(1331,160),
                    new(1343,183), new(1348,205), new(1347,224), new(1342,235), new(1338,240),
                    new(1334,245), new(1331,250), new(1324,252), new(1320,254), new(1315,256),
                    new(1307,258), new(1287,260), new(1271,260), new(1267,258), new(1259,256),
                    new(1248,252), new(1240,248), new(1231,240), new(1227,235), new(1220,225), new(1218,205),
                    new(1220,184), new(1230,164), new(1235,153), new(1235,145)]),
                new(.30f, [new(1275,67), new(1288,74), new(1277,102), new(1273,116),
                    new(1276,126), new(1273,135), new(1264,141), new(1251,138), new(1248,130),
                    new(1250,119), new(1257,112), new(1264,94), new(1270,81)]),
                new(.30f, [new(1292,52), new(1300,60), new(1298,74), new(1302,85),
                    new(1312,112), new(1318,118), new(1321,130), new(1320,140), new(1310,144),
                    new(1302,142), new(1298,133), new(1294,125), new(1294,117), new(1286,93), new(1280,81), new(1283,71)]),
                new(.32f, [new(1269,254), new(1289,255), new(1294,264), new(1293,275),
                    new(1287,281), new(1290,289), new(1296,314), new(1295,323), new(1285,327),
                    new(1265,326), new(1258,321), new(1261,303), new(1265,282), new(1262,274), new(1262,263)])],
        };
        Vector2 min = parts.SelectMany(p => p.Gate).Aggregate(new Vector2(float.MaxValue, float.MaxValue), (a,b) => a.Min(b)).Floor() - Vector2.One * 5;
        Vector2 max = parts.SelectMany(p => p.Gate).Aggregate(Vector2.Zero, (a,b) => a.Max(b)).Ceil() + Vector2.One * 5;
        max = max.Min(background.GetSize()); min = min.Max(Vector2.Zero);
        Rect2 bounds = new(min, max - min);
        using Image source = background.GetImage();
        var paths = new StringBuilder();
        foreach (Part part in parts)
        {
            var left = new List<Vector2>(); var right = new List<Vector2>();
            int top = Math.Max((int)min.Y, (int)part.Gate.Min(p => p.Y) - 2);
            int bottom = Math.Min((int)max.Y - 1, (int)part.Gate.Max(p => p.Y) + 2);
            for (int y = top; y <= bottom; y++)
            {
                float threshold = id == TianjinPaintedObject.Trash ? (y < 845 ? .42f : .26f) : part.Threshold;
                float scan = Math.Clamp(y + .5f, part.Gate.Min(p => p.Y) + .01f, part.Gate.Max(p => p.Y) - .01f);
                var crossings = new List<float>();
                for (int i = 0; i < part.Gate.Length; i++)
                {
                    Vector2 a = part.Gate[i], b = part.Gate[(i + 1) % part.Gate.Length];
                    if ((a.Y <= scan && b.Y > scan) || (b.Y <= scan && a.Y > scan))
                        crossings.Add(a.X + (scan - a.Y) / (b.Y - a.Y) * (b.X - a.X));
                }
                if (crossings.Count < 2) continue;
                int margin = id == TianjinPaintedObject.Pendant ? 1 : 4;
                int start = Math.Max((int)min.X, (int)MathF.Floor(crossings.Min()) - margin);
                int end = Math.Min((int)max.X - 1, (int)MathF.Ceiling(crossings.Max()) + margin);
                // The mounting bracket and the dark right edge of the post are
                // behind the pendant, not part of its pin, cords or pouch.
                if (id == TianjinPaintedObject.Pendant && y < 65) end = Math.Min(end, 1299);
                int first = -1, last = -1;
                for (int x = start; x <= end; x++)
                    if (Luma(x, y) < threshold) { if (first < 0) first = x; last = x; }
                if (first < 0) continue;
                float l = Crossing(first - 1, first, y, threshold);
                float r = Crossing(last, last + 1, y, threshold);
                left.Add(new(l, y + .5f)); right.Add(new(r, y + .5f));
            }
            if (left.Count < 2) continue;
            Smooth(left); Smooth(right);
            var polygon = left.Concat(right.AsEnumerable().Reverse()).ToArray();
            paths.Append("<path d='");
            for (int i = 0; i < polygon.Length; i++)
                paths.Append(i == 0 ? 'M' : 'L').Append((polygon[i].X - min.X).ToString("F3", CultureInfo.InvariantCulture))
                    .Append(' ').Append((polygon[i].Y - min.Y).ToString("F3", CultureInfo.InvariantCulture));
            paths.Append("Z' fill='white'/>");
        }
        var image = new Image();
        string svg = FormattableString.Invariant($"<svg xmlns='http://www.w3.org/2000/svg' width='{bounds.Size.X*4}' height='{bounds.Size.Y*4}' viewBox='0 0 {bounds.Size.X} {bounds.Size.Y}'>{paths}</svg>");
        if (image.LoadSvgFromString(svg) != Error.Ok) throw new InvalidOperationException("Cannot rasterize Tianjin ink silhouette");
        Cache[(background, id)] = matte = new(ImageTexture.CreateFromImage(image), image, bounds);
        return matte;

        float Luma(int x, int y)
        {
            Color p = source.GetPixel(Math.Clamp(x, 0, source.GetWidth() - 1), y);
            return p.R * .299f + p.G * .587f + p.B * .114f;
        }
        float Crossing(int a, int b, int y, float threshold)
        {
            float from = Luma(a, y), to = Luma(b, y);
            return a + .5f + (Math.Abs(to - from) < .001f ? .5f : Math.Clamp((threshold - from) / (to - from), 0, 1));
        }
        void Smooth(List<Vector2> edge)
        {
            Vector2[] original = edge.ToArray();
            for (int i = 1; i < edge.Count - 1; i++)
            {
                float x = (original[i - 1].X + original[i].X * 2 + original[i + 1].X) / 4;
                edge[i] = new(Math.Clamp(x, original[i].X - .5f, original[i].X + .5f), original[i].Y);
            }
        }
    }

    internal static void Draw(CanvasItem canvas, Texture2D background, TianjinPaintedObject id, InteractionHighlightState state, Vector2 origin = default)
    {
        Matte matte = Get(background, id);
        Rect2 rect = new(matte.Bounds.Position * TianjinWorkbenchLayout.SourceScale - origin,
            matte.Bounds.Size * TianjinWorkbenchLayout.SourceScale);
        DrawnArtContour.Draw(canvas, matte.Texture, rect, state);
    }
}

internal partial class TianjinPendantButton : Button
{
    internal bool IndependentArtwork { get; set; }
    internal Func<Texture2D> Background { get; set; } = null!;
    internal Func<Vector2, bool>? IsOccluded { get; set; }
    private TianjinPendantOutline _outline = null!;
    public override void _Ready()
    {
        _outline = new TianjinPendantOutline { Button = this, MouseFilter = MouseFilterEnum.Ignore,
            ZAsRelative = false, ZIndex = 20, TextureFilter = TextureFilterEnum.Linear };
        AddChild(_outline);
    }
    public override bool _HasPoint(Vector2 point)
    {
        if (IsOccluded?.Invoke(GetGlobalTransform() * point) == true) return false;
        var matte = TianjinPaintedObjectContour.Get(Background(), TianjinPaintedObject.Pendant);
        Vector2 pixel = ((point + Position) / TianjinWorkbenchLayout.SourceScale - matte.Bounds.Position) * 4;
        return new Rect2(Vector2.Zero, matte.Pixels.GetSize()).HasPoint(pixel)
            && matte.Pixels.GetPixel((int)pixel.X, (int)pixel.Y).A > .5f;
    }
    public override void _Process(double delta) => _outline.QueueRedraw();
}

internal partial class TianjinPendantOutline : Control
{
    internal TianjinPendantButton Button { get; set; } = null!;
    public override void _Draw()
    {
        if (!Button.IndependentArtwork && !Button.Disabled && (Button.IsHovered() || Button.HasFocus()))
            TianjinPaintedObjectContour.Draw(this, Button.Background(), TianjinPaintedObject.Pendant, InteractionHighlightState.Hover, Button.Position);
    }
}
