using Godot;

namespace ProjectCake.Data;

public enum CustomerOrderProfile
{
    Standard,
    RegularSignature,
    BigOrder,
}

[GlobalClass]
public partial class CustomerTypeData : Resource
{
    [Export] public string Id { get; set; } = string.Empty;
    [Export] public string DisplayName { get; set; } = string.Empty;
    [Export] public float HappyUntilSeconds { get; set; }
    [Export] public float NormalUntilSeconds { get; set; }
    [Export] public float ImpatientUntilSeconds { get; set; }
    [Export] public float LeaveAtSeconds { get; set; }
    [Export] public float PerfectTipRate { get; set; }
    [Export] public bool IsBigOrderCustomer { get; set; }
    [Export] public CustomerOrderProfile OrderProfile { get; set; }
}
