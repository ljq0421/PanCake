namespace ProjectCake.UI;

/// <summary>Display-only facts shared by the shop, preview and first-use cue.</summary>
public sealed record EquipmentUpgradePresentation(string City, bool Fixed, int UnlockAfterDay,
    bool DayUnlocked, int CoinsMissing, string Headline, string CurrentArt, string NextArt,
    IReadOnlyList<EquipmentEffect> Highlights)
{
    public static EquipmentUpgradePresentation Create(CityEquipmentView e, string city, int after, bool unlocked, int coins, bool fixedStation)
    {
        string Art(int level) => e.Id switch
        {
            // Keep the same camera and pot body; functional baskets are independent layers.
            "noodle_cooker" => "res://resource/art/Wuhan/煮面锅 Lv1 基础锅体_v2.png",
            "doupi_griddle" => "res://resource/art/Wuhan/三鲜豆皮锅 Lv1 基础锅体_v2.png",
            _ => e.Art ?? "",
        };
        string[] keys = e.Id switch
        {
            "noodle_cooker" => (e.TargetLevel ?? e.Level) == 3 ? new[] { "面篮数量", "自动提篮", "最佳煮面时间" } : new[] { "锁定最佳熟度", "最佳煮面时间" },
            "doupi_griddle" => (e.TargetLevel ?? e.Level) == 3 ? new[] { "翻面与切块", "第一阶段煎制时间" } : new[] { "火候保护", "第一阶段煎制时间" },
            "pancake_stove" => new[] { "防焦保护", "第一面成熟时间", "第二面成熟时间" },
            "fryer" => (e.TargetLevel ?? e.Level) == 3 ? new[] { "自动提篮", "炸至金黄", "每锅容量" } : new[] { "每锅容量", "炸至金黄" },
            _ => new[] { "鸡蛋容量", "薄脆容量", "葱花容量", "火腿容量", "生面供应" },
        };
        var highlights = keys.Select(k => e.Effects.FirstOrDefault(v => v.Name == k)).Where(v => v is not null).Cast<EquipmentEffect>().ToArray();
        string headline = fixedStation ? "生面随取随用，无需补货" : e.TargetLevel is int next ? HeadlineFor(e.Id, next)
            : e.Level == 0 ? "营业开放后，即可使用" : "好设备，已经准备就绪";
        return new(city, fixedStation, after, unlocked, Math.Max(0, e.Price - coins), headline, Art(e.Level), Art(e.TargetLevel ?? e.Level), highlights);
    }

    public static string HeadlineFor(string id, int level) => (id, level) switch
    {
        ("noodle_cooker", 3) => "一口锅，同时煮两份面！",
        ("noodle_cooker", _) => "锁住好熟度，不怕煮过头",
        ("doupi_griddle", 3) => "豆皮自己翻，腾出手来煮面",
        ("doupi_griddle", _) => "恒温不煎焦，忙起来更从容",
        ("pancake_stove", 3) => "保持不煎焦，下一份更快熟",
        ("pancake_stove", _) => "不再煎焦，安心照顾另一锅",
        ("fryer", 3) => "炸好自动提篮，不用守着锅",
        ("fryer", _) => "一锅多炸些，来客不用慌",
        _ => "多备一些，忙起来少补货",
    };

    public static string FirstUse(string id, int level) => (id, level) switch
    {
        ("fryer", 1) => "新锅已经安装，可以开始炸油条",
        ("doupi_griddle", 1) => "新锅已经安装，可以开始做豆皮",
        ("noodle_cooker", 3) => "另一篮也能下锅！熟面自动提起",
        ("noodle_cooker", _) => "已锁定最佳熟度，煮好记得提篮",
        ("doupi_griddle", 3) => "现在会自动翻面，切块还由你来",
        ("doupi_griddle", _) => "恒温保护已开启，不会煎焦",
        ("pancake_stove", 3) => "煎得更快了，仍需手动翻面",
        ("pancake_stove", _) => "恒温不煎焦，记得手动翻面",
        ("fryer", 3) => "炸好自动提篮，沥好再取用",
        ("fryer", _) => "一锅能装更多，记得手动提篮",
        _ => "备料容量增加了，忙时少补货",
    };

    public string Condition(CityEquipmentView e)
    {
        if (Fixed || e.TargetLevel is null) return e.Notice;
        string day = DayUnlocked ? "" : $"完成第 {UnlockAfterDay} 天后可升级";
        string money = CoinsMissing > 0 ? $"还差 {CoinsMissing} 金币" : "金币已备齐";
        return day.Length > 0 ? day + " · " + money : !e.CanBuy && CoinsMissing == 0 ? e.Notice : money;
    }
    public string State(CityEquipmentView e) => Fixed ? "已生效" : e.Level == 0 ? "未开放" : e.TargetLevel is null ? "已满级"
        : !DayUnlocked ? $"下一级：完成第 {UnlockAfterDay} 天后开放" : CoinsMissing > 0 ? $"还差 {CoinsMissing} 金币" : e.CanBuy ? "可升级" : e.Notice;
    public string Action(CityEquipmentView e) => !DayUnlocked ? "待解锁" : CoinsMissing > 0 ? $"还差 {CoinsMissing} 金币"
        : e.CanBuy ? e.Id == "noodle_cooker" && e.TargetLevel == 3 ? "升级为双篮锅" : "升级设备" : "暂不可升级";
}
