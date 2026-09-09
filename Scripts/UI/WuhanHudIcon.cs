using Godot;

namespace ProjectCake.UI;

public partial class WuhanHudIcon : Control
{
    public string Kind { get; set; } = "clock";
    public override void _Draw()
    {
        Color ink = WuhanUi.Ink;
        void Line(Vector2 a, Vector2 b) => DrawLine(a, b, ink, 2.5f, true);
        if (Kind == "day")
        {
            DrawArc(new(15, 15), 6, 0, Mathf.Tau, 24, ink, 2.5f, true);
            for (int i = 0; i < 8; i++) { Vector2 d = Vector2.FromAngle(i * Mathf.Tau / 8); Line(new Vector2(15, 15) + d * 10, new Vector2(15, 15) + d * 14); }
        }
        else if (Kind == "exit")
        {
            Line(new(12, 4), new(4, 4)); Line(new(4, 4), new(4, 26)); Line(new(4, 26), new(12, 26));
            Line(new(10, 15), new(27, 15)); Line(new(27, 15), new(21, 9)); Line(new(27, 15), new(21, 21));
        }
        else
        {
            DrawArc(new(15, 15), 12, 0, Mathf.Tau, 32, ink, 2.5f, true);
            Line(new(15, 15), new(15, 7)); Line(new(15, 15), new(22, 18));
        }
    }
}
