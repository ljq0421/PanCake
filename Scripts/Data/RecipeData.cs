using Godot;

namespace ProjectCake.Data;

[GlobalClass]
public partial class RecipeData : Resource
{
    [Export]
    public string Id { get; set; } = string.Empty;

    [Export]
    public string DisplayName { get; set; } = string.Empty;

    [Export]
    public int Price { get; set; }

    [Export]
    public Texture2D? Icon { get; set; }

    [Export]
    public Godot.Collections.Array<string> ExtraIngredients { get; set; } = new();
}

