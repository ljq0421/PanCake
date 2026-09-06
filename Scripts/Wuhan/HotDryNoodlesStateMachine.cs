using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Wuhan;

public enum NoodleBowlState { Empty, Noodles, Seasoned, Mixing, Ready }
public sealed record PreparedHotDryNoodles(string RecipeId, NoodleQuality NoodleQuality, bool MixedComplete);

public sealed class HotDryNoodlesStateMachine
{
    private readonly HashSet<string> _toppings = new(StringComparer.Ordinal);
    private NoodleQuality _quality;
    public NoodleBowlState State { get; private set; }
    public double MixProgress { get; private set; }
    public IReadOnlySet<string> Toppings => _toppings;

    public bool TryAddNoodles(NoodleQuality quality)
    {
        if (State != NoodleBowlState.Empty) return false;
        _quality = quality; State = NoodleBowlState.Noodles; return true;
    }
    public bool TryAddBaseSeasoning()
    {
        if (State != NoodleBowlState.Noodles) return false;
        State = NoodleBowlState.Seasoned; return true;
    }
    public bool TryAddTopping(string ingredientId)
    {
        if (State != NoodleBowlState.Seasoned || ingredientId is not (StableIds.Ingredients.WuhanScallion or StableIds.Ingredients.WuhanChiliOil or StableIds.Ingredients.WuhanBraisedBeef)) return false;
        return _toppings.Add(ingredientId);
    }
    public bool AddMixDistance(double pixels)
    {
        if (State is not (NoodleBowlState.Seasoned or NoodleBowlState.Mixing) || pixels <= 0) return false;
        State = NoodleBowlState.Mixing;
        MixProgress = Math.Min(100, MixProgress + pixels / 5.0);
        if (MixProgress >= 85) { MixProgress = 100; State = NoodleBowlState.Ready; }
        return true;
    }
    public bool TryPrepare(IReadOnlyDictionary<string, RecipeData> recipes, out PreparedHotDryNoodles prepared)
    {
        prepared = null!;
        if (State != NoodleBowlState.Ready) return false;
        RecipeData? recipe = recipes.Values.FirstOrDefault(item => item.Id.StartsWith("hot_dry_noodles_", StringComparison.Ordinal) && _toppings.SetEquals(item.ExtraIngredients));
        string id = recipe?.Id ?? $"invalid:{string.Join('+', _toppings.OrderBy(value => value, StringComparer.Ordinal))}";
        prepared = new PreparedHotDryNoodles(id, _quality, true);
        return true;
    }
    public void Reset() { State = NoodleBowlState.Empty; MixProgress = 0; _toppings.Clear(); }
    public static WuhanFoodQuality ToQuality(PreparedHotDryNoodles item) => WuhanFoodQuality.MixedComplete | item.NoodleQuality switch
    {
        NoodleQuality.Soft => WuhanFoodQuality.NoodlesSoft,
        NoodleQuality.Overcooked => WuhanFoodQuality.NoodlesOvercooked,
        _ => WuhanFoodQuality.None,
    };
}
