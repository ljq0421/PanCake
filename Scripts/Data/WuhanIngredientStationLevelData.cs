using Godot;
namespace ProjectCake.Data;
[GlobalClass]
public partial class WuhanIngredientStationLevelData : Resource
{
    [Export] public int Level { get; set; }
    [Export] public int NoodlesCapacity { get; set; }
    [Export] public int LowStockThreshold { get; set; } = 2;
    [Export] public float RefillSeconds { get; set; } = 1f;
    [Export] public int UpgradePrice { get; set; }
    public int GetCapacity(string id) => id == StableIds.Ingredients.WuhanNoodles
        ? NoodlesCapacity : throw new ArgumentException("仅生面条设有库存容量。", nameof(id));
}
