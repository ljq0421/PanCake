namespace ProjectCake.Data;

/// <summary>Opt-in teaching rules shared by all runtime profiles. Ordinary shifts use None.</summary>
public sealed record TutorialProtection
{
    public static TutorialProtection None { get; } = new();
    public static TutorialProtection GuidedExample { get; } = new()
    { FreezeBusinessClocks = true, ProtectPancakeHeat = true, SuppressRevenue = true };

    public bool FreezeBusinessClocks { get; init; }
    public bool ProtectPancakeHeat { get; init; }
    public bool SuppressRevenue { get; init; }
    [System.Text.Json.Serialization.JsonIgnore]
    public bool IsActive => FreezeBusinessClocks || ProtectPancakeHeat || SuppressRevenue;
}
