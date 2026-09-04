using Godot;

namespace ProjectCake.Data;

[GlobalClass]
public partial class PancakeStoveLevelData : Resource
{
    [Export]
    public int Level { get; set; }

    [Export]
    public bool CanBurn { get; set; }

    [Export]
    public float SideAReadySeconds { get; set; }

    [Export]
    public float SideAOverdoneSeconds { get; set; }

    [Export]
    public float SideBReadySeconds { get; set; }

    [Export]
    public float SideABurnSeconds { get; set; }

    [Export]
    public float SideBBurnSeconds { get; set; }

    [Export]
    public int UpgradePrice { get; set; }
}
