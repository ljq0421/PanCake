using Godot;

namespace ProjectCake.Pancake;

public partial class PancakeCanvas
{
    private readonly List<(Vector2 Point, float Life)> _spreadMarks = new();
    internal int SpreadMarkCount => _spreadMarks.Count;

    internal void SpreadContact(Vector2 point)
    {
        if (ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool()) return;
        Rect2 surface = GetSurfaceRect();
        Vector2 normalized = (point - surface.GetCenter()) / (surface.Size * .5f);
        if (normalized.LengthSquared() > 1) return;
        if (_spreadMarks.Count > 0 && _spreadMarks[^1].Point.DistanceTo(point) < 7) return;
        _spreadMarks.Add((point, .14f));
        if (_spreadMarks.Count > 6) _spreadMarks.RemoveAt(0);
    }

    private void TickMakingMotion(double delta, bool active)
    {
        if (!active || _runtime?.State != PancakeState.Spreading) _spreadMarks.Clear();
        for (int i = _spreadMarks.Count - 1; i >= 0; i--)
        {
            var mark = _spreadMarks[i];
            mark.Life -= (float)delta;
            if (mark.Life <= 0) _spreadMarks.RemoveAt(i); else _spreadMarks[i] = mark;
        }
    }

    private void DrawSpreadContact(Rect2 pancake)
    {
        foreach (var mark in _spreadMarks)
        {
            Vector2 toward = mark.Point - pancake.GetCenter();
            // Restrict the tiny contact trace to the currently revealed food.
            Vector2 n = toward / (pancake.Size * .5f);
            if (n.LengthSquared() > .78f) continue;
            float angle = toward.Angle();
            DrawArc(mark.Point, 10, angle + 1.8f, angle + 4.5f, 10,
                new Color(1, .91f, .58f, .30f * mark.Life / .14f), 2, true);
        }
    }
}
