using System.Text.Json;
using System.Text.Json.Serialization;
using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Core;

public sealed class DemoOrder
{
    public string CustomerTypeId { get; init; } = "normal";
    public required OrderLineData[] Lines { get; init; }
}
public sealed class DemoStage
{
    public required string Id { get; init; }
    public string CityId { get; init; } = StableIds.Cities.Tianjin;
    public int Day { get; init; }
    public required string TitleZh { get; init; }
    public required string TitleEn { get; init; }
    public double DurationSeconds { get; init; }
    public double PatienceMultiplier { get; init; }
    public required double[] Arrivals { get; init; }
    public string[] Recipes { get; init; } = Array.Empty<string>();
    public DemoOrder[] Orders { get; init; } = Array.Empty<DemoOrder>();
    public required string[] AvailableRecipes { get; init; }
    public ProductKind[] AvailableProducts { get; init; } = new[] { ProductKind.Pancake };
    public string[] StartUnlocks { get; init; } = Array.Empty<string>();
    public required string[] CompletionUnlocks { get; init; }
    public string Tutorial { get; init; } = "";
}

// Read-only legacy format: never used to generate current days or orders.
public sealed class DemoCatalog
{
    public required string ProfileId { get; init; }
    public int ContentRevision { get; init; }
    public required DemoStage[] Stages { get; init; }
    public static readonly JsonSerializerOptions JsonOptions = new()
    { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow, WriteIndented = true };
    public DemoStage? Stage(string id) => Stages.FirstOrDefault(s => s.Id == id);
}
