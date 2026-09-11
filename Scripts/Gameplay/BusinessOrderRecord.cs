using ProjectCake.Customers;
using ProjectCake.Orders;

namespace ProjectCake.Gameplay;

/// <summary>Immutable, session-only snapshot taken at the business outcome boundary.</summary>
public sealed record BusinessOrderRecord(string OrderId, string CustomerId, string CustomerName,
    string AppearanceId, IReadOnlyList<OrderLineData> Lines, bool Lost, DeliveryEvaluation? Evaluation)
{
    public static BusinessOrderRecord Capture(CustomerRuntime customer, DeliveryEvaluation? evaluation) =>
        new(customer.Order.OrderId, customer.Id, customer.Type.DisplayName, customer.AppearanceId,
            Array.AsReadOnly(customer.Order.Lines.ToArray()), evaluation is null, evaluation);
}
