using Godot;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private Vector2[] PanCorners => _layout.PanCorners;
    // Each illustration already has perspective. Sample its trapezoid, not its
    // rectangular canvas, so the shared pan mesh does not apply perspective twice.
    private static Vector2[] DoupiSource(string id, Rect2 region)
    {
        Vector2[] source = id switch
        {
            "doupi_egg" => SourceQuad(1254, 1254, 102, 350, 1158, 350, 1236, 892, 20, 892),
            "doupi_filling_overlay" => SourceQuad(1254, 1254, 98, 390, 1160, 390, 1234, 870, 22, 870),
            "doupi_filling_cooked" => SourceQuad(1774, 887, 120, 130, 1650, 130, 1754, 817, 18, 817),
            "doupi_burnt" => RectQuad(new Rect2(.04f, .075f, .93f, .85f)),
            _ => SourceQuad(1536, 1024, 122, 250, 1410, 250, 1502, 831, 34, 831),
        };
        return QuadRegion(source, region);
    }
    private static Vector2[] SourceQuad(float width, float height, params float[] points) =>
        Enumerable.Range(0, 4).Select(i => new Vector2(points[i * 2] / width, points[i * 2 + 1] / height)).ToArray();
    private static float Smooth(float p) { p = Mathf.Clamp(p, 0, 1); return p * p * (3 - 2 * p); }
    private static float Phase(float p, float start, float end) => Smooth((p - start) / (end - start));
    private static Vector2 QuadPoint(Vector2[] q, float x, float y) => q[0].Lerp(q[1], x).Lerp(q[3].Lerp(q[2], x), y);
    private static Vector2[] QuadRegion(Vector2[] q, Rect2 region) => new[] {
        QuadPoint(q, region.Position.X, region.Position.Y), QuadPoint(q, region.End.X, region.Position.Y),
        QuadPoint(q, region.End.X, region.End.Y), QuadPoint(q, region.Position.X, region.End.Y) };
    private static Rect2 PieceRegion(int tile) => new((tile % 4) / 4f, (tile / 4) / 2f, .25f, .5f);
    private static Vector2[] RectQuad(Rect2 r) => new[] { r.Position, new Vector2(r.End.X, r.Position.Y), r.End, new Vector2(r.Position.X, r.End.Y) };

    private void SurfaceLayer(string id, Vector2[] quad, Color tint, Rect2? region = null, CanvasItem? canvas = null)
    {
        if (tint.A <= 0) return;
        // Use exactly the same mesh before/after cutting. A single triangulated
        // trapezoid would shift the texture when replaced by eight smaller quads.
        if (region is null)
        {
            for (int tile = 0; tile < 8; tile++)
                SurfaceLayer(id, QuadRegion(quad, PieceRegion(tile)), tint, PieceRegion(tile), canvas);
            return;
        }
        Texture2D texture = _art.Texture(id);
        Vector2[] source = DoupiSource(id, region ?? new Rect2(0, 0, 1, 1));
        (canvas ?? this).DrawPolygon(quad, new[] { tint }, source, texture);
    }

    private void DrawBurntDoupi(CanvasItem canvas, Vector2[] quad, bool hasFilling)
    {
        SurfaceLayer(hasFilling ? "doupi_filling_cooked" : "doupi_egg", quad, new Color(.66f, .43f, .24f), canvas: canvas);
        SurfaceLayer("doupi_burnt", quad, new Color(.60f, .43f, .28f), canvas: canvas);
        Vector2[] rim = { quad[3], quad[2], QuadPoint(quad, 1, .94f), QuadPoint(quad, 0, .94f) };
        canvas.DrawColoredPolygon(rim, new Color(.19f, .10f, .04f, .85f));
    }

    private Control CreateBurntDoupiPreview(bool hasFilling, Vector2 size)
    {
        var preview = new Control { Name = "BurntDoupiPreview", MouseFilter = MouseFilterEnum.Ignore, CustomMinimumSize = size };
        Vector2[] corners = PanCorners;
        Vector2 min = new(corners.Min(p => p.X), corners.Min(p => p.Y));
        Vector2 extent = new(corners.Max(p => p.X) - min.X, corners.Max(p => p.Y) - min.Y);
        float scale = Math.Min((size.X - 8) / extent.X, (size.Y - 8) / extent.Y);
        Vector2 offset = (size - extent * scale) / 2;
        Vector2[] quad = corners.Select(p => (p - min) * scale + offset).ToArray();
        preview.Draw += () => DrawBurntDoupi(preview, quad, hasFilling);
        return preview;
    }
    private Control CreateDoupiPiecePreview(DoupiInventory.Piece piece)
    {
        var preview = new Control { Name = "DoupiPiecePreview", MouseFilter = MouseFilterEnum.Ignore, CustomMinimumSize = new Vector2(100, 60), TextureFilter = TextureFilterEnum.LinearWithMipmaps };
        preview.Draw += () => DrawStockPiece(piece.Tile, FitDoupiPieceQuad(piece.Tile, new Rect2(0, 0, 100, 60)), piece.Quality, canvas: preview);
        return preview;
    }
    private Vector2[] FitDoupiPieceQuad(int tile, Rect2 bounds)
    {
        // These cut-piece sprites already include perspective, outline and depth.
        // Preserve the complete illustration with one uniform scale.
        Vector2 size = _art.DoupiPiece(tile).GetSize();
        float scale = Math.Min(bounds.Size.X / size.X, bounds.Size.Y / size.Y);
        Vector2 origin = bounds.GetCenter() - size * scale / 2;
        return RectQuad(new Rect2(origin, size * scale));
    }
    private void DrawStockPiece(int tile, Vector2[] quad, DoupiQuality quality, float alpha = 1, CanvasItem? canvas = null)
    {
        if (alpha <= 0) return;
        Color tint = quality switch
        {
            DoupiQuality.Overbrowned => new Color(.78f, .60f, .39f, alpha),
            DoupiQuality.Burnt => new Color(.35f, .23f, .14f, alpha),
            _ => new Color(1, 1, 1, alpha),
        };
        // Tint the sprite itself so darker food keeps its natural transparent edge.
        (canvas ?? this).DrawPolygon(quad, new[] { tint }, RectQuad(new Rect2(0, 0, 1, 1)), _art.DoupiPiece(tile));
    }
    private Control CreatePanDoupiPreview(Vector2 size)
    {
        var preview = new Control { Name = "PanDoupiPreview", MouseFilter = MouseFilterEnum.Ignore, CustomMinimumSize = size };
        Vector2[] corners = PanCorners;
        Vector2 min = new(corners.Min(p => p.X), corners.Min(p => p.Y));
        Vector2 extent = new(corners.Max(p => p.X) - min.X, corners.Max(p => p.Y) - min.Y);
        float scale = Math.Min((size.X - 8) / extent.X, (size.Y - 8) / extent.Y);
        Vector2 offset = (size - extent * scale) / 2;
        Vector2[] quad = corners.Select(p => (p - min) * scale + offset).ToArray();
        preview.Draw += () =>
        {
            if (_doupi is null) return;
            DoupiState state = _doupi.State;
            if (state == DoupiState.Burnt) DrawBurntDoupi(preview, quad, _doupi.Coverage > 0);
            else if (state == DoupiState.Cut)
                for (int i = _doupi.FirstRemainingPiece; i < _doupi.FirstRemainingPiece + _doupi.RemainingPieces; i++)
                    DrawPiece(i, QuadRegion(quad, PieceRegion(i)), _doupi.Quality, canvas: preview);
            else if (state is DoupiState.SecondCooking or DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting)
                FilledSurface(quad, _doupi.BrowningProgress, quality: _doupi.Quality, canvas: preview);
            else
            {
                SurfaceLayer(state == DoupiState.Batter ? "doupi_skin" : "doupi_egg", quad, Colors.White, canvas: preview);
                if (state == DoupiState.Spreading) DrawSpreading(quad, preview);
            }
            if (state == DoupiState.Cutting)
                foreach (DoupiCutLine line in _doupi.CutLines)
                {
                    int index = (int)line;
                    Vector2 a = index < 3 ? QuadPoint(quad, (index + 1) / 4f, 0) : QuadPoint(quad, 0, .5f);
                    Vector2 b = index < 3 ? QuadPoint(quad, (index + 1) / 4f, 1) : QuadPoint(quad, 1, .5f);
                    preview.DrawLine(a, b, new Color("#744625"), 2, true);
                }
        };
        return preview;
    }
    private void FilledSurface(Vector2[] quad, float browning, float alpha = 1, Rect2? region = null, DoupiQuality quality = DoupiQuality.Normal, CanvasItem? canvas = null)
    {
        float cooked = Smooth(browning);
        if (cooked < 1) SurfaceLayer("doupi_filling_overlay", quad, new Color(1, 1, 1, alpha), region, canvas);
        if (cooked > 0) SurfaceLayer("doupi_filling_cooked", quad, new Color(1, 1, 1, alpha * cooked), region, canvas);
        if (quality != DoupiQuality.Normal)
            SurfaceLayer("doupi_burnt", quad, new Color(1, 1, 1, alpha * (quality == DoupiQuality.Burnt ? 1 : .3f)), region, canvas);
    }
    private void DrawPiece(int tile, Vector2[] quad, DoupiQuality quality, float alpha = 1, CanvasItem? canvas = null)
    {
        canvas ??= this;
        Vector2 depth = new(0, 3);
        canvas.DrawColoredPolygon(new[] { quad[3], quad[2], quad[2] + depth, quad[3] + depth }, new Color(.58f, .30f, .10f, alpha));
        FilledSurface(quad, 1, alpha, PieceRegion(tile), quality, canvas);
        canvas.DrawPolyline(new[] { quad[0], quad[1], quad[2], quad[3], quad[0] }, new Color(.52f, .30f, .10f, .7f * alpha), 1, true);
    }
    private Vector2[] PanPiece(int tile) => QuadRegion(PanCorners, PieceRegion(tile));
    private Rect2 StockItemRect(int index)
    {
        int slot = index % 8, layer = index / 8;
        Rect2 tray = _layout.StockFood;
        // Fill most of the serving area with a compact group. The front row
        // slightly overlaps the back row; food still keeps its source proportions.
        Vector2 center = tray.GetCenter() + new Vector2((slot % 4 - 1.5f) * 73, (slot / 4 - .5f) * 32 + 1);
        center += new Vector2(layer * 1.5f, -layer * 5);
        return At(center, new Vector2(70, 50));
    }
    private void DrawDoupiStock(Motion? motion)
    {
        // Finish both layers of the back row before drawing the front row.
        // Incoming pieces use this same order, so they do not change depth on landing.
        for (int row = 0; row < 2; row++)
        for (int i = 0; i < _stock.Count; i++)
        {
            if (i % 8 / 4 != row) continue;
            DoupiInventory.Piece piece = _stock.PieceAt(i);
            Vector2[] target = FitDoupiPieceQuad(piece.Tile, StockItemRect(i));
            if (motion?.Kind != "stock" || i < motion.StockStart || i >= motion.StockStart + motion.Amount)
            {
                DrawStockPiece(piece.Tile, target, piece.Quality);
                continue;
            }
            float t = Smooth(motion.Progress);
            Vector2[] source = PanPiece(piece.Tile);
            if (ReducedMotion)
            {
                DrawPiece(piece.Tile, source, piece.Quality, 1 - t);
                DrawStockPiece(piece.Tile, target, piece.Quality, t);
            }
            else
            {
                Vector2[] quad = source.Select((v, j) => v.Lerp(target[j], t) - new Vector2(0, Mathf.Sin(t * Mathf.Pi) * 24)).ToArray();
                float reveal = Phase(motion.Progress, .08f, .48f);
                if (reveal < 1) DrawPiece(piece.Tile, quad, piece.Quality, 1 - reveal);
                DrawStockPiece(piece.Tile, quad, piece.Quality, reveal);
            }
        }
    }
    private void DrawDoupi()
    {
        if (_doupi is null) return;
        DrawDoupiIngredients();
        Motion? motion = Find("pan");
        DoupiState state = _doupi.State;
        float p = motion?.Progress ?? 1;
        if (motion?.Kind == "discard")
            FilledSurface(PanCorners, 1, 1 - Smooth(p), quality: DoupiQuality.Burnt);
        if (state == DoupiState.Cut)
        {
            // Keep the final cutting stroke on the intact surface until it finishes.
            if (motion?.Kind == "cut") FilledSurface(PanCorners, 1, quality: _doupi.Quality);
            else for (int i = _doupi.FirstRemainingPiece; i < _doupi.FirstRemainingPiece + _doupi.RemainingPieces; i++)
                DrawPiece(i, PanPiece(i), _doupi.Quality);
        }
        else if (state != DoupiState.Empty)
        {
            Vector2[] quad = PanCorners;
            float deposit = Phase(p, .35f, .80f);
            if (motion?.Kind == "flip" && !ReducedMotion)
            {
                float turn = Phase(p, .18f, .82f);
                float squash = Mathf.Abs(Mathf.Cos(turn * Mathf.Pi));
                // Preserve the food/tool relationship throughout lift and landing.
                float lift = Mathf.Sin(Smooth(p) * Mathf.Pi) * 36;
                quad = quad.Select(v => PanCenter + (v - PanCenter) * new Vector2(1, squash) - new Vector2(0, lift)).ToArray();
            }
            float heldLift = _gesture == "flip" && state == DoupiState.ReadyToFlip ? _flipLift : 0;
            if (motion?.Kind == "flip_return") heldLift = motion.Lift * (1 - Smooth(p));
            if (motion?.Kind == "flip") heldLift = motion.Lift * (1 - Phase(p, 0, .4f));
            if (heldLift > 0 && !ReducedMotion)
            {
                quad = (Vector2[])quad.Clone();
                quad[2] -= new Vector2(0, 24 * heldLift); quad[3] -= new Vector2(0, 24 * heldLift);
            }
            float alpha = motion?.Kind == "batter" ? deposit : 1;
            if (motion?.Kind == "batter" && !ReducedMotion)
                quad = quad.Select(v => PanCenter + (v - PanCenter) * (.85f + .15f * deposit)).ToArray();
            if (state is DoupiState.Batter || motion?.Kind == "egg")
                SurfaceLayer("doupi_skin", quad, new Color(1, 1, 1, alpha));
            if (state is DoupiState.SkinCooking or DoupiState.ReadyToFlip or DoupiState.Flipped or DoupiState.Spreading)
            {
                if (motion?.Kind == "egg" && !ReducedMotion) DrawEggSurface(quad, p);
                else SurfaceLayer("doupi_egg", quad, new Color(1, 1, 1, motion?.Kind == "egg" ? Smooth(p) : 1));
            }
            if (state == DoupiState.Spreading) DrawSpreading(quad);
            if (state is DoupiState.SecondCooking or DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting)
                FilledSurface(quad, _doupi.BrowningProgress, motion?.Kind == "filling" ? deposit : 1, quality: _doupi.Quality);
            if (state == DoupiState.Burnt)
            {
                DrawBurntDoupi(this, quad, _doupi.Coverage > 0);
            }
            if (state is DoupiState.SkinCooking or DoupiState.ReadyToFlip)
            {
                float cooked = Smooth(_doupi.SkinCookProgress);
                // A narrow golden crust follows the food's edge, not the pan's hit box.
                Vector2[] rim = { quad[3], quad[2], QuadPoint(quad, 1, .95f), QuadPoint(quad, 0, .95f) };
                DrawColoredPolygon(rim, new Color(.83f, .53f, .19f, cooked * .75f));
                if (state == DoupiState.ReadyToFlip && heldLift == 0)
                {
                    Vector2 lift = new(0, -4);
                    DrawColoredPolygon(new[] { quad[3], quad[2], quad[2] + lift, quad[3] + lift }, new Color(.90f, .66f, .29f, .85f));
                }
            }
            if (_doupi.HeatStress > 0 && state != DoupiState.Burnt)
            {
                Vector2[] rim = { quad[3], quad[2], QuadPoint(quad, 1, .93f), QuadPoint(quad, 0, .93f) };
                DrawColoredPolygon(rim, new Color(.24f, .12f, .055f, _doupi.HeatStress * .8f));
            }
        }
        if (state != DoupiState.Empty)
        {
            foreach (DoupiCutLine line in _doupi.CutLines)
                if (state != DoupiState.Cut || motion?.Kind == "cut") DrawCut((int)line, 1);
            if (_gesture == "cut" && state is (DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting))
                foreach (DoupiCutLine line in Enum.GetValues<DoupiCutLine>())
                {
                    if (_doupi.CutLines.Contains(line)) continue;
                    var (from, to) = CutLine((int)line);
                    DrawDashedLine(from, to, new Color(1, .96f, .8f, .32f), 1.5f, 9, true);
                }
            if (state is DoupiState.SkinCooking or DoupiState.SecondCooking or DoupiState.ReadyToFlip or DoupiState.ReadyToCut)
                Steam(PanCenter + new Vector2(0, -30), .7f);
        }
        if (state is (DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting) && _gesture != "cut" && !Busy("pan"))
        {
            Rect2 tool = At(new Vector2(PanRect.End.X - 28, PanRect.End.Y - 30), new Vector2(110, 73));
            Sprite("cut_tool", tool); HighlightTool("cut_tool", tool);
        }
        if (state == DoupiState.Burnt && !ReducedMotion)
        {
            for (int i = 0; i < 3; i++)
            {
                float t = Mathf.PosMod(_phase * .35f + i / 3f, 1);
                Vector2 center = PanCenter + new Vector2((i - 1) * 24 + Mathf.Sin(t * 4 + i) * 8, -18 - t * 55);
                Ellipse(center, new Vector2(9 + t * 6, 5 + t * 4), new Color(.24f, .22f, .20f, (1 - t) * .22f));
            }
        }
        DrawDoupiStock(motion);
        if (motion is not null && motion.Kind != "stock") DrawPanMotion(motion);
    }
    private void DrawDoupiIngredients()
    {
        if (_gesture != "batter" && (ReducedMotion || Find("pan")?.Kind != "batter"))
            Sprite("doupi_ladle", _layout.BatterLadle);
        // Egg liquid and its tray are painted into the sheet. The spoon is the only overlay.
        if (ReducedMotion || Find("pan")?.Kind != "egg")
            Sprite("egg_ladle", _layout.DoupiEggFood);
    }

    private void DrawSpreading(Vector2[] quad, CanvasItem? canvas = null)
    {
        const int width = DoupiInteraction.CoverageWidth, height = DoupiInteraction.CoverageHeight;
        float Alpha(int x, int y)
        {
            float sum = 0;
            for (int dy = -1; dy <= 0; dy++) for (int dx = -1; dx <= 0; dx++)
                if (_doupi!.IsCovered(Math.Clamp(x + dx, 0, width - 1), Math.Clamp(y + dy, 0, height - 1))) sum += .25f;
            return sum;
        }
        Texture2D texture = _art.Texture("doupi_filling_overlay");
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
        {
            Color[] colors = { new(1, 1, 1, Alpha(x, y)), new(1, 1, 1, Alpha(x + 1, y)),
                new(1, 1, 1, Alpha(x + 1, y + 1)), new(1, 1, 1, Alpha(x, y + 1)) };
            if (colors.All(c => c.A == 0)) continue;
            Rect2 region = new((float)x / width, (float)y / height, 1f / width, 1f / height);
            (canvas ?? this).DrawPolygon(QuadRegion(quad, region), colors, DoupiSource("doupi_filling_overlay", region), texture);
        }
    }
    private (Vector2 From, Vector2 To) CutLine(int index)
    {
        Vector2[] c = PanCorners;
        return index < 3 ? (c[0].Lerp(c[1], (index + 1) / 4f), c[3].Lerp(c[2], (index + 1) / 4f))
            : (c[0].Lerp(c[3], .5f), c[1].Lerp(c[2], .5f));
    }
    private void DrawCut(int index, float progress)
    {
        if (progress <= 0) return;
        var (from, to) = CutLine(index);
        DrawLine(from, from.Lerp(to, progress), new Color("#744625"), 3, true);
    }
    private void DrawPanMotion(Motion m)
    {
        float p = m.Progress;
        if (ReducedMotion) return;
        float toolAlpha = Phase(p, 0, .12f) * (1 - Phase(p, .85f, 1));
        if (m.Kind is "flip" or "cut")
        {
            Vector2 center;
            if (m.Kind == "cut")
            {
                var (from, to) = CutLine((int)m.Line);
                center = (m.Origin ?? to) - new Vector2(0, 10 * Smooth(p));
            }
            else center = PanCenter + new Vector2(35, -Mathf.Sin(Smooth(p) * Mathf.Pi) * 36);
            Sprite(m.Kind == "cut" ? "cut_tool" : "flip_tool", At(center + new Vector2(30, -23), new Vector2(138, 91)), toolAlpha,
                m.Kind == "flip" ? -Mathf.Sin(Smooth(p) * Mathf.Pi) * .4f : 0);
        }
        else if (m.Kind == "egg") DrawEggMotion(m);
        else if (m.Kind is "batter" or "filling")
        {
            Vector2 start = m.Origin ?? (m.Kind == "filling" ? FillingRect : BatterRect).GetCenter();
            Vector2 above = PanCenter + new Vector2(0, -60);
            float travel = Phase(p, 0, .35f), retreat = Phase(p, .8f, 1);
            Vector2 center = start.Lerp(above, travel).Lerp(start, retreat);
            Sprite("doupi_ladle", At(center, new Vector2(90, 90)), toolAlpha);
            float stream = Phase(p, .3f, .42f) * (1 - Phase(p, .65f, .8f));
            if (stream > 0) DrawLine(center + new Vector2(0, 12), PanCenter,
                new Color(new Color("#EACD8C"), stream), 5, true);
        }
    }

    // One accepted egg action: scoop, carry, pour, return and one automatic spatula sweep.
    // Cooking continues on the existing clock while these presentation phases play.
    private void DrawEggSurface(Vector2[] quad, float p)
    {
        float landed = Phase(p, .30f, .48f), spread = Phase(p, .48f, .88f);
        Vector2 center = QuadPoint(quad, .5f, .5f);
        Ellipse(center, new Vector2(25, 10) * (.7f + landed * .3f),
            new Color(1, .78f, .22f, landed * (1 - spread)));
        if (spread > 0)
        {
            // Reveal the final texture behind the tool without stretching the food art.
            const int strips = 32;
            for (int i = 0; i < strips; i++)
            {
                Rect2 region = new(i / (float)strips, 0, 1f / strips, 1);
                float alpha = Smooth((spread * 1.08f - region.Position.X) / .08f);
                SurfaceLayer("doupi_egg", QuadRegion(quad, region), new Color(1, 1, 1, alpha), region);
            }
        }
    }

    private void DrawEggMotion(Motion m)
    {
        float p = m.Progress;
        Vector2 above = PanCenter + new Vector2(0, -58);
        Vector2 home = _layout.DoupiEggFood.GetCenter();
        float carry = Phase(p, .08f, .28f), retreat = Phase(p, .52f, .86f);
        Vector2 center = home.Lerp(above, carry).Lerp(home, retreat);
        center.Y += 5 * Mathf.Sin(Phase(p, 0, .08f) * Mathf.Pi);
        float tilt = -.42f * Phase(p, .28f, .36f) * (1 - Phase(p, .48f, .58f));
        Sprite("egg_ladle", At(center, _layout.DoupiEggFood.Size), 1, tilt);
        float stream = Phase(p, .28f, .34f) * (1 - Phase(p, .42f, .50f));
        if (stream > 0)
        {
            Vector2 end = (above + new Vector2(0, 15)).Lerp(PanCenter, Phase(p, .28f, .38f));
            Vector2 lip = center + new Vector2(-20, 15).Rotated(tilt);
            DrawLine(lip, end, new Color(1, .79f, .22f, stream), 5, true);
            Ellipse(end, new Vector2(7, 9), new Color(1, .73f, .13f, stream));
        }
        float sweep = Phase(p, .48f, .88f);
        float toolAlpha = Phase(p, .44f, .52f) * (1 - Phase(p, .88f, 1));
        Vector2 contact = QuadPoint(PanCorners, sweep, .55f);
        Sprite("flip_tool", At(contact + new Vector2(30, -23), new Vector2(138, 91)), toolAlpha, -.12f);
    }
}
