using Godot;

namespace ProjectCake.UI;

// Reuses the painted paper portion of the existing product texture as a native
// textured mesh. The moving food is drawn between the back lip and front wall.
public partial class TianjinBagVisual : Control
{
    private Texture2D _paper = null!, _food = null!;
    private Vector2 _foodPosition, _home, _from;
    private Color _foodTint = Colors.White;
    private bool _held, _commit;
    private float _time, _opening;
    public bool Animating { get; private set; }
    public bool NearMouth { get; private set; }
    public Rect2 Mouth => new(520, 757, 182, 80);
    internal Vector2[] FocusOutline => Wall.Select(Map).ToArray();
    private static readonly Rect2 ArtRect = new(461, 666, 288, 316);
    // Pixel coordinates on the 1280 reference, normalized at draw time.
    private static readonly Vector2[] Rim = new Vector2[] { new(293, 533), new(329, 546), new(373, 560),
        new(412, 582), new(507, 558), new(630, 535), new(757, 517), new(792, 523),
        new(852, 510), new(925, 498), new(970, 476) }.Select(p => p + new Vector2(0, 8)).ToArray();
    private static readonly Vector2[] Wall = Rim.Concat(new[] { new Vector2(990, 490),
        new Vector2(988, 622), new Vector2(1008, 755), new Vector2(1023, 886),
        new Vector2(1005, 922), new Vector2(467, 1045), new Vector2(420, 1038),
        new Vector2(279, 931), new Vector2(271, 907), new Vector2(303, 657), new Vector2(287, 557) }).ToArray();

    public void Configure(Texture2D food)
    {
        _food = food;
        _paper = GD.Load<Texture2D>("res://resource/art/TianJin/装袋后的通用煎饼果子.png");
        Hide();
    }
    public void Begin(Vector2 home, Color tint)
    {
        Cancel(); _home = _foodPosition = home; _foodTint = tint; _held = true; Show(); QueueRedraw();
    }
    public void MoveFood(Vector2 point, bool reduced)
    {
        NearMouth = Mouth.Grow(18).HasPoint(point);
        _opening = Mathf.Clamp(1 - point.DistanceTo(Mouth.GetCenter()) / 190, 0, 1);
        // Small magnetic assistance; never accepts a release outside the generous mouth.
        _foodPosition = NearMouth && !reduced ? point.Lerp(Mouth.GetCenter() + new Vector2(0, -48), .18f) : point;
        QueueRedraw();
    }
    public void Release(bool commit, bool reduced)
    {
        _held = false; _commit = commit; _from = _foodPosition; _time = 0;
        Animating = !reduced;
        if (reduced) Cancel();
        QueueRedraw();
    }
    public bool Tick(float delta, bool reduced)
    {
        if (!Animating) return false;
        _time += Math.Max(0, delta);
        float duration = _commit ? .28f : .16f;
        float t = Mathf.Clamp(_time / duration, 0, 1);
        _foodPosition = _from.Lerp(_commit ? Mouth.GetCenter() + new Vector2(0, 15) : _home, 1 - Mathf.Pow(1 - t, 3));
        _opening = _commit ? 1 - t : _opening * (1 - t);
        if (reduced || t >= 1) { Cancel(); return true; }
        QueueRedraw(); return false;
    }
    public void Cancel()
    {
        _held = false; Animating = false; NearMouth = false; _opening = 0; QueueRedraw();
    }
    private static Vector2 Map(Vector2 pixel) => ArtRect.Position + pixel / 1280 * ArtRect.Size;
    public override void _Draw()
    {
        if (_paper is null) return;
        Vector2[] front = Rim.Select(Map).ToArray();
        Vector2[] back = front.Select(p => p + new Vector2(0, -5 - 16 * _opening)).ToArray();
        float sway = Animating && _commit ? Mathf.Sin(_time / .28f * Mathf.Tau) * .025f : 0;
        Vector2 pivot = new(610, 920);
        DrawSetTransform(pivot, sway);
        Vector2[] opening = back.Concat(front.Reverse()).Select(p => p - pivot).ToArray();
        DrawColoredPolygon(opening, new Color("#6d391c"));
        DrawPolyline(back.Select(p => p - pivot).ToArray(), new Color("#ecc493"), 5, true);
        DrawSetTransform(Vector2.Zero);
        if (_held || Animating)
        {
            float t = Animating && _commit ? Mathf.Clamp(_time / .28f, 0, 1) : 0;
            Vector2 size = new Vector2(260, 220).Lerp(new Vector2(158, 145), t);
            DrawTextureRect(_food, new Rect2(_foodPosition - size * .5f, size), false, _foodTint);
        }
        DrawSetTransform(pivot, sway);
        DrawPolygon(Wall.Select(p => Map(p) - pivot).ToArray(), new[] { Colors.White },
            Wall.Select(p => p / 1280).ToArray(), _paper);
        DrawPolyline(front.Select(p => p - pivot).ToArray(), new Color("#603416"), 2.5f, true);
        DrawSetTransform(Vector2.Zero);
    }
}
