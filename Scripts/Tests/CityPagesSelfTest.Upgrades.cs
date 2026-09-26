using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;
using ProjectCake.Xian;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class CityPagesSelfTest
{
    private async Task CheckUpgradeGrid()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            if (!_save.Data.UnlockedCityIds.Contains(city)) _save.Data.UnlockedCityIds.Add(city);
            var progress = _save.Data.GetCity(city);
            progress.HighestUnlockedDay = 1;
            progress.DayBestRecords.Clear(); progress.UnlockedContentIds.Clear();
            progress.EquipmentLevels.Clear();
            string primary = city == StableIds.Cities.Tianjin ? "pancake_stove" : "noodle_cooker";
            progress.EquipmentLevels[primary] = 1; progress.EquipmentLevels["ingredient_station"] = 1;
            _save.Data.Coins = 0;
            _screen.PresentCity(city); _screen.PresentUpgrades(); await Frames();
            var view = _screen.Descendants<EquipmentUpgradeView>().Single();
            Check(view.SelectedId == (city == StableIds.Cities.Tianjin ? "ingredient_station" : primary), "earliest unlock selected " + city);
            var cards = view.Buttons.Where(b => b.Name.ToString().StartsWith("Select_")).ToArray();
            Check(cards.Length == (city == StableIds.Cities.Tianjin ? 4 : 2), "only upgradeable devices visible " + city);
            if (city == StableIds.Cities.Tianjin)
                Check(cards[0].Position.Y == cards[1].Position.Y && cards[2].Position.X == cards[0].Position.X && cards[2].Position.Y > cards[0].Position.Y, "two-column grid " + city);
            else
                Check(cards.All(c => c.Position.X == cards[0].Position.X) && cards[0].Position.Y < cards[1].Position.Y, "single column with two rows " + city);
            Check(!Find<Control>("UpgradeWallet").GetGlobalRect().Intersects(Find<Control>("BookCloseArt").GetGlobalRect()), "wallet clears close artwork " + city);
            if (city == StableIds.Cities.Tianjin)
                Check(Find<Button>("Select_soy_milk_tray").GetNode<Label>("EquipmentName").Text == "豆浆", "soy milk label");
            await Capture(city.Replace(':', '-') + "-grid-locked");
            if (city == StableIds.Cities.Tianjin)
            {
                Click("Select_soy_milk_tray"); await Frames();
                Check(view.SelectedId == "soy_milk_tray", "soy milk detail opens");
                await Capture("tianjin-soy-milk-upgrade");
            }
            progress.HighestUnlockedDay = 12;
            for (int day = 1; day <= 12; day++) progress.DayBestRecords[day] = new();
            progress.UnlockedContentIds = catalog.GetDays(city).Values.SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
            _screen.PresentUpgrades(); await Frames();
            var model = new CityPageModel(catalog, _save, YangzhouCatalog.Load());
            var cheapest = model.Equipment(city).Where(e => e.TargetLevel.HasValue).OrderBy(e => e.Price).First();
            Check(_screen.Descendants<EquipmentUpgradeView>().Single().SelectedId == cheapest.Id, "smallest coin shortfall selected " + city);
            await Capture(city.Replace(':', '-') + "-grid-short");
            _save.Data.Coins = 10000;
            _screen.PresentUpgrades(); await Frames();
            var offer = model.Equipment(city).First(e => e.CanBuy);
            Check(_screen.Descendants<EquipmentUpgradeView>().Single().SelectedId == offer.Id, "purchasable takes priority " + city);
            Click("Select_" + cheapest.Id);
            Check(_save.Data.Coins == 10000, "selection does not purchase " + city);
            Click("UpgradeEquipment"); await Frames();
            Check(_save.Data.Coins == 10000 - cheapest.Price, "purchase uses selected device " + city);
            Check(_screen.Descendants<EquipmentUpgradeView>().Single().SelectedId == cheapest.Id, "purchase retains selection " + city);
            await Capture(city.Replace(':', '-') + "-grid-purchased");
            foreach (var item in model.Equipment(city)) progress.EquipmentLevels[item.Id] = item.Id == "soy_milk_tray" ? 1 : 3;
            _screen.PresentUpgrades(); await Frames();
            Check(Find<Button>("UpgradeEquipment").Disabled, "all complete has safe fallback " + city);
            await Capture(city.Replace(':', '-') + "-grid-complete");
        }
    }

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
            Check(Find<TextureRect>("SharedBook").GetGlobalRect().Encloses(Find<Control>("UpgradeWallet").GetGlobalRect()), city.Name + " wallet stays inside the book page");
            CheckBookTheme(city.Id);
            Check(Find<Button>("Home").IsVisibleInTree() && !_screen.Descendants<Button>().Any(b => b.Name == "MapTab"), city.Name + " upgrade page retains home without map bookmark");
            Check(!_screen.Descendants<Button>().Any(b => b.Name == "CloseUpgrades"), city.Name + " home has no settlement return");
            var offer = model.Equipment(city.Id).First(e => e.CanBuy);
            Check(_screen.Descendants<EquipmentUpgradeView>().Single().SelectedId == offer.Id,
                city.Name + " upgrade page defaults to the first currently purchasable device");
            if (city.Id == StableIds.Cities.Wuhan)
            {
                var equipment = model.Equipment(city.Id);
                Check(equipment.Single(e => e.Id == "noodle_cooker").Presentation is { Highlights.Count: > 0 }
                    && equipment.Single(e => e.Id == "doupi_griddle").Presentation is not null
                    && equipment.All(e => e.Id != "ingredient_station"),
                    "Wuhan upgrades show only the cooker and griddle");
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
        foreach (var city in JourneyModel.Cities)
        {
            // Repeat through the real homepage overlay, which must not block its own purchase.
            string overlayEquipment = city.Id == StableIds.Cities.Wuhan ? "doupi_griddle" : model.Equipment(city.Id).First().Id;
            var progress = _save.Data.GetCity(city.Id);
            progress.EquipmentLevels[overlayEquipment] = 1;
            _save.Data.Coins = 757;
            var overlayOffer = model.Equipment(city.Id).Single(e => e.Id == overlayEquipment);
            _screen.Present();
            _screen.PresentCity(city.Id, fromHome: true);
            Click("UpgradeTab"); Click("Select_" + overlayEquipment); await Frames();
            Check(_screen.ModalOpen && !Find<Button>("UpgradeEquipment").Disabled, city.Name + " home overlay upgrade available");
            Click("UpgradeEquipment"); await Frames();
            Check(_save.Data.Coins == 757 - overlayOffer.Price && progress.EquipmentLevels[overlayEquipment] == 2,
                city.Name + " home overlay purchases and refreshes level");
            Check(_screen.Descendants<Label>().Any(l => l.Name == "Coins" && l.Text == _save.Data.Coins.ToString()),
                city.Name + " home overlay refreshes wallet");
            _screen.Present();
        }
    }
}
