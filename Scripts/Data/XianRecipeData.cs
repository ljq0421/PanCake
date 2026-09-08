using Godot;

namespace ProjectCake.Data;

[GlobalClass]
public partial class XianRecipeData : RecipeData
{
    [Export] public int MeatPortions { get; set; } = 1;
    [Export] public bool HasJuice { get; set; }
}
