using ProjectCake.Orders;

namespace ProjectCake.Gameplay;

public enum BusinessCue { ItemAccepted, OrderCompleted, DeliveryError, LowPatience, CustomerLeft, CoinCredited }
public sealed record BusinessFeedbackEvent(BusinessCue Cue, string? CustomerId = null, int Amount = 0);

/// <summary>Semantic business feedback; independent of audio devices and presentation clocks.</summary>
public sealed class BusinessFeedback
{
    private readonly HashSet<string> _warned = new(StringComparer.Ordinal);
    public event Action<BusinessFeedbackEvent>? Requested;
    public event Action? ResetRequested;

    public void Delivery(string? customerId, DeliveryEvaluation result, bool matchesRequestedItem = true)
    {
        BusinessCue cue = result.Grade is DeliveryGrade.Rejected or DeliveryGrade.Incorrect || !matchesRequestedItem
            ? BusinessCue.DeliveryError : result.CompletesOrder ? BusinessCue.OrderCompleted
            : result.ItemAccepted ? BusinessCue.ItemAccepted : BusinessCue.DeliveryError;
        Requested?.Invoke(new(cue, customerId));
    }
    public void Reject(string? customerId = null) => Requested?.Invoke(new(BusinessCue.DeliveryError, customerId));
    public void Warn(string customerId, bool protectedByTutorial = false)
    {
        if (!protectedByTutorial && _warned.Add(customerId)) Requested?.Invoke(new(BusinessCue.LowPatience, customerId));
    }
    public void TimedOut(string customerId) => Requested?.Invoke(new(BusinessCue.CustomerLeft, customerId));
    public void Credit(int amount, string? customerId = null)
    {
        if (amount > 0) Requested?.Invoke(new(BusinessCue.CoinCredited, customerId, amount));
    }
    public void Reset() { _warned.Clear(); ResetRequested?.Invoke(); }
}
