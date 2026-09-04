namespace ProjectCake.Data;

public static class StableIds
{
    public static class Products
    {
        public const string Youtiao = "youtiao";
        public const string SoyMilk = "soy_milk";

        public static readonly IReadOnlySet<string> All = new HashSet<string>(StringComparer.Ordinal)
        {
            Youtiao,
            SoyMilk,
        };
    }

    public static class Ingredients
    {
        public const string Batter = "batter";
        public const string Egg = "egg";
        public const string Sauce = "sauce";
        public const string Crispy = "crispy";
        public const string Scallion = "scallion";
        public const string Ham = "ham";
        public const string Youtiao = "youtiao";
    }

    public static class Recipes
    {
        public const string Basic = "pancake_basic";
        public const string Crispy = "pancake_crispy";
        public const string Scallion = "pancake_scallion";
        public const string ScallionCrispy = "pancake_scallion_crispy";
        public const string Ham = "pancake_ham";
        public const string HamCrispy = "pancake_ham_crispy";
        public const string Youtiao = "pancake_youtiao";
        public const string ScallionYoutiao = "pancake_scallion_youtiao";

        public static readonly IReadOnlySet<string> All = new HashSet<string>(StringComparer.Ordinal)
        {
            Basic,
            Crispy,
            Scallion,
            ScallionCrispy,
            Ham,
            HamCrispy,
            Youtiao,
            ScallionYoutiao,
        };
    }

    public static readonly IReadOnlySet<string> IngredientIds = new HashSet<string>(StringComparer.Ordinal)
    {
        Ingredients.Batter,
        Ingredients.Egg,
        Ingredients.Sauce,
        Ingredients.Crispy,
        Ingredients.Scallion,
        Ingredients.Ham,
        Ingredients.Youtiao,
    };

    public static readonly IReadOnlySet<string> CustomerTypeIds = new HashSet<string>(StringComparer.Ordinal)
    {
        "normal",
        "office_worker",
        "regular",
        "big_order",
    };

    public static readonly IReadOnlySet<string> OrderTypeIds = new HashSet<string>(StringComparer.Ordinal)
    {
        "pancake",
        "youtiao",
        "pancake_youtiao",
        "soy_milk",
        "pancake_soy_milk",
        "full_combo",
    };

    public static readonly IReadOnlySet<string> UnlockIds = BuildUnlockIds();

    public static string RecipeUnlock(string recipeId) => $"recipe:{recipeId}";

    private static IReadOnlySet<string> BuildUnlockIds()
    {
        var values = new HashSet<string>(StringComparer.Ordinal);

        foreach (string recipeId in Recipes.All)
        {
            values.Add(RecipeUnlock(recipeId));
        }

        foreach (string ingredientId in IngredientIds)
        {
            values.Add($"ingredient:{ingredientId}");
        }

        values.Add("equipment:ingredient_station_lv2");
        values.Add("equipment:ingredient_station_lv3");
        values.Add("equipment:pancake_stove_lv2");
        values.Add("equipment:pancake_stove_lv3");
        values.Add("equipment:fryer_lv1");
        values.Add("equipment:fryer_lv2");
        values.Add("equipment:fryer_lv3");
        values.Add("product:soy_milk");
        values.Add("product:youtiao");

        return values;
    }
}
