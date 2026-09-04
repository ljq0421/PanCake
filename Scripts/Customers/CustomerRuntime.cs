using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Customers;

public enum CustomerState
{
    ArrivalDelayed,
    DoorWaiting,
    Entering,
    Happy,
    Normal,
    Impatient,
    Angry,
    Served,
    Leaving,
    Left,
}

public sealed class CustomerRuntime
{
    public CustomerRuntime(PlannedCustomer plan, CustomerTypeData type, double patienceMultiplier)
    {
        Plan = plan;
        Type = type;
        PatienceMultiplier = patienceMultiplier;
        Progress = new OrderProgress(plan.Order);
    }

    public PlannedCustomer Plan { get; }
    public CustomerTypeData Type { get; }
    public double PatienceMultiplier { get; }
    public string Id => Plan.CustomerId;
    public OrderData Order => Plan.Order;
    public OrderProgress Progress { get; }
    public CustomerState State { get; internal set; } = CustomerState.ArrivalDelayed;
    public double WaitSeconds { get; internal set; }
    public double PhaseSeconds { get; internal set; }
    public double ArrivalDelaySeconds { get; internal set; }
    public bool WasServed { get; internal set; }

    public double LeaveAtSeconds => Type.LeaveAtSeconds * PatienceMultiplier;
    public double PatienceProgress => Math.Clamp(WaitSeconds / LeaveAtSeconds, 0, 1);

    internal bool Tick(double deltaSeconds)
    {
        PhaseSeconds += deltaSeconds;
        if (State == CustomerState.Entering)
        {
            if (PhaseSeconds >= CustomerQueue.EnterDurationSeconds)
            {
                PhaseSeconds = 0;
                State = CustomerState.Happy;
            }
            return false;
        }

        if (State is CustomerState.Served or CustomerState.Leaving)
        {
            if (State == CustomerState.Served)
            {
                State = CustomerState.Leaving;
                PhaseSeconds = 0;
            }
            return false;
        }

        if (State is not (CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry))
        {
            return false;
        }

        WaitSeconds += deltaSeconds;
        if (WaitSeconds >= Type.LeaveAtSeconds * PatienceMultiplier)
        {
            State = CustomerState.Leaving;
            PhaseSeconds = 0;
            Order.Status = OrderStatus.Lost;
            return true;
        }
        if (WaitSeconds >= Type.ImpatientUntilSeconds * PatienceMultiplier)
        {
            State = CustomerState.Angry;
        }
        else if (WaitSeconds >= Type.NormalUntilSeconds * PatienceMultiplier)
        {
            State = CustomerState.Impatient;
        }
        else if (WaitSeconds >= Type.HappyUntilSeconds * PatienceMultiplier)
        {
            State = CustomerState.Normal;
        }
        else
        {
            State = CustomerState.Happy;
        }
        return false;
    }
}
