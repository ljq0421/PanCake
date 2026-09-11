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
    private readonly List<BusinessOrderRecord> _businessRecords = new();
    private readonly HashSet<string> _recordedOrders = new(StringComparer.Ordinal);
    public IReadOnlyList<BusinessOrderRecord> BusinessRecords => _businessRecords.AsReadOnly();

    private void RecordOutcome(CustomerRuntime customer, DeliveryEvaluation? evaluation)
    {
        if ((CurrentConfig?.CityId is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan) && _recordedOrders.Add(customer.Order.OrderId))
            _businessRecords.Add(BusinessOrderRecord.Capture(customer, evaluation));
    }
    public double DayElapsedSeconds { get; private set; }
    public double OpeningRemainingSeconds { get; private set; }
    public double ClosingRemainingSeconds { get; private set; }
    private bool _paused;
    private readonly HashSet<string> _pauseReasons = new(StringComparer.Ordinal);
    public bool IsPaused { get => _paused || _pauseReasons.Count > 0; set => _paused = value; }
    internal void SetPauseReason(string reason, bool paused)
    {
        if (paused) _pauseReasons.Add(reason); else _pauseReasons.Remove(reason);
    }
    public double DayRemainingSeconds => Math.Max(0, (CurrentConfig?.DurationSeconds ?? 0) - DayElapsedSeconds);
    public Func<string, int>? GuangzhouStockCount { get; set; }

    public bool TryPrepareDay(int dayNumber, DataCatalog catalog, out string error)
        => TryPrepareDay(StableIds.Cities.Tianjin, dayNumber, catalog, out error);

    public bool TryPrepareDay(string cityId, int dayNumber, DataCatalog catalog, out string error)
    {
        if (!catalog.IsValid)
        {
            error = "DataCatalog 存在配置错误，不能准备营业日。";
            return false;
        }

        if (!catalog.TryGetDay(cityId, dayNumber, out DayConfig config))
        {
            error = $"找不到 Day {dayNumber} 配置。";
            return false;
        }

        CurrentConfig = config;
        CurrentPlan = new OrderGenerator().Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
        CustomerQueue = new CustomerQueue(CurrentPlan, catalog.CustomersById, config.PatienceMultiplier, config.MaxWaitingCustomers,
            config.Constraints.PressureDelaySeconds, config.Constraints.MaxPressureDelaySeconds, config.CityId == StableIds.Cities.Xian ? config.Constraints : null);
        GuangzhouStockCount = null;
        if (cityId == StableIds.Cities.Guangzhou)
            CustomerQueue.ResolveBeforeArrival = (planned, ordinal) => ProjectCake.Guangzhou.GuangzhouOrderProtection.Resolve(
                planned, ordinal, config, CustomerQueue.Slots, id => GuangzhouStockCount?.Invoke(id) ?? 0, catalog.ProductsById);
        Ledger = new DayLedger(config.Day, config.CustomerCount, config.SatisfactionAverageMode);
        _businessRecords.Clear();
        _recordedOrders.Clear();
        CustomerQueue.CustomerLost += customer => { Ledger.RecordLost(); RecordOutcome(customer, null); };
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
        DataCatalog catalog) => TryDeliverPancakeTo(CustomerQueue?.SelectedCustomerId, pancake, catalog);

    public bool CanDeliverTo(string? customerId, ProductKind kind) =>
        FindDeliveryCustomer(customerId) is CustomerRuntime customer && customer.Progress.CanAccept(kind);

    public DeliveryEvaluation TryDeliverPancakeTo(string? customerId, PancakeStateMachine pancake, DataCatalog catalog)
    {
        if (FindDeliveryCustomer(customerId) is not CustomerRuntime customer)
        {
            return Rejected("请把成品拖给仍在等待的顾客。");
        }

        if (!pancake.TryGetPrepared(out PreparedPancake prepared))
        {
            return new DeliveryEvaluation(DeliveryGrade.Rejected, 0, 0, 0, "请先完成并装袋一张未焦糊的煎饼。");
        }

        return DeliverPreparedPancake(customer, prepared, catalog, pancake.TryAcceptPrepared);
    }

    public DeliveryEvaluation TryDeliverPreparedPancakeTo(string? customerId, PreparedPancake prepared,
        DataCatalog catalog, Func<bool> consume)
    {
        CustomerRuntime? customer = FindDeliveryCustomer(customerId);
        return customer is null ? Rejected("请把成品拖给仍在等待的顾客。")
            : DeliverPreparedPancake(customer, prepared, catalog, consume);
    }

    private DeliveryEvaluation DeliverPreparedPancake(CustomerRuntime customer, PreparedPancake prepared,
        DataCatalog catalog, Func<bool> consume)
    {

        string actualRecipeId = catalog.RecipesById.Values
            .FirstOrDefault(recipe => prepared.ExtraIngredients.SetEquals(recipe.ExtraIngredients))?.Id
            ?? $"invalid:{string.Join('+', prepared.ExtraIngredients.OrderBy(id => id, StringComparer.Ordinal))}";
        var item = new DeliveredItem(ProductKind.Pancake, actualRecipeId, prepared.Quality, null, prepared.InternalYoutiaoQuality,
            SauceAmount: prepared.SauceAmount);
        return TryDeliverItem(customer, item, consume, null);
    }

    public DeliveryEvaluation TryDeliverYoutiaoSelected(YoutiaoInventory inventory) =>
        TryDeliverYoutiaoTo(CustomerQueue?.SelectedCustomerId, inventory);

    public DeliveryEvaluation TryDeliverYoutiaoTo(string? customerId, YoutiaoInventory inventory)
    {
        if (!inventory.TryPeek(out YoutiaoQuality quality))
            return Rejected("没有可用的成品油条。");
        CustomerRuntime? customer = FindDeliveryCustomer(customerId);
        if (customer is null) return Rejected("这位顾客已经不能接餐，请拖给仍在等待的顾客。");
        var item = new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, null, quality);
        return TryDeliverItem(customer, item, () => inventory.TryTake(out _), null);
    }

    public DeliveryEvaluation TryDeliverSoyMilkSelected(SoyMilkTrayRuntime tray) =>
        TryDeliverSoyMilkTo(CustomerQueue?.SelectedCustomerId, tray);

    public DeliveryEvaluation TryDeliverSoyMilkTo(string? customerId, SoyMilkTrayRuntime tray)
    {
        CustomerRuntime? customer = FindDeliveryCustomer(customerId);
        if (customer is null) return Rejected("这位顾客已经不能接餐，请拖给仍在等待的顾客。");
        var item = new DeliveredItem(ProductKind.SoyMilk, StableIds.Products.SoyMilk);
        return TryDeliverItem(customer, item, tray.TryConsumeForDelivery, null);
    }

    public DeliveryEvaluation TryDeliverWuhanSelected(DeliveredItem item, Func<bool> consume) =>
        TryDeliverWuhanTo(CustomerQueue?.SelectedCustomerId, item, consume);

    public DeliveryEvaluation TryDeliverWuhanTo(string? customerId, DeliveredItem item, Func<bool> consume)
    {
        if (IsPaused || CurrentConfig?.CityId != StableIds.Cities.Wuhan
            || item.ProductKind is not (ProductKind.HotDryNoodles or ProductKind.Doupi or ProductKind.EggRiceWine))
            return Rejected("当前不能交付武汉商品。");
        CustomerRuntime? customer = FindDeliveryCustomer(customerId);
        return customer is null ? Rejected("请把成品拖给仍在等待的顾客。") : TryDeliverItem(customer, item, consume, null);
    }

    public int GetWuhanDoupiDeliveryQuantity(string? customerId, ProjectCake.Wuhan.DoupiInventory inventory)
    {
        if (IsPaused || CurrentConfig?.CityId != StableIds.Cities.Wuhan || FindDeliveryCustomer(customerId) is not CustomerRuntime customer) return 0;
        int remaining = customer.Order.Lines.Select((line, index) => line.ProductKind == ProductKind.Doupi
            ? customer.Progress.GetRemainingQuantity(index) : 0).Sum();
        return Math.Min(inventory.Count, remaining);
    }

    public DeliveryEvaluation TryDeliverWuhanDoupiTo(string? customerId, ProjectCake.Wuhan.DoupiInventory inventory)
    {
        int count = GetWuhanDoupiDeliveryQuantity(customerId, inventory);
        if (count == 0 || FindDeliveryCustomer(customerId) is not CustomerRuntime customer) return Rejected("没有可交付的豆皮或顾客已不再需要。");
        DeliveryEvaluation result = Rejected("豆皮交付未生效。");
        // Synchronous FIFO commits preserve each piece's quality. No callbacks until the batch ends.
        for (int i = 0; i < count; i++)
        {
            if (!inventory.TryPeek(out var quality)) break;
            var item = new DeliveredItem(ProductKind.Doupi, StableIds.Products.Doupi, WuhanQuality:
                quality == ProjectCake.Wuhan.DoupiQuality.Overbrowned ? WuhanFoodQuality.DoupiOverbrowned : WuhanFoodQuality.None);
            result = TryDeliverItem(customer, item, () => inventory.TryTake(1, out _), null, false);
            if (!result.ItemAccepted || result.CompletesOrder) break;
        }
        if (result.ItemAccepted || result.CompletesOrder) DeliveryCompleted?.Invoke(result);
        return result;
    }

    public DeliveryEvaluation TryDeliverXianTo(string? customerId, DeliveredItem item, Func<bool> consume)
    {
        if (IsPaused || CurrentConfig?.CityId != StableIds.Cities.Xian || item.ProductKind is not (ProductKind.Roujiamo or ProductKind.Hulatang)) return Rejected("当前不能交付。");
        var customer = FindDeliveryCustomer(customerId);
        return customer is null ? Rejected("请交给仍在等待的顾客。") : TryDeliverItem(customer, item, consume, null);
    }

    public DeliveryEvaluation TryDeliverGuangzhouTo(string? customerId, DeliveredItem item, Func<bool> consume)
    {
        if (IsPaused || CurrentConfig?.CityId != StableIds.Cities.Guangzhou || !ProjectCake.Guangzhou.GuangzhouRules.IsProduct(item.ProductKind))
            return Rejected("当前不能交付广州商品。");
        var customer = FindDeliveryCustomer(customerId);
        return customer is null ? Rejected("请交给仍在等待的顾客。") : TryDeliverItem(customer, item, consume, null);
    }

    public void AbandonDay()
    {
        if (State is DayState.Opening or DayState.Running or DayState.Closing)
        {
            CurrentPlan = null;
            CustomerQueue = null;
            Ledger = null;
            _businessRecords.Clear();
            _recordedOrders.Clear();
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

    private CustomerRuntime? FindDeliveryCustomer(string? customerId) =>
        State is DayState.Running or DayState.Closing
            ? CustomerQueue?.Slots.FirstOrDefault(customer => customer.Id == customerId
                && customer.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry)
            : null;

    private DeliveryEvaluation TryDeliverItem(CustomerRuntime customer, DeliveredItem item, Func<bool>? consume, Func<bool>? acceptPrepared, bool notify = true)
    {
        if (!customer.Progress.CanAccept(item, out string error)) return Rejected(error);
        bool matchesRequestedItem = customer.Order.Lines.Select((line, index) =>
            line.ProductKind == item.ProductKind && line.DefinitionId == item.DefinitionId
            && (item.ProductKind != ProductKind.Pancake || SauceRules.Matches(line.Sauce, item.SauceAmount))
            && customer.Progress.GetRemainingQuantity(index) > 0).Any(matches => matches);
        if (consume is not null && !consume()) return Rejected("商品库存已经变化，请重试。");

        OrderItemAcceptance acceptance = customer.Progress.TryAccept(item);
        if (!acceptance.Accepted || acceptPrepared is not null && !acceptPrepared())
            return Rejected("顾客状态已经变化，本次交付未生效。");

        if (customer.Order.CityId is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan or StableIds.Cities.Xian && matchesRequestedItem)
            customer.RestorePatience(0.15);

        if (!acceptance.OrderComplete)
        {
            var incomplete = new DeliveryEvaluation(DeliveryGrade.Incomplete, 0, 0, 0, acceptance.Message, true);
            if (notify) DeliveryCompleted?.Invoke(incomplete);
            return incomplete;
        }

        DeliveryEvaluation evaluation = customer.Order.CityId == StableIds.Cities.Guangzhou
            ? new OrderEvaluator().EvaluateCompletedGuangzhou(customer.Progress, customer.PatienceProgress, customer.Type)
            : customer.Order.CityId == StableIds.Cities.Xian
            ? new OrderEvaluator().EvaluateCompletedXian(customer.Progress, customer.PatienceProgress, customer.Type)
            : customer.Order.CityId == StableIds.Cities.Wuhan
            ? new OrderEvaluator().EvaluateCompletedWuhan(customer.Progress, customer.PatienceProgress, customer.Type)
            : new OrderEvaluator().EvaluateCompleted(customer.Progress, customer.State, customer.Type);
        if (!CustomerQueue!.TryMarkServed(customer.Id)) return Rejected("顾客状态已经变化，本次交付未生效。");
        Ledger!.RecordDelivery(evaluation);
        RecordOutcome(customer, evaluation);
        if (notify) DeliveryCompleted?.Invoke(evaluation);
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
