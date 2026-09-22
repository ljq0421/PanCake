namespace ProjectCake.Orders;

public sealed class DayPlan
{
    [System.Text.Json.Serialization.JsonIgnore]
    public Dictionary<string, int> PendingCustomerVisits { get; } = new(StringComparer.Ordinal);
    [System.Text.Json.Serialization.JsonIgnore]
    public HashSet<string> RecordedCustomerOrders { get; } = new(StringComparer.Ordinal);
    public ProjectCake.Core.DailyChallenge? Challenge { get; init; }
    [System.Text.Json.Serialization.JsonIgnore]
    public Dictionary<string, ProjectCake.Core.BreakfastStatistics> PendingBreakfastStats { get; } = new(StringComparer.Ordinal);
    [System.Text.Json.Serialization.JsonIgnore]
    public HashSet<string> PendingBreakfastRecords { get; } = new(StringComparer.Ordinal);
    [System.Text.Json.Serialization.JsonIgnore] public string StageId { get; init; } = string.Empty;
    [System.Text.Json.Serialization.JsonIgnore] public string RunId { get; init; } = Guid.NewGuid().ToString("N");
    public int Day { get; init; }
    public int RandomSeed { get; init; }
    public IReadOnlyList<PlannedCustomer> Customers { get; init; } = Array.Empty<PlannedCustomer>();
}

public sealed class PlannedCustomer
{
    public required string CustomerId { get; init; }
    public required string CustomerTypeId { get; init; }
    public double ArrivalTime { get; init; }
    public required OrderData Order { get; set; }
}
