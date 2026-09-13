using Godot;
using ProjectCake.Core;
using ProjectCake.UI;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class BusinessBookSelfTest
{
    private async Task CheckBookUpgrades(DataCatalog catalog, YangzhouCatalog yc)
    {
        foreach (string city in new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" })
        {
            var save = new SaveService();
            string path = "res://.tmp/book-tests/upgrade-" + Guid.NewGuid() + ".json";
            save.UsePathForTests(path); AddChild(save);
            string cityId = "city:" + city;
            var progress = save.Data.GetCity(cityId);
            var source = city == "yangzhou" ? new BookUpgradeSource(save, yc) : new BookUpgradeSource(save, catalog, cityId);
            save.Data.Coins = 10000;
            Check(source.Offers.Count == 0, city + " locked offers hidden");
            if (city != "yangzhou")
            {
                progress.UnlockedContentIds = catalog.GetDays(cityId).Values.SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
                // Free equipment has already been introduced by the end of a chapter.
                foreach (string id in progress.EquipmentLevels.Keys.ToArray()) progress.EquipmentLevels[id] = 1;
            }
            else progress.EquipmentLevels[YangzhouCatalog.SteamerId] = 1;
            for (int day = 1; day <= SaveService.ChapterDays(cityId); day++) progress.DayBestRecords[day] = new DayBestRecord();
            Check(source.Offers.Count >= 2, city + " multiple next-level offers");
            var first = source.Offers[0];
            save.Data.Coins = first.Price - 1;
            Check(!source.Offers.Contains(first), city + " insufficient offer hidden");
            save.Data.Coins = 10000;
            foreach (var offer in source.Offers) Check(source.Effects(offer).Length > 0, city + " effects present");
            if (city == "wuhan")
            {
                var doupi = source.Offers.Single(o => o.EquipmentId == "doupi_griddle");
                Check(doupi.Price == 280 && source.Effects(doupi).Contains("不会煎焦") && source.Effects(doupi).Contains("每锅 8 块") && source.Effects(doupi).Contains("手动翻面"), "Wuhan Lv2 price and actual capabilities");
            }
            Check(save.TrySave(out _), city + " fixture saved");
            using (var locked = new FileStream(ProjectSettings.GlobalizePath(path) + ".tmp", FileMode.Create, System.IO.FileAccess.Write, FileShare.None))
                Check(!source.Purchase(first, out _) && source.Coins == 10000 && source.Offers.Contains(first), city + " failed save rolls back wallet and level");

            var model = Fixture(city); model.Closing = true; model.Upgrades = source;
            var view = new BusinessDetailsView(); AddChild(view); bool closed = false; view.CloseRequested += () => closed = true;
            model.Practice = true; view.Open(model);
            Check(!view.Descendants<Button>().Any(b => b.Name == "OpenBookUpgrades" || b.Name == "UpgradeSticker"), city + " affordable practice upgrades hidden");
            model.Practice = false; model.Closing = false; view.Open(model);
            Check(!view.Descendants<Button>().Any(b => b.Name == "OpenBookUpgrades" || b.Name == "UpgradeSticker"), city + " affordable live upgrades hidden");
            model.Closing = true;
            Button Entry() => view.Descendants<Button>().Single(b => b.Name == (city is "tianjin" or "wuhan" or "xian" ? "OpenBookUpgrades" : "UpgradeSticker"));
            foreach (var size in CaptureSizes.Take(2))
            {
                GetWindow().Size = size; await Frames(5); view.Open(model); view.FinishAnimation(); await Frames();
                Click(Entry()); await Frames();
                var modal = view.Descendants<Control>().Single(n => n.Name == "BookUpgradeModal");
                Check(modal.IsVisibleInTree(), city + " click opens modal");
                Check(view.Descendants<Label>().Any(l => l.Text == $"当前余额 ¥{source.Coins}"), city + " wallet shown");
                Click(view.CloseButton); Check(!closed, city + " modal blocks book close");
                for (int i = 0; i < 8; i++)
                {
                    GetViewport().PushInput(new InputEventKey { Keycode = Key.Tab, Pressed = true }, true);
                    Check(modal.IsAncestorOf(GetViewport().GuiGetFocusOwner()), city + " modal traps keyboard focus");
                }
                view.Descendants<ScrollContainer>().Single(n => n.Name == "UpgradeScroll").ScrollVertical = 0; await Frames();
                if (Capture) await Shot($"{city}-upgrades-{size.X}");
                GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
                Check(!closed && Entry().HasFocus(), city + " Escape restores upgrade focus");
            }
            int income = model.Result.TotalRevenue;
            Click(Entry()); await Frames();
            var buy = view.Descendants<Button>().Single(b => b.Name == "Buy_" + first.EquipmentId);
            var scroll = view.Descendants<ScrollContainer>().Single(n => n.Name == "UpgradeScroll"); scroll.EnsureControlVisible(buy); await Frames();
            Click(buy); await Frames();
            Check(source.Coins == 10000 - first.Price && model.Result.TotalRevenue == income, city + " UI purchase debits once without recommitting revenue");
            Check(!source.Purchase(first, out _) && source.Coins == 10000 - first.Price, city + " stale duplicate rejected");
            save.Load();
            Check(source.Coins == 10000 - first.Price && save.Data.GetCity(cityId).EquipmentLevels[first.EquipmentId] == first.TargetLevel, city + " purchase persists across reload");
            Check(view.Descendants<Label>().Any(l => l.Text == "升级成功，下次营业生效。"), city + " success feedback");
            int bought = 0;
            while (source.Offers.Count > 1 && bought++ < 20)
            {
                var offer = source.Offers[0];
                Check(source.Effects(offer).Length > 0, city + " every level has effects");
                Check(source.Purchase(offer, out _), city + " sequential purchase");
            }
            Check(source.Offers.Count == 1, city + " single remaining offer");
            var last = source.Offers.Single(); save.Data.Coins = last.Price;
            view.Open(model); view.FinishAnimation(); await Frames(); Entry().GrabFocus();
            foreach (bool pressed in new[] { true, false }) GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, Pressed = pressed }, true);
            await Frames();
            Check(view.Descendants<Control>().Any(n => n.Name == "BookUpgradeModal"), city + " Enter opens upgrades");
            var lastBuy = view.Descendants<Button>().Single(b => b.Name == "Buy_" + last.EquipmentId); lastBuy.GrabFocus(); await Frames();
            foreach (bool pressed in new[] { true, false }) GetViewport().PushInput(new InputEventKey { Keycode = Key.Space, Pressed = pressed }, true);
            await Frames();
            Check(source.Coins == 0 && view.Descendants<Label>().Any(l => l.Text == "暂无可购买升级"), city + " Space buys final offer with exact balance and empty state");
            Check(source.Offers.Count == 0 && bought < 20, city + " max levels hide offers");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            Check(view.CloseButton.HasFocus(), city + " empty list returns focus to book close");
            view.Open(model); view.FinishAnimation();
            Check(!view.Descendants<Button>().Any(b => b.Name == "OpenBookUpgrades" || b.Name == "UpgradeSticker"), city + " no affordable offer hides entry");
            foreach (bool practice in new[] { true, false })
            {
                model.Practice = practice; model.Closing = practice; view.Open(model);
                Check(!view.Descendants<Button>().Any(b => b.Name == "OpenBookUpgrades" || b.Name == "UpgradeSticker"), city + " practice or live no entry");
            }
            view.QueueFree(); save.QueueFree(); await Frames();
        }
    }
}
