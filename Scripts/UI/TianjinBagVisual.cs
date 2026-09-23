using Godot;

namespace ProjectCake.UI;

// Reuses the existing painted paper for both the flat stack and the moving bag.
public partial class TianjinBagVisual : Control
{
    private Texture2D _paper = null!, _food = null!, _finished = null!;
    private Rect2 _paperRegion;
    private Vector2 _foodCenter, _position, _from;
    private Color _foodTint = Colors.White;
    private bool _held, _commit;
    private float _time, _opening, _fromOpening;
    public bool Animating { get; private set; }
    public bool OverFood { get; private set; }
    public Rect2 StackBounds => TianjinWorkbenchLayout.EmbeddedBagStack;
    private static readonly Vector2 PaperPivot = new(647, 765);
    private static readonly Vector2[] Rim = new Vector2[] { new(293, 533), new(329, 546), new(373, 560),
        new(412, 582), new(507, 558), new(630, 535), new(757, 517), new(792, 523),
        new(852, 510), new(925, 498), new(970, 476) }.Select(p => p + new Vector2(0, 8)).ToArray();
    private static readonly Vector2[] Wall = Rim.Concat(new[] { new Vector2(990, 490),
        new Vector2(988, 622), new Vector2(1008, 755), new Vector2(1023, 886),
        new Vector2(1005, 922), new Vector2(467, 1045), new Vector2(420, 1038),
        new Vector2(279, 931), new Vector2(271, 907), new Vector2(303, 657), new Vector2(287, 557) }).ToArray();

    public void Configure(Texture2D food, Texture2D finished)
    {
        _food = food; _finished = finished;
        _paper = GD.Load<Texture2D>("res://resource/art/TianJin/装袋后的通用煎饼果子.png");
        _paperRegion = finished is AtlasTexture atlas ? atlas.Region : new Rect2(Vector2.Zero, finished.GetSize());
        Show(); QueueRedraw();
    }
    public override bool _HasPoint(Vector2 point) => StackBounds.HasPoint(point);
    public void Begin(Vector2 foodCenter, Color tint)
    {
        Cancel(); _foodCenter = foodCenter; _position = StackBounds.GetCenter();
        _foodTint = tint; _held = true; QueueRedraw();
    }
    public void MoveBag(Vector2 point, bool reduced)
    {
        OverFood = new Rect2(_foodCenter - new Vector2(120, 95), new Vector2(240, 190)).HasPoint(point);
        _opening = Mathf.Clamp(1 - point.DistanceTo(_foodCenter) / 240, 0, 1);
        _position = OverFood && !reduced ? point.Lerp(_foodCenter + new Vector2(0, 40), .18f) : point;
        QueueRedraw();
    }
    public void Release(bool commit, bool reduced)
    {
        _held = false; _commit = commit; _from = _position; _fromOpening = _opening; _time = 0;
        Animating = !reduced;
        if (reduced) Cancel();
        QueueRedraw();
    }
    public bool Tick(float delta, bool reduced)
    {
        if (!Animating) return false;
        _time += Math.Max(0, delta);
        float t = Mathf.Clamp(_time / (_commit ? .28f : .16f), 0, 1);
        float ease = 1 - Mathf.Pow(1 - t, 3);
        _position = _from.Lerp(_commit ? _foodCenter : StackBounds.GetCenter(), ease);
        _opening = Mathf.Lerp(_fromOpening, _commit ? 1 : 0, ease);
        if (reduced || t >= 1) { Cancel(); return true; }
        QueueRedraw(); return false;
    }
    public void Cancel()
    {
        _held = false; Animating = false; OverFood = false; _opening = 0; QueueRedraw();
    }
    private static Vector2 StackPoint(Vector2 pixel, Vector2 center) =>
        center + ((pixel - PaperPivot) * .23f).Rotated(Mathf.Pi / 2) * new Vector2(1.15f, .42f);
    private Rect2 FinishedRect(Vector2 center)
    {
        Vector2 size = _finished.GetSize();
        size *= Math.Min(260 / size.X, 260 / size.Y);
        return new Rect2(center - size * .5f, size);
    }
    private Vector2 OpenPoint(Vector2 pixel, Vector2 center)
    {
        Rect2 rect = FinishedRect(center);
        return rect.Position + (pixel - _paperRegion.Position) / _paperRegion.Size * rect.Size;
    }
    private void DrawPaper(Vector2 center, float opening, float alpha = 1)
    {
        Vector2 Map(Vector2 p) => StackPoint(p, center).Lerp(OpenPoint(p, center), opening);
        Vector2[] front = Rim.Select(Map).ToArray();
        Vector2[] back = Rim.Select(p => Map(p + new Vector2(0, -10 - 25 * opening))).ToArray();
        DrawColoredPolygon(back.Concat(front.Reverse()).ToArray(), new Color(.36f, .19f, .08f, alpha));
        DrawPolygon(Wall.Select(Map).ToArray(), new[] { new Color(1, 1, 1, alpha) },
            Wall.Select(p => p / 1280).ToArray(), _paper);
    }
    public override void _Draw()
    {
        if (_paper is null) return;
        // The v3 background owns the paper stack at rest. Draw only the sheet
        // being moved so the painted stack is not duplicated or misaligned.
        if (!_held && !Animating) return;
        if (!_commit || _held)
        {
            DrawPaper(_position + new Vector2(0, 34 * _opening), _opening);
            return;
        }
        float t = Mathf.Clamp(_time / .28f, 0, 1);
        float settle = Mathf.SmoothStep(.5f, 1, t);
        // A small lift frees the bottom edge; the paper slides up and encloses it.
        Vector2 foodPosition = _foodCenter + new Vector2(0, -9 * Mathf.Sin(t * Mathf.Pi));
        Vector2 size = new(260, 220);
        DrawTextureRect(_food, new Rect2(foodPosition - size * .5f, size), false,
            new Color(_foodTint, 1 - settle));
        DrawPaper(_position + new Vector2(0, 34 * _fromOpening * (1 - t)), _opening, 1 - settle);
        DrawTextureRect(_finished, FinishedRect(_foodCenter), false, new Color(1, 1, 1, settle));
    }
}
