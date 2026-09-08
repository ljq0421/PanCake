using Godot;

namespace ProjectCake.Data;

[GlobalClass]
public partial class GuangzhouEquipmentData : Resource
{
    [Export] public string EquipmentId { get; set; } = "";
    [Export] public string DisplayName { get; set; } = "";
    [Export] public int Level { get; set; } = 1;
    [Export] public int Capacity { get; set; }
    [Export] public double CookSeconds { get; set; }
    [Export] public double HarGowCookSeconds { get; set; }
    [Export] public double BestWindowSeconds { get; set; }
    [Export] public double NormalWindowSeconds { get; set; }
    [Export] public bool KeepWarm { get; set; }
    [Export] public bool PopOut { get; set; }
    [Export] public int UpgradePrice { get; set; }
    [Export] public int UnlockAfterDay { get; set; }
    [Export] public int BatterCapacity { get; set; }
    [Export] public int EggCapacity { get; set; }
    [Export] public int PorkCapacity { get; set; }
    [Export] public int ShrimpCapacity { get; set; }
    [Export] public int SauceCapacity { get; set; }
}
