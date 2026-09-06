using Godot;
namespace ProjectCake.Data;
[GlobalClass]
public partial class WuhanIngredientStationLevelData : Resource
{
    [Export] public int Level { get; set; }
    [Export] public int NoodlesCapacity { get; set; }
    [Export] public int BaseSeasoningCapacity { get; set; }
    [Export] public int ScallionCapacity { get; set; }
    [Export] public int ChiliOilCapacity { get; set; }
    [Export] public int BraisedBeefCapacity { get; set; }
    [Export] public int LowStockThreshold { get; set; } = 2;
    [Export] public float RefillSeconds { get; set; } = 1f;
    [Export] public int UpgradePrice { get; set; }
    public int GetCapacity(string id) => id switch
    {
        StableIds.Ingredients.WuhanNoodles => NoodlesCapacity, StableIds.Ingredients.WuhanBaseSeasoning => BaseSeasoningCapacity,
        StableIds.Ingredients.WuhanScallion => ScallionCapacity, StableIds.Ingredients.WuhanChiliOil => ChiliOilCapacity,
        StableIds.Ingredients.WuhanBraisedBeef => BraisedBeefCapacity, _ => throw new KeyNotFoundException($"未知武汉食材 ID：{id}。"),
    };
}
