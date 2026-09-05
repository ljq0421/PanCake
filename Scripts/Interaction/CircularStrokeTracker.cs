using Godot;

namespace ProjectCake.Interaction;

/// <summary>
/// Tracks a forgiving circular gesture in normalized ellipse space. Progress survives
/// separate pointer presses, while gaps between presses and out-of-band movement never
/// contribute angular travel.
/// </summary>
public sealed class CircularStrokeTracker
{
    public const int SectorCount = 8;
    public const int RequiredSectors = 7;
    public const float RequiredRadians = Mathf.Pi * 11.0f / 6.0f;
    public const float MinimumNormalizedRadius = 0.32f;
    public const float MaximumNormalizedRadius = 1.12f;
    public const float MaximumSampleRadians = Mathf.Pi / 3.0f;

    private readonly bool[] _visited = new bool[SectorCount];
    private float? _lastAngle;
    private float _signedTravel;

    public float AngularProgress => Mathf.Clamp(Mathf.Abs(_signedTravel) / RequiredRadians, 0, 1);
    public float SectorProgress => Mathf.Clamp((float)VisitedSectors / RequiredSectors, 0, 1);
    public float SignedTravel => _signedTravel;
    public double Progress => Math.Min(AngularProgress, SectorProgress);
    public int VisitedSectors { get; private set; }
    public bool IsComplete => Mathf.Abs(_signedTravel) >= RequiredRadians && VisitedSectors >= RequiredSectors;

    public void BeginStroke(Vector2 point, Vector2 center, Vector2 radii)
    {
        _lastAngle = TryGetAngle(point, center, radii, out float angle) ? angle : null;
        if (_lastAngle.HasValue)
        {
            MarkSector(angle);
        }
    }

    public bool AddPoint(Vector2 point, Vector2 center, Vector2 radii)
    {
        if (!TryGetAngle(point, center, radii, out float angle))
        {
            _lastAngle = null;
            return false;
        }

        MarkSector(angle);
        if (!_lastAngle.HasValue)
        {
            _lastAngle = angle;
            return false;
        }

        float delta = Mathf.AngleDifference(_lastAngle.Value, angle);
        _lastAngle = angle;
        if (Mathf.Abs(delta) > MaximumSampleRadians)
        {
            return false;
        }

        float previousTravel = _signedTravel;
        _signedTravel += delta;
        return !Mathf.IsEqualApprox(previousTravel, _signedTravel);
    }

    public void EndStroke() => _lastAngle = null;

    public void Reset()
    {
        Array.Fill(_visited, false);
        VisitedSectors = 0;
        _lastAngle = null;
        _signedTravel = 0;
    }

    private static bool TryGetAngle(Vector2 point, Vector2 center, Vector2 radii, out float angle)
    {
        angle = 0;
        if (radii.X <= 0 || radii.Y <= 0)
        {
            return false;
        }

        Vector2 normalized = new((point.X - center.X) / radii.X, (point.Y - center.Y) / radii.Y);
        float radius = normalized.Length();
        if (radius < MinimumNormalizedRadius || radius > MaximumNormalizedRadius)
        {
            return false;
        }

        angle = Mathf.Atan2(normalized.Y, normalized.X);
        return true;
    }

    private void MarkSector(float angle)
    {
        float normalized = Mathf.PosMod(angle, Mathf.Tau);
        int sector = Math.Min(SectorCount - 1, Mathf.FloorToInt(normalized / Mathf.Tau * SectorCount));
        if (_visited[sector])
        {
            return;
        }

        _visited[sector] = true;
        VisitedSectors++;
    }
}
