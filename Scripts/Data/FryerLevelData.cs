using Godot;

namespace ProjectCake.Data;

[GlobalClass]
public partial class FryerLevelData : Resource
{
    [Export] public int Level { get; set; }
    [Export] public int Capacity { get; set; }
    [Export] public float GoldenStartSeconds { get; set; }
    [Export] public float GoldenEndSeconds { get; set; }
    [Export] public float BurnAtSeconds { get; set; }
    [Export] public bool AutoRaise { get; set; }
    [Export] public float AutoRaiseAtSeconds { get; set; }
    [Export] public float DrainSeconds { get; set; } = 0.6f;
    [Export] public int UpgradePrice { get; set; }
}
