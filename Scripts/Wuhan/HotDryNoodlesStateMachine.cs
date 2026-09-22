using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Wuhan;

public enum NoodleBowlState { Empty, Noodles, Seasoned, Mixing, Ready }
public sealed record PreparedHotDryNoodles(string RecipeId, NoodleQuality NoodleQuality, bool MixedComplete);

public sealed class HotDryNoodlesStateMachine
{
    public const double MixCompletionProgress = 85;
    private readonly HashSet<string> _toppings = new(StringComparer.Ordinal);
    private NoodleQuality _quality;
    public NoodleBowlState State { get; private set; }
    public long Generation { get; private set; }
    public double MixProgress { get; private set; }
    public NoodleQuality Quality => _quality;
    public IReadOnlySet<string> Toppings => _toppings;
    public bool HasBaseSeasoning { get; private set; }

    public bool TryAddNoodles(NoodleQuality quality)
    {
        if (State != NoodleBowlState.Empty) return false;
        _quality = quality; State = NoodleBowlState.Noodles; return true;
    }
    public bool TryAddBaseSeasoning()
    {
        if (HasBaseSeasoning || State is not (NoodleBowlState.Noodles or NoodleBowlState.Seasoned)) return false;
        HasBaseSeasoning = true;
        State = NoodleBowlState.Seasoned; return true;
    }
    public bool TryAddTopping(string ingredientId)
    {
        bool allowed = ingredientId switch
        {
            StableIds.Ingredients.WuhanBraisedBeef => State == NoodleBowlState.Ready,
            StableIds.Ingredients.WuhanScallion or StableIds.Ingredients.WuhanChiliOil => State is NoodleBowlState.Noodles or NoodleBowlState.Seasoned,
            _ => false,
        };
        if (!allowed) return false;
        if (!_toppings.Add(ingredientId)) return false;
        if (State == NoodleBowlState.Noodles) State = NoodleBowlState.Seasoned;
        return true;
    }
    public bool AddMixDistance(double pixels)
    {
        if (!HasBaseSeasoning || State is not (NoodleBowlState.Seasoned or NoodleBowlState.Mixing) || pixels <= 0) return false;
        State = NoodleBowlState.Mixing;
        MixProgress = Math.Min(100, MixProgress + pixels / 5.0);
        if (MixProgress >= MixCompletionProgress) { MixProgress = 100; State = NoodleBowlState.Ready; }
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
    public void Reset() { Generation++; State = NoodleBowlState.Empty; MixProgress = 0; HasBaseSeasoning = false; _toppings.Clear(); }
    public static WuhanFoodQuality ToQuality(PreparedHotDryNoodles item) => WuhanFoodQuality.MixedComplete | item.NoodleQuality switch
    {
        NoodleQuality.Soft => WuhanFoodQuality.NoodlesSoft,
        NoodleQuality.Overcooked => WuhanFoodQuality.NoodlesOvercooked,
        _ => WuhanFoodQuality.None,
    };
}
