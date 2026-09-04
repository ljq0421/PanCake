using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Pancake;

namespace ProjectCake.Orders;

public enum OrderStatus
{
    Planned,
    Waiting,
    Completed,
    Lost,
}

public sealed record OrderLineData(ProductKind ProductKind, string DefinitionId, int Quantity);

public sealed class OrderData
{
    public required string OrderId { get; init; }
    public required string CustomerTypeId { get; init; }
    public required IReadOnlyList<OrderLineData> Lines { get; init; }
    public double CreatedTime { get; init; }
    public double PatienceSeconds { get; init; }
    public int BasePrice { get; init; }
    public OrderStatus Status { get; set; } = OrderStatus.Planned;

    public string PancakeRecipeId => Lines.FirstOrDefault(line => line.ProductKind == ProductKind.Pancake)?.DefinitionId ?? string.Empty;
}

public enum DeliveryGrade
{
    Perfect,
    Correct,
    Incorrect,
    Incomplete,
    Rejected,
}

public sealed record DeliveryEvaluation(
    DeliveryGrade Grade,
    int SaleRevenue,
    int Tip,
    int SatisfactionScore,
    string Message,
    bool ItemAccepted = false)
{
    public int TotalRevenue => SaleRevenue + Tip;
    public bool CompletesOrder => Grade is DeliveryGrade.Perfect or DeliveryGrade.Correct or DeliveryGrade.Incorrect;
}

public sealed record DeliveredItem(
    ProductKind ProductKind,
    string DefinitionId,
    PancakeQuality? PancakeQuality = null,
    YoutiaoQuality? YoutiaoQuality = null,
    YoutiaoQuality? InternalYoutiaoQuality = null);
