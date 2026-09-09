using Godot;

namespace ProjectCake.UI;

internal partial class LedgerLockIcon : Control
{
    public override void _Draw()
    {
        DrawArc(new Vector2(65, 75), 34, Mathf.Pi, Mathf.Tau, 32, TianjinUi.Brown, 8, true);
        DrawStyleBox(TianjinUi.Box(TianjinUi.CreamMuted, 14, 4, false), new Rect2(15, 74, 100, 78));
        DrawCircle(new Vector2(65, 108), 8, TianjinUi.BrownDark);
        DrawLine(new Vector2(65, 112), new Vector2(65, 128), TianjinUi.BrownDark, 7, true);
    }
}
