using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.Fryer;
namespace ProjectCake.Core;

public sealed record DeliveryReceipt(string RunId, string StageId, DeliveredItem Item, bool Matched, bool Accepted, bool Tutorial);
public sealed record BreakfastCard(string Id, string CityId, string Name, string Visual, string Description, string Steps);
public static class DemoBreakfastCollection
{
    public static readonly BreakfastCard[] Cards =
    {
        new("pancake", StableIds.Cities.Tianjin, "煎饼果子", "Pancake", "一张薄饼，卷起天津的清晨。", "摊饼 → 加蛋 → 翻面 → 刷酱与配料 → 折叠装袋"),
        new("youtiao", StableIds.Cities.Tianjin, "油条", "Youtiao", "金黄出锅，沥油后趁热送出。", "装入生油条 → 下锅 → 金黄时提篮 → 沥油 → 交付"),
        new("soy_milk", StableIds.Cities.Tianjin, "豆浆", "SoyMilk", "供应记录 · 先递一杯，为制作争取时间。", "查看组合订单 → 先交豆浆 → 留意耐心恢复"),
        new("noodles", StableIds.Cities.Wuhan, "热干面", "HotDryNoodles", "提篮沥水，把酱香拌进每一根面。", "生面入篮 → 提篮沥水 → 入碗调味 → 拌匀 → 交付"),
        new("doupi", StableIds.Cities.Wuhan, "三鲜豆皮", "Doupi", "一锅成形，切成一份份武汉早餐。", "倒浆加蛋 → 定型翻面 → 放馅 → 成熟切块 → 入盘交付"),
    };
    public static string? Qualifies(DeliveredItem item) => item.ProductKind switch
    {
        ProductKind.Pancake when item.PancakeQuality == PancakeQuality.Perfect
            && (!item.DefinitionId.Contains("youtiao") || item.InternalYoutiaoQuality == YoutiaoQuality.Golden) => "pancake",
        ProductKind.Youtiao when item.YoutiaoQuality == YoutiaoQuality.Golden => "youtiao",
        ProductKind.SoyMilk => "soy_milk",
        ProductKind.HotDryNoodles when item.WuhanQuality is { } q && q.HasFlag(WuhanFoodQuality.MixedComplete)
            && (q & (WuhanFoodQuality.NoodlesSoft | WuhanFoodQuality.NoodlesOvercooked)) == 0 => "noodles",
        ProductKind.Doupi when item.WuhanQuality is { } q && !q.HasFlag(WuhanFoodQuality.DoupiOverbrowned) => "doupi",
        _ => null,
    };
    public static void Observe(DeliveryReceipt receipt, DayPlan plan)
    {
        if (receipt.Tutorial || !receipt.Matched || !receipt.Accepted || receipt.RunId != plan.RunId
            || receipt.StageId != plan.StageId) return;
        string? id = receipt.Item.ProductKind switch
        {
            ProductKind.Pancake => "pancake", ProductKind.Youtiao => "youtiao", ProductKind.SoyMilk => "soy_milk",
            ProductKind.HotDryNoodles => "noodles", ProductKind.Doupi => "doupi", _ => null,
        };
        if (id is null) return;
        if (!plan.PendingBreakfastStats.TryGetValue(id, out var stats)) plan.PendingBreakfastStats[id] = stats = new();
        stats.Delivered++;
        if (Qualifies(receipt.Item) is not null)
        {
            plan.PendingBreakfastRecords.Add(id);
            if (id != "soy_milk") stats.Perfect++;
        }
    }
}
