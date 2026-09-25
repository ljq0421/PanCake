using Godot;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private readonly Dictionary<(int State, int Ingredient), Texture2D> _stockArtwork = new();
    private readonly Dictionary<(Texture2D Background, int Ingredient), (Texture2D Texture, Rect2 Rect)> _stockBackings = new();
    internal bool StockArtworkReady => IngredientIds.Select((id, index) => (id, index)).All(item =>
        AllowedIngredients is not null && !AllowedIngredients.Contains(item.id)
        || _ingredients.VisualStockState(item.id) == 4 || _stockArtwork.ContainsKey((_ingredients.VisualStockState(item.id), item.index)));

    private void DrawIngredientStock()
    {
        if (_ingredients is null) return;
        Texture2D background = _art.WorkbenchBackground(_doupi is not null, BeefUnlocked);
        var changed = new List<(int Index, int State)>();
        for (int index = 0; index < IngredientIds.Length; index++)
        {
            string id = IngredientIds[index];
            if (AllowedIngredients is not null && !AllowedIngredients.Contains(id)) continue;
            int state = _ingredients.VisualStockState(id);
            if (state == 4) continue;
            changed.Add((index, state));
            if (!_stockBackings.TryGetValue((background, index), out var backing))
            {
                backing = BuildStockBacking(index, background, _art.WorkbenchBackground(false, false));
                _stockBackings[(background, index)] = backing;
            }
            DrawTextureRect(backing.Texture, backing.Rect, false);
        }
        // Complete, unwarped source artwork: no old spoon, bowl edge, or interior
        // is pasted over a different illustration. Each ingredient is independent.
        foreach (var (index, state) in changed)
        {
            if (!_stockArtwork.TryGetValue((state, index), out Texture2D? artwork))
            {
                artwork = BuildStockArtwork(index, state);
                _stockArtwork[(state, index)] = artwork;
            }
            Rect2 bounds = StockOutlineBounds(index);
            DrawTextureRect(artwork, new Rect2(WuhanWorkbenchLayout.Point(bounds.Position.X, bounds.Position.Y),
                bounds.Size * WuhanWorkbenchLayout.DesignSize / WuhanWorkbenchLayout.SourceSize), false);
        }
    }

    private static Rect2 StockOutlineBounds(int index)
    {
        Vector2[] outline = IngredientSilhouette(index);
        Vector2 min = new(outline.Min(p => p.X), outline.Min(p => p.Y));
        Vector2 max = new(outline.Max(p => p.X), outline.Max(p => p.Y));
        return new Rect2(min, max - min);
    }

    private static Texture2D BuildStockArtwork(int index, int state)
    {
        string name = state switch { 3 => "四分之三", 2 => "二分之一", 1 => "四分之一", _ => "空" };
        Texture2D sheet = GD.Load<Texture2D>($"res://resource/art/Wuhan/{name}.png");
        int column = index switch { 1 => 2, 2 => 1, _ => index };
        using Image image = sheet.GetImage();
        int left = Math.Max(0, image.GetWidth() * column / 4 - 14);
        int right = Math.Min(image.GetWidth(), image.GetWidth() * (column + 1) / 4 + 14);
        int top = 0, bottom = image.GetHeight();
        using Image crop = image.GetRegion(new Rect2I(left, top, right - left, bottom - top));
        crop.Convert(Image.Format.Rgba8);
        int width = crop.GetWidth(), height = crop.GetHeight();
        byte[] pixels = crop.GetData();
        var ink = new bool[width * height];
        var outside = new bool[ink.Length];
        var queue = new Queue<int>();
        for (int i = 0; i < ink.Length; i++)
            ink[i] = pixels[i * 4] < 75 && pixels[i * 4 + 1] < 75 && pixels[i * 4 + 2] < 75;
        int[] inkSum = StockMaskIntegral(ink, width, height);
        for (int y = 0; y < height; y++)
        for (int x = 0; x < width; x++)
            ink[y * width + x] = StockMaskSum(inkSum, width, Math.Max(0, x - 2), Math.Max(0, y - 2),
                Math.Min(width, x + 3), Math.Min(height, y + 3)) > 0;
        void Outside(int x, int y)
        {
            int p = y * width + x;
            if (outside[p] || ink[p]) return;
            outside[p] = true; queue.Enqueue(p);
        }
        // Seed every exposed boundary segment: tray lines divide the exterior
        // into disconnected areas that a corner-only flood cannot reach.
        for (int x = 0; x < width; x++) { Outside(x, 0); Outside(x, height - 1); }
        for (int y = 0; y < height; y++) { Outside(0, y); Outside(width - 1, y); }
        while (queue.Count > 0)
        {
            int p = queue.Dequeue(), x = p % width, y = p / width;
            if (x > 0) Outside(x - 1, y);
            if (x + 1 < width) Outside(x + 1, y);
            if (y > 0) Outside(x, y - 1);
            if (y + 1 < height) Outside(x, y + 1);
        }
        bool[] enclosed = outside.Select(value => !value).ToArray();
        int[] sum = StockMaskIntegral(enclosed, width, height);
        // Undo the two-pixel ink expansion used only to close outline gaps.
        // Keeping it in the final alpha includes a pale band of source tabletop.
        var tight = new bool[enclosed.Length];
        for (int y = 2; y < height - 2; y++)
        for (int x = 2; x < width - 2; x++)
            tight[y * width + x] = StockMaskSum(sum, width, x - 2, y - 2, x + 3, y + 3) == 25;
        var core = new bool[ink.Length];
        const int radius = 10;
        for (int y = radius; y < height - radius; y++)
        for (int x = radius; x < width - radius; x++)
            core[y * width + x] = StockMaskSum(sum, width, x - radius, y - radius, x + radius + 1, y + radius + 1) == (radius * 2 + 1) * (radius * 2 + 1);
        // Opening removes the tray's thin background ink, while the bowl and
        // the complete spoon remain one connected foreground component.
        bool[] foreground = LargestStockComponent(core, width, height);
        int[] foregroundSum = StockMaskIntegral(foreground, width, height);
        int opaque = 0;
        for (int y = 0; y < height; y++)
        for (int x = 0; x < width; x++)
        {
            int p = y * width + x;
            bool visible = tight[p] && StockMaskSum(foregroundSum, width,
                Math.Max(0, x - radius - 1), Math.Max(0, y - radius - 1),
                Math.Min(width, x + radius + 2), Math.Min(height, y + radius + 2)) > 0;
            pixels[p * 4 + 3] = visible ? (byte)255 : (byte)0;
            if (visible) opaque++;
        }
        if (opaque < width * height / 4) throw new InvalidOperationException($"Incomplete stock artwork: {name}/{index}");
        using Image masked = Image.CreateFromData(width, height, false, Image.Format.Rgba8, pixels);
        using Image trimmed = masked.GetRegion(masked.GetUsedRect());
        trimmed.FixAlphaEdges();
        if (trimmed.GetPixel(0, 0).A > 0 || trimmed.GetPixel(0, trimmed.GetHeight() - 1).A > 0)
            throw new InvalidOperationException($"Stock artwork includes its background: {name}/{index}");
        return ImageTexture.CreateFromImage(trimmed);
    }

    private static int[] StockMaskIntegral(bool[] mask, int width, int height)
    {
        var sum = new int[(width + 1) * (height + 1)];
        for (int y = 0; y < height; y++)
        {
            int row = 0;
            for (int x = 0; x < width; x++)
            {
                row += mask[y * width + x] ? 1 : 0;
                sum[(y + 1) * (width + 1) + x + 1] = sum[y * (width + 1) + x + 1] + row;
            }
        }
        return sum;
    }

    private static int StockMaskSum(int[] sum, int width, int left, int top, int right, int bottom)
        => sum[bottom * (width + 1) + right] - sum[top * (width + 1) + right]
            - sum[bottom * (width + 1) + left] + sum[top * (width + 1) + left];

    private static bool[] LargestStockComponent(bool[] core, int width, int height)
    {
        var visited = new bool[core.Length];
        var queue = new Queue<int>();
        var largest = new List<int>();
        for (int seed = 0; seed < core.Length; seed++)
        {
            if (!core[seed] || visited[seed]) continue;
            var component = new List<int>();
            visited[seed] = true; queue.Enqueue(seed);
            void Visit(int p) { if (!core[p] || visited[p]) return; visited[p] = true; queue.Enqueue(p); }
            while (queue.Count > 0)
            {
                int p = queue.Dequeue(), x = p % width, y = p / width;
                component.Add(p);
                if (x > 0) Visit(p - 1);
                if (x + 1 < width) Visit(p + 1);
                if (y > 0) Visit(p - width);
                if (y + 1 < height) Visit(p + width);
            }
            if (component.Count > largest.Count) largest = component;
        }
        var result = new bool[core.Length];
        foreach (int p in largest) result[p] = true;
        return result;
    }

    private static (Texture2D Texture, Rect2 Rect) BuildStockBacking(int index, Texture2D background, Texture2D cleanTable)
    {
        Vector2[] outline = IngredientSilhouette(index);
        Rect2 bowlBounds = StockOutlineBounds(index);
        Rect2 bounds = bowlBounds.Grow(12);
        bounds.Size += new Vector2(0, 18);
        var region = new Rect2I((int)MathF.Floor(bounds.Position.X), (int)MathF.Floor(bounds.Position.Y),
            (int)MathF.Ceiling(bounds.Size.X) + 1, (int)MathF.Ceiling(bounds.Size.Y) + 1);
        using Image table = cleanTable.GetImage();
        using Image original = background.GetImage();
        // Only erase this bowl. An opaque rectangular crop would repaint the
        // neighbouring bowl's old edge/handle when the rectangles overlap.
        using Image backing = Image.CreateFromData(region.Size.X, region.Size.Y, false, Image.Format.Rgba8,
            new byte[region.Size.X * region.Size.Y * 4]);
        for (int y = 0; y < region.Size.Y; y++)
        {
            var covered = new bool[region.Size.X];
            for (int x = 0; x < covered.Length; x++)
            {
                Vector2 p = new(region.Position.X + x, region.Position.Y + y);
                covered[x] = Geometry2D.IsPointInPolygon(p, outline);
                for (int edge = 0; !covered[x] && edge < outline.Length; edge++)
                    covered[x] = p.DistanceSquaredTo(Geometry2D.GetClosestPointToSegment(p,
                        outline[edge], outline[(edge + 1) % outline.Length])) <= 20.25f;
            }
            for (int x = 0; x < covered.Length; x++)
            {
                if (!covered[x]) continue;
                int start = x;
                while (x + 1 < covered.Length && covered[x + 1]) x++;
                int end = x;
                for (int fill = start; fill <= end; fill++)
                {
                    int globalY = region.Position.Y + y;
                    // Use clean tabletop below the tray, and local background
                    // interpolation where the spoon overlaps the tray/shadow.
                    Color color = table.GetPixel(1200, globalY);
                    if (globalY >= 760)
                    {
                        int globalX = region.Position.X + fill;
                        Color painted = original.GetPixel(globalX, globalY);
                        bool inside = Geometry2D.IsPointInPolygon(new Vector2(globalX, globalY), outline);
                        // Keep the original painted cast shadow. Where the new bowl
                        // is narrower, extend that same shadow up to its silhouette.
                        color = !inside && painted.R > .35f ? painted
                            : original.GetPixel((int)bowlBounds.GetCenter().X, (int)bowlBounds.End.Y + 7);
                    }
                    if (globalY < 720)
                    {
                        // Continue the local tray edge/shadow behind the handle;
                        // a distant flat table sample leaves a bright silhouette.
                        Color a = original.GetPixel(region.Position.X + start - 2, globalY);
                        Color b = original.GetPixel(region.Position.X + end + 2, globalY);
                        color = a.Lerp(b, (fill - start + 2f) / (end - start + 4f));
                    }
                    backing.SetPixel(fill, y, color);
                }
            }
        }
        backing.FixAlphaEdges();
        return (ImageTexture.CreateFromImage(backing), new Rect2(
            WuhanWorkbenchLayout.Point(region.Position.X, region.Position.Y),
            new Vector2(region.Size.X, region.Size.Y) * WuhanWorkbenchLayout.DesignSize / WuhanWorkbenchLayout.SourceSize));
    }
}
