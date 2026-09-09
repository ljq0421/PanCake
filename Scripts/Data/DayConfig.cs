using System.Text.Json.Serialization;

namespace ProjectCake.Data;

[JsonConverter(typeof(JsonStringEnumConverter<ProductKind>))]
public enum ProductKind
{
    Pancake,
    Youtiao,
    SoyMilk,
    HotDryNoodles,
    Doupi,
    EggRiceWine,
    Roujiamo,
    Hulatang,
    RiceRoll,
    SiuMai,
    HarGow,
    MorningTea,
}

[JsonConverter(typeof(JsonStringEnumConverter<SatisfactionAverageMode>))]
public enum SatisfactionAverageMode
{
    PlannedCustomers,
    CompletedCustomers,
}

public sealed class DayConfig
{
    [JsonIgnore]
    public string SourcePath { get; set; } = string.Empty;

    public string CityId { get; set; } = StableIds.Cities.Tianjin;

    public SatisfactionAverageMode SatisfactionAverageMode { get; set; } = SatisfactionAverageMode.CompletedCustomers;

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
    public GuangzhouDaySettings? Guangzhou { get; set; }
}

public sealed class GuangzhouDaySettings
{
    public Dictionary<string, double> DimSumWeights { get; set; } = new();
    public double EmptyStockWeightMultiplier { get; set; } = .2;
    public int WaitingOrdersThreshold { get; set; } = 2;
}

public sealed class StarGoalConfig
{
    public int? MaximumIncorrectOrders { get; set; }
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
    public int MaxDoubleOrders { get; set; } = int.MaxValue;
    public int MaxSimultaneousDoubleOrders { get; set; } = int.MaxValue;
    public double WaitingPressureThreshold { get; set; }
    public double AdditionalPressureThreshold { get; set; }
    [JsonRequired]
    public int MaxBigOrderCustomers { get; set; }

    [JsonRequired]
    public int SimpleNewProductOrders { get; set; }

    [JsonRequired]
    public int MaxConsecutiveYoutiaoOrders { get; set; }

    [JsonRequired]
    public int MaxPancakesPerCustomer { get; set; }

    public int MaxConsecutiveComplexOrders { get; set; } = 2;

    public double PressureDelaySeconds { get; set; }

    public double MaxPressureDelaySeconds { get; set; }
}
