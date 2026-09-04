using ProjectCake.Data;
using ProjectCake.Fryer;

namespace ProjectCake.Pancake;

public sealed class PancakeRuntime
{
    private readonly HashSet<string> _extraIngredients = new(StringComparer.Ordinal);

    public PancakeState State { get; internal set; } = PancakeState.Empty;
    public PancakeQuality Quality { get; internal set; } = PancakeQuality.Perfect;
    public double CookingSeconds { get; internal set; }
    public double SpreadCoverage { get; internal set; }
    public double SauceCoverage { get; internal set; }
    public bool HasEgg { get; internal set; }
    public bool HasSauce { get; internal set; }
    public IReadOnlySet<string> ExtraIngredients => _extraIngredients;
    public YoutiaoQuality? InternalYoutiaoQuality { get; internal set; }

    internal bool AddIngredient(string ingredientId) => _extraIngredients.Add(ingredientId);

    internal void Reset()
    {
        State = PancakeState.Empty;
        Quality = PancakeQuality.Perfect;
        CookingSeconds = 0;
        SpreadCoverage = 0;
        SauceCoverage = 0;
        HasEgg = false;
        HasSauce = false;
        _extraIngredients.Clear();
        InternalYoutiaoQuality = null;
    }

    public bool Matches(RecipeData recipe) =>
        _extraIngredients.SetEquals(recipe.ExtraIngredients);
}
