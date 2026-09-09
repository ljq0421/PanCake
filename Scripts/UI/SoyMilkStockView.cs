using Godot;

namespace ProjectCake.UI;

/// <summary>Persistent cups in two staggered rows, with one shared take target.</summary>
public partial class SoyMilkStockView : Control
{
    private readonly TextureRect[] _cups;
    public int VisibleCupCount => _cups.Count(cup => cup.Visible);
    public IReadOnlyList<TextureRect> Cups => _cups;

    public SoyMilkStockView(Texture2D texture, int capacity = ProjectCake.Inventory.SoyMilkTrayRuntime.DefaultCapacity)
    {
        _cups = new TextureRect[capacity];
        int columns = (capacity + 1) / 2;
        Name = "SoyMilkStockArt";
        MouseFilter = MouseFilterEnum.Ignore;
        for (int index = 0; index < _cups.Length; index++)
        {
            var cup = TianjinUi.Texture(texture, new Vector2(40, 52));
            cup.Name = $"SoyMilkCupArt{index + 1}";
            cup.MouseFilter = MouseFilterEnum.Ignore;
            // Back row first; removal proceeds from the front-right cup.
            // Position against the whole tray, independently of its input origin.
            // Cups in a row have a visible gap; staggered feet sit on the tray floor.
            int row = index / columns;
            cup.Position = new Vector2(125 + (index % columns - (columns - 1) * .5f) * 34 + (row == 0 ? 3 : -3) - 20,
                row == 0 ? -20 : 6)
                - TianjinWorkbenchLayout.SoyCupInput.Position;
            cup.Size = new Vector2(40, 52);
            cup.ZIndex = row;
            _cups[index] = cup;
            AddChild(cup);
        }
    }

    public void RenderQuantity(int quantity)
    {
        for (int index = 0; index < _cups.Length; index++) _cups[index].Visible = index < quantity;
    }
}
