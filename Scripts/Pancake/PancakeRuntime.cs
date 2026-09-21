using ProjectCake.Data;
using ProjectCake.Fryer;

namespace ProjectCake.Pancake;

public sealed class PancakeRuntime
{
    internal long Generation { get; private set; }
    private readonly HashSet<string> _extraIngredients = new(StringComparer.Ordinal);
    private readonly List<string> _extraIngredientOrder = [];

    public PancakeState State { get; internal set; } = PancakeState.Empty;
    public PancakeQuality Quality { get; internal set; } = PancakeQuality.Perfect;
    public double CookingSeconds { get; internal set; }
    public double SpreadCoverage { get; internal set; }
    public double SauceCoverage { get; internal set; }
    public bool HasEgg { get; internal set; }
    public bool HasSauce { get; internal set; }
    public IReadOnlySet<string> ExtraIngredients => _extraIngredients;
    /// <summary>附加小料的实际加入顺序；末项应绘制在最上层。</summary>
    public IReadOnlyList<string> ExtraIngredientOrder => _extraIngredientOrder;
    public YoutiaoQuality? InternalYoutiaoQuality { get; internal set; }

    internal bool AddIngredient(string ingredientId)
    {
        if (!_extraIngredients.Add(ingredientId)) return false;
        _extraIngredientOrder.Add(ingredientId);
        return true;
    }

    internal void Reset()
    {
        Generation++;
        State = PancakeState.Empty;
        Quality = PancakeQuality.Perfect;
        CookingSeconds = 0;
        SpreadCoverage = 0;
        SauceCoverage = 0;
        HasEgg = false;
        HasSauce = false;
        _extraIngredients.Clear();
        _extraIngredientOrder.Clear();
        InternalYoutiaoQuality = null;
    }

    public bool Matches(RecipeData recipe) =>
        _extraIngredients.SetEquals(recipe.ExtraIngredients);
}
