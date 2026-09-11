using ProjectCake.Data;

namespace ProjectCake.Wuhan;

public enum NoodleBasketState { Empty, Cooking, Ready, Soft, Overcooked, Locked, Raised, Draining, Drained }
public enum NoodleQuality { Optimal, Soft, Overcooked }

public sealed class NoodleBasketRuntime
{
    public NoodleBasketState State { get; internal set; }
    public long Generation { get; internal set; }
    public double CookSeconds { get; internal set; }
    public double DrainSeconds { get; internal set; }
    public NoodleQuality Quality { get; internal set; } = NoodleQuality.Optimal;
}

public sealed class NoodleCookerStateMachine
{
    private readonly NoodleCookerLevelData _data;
    private readonly List<NoodleBasketRuntime> _baskets;

    public NoodleCookerStateMachine(NoodleCookerLevelData data)
    {
        _data = data;
        _baskets = Enumerable.Range(0, data.BasketCount).Select(_ => new NoodleBasketRuntime()).ToList();
    }

    public IReadOnlyList<NoodleBasketRuntime> Baskets => _baskets;
    public int? PendingPourBasket { get; private set; }
    private HotDryNoodlesStateMachine? _reservedBowl;

    public bool TryReservePour(int basket, HotDryNoodlesStateMachine bowl)
    {
        if (PendingPourBasket.HasValue || bowl.State != NoodleBowlState.Empty
            || !TryGet(basket, out var item) || item.State is not (NoodleBasketState.Raised or NoodleBasketState.Draining or NoodleBasketState.Drained)) return false;
        PendingPourBasket = basket; _reservedBowl = bowl;
        return true;
    }

    public void CancelPendingPour() { PendingPourBasket = null; _reservedBowl = null; }

    public bool TryCompletePendingPour(out int basket, out NoodleQuality quality)
    {
        basket = PendingPourBasket ?? -1; quality = NoodleQuality.Optimal;
        if (_reservedBowl is null || basket < 0) return false;
        if (_reservedBowl.State != NoodleBowlState.Empty) { CancelPendingPour(); return false; }
        quality = _baskets[basket].Quality;
        if (!TryTransferTo(basket, _reservedBowl)) return false;
        CancelPendingPour(); return true;
    }

    public bool TryStart(int basket)
    {
        if (!TryGet(basket, out NoodleBasketRuntime item) || item.State != NoodleBasketState.Empty) return false;
        item.State = NoodleBasketState.Cooking; item.CookSeconds = 0; item.DrainSeconds = 0; item.Quality = NoodleQuality.Optimal; return true;
    }

    public void Tick(double delta)
    {
        if (delta <= 0) return;
        foreach (NoodleBasketRuntime item in _baskets)
        {
            if (item.State is NoodleBasketState.Cooking or NoodleBasketState.Ready or NoodleBasketState.Soft)
            {
                item.CookSeconds += delta;
                if (_data.AutoLockOptimal && item.CookSeconds + .0001 >= _data.OptimalSeconds)
                {
                    item.Quality = NoodleQuality.Optimal;
                    item.State = _data.AutoRaise ? NoodleBasketState.Draining : NoodleBasketState.Locked;
                    continue;
                }
                item.State = item.CookSeconds + .0001 < _data.OptimalSeconds ? NoodleBasketState.Cooking
                    : item.CookSeconds <= _data.SoftUntilSeconds ? NoodleBasketState.Ready
                    : item.CookSeconds <= _data.OvercookedSeconds ? NoodleBasketState.Soft : NoodleBasketState.Overcooked;
                item.Quality = item.State switch { NoodleBasketState.Soft => NoodleQuality.Soft, NoodleBasketState.Overcooked => NoodleQuality.Overcooked, _ => NoodleQuality.Optimal };
            }
            else if (item.State is NoodleBasketState.Raised or NoodleBasketState.Draining)
            {
                item.State = NoodleBasketState.Draining;
                item.DrainSeconds += delta;
                if (item.DrainSeconds >= _data.NaturalDrainSeconds) item.State = NoodleBasketState.Drained;
            }
        }
    }

    public bool TryRaise(int basket)
    {
        if (!TryGet(basket, out NoodleBasketRuntime item) || item.State is not (NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked)) return false;
        item.State = NoodleBasketState.Raised; item.DrainSeconds = 0; return true;
    }

    public bool TryQuickDrain(int basket)
    {
        if (!TryGet(basket, out NoodleBasketRuntime item) || item.State is not (NoodleBasketState.Raised or NoodleBasketState.Draining)) return false;
        item.DrainSeconds = _data.QuickDrainSeconds;
        item.State = NoodleBasketState.Drained;
        return true;
    }

    public bool TryTake(int basket, out NoodleQuality quality)
    {
        quality = NoodleQuality.Optimal;
        if (!TryGet(basket, out NoodleBasketRuntime item) || item.State != NoodleBasketState.Drained) return false;
        quality = item.Quality; item.Generation++; item.State = NoodleBasketState.Empty; item.CookSeconds = 0; item.DrainSeconds = 0; return true;
    }

    // Validate the destination before consuming the source. Both mutations are synchronous.
    public bool TryTransferTo(int basket, HotDryNoodlesStateMachine bowl)
    {
        if (PendingPourBasket.HasValue && (PendingPourBasket != basket || !ReferenceEquals(bowl, _reservedBowl))) return false;
        if (!TryGet(basket, out NoodleBasketRuntime item) || item.State != NoodleBasketState.Drained
            || !bowl.TryAddNoodles(item.Quality)) return false;
        return TryTake(basket, out _);
    }

    public bool TryDiscard(int basket)
    {
        if (!TryGet(basket, out var item) || item.State == NoodleBasketState.Empty) return false;
        if (PendingPourBasket == basket) CancelPendingPour();
        item.Generation++; item.State = NoodleBasketState.Empty;
        item.CookSeconds = 0; item.DrainSeconds = 0; item.Quality = NoodleQuality.Optimal;
        return true;
    }

    private bool TryGet(int index, out NoodleBasketRuntime item)
    {
        if (index >= 0 && index < _baskets.Count) { item = _baskets[index]; return true; }
        item = null!; return false;
    }
}
