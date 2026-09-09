using Godot;

namespace ProjectCake.Data;

[GlobalClass]
public partial class IngredientStationLevelData : Resource
{
    [Export] public int Level { get; set; }
    [Export] public int BatterCapacity { get; set; }
    [Export] public int EggCapacity { get; set; }
    [Export] public int SauceCapacity { get; set; }
    [Export] public bool UnlimitedBatter { get; set; }
    [Export] public bool UnlimitedSauce { get; set; }
    [Export] public int CrispyCapacity { get; set; }
    [Export] public int ScallionCapacity { get; set; }
    [Export] public int HamCapacity { get; set; }
    [Export] public int LowStockThreshold { get; set; } = 2;
    [Export] public float RefillSeconds { get; set; } = 1.0f;
    [Export] public int UpgradePrice { get; set; }

    public bool IsUnlimited(string ingredientId) => ingredientId switch
    {
        StableIds.Ingredients.Batter => UnlimitedBatter,
        StableIds.Ingredients.Sauce => UnlimitedSauce,
        _ => false,
    };

    // Unlimited ingredients have no numeric stock; callers use IsUnlimited.
    public int GetCapacity(string ingredientId) => IsUnlimited(ingredientId) ? 0 : ingredientId switch
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
