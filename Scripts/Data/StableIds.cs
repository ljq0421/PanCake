namespace ProjectCake.Data;

public static class StableIds
{
    public static class Cities
    {
        public const string Tianjin = "city:tianjin";
        public const string Wuhan = "city:wuhan";
        public const string Xian = "city:xian";
        public const string Guangzhou = "city:guangzhou";
        public const string Yangzhou = "city:yangzhou";
    }

    public static class Products
    {
        public const string Youtiao = "youtiao";
        public const string SoyMilk = "soy_milk";
        public const string Doupi = "doupi";
        public const string EggRiceWine = "egg_rice_wine";

        public static readonly IReadOnlySet<string> All = new HashSet<string>(StringComparer.Ordinal)
        {
            Youtiao,
            SoyMilk,
            Doupi,
            EggRiceWine,
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
        public const string WuhanNoodles = "wuhan_noodles";
        public const string WuhanBaseSeasoning = "wuhan_base_seasoning";
        public const string WuhanScallion = "wuhan_scallion";
        public const string WuhanChiliOil = "wuhan_chili_oil";
        public const string WuhanBraisedBeef = "wuhan_braised_beef";
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
        public const string HotDryNoodlesClassic = "hot_dry_noodles_classic";
        public const string HotDryNoodlesScallion = "hot_dry_noodles_scallion";
        public const string HotDryNoodlesChili = "hot_dry_noodles_chili";
        public const string HotDryNoodlesScallionChili = "hot_dry_noodles_scallion_chili";
        public const string HotDryNoodlesBeef = "hot_dry_noodles_beef";
        public const string HotDryNoodlesBeefChili = "hot_dry_noodles_beef_chili";

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
            HotDryNoodlesClassic,
            HotDryNoodlesScallion,
            HotDryNoodlesChili,
            HotDryNoodlesScallionChili,
            HotDryNoodlesBeef,
            HotDryNoodlesBeefChili,
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
        Ingredients.WuhanNoodles,
        Ingredients.WuhanBaseSeasoning,
        Ingredients.WuhanScallion,
        Ingredients.WuhanChiliOil,
        Ingredients.WuhanBraisedBeef,
    };

    public static readonly IReadOnlySet<string> CustomerTypeIds = new HashSet<string>(StringComparer.Ordinal)
    {
        "normal",
        "office_worker",
        "regular",
        "big_order",
        "wuhan_normal",
        "wuhan_office_worker",
        "wuhan_regular",
        "wuhan_tourist",
        "wuhan_big_order",
        "xian_normal", "xian_office_worker", "xian_regular", "xian_tourist",
    };

    public static readonly IReadOnlySet<string> OrderTypeIds = new HashSet<string>(StringComparer.Ordinal)
    {
        "pancake",
        "youtiao",
        "pancake_youtiao",
        "soy_milk",
        "pancake_soy_milk",
        "full_combo",
        "hot_dry_noodles",
        "doupi",
        "egg_rice_wine",
        "noodles_doupi",
        "noodles_egg_rice_wine",
        "wuhan_full_combo",
        "xian_a", "xian_b", "xian_c", "xian_d", "xian_e",
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
        values.Add("product:doupi");
        values.Add("product:egg_rice_wine");
        values.Add("equipment:wuhan_ingredient_station_lv2");
        values.Add("equipment:wuhan_ingredient_station_lv3");
        values.Add("equipment:noodle_cooker_lv2");
        values.Add("equipment:noodle_cooker_lv3");
        values.Add("equipment:doupi_griddle_lv1");
        values.Add("equipment:doupi_griddle_lv2");
        values.Add("equipment:doupi_griddle_lv3");
        values.Add("equipment:egg_rice_wine_station");

        foreach (string recipe in ProjectCake.Xian.XianRules.Recipes) values.Add(RecipeUnlock(recipe));
        foreach (string eq in new[] { "xian_oven", "xian_board", "xian_soup" })
            for (int level = 1; level <= 3; level++) values.Add($"equipment:{eq}_lv{level}");
        values.Add("product:hulatang");
        return values;
    }
}
