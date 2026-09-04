using ProjectCake.Orders;

namespace ProjectCake.Gameplay;

public sealed class DayResult
{
    public int Day { get; init; }
    public int PlannedCustomers { get; init; }
    public int SaleRevenue { get; init; }
    public int Tips { get; init; }
    public int CompletedCustomers { get; init; }
    public int LostCustomers { get; init; }
    public int PerfectOrders { get; init; }
    public int CorrectOrders { get; init; }
    public int IncorrectOrders { get; init; }
    public int HighestCorrectStreak { get; init; }
    public double Satisfaction { get; init; }
    public int YoutiaoUsed { get; init; }
    public int YoutiaoBurnt { get; init; }
    public int TotalRevenue => SaleRevenue + Tips;
}

public sealed class DayLedger
{
    private readonly int _day;
    private readonly int _plannedCustomers;
    private int _satisfactionPoints;
    private int _currentStreak;

    public DayLedger(int day, int plannedCustomers)
    {
        _day = day;
        _plannedCustomers = plannedCustomers;
    }

    public int SaleRevenue { get; private set; }
    public int Tips { get; private set; }
    public int CompletedCustomers { get; private set; }
    public int LostCustomers { get; private set; }
    public int PerfectOrders { get; private set; }
    public int CorrectOrders { get; private set; }
    public int IncorrectOrders { get; private set; }
    public int HighestCorrectStreak { get; private set; }
    public int YoutiaoUsed { get; private set; }
    public int YoutiaoBurnt { get; private set; }

    public void RecordYoutiaoUsed(int quantity = 1) => YoutiaoUsed += Math.Max(0, quantity);
    public void RecordYoutiaoBurnt(int quantity) => YoutiaoBurnt += Math.Max(0, quantity);

    public void RecordDelivery(DeliveryEvaluation evaluation)
    {
        if (!evaluation.CompletesOrder)
        {
            return;
        }
        SaleRevenue += evaluation.SaleRevenue;
        Tips += evaluation.Tip;
        CompletedCustomers++;
        _satisfactionPoints += evaluation.SatisfactionScore;
        if (evaluation.Grade == DeliveryGrade.Perfect)
        {
            PerfectOrders++;
            ContinueStreak();
        }
        else if (evaluation.Grade == DeliveryGrade.Correct)
        {
            CorrectOrders++;
            ContinueStreak();
        }
        else
        {
            IncorrectOrders++;
            _currentStreak = 0;
        }
    }

    public void RecordLost()
    {
        LostCustomers++;
        _currentStreak = 0;
    }

    public DayResult Build() => new()
    {
        Day = _day,
        PlannedCustomers = _plannedCustomers,
        SaleRevenue = SaleRevenue,
        Tips = Tips,
        CompletedCustomers = CompletedCustomers,
        LostCustomers = LostCustomers,
        PerfectOrders = PerfectOrders,
        CorrectOrders = CorrectOrders,
        IncorrectOrders = IncorrectOrders,
        HighestCorrectStreak = HighestCorrectStreak,
        Satisfaction = _plannedCustomers == 0 ? 0 : (double)_satisfactionPoints / _plannedCustomers,
        YoutiaoUsed = YoutiaoUsed,
        YoutiaoBurnt = YoutiaoBurnt,
    };

    private void ContinueStreak()
    {
        _currentStreak++;
        HighestCorrectStreak = Math.Max(HighestCorrectStreak, _currentStreak);
    }
}
