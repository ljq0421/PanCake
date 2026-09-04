using Godot;

namespace ProjectCake.Data;

[GlobalClass]
public partial class IngredientStationLevelData : Resource
{
    [Export] public int Level { get; set; }
    [Export] public int BatterCapacity { get; set; }
    [Export] public int EggCapacity { get; set; }
    [Export] public int SauceCapacity { get; set; }
    [Export] public int CrispyCapacity { get; set; }
    [Export] public int ScallionCapacity { get; set; }
    [Export] public int HamCapacity { get; set; }
    [Export] public float RefillSeconds { get; set; } = 1.0f;
    [Export] public int UpgradePrice { get; set; }

    public int GetCapacity(string ingredientId) => ingredientId switch
    {
        StableIds.Ingredients.Batter => BatterCapacity,
        StableIds.Ingredients.Egg => EggCapacity,
        StableIds.Ingredients.Sauce => SauceCapacity,
        StableIds.Ingredients.Crispy => CrispyCapacity,
        StableIds.Ingredients.Scallion => ScallionCapacity,
        StableIds.Ingredients.Ham => HamCapacity,
        _ => throw new KeyNotFoundException($"未知食材 ID：{ingredientId}。"),
    };
}
