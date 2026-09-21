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
        SurfaceLayer(hasFilling ? "doupi_filling_cooked" : _doupi?.HasEgg == true && !_doupi.SecondSide ? "doupi_egg" : "doupi_skin", quad, new Color(.66f, .43f, .24f), canvas: canvas);
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
            if (state == DoupiState.Burnt) DrawBurntDoupi(preview, quad, _doupi.HasFilling);
            else if (state == DoupiState.Cut)
                for (int i = _doupi.FirstRemainingPiece; i < _doupi.FirstRemainingPiece + _doupi.RemainingPieces; i++)
                    DrawPiece(i, QuadRegion(quad, PieceRegion(i)), _doupi.Quality, canvas: preview);
            else if (state is DoupiState.SecondCooking or DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting)
                FilledSurface(quad, _doupi.BrowningProgress, quality: _doupi.Quality, canvas: preview);
            else
            {
                SurfaceLayer(!_doupi.HasEgg || _doupi.SecondSide ? "doupi_skin" : "doupi_egg", quad, Colors.White, canvas: preview);
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
    private Vector2[] PanPiece(int tile) => SeparatedPanPiece(tile, 1);
    private Vector2[] SeparatedPanPiece(int tile, float progress)
    {
        Vector2[] quad = QuadRegion(PanCorners, PieceRegion(tile));
        Vector2 center = (quad[0] + quad[2]) * .5f;
        // Open narrow seams by insetting each piece; no outer edge leaves the pan.
        return quad.Select(p => p.MoveToward(center, ReducedMotion ? 1.5f : 1.5f * progress)).ToArray();
    }
    private Rect2 StockItemRect(int index)
    {
        Rect2 tray = _layout.StockFood;
        Vector2 cell = tray.Size / new Vector2(4, 2);
        Vector2 center = tray.Position + cell * new Vector2(index % 4 + .5f, index / 4 + .5f);
        return At(center, new Vector2(cell.X * .94f, cell.Y * 1.02f));
    }
    private void DrawDoupiStock(Motion? motion)
    {
        // Draw the back row before the front row.
        // Incoming pieces use this same order, so they do not change depth on landing.
        int[] indices = Enumerable.Range(0,_stock.Count).OrderBy(_stock.SlotAt).ToArray();
        for (int row = 0; row < 2; row++)
        foreach (int i in indices)
        {
            if (_stock.SlotAt(i) % 8 / 4 != row) continue;
            DoupiInventory.Piece piece = _stock.PieceAt(i);
            Vector2[] target = FitDoupiPieceQuad(piece.Tile, StockItemRect(_stock.SlotAt(i)));
            if (motion?.Kind != "stock" || i < motion.StockStart || i >= motion.StockStart + motion.Amount)
            {
                DrawStockPiece(piece.Tile, target, piece.Quality);
                continue;
            }
            float delay = ((i - motion.StockStart) / 4) * .07f;
            float t = Phase(motion.Progress, delay, 1);
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
            if (motion?.Kind == "cut" && p < .6f) FilledSurface(PanCorners, 1, quality: _doupi.Quality);
            else if (motion?.Kind == "cut")
                for (int i = _doupi.FirstRemainingPiece; i < _doupi.FirstRemainingPiece + _doupi.RemainingPieces; i++)
                    DrawPiece(i, SeparatedPanPiece(i, Phase(p, .6f, 1)), _doupi.Quality);
            else for (int i = _doupi.FirstRemainingPiece; i < _doupi.FirstRemainingPiece + _doupi.RemainingPieces; i++)
                DrawPiece(i, PanPiece(i), _doupi.Quality);
        }
        else if (state != DoupiState.Empty)
        {
            Vector2[] quad = PanCorners;
            float deposit = Phase(p, .35f, .80f);
            float heldLift = _gesture == "flip" && state == DoupiState.ReadyToFlip ? _flipLift : 0;
            if (motion?.Kind == "flip_return") heldLift = motion.Lift * (1 - Smooth(p));
            if (!ReducedMotion)
            {
                if (motion?.Kind == "flip")
                {
                    quad = FlipQuad(motion);
                    float air = Mathf.Sin(Phase(p, 0, .88f) * Mathf.Pi);
                    Ellipse(PanCenter + new Vector2(0, 8), new Vector2(130 - air * 14, 38 - air * 10), new Color(.18f,.10f,.04f,.12f + .1f * (1-air)));
                }
                else if (heldLift > 0)
                {
                    quad = (Vector2[])quad.Clone();
                    quad[2] -= new Vector2(0,24*heldLift); quad[3] -= new Vector2(0,24*heldLift);
                }
            }
            float alpha = motion?.Kind == "batter" ? deposit : 1;
            if (motion?.Kind == "batter" && !ReducedMotion)
                quad = quad.Select(v => PanCenter + (v - PanCenter) * (.25f + .75f * deposit)).ToArray();
            if (state is DoupiState.Batter || motion?.Kind == "egg")
                SurfaceLayer("doupi_skin", quad, new Color(1, 1, 1, alpha));
            if (state is DoupiState.SkinCooking or DoupiState.ReadyToFlip or DoupiState.Flipped)
            {
                if (motion?.Kind == "flip")
                {
                    if (ReducedMotion)
                    {
                        SurfaceLayer("doupi_egg",quad,Colors.White);
                        SurfaceLayer("doupi_skin",quad,new Color(1,.91f,.66f,Smooth(p)));
                    }
                    else DrawFlippingSkin(motion);
                }
                else if (motion?.Kind == "egg" && !ReducedMotion) DrawEggSurface(quad, p);
                else
                {
                    bool underside = state == DoupiState.Flipped && (motion?.Kind != "flip" || p >= .5f);
                    SurfaceLayer(underside ? "doupi_skin" : "doupi_egg", quad,
                        underside ? new Color(1,.91f,.66f,1) : Colors.White);
                }
            }
            if (state is DoupiState.SecondCooking or DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting)
            {
                if (motion?.Kind == "filling") DrawAutoFilling(quad, p);
                else FilledSurface(quad, _doupi.BrowningProgress, quality: _doupi.Quality);
            }
            if (state == DoupiState.Burnt)
            {
                DrawBurntDoupi(this, quad, _doupi.HasFilling);
            }
            if (!_doupi.SecondSide && _doupi.IsHeating)
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
                if (state != DoupiState.Cut || motion?.Kind == "cut")
                {
                    float reveal = 1;
                    if (!ReducedMotion && motion?.Kind == "cut" && motion.Line != DoupiCutLine.Horizontal
                        && line != DoupiCutLine.Horizontal && line != motion.Line)
                        reveal = Phase(p, .08f + (int)line * .08f, .38f + (int)line * .08f);
                    DrawCut((int)line, reveal);
                }
            if (IsKnifeHeld && state is (DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting))
                foreach (DoupiCutLine line in Enum.GetValues<DoupiCutLine>())
                {
                    if (_doupi.CutLines.Contains(line)) continue;
                    var (from, to) = CutLine((int)line);
                    DrawDashedLine(from, to, new Color(1, .96f, .8f, .32f), 1.5f, 9, true);
                }
            if (_doupi.IsHeating) Steam(PanCenter + new Vector2(0, -30), .7f);
            if (motion?.Kind == "flip" && !ReducedMotion && p > .78f)
            {
                float puff = Phase(p,.78f,1);
                for (int i=0;i<3;i++) Ellipse(PanCenter + new Vector2((i-1)*85, -puff*18),
                    new Vector2(9+puff*14, 3+puff*6), new Color(1,1,1,.28f*(1-puff)));
            }
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

    private Vector2[] FlipQuad(Motion motion) => FlipQuad(motion.Progress, motion.Lift);
    private Vector2[] FlipQuad(float p, float heldLift)
    {
        float turn = Phase(p,.15f,.80f);
        float lift = Mathf.Sin(Phase(p,0,.88f)*Mathf.Pi)*24;
        float depth = Math.Max(.12f, Mathf.Abs(Mathf.Cos(turn*Mathf.Pi)));
        float settle = Mathf.Sin(Phase(p,.84f,1)*Mathf.Pi)*3;
        Vector2[] quad = PanCorners.Select(v => PanCenter + (v-PanCenter)*new Vector2(1,depth)
            + new Vector2((v.Y-PanCenter.Y)*Mathf.Sin(turn*Mathf.Pi)*.12f, -lift+settle)).ToArray();
        float held = heldLift * (1-Phase(p,0,.35f));
        quad[2] -= new Vector2(0,24*held); quad[3] -= new Vector2(0,24*held);
        float tilt = -Mathf.Sin(turn*Mathf.Pi)*.08f;
        return quad.Select(v => PanCenter+(v-PanCenter).Rotated(tilt)).ToArray();
    }
    internal Vector2[] FlipSurfaceQuad(float progress, float heldLift, Rect2 region)
    {
        Vector2[] quad = FlipQuad(progress,heldLift);
        float curl = Mathf.Sin(Phase(progress,.15f,.80f)*Mathf.Pi);
        // Bend equally along both edges: varying curvature across depth can fold a cell over itself.
        Vector2 Bent(float u,float v) => QuadPoint(quad,u,v)-new Vector2(0,Mathf.Sin(u*Mathf.Pi)*curl*6);
        return new[]{Bent(region.Position.X,region.Position.Y),Bent(region.End.X,region.Position.Y),
            Bent(region.End.X,region.End.Y),Bent(region.Position.X,region.End.Y)};
    }
    private void DrawFlippingSkin(Motion motion)
    {
        float turn = Phase(motion.Progress,.15f,.80f);
        // A curved mesh keeps the flexible skin readable through the middle of the turn.
        // The underside rolls into view across its width instead of swapping one flat sprite.
        for (int y=0;y<4;y++) for (int x=0;x<12;x++)
        {
            Rect2 region = new(x/12f,y/4f,1/12f,1/4f);
            Vector2[] cell = FlipSurfaceQuad(motion.Progress,motion.Lift,region);
            if (y==3) DrawColoredPolygon(new[]{cell[3],cell[2],cell[2]+new Vector2(0,4),cell[3]+new Vector2(0,4)},new Color("#C9964A"));
            float underside = Smooth((turn-.42f+x/12f*.12f)/.16f);
            SurfaceLayer("doupi_egg",cell,Colors.White,region);
            SurfaceLayer("doupi_skin",cell,new Color(1,.91f,.66f,underside),region);
        }
    }
    private void DrawFlipTool(Vector2 contact, float alpha = 1, float angle = 0)
        => Sprite("flip_tool", At(contact + new Vector2(30,-23), new Vector2(138,91)), alpha, angle);
    private void DrawFillingPortion(Vector2 center, float alpha = 1)
    {
        Vector2[] ring = Enumerable.Range(0,24).Select(i => new Vector2(Mathf.Cos(i*Mathf.Tau/24),Mathf.Sin(i*Mathf.Tau/24))).ToArray();
        DrawPolygon(ring.Select(v=>center+v*new Vector2(27,13)).ToArray(),new[]{new Color(1,1,1,alpha)},
            ring.Select(v=>new Vector2(.5f,.5f)+v*new Vector2(.12f,.07f)).ToArray(),_art.Texture("doupi_filling_overlay"));
    }
    private void DrawFillingTool(Vector2 contact, float alpha = 1)
    {
        DrawFlipTool(contact, alpha); DrawFillingPortion(contact + new Vector2(-6, -4), alpha);
    }
    private void DrawAutoFilling(Vector2[] quad, float p)
    {
        SurfaceLayer("doupi_skin",quad,new Color(1,.91f,.66f,1));
        float spread = Phase(p,.20f,.88f);
        if (ReducedMotion)
        { FilledSurface(quad,_doupi!.BrowningProgress,Smooth(p),quality:_doupi.Quality); return; }
        DrawFillingPortion(PanCenter, Phase(p,0,.20f)*(1-spread));
        const int strips = 32;
        for (int i=0;i<strips;i++)
        {
            Rect2 region = new(i/(float)strips,0,1f/strips,1);
            float alpha = Smooth((spread*1.1f-region.Position.X)/.10f);
            FilledSurface(QuadRegion(quad,region),_doupi!.BrowningProgress,alpha,region,_doupi.Quality);
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
        if (m.Kind is "flip" or "flip_return" or "cut")
        {
            Vector2 center;
            if (m.Kind == "cut")
            {
                var (from, to) = CutLine((int)m.Line);
                center = (m.Origin ?? to) - new Vector2(0, 10 * Smooth(p));
            }
            else
            {
                Vector2 target = m.Kind == "flip" ? QuadPoint(FlipQuad(m),.65f,.8f) : PanCenter;
                center = (m.Origin ?? target).Lerp(target, Phase(p,0,.35f));
                float alpha = m.Kind == "flip_return" ? 1-Smooth(p) : 1-Phase(p,.8f,1);
                DrawFlipTool(center, alpha, m.Kind == "flip" ? -Mathf.Sin(Phase(p,.15f,.8f)*Mathf.Pi)*.4f : 0);
                return;
            }
            Sprite("cut_tool", At(center + new Vector2(30,-23),new Vector2(138,91)),toolAlpha);
        }
        else if (m.Kind == "egg") DrawEggMotion(m);
        else if (m.Kind == "filling")
        {
            float sweep = Phase(p,.20f,.88f);
            Vector2 contact = (m.Origin ?? PanCenter).Lerp(QuadPoint(PanCorners,0,.55f),Phase(p,0,.20f));
            if (p >= .20f) contact = QuadPoint(PanCorners,sweep,.55f);
            DrawFlipTool(contact,1-Phase(p,.88f,1));
            if (p < .20f) DrawFillingPortion(contact + new Vector2(-6,-4),1-Phase(p,0,.20f));
        }
        else if (m.Kind == "batter")
        {
            Vector2 start = m.Origin ?? BatterRect.GetCenter();
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
