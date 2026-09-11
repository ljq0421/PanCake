using Godot;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private Vector2[] PanCorners => _layout.PanCorners;
    // The square, top-down source is cropped to a wide work surface BEFORE
    // projection. Keeping the middle band preserves the proportions of the rice.
    private static readonly Rect2 DoupiSurface = new(.08f, .27f, .84f, .46f);
    private static float Smooth(float p) { p = Mathf.Clamp(p, 0, 1); return p * p * (3 - 2 * p); }
    private static float Phase(float p, float start, float end) => Smooth((p - start) / (end - start));
    private static Vector2 QuadPoint(Vector2[] q, float x, float y) => q[0].Lerp(q[1], x).Lerp(q[3].Lerp(q[2], x), y);
    private static Vector2[] QuadRegion(Vector2[] q, Rect2 region) => new[] {
        QuadPoint(q, region.Position.X, region.Position.Y), QuadPoint(q, region.End.X, region.Position.Y),
        QuadPoint(q, region.End.X, region.End.Y), QuadPoint(q, region.Position.X, region.End.Y) };
    private static Rect2 PieceRegion(int tile) => new((tile % 4) / 4f, (tile / 4) / 2f, .25f, .5f);
    private static Vector2[] RectQuad(Rect2 r) => new[] { r.Position, new Vector2(r.End.X, r.Position.Y), r.End, new Vector2(r.Position.X, r.End.Y) };

    private void SurfaceLayer(string id, Vector2[] quad, Color tint, Rect2? region = null)
    {
        if (tint.A <= 0) return;
        // Use exactly the same mesh before/after cutting. A single triangulated
        // trapezoid would shift the texture when replaced by eight smaller quads.
        if (region is null)
        {
            for (int tile = 0; tile < 8; tile++)
                SurfaceLayer(id, QuadRegion(quad, PieceRegion(tile)), tint, PieceRegion(tile));
            return;
        }
        Texture2D texture = _art.Texture(id);
        Rect2 source = RelativeRect(DoupiSurface, region ?? new Rect2(0, 0, 1, 1));
        DrawPolygon(quad, new[] { tint }, RectQuad(source), texture);
    }
    private static Color CookedTint(float progress, float alpha = 1) => new Color(1, 1, 1, alpha).Lerp(new Color(1, .83f, .56f, alpha), Smooth(progress));
    private void FilledSurface(Vector2[] quad, float browning, float alpha = 1, Rect2? region = null, DoupiQuality quality = DoupiQuality.Normal)
    {
        SurfaceLayer("doupi_skin", quad, CookedTint(browning, alpha), region);
        SurfaceLayer("doupi_filling_overlay", quad, CookedTint(browning, alpha), region);
        if (quality != DoupiQuality.Normal)
            SurfaceLayer("doupi_burnt", quad, new Color(1, 1, 1, alpha * (quality == DoupiQuality.Burnt ? 1 : .3f)), region);
    }
    private void DrawPiece(int tile, Vector2[] quad, DoupiQuality quality, float alpha = 1)
    {
        Vector2 depth = new(0, 3);
        DrawColoredPolygon(new[] { quad[3], quad[2], quad[2] + depth, quad[3] + depth }, new Color(.58f, .30f, .10f, alpha));
        FilledSurface(quad, 1, alpha, PieceRegion(tile), quality);
        DrawPolyline(new[] { quad[0], quad[1], quad[2], quad[3], quad[0] }, new Color(.52f, .30f, .10f, .7f * alpha), 1, true);
    }
    private Vector2[] PanPiece(int tile) => QuadRegion(PanCorners, PieceRegion(tile));
    private Rect2 StockItemRect(int index)
    {
        int slot = index % 8, layer = index / 8;
        Rect2 tray = _layout.StockFood;
        Vector2 center = tray.Position + tray.Size * new Vector2((slot % 4 + .5f) / 4, .30f + slot / 4 * .43f);
        center += new Vector2(layer * 1.5f, -layer * 5);
        return At(center, new Vector2(tray.Size.X / 4 - 3, 30));
    }
    private void DrawDoupi()
    {
        if (_doupi is null) return;
        Hint(StockRect, "stock");
        DrawDoupiIngredients();
        Motion? motion = Find("pan");
        int displayed = _stock.Count - (motion?.Kind == "stock" ? motion.Amount : 0);
        for (int i = 0; i < displayed; i++)
        {
            DoupiInventory.Piece piece = _stock.PieceAt(i);
            DrawPiece(piece.Tile, RectQuad(StockItemRect(i)), piece.Quality);
        }
        Hint(At(PanCenter, PanRect.Size * new Vector2(.7f, .4f)), "pan");
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
            SurfaceLayer("doupi_skin", quad, new Color(1, 1, 1, alpha));
            if (state != DoupiState.Batter)
                SurfaceLayer("doupi_egg", quad, new Color(1, 1, 1, motion?.Kind == "egg" ? deposit : 1));
            if (state == DoupiState.Spreading) DrawSpreading(quad);
            if (state is DoupiState.SecondCooking or DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting)
                FilledSurface(quad, _doupi.BrowningProgress, motion?.Kind == "filling" ? deposit : 1, quality: _doupi.Quality);
            if (state == DoupiState.Burnt) SurfaceLayer("doupi_burnt", quad, Colors.White);
        }
        if (state != DoupiState.Empty)
        {
            foreach (DoupiCutLine line in _doupi.CutLines)
                if (state != DoupiState.Cut || motion?.Kind == "cut") DrawCut((int)line, 1);
            if (state is DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting)
                foreach (DoupiCutLine line in Enum.GetValues<DoupiCutLine>())
                {
                    if (_doupi.CutLines.Contains(line)) continue;
                    var (from, to) = CutLine((int)line);
                    DrawDashedLine(from, to, new Color(1, .96f, .8f, .65f), 2, 9, true);
                }
            if (state is DoupiState.SkinCooking or DoupiState.SecondCooking or DoupiState.ReadyToFlip or DoupiState.ReadyToCut)
                Steam(PanCenter + new Vector2(0, -30), .7f);
        }
        if (motion is not null) DrawPanMotion(motion);
    }
    private void DrawDoupiIngredients()
    {
        // The tray is painted into the sheet; only the eggs are a dynamic overlay.
        Sprite(_art.Shared.Ingredient(ProjectCake.Data.StableIds.Ingredients.Egg), _layout.DoupiEggFood);
        Rect2? available = _doupi?.State switch
        { DoupiState.Empty => BatterRect, DoupiState.Batter => DoupiEggRect, DoupiState.Flipped => FillingRect, _ => null };
        if (available is Rect2 rect && !Busy("pan"))
            DrawStyleBox(WuhanUi.Box(new Color(1, .93f, .65f, .12f), 16, 1, false), rect);
        Hint(BatterRect, "batter"); Hint(FillingRect, "filling"); Hint(DoupiEggRect, "doupi_egg");
    }

    private void DrawSpreading(Vector2[] quad)
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
            DrawPolygon(QuadRegion(quad, region), colors, RectQuad(RelativeRect(DoupiSurface, region)), texture);
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
        if (m.Kind == "stock")
        {
            for (int i = 0; i < m.Amount; i++)
            {
                float t = Smooth(p);
                Vector2[] source = PanPiece(m.Index + i), target = RectQuad(StockItemRect(m.StockStart + i));
                Vector2[] quad = source.Select((v, j) => v.Lerp(target[j], t) - new Vector2(0, Mathf.Sin(t * Mathf.Pi) * 24)).ToArray();
                if (ReducedMotion)
                {
                    DrawPiece(m.Index + i, source, m.DoupiQuality, 1 - t);
                    DrawPiece(m.Index + i, target, m.DoupiQuality, t);
                }
                else DrawPiece(m.Index + i, quad, m.DoupiQuality);
            }
            return;
        }
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
        else if (m.Kind is "batter" or "egg" or "filling")
        {
            Vector2 start = m.Origin ?? (m.Kind == "egg" ? DoupiEggRect : m.Kind == "filling" ? FillingRect : BatterRect).GetCenter();
            Vector2 above = PanCenter + new Vector2(0, -60);
            float travel = Phase(p, 0, .35f), retreat = Phase(p, .8f, 1);
            Vector2 center = start.Lerp(above, travel).Lerp(start, retreat);
            if (m.Kind == "egg") Sprite(_art.Shared.Ingredient(ProjectCake.Data.StableIds.Ingredients.Egg), At(center, new Vector2(55, 50)), toolAlpha);
            else
            {
                Sprite("doupi_ladle", At(center, new Vector2(90, 90)), toolAlpha);
            }
            float stream = Phase(p, .3f, .42f) * (1 - Phase(p, .65f, .8f));
            if (stream > 0) DrawLine(center + new Vector2(0, 12), PanCenter,
                new Color(new Color(m.Kind == "egg" ? "#FFC942" : "#EACD8C"), stream), 5, true);
        }
    }
}
