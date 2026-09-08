using Godot;

namespace ProjectCake.UI;

/// <summary>Six persistent cups; one shared take target remains owned by the workstation.</summary>
public partial class SoyMilkStockView : Control
{
    private readonly TextureRect[] _cups = new TextureRect[6];
    public int VisibleCupCount => _cups.Count(cup => cup.Visible);
    public IReadOnlyList<TextureRect> Cups => _cups;

    public SoyMilkStockView(Texture2D texture)
    {
        Name = "SoyMilkStockArt";
        MouseFilter = MouseFilterEnum.Ignore;
        for (int index = 0; index < _cups.Length; index++)
        {
            var cup = TianjinUi.Texture(texture, new Vector2(44, 52));
            cup.Name = $"SoyMilkCupArt{index + 1}";
            cup.MouseFilter = MouseFilterEnum.Ignore;
            // Back row first; removal proceeds from the front-right cup.
            // Position against the whole tray, independently of its input origin.
            // Cups in a row have a visible gap; staggered feet sit on the tray floor.
            cup.Position = new Vector2(30 + index % 3 * 69 + index / 3 * 8, -18 + index / 3 * 24)
                - TianjinWorkbenchLayout.SoyCupInput.Position;
            cup.Size = new Vector2(44, 52);
            _cups[index] = cup;
            AddChild(cup);
        }
    }

    public void RenderQuantity(int quantity)
    {
        for (int index = 0; index < _cups.Length; index++) _cups[index].Visible = index < quantity;
    }
}
