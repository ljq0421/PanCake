using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Xian;
using ProjectCake.Guangzhou;
using ProjectCake.Yangzhou;

namespace ProjectCake.UI;

public sealed record CityEquipmentView(string Id, string Name, int Level, string? Art,
    string Detail, int Price, string PurchaseId, bool CanBuy, string Notice)
{
    public int? TargetLevel { get; init; }
    public IReadOnlyList<EquipmentEffect> Effects { get; init; } = Array.Empty<EquipmentEffect>();
}

/// <summary>Read-only presentation adapter; purchases still use the city's save service.</summary>
public sealed partial class CityPageModel(DataCatalog? catalog, SaveService save, YangzhouCatalog? yangzhou)
{
    private DataCatalog Catalog => catalog ?? throw new InvalidOperationException("该城市缺少设备配置。");
    private YangzhouCatalog Yangzhou => yangzhou ?? throw new InvalidOperationException("扬州缺少设备配置。");
    public string[] LedgerArt(string city, int day)
    {
        if (city == StableIds.Cities.Tianjin)
        {
            string[] names = day switch {
                2 => new[] { "装袋后的通用煎饼果子", "薄脆" },
                3 => new[] { "装袋后的通用煎饼果子", "香葱碎" },
                5 => new[] { "熟油条" },
                6 or 7 => new[] { "装袋后的通用煎饼果子", "熟油条" },
                8 => new[] { "装袋后的通用煎饼果子", "火腿片" },
                9 => new[] { "装袋后的通用煎饼果子", "成品豆浆杯" },
                11 => new[] { "普通男上班族", "装袋后的通用煎饼果子" },
                >= 10 => new[] { "装袋后的通用煎饼果子", "熟油条", "成品豆浆杯" },
                _ => new[] { "装袋后的通用煎饼果子" },
            };
            return names.Select(n => "res://resource/art/TianJin/" + n + ".png").ToArray();
        }
        if (city == StableIds.Cities.Wuhan)
        {
            string[] names = day switch {
                1 => new[] { "热干面完整成品", "辣油壶_v2", "葱花覆盖层" },
                2 => new[] { "热干面完整成品", "葱花覆盖层", "辣油壶_v2" },
                3 => new[] { "热干面完整成品", "卤牛肉片" },
                4 or 5 => new[] { "热干面完整成品", "DoupiPieces_v1/piece-01" },
                6 => new[] { "热干面完整成品", "成品蛋酒杯_v2" },
                7 => new[] { "热干面完整成品", "卤牛肉片" },
                10 => new[] { "DoupiPieces_v1/piece-01", "三鲜豆皮锅 Lv3 自动翻面快热版锅体_v2" },
                >= 8 => new[] { "热干面完整成品", "DoupiPieces_v1/piece-01", "成品蛋酒杯_v2" },
                _ => new[] { "热干面完整成品" },
            };
            return names.Select(n => "res://resource/art/Wuhan/" + n + ".png").ToArray();
        }
        return Array.Empty<string>();
    }
    public string DayTitle(string city, int day) => day > SaveService.ChapterDays(city) ? "日常营业" : city switch
    {
        StableIds.Cities.Tianjin => MorningHub.DaySubtitle(day),
        StableIds.Cities.Wuhan => WuhanHub.DaySubtitle(day),
        StableIds.Cities.Xian => XianRules.Titles[day - 1],
        StableIds.Cities.Yangzhou => Yangzhou.Days.Single(d => d.Day == day).Title,
        _ => new[] { "斋肠初体验", "蒸前加鸡蛋", "猪肉肠", "第一次高峰", "烧卖开蒸", "双线备货", "虾仁与早班", "添一杯早茶", "虾饺登场", "一盅两件", "完整早餐高峰", "最终早茶挑战" }[day - 1],
    };

    public CityEquipmentView[] Equipment(string city)
    {
        string[] ids = city switch
        {
            StableIds.Cities.Tianjin => new[] { "pancake_stove", "fryer", "ingredient_station" },
            StableIds.Cities.Wuhan => new[] { "noodle_cooker", "doupi_griddle", "ingredient_station" },
            StableIds.Cities.Xian => new[] { XianRules.Oven, XianRules.Board, XianRules.Soup },
            StableIds.Cities.Guangzhou => GuangzhouRules.Equipment,
            _ => new[] { YangzhouCatalog.BoardId, YangzhouCatalog.SteamerId },
        };
        return ids.Select(id => Describe(city, id)).ToArray();
    }

    private CityEquipmentView Describe(string city, string id)
    {
        var progress = JourneyModel.Progress(save, city);
        int level = progress.EquipmentLevels.GetValueOrDefault(id);
        int maximum = 3;
        int target = Math.Min(maximum, Math.Max(1, level) + 1), price = 0, after = 0;
        string name = id, detail = "", purchase = $"equipment:{id}_lv{target}";
        string? art = null;
        const string root = "res://resource/art/";
        bool fixedStation = city == StableIds.Cities.Wuhan && id == "ingredient_station";
        switch (city)
        {
            case StableIds.Cities.Tianjin:
                if (id == "pancake_stove") { var d = Catalog.StovesByLevel[target]; name = "煎饼炉"; price = d.UpgradePrice; detail = $"{(d.CanBurn ? "手动控温" : "恒温不焦")}\n正面 {d.SideAReadySeconds:0.##} 秒成熟"; art = root + "TianJin/BusinessSign/stove.png"; }
                else if (id == "fryer") { var d = Catalog.FryersByLevel[target]; name = "油条锅"; price = d.UpgradePrice; detail = $"容量 {d.Capacity} 根\n{(d.AutoRaise ? "自动抬篮" : "手动抬篮")}"; art = root + "TianJin/BusinessSign/fryer.png"; }
                else { var d = Catalog.IngredientStationsByLevel[target]; name = "配料台"; price = d.UpgradePrice; detail = $"鸡蛋 {d.EggCapacity} · 薄脆 {d.CrispyCapacity}\n香葱 {d.ScallionCapacity} · 火腿 {d.HamCapacity}"; art = root + "TianJin/升级小料.png"; }
                break;
            case StableIds.Cities.Wuhan:
                if (id == "noodle_cooker") { var d = Catalog.NoodleCookersByLevel[target]; name = "煮面锅"; price = d.UpgradePrice; detail = $"{d.BasketCount} 个面篮 · {d.OptimalSeconds:0.##} 秒\n{(d.AutoRaise ? "自动提篮" : "手动提篮")}"; art = root + $"Wuhan/煮面锅 Lv{Math.Max(1, level)} {new[] { "基础锅体", "自动提篮版锅体", "双漏勺快热版锅体" }[Math.Max(1, level)-1]}_v2.png"; }
                else if (id == "doupi_griddle") { var d = Catalog.DoupiGriddlesByLevel[target]; name = "豆皮锅"; price = d.UpgradePrice; detail = $"每锅 {d.BatchYield} 份\n{(d.AutoFlip ? "自动翻面" : d.CanBurn ? "手动控温" : "恒温不焦")}"; art = root + "Wuhan/" + (level >= 3 ? "三鲜豆皮锅 Lv3 自动翻面快热版锅体_v2.png" : level == 2 ? "三鲜豆皮锅 Lv2 恒温版_v2.png" : "三鲜豆皮锅 Lv1 基础锅体_v2.png"); }
                else { name = "备料台"; detail = "生面无限供应"; art = root + "Wuhan/生热干面面条.png"; }
                break;
            case StableIds.Cities.Xian:
                var x = Catalog.GetXianEquipment(id, target); name = XianRules.EquipmentName(id); price = x.UpgradePrice; after = x.UnlockAfterDay;
                detail = id == XianRules.Board ? $"预剁 {x.StockCapacity} 份\n操作量 {x.WorkMultiplier:P0}" : id == XianRules.Oven ? $"一炉 {x.Capacity} 个 · 备货 {x.StockCapacity}\n{(x.Automatic ? "自动翻面、出炉" : x.BurnProof ? "恒温不焦" : "手动翻面")}" : $"容量 {x.Capacity} 份\n补锅 {x.RefillSeconds:0.#} 秒";
                art = root + "XiAn/" + (id == XianRules.Oven ? $"白吉馍炉 Lv{Math.Max(1, level)} {new[] { "基础版", "恒温版", "自动翻面快热版" }[Math.Max(1, level)-1]}" : id == XianRules.Board ? "肉夹馍砧板＋主组装台" : level >= 3 ? "肉丸胡辣汤锅 Lv3 大容量版_v1" : level == 2 ? "肉丸胡辣汤锅 Lv2 扩容版_v1" : "肉丸胡辣汤锅 Lv1") + ".png";
                break;
            case StableIds.Cities.Guangzhou:
                var g = Catalog.GetGuangzhouEquipment(id, target); name = GuangzhouRules.Name(id); price = g.UpgradePrice; after = g.UnlockAfterDay;
                detail = id == GuangzhouRules.Stove ? $"{g.Capacity} 屉 · {g.CookSeconds:0.#} 秒\n{(g.PopOut ? "熟后弹出提示" : g.KeepWarm ? "保温防过蒸" : "手动控时")}" : id == GuangzhouRules.Cabinet ? $"{g.Capacity} 层 · 烧卖 {g.CookSeconds:0.#} 秒\n{(g.KeepWarm ? "自动保温" : "手动取出")}" : $"米浆 {g.BatterCapacity} · 鸡蛋 {g.EggCapacity}\n肉 {g.PorkCapacity} · 虾 {g.ShrimpCapacity}";
                break;
            default:
                bool board = id == YangzhouCatalog.BoardId; name = board ? "干丝台" : "竹蒸笼"; purchase = id;
                if (board) { var d = Yangzhou.Boards.Single(d => d.Level == target); price = d.Price; after = d.UnlockAfterDay; detail = $"每块 {d.Yield} 份 · 库存 {d.Capacity}\n{d.Snap:P0} 辅助完成"; }
                else { var d = Yangzhou.Steamers.Single(d => d.Level == target); price = d.Price; after = d.UnlockAfterDay; detail = $"{d.Layers} 层 × {d.Capacity} 格\n{(d.Hold ? "自动保温，手动出笼" : "留意出笼火候")}"; }
                break;
        }
        if (after == 0 && city != StableIds.Cities.Yangzhou)
            for (int day = 1; day <= save.ChapterLength(city); day++)
                if (Catalog.TryGetDay(city, day, out var config) && config.CompletionUnlocks.Contains(purchase)) { after = day; break; }
        bool available = !save.HasLoadError && save.Data.UnlockedCityIds.Contains(city) && (city == StableIds.Cities.Yangzhou || Catalog.IsValid);
        string notice = "";
        if (fixedStation) { available = false; notice = "生面无限供应"; }
        else if (level == 0) { available = false; notice = "对应营业日开张时免费开放"; }
        else if (level >= maximum) { available = false; notice = "已升至最高等级"; }
        else if (city == StableIds.Cities.Yangzhou) { available &= save.CanPurchaseYangzhou(id, Yangzhou, out notice); }
        else { available &= save.CanPurchase(city, purchase, Catalog, out notice); }
        if (level > 0 && level < 3 && !fixedStation && after > 0 && !progress.DayBestRecords.ContainsKey(after)) notice = $"完成第 {after} 天后开放";
        if (save.HasLoadError) notice = "存档无法读取";
        int current = Math.Max(1, level);
        var effects = fixedStation ? new[] { new EquipmentEffect("生面供应", "无限供应", "无限供应") }
            : BookUpgradeEffects.Compare(new(city, purchase, id, name, current, level == 0 ? current : target, price), catalog, yangzhou);
        return new(id, name, level, art, detail, price, purchase, available, notice)
        { TargetLevel = fixedStation || level == 0 || level >= maximum ? null : target, Effects = effects };
    }
}
