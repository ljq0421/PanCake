using Godot;

namespace ProjectCake.Wuhan;

public enum DoupiCutLine { Left, Center, Right, Horizontal }

/// <summary>Shared tuning in normalized food-surface coordinates, independent of viewport size.</summary>
public static class DoupiInteraction
{
    public const float CutBand = .18f, CutTarget = .70f;
    public const float VerticalCutDistance = .40f, VerticalDirectionRatio = 1.15f;
    public const float FlipDistance = 40, FlipSideTolerance = 150;
    public static bool Inside(Vector2 p) => p.IsFinite() && p.X >= 0 && p.X <= 1 && p.Y >= 0 && p.Y <= 1;
    public static float Position(DoupiCutLine line) => line switch
    { DoupiCutLine.Left => .25f, DoupiCutLine.Right => .75f, _ => .5f };

    // Inverse of the bilinear quadrilateral used by the presentation, also valid outside the pan.
    public static Vector2 ToSurface(Vector2[] q, Vector2 point)
    {
        Vector2 b = q[1] - q[0], c = q[3] - q[0], d = q[0] - q[1] + q[2] - q[3];
        Vector2 uv = new(.5f, .5f);
        for (int i = 0; i < 8; i++)
        {
            Vector2 error = q[0] + b * uv.X + c * uv.Y + d * uv.X * uv.Y - point;
            Vector2 dx = b + d * uv.Y, dy = c + d * uv.X;
            float determinant = dx.Cross(dy);
            if (Math.Abs(determinant) < .00001f) break;
            uv -= new Vector2(error.Cross(dy), dx.Cross(error)) / determinant;
        }
        return uv;
    }
}

/// <summary>One press, one direction. Horizontal cuts trace a line; vertical cuts use deliberate displacement.</summary>
public sealed class DoupiCutStroke
{
    private const int Samples = 100;
    private readonly bool[] _covered = new bool[Samples];
    private readonly Vector2 _start;
    private Vector2 _previous;
    public DoupiCutLine? Line { get; private set; }
    public float Coverage => (float)_covered.Count(x => x) / Samples;
    public bool Covered(int index) => _covered[index];
    public int SampleCount => Samples;
    public DoupiCutStroke(Vector2 start) => _start = _previous = start;
    public bool Move(Vector2 point)
    {
        if (!point.IsFinite()) return false;
        Vector2 from = _previous; _previous = point;
        if (Line is null)
        {
            Vector2 delta = point - _start;
            float x = Math.Abs(delta.X), y = Math.Abs(delta.Y);
            if (Math.Max(x, y) < .04f) return false;
            if (x > y ? x < y * 1.5f : y < x * DoupiInteraction.VerticalDirectionRatio) return false;
            Line = x > y ? DoupiCutLine.Horizontal
                : (DoupiCutLine)Math.Clamp((int)MathF.Round(_start.X * 4) - 1, 0, 2);
            from = _start;
        }
        bool horizontal = Line == DoupiCutLine.Horizontal;
        float axisA = horizontal ? from.X : from.Y, axisB = horizontal ? point.X : point.Y;
        float crossA = horizontal ? from.Y : from.X, crossB = horizontal ? point.Y : point.X;
        float position = DoupiInteraction.Position(Line.Value);
        // Direction is locked once. Small sideways jitters must not drop valid progress.
        // Vertical previews snap to the template regardless of the stroke's starting column.
        // Horizontal cuts retain their existing line-band coverage requirement.
        if (Math.Abs(axisB - axisA) < .00001f) return false;
        for (int i = 0; i < Samples; i++)
        {
            float axis = (i + .5f) / Samples;
            float t = (axis - axisA) / (axisB - axisA);
            if (t < 0 || t > 1) continue;
            float cross = Mathf.Lerp(crossA, crossB, t);
            if (cross >= 0 && cross <= 1 && (!horizontal || Math.Abs(cross - position) <= DoupiInteraction.CutBand)) _covered[i] = true;
        }
        if (horizontal) return Coverage >= DoupiInteraction.CutTarget;
        Vector2 displacement = point - _start;
        float verticalDistance = Math.Abs(Math.Clamp(point.Y, 0, 1) - Math.Clamp(_start.Y, 0, 1));
        return verticalDistance + .00001f >= DoupiInteraction.VerticalCutDistance
            && Math.Abs(displacement.Y) >= Math.Abs(displacement.X) * DoupiInteraction.VerticalDirectionRatio
            && Coverage >= DoupiInteraction.VerticalCutDistance;
    }
}
