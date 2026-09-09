using Godot;

namespace ProjectCake.UI;

internal partial class WuhanLedgerLockIcon : Control
{
    public override void _Draw()
    {
        DrawArc(new Vector2(65, 75), 34, Mathf.Pi, Mathf.Tau, 32, WuhanUi.Muted, 8, true);
        DrawStyleBox(WuhanUi.Box(WuhanUi.Disabled, 14, 4, false), new Rect2(15, 74, 100, 78));
        DrawCircle(new Vector2(65, 108), 8, WuhanUi.Ink);
        DrawLine(new Vector2(65, 112), new Vector2(65, 128), WuhanUi.Ink, 7, true);
    }
}
