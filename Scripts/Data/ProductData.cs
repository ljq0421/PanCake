using Godot;

namespace ProjectCake.Data;

[GlobalClass]
public partial class ProductData : Resource
{
    [Export] public string Id { get; set; } = string.Empty;
    [Export] public ProductKind Kind { get; set; }
    [Export] public string DisplayName { get; set; } = string.Empty;
    [Export] public int UnitPrice { get; set; }
    [Export] public Texture2D? Icon { get; set; }
}
