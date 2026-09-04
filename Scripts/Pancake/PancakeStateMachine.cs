using ProjectCake.Data;
using ProjectCake.Fryer;

namespace ProjectCake.Pancake;

public sealed class PancakeStateMachine
{
    private const double TimingEpsilon = 0.0001;

    private static readonly IReadOnlySet<string> SliceIngredients = new HashSet<string>(StringComparer.Ordinal)
    {
        StableIds.Ingredients.Crispy,
        StableIds.Ingredients.Scallion,
        StableIds.Ingredients.Ham,
        StableIds.Ingredients.Youtiao,
    };

    public PancakeStateMachine(PancakeStoveLevelData stove)
    {
        Stove = stove;
    }

    public event Action? Changed;

    public PancakeStoveLevelData Stove { get; private set; }

    public PancakeRuntime Runtime { get; } = new();

    public bool CanSwitchStove => Runtime.State == PancakeState.Empty;

    public void Tick(double deltaSeconds)
    {
        if (deltaSeconds <= 0)
        {
            return;
        }

        bool changed = Runtime.State switch
        {
            PancakeState.SideACooking or PancakeState.SideAReady or PancakeState.SideAOverdone => TickSideA(deltaSeconds),
            PancakeState.SideBCooking or PancakeState.SideBReady => TickSideB(deltaSeconds),
            _ => false,
        };

        if (changed)
        {
            Changed?.Invoke();
        }
    }

    public PancakeActionResult TryExecute(
        PancakeCommand command,
        string? ingredientId = null,
        Func<string, bool>? tryConsume = null)
    {
        tryConsume ??= _ => true;

        PancakeActionResult result = command switch
        {
            PancakeCommand.PlaceBatter => PlaceBatter(tryConsume),
            PancakeCommand.BeginSpread => Transition(PancakeState.BatterPlaced, PancakeState.Spreading, "开始摊开面糊。"),
            PancakeCommand.CompleteSpread => Transition(PancakeState.Spreading, PancakeState.Spread, "面糊已经摊匀。"),
            PancakeCommand.AddEgg => AddEgg(tryConsume),
            PancakeCommand.Flip => Flip(),
            PancakeCommand.BeginSauce => Transition(PancakeState.SideBReady, PancakeState.Saucing, "开始抹酱。"),
            PancakeCommand.CompleteSauce => CompleteSauce(tryConsume),
            PancakeCommand.AddIngredient => AddIngredient(ingredientId, tryConsume),
            PancakeCommand.Fold => Fold(),
            PancakeCommand.Bag => Transition(PancakeState.Folded, PancakeState.Bagged, "煎饼已经装袋。"),
            PancakeCommand.Discard => Discard(),
            _ => PancakeActionResult.Fail(PancakeActionError.InvalidState, "未知操作。"),
        };

        if (result.Success)
        {
            Changed?.Invoke();
        }

        return result;
    }

    public PancakeDeliveryResult TryDeliver(RecipeData target)
    {
        if (Runtime.State == PancakeState.Burnt)
        {
            return new PancakeDeliveryResult(false, PancakeActionError.Burnt, "焦糊煎饼不能出餐。", PancakeQuality.Burnt);
        }

        if (Runtime.State != PancakeState.Bagged)
        {
            return new PancakeDeliveryResult(false, PancakeActionError.InvalidState, "请先折叠并装袋。", Runtime.Quality);
        }

        if (!Runtime.Matches(target))
        {
            return new PancakeDeliveryResult(false, PancakeActionError.RecipeMismatch, "配料与当前目标不符。", Runtime.Quality);
        }

        Runtime.State = PancakeState.Delivered;
        Changed?.Invoke();
        return new PancakeDeliveryResult(true, PancakeActionError.None, "出餐成功。", Runtime.Quality);
    }

    public bool TryGetPrepared(out PreparedPancake prepared)
    {
        if (Runtime.State != PancakeState.Bagged || Runtime.Quality == PancakeQuality.Burnt)
        {
            prepared = null!;
            return false;
        }

        prepared = new PreparedPancake(
            Runtime.Quality,
            new HashSet<string>(Runtime.ExtraIngredients, StringComparer.Ordinal),
            Runtime.InternalYoutiaoQuality);
        return true;
    }

    public bool TrySetInternalYoutiaoQuality(YoutiaoQuality quality)
    {
        if (!Runtime.ExtraIngredients.Contains(StableIds.Ingredients.Youtiao) || quality == YoutiaoQuality.Burnt)
        {
            return false;
        }
        Runtime.InternalYoutiaoQuality = quality;
        Changed?.Invoke();
        return true;
    }

    public bool TryAcceptPrepared()
    {
        if (Runtime.State != PancakeState.Bagged)
        {
            return false;
        }

        Runtime.State = PancakeState.Delivered;
        Changed?.Invoke();
        return true;
    }

    public bool TrySwitchStove(PancakeStoveLevelData stove)
    {
        if (!CanSwitchStove)
        {
            return false;
        }

        Stove = stove;
        Changed?.Invoke();
        return true;
    }

    public void SetSpreadCoverage(double coverage)
    {
        Runtime.SpreadCoverage = Math.Clamp(coverage, 0, 1);
        Changed?.Invoke();
    }

    public void SetSauceCoverage(double coverage)
    {
        Runtime.SauceCoverage = Math.Clamp(coverage, 0, 1);
        Changed?.Invoke();
    }

    private PancakeActionResult PlaceBatter(Func<string, bool> tryConsume)
    {
        if (Runtime.State != PancakeState.Empty)
        {
            return Invalid("炉面上已经有煎饼了。" );
        }

        if (!tryConsume(StableIds.Ingredients.Batter))
        {
            return Missing(StableIds.Ingredients.Batter);
        }

        Runtime.State = PancakeState.BatterPlaced;
        return PancakeActionResult.Ok("面糊已放到炉面。", StableIds.Ingredients.Batter);
    }

    private PancakeActionResult AddEgg(Func<string, bool> tryConsume)
    {
        if (Runtime.State != PancakeState.Spread)
        {
            return Invalid("请先把面糊摊匀。" );
        }

        if (!tryConsume(StableIds.Ingredients.Egg))
        {
            return Missing(StableIds.Ingredients.Egg);
        }

        Runtime.HasEgg = true;
        Runtime.CookingSeconds = 0;
        Runtime.State = PancakeState.SideACooking;
        return PancakeActionResult.Ok("鸡蛋已加入，第一面开始熟制。", StableIds.Ingredients.Egg);
    }

    private PancakeActionResult Flip()
    {
        if (Runtime.State is not (PancakeState.SideAReady or PancakeState.SideAOverdone))
        {
            return Invalid("现在还不能翻面。" );
        }

        Runtime.CookingSeconds = 0;
        Runtime.State = PancakeState.SideBCooking;
        return PancakeActionResult.Ok("翻面成功，第二面开始熟制。" );
    }

    private PancakeActionResult CompleteSauce(Func<string, bool> tryConsume)
    {
        if (Runtime.State != PancakeState.Saucing)
        {
            return Invalid("现在不能抹酱。" );
        }

        if (!tryConsume(StableIds.Ingredients.Sauce))
        {
            return Missing(StableIds.Ingredients.Sauce);
        }

        Runtime.HasSauce = true;
        Runtime.State = PancakeState.Sauced;
        return PancakeActionResult.Ok("酱料已经抹匀。", StableIds.Ingredients.Sauce);
    }

    private PancakeActionResult AddIngredient(string? ingredientId, Func<string, bool> tryConsume)
    {
        if (Runtime.State is not (PancakeState.Sauced or PancakeState.Toppings))
        {
            return Invalid("请先完成第二面熟制并抹酱。" );
        }

        if (ingredientId is null || !SliceIngredients.Contains(ingredientId))
        {
            return PancakeActionResult.Fail(PancakeActionError.UnsupportedIngredient, "当前不支持这种配料。" );
        }

        if (Runtime.ExtraIngredients.Contains(ingredientId))
        {
            return PancakeActionResult.Fail(PancakeActionError.DuplicateIngredient, "这种配料已经放过了。" );
        }

        if (!tryConsume(ingredientId))
        {
            return Missing(ingredientId);
        }

        Runtime.AddIngredient(ingredientId);
        Runtime.State = PancakeState.Toppings;
        return PancakeActionResult.Ok("配料已加入。", ingredientId);
    }

    private PancakeActionResult Fold()
    {
        if (Runtime.State is not (PancakeState.Sauced or PancakeState.Toppings))
        {
            return Invalid("请先完成抹酱。" );
        }

        Runtime.State = PancakeState.Folded;
        return PancakeActionResult.Ok("煎饼已折叠。" );
    }

    private PancakeActionResult Discard()
    {
        if (Runtime.State == PancakeState.Empty)
        {
            return Invalid("炉面目前是空的。" );
        }

        Runtime.Reset();
        return PancakeActionResult.Ok("已清理炉面。" );
    }

    private PancakeActionResult Transition(PancakeState expected, PancakeState next, string message)
    {
        if (Runtime.State != expected)
        {
            return Invalid("当前步骤不能执行这个操作。" );
        }

        Runtime.State = next;
        return PancakeActionResult.Ok(message);
    }

    private bool TickSideA(double deltaSeconds)
    {
        Runtime.CookingSeconds += deltaSeconds;
        PancakeState previous = Runtime.State;

        if (!Stove.CanBurn)
        {
            if (Runtime.CookingSeconds + TimingEpsilon >= Stove.SideAReadySeconds)
            {
                Runtime.CookingSeconds = Stove.SideAReadySeconds;
                Runtime.State = PancakeState.SideAReady;
            }
        }
        else if (Runtime.CookingSeconds + TimingEpsilon >= Stove.SideABurnSeconds)
        {
            Runtime.State = PancakeState.Burnt;
            Runtime.Quality = PancakeQuality.Burnt;
        }
        else if (Runtime.CookingSeconds + TimingEpsilon >= Stove.SideAOverdoneSeconds)
        {
            Runtime.State = PancakeState.SideAOverdone;
            Runtime.Quality = PancakeQuality.Overdone;
        }
        else if (Runtime.CookingSeconds + TimingEpsilon >= Stove.SideAReadySeconds)
        {
            Runtime.State = PancakeState.SideAReady;
        }

        return previous != Runtime.State || deltaSeconds > 0;
    }

    private bool TickSideB(double deltaSeconds)
    {
        Runtime.CookingSeconds += deltaSeconds;
        PancakeState previous = Runtime.State;

        if (!Stove.CanBurn)
        {
            if (Runtime.CookingSeconds + TimingEpsilon >= Stove.SideBReadySeconds)
            {
                Runtime.CookingSeconds = Stove.SideBReadySeconds;
                Runtime.State = PancakeState.SideBReady;
            }
        }
        else if (Runtime.CookingSeconds + TimingEpsilon >= Stove.SideBBurnSeconds)
        {
            Runtime.State = PancakeState.Burnt;
            Runtime.Quality = PancakeQuality.Burnt;
        }
        else if (Runtime.CookingSeconds + TimingEpsilon >= Stove.SideBReadySeconds)
        {
            Runtime.State = PancakeState.SideBReady;
        }

        return previous != Runtime.State || deltaSeconds > 0;
    }

    private static PancakeActionResult Invalid(string message) =>
        PancakeActionResult.Fail(PancakeActionError.InvalidState, message);

    private static PancakeActionResult Missing(string ingredientId) =>
        PancakeActionResult.Fail(PancakeActionError.MissingIngredient, $"{ingredientId} 库存不足或正在补料。" );
}
