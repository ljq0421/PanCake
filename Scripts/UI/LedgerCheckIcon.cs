using Godot;

namespace ProjectCake.UI;

internal partial class LedgerCheckIcon : Control
{
    public override void _Draw() => DrawPolyline(new[] { new Vector2(2, 14), new Vector2(11, 23), new Vector2(27, 3) }, TianjinUi.Brown, 5, true);
}
