using ProjectCake.Data;

namespace ProjectCake.Guangzhou;

public static class GuangzhouRules
{
    public const string Stove = "guangzhou_stove", Cabinet = "guangzhou_cabinet", Station = "guangzhou_station";
    public const string Batter = "gz_batter", Egg = "gz_egg", Pork = "gz_pork", Shrimp = "gz_shrimp", Sauce = "gz_sauce";
    public const string SiuMai = "gz_siu_mai", HarGow = "gz_har_gow", Tea = "gz_tea";
    public static readonly string[] Recipes = { "gz_plain", "gz_egg", "gz_pork", "gz_shrimp", "gz_egg_pork" };
    public static readonly string[] RecipeNames = { "斋肠粉", "鸡蛋肠粉", "猪肉肠粉", "虾仁肠粉", "鸡蛋猪肉肠粉" };
    public static readonly string[] Ingredients = { Batter, Egg, Pork, Shrimp, Sauce };
    public static readonly string[] Equipment = { Stove, Cabinet, Station };
    public static readonly string[] Customers = { "gz_normal", "gz_office", "gz_regular", "gz_tourist", "gz_family" };
    public static readonly string[] Orders = { "gz_a", "gz_b", "gz_c", "gz_d", "gz_e", "gz_f" };
    public static string Name(string id) => id switch
    {
        Batter => "米浆", Egg => "鸡蛋", Pork => "猪肉", Shrimp => "虾仁", Sauce => "豉油",
        SiuMai => "干蒸烧卖", HarGow => "虾饺", Tea => "早茶", Stove => "肠粉炉", Cabinet => "点心蒸柜", Station => "配料台",
        "gz_plain" => RecipeNames[0], "gz_egg_pork" => RecipeNames[4], _ => id,
    };
    public static int RecipeUnlockDay(int index) => new[] { 1, 2, 3, 7, 10 }[index];
    public static bool HasRiceRoll(string order) => order is "gz_a" or "gz_d" or "gz_e" or "gz_f";
    public static bool HasDimSum(string order) => order is "gz_b" or "gz_e" or "gz_f";
    public static bool HasTea(string order) => order is "gz_c" or "gz_d" or "gz_f";
    public static bool IsComplex(string order) => order is "gz_d" or "gz_e" or "gz_f";
    public static ProductKind DimSumKind(string id) => id == HarGow ? ProductKind.HarGow : ProductKind.SiuMai;
    public static bool IsProduct(ProductKind kind) => kind is ProductKind.RiceRoll or ProductKind.SiuMai or ProductKind.HarGow or ProductKind.MorningTea;
}

public enum RiceRollQuality { Perfect, Normal, Dry }
public enum DimSumQuality { Perfect, Normal, Oversteamed }

/// <summary>Independent defects must survive presentation's three quality labels.</summary>
public sealed record GuangzhouFoodQuality(bool Complete = false, RiceRollQuality? RiceRoll = null,
    bool Broken = false, DimSumQuality? DimSum = null);
