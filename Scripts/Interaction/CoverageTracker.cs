using Godot;

namespace ProjectCake.Interaction;

public sealed class CoverageTracker
{
    public const int RingCount = 4;
    public const int SectorCount = 8;
    public const int CellCount = RingCount * SectorCount;
    public const float SampleSpacing = 12.0f;
    public const float EdgeAssistDistance = 32.0f;

    private readonly bool[] _covered = new bool[CellCount];

    public CoverageTracker(int requiredCells)
    {
        if (requiredCells is < 1 or > CellCount)
        {
            throw new ArgumentOutOfRangeException(nameof(requiredCells));
        }

        RequiredCells = requiredCells;
    }

    public int RequiredCells { get; }

    public int CoveredCells { get; private set; }

    public double Progress => Math.Clamp((double)CoveredCells / RequiredCells, 0, 1);

    public bool IsComplete => CoveredCells >= RequiredCells;

    public IReadOnlyList<bool> Covered => _covered;

    public void Reset()
    {
        Array.Fill(_covered, false);
        CoveredCells = 0;
    }

    public bool AddSegment(Vector2 from, Vector2 to, float radius)
    {
        float distance = from.DistanceTo(to);
        int steps = Math.Max(1, Mathf.CeilToInt(distance / SampleSpacing));
        bool changed = false;

        for (int index = 0; index <= steps; index++)
        {
            Vector2 point = from.Lerp(to, (float)index / steps);
            Vector2? assisted = GetAssistedPoint(point, radius);
            if (assisted is not null)
            {
                changed |= MarkPoint(assisted.Value, radius);
            }
        }

        return changed;
    }

    public static Vector2? GetAssistedPoint(Vector2 localPoint, float radius)
    {
        float distance = localPoint.Length();
        if (distance > radius + EdgeAssistDistance)
        {
            return null;
        }

        if (distance <= radius || distance <= float.Epsilon)
        {
            return localPoint;
        }

        return localPoint.Normalized() * (radius - 0.01f);
    }

    private bool MarkPoint(Vector2 point, float radius)
    {
        float normalizedRadius = Math.Clamp(point.Length() / radius, 0, 0.9999f);
        int ring = Math.Min((int)(normalizedRadius * RingCount), RingCount - 1);
        float angle = Mathf.Atan2(point.Y, point.X);
        if (angle < 0)
        {
            angle += Mathf.Tau;
        }

        int sector = Math.Min((int)(angle / Mathf.Tau * SectorCount), SectorCount - 1);
        int cell = ring * SectorCount + sector;
        if (_covered[cell])
        {
            return false;
        }

        _covered[cell] = true;
        CoveredCells++;
        return true;
    }
}

