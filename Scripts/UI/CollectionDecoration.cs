using Godot;
namespace ProjectCake.UI;

/// <summary>Paper, perforations and ink marks drawn at the book's native canvas scale.</summary>
public partial class CollectionDecoration : Control
{
    public string Kind { get; set; } = "paper";
    public Color Ink { get; set; } = new("#CEAD80");
    public Color Fill { get; set; } = new("#FFF5DF");
    public bool Selected { get; set; }
    public override void _Ready() => MouseFilter = MouseFilterEnum.Ignore;
    public override void _Draw()
    {
        var c = Size / 2;
        if (Kind == "lock")
        {
            DrawArc(c + new Vector2(0, -9), 12, Mathf.Pi, Mathf.Tau, 24, Ink, 5, true);
            DrawStyleBox(TianjinUi.Box(Ink, 4, 0, false), new Rect2(c.X - 17, c.Y - 8, 34, 28));
            DrawCircle(c + new Vector2(0, 2), 3, Fill); DrawLine(c + new Vector2(0, 2), c + new Vector2(0, 11), Fill, 3, true); return;
        }
        if (Kind == "check")
        {
            DrawCircle(c, 17, Ink); DrawArc(c, 17, 0, Mathf.Tau, 32, Fill, 2, true);
            DrawPolyline(new[] { c + new Vector2(-8, 0), c + new Vector2(-2, 6), c + new Vector2(9, -7) }, Fill, 4, true); return;
        }
        if (Kind == "stamp")
        {
            float r = Math.Min(Size.X, Size.Y) / 2 - 5;
            DrawArc(c, r, 0, Mathf.Tau, 80, Ink, 3, true);
            DrawArc(c, r - 7, 0, Mathf.Tau, 80, Ink, 1, true);
            DrawLine(c + new Vector2(-r * .67f, 12), c + new Vector2(r * .67f, 12), Ink, 1, true);
            for (int i = -1; i <= 1; i++) DrawCircle(c + new Vector2(i * 17, -r * .65f), 2.5f, Ink);
            return;
        }
        var box = TianjinUi.Box(Fill, Kind == "photo" ? 2 : 8, Selected ? 4 : 1, true);
        box.ShadowSize = 3; box.ShadowOffset = new(1, 3); box.ShadowColor = new Color("#62442B28");
        box.BorderColor = Selected ? new Color("#E79C25") : Ink;
        DrawStyleBox(box, new Rect2(Vector2.Zero, Size));
        if (Kind == "postage")
        {
            for (float x = 9; x < Size.X - 5; x += 13)
            { DrawCircle(new(x, 0), 3, new("#F5E8CE")); DrawCircle(new(x, Size.Y), 3, new("#F5E8CE")); }
            for (float y = 9; y < Size.Y - 5; y += 13)
            { DrawCircle(new(0, y), 3, new("#F5E8CE")); DrawCircle(new(Size.X, y), 3, new("#F5E8CE")); }
            DrawRect(new Rect2(10, 10, Size.X - 20, Size.Y - 20), Ink with { A = .3f }, false, 1);
        }
        if (Kind == "photo")
        {
            DrawRect(new Rect2(14, 14, Size.X - 28, Size.Y - 60), new Color("#D9E7E9"));
            DrawColoredPolygon(new[] { new Vector2(-10, 9), new Vector2(68, -18), new Vector2(83, 9), new Vector2(4, 38) }, new Color("#EBCB93CC"));
        }
    }
}
