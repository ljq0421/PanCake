using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class BusinessBookSelfTest
{
    private async Task CheckBookUpgrades(DataCatalog catalog, YangzhouCatalog yc)
    {
        GetWindow().ContentScaleAspect = Window.ContentScaleAspectEnum.Expand;
        foreach (string city in new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" })
        {
            var save = new SaveService();
            string path = "res://.tmp/book-tests/upgrade-" + Guid.NewGuid() + ".json";
            save.UsePathForTests(path); AddChild(save);
            string cityId = "city:" + city;
            if (!save.Data.UnlockedCityIds.Contains(cityId)) save.Data.UnlockedCityIds.Add(cityId);
            var progress = save.Data.GetCity(cityId);
            var source = city == "yangzhou" ? new BookUpgradeSource(save, yc) : new BookUpgradeSource(save, catalog, cityId);
            save.Data.Coins = 10000;
            Check(source.Offers.Count == 0, city + " locked offers hidden");
            Check(!source.NeedsUpgradeTeaching, city + " locked upgrades do not teach");
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
            save.Data.Coins = 0;
            Check(!source.NeedsUpgradeTeaching, city + " no affordable upgrade does not teach");
            save.Data.Coins = 10000;
            Check(source.NeedsUpgradeTeaching, city + " first affordable upgrade teaches");
            foreach (var offer in source.Offers) Check(source.Effects(offer).Length > 0, city + " effects present");
            if (city == "wuhan")
            {
                var doupi = source.Offers.Single(o => o.EquipmentId == "doupi_griddle");
                Check(doupi.Price == 280 && source.Effects(doupi).Contains("不会煎焦") && source.Equipment.Single(e => e.Id == "doupi_griddle").Effects.Any(e => e.Name == "每锅产量" && e.Next == "8 块") && source.Equipment.Single(e => e.Id == "doupi_griddle").Effects.Any(e => e.Next.Contains("手动翻面")), "Wuhan Lv2 price and actual capabilities");
            }
            Check(save.TrySave(out _), city + " fixture saved");
            using (var locked = new FileStream(ProjectSettings.GlobalizePath(path) + ".tmp", FileMode.Create, System.IO.FileAccess.Write, FileShare.None))
                Check(!source.Purchase(first, out _) && source.Coins == 10000 && source.Offers.Contains(first), city + " failed save rolls back wallet and level");

            // Keep a real workstation behind the book in captures, so an opaque page backdrop is visible as a regression.
            Control? workstation = null;
            DayController? controller = null;
            if (Capture && city == "tianjin")
            {
                controller = new DayController(); AddChild(controller); controller.SetProcess(false);
                var screen = GD.Load<PackedScene>("res://Scenes/Gameplay/TianjinDayScreen.tscn").Instantiate<TianjinDayScreen>();
                AddChild(screen); screen.SetProcess(false);
                screen.ConnectController(controller); screen.Initialize(catalog, save, controller, 2); screen.BeginDay();
                workstation = screen;
            }
            var model = Fixture(city); model.Closing = true; model.Upgrades = source;
            var view = new BusinessDetailsView(); AddChild(view); bool closed = false; view.CloseRequested += () => closed = true;
            model.Closing = false; view.Open(model);
            view.FinishAnimation(); await Frames();
            var teaching = view.Descendants<TutorialFocusLayer>().Single();
            Check(teaching.CurrentAction is null, city + " no upgrade teaching during business");
            if (city is "tianjin" or "wuhan")
                Check(view.Descendants<Button>().Single(b => b.Name == "OpenBookUpgrades").Disabled, city + " live summary keeps a disabled upgrade action");
            else Check(!view.Descendants<Button>().Any(b => b.Name == "OpenBookUpgrades" || b.Name == "UpgradeSticker"), city + " affordable live upgrades hidden");
            model.Closing = true;
            Button Entry() => view.Descendants<Button>().Single(b => b.Name == (city is "tianjin" or "wuhan" or "xian" ? "OpenBookUpgrades" : "UpgradeSticker"));
            foreach (var size in CaptureSizes)
            {
                GetWindow().Size = size; await Frames(5); view.Open(model); view.FinishAnimation(); await Frames();
                if (!save.Data.UpgradeTeachingCompleted)
                {
                    Check(teaching.CurrentAction == "first-shop-upgrade", city + " summary highlights affordable upgrade");
                    view.SelectPage(true, false); await Frames();
                    Check(teaching.CurrentAction is null, city + " details hide upgrade teaching");
                    view.SelectPage(false, false); await Frames();
                    if (Capture) await Shot(city + "-first-upgrade-teaching");
                }
                Click(Entry()); await Frames();
                Check(save.Data.UpgradeTeachingCompleted && teaching.CurrentAction is null && source.Coins == 10000,
                    city + " clicking entry acknowledges teaching without purchase");
                save.Load();
                Check(save.Data.UpgradeTeachingCompleted && !source.NeedsUpgradeTeaching, city + " teaching acknowledgement persists");
                Check(!new BookUpgradeSource(save, catalog, ProjectCake.Data.StableIds.Cities.Tianjin).NeedsUpgradeTeaching,
                    city + " acknowledgement shared across cities");
                if (OS.GetCmdlineUserArgs().Contains("--teaching-only")) break;
                var modal = view.Descendants<Control>().Single(n => n.Name == "BookUpgradeModal");
                Check(modal.IsVisibleInTree(), city + " click opens modal");
                Check(modal.Descendants<Label>().Any(l => l.Name == "Coins" && l.Text == source.Coins.ToString()), city + " wallet shown");
                var page = modal.Descendants<StartScreen>().Single();
                Check(page.Page == JourneyPage.Upgrades && page.SelectedCityId == cityId, city + " reuses home upgrade page for source city");
                Check(!page.GetNode<Control>("Canvas/Background").Visible && !page.GetNode<Control>("Letterbox").Visible
                    && page.FindChild("SharedBook", true, false) is TextureRect { Visible: true }, city + " reuses only book and preserves gameplay backdrop");
                Check(view.Descendants<Control>().Single(n => n.Name == "SettlementBook").GetGlobalRect()
                    == page.Descendants<TextureRect>().Single(n => n.Name == "SharedBook").GetGlobalRect(),
                    city + " settlement and upgrade books share the same on-screen frame");
                Check(!view.CloseButton.IsVisibleInTree(), city + " original ledger is hidden beneath upgrade book");
                Check(!page.Descendants<Button>().Any(b => b.Name == "Home" || b.Name == "MapTab" || b.Name == "LedgerTab"), city + " settlement navigation only returns to book");
                Check(!page.Descendants<Button>().Any(b => b.Name == "CloseUpgrades"), city + " upgrade page has no upper-right return button");
                view.CloseButton.EmitSignal(BaseButton.SignalName.Pressed); Check(!closed, city + " modal blocks book close");
                for (int i = 0; i < 8; i++)
                {
                    GetViewport().PushInput(new InputEventKey { Keycode = Key.Tab, Pressed = true, ShiftPressed = i >= 4 }, true);
                    Check(modal.IsAncestorOf(GetViewport().GuiGetFocusOwner()), city + " modal traps keyboard focus " + i + " owner=" + GetViewport().GuiGetFocusOwner()?.GetPath());
                }
                view.Descendants<ScrollContainer>().Single(n => n.Name == "UpgradeScroll").ScrollVertical = 0; await Frames();
                if (Capture) await Shot($"{city}-upgrades-{size.X}");
                var detailScroll = view.Descendants<ScrollContainer>().Single(n => n.Name == "UpgradeScroll");
                var actionRect = view.Descendants<Button>().Single(b => b.Name == "UpgradeEquipment").GetGlobalRect();
                detailScroll.ScrollVertical = 100000; await Frames();
                Check(view.Descendants<Button>().Single(b => b.Name == "UpgradeEquipment").GetGlobalRect() == actionRect, city + " scrolling keeps purchase action fixed");
                if (Capture && detailScroll.ScrollVertical > 0) await Shot($"{city}-upgrades-{size.X}-bottom");
                GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
                Check(!closed && Entry().HasFocus(), city + " Escape restores upgrade focus");
                if (city is "tianjin" or "wuhan")
                    Check(Entry().HasFocus() && Entry().GetThemeStylebox("focus") is StyleBoxFlat,
                        city + " return focus highlights the dedicated upgrade action");
                else if (city == "xian")
                    Check(Entry().GetThemeStylebox("focus") is StyleBoxFlat focus && focus.BgColor.A == 0 && focus.BorderWidthTop > 0,
                        city + " return focus leaves sticker artwork and caption visible");
                if (Capture && size.X == 1920) await Shot(city + "-upgrade-return-focus");
                Click(Entry()); await Frames();
                GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true); await Frames();
                Check(!closed && Entry().HasFocus() && !view.Descendants<Control>().Any(n => n.Name == "BookUpgradeModal"), city + " Escape restores original book");
            }
            if (OS.GetCmdlineUserArgs().Contains("--teaching-only"))
            {
                view.QueueFree(); workstation?.QueueFree(); controller?.QueueFree(); save.QueueFree(); await Frames();
                continue;
            }
            int income = model.Result.TotalRevenue;
            Click(Entry()); await Frames();
            Click(view.Descendants<Button>().Single(b => b.Name == "Select_" + first.EquipmentId));
            Check(source.Coins == 10000, city + " selection does not purchase");
            var buy = view.Descendants<Button>().Single(b => b.Name == "UpgradeEquipment");
            var scroll = view.Descendants<ScrollContainer>().Single(n => n.Name == "UpgradeScroll"); scroll.ScrollVertical = 0; await Frames();
            using (var locked = new FileStream(ProjectSettings.GlobalizePath(path) + ".tmp", FileMode.Create, System.IO.FileAccess.Write, FileShare.None)) {
                Click(buy); await Frames();
                Check(source.Coins == 10000 && view.Descendants<Label>().Any(l => l.Name == "UpgradeFeedback" && l.Text.Contains("保存失败")), city + " UI failure rolls back and explains retry");
            }
            buy = view.Descendants<Button>().Single(b => b.Name == "UpgradeEquipment");
            Check(!buy.Disabled, city + " failure allows retry");
            Click(buy); await Frames();
            Check(view.Descendants<EquipmentUpgradeView>().Single().SelectedId == first.EquipmentId, city + " purchase retains selection");
            Check(source.Coins == 10000 - first.Price && model.Result.TotalRevenue == income, city + " UI purchase debits once without recommitting revenue");
            Check(view.Descendants<Label>().Any(l => l.Name == "Coins" && l.Text == source.Coins.ToString()), city + " shared page refreshes balance after purchase");
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
            Click(view.Descendants<Button>().Single(b => b.Name == "Select_" + last.EquipmentId));
            var lastBuy = view.Descendants<Button>().Single(b => b.Name == "UpgradeEquipment"); lastBuy.GrabFocus(); await Frames();
            foreach (bool pressed in new[] { true, false }) GetViewport().PushInput(new InputEventKey { Keycode = Key.Space, Pressed = pressed }, true);
            await Frames();
            Check(source.Coins == 0 && view.Descendants<Button>().Single(b => b.Name == "UpgradeEquipment").Disabled, city + " Space buys final offer with exact balance and empty state");
            Check(source.Offers.Count == 0 && bought < 20, city + " max levels hide offers");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            Check(Entry().HasFocus(), city + " unaffordable list returns focus to upgrade entry");
            view.Open(model); view.FinishAnimation();
            Check(Entry().IsVisibleInTree(), city + " unaffordable equipment keeps entry");
            Click(Entry()); await Frames();
            Check(view.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("Select_")) == (city == "yangzhou" ? 2 : 3), city + " all equipment remains visible");
            if (Capture) await Shot(city + "-upgrades-unaffordable");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            var reloadedProgress = save.Data.GetCity(cityId);
            foreach (string id in reloadedProgress.EquipmentLevels.Keys.ToArray())
                if (!(city == "wuhan" && id == "ingredient_station")) reloadedProgress.EquipmentLevels[id] = 3;
            save.Data.Coins = 10000;
            view.Open(model); view.FinishAnimation(); await Frames();
            Check(source.Offers.Count == 0 && Entry().IsVisibleInTree(), city + " truly maxed equipment keeps entry with sufficient coins");
            Click(Entry()); await Frames();
            Check(source.Equipment.All(e => e.TargetLevel is null && !e.CanBuy), city + " maxed equipment has no next level");
            Check(view.Descendants<Label>().All(l => !l.Name.ToString().StartsWith("Next_")), city + " max detail only shows current effects");
            if (Capture) await Shot(city + "-upgrades-max");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            model.Closing = false; view.Open(model);
            if (city is "tianjin" or "wuhan")
                Check(view.Descendants<Button>().Single(b => b.Name == "OpenBookUpgrades").Disabled, city + " live summary retains disabled upgrade action");
            else Check(!view.Descendants<Button>().Any(b => b.Name == "OpenBookUpgrades" || b.Name == "UpgradeSticker"), city + " live no entry");
            view.QueueFree(); workstation?.QueueFree(); controller?.QueueFree(); save.QueueFree(); await Frames();
        }
    }
}
