using Godot;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private Vector2 _foodPull;
    private Vector2 _foodContact;
    private float _mixFinish;
    private long _foodGeneration = -1;
    private static readonly Vector2[] NoodleEdge = Enumerable.Range(0, 32)
        .Select(i => Vector2.One * .5f + Vector2.FromAngle(i * Mathf.Tau / 32) * .5f).ToArray();
    internal Vector2 FoodPull => _foodPull;

    private void PullNoodles(Vector2 point, Vector2 movement)
    {
        SyncFoodGeneration();
        if (ReducedMotion || movement.LengthSquared() < .01f) return;
        _foodContact = point;
        _foodPull = movement.LimitLength(6);
    }

    private void ResetFoodMotion()
    {
        _foodPull = Vector2.Zero;
        _mixFinish = 0;
    }

    private void TickFoodMotion(double delta)
    {
        SyncFoodGeneration();
        if (ReducedMotion || _bowl.State == ProjectCake.Wuhan.NoodleBowlState.Empty)
        { ResetFoodMotion(); return; }
        _foodPull = _foodPull.MoveToward(Vector2.Zero, (float)delta * 40);
        _mixFinish = Math.Max(0, _mixFinish - (float)delta);
    }

    private void SyncFoodGeneration()
    {
        if (_foodGeneration == _bowl.Generation) return;
        _foodGeneration = _bowl.Generation;
        ResetFoodMotion();
    }

    // The rim stays fixed. Only vertices close to the tool move, and the oval
    // boundary has zero displacement so every layer remains inside the bowl.
    internal Vector2 NoodleVertex(Vector2 normalized, Rect2 food)
    {
        Vector2 point = food.Position + food.Size * normalized;
        float edge = Mathf.Clamp((1 - ((normalized - Vector2.One * .5f) * 2).LengthSquared()) * 3, 0, 1);
        float near = Mathf.Clamp(1 - point.DistanceTo(_foodContact) / 85, 0, 1);
        point += _foodPull * (near * near * edge);
        float gather = Mathf.Sin(Mathf.Clamp(_mixFinish / .18f, 0, 1) * Mathf.Pi) * .025f;
        return point.Lerp(food.GetCenter(), gather * edge);
    }

    private void DrawMovingNoodleLayer(string id, Rect2 food, float alpha)
    {
        if (alpha <= 0) return;
        var texture = _art.Texture(id);
        Rect2 source = Source(texture);
        if (_foodPull.LengthSquared() < .001f && _mixFinish <= 0)
        {
            DrawPolygon(NoodleEdge.Select(p => food.Position + food.Size * p).ToArray(),
                new[] { new Color(1, 1, 1, alpha) },
                NoodleEdge.Select(p => (source.Position + source.Size * p) / texture.GetSize()).ToArray(), texture);
            return;
        }
        // A polar mesh clips at the authored food oval and bends the existing
        // coarse noodle groups; no extra painted strands or rotating bowl.
        const int rings = 4, sectors = 32;
        var vertices = new Vector2[4]; var uv = new Vector2[4];
        for (int ring = 0; ring < rings; ring++)
        for (int sector = 0; sector < sectors; sector++)
        {
            Vector2 Point(int r, int s) => Vector2.One * .5f + Vector2.FromAngle(s * Mathf.Tau / sectors) * (.5f * r / rings);
            var points = new[] { Point(ring, sector), Point(ring + 1, sector), Point(ring + 1, sector + 1), Point(ring, sector + 1) };
            for (int i = 0; i < 4; i++)
            { vertices[i] = NoodleVertex(points[i], food); uv[i] = (source.Position + source.Size * points[i]) / texture.GetSize(); }
            if (ring == 0) DrawPolygon(new[] { vertices[0], vertices[1], vertices[2] }, new[] { new Color(1,1,1,alpha) }, new[] { uv[0],uv[1],uv[2] }, texture);
            else DrawPolygon(vertices, new[] { new Color(1,1,1,alpha) }, uv, texture);
        }
    }

    private void DrawPouringNoodles(string id, Vector2 start, Vector2 size, float angle, float progress, float alpha)
    {
        if (alpha <= 0) return;
        var texture = _art.Texture(id);
        Rect2 source = Source(texture);
        Vector2 Vertex(Vector2 p)
        {
            // Smooth delays keep adjacent noodle groups connected throughout the fall.
            float delay = .035f * (1 - Mathf.Cos(p.X * Mathf.Tau * 2));
            float fall = Segment(progress, .40f + delay, .66f + delay);
            float settle = Phase(progress, .70f, .82f);
            Vector2 landingSize = BowlFood.Size * new Vector2(1 + .04f * (1 - settle), 1 - .05f * (1 - settle));
            Vector2 offset = p - Vector2.One * .5f;
            return (start + (offset * size).Rotated(angle)).Lerp(BowlFood.GetCenter() + offset * landingSize, fall);
        }
        const int rings = 4, sectors = 32;
        Vector2 Point(int r, int s) => Vector2.One * .5f + Vector2.FromAngle(s * Mathf.Tau / sectors) * (.5f * r / rings);
        for (int ring = 0; ring < rings; ring++)
        for (int sector = 0; sector < sectors; sector++)
        {
            Vector2[] points = ring == 0
                ? new[] { Point(0, sector), Point(1, sector), Point(1, sector + 1) }
                : new[] { Point(ring, sector), Point(ring + 1, sector), Point(ring + 1, sector + 1), Point(ring, sector + 1) };
            DrawPolygon(points.Select(Vertex).ToArray(), new[] { new Color(1, 1, 1, alpha) },
                points.Select(p => (source.Position + source.Size * p) / texture.GetSize()).ToArray(), texture);
        }
    }

    private void DrawBowlFront()
    {
        // Restore the painted front rim below the food opening, from the same
        // sheet as the stage. It never moves with the food or changes hit areas.
        Vector2 center = BowlFood.GetCenter(), radii = BowlFood.Size * .5f;
        var outline = Enumerable.Range(0, 25).Select(i => center + Vector2.FromAngle(i * Mathf.Pi / 24) * radii)
            .Concat(new[] { new Vector2(BowlFood.Position.X, BowlRect.End.Y), new Vector2(BowlFood.End.X, BowlRect.End.Y) }).ToArray();
        DrawPolygon(outline, new[] { Colors.White }, outline.Select(p => p / WuhanWorkbenchLayout.DesignSize).ToArray(), WorkbenchSheet);
    }

    private void DrawFoodSlice(string id, Rect2 whole, int part, int count, float alpha)
    {
        if (alpha <= 0) return;
        var texture = _art.Texture(id);
        Rect2 source = Source(texture);
        Vector2 portion = new(1f / count, 1);
        DrawTextureRectRegion(texture,
            new Rect2(whole.Position + new Vector2(whole.Size.X * part / count, 0), whole.Size * portion),
            new Rect2(source.Position + new Vector2(source.Size.X * part / count, 0), source.Size * portion),
            new Color(1, 1, 1, alpha));
    }

    private void DrawSettlingTopping(string id, Rect2 rect, float alpha, Motion? motion)
    {
        if (ReducedMotion || motion?.Kind != "ingredient" || ToppingArt(motion.Ingredient) != id)
        { FoodLayer(id, rect, alpha); return; }
        float settle = Phase(motion.Progress, .62f, 1);
        if (id == "scallion")
        {
            for (int group = 0; group < 3; group++)
            {
                float drop = Phase(motion.Progress, .62f + group * .035f, .9f + group * .035f);
                DrawFoodSlice(id, new Rect2(rect.Position - new Vector2(0, (1 - drop) * 12), rect.Size), group, 3, alpha * drop);
            }
        }
        else
        {
            float squeeze = Mathf.Sin(settle * Mathf.Pi) * (id == "beef_overlay" ? .04f : .015f);
            Vector2 size = rect.Size * new Vector2(1 + squeeze, 1 - squeeze);
            FoodLayer(id, new Rect2(rect.GetCenter() - size * .5f, size), alpha * Mathf.Clamp(settle * 4, 0, 1));
        }
    }
}
