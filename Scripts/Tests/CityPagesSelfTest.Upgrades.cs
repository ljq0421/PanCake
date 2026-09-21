using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;
using ProjectCake.Xian;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class CityPagesSelfTest
{
    private async Task CheckSharedUpgradePage()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var model = new CityPageModel(catalog, _save, YangzhouCatalog.Load());
        foreach (var city in JourneyModel.Cities)
        {
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            var progress = _save.Data.GetCity(city.Id);
            progress.HighestUnlockedDay = city.Days;
            for (int day = 1; day <= city.Days; day++) progress.DayBestRecords[day] = new();
            foreach (string id in progress.EquipmentLevels.Keys.ToArray()) progress.EquipmentLevels[id] = 2;
            if (city.Id != YangzhouCatalog.CityId)
                progress.UnlockedContentIds = catalog.GetDays(city.Id).Values.SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
            _save.Data.Coins = 10000; Check(_save.TrySave(out _), city.Name + " fixture saved");
            Check(_main.OpenCity(city.Id), city.Name + " home city opens");
            // The home overlay intentionally keeps the home book palette. Exercise the city book here.
            _screen.PresentCity(city.Id);
            Click("UpgradeTab"); await Frames();
            Check(_screen.Page == JourneyPage.Upgrades && _screen.SelectedCityId == city.Id, city.Name + " home upgrade route");
            CheckBookTheme(city.Id);
            Check(Find<Button>("Home").IsVisibleInTree() && !_screen.Descendants<Button>().Any(b => b.Name == "MapTab"), city.Name + " upgrade page retains home without map bookmark");
            Check(!_screen.Descendants<Button>().Any(b => b.Name == "CloseUpgrades"), city.Name + " home has no settlement return");
            var offer = model.Equipment(city.Id).First(e => e.CanBuy);
            if (city.Id == StableIds.Cities.Wuhan)
            {
                var equipment = model.Equipment(city.Id);
                Check(equipment.Single(e => e.Id == "noodle_cooker").Presentation is { Highlights.Count: > 0 }
                    && equipment.Single(e => e.Id == "doupi_griddle").Presentation is not null
                    && equipment.Single(e => e.Id == "ingredient_station").Presentation?.Fixed == true,
                    "Wuhan upgrades have structured functional comparisons and a fixed station");
            }
            else if (city.Id == StableIds.Cities.Xian)
            {
                var equipment = model.Equipment(city.Id);
                Check(equipment.Single(e => e.Id == XianRules.Oven).Art?.EndsWith("白吉馍炉 Lv1 基础版.png") == true
                    && equipment.Single(e => e.Id == XianRules.Soup).Art?.EndsWith("肉丸胡辣汤锅 Lv1.png") == true,
                    "Xi'an upgrades retain original equipment art");
            }
            Click("Select_" + offer.Id);
            Check(_save.Data.Coins == 10000, city.Name + " selection does not purchase");
            var upgrade = _screen.Descendants<EquipmentUpgradeView>().Single();
            Check(upgrade.Position == new Vector2(320, 230), city.Name + " shared interior placement");
            if (city.Id == StableIds.Cities.Wuhan)
            {
                Check(upgrade.FindChildren("Backing", "NinePatchRect", true, false).OfType<NinePatchRect>().Any(IsWuhanPalette), "Wuhan equipment backgrounds use city palette");
                Check(upgrade.FindChildren("UpgradeButtonArt", "NinePatchRect", true, false).OfType<NinePatchRect>().Single() is { } purchaseArt
                    && IsWuhanPalette(purchaseArt), "Wuhan upgrade button uses city palette");
            }
            using (var locked = new FileStream(_path + ".tmp", FileMode.Create, System.IO.FileAccess.Write, FileShare.None))
            {
                Click("UpgradeEquipment"); await Frames();
                Check(_save.Data.Coins == 10000 && Find<Label>("Status").Text.Contains("保存失败"), city.Name + " failed save preserves balance and reports error");
            }
            Check(!Find<Button>("UpgradeEquipment").Disabled, city.Name + " failed purchase allows retry");
            Click("UpgradeEquipment"); await Frames();
            Check(_save.Data.Coins == 10000 - offer.Price && _save.Data.GetCity(city.Id).EquipmentLevels[offer.Id] == offer.Level + 1, city.Name + " home purchase uses correct city and price");
            Check(_screen.Descendants<EquipmentUpgradeView>().Single().SelectedId == offer.Id, city.Name + " home retains purchased selection");
            Check(_screen.Descendants<Label>().Any(l => l.Name == "Coins" && l.Text == _save.Data.Coins.ToString()), city.Name + " home refreshes wallet");
            await Capture(city.Name + "-shared-upgrade-home");
            Click("LedgerTab"); await Frames();
            Check(_screen.Page == JourneyPage.Ledger && !_screen.Descendants<Button>().Any(b => b.Name == "MapTab"), city.Name + " ledger has no map bookmark");
            await Capture(city.Name + "-ledger-no-map");
            Click("UpgradeTab"); await Frames();
            Check(_screen.Page == JourneyPage.Upgrades && _screen.SelectedCityId == city.Id, city.Name + " bookmarks retain city navigation");
        }
    }
}
