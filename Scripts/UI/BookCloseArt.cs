using Godot;

namespace ProjectCake.UI;

/// <summary>Small paper close seal drawn above a journey book's printed decoration.</summary>
public partial class BookCloseArt : Control
{
    public Color Ink { get; set; } = new("#936249");
    public Color Paper { get; set; } = new("#FFF5E3");
    public Color Sparkle { get; set; } = new("#FFD18E");

    public override void _Draw()
    {
        // The three small strokes sit just left of the seal, like the supplied book reference.
        DrawRay(new(19, 12), new(31, 26));
        DrawRay(new(10, 38), new(28, 41));
        DrawRay(new(19, 65), new(32, 54));
        var center = new Vector2(74, 41);
        DrawCircle(center + new Vector2(2, 4), 32, new Color(0.31f, 0.16f, 0.09f, 0.16f));
        DrawCircle(center, 31, Paper);
        DrawArc(center, 31, 0, Mathf.Tau, 64, Ink, 3.5f, true);
        DrawLine(center + new Vector2(-10, -10), center + new Vector2(10, 10), Ink, 6, true);
        DrawLine(center + new Vector2(10, -10), center + new Vector2(-10, 10), Ink, 6, true);
    }

    private void DrawRay(Vector2 from, Vector2 to)
    {
        DrawLine(from, to, Sparkle, 6, true);
        DrawCircle(from, 3, Sparkle);
        DrawCircle(to, 3, Sparkle);
    }
}
