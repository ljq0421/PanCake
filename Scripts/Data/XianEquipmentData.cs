using Godot;

namespace ProjectCake.Data;

/// <summary>One row per equipment level. Values are shared by simulation and shop.</summary>
[GlobalClass]
public partial class XianEquipmentData : Resource
{
    [Export] public string EquipmentId { get; set; } = "";
    [Export] public int Level { get; set; } = 1;
    [Export] public int Capacity { get; set; }
    [Export] public int StockCapacity { get; set; }
    [Export] public int IngredientCapacity { get; set; }
    [Export] public double ActionSeconds { get; set; }
    [Export] public double RefillSeconds { get; set; }
    [Export] public double WorkMultiplier { get; set; } = 1;
    [Export] public bool BurnProof { get; set; }
    [Export] public bool Automatic { get; set; }
    [Export] public int UpgradePrice { get; set; }
    [Export] public int UnlockAfterDay { get; set; }
}
