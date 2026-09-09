using Godot;

namespace ProjectCake.UI;

/// <summary>Persistent cups in two staggered rows, with one shared take target.</summary>
public partial class SoyMilkStockView : Control
{
    private readonly TextureRect[] _cups = new TextureRect[ProjectCake.Inventory.SoyMilkTrayRuntime.DefaultCapacity];
    public int VisibleCupCount => _cups.Count(cup => cup.Visible);
    public IReadOnlyList<TextureRect> Cups => _cups;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
    }

    public void Configure(Texture2D texture)
    {
        foreach (TextureRect cup in _cups) cup.Texture = texture;
    }

    public void RenderQuantity(int quantity)
    {
        for (int index = 0; index < _cups.Length; index++) _cups[index].Visible = index < quantity;
    }
}
