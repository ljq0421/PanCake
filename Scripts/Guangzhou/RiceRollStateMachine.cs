using ProjectCake.Data;

namespace ProjectCake.Guangzhou;

public enum RiceRollState { Empty, Spreading, Steaming, Rolling, Cut, Ready }

public sealed class RiceRollStateMachine
{
    private readonly GuangzhouEquipmentData _equipment;
    private readonly HashSet<string> _ingredients = new(StringComparer.Ordinal);
    public RiceRollStateMachine(GuangzhouEquipmentData equipment) => _equipment = equipment;
    public RiceRollState State { get; private set; }
    public double SpreadProgress { get; private set; }
    public double RollProgress { get; private set; }
    public double SteamSeconds { get; private set; }
    public bool SauceApplied { get; private set; }
    public bool Broken { get; private set; }
    public IReadOnlySet<string> Ingredients => _ingredients;
    public bool Cooked => State == RiceRollState.Steaming && SteamSeconds + 1e-8 >= _equipment.CookSeconds;
    public bool PoppedOut => Cooked && _equipment.PopOut;
    public RiceRollQuality Quality { get; private set; } = RiceRollQuality.Perfect;
    public GuangzhouFoodQuality FoodQuality => new(State == RiceRollState.Ready && SauceApplied, Quality, Broken);
    public string RecipeId => _ingredients.SetEquals(new[] { GuangzhouRules.Egg, GuangzhouRules.Pork }) ? GuangzhouRules.Recipes[4]
        : _ingredients.Count == 0 ? GuangzhouRules.Recipes[0]
        : _ingredients.Count == 1 ? _ingredients.First()
        : "invalid:" + string.Join('+', _ingredients.OrderBy(x => x, StringComparer.Ordinal));

    public bool TryPour(GuangzhouStock batter)
    {
        if (State != RiceRollState.Empty || !batter.TryTake()) return false;
        State = RiceRollState.Spreading; return true;
    }
    public void Spread(double progress)
    {
        if (State != RiceRollState.Spreading || !double.IsFinite(progress) || progress <= 0) return;
        SpreadProgress = Math.Clamp(SpreadProgress + progress, 0, 1);
        if (SpreadProgress + 1e-8 >= .8) SpreadProgress = 1;
    }
    public bool TryAdd(string id, GuangzhouStock stock)
    {
        if (State != RiceRollState.Spreading || SpreadProgress + 1e-8 < .65 || _ingredients.Contains(id)
            || id is not (GuangzhouRules.Egg or GuangzhouRules.Pork or GuangzhouRules.Shrimp) || !stock.TryTake()) return false;
        _ingredients.Add(id); return true;
    }
    public bool TryPush()
    {
        if (State != RiceRollState.Spreading || SpreadProgress + 1e-8 < .65) return false;
        State = RiceRollState.Steaming; return true;
    }
    public void Tick(double delta)
    {
        if (delta <= 0 || State != RiceRollState.Steaming) return;
        SteamSeconds += delta;
        if (_equipment.KeepWarm) { SteamSeconds = Math.Min(SteamSeconds, _equipment.CookSeconds); return; }
        double bestEnd = _equipment.CookSeconds + _equipment.BestWindowSeconds;
        Quality = SteamSeconds > bestEnd + _equipment.NormalWindowSeconds + 1e-8 ? RiceRollQuality.Dry
            : SteamSeconds > bestEnd + 1e-8 ? RiceRollQuality.Normal : RiceRollQuality.Perfect;
    }
    public bool TryPull() { if (!Cooked) return false; State = RiceRollState.Rolling; return true; }
    public void Roll(double absoluteProgress)
    {
        if (State != RiceRollState.Rolling || !double.IsFinite(absoluteProgress)) return;
        RollProgress = Math.Clamp(Math.Max(RollProgress, absoluteProgress), 0, 1);
        if (RollProgress + 1e-8 >= .85) RollProgress = 1;
    }
    public bool TryCut()
    {
        if (State != RiceRollState.Rolling || RollProgress + 1e-8 < .75) return false;
        Broken = RollProgress < 1;
        State = RiceRollState.Cut; return true;
    }
    public bool TrySauce(GuangzhouStock stock)
    {
        if (State != RiceRollState.Cut || SauceApplied || !stock.TryTake()) return false;
        SauceApplied = true; State = RiceRollState.Ready; return true;
    }
    public bool TryTake() { if (State != RiceRollState.Ready) return false; Reset(); return true; }
    public void Reset()
    {
        State = RiceRollState.Empty; SpreadProgress = RollProgress = SteamSeconds = 0;
        SauceApplied = Broken = false; Quality = RiceRollQuality.Perfect; _ingredients.Clear();
    }
}
