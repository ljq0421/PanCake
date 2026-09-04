using Godot;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Fryer;
using ProjectCake.Inventory;
using ProjectCake.Orders;
using ProjectCake.Pancake;

namespace ProjectCake.Core;

public enum DayState
{
    Preparing,
    Opening,
    Running,
    Closing,
    Results,
}

public partial class DayController : Node
{
    public const double OpeningDurationSeconds = 3.0;
    public const double ClosingDurationSeconds = 15.0;

    public event Action<DayConfig>? DayPrepared;
    public event Action<DayState>? StateChanged;
    public event Action<DayResult>? DayFinished;
    public event Action<DeliveryEvaluation>? DeliveryCompleted;

    public DayConfig? CurrentConfig { get; private set; }

    public DayState State { get; private set; } = DayState.Preparing;
    public DayPlan? CurrentPlan { get; private set; }
    public CustomerQueue? CustomerQueue { get; private set; }
    public DayLedger? Ledger { get; private set; }
    public double DayElapsedSeconds { get; private set; }
    public double OpeningRemainingSeconds { get; private set; }
    public double ClosingRemainingSeconds { get; private set; }
    public bool IsPaused { get; set; }
    public double DayRemainingSeconds => Math.Max(0, (CurrentConfig?.DurationSeconds ?? 0) - DayElapsedSeconds);

    public bool TryPrepareDay(int dayNumber, DataCatalog catalog, out string error)
    {
        if (!catalog.IsValid)
        {
            error = "DataCatalog 存在配置错误，不能准备营业日。";
            return false;
        }

        if (!catalog.TryGetDay(dayNumber, out DayConfig config))
        {
            error = $"找不到 Day {dayNumber} 配置。";
            return false;
        }

        CurrentConfig = config;
        CurrentPlan = new OrderGenerator().Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
        CustomerQueue = new CustomerQueue(CurrentPlan, catalog.CustomersById, config.PatienceMultiplier, config.MaxWaitingCustomers);
        Ledger = new DayLedger(config.Day, config.CustomerCount);
        CustomerQueue.CustomerLost += _ => Ledger.RecordLost();
        DayElapsedSeconds = 0;
        OpeningRemainingSeconds = OpeningDurationSeconds;
        ClosingRemainingSeconds = ClosingDurationSeconds;
        SetState(DayState.Preparing);
        error = string.Empty;
        DayPrepared?.Invoke(config);
        return true;
    }

    public bool TryStartDay(out string error)
    {
        if (State != DayState.Preparing || CurrentConfig is null || CurrentPlan is null)
        {
            error = "当前没有已准备的营业日。";
            return false;
        }

        OpeningRemainingSeconds = OpeningDurationSeconds;
        SetState(DayState.Opening);
        error = string.Empty;
        return true;
    }

    public void Tick(double deltaSeconds)
    {
        if (IsPaused || deltaSeconds <= 0 || CurrentConfig is null || CustomerQueue is null)
        {
            return;
        }

        if (State == DayState.Opening)
        {
            OpeningRemainingSeconds = Math.Max(0, OpeningRemainingSeconds - deltaSeconds);
            if (OpeningRemainingSeconds <= 0)
            {
                SetState(DayState.Running);
            }
            return;
        }

        if (State == DayState.Running)
        {
            DayElapsedSeconds = Math.Min(CurrentConfig.DurationSeconds, DayElapsedSeconds + deltaSeconds);
            CustomerQueue.Tick(DayElapsedSeconds, deltaSeconds, true);
            if (DayElapsedSeconds >= CurrentConfig.DurationSeconds)
            {
                ClosingRemainingSeconds = ClosingDurationSeconds;
                SetState(DayState.Closing);
                TryFinishIfResolved();
            }
            return;
        }

        if (State == DayState.Closing)
        {
            CustomerQueue.Tick(DayElapsedSeconds, deltaSeconds, false);
            ClosingRemainingSeconds = Math.Max(0, ClosingRemainingSeconds - deltaSeconds);
            if (TryFinishIfResolved())
            {
                return;
            }

            if (ClosingRemainingSeconds <= 0)
            {
                CustomerQueue.ForceLoseAll();
                CompleteDay();
            }
        }
    }

    public DeliveryEvaluation TryDeliverSelected(
        PancakeStateMachine pancake,
        DataCatalog catalog)
    {
        if (State is not (DayState.Running or DayState.Closing) || CustomerQueue?.SelectedCustomer is not CustomerRuntime customer)
        {
            return new DeliveryEvaluation(DeliveryGrade.Rejected, 0, 0, 0, "请先选择一位仍在等待的顾客。");
        }

        if (!pancake.TryGetPrepared(out PreparedPancake prepared))
        {
            return new DeliveryEvaluation(DeliveryGrade.Rejected, 0, 0, 0, "请先完成并装袋一张未焦糊的煎饼。");
        }

        string actualRecipeId = catalog.RecipesById.Values
            .FirstOrDefault(recipe => prepared.ExtraIngredients.SetEquals(recipe.ExtraIngredients))?.Id
            ?? $"invalid:{string.Join('+', prepared.ExtraIngredients.OrderBy(id => id, StringComparer.Ordinal))}";
        var item = new DeliveredItem(ProductKind.Pancake, actualRecipeId, prepared.Quality, null, prepared.InternalYoutiaoQuality);
        return TryDeliverItem(customer, item, null, pancake.TryAcceptPrepared);
    }

    public DeliveryEvaluation TryDeliverYoutiaoSelected(YoutiaoInventory inventory)
    {
        if (!inventory.TryPeek(out YoutiaoQuality quality))
            return Rejected("沥油区没有可用油条。");
        CustomerRuntime? customer = GetDeliveryCustomer(out DeliveryEvaluation rejection);
        if (customer is null) return rejection;
        var item = new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, null, quality);
        return TryDeliverItem(customer, item, () => inventory.TryTake(out _), null);
    }

    public DeliveryEvaluation TryDeliverSoyMilkSelected(SoyMilkTrayRuntime tray)
    {
        CustomerRuntime? customer = GetDeliveryCustomer(out DeliveryEvaluation rejection);
        if (customer is null) return rejection;
        var item = new DeliveredItem(ProductKind.SoyMilk, StableIds.Products.SoyMilk);
        return TryDeliverItem(customer, item, tray.TryConsumeForDelivery, null);
    }

    public void AbandonDay()
    {
        if (State is DayState.Opening or DayState.Running or DayState.Closing)
        {
            CurrentPlan = null;
            CustomerQueue = null;
            Ledger = null;
            DayElapsedSeconds = 0;
            SetState(DayState.Preparing);
        }
    }

    private bool TryFinishIfResolved()
    {
        if (CustomerQueue?.IsResolved != true)
        {
            return false;
        }

        CompleteDay();
        return true;
    }

    private CustomerRuntime? GetDeliveryCustomer(out DeliveryEvaluation rejection)
    {
        if (State is not (DayState.Running or DayState.Closing) || CustomerQueue?.SelectedCustomer is not CustomerRuntime customer)
        {
            rejection = Rejected("请先选择一位仍在等待的顾客。");
            return null;
        }
        rejection = null!;
        return customer;
    }

    private DeliveryEvaluation TryDeliverItem(CustomerRuntime customer, DeliveredItem item, Func<bool>? consume, Func<bool>? acceptPrepared)
    {
        if (!customer.Progress.CanAccept(item, out string error)) return Rejected(error);
        if (consume is not null && !consume()) return Rejected("商品库存已经变化，请重试。");

        OrderItemAcceptance acceptance = customer.Progress.TryAccept(item);
        if (!acceptance.Accepted || acceptPrepared is not null && !acceptPrepared())
            return Rejected("顾客状态已经变化，本次交付未生效。");

        if (!acceptance.OrderComplete)
        {
            var incomplete = new DeliveryEvaluation(DeliveryGrade.Incomplete, 0, 0, 0, acceptance.Message, true);
            DeliveryCompleted?.Invoke(incomplete);
            return incomplete;
        }

        DeliveryEvaluation evaluation = new OrderEvaluator().EvaluateCompleted(customer.Progress, customer.State, customer.Type);
        if (!CustomerQueue!.TryMarkServed(customer.Id)) return Rejected("顾客状态已经变化，本次交付未生效。");
        Ledger!.RecordDelivery(evaluation);
        DeliveryCompleted?.Invoke(evaluation);
        return evaluation;
    }

    private static DeliveryEvaluation Rejected(string message) => new(DeliveryGrade.Rejected, 0, 0, 0, message, false);

    private void CompleteDay()
    {
        if (State == DayState.Results)
        {
            return;
        }

        DayResult result = Ledger!.Build();
        SetState(DayState.Results);
        DayFinished?.Invoke(result);
    }

    private void SetState(DayState state)
    {
        State = state;
        StateChanged?.Invoke(state);
    }
}
