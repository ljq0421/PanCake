namespace ProjectCake.Orders;

public sealed class DayPlan
{
    [System.Text.Json.Serialization.JsonIgnore] public string StageId { get; init; } = string.Empty;
    [System.Text.Json.Serialization.JsonIgnore] public string RunId { get; init; } = string.Empty;
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
