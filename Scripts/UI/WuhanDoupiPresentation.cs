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
            float alpha = motion?.Kind == "batter" ? deposit : 1;
            if (motion?.Kind == "batter" && !ReducedMotion)
                quad = quad.Select(v => PanCenter + (v - PanCenter) * (.85f + .15f * deposit)).ToArray();
            SurfaceLayer("doupi_skin", quad, new Color(1, 1, 1, alpha));
            if (state != DoupiState.Batter)
                SurfaceLayer("doupi_egg", quad, new Color(1, 1, 1, motion?.Kind == "egg" ? deposit : 1));
            if (state is DoupiState.SecondCooking or DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting)
                FilledSurface(quad, _doupi.BrowningProgress, motion?.Kind == "filling" ? deposit : 1, quality: _doupi.Quality);
            if (state == DoupiState.Burnt) SurfaceLayer("doupi_burnt", quad, Colors.White);
        }
        if (state != DoupiState.Empty)
        {
            foreach (DoupiCutDirection direction in _doupi.CutDirections)
                for (int i = 0; i < (direction == DoupiCutDirection.Horizontal ? 1 : 3); i++)
                {
                    int line = direction == DoupiCutDirection.Horizontal ? 3 : i;
                    float progress = motion?.Kind == "cut" && motion.Direction == direction ? CutProgress(direction, i, p) : 1;
                    // Separate piece outlines replace the cutting overlay when transfer begins.
                    if (state != DoupiState.Cut || motion?.Kind == "cut") DrawCut(line, progress);
                }
            if (state is DoupiState.SkinCooking or DoupiState.SecondCooking or DoupiState.ReadyToFlip or DoupiState.ReadyToCut)
                Steam(PanCenter + new Vector2(0, -30), .7f);
        }
        if (motion is not null) DrawPanMotion(motion);
    }
    private static float CutProgress(DoupiCutDirection direction, int index, float p) => direction == DoupiCutDirection.Horizontal
        ? Phase(p, .1f, .9f) : Phase(p, .08f + index * .28f, .30f + index * .28f);
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
                int stroke = m.Direction == DoupiCutDirection.Horizontal ? 0 : Math.Clamp((int)((p - .08f) / .28f), 0, 2);
                var (from, to) = CutLine(m.Direction == DoupiCutDirection.Horizontal ? 3 : stroke);
                center = from.Lerp(to, CutProgress(m.Direction, stroke, p));
                // Lift/fade between parallel strokes instead of sliding a blade across food.
                if (m.Direction == DoupiCutDirection.Vertical)
                    toolAlpha *= Phase(p, .06f + stroke * .28f, .08f + stroke * .28f)
                        * (1 - Phase(p, .30f + stroke * .28f, .36f + stroke * .28f));
            }
            else center = PanCenter + new Vector2(35, -Mathf.Sin(Smooth(p) * Mathf.Pi) * 36);
            Sprite(m.Kind == "cut" ? "cut_tool" : "flip_tool", At(center + new Vector2(30, -23), new Vector2(138, 91)), toolAlpha,
                m.Kind == "flip" ? -Mathf.Sin(Smooth(p) * Mathf.Pi) * .4f : 0);
        }
        else if (m.Kind is "batter" or "egg" or "filling")
        {
            Vector2 start = (m.Kind == "filling" ? FillingRect : BatterRect).GetCenter();
            Vector2 above = PanCenter + new Vector2(0, -60);
            float travel = Phase(p, 0, .35f), retreat = Phase(p, .8f, 1);
            Vector2 center = start.Lerp(above, travel).Lerp(start, retreat);
            if (m.Kind == "egg") Sprite(_art.Shared.Ingredient(ProjectCake.Data.StableIds.Ingredients.Egg), At(center, new Vector2(55, 50)), toolAlpha);
            else
            {
                Ellipse(center, new Vector2(22, 12), new Color(new Color(m.Kind == "batter" ? "#EACD8C" : "#CE955A"), toolAlpha));
                DrawLine(center, center + new Vector2(32, -35), new Color(WuhanUi.Ink, toolAlpha), 5, true);
            }
            float stream = Phase(p, .3f, .42f) * (1 - Phase(p, .65f, .8f));
            if (stream > 0) DrawLine(center + new Vector2(0, 12), PanCenter,
                new Color(new Color(m.Kind == "egg" ? "#FFC942" : "#EACD8C"), stream), 5, true);
        }
    }
}
