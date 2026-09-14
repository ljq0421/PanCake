using ProjectCake.Core;
using ProjectCake.Yangzhou;

namespace ProjectCake.UI;

public sealed record EquipmentEffect(string Name, string Current, string Next)
{
    public bool Changed => Current != Next;
}

internal static class BookUpgradeEffects
{
    internal static string Describe(BookUpgradeOffer o, DataCatalog? c, YangzhouCatalog? y)
    {
        return string.Join("\n", Compare(o, c, y).Where(e => e.Changed).Select(e => $"{e.Name}：{e.Current} → {e.Next}"));
    }
    internal static IReadOnlyList<EquipmentEffect> Compare(BookUpgradeOffer o, DataCatalog? c, YangzhouCatalog? y)
    {
        var lines = new List<EquipmentEffect>();
        void Change(string name, double a, double b, string unit = "")
        { lines.Add(new(name, $"{a:0.##}{unit}", $"{b:0.##}{unit}")); }
        void Flag(string name, bool a, bool b) { lines.Add(new(name, a ? "开启" : "关闭", b ? "开启" : "关闭")); }
        int from = o.CurrentLevel, to = o.TargetLevel;
        switch (o.EquipmentId)
        {
            case "pancake_stove":
                c!.TryGetStove(from, out var sa); c.TryGetStove(to, out var sb);
                Flag("防焦保护", !sa.CanBurn, !sb.CanBurn);
                Change("第一面成熟时间", sa.SideAReadySeconds, sb.SideAReadySeconds, " 秒");
                Change("第二面成熟时间", sa.SideBReadySeconds, sb.SideBReadySeconds, " 秒"); break;
            case "ingredient_station":
                c!.TryGetIngredientStation(from, out var ia); c.TryGetIngredientStation(to, out var ib);
                lines.Add(new("面糊供应", ia.UnlimitedBatter ? "无限供应" : $"{ia.BatterCapacity} 份", ib.UnlimitedBatter ? "无限供应" : $"{ib.BatterCapacity} 份"));
                lines.Add(new("酱料供应", ia.UnlimitedSauce ? "无限供应" : $"{ia.SauceCapacity} 份", ib.UnlimitedSauce ? "无限供应" : $"{ib.SauceCapacity} 份"));
                Change("鸡蛋容量", ia.EggCapacity, ib.EggCapacity, " 份"); Change("薄脆容量", ia.CrispyCapacity, ib.CrispyCapacity, " 份");
                Change("葱花容量", ia.ScallionCapacity, ib.ScallionCapacity, " 份"); Change("火腿容量", ia.HamCapacity, ib.HamCapacity, " 份");
                Change("补料时间", ia.RefillSeconds, ib.RefillSeconds, " 秒"); break;
            case "fryer":
                c!.TryGetFryer(from, out var fa); c.TryGetFryer(to, out var fb);
                Change("每锅容量", fa.Capacity, fb.Capacity, " 根"); Flag("自动提篮", fa.AutoRaise, fb.AutoRaise);
                Change("炸至金黄", fa.GoldenStartSeconds, fb.GoldenStartSeconds, " 秒");
                Change("金黄可捞时间窗", fa.GoldenEndSeconds - fa.GoldenStartSeconds, fb.GoldenEndSeconds - fb.GoldenStartSeconds, " 秒");
                lines.Add(new("提篮方式", fa.AutoRaise ? $"{fa.AutoRaiseAtSeconds:0.##} 秒自动提篮" : "手动提篮", fb.AutoRaise ? $"{fb.AutoRaiseAtSeconds:0.##} 秒自动提篮" : "手动提篮"));
                lines.Add(new("焦糊风险", fa.AutoRaise ? "保持金黄，不再炸焦" : $"{fa.BurnAtSeconds:0.##} 秒开始焦糊", fb.AutoRaise ? "保持金黄，不再炸焦" : $"{fb.BurnAtSeconds:0.##} 秒开始焦糊"));
                Change("沥油时间", fa.DrainSeconds, fb.DrainSeconds, " 秒"); break;
            case "noodle_cooker":
                c!.TryGetNoodleCooker(from, out var na); c.TryGetNoodleCooker(to, out var nb);
                Change("面篮数量", na.BasketCount, nb.BasketCount, " 个"); Flag("锁定最佳熟度", na.AutoLockOptimal, nb.AutoLockOptimal);
                Flag("自动提篮", na.AutoRaise, nb.AutoRaise); Change("最佳煮面时间", na.OptimalSeconds, nb.OptimalSeconds, " 秒");
                Change("自然沥水时间", na.NaturalDrainSeconds, nb.NaturalDrainSeconds, " 秒");
                Change("快速沥水时间", na.QuickDrainSeconds, nb.QuickDrainSeconds, " 秒"); break;
            case "doupi_griddle":
                c!.TryGetDoupiGriddle(from, out var da); c.TryGetDoupiGriddle(to, out var db);
                lines.Add(new("火候保护", da.CanBurn ? "需留意火候" : "恒温保护，不会煎焦", db.CanBurn ? "需留意火候" : "恒温保护，不会煎焦"));
                Change("第一阶段煎制时间", da.StageSeconds / da.SpeedMultiplier, db.StageSeconds / db.SpeedMultiplier, " 秒");
                Change("第二阶段煎制时间", da.SecondStageReadySeconds / da.SpeedMultiplier, db.SecondStageReadySeconds / db.SpeedMultiplier, " 秒");
                Change("每锅产量", da.BatchYield, db.BatchYield, " 块");
                lines.Add(new("翻面与切块", da.AutoFlip ? "自动翻面，手动切块" : "手动翻面、切块", db.AutoFlip ? "自动翻面，手动切块" : "手动翻面、切块")); break;
            case YangzhouCatalog.BoardId:
                var ba = y!.Boards.Single(v => v.Level == from); var bb = y.Boards.Single(v => v.Level == to);
                Change("每次产量", ba.Yield, bb.Yield, " 份"); Change("库存容量", ba.Capacity, bb.Capacity, " 份");
                Change("制作时间", ba.Seconds, bb.Seconds, " 秒"); Change("辅助完成", ba.Snap * 100, bb.Snap * 100, "%"); break;
            case YangzhouCatalog.SteamerId:
                var ta = y!.Steamers.Single(v => v.Level == from); var tb = y.Steamers.Single(v => v.Level == to);
                Change("每层容量", ta.Capacity, tb.Capacity, " 格"); Change("蒸笼层数", ta.Layers, tb.Layers, " 层");
                Flag("保温", ta.Hold, tb.Hold); Change("包子蒸制时间", ta.BunSeconds, tb.BunSeconds, " 秒");
                Change("烧麦蒸制时间", ta.SiumaiSeconds, tb.SiumaiSeconds, " 秒"); break;
            default:
                if (c!.XianEquipment.ContainsKey($"{o.EquipmentId}_lv{to}"))
                {
                    var a = c.GetXianEquipment(o.EquipmentId, from); var b = c.GetXianEquipment(o.EquipmentId, to);
                    if (o.EquipmentId == "xian_board") {
                        Change("预剁库存", a.StockCapacity, b.StockCapacity, " 份");
                        Change("原料容量", a.IngredientCapacity, b.IngredientCapacity, " 份");
                        Change("剁肉操作量", a.WorkMultiplier * 100, b.WorkMultiplier * 100, "%");
                    } else {
                        Change("制作容量", a.Capacity, b.Capacity, o.EquipmentId == "xian_oven" ? " 个" : " 份");
                        Change("制作时间", a.ActionSeconds, b.ActionSeconds, " 秒");
                        if (o.EquipmentId == "xian_oven") {
                            Change("成品库存", a.StockCapacity, b.StockCapacity, " 个");
                            Flag("防焦保护", a.BurnProof, b.BurnProof); Flag("自动翻面与收取", a.Automatic, b.Automatic);
                        } else Change("补锅时间", a.RefillSeconds, b.RefillSeconds, " 秒");
                    }
                }
                else
                {
                    var a = c.GetGuangzhouEquipment(o.EquipmentId, from); var b = c.GetGuangzhouEquipment(o.EquipmentId, to);
                    if (o.EquipmentId == "guangzhou_station") {
                        Change("米浆容量", a.BatterCapacity, b.BatterCapacity, " 份"); Change("鸡蛋容量", a.EggCapacity, b.EggCapacity, " 份");
                        Change("猪肉容量", a.PorkCapacity, b.PorkCapacity, " 份"); Change("虾仁容量", a.ShrimpCapacity, b.ShrimpCapacity, " 份"); Change("酱汁容量", a.SauceCapacity, b.SauceCapacity, " 份");
                    } else {
                        Change("制作容量", a.Capacity, b.Capacity, o.EquipmentId == "guangzhou_stove" ? " 屉" : " 层");
                        Change(o.EquipmentId == "guangzhou_stove" ? "肠粉蒸制时间" : "烧卖蒸制时间", a.CookSeconds, b.CookSeconds, " 秒");
                        if (o.EquipmentId == "guangzhou_cabinet") Change("虾饺蒸制时间", a.HarGowCookSeconds, b.HarGowCookSeconds, " 秒");
                        Change("最佳出餐时间窗", a.BestWindowSeconds, b.BestWindowSeconds, " 秒"); Change("普通出餐时间窗", a.NormalWindowSeconds, b.NormalWindowSeconds, " 秒");
                        Flag("保温保护", a.KeepWarm, b.KeepWarm);
                        if (o.EquipmentId == "guangzhou_stove") Flag("自动弹出", a.PopOut, b.PopOut);
                    }
                }
                break;
        }
        return lines;
    }
}
