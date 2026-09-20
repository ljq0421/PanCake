using Godot;

namespace ProjectCake.Interaction;

public sealed class CoverageTracker
{
    public const int RingCount = 4;
    public const int SectorCount = 8;
    public const int CellCount = RingCount * SectorCount;
    public const float SampleSpacing = 12.0f;
    public const float EdgeAssistDistance = 32.0f;

    private readonly bool[] _covered;
    private readonly int _rings;
    private readonly int _sectors;
    private readonly float _sampleSpacing;

    public CoverageTracker(int requiredCells, double maximumProgress = 1,
        int rings = RingCount, int sectors = SectorCount, float sampleSpacing = SampleSpacing)
    {
        if (rings < 1 || sectors < 1 || !float.IsFinite(sampleSpacing) || sampleSpacing <= 0)
            throw new ArgumentOutOfRangeException(nameof(rings));
        _rings = rings;
        _sectors = sectors;
        _sampleSpacing = sampleSpacing;
        _covered = new bool[checked(rings * sectors)];
        if (requiredCells < 1 || requiredCells > _covered.Length)
        {
            throw new ArgumentOutOfRangeException(nameof(requiredCells));
        }

        RequiredCells = requiredCells;
        if (!double.IsFinite(maximumProgress) || maximumProgress < 1 || requiredCells * maximumProgress > _covered.Length)
            throw new ArgumentOutOfRangeException(nameof(maximumProgress));
        MaximumProgress = maximumProgress;
    }

    public int RequiredCells { get; }
    public double MaximumProgress { get; }

    public int CoveredCells { get; private set; }

    public double Progress => Math.Clamp((double)CoveredCells / RequiredCells, 0, MaximumProgress);

    public bool IsComplete => CoveredCells >= RequiredCells * MaximumProgress;

    public IReadOnlyList<bool> Covered => _covered;

    public void Reset()
    {
        Array.Fill(_covered, false);
        CoveredCells = 0;
    }

    public bool AddSegment(Vector2 from, Vector2 to, float radius)
    {
        float distance = from.DistanceTo(to);
        int steps = Math.Max(1, Mathf.CeilToInt(distance / _sampleSpacing));
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
        int ring = Math.Min((int)(normalizedRadius * _rings), _rings - 1);
        float angle = Mathf.Atan2(point.Y, point.X);
        if (angle < 0)
        {
            angle += Mathf.Tau;
        }

        int sector = Math.Min((int)(angle / Mathf.Tau * _sectors), _sectors - 1);
        int cell = ring * _sectors + sector;
        if (_covered[cell])
        {
            return false;
        }

        _covered[cell] = true;
        CoveredCells++;
        return true;
    }
}
