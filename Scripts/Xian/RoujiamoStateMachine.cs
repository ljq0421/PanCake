using ProjectCake.Orders;
using ProjectCake.Data;

namespace ProjectCake.Xian;

public sealed class RoujiamoStateMachine
{
    public RoujiamoState State { get; private set; }
    public BunQuality Quality { get; private set; }
    public int MeatPortions { get; private set; }
    public bool HasJuice { get; private set; }
    public bool TryTakeBun(BunInventory stock)
    {
        if (State != RoujiamoState.Empty || !stock.TryTake(out BunQuality quality)) return false;
        Quality = quality; State = RoujiamoState.Whole; return true;
    }
    public bool TryCut(double horizontalStroke)
    {
        if (State != RoujiamoState.Whole || Math.Abs(horizontalStroke) < 70) return false;
        State = RoujiamoState.Open; return true;
    }
    public bool TryAddMeat(ChoppingStateMachine board, int maximumMeat)
    {
        if (State != RoujiamoState.Open || MeatPortions >= maximumMeat || !board.TryTake()) return false;
        MeatPortions++; return true;
    }
    public bool TryAddJuice(RefillableStock juice, bool unlocked)
    {
        if (!unlocked || State != RoujiamoState.Open || MeatPortions < 1 || HasJuice || !juice.TryConsume(1)) return false;
        HasJuice = true; return true;
    }
    public bool TryWrap()
    {
        if (State != RoujiamoState.Open || MeatPortions < 1 || Quality == BunQuality.Burnt) return false;
        State = RoujiamoState.Wrapped; return true;
    }
    public DeliveredItem? Prepared => State == RoujiamoState.Wrapped
        ? new DeliveredItem(ProductKind.Roujiamo, XianRules.RecipeId(MeatPortions, HasJuice), BunQuality: Quality, MeatPortions: MeatPortions, HasJuice: HasJuice) : null;
    public bool TryTake() { if (Prepared is null) return false; Reset(); return true; }
    public void Reset() { State = RoujiamoState.Empty; MeatPortions = 0; HasJuice = false; Quality = BunQuality.Golden; }
}
