using Godot;
namespace ProjectCake.Data;
[GlobalClass]
public partial class DoupiGriddleLevelData : Resource
{
    [Export] public int Level { get; set; }
    [Export] public int BatchYield { get; set; } = 8;
    [Export] public float StageSeconds { get; set; } = 2.5f;
    [Export] public float BurnSeconds { get; set; } = 4.5f;
    [Export] public float SecondStageReadySeconds { get; set; } = 3.5f;
    [Export] public float SecondStageOverbrownedSeconds { get; set; } = 6.5f;
    [Export] public float SecondStageBurnSeconds { get; set; } = 8.5f;
    [Export] public bool CanBurn { get; set; } = true;
    [Export] public bool AutoFlip { get; set; }
    [Export] public float SpeedMultiplier { get; set; } = 1f;
    [Export] public int UpgradePrice { get; set; }
}
