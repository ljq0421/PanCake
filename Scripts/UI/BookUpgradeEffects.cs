using ProjectCake.Core;
using ProjectCake.Yangzhou;

namespace ProjectCake.UI;

internal static class BookUpgradeEffects
{
    internal static string Describe(BookUpgradeOffer o, DataCatalog? c, YangzhouCatalog? y)
    {
        var lines = new List<string>();
        void Change(string name, double a, double b, string unit = "")
        { if (Math.Abs(a - b) > .00001) lines.Add($"{name}：{a:0.##}{unit} → {b:0.##}{unit}"); }
        void Flag(string name, bool a, bool b) { if (a != b) lines.Add(name + (b ? "：开启" : "：关闭")); }
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
                Flag("面糊无限供应", ia.UnlimitedBatter, ib.UnlimitedBatter); Flag("酱料无限供应", ia.UnlimitedSauce, ib.UnlimitedSauce);
                if (!ib.UnlimitedBatter) Change("面糊容量", ia.BatterCapacity, ib.BatterCapacity);
                if (!ib.UnlimitedSauce) Change("酱料容量", ia.SauceCapacity, ib.SauceCapacity);
                Change("鸡蛋容量", ia.EggCapacity, ib.EggCapacity); Change("薄脆容量", ia.CrispyCapacity, ib.CrispyCapacity);
                Change("葱花容量", ia.ScallionCapacity, ib.ScallionCapacity); Change("火腿容量", ia.HamCapacity, ib.HamCapacity);
                Change("补料时间", ia.RefillSeconds, ib.RefillSeconds, " 秒"); break;
            case "fryer":
                c!.TryGetFryer(from, out var fa); c.TryGetFryer(to, out var fb);
                Change("每锅容量", fa.Capacity, fb.Capacity, " 根"); Flag("自动提篮", fa.AutoRaise, fb.AutoRaise);
                Change("炸至金黄", fa.GoldenStartSeconds, fb.GoldenStartSeconds, " 秒");
                Change("金黄可捞时间窗", fa.GoldenEndSeconds - fa.GoldenStartSeconds, fb.GoldenEndSeconds - fb.GoldenStartSeconds, " 秒");
                if (fb.AutoRaise) lines.Add($"炸至 {fb.AutoRaiseAtSeconds:0.##} 秒自动提篮，保持金黄、不再炸焦。");
                else Change("开始焦糊时间", fa.BurnAtSeconds, fb.BurnAtSeconds, " 秒");
                Change("沥油时间", fa.DrainSeconds, fb.DrainSeconds, " 秒"); break;
            case "noodle_cooker":
                c!.TryGetNoodleCooker(from, out var na); c.TryGetNoodleCooker(to, out var nb);
                Change("面篮数量", na.BasketCount, nb.BasketCount, " 个"); Flag("锁定最佳熟度", na.AutoLockOptimal, nb.AutoLockOptimal);
                Flag("自动提篮", na.AutoRaise, nb.AutoRaise); Change("最佳煮面时间", na.OptimalSeconds, nb.OptimalSeconds, " 秒");
                Change("自然沥水时间", na.NaturalDrainSeconds, nb.NaturalDrainSeconds, " 秒");
                Change("快速沥水时间", na.QuickDrainSeconds, nb.QuickDrainSeconds, " 秒"); break;
            case "doupi_griddle":
                c!.TryGetDoupiGriddle(from, out var da); c.TryGetDoupiGriddle(to, out var db);
                if (da.CanBurn && !db.CanBurn) lines.Add("获得恒温保护，豆皮不会煎焦。");
                Change("第一阶段煎制时间", da.StageSeconds / da.SpeedMultiplier, db.StageSeconds / db.SpeedMultiplier, " 秒");
                Change("第二阶段煎制时间", da.SecondStageReadySeconds / da.SpeedMultiplier, db.SecondStageReadySeconds / db.SpeedMultiplier, " 秒");
                lines.Add($"每锅 {db.BatchYield} 块；" + (db.AutoFlip ? "第一阶段自动翻面，仍需手动切块。" : "仍需手动翻面。")); break;
            case YangzhouCatalog.BoardId:
                var ba = y!.Boards.Single(v => v.Level == from); var bb = y.Boards.Single(v => v.Level == to);
                Change("每次产量", ba.Yield, bb.Yield, " 份"); Change("库存容量", ba.Capacity, bb.Capacity, " 份");
                Change("制作时间", ba.Seconds, bb.Seconds, " 秒"); break;
            case YangzhouCatalog.SteamerId:
                var ta = y!.Steamers.Single(v => v.Level == from); var tb = y.Steamers.Single(v => v.Level == to);
                Change("容量", ta.Capacity, tb.Capacity); Change("蒸笼层数", ta.Layers, tb.Layers);
                Flag("保温", ta.Hold, tb.Hold); Change("包子蒸制时间", ta.BunSeconds, tb.BunSeconds, " 秒");
                Change("烧麦蒸制时间", ta.SiumaiSeconds, tb.SiumaiSeconds, " 秒"); break;
            default:
                if (c!.XianEquipment.ContainsKey($"{o.EquipmentId}_lv{to}"))
                {
                    var a = c.GetXianEquipment(o.EquipmentId, from); var b = c.GetXianEquipment(o.EquipmentId, to);
                    Change("制作容量", a.Capacity, b.Capacity); Change("成品库存容量", a.StockCapacity, b.StockCapacity);
                    Change("原料容量", a.IngredientCapacity, b.IngredientCapacity); Change("制作时间", a.ActionSeconds, b.ActionSeconds, " 秒");
                    Change("补料时间", a.RefillSeconds, b.RefillSeconds, " 秒"); Change("剁肉操作量", a.WorkMultiplier * 100, b.WorkMultiplier * 100, "%");
                    Flag("防焦保护", a.BurnProof, b.BurnProof); Flag("自动翻面与收取", a.Automatic, b.Automatic);
                }
                else
                {
                    var a = c.GetGuangzhouEquipment(o.EquipmentId, from); var b = c.GetGuangzhouEquipment(o.EquipmentId, to);
                    Change("制作容量", a.Capacity, b.Capacity); Change("制作时间", a.CookSeconds, b.CookSeconds, " 秒");
                    Change("虾饺蒸制时间", a.HarGowCookSeconds, b.HarGowCookSeconds, " 秒");
                    Change("最佳出餐时间窗", a.BestWindowSeconds, b.BestWindowSeconds, " 秒"); Change("普通出餐时间窗", a.NormalWindowSeconds, b.NormalWindowSeconds, " 秒");
                    Flag("保温保护", a.KeepWarm, b.KeepWarm); Flag("自动弹出", a.PopOut, b.PopOut);
                    Change("米浆容量", a.BatterCapacity, b.BatterCapacity); Change("鸡蛋容量", a.EggCapacity, b.EggCapacity);
                    Change("猪肉容量", a.PorkCapacity, b.PorkCapacity); Change("虾仁容量", a.ShrimpCapacity, b.ShrimpCapacity); Change("酱汁容量", a.SauceCapacity, b.SauceCapacity);
                }
                break;
        }
        return string.Join("\n", lines);
    }
}
