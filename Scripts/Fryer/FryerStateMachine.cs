using ProjectCake.Data;

namespace ProjectCake.Fryer;

public sealed class FryerStateMachine
{
    private const double Epsilon = 0.0001;

    public FryerStateMachine(FryerLevelData level)
    {
        Level = level;
        Inventory = new YoutiaoInventory(level.Capacity);
        Inventory.Changed += () => Changed?.Invoke();
    }

    public event Action? Changed;
    public event Action<int, YoutiaoQuality>? BatchStored;
    public event Action<int>? BatchBurnt;
    public FryerLevelData Level { get; private set; }
    public FryerBatchRuntime Runtime { get; } = new();
    public YoutiaoInventory Inventory { get; }
    public bool CanSwitchLevel => Runtime.State == FryerState.Empty && Inventory.IsEmpty;

    public FryerActionResult TryExecute(FryerCommand command)
    {
        FryerActionResult result = command switch
        {
            FryerCommand.LoadOne => LoadOne(),
            FryerCommand.LowerBasket => LowerBasket(),
            FryerCommand.RaiseBasket => RaiseBasket(),
            FryerCommand.Discard => Discard(),
            _ => FryerActionResult.Fail(FryerActionError.InvalidState, "未知油条锅操作。"),
        };
        if (result.Success) Changed?.Invoke();
        return result;
    }

    public void Tick(double deltaSeconds)
    {
        if (deltaSeconds <= 0) return;
        bool changed = false;
        if (Runtime.State == FryerState.Stored)
        {
            Runtime.Reset();
            changed = true;
        }
        else if (Runtime.State == FryerState.Frying)
        {
            Runtime.FrySeconds += deltaSeconds;
            Runtime.Quality = ResolveQuality(Runtime.FrySeconds);
            changed = true;
            if (Level.AutoRaise && Runtime.FrySeconds + Epsilon >= Level.AutoRaiseAtSeconds)
            {
                Runtime.FrySeconds = Level.AutoRaiseAtSeconds;
                Runtime.Quality = YoutiaoQuality.Golden;
                BeginRaise();
            }
            else if (!Level.AutoRaise && Runtime.Quality == YoutiaoQuality.Burnt)
            {
                Runtime.State = FryerState.Burnt;
                BatchBurnt?.Invoke(Runtime.Quantity);
            }
        }
        else if (Runtime.State == FryerState.Raised)
        {
            if (Inventory.CanStore(Runtime.Quantity))
            {
                Runtime.State = FryerState.Draining;
                Runtime.DrainSeconds = 0;
                changed = true;
            }
        }
        else if (Runtime.State == FryerState.Draining)
        {
            Runtime.DrainSeconds += deltaSeconds;
            changed = true;
            if (Runtime.DrainSeconds + Epsilon >= Level.DrainSeconds)
            {
                int quantity = Runtime.Quantity;
                YoutiaoQuality quality = Runtime.Quality;
                if (Inventory.TryStore(quantity, quality))
                {
                    Runtime.State = FryerState.Stored;
                    Runtime.DrainSeconds = Level.DrainSeconds;
                    BatchStored?.Invoke(quantity, quality);
                }
                else
                {
                    Runtime.State = FryerState.Raised;
                    Runtime.DrainSeconds = 0;
                }
            }
        }

        if (changed) Changed?.Invoke();
    }

    public YoutiaoQuality ResolveQuality(double seconds)
    {
        if (seconds + Epsilon < Level.GoldenStartSeconds) return YoutiaoQuality.Light;
        if (Level.AutoRaise || seconds <= Level.GoldenEndSeconds + Epsilon) return YoutiaoQuality.Golden;
        if (seconds <= Level.BurnAtSeconds + Epsilon) return YoutiaoQuality.Deep;
        return YoutiaoQuality.Burnt;
    }

    public bool TrySwitchLevel(FryerLevelData level)
    {
        if (!CanSwitchLevel || !Inventory.TrySwitchCapacity(level.Capacity)) return false;
        Level = level;
        Changed?.Invoke();
        return true;
    }

    public void Reset()
    {
        Runtime.Reset();
        Inventory.Clear();
        Changed?.Invoke();
    }

    private FryerActionResult LoadOne()
    {
        if (Runtime.State == FryerState.Stored) Runtime.Reset();
        if (Runtime.State is not (FryerState.Empty or FryerState.Loaded))
            return FryerActionResult.Fail(FryerActionError.InvalidState, "只有抬起且空闲的炸篮可以装入生油条。");
        if (Runtime.Quantity >= Level.Capacity)
            return FryerActionResult.Fail(FryerActionError.BasketFull, "炸篮已经装满。");
        Runtime.Quantity++;
        Runtime.State = FryerState.Loaded;
        return FryerActionResult.Ok($"已装入第 {Runtime.Quantity} 根生油条。");
    }

    private FryerActionResult LowerBasket()
    {
        if (Runtime.State != FryerState.Loaded || Runtime.Quantity <= 0)
            return FryerActionResult.Fail(FryerActionError.BasketEmpty, "请先装入至少一根生油条。");
        Runtime.State = FryerState.Frying;
        Runtime.FrySeconds = 0;
        Runtime.Quality = YoutiaoQuality.Light;
        return FryerActionResult.Ok("炸篮已放下，油条开始炸制。");
    }

    private FryerActionResult RaiseBasket()
    {
        if (Runtime.State == FryerState.Burnt)
            return FryerActionResult.Fail(FryerActionError.Burnt, "油条已经炸焦，只能丢弃。");
        if (Runtime.State != FryerState.Frying)
            return FryerActionResult.Fail(FryerActionError.InvalidState, "当前不能抬起炸篮。");
        if (Level.AutoRaise)
            return FryerActionResult.Fail(FryerActionError.InvalidState, "高级油条锅会在最佳时刻自动抬篮。");
        BeginRaise();
        return FryerActionResult.Ok(Inventory.CanStore(Runtime.Quantity) ? "炸篮已抬起，开始沥油。" : "炸篮已抬起，等待成品区空位。");
    }

    private void BeginRaise()
    {
        Runtime.State = Inventory.CanStore(Runtime.Quantity) ? FryerState.Draining : FryerState.Raised;
        Runtime.DrainSeconds = 0;
    }

    private FryerActionResult Discard()
    {
        if (Runtime.State == FryerState.Empty)
            return FryerActionResult.Fail(FryerActionError.InvalidState, "炸篮目前是空的。");
        Runtime.Reset();
        return FryerActionResult.Ok("炸篮已经清理。");
    }
}
