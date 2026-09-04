using System.Text.Json.Serialization;

namespace ProjectCake.Data;

[JsonConverter(typeof(JsonStringEnumConverter<ProductKind>))]
public enum ProductKind
{
    Pancake,
    Youtiao,
    SoyMilk,
}

public sealed class DayConfig
{
    [JsonIgnore]
    public string SourcePath { get; set; } = string.Empty;

    [JsonRequired]
    public int Day { get; set; }

    [JsonRequired]
    public double DurationSeconds { get; set; }

    [JsonRequired]
    public int CustomerCount { get; set; }

    [JsonRequired]
    public int ExpectedRevenue { get; set; }

    [JsonRequired]
    public double PatienceMultiplier { get; set; }

    [JsonRequired]
    public int MaxWaitingCustomers { get; set; }

    [JsonRequired]
    public int RandomSeed { get; set; }

    [JsonRequired]
    public Dictionary<string, double> CustomerWeights { get; set; } = new();

    [JsonRequired]
    public Dictionary<string, double> OrderTypeWeights { get; set; } = new();

    [JsonRequired]
    public Dictionary<string, double> RecipeWeights { get; set; } = new();

    [JsonRequired]
    public List<ArrivalSegmentConfig> ArrivalSegments { get; set; } = new();

    [JsonRequired]
    public List<string> StartUnlocks { get; set; } = new();

    [JsonRequired]
    public List<string> CompletionUnlocks { get; set; } = new();

    [JsonRequired]
    public List<string> AvailableRecipeIds { get; set; } = new();

    [JsonRequired]
    public List<ProductKind> AvailableProductKinds { get; set; } = new();

    [JsonRequired]
    public DayConstraintConfig Constraints { get; set; } = new();

    public List<StarGoalConfig> StarGoals { get; set; } = new();
}

public sealed class StarGoalConfig
{
    [JsonRequired]
    public int Stars { get; set; }

    [JsonRequired]
    public int MinimumCompletedCustomers { get; set; }

    [JsonRequired]
    public double MinimumSatisfaction { get; set; }

    [JsonRequired]
    public int MinimumPerfectOrders { get; set; }
}

public sealed class ArrivalSegmentConfig
{
    [JsonRequired]
    public double Start { get; set; }

    [JsonRequired]
    public double End { get; set; }

    [JsonRequired]
    public double CustomerRatio { get; set; }
}

public sealed class DayConstraintConfig
{
    [JsonRequired]
    public int MaxBigOrderCustomers { get; set; }

    [JsonRequired]
    public int SimpleNewProductOrders { get; set; }

    [JsonRequired]
    public int MaxConsecutiveYoutiaoOrders { get; set; }

    [JsonRequired]
    public int MaxPancakesPerCustomer { get; set; }
}
