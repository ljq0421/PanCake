using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public sealed partial class BookUpgradeSource
{
    public BookUpgradeOffer? LastPurchased { get; private set; }
    public int NextDay => _save.Data.GetCity(_city).HighestUnlockedDay;
    public bool SupportsContinue => _city is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan;
    public string NextGoal
    {
        get
        {
            if (!SupportsContinue || _catalog is null) return "";
            if (LastPurchased is { } bought) return $"下次营业体验：{bought.Name} Lv{bought.TargetLevel} · {Benefit(bought)}";
            foreach (string id in _city == StableIds.Cities.Tianjin
                ? new[] { BaseEquipmentPurchases.Fryer, BaseEquipmentPurchases.SoyTray }
                : new[] { BaseEquipmentPurchases.DoupiGriddle })
            {
                var item = BaseEquipmentPurchases.Describe(id);
                if (_save.Data.GetCity(_city).EquipmentLevels.GetValueOrDefault(item.Equipment) > 0) continue;
                if (NextDay < item.Day) return $"下一目标：{item.Name} · Day {item.Day} 到货 · {item.Price} 金币";
                return Coins >= item.Price ? $"可以买了：{item.Name} · {item.Price} 金币"
                    : $"攒钱买{item.Name}：{Coins} / {item.Price} 金币 · 还差 {item.Price - Coins}";
            }
            var candidates = Equipment.Where(e => e.TargetLevel.HasValue)
                .Select(e => new BookUpgradeOffer(_city, e.PurchaseId, e.Id, e.Name, e.Level, e.TargetLevel!.Value, e.Price))
                .Where(o => _save.Data.GetCity(_city).UnlockedContentIds.Contains(o.PurchaseId))
                .OrderBy(o => Priority(o)).ThenBy(o => o.Price).ThenBy(o => o.EquipmentId, StringComparer.Ordinal).ToArray();
            if (candidates.FirstOrDefault(o => o.Price <= Coins) is { } available)
                return $"可以买了：{available.Name} Lv{available.TargetLevel} · {Benefit(available)}";
            if (NextDay <= _save.ChapterLength(_city) && _catalog.TryGetDay(_city, NextDay, out var next))
            {
                string? newFood = next.StartUnlocks.FirstOrDefault(id => id.StartsWith("product:"))
                    ?? next.StartUnlocks.FirstOrDefault(id => id.StartsWith("recipe:"));
                if (newFood is not null)
                {
                    string id = newFood[(newFood.IndexOf(':') + 1)..];
                    string name = _catalog.ProductsById.TryGetValue(id, out var product) ? product.DisplayName
                        : _catalog.RecipesById.TryGetValue(id, out var recipe) ? recipe.DisplayName : "新餐品";
                    string benefit = id switch { "youtiao" => "趁摊饼的空隙提前炸好油条", "soy_milk" => "先递豆浆，为主食制作争取时间", "doupi" => "提前备好豆皮，高峰时快速出餐", _ => "试试新的早餐搭配" };
                    return $"明日新餐品：{name} · {benefit}";
                }
            }
            if (candidates.FirstOrDefault() is { } saving)
                return $"升级目标：{saving.Name} Lv{saving.TargetLevel} · 还差 {saving.Price - Coins} 金币";
            return _catalog.TryGetDay(_city, NextDay, out var config) && DailyChallenge.Create(config) is { } challenge
                ? challenge.Preview(_save.Data.GetCity(_city).ClaimedChallenges.ContainsKey(NextDay)) : "准备迎接下一天的街坊。";
        }
    }
    private static int Priority(BookUpgradeOffer o) => (o.EquipmentId, o.TargetLevel) is ("pancake_stove", 2) or ("fryer", 3)
        or ("noodle_cooker", 2 or 3) or ("doupi_griddle", 2 or 3) ? 0 : 1;
    public static string Benefit(BookUpgradeOffer o) => (o.EquipmentId, o.TargetLevel) switch
    {
        ("pancake_stove", 2) => "不再煎焦，腾出注意力照顾炸锅",
        ("fryer", 1) => "开始供应油条",
        ("soy_milk_tray", 1) => "开始供应豆浆",
        ("doupi_griddle", 1) => "开始供应三鲜豆皮",
        ("pancake_stove", 3) => "保持防焦，煎饼熟得更快",
        ("fryer", 2) => "一锅容量增加，油条更快炸至金黄",
        ("fryer", 3) => "自动提篮，可以安心处理其他订单",
        ("noodle_cooker", 2) => "锁定最佳熟度，仍需手动提篮",
        ("noodle_cooker", 3) => "双篮并行，熟面自动提起",
        ("doupi_griddle", 2) => "恒温防焦，安心穿插制作热干面",
        ("doupi_griddle", 3) => "自动翻面、加快制作，仍需手动切块",
        _ => "增加备料容量，减少补料中断",
    };
}
