using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class CityPagesSelfTest
{
    private async Task CheckUpgradeFeedback()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var model = new CityPageModel(catalog, _save, YangzhouCatalog.Load());
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        foreach (var (city, equipment) in new[] { (StableIds.Cities.Tianjin, "pancake_stove"), (StableIds.Cities.Wuhan, "noodle_cooker") })
        {
            if (!_save.Data.UnlockedCityIds.Contains(city)) _save.Data.UnlockedCityIds.Add(city);
            var progress = _save.Data.GetCity(city);
            progress.HighestUnlockedDay = 12;
            progress.UnlockedContentIds = catalog.GetDays(city).Values.SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
            for (int day = 1; day <= 12; day++) progress.DayBestRecords[day] = new();
            foreach (bool reduced in new[] { false, true })
            {
                settings.SetReduceMotion(reduced);
                progress.EquipmentLevels[equipment] = 1;
                _save.Data.Coins = 10000;
                _screen.PresentCity(city); _screen.PresentUpgrades(); Click("Select_" + equipment);
                await ToSignal(GetTree().CreateTimer(.7), SceneTreeTimer.SignalName.Timeout);
                for (int target = 2; target <= 3; target++)
                {
                    var previous = model.Equipment(city).Single(e => e.Id == equipment);
                    Click("UpgradeEquipment"); await Frames();
                    Check(progress.EquipmentLevels[equipment] == target, "purchase reaches requested level");
                    Check(Find<Label>("LevelTransition").Text == $"已升至 Lv{target} · 下次营业生效", "feedback reports purchased level");
                    Check(Find<Label>("Status").Text.Length == 0, "no global success status");
                    Check(Find<Label>("UpgradeBenefit").Text == previous.Presentation!.Headline, "success headline describes purchased benefit rather than next level");
                    var level = Find<Label>("LevelTransition");
                    Check(level.GetThemeFont("font").GetStringSize(level.Text, HorizontalAlignment.Left, -1, level.GetThemeFontSize("font_size")).X <= level.Size.X, "success caption fits beside stamp");
                    Check(!Find<Control>("UpgradeSuccessPaper").GetGlobalRect().Intersects(Find<Control>("CurrentEquipment").GetGlobalRect()), "success stamp does not cover illustration");
                    var current = model.Equipment(city).Single(e => e.Id == equipment);
                    for (int i = 0; i < current.Effects.Count; i++)
                    {
                        var old = previous.Effects.FirstOrDefault(e => e.Name == current.Effects[i].Name);
                        if (old is null || old.Current == current.Effects[i].Current) continue;
                        var row = Find<Control>("ParameterRow" + i);
                        Check(row.Descendants<Label>().Single(l => l.Name == "CurrentValue").GetThemeColor("font_color") == new Color("#276631"), "purchased current value highlighted");
                    }
                    await Capture($"feedback-{equipment}-lv{target}-{(reduced ? "reduced" : "motion")}");
                    await ToSignal(GetTree().CreateTimer(2.5), SceneTreeTimer.SignalName.Timeout);
                    Check(!_screen.Descendants<Control>().Any(n => n.Name == "UpgradeSuccessPaper"), "success feedback clears including reduced motion");
                    Check(Find<Label>("LevelTransition").Text.Contains(target == 3 ? "已满级" : "Lv3"), "normal comparison restored");
                }
                if (!reduced) await Capture($"feedback-{equipment}-settled");
            }
        }
    }

    private async Task CaptureFryerPreview()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var progress = _save.Data.GetCity(StableIds.Cities.Tianjin);
        progress.HighestUnlockedDay = 12;
        progress.UnlockedContentIds = catalog.GetDays(StableIds.Cities.Tianjin).Values
            .SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
        for (int day = 1; day <= 12; day++) progress.DayBestRecords[day] = new();
        _save.Data.Coins = 10000;
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        for (int level = 1; level <= 3; level++)
        {
            progress.EquipmentLevels["fryer"] = level;
            settings.SetReduceMotion(true);
            _screen.PresentCity(StableIds.Cities.Tianjin); _screen.PresentUpgrades();
            Click("Select_fryer"); await Frames();
            await Capture($"fryer-lv{level}-settled");
            if (level == 3) continue;
            settings.SetReduceMotion(false); Click("NextEquipment");
            await ToSignal(GetTree().CreateTimer(.9), SceneTreeTimer.SignalName.Timeout);
            await Capture($"fryer-lv{level}-lowered");
            await ToSignal(GetTree().CreateTimer(1.6), SceneTreeTimer.SignalName.Timeout);
            await Capture($"fryer-lv{level}-finished");
        }
    }

    private async Task CheckUpgradeExperience()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var model = new CityPageModel(catalog, _save, YangzhouCatalog.Load());
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            if (!_save.Data.UnlockedCityIds.Contains(city)) _save.Data.UnlockedCityIds.Add(city);
            var progress = _save.Data.GetCity(city); progress.HighestUnlockedDay = 12;
            progress.UnlockedContentIds = catalog.GetDays(city).Values.SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
            for (int day = 1; day <= 12; day++) progress.DayBestRecords[day] = new();
            foreach (string id in progress.EquipmentLevels.Keys.ToArray()) progress.EquipmentLevels[id] = 2;
            _save.Data.Coins = 10000; Check(_save.TrySave(out _), "fixture saved");
            _screen.PresentCity(city); _screen.PresentUpgrades(); await Frames();
            foreach (var item in model.Equipment(city))
            {
                Click("Select_" + item.Id); await Frames();
                Check(!_screen.Descendants<ScrollContainer>().Any(v => v.Name == "UpgradeScroll"), "comparison has no main scroll");
                Check(_screen.Descendants<Label>().Any(v => v.Name == "UpgradeBenefit" && v.Text == item.Presentation!.Headline), "real benefit headline");
                Check(_screen.Descendants<Button>().Any(v => v.Name == "CurrentEquipment"), "current preview is clickable");
                if (item.TargetLevel.HasValue) Check(_screen.Descendants<Button>().Any(v => v.Name == "NextEquipment"), "next preview is clickable");
                Check(Find<Button>("CurrentEquipment").TooltipText.Length == 0 && Find<Button>("CurrentEquipment").GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is not null,
                    "equipment frame uses standard scale feedback without a hover prompt");
                Check(!_screen.Descendants<Button>().Any(v => v.Name == "ReplayUpgradePreview"), "comparison replays from equipment frames");
                var parameters = Find<ScrollContainer>("UpgradeParameterScroll");
                var rows = parameters.GetNode<VBoxContainer>("ParameterRows");
                Check(rows.GetChildCount() == item.Effects.Count, "all real effects shown inline");
                Check(!_screen.Descendants<Control>().Any(v => v.Name == "UpgradeParameters" || v.Name == "UpgradeParameterModal"), "no extra parameters entry or modal");
                for (int i = 0; i < item.Effects.Count; i++)
                {
                    var labels = rows.GetChild(i).Descendants<Label>().ToArray();
                    var effect = item.Effects[i];
                    Check(labels[0].Text == effect.Name && labels[1].Text == effect.Current && labels[2].Text == (item.TargetLevel.HasValue ? effect.Next : ""), "inline values match equipment data");
                    Check(labels.All(v => v.GetMinimumSize().Y <= v.Size.Y + 1), "parameter row fits wrapped text");
                    if (item.TargetLevel.HasValue && effect.Changed)
                        Check(labels[2].GetThemeColor("font_color") == new Color("#276631"), "changed value highlighted");
                }
                GetNode<JourneySettings>("/root/JourneySettings").SetReduceMotion(true);
                if (item.TargetLevel.HasValue)
                {
                    Click("CurrentEquipment");
                    Click("NextEquipment");
                }
                await Capture(city.Replace(':', '-') + "-" + item.Id + "-comparison");
                if (rows.Size.Y > parameters.Size.Y)
                {
                    var priceRect = Find<Control>("UpgradePriceFrame").GetGlobalRect();
                    var buyRect = Find<Button>("UpgradeEquipment").GetGlobalRect();
                    parameters.GrabFocus();
                    parameters.EmitSignal(Control.SignalName.GuiInput, new InputEventKey { Pressed = true, Keycode = Key.End });
                    await Frames();
                    Check(parameters.ScrollVertical > 0, "long parameters keyboard scroll");
                    Check(Find<Control>("UpgradePriceFrame").GetGlobalRect() == priceRect && Find<Button>("UpgradeEquipment").GetGlobalRect() == buyRect, "scroll keeps price and purchase fixed");
                    var last = rows.GetChild<Control>(rows.GetChildCount() - 1);
                    Check(last.GetGlobalRect().End.Y <= parameters.GetGlobalRect().End.Y + 1, "last parameter reachable");
                    await Capture(city.Replace(':', '-') + "-" + item.Id + "-parameters-bottom");
                }
                GetNode<JourneySettings>("/root/JourneySettings").SetReduceMotion(false);
            }
            if (city != StableIds.Cities.Wuhan) continue;
            progress.DayBestRecords.Remove(7); progress.UnlockedContentIds.Remove("equipment:noodle_cooker_lv3");
            _save.Data.Coins = 496; _screen.PresentUpgrades(); Click("Select_noodle_cooker"); await Frames();
            var locked = model.Equipment(city).Single(e => e.Id == "noodle_cooker");
            Check(locked.Presentation is { DayUnlocked: false, CoinsMissing: 24 }, "day lock and funds are independent");
            Check(Find<Label>("UpgradeNotice").Text.Contains("7") && Find<Label>("UpgradeNotice").Text.Contains("24"), "both conditions visible");
            Check(locked.Effects.Any(v => v.Name == "自动提篮" && v.Current == "关闭" && v.Next == "开启"), "real automation change");
            await Capture("upgrade-locked-and-short");
            progress.DayBestRecords[7] = new(); progress.UnlockedContentIds.Add("equipment:noodle_cooker_lv3");
            _screen.PresentUpgrades(); await Frames();
            Check(Find<Button>("UpgradeEquipment").Text == "还差 24 金币", "only funds missing");
            await Capture("upgrade-short");
            _save.Data.Coins = 520; _screen.PresentUpgrades(); await Frames();
            Check(!Find<Button>("UpgradeEquipment").Disabled, "exact funds allow purchase");
            Click("UpgradeEquipment"); await Frames();
            Check(_save.Data.Coins == 0 && _save.Data.Wuhan.EquipmentLevels["noodle_cooker"] == 3, "purchase debits once and upgrades");
            Check(_screen.Descendants<Label>().Any(v => v.Name == "UpgradeSuccessStamp"), "success feedback");
            await Capture("upgrade-purchased");
            Check(Find<Button>("UpgradeEquipment").Disabled, "max level disables purchase");
            progress.EquipmentLevels["doupi_griddle"] = 0; _screen.PresentUpgrades(); Click("Select_doupi_griddle"); await Frames();
            Check(Find<Button>("UpgradeEquipment").Disabled && Find<Label>("LevelTransition").Text == "设备尚未开放", "unopened device");
            await Capture("upgrade-unopened");
        }
    }
}
