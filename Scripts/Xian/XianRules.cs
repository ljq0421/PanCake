namespace ProjectCake.Xian;

public static class XianRules
{
    public const string Oven = "xian_oven", Board = "xian_board", Soup = "xian_soup";
    public static readonly string[] Recipes = { "roujiamo_standard", "roujiamo_juicy", "roujiamo_extra_meat", "roujiamo_extra_juicy" };
    public static readonly string[] RecipeNames = { "标准肉夹馍", "加汁肉夹馍", "多肉肉夹馍", "多肉加汁肉夹馍" };
    public static readonly string[] Titles = { "第一只肉夹馍", "来点腊汁", "白吉馍炉到了", "提前备货", "多肉更满足", "肉丸胡辣汤", "完整菜单", "熟客来了", "两人份早餐", "自动化准备", "长安早高峰", "西安早餐大挑战" };
    public static string RecipeId(int meat, bool juice) => Recipes[(meat == 2 ? 2 : 0) + (juice ? 1 : 0)];
    public static int Meat(string id) => Array.IndexOf(Recipes, id) >= 2 ? 2 : 1;
    public static bool Juice(string id) => id == Recipes[1] || id == Recipes[3];
    public static string EquipmentName(string id) => id switch { Oven => "白吉馍炉", Board => "剁肉台", _ => "胡辣汤锅" };
    public static bool IsDouble(string type) => type is "xian_d" or "xian_e";
    public static double Pressure(string type) => type switch { "xian_a" => 1, "xian_b" => .3, "xian_c" => 1.3, "xian_d" => 2, "xian_e" => 2.3, _ => 0 };
}

public enum BunQuality { Golden, Overbrowned, Burnt }
public enum BunOvenState { Empty, FirstSide, SecondSide, Ready, Burnt }
public enum RoujiamoState { Empty, Whole, Open, Wrapped }
