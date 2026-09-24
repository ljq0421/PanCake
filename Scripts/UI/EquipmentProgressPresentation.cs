using ProjectCake.Pancake;
using ProjectCake.Fryer;
using ProjectCake.Wuhan;
using ProjectCake.Xian;
using ProjectCake.Data;

namespace ProjectCake.UI;

internal static class EquipmentProgressPresentation
{
    internal static EquipmentProgressState Pancake(PancakeStateMachine? machine)
    {
        if (machine is null) return default;
        var r = machine.Runtime; var d = machine.Stove;
        bool first = r.State is PancakeState.SideACooking or PancakeState.SideAReady or PancakeState.SideAOverdone;
        if (r.State == PancakeState.Burnt)
            return EquipmentProgressState.Done("已焦糊 · 请丢弃", failed: true) with { HeatPosition = .95 };
        if (d.CanBurn && r.State is (PancakeState.SideACooking or PancakeState.SideBCooking
            or PancakeState.SideAReady or PancakeState.SideAOverdone or PancakeState.SideBReady))
        {
            double readyAt = first ? d.SideAReadySeconds : d.SideBReadySeconds;
            double burnAt = first ? d.SideABurnSeconds : d.SideBBurnSeconds;
            bool ready = r.State is not (PancakeState.SideACooking or PancakeState.SideBCooking);
            double remaining = Math.Max(0, burnAt - r.CookingSeconds);
            string action = first ? "请翻面" : "请刷酱";
            string caption = !ready ? first ? "正面煎制中" : "反面煎制中"
                : remaining <= 1.0001 ? $"快焦了 · {action}" : first ? "可翻面" : "可刷酱";
            double position = ready ? .3 + .6 * EquipmentProgressState.Heat(r.CookingSeconds, readyAt, burnAt)
                : .3 * Math.Clamp(r.CookingSeconds / readyAt, 0, 1);
            return new(true, Math.Clamp(r.CookingSeconds / readyAt, 0, 1), caption, ready,
                HeatPosition: Math.Min(position, .8999));
        }
        if (r.State is PancakeState.SideACooking or PancakeState.SideBCooking)
            return EquipmentProgressState.Working(r.CookingSeconds, first ? d.SideAReadySeconds : d.SideBReadySeconds, first ? "正面煎制中" : "反面煎制中");
        if (r.State is PancakeState.SideAReady or PancakeState.SideAOverdone or PancakeState.SideBReady)
            return EquipmentProgressState.Done(r.State == PancakeState.SideAOverdone ? "偏焦 · 请翻面" : first ? "可翻面" : "可刷酱",
                d.CanBurn ? EquipmentProgressState.Heat(r.CookingSeconds, first ? d.SideAOverdoneSeconds : d.SideBReadySeconds,
                    first ? d.SideABurnSeconds : d.SideBBurnSeconds) : 0);
        return r.State is PancakeState.Saucing or PancakeState.Sauced or PancakeState.Toppings or PancakeState.Folded
            ? EquipmentProgressState.Done("已煎好") : default;
    }

    internal static EquipmentProgressState Fryer(FryerStateMachine? machine)
    {
        if (machine is null) return default;
        var r = machine.Runtime; var d = machine.Level;
        return r.State switch
        {
            FryerState.Frying when r.Quality == YoutiaoQuality.Light => EquipmentProgressState.Working(r.FrySeconds, d.GoldenStartSeconds, "油炸中"),
            FryerState.Frying => EquipmentProgressState.Done(r.Quality == YoutiaoQuality.Deep ? "偏焦 · 请起锅" : "可起锅",
                d.AutoRaise ? 0 : EquipmentProgressState.Heat(r.FrySeconds, d.GoldenEndSeconds, d.BurnAtSeconds)),
            FryerState.Raised => EquipmentProgressState.Done("等待成品盘"),
            FryerState.Draining => EquipmentProgressState.Working(r.DrainSeconds, d.DrainSeconds, "沥油中"),
            FryerState.Burnt => EquipmentProgressState.Done("已焦糊", failed: true),
            _ => default,
        };
    }

    internal static EquipmentProgressState Noodles(NoodleCookerStateMachine? machine, int index)
    {
        if (machine is null || index >= machine.Baskets.Count) return default;
        var r = machine.Baskets[index]; var d = machine.Level;
        return r.State switch
        {
            NoodleBasketState.Empty => default,
            NoodleBasketState.Cooking => EquipmentProgressState.Working(r.CookSeconds, d.OptimalSeconds, "煮面中"),
            NoodleBasketState.Raised or NoodleBasketState.Draining => EquipmentProgressState.Working(r.DrainSeconds, d.NaturalDrainSeconds, "沥水中"),
            NoodleBasketState.Drained => EquipmentProgressState.Done(r.Quality == NoodleQuality.Overcooked ? "已煮烂" : r.Quality == NoodleQuality.Soft ? "偏软 · 可倒面" : "可倒面",
                r.Quality == NoodleQuality.Soft ? .5 : 0, r.Quality == NoodleQuality.Overcooked),
            NoodleBasketState.Overcooked => EquipmentProgressState.Done("已煮烂", failed: true),
            _ => EquipmentProgressState.Done(r.State == NoodleBasketState.Soft ? "偏软 · 请捞起" : "可捞起",
                d.AutoLockOptimal ? 0 : EquipmentProgressState.Heat(r.CookSeconds, d.SoftUntilSeconds, d.OvercookedSeconds)),
        };
    }

    internal static EquipmentProgressState Doupi(DoupiStateMachine? machine)
    {
        if (machine is null) return default;
        return machine.State switch
        {
            DoupiState.Batter => new(true, machine.SkinCookProgress, "正在煎制，请加蛋液", Risk: machine.HeatStress),
            DoupiState.SkinCooking => new(true, machine.SkinCookProgress, "饼皮煎制中", Risk: machine.HeatStress),
            DoupiState.ReadyToFlip => EquipmentProgressState.Done("可翻面", machine.HeatStress),
            DoupiState.Flipped => new(true, machine.BrowningProgress, "正在煎制，请加三鲜馅", Risk: machine.HeatStress),
            DoupiState.SecondCooking => new(true, machine.BrowningProgress, "二次煎制中", Risk: machine.HeatStress),
            DoupiState.ReadyToCut or DoupiState.Overbrowned => EquipmentProgressState.Done(machine.State == DoupiState.Overbrowned ? "偏焦 · 请切块" : "可切块", machine.HeatStress),
            DoupiState.Cutting => EquipmentProgressState.Done("已收火 · 切块中"),
            DoupiState.Cut => EquipmentProgressState.Done("等待成品盘"),
            DoupiState.Burnt => EquipmentProgressState.Done("已焦糊", failed: true),
            _ => default,
        };
    }

    internal static EquipmentProgressState Oven(BunOvenStateMachine? oven, XianEquipmentData data)
    {
        if (oven is null || oven.State == BunOvenState.Empty) return default;
        if (oven.State == BunOvenState.Burnt) return EquipmentProgressState.Done("已焦糊", failed: true);
        if (oven.SideSeconds < data.ActionSeconds)
            return EquipmentProgressState.Working(oven.SideSeconds, data.ActionSeconds, oven.State == BunOvenState.FirstSide ? "正面烙制中" : "反面烙制中");
        string caption = oven.State == BunOvenState.FirstSide ? "可翻面" : data.Automatic ? "等待馍篮" : "可收取";
        return EquipmentProgressState.Done(oven.Quality == BunQuality.Overbrowned ? "偏焦 · " + caption : caption, oven.HeatStress);
    }

    internal static EquipmentProgressState Soup(HulatangRuntime? soup, XianEquipmentData data) => soup is null ? default
        : soup.HasBowl ? EquipmentProgressState.Done("可端汤") : soup.RemainingSeconds > 0
        ? EquipmentProgressState.Working(data.ActionSeconds - soup.RemainingSeconds, data.ActionSeconds, "盛汤中") : default;
}
