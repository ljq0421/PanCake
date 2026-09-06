using Godot;
namespace ProjectCake.Data;
[GlobalClass]
public partial class NoodleCookerLevelData : Resource
{
    [Export] public int Level { get; set; }
    [Export] public int BasketCount { get; set; } = 1;
    [Export] public float OptimalSeconds { get; set; } = 1.6f;
    [Export] public float SoftUntilSeconds { get; set; } = 3f;
    [Export] public float OvercookedSeconds { get; set; } = 4f;
    [Export] public bool AutoLockOptimal { get; set; }
    [Export] public bool AutoRaise { get; set; }
    [Export] public float NaturalDrainSeconds { get; set; } = .7f;
    [Export] public float QuickDrainSeconds { get; set; } = .35f;
    [Export] public int UpgradePrice { get; set; }
}
