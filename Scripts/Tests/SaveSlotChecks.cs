using System.Text.Json;
using System.Text.Json.Nodes;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

internal static class SaveSlotChecks
{
    private static int _checks;
    private static void Check(bool ok, string reason)
    { if (!ok) throw new InvalidOperationException(reason); _checks++; }

    public static async Task Run(Node host, StartScreen screen, GameController main, SaveService save,
        string directory, Func<string, Task> capture)
    {
        _checks = 0;
        Storage(directory, host.GetNode<DataCatalog>("/root/DataCatalog"));
        var configured = new SaveService(); configured.UsePathForTests(Path.Combine(directory, "before-ready.json"));
        host.AddChild(configured);
        Check(!configured.UsesSlots && configured.TrySave(out _), "explicit test path survives node initialization");
        configured.Free();
        string root = Path.Combine(directory, "ui-slots");
        save.UseSlotsForTests(root, ExperienceProfile.IsDemo);
        screen.PresentHome(); await Frames();
        Check(Find<Button>("Continue").Disabled, "no active journey cannot continue");
        await capture("slots-home");
        await Click("JourneyArchives");
        Check(screen.ModalOpen && !save.GetSlots().Any(s => s.Exists), "browsing archives does not create a save");
        await capture("slots-archives-empty");
        await Click("CloseArchives");
        string blocked = Path.Combine(root, "slot-1.json");
        Directory.CreateDirectory(blocked);
        await Click("NewGame");
        Check(screen.Page == JourneyPage.Home && !save.CanContinue && Find<Label>("Status").Text.Length > 0,
            "failed creation stays on home and exposes error");
        Directory.Delete(blocked);
        await Click("NewGame");
        await Frames();
        Check(save.ActiveSlotId == 1 && screen.Page == JourneyPage.NewJourneyMap && save.GetSlots().Count(s => s.Exists) == 1,
            "new journey creates the chosen empty slot and opens first-station animation");
        await capture("slots-new-opening");
        save.Data.Coins = 321; save.Data.Tianjin.HighestUnlockedDay = 4;
        save.Data.Tianjin.LearnedWorkbenchActions.Add("flip");
        Check(save.TrySave(out _), "save first journey");
        string first = File.ReadAllText(Path.Combine(root, "slot-1.json"));
        Check(save.TryCreateSlot(2, out _), "create second journey outside settings");
        save.Data.Coins = 654; save.Data.Tianjin.HighestUnlockedDay = 6; Check(save.TrySave(out _), "save second journey");
        save.TryLoadSlot(1, out _);
        screen.PresentHome(); await Click("JourneyArchives");
        Check(screen.FindChild("ArchiveCard1", true, false) is null
            && Enumerable.Range(2, 4).All(id => Find<Control>("ArchiveCard" + id) is not null),
            "featured journey has no frame and all four other slots remain visible");
        Check(Find<Label>("CurrentArchiveCaption").Text == "旅途中·" + save.GetSlots()[0].Name
            && screen.FindChild("ArchiveName1", true, false) is null
            && Find<TextureRect>("ArchiveCitySticker1").Position.X > 700
            && Find<TextureRect>("ArchiveCitySticker1").Size == new Vector2(150, 150),
            "featured name is merged into the note and city icon is at top right");
        Check(Find<TextureRect>("CurrentArchiveFlag").Texture is AtlasTexture banner
            && banner.Atlas.ResourcePath.EndsWith("今日手记便签底板.png")
            && screen.FindChild("ArchiveBreakfastMap1", true, false) is not null
            && Find<TextureRect>("CurrentArchiveFlag").StretchMode == TextureRect.StretchModeEnum.KeepAspectCentered
            && screen.FindChild("ArchiveJourneyLine", true, false) is null
            && screen.FindChild("ArchiveJourneyStart", true, false) is null
            && screen.FindChild("ArchiveJourneyEnd", true, false) is null,
            "featured note keeps its aspect ratio, skyline returns without route");
        Check(Find<Label>("ArchivePostcardCity").Text == "天津"
            && Find<TextureRect>("ArchivePostcardPin") is not null
            && screen.FindChild("FeaturedArchiveCover", true, false) is null,
            "featured city postcard replaces the book and includes a location label");
        Check(Find<Label>("ArchiveProgress2").Text == "天津 · 第 6 天"
            && Find<Label>("ArchiveCoins2").Text == "654"
            && Find<TextureRect>("ArchiveCoinIcon2").Position.Y > Find<Label>("ArchiveProgress2").Position.Y
            && Find<Button>("ArchiveSelect2").TooltipText == "",
            "other journey shows coins on a separate icon row with no tooltip");
        Check(Find<Button>("DeleteSlot1").Text == "删除",
            "delete action is explicitly labeled");
        await capture("slots-archives-two");
        await Click("ArchiveSelect2");
        Check(save.ActiveSlotId == 1 && Find<Button>("ArchiveSlot2").Text == "选择这段旅程",
            "selecting a small journal reveals its action without switching saves");
        Check(Find<Button>("RenameSlot1").Size == Find<Button>("RenameSlot2").Size
            && Find<Button>("DeleteSlot1").Size == Find<Button>("DeleteSlot2").Size
            && Find<Button>("RenameSlot1").Position.Y == Find<Button>("DeleteSlot1").Position.Y
            && Find<Button>("ArchiveSlot1").Position.Y == Find<Button>("RenameSlot1").Position.Y,
            "both pages use matching rename and delete controls");
        await capture("slots-archives-selected");
        await Click("ArchiveSlot2");
        Check(save.ActiveSlotId == 2 && save.Data.Coins == 654 && screen.Page == JourneyPage.Map && !screen.ModalOpen,
            "archives switch to the selected journey and show its map");
        await capture("slots-map-current");
        Check(File.ReadAllText(Path.Combine(root, "slot-1.json")) == first, "switching preserves the first journey");
        await Click("MapSwitchJourney");
        Check(screen.ModalOpen && Find<Button>("MapSwitchSlot1").Text.Contains("第4天")
            && Find<Button>("MapSwitchSlot1").Text.Contains("金币321")
            && Find<Button>("MapSwitchSlot2").Text.Contains("金币654")
            && screen.FindChild("MapSwitchSlot3", true, false) is null
            && Find<Button>("MapSwitchArchives") is not null,
            "map dropdown lists occupied journeys with independent city, day, coins and archive access");
        await capture("slots-map-switch");
        await Click("MapSwitchSlot1");
        Check(save.ActiveSlotId == 1 && save.Data.Coins == 321 && screen.Page == JourneyPage.Map
            && Find<Label>("MapJourneyTitle").Text == "天津·第4天·金币321"
            && screen.FindChild("MapCurrentProgress", true, false) is null,
            "quick switch refreshes the map from the selected journey");
        await Click("MapSwitchJourney"); await Click("MapSwitchSlot2");
        screen.PresentHome(); await Click("JourneyArchives");
        await Click("RenameSlot2");
        Find<LineEdit>("ArchiveRename").Text = "清晨武汉";
        await Click("SaveArchiveName");
        Check(save.GetSlots()[1].Name == "清晨武汉" && Find<Label>("CurrentArchiveCaption").Text == "旅途中·清晨武汉",
            "archive renames a journey without changing its progress");
        await Click("CloseArchives");
        var settings = host.GetNode<JourneySettings>("/root/JourneySettings");
        settings.SetLanguage("en"); screen.PresentHome(); await Click("JourneyArchives");
        Check(screen.FindChild("ArchivesTitle", true, false) is null
            && screen.FindChild("ArchivesHint", true, false) is null,
            "archive spread omits the central title and instruction");
        await capture("slots-archives-en");
        await Click("CloseArchives"); settings.SetLanguage("zh_CN"); screen.PresentHome();
        for (int id = 3; id <= 5; id++) Check(save.TryCreateSlot(id, out _), "fill slot " + id);
        save.TryLoadSlot(2, out _); screen.PresentHome(); await Click("NewGame");
        Check(screen.ModalOpen && Find<Label>("ArchivesFullMessage").Text.Contains("旅程档案") && save.ActiveSlotId == 2,
            "full slots show archive recovery without replacing current journey");
        await Click("CloseArchivesFull");
        File.WriteAllText(Path.Combine(root, "slot-3.json"), "broken");
        screen.PresentHome(); await Click("JourneyArchives");
        Check(Find<Label>("ArchiveName3").Text.Contains("无法读取") && Find<Button>("ArchiveSlot2") is not null,
            "corrupt slot does not block other journey choices");
        await capture("slots-corrupt");
        await Click("CloseArchives");
        save.Load();
        Check(save.ActiveSlotId == 2 && save.CanContinue, "restart restores last selected slot");
        // Exercise actual city initialization and ownership binding, including Yangzhou's separate session.
        string[] cities = ExperienceProfile.IsDemo ? new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan }
            : JourneyModel.Cities.Select(c => c.Id).ToArray();
        save.Data.UnlockedCityIds = cities.ToList(); foreach (string city in cities) save.Data.GetCity(city);
        save.TrySave(out _);
        if (!OS.GetCmdlineUserArgs().Contains("--archives-only")) foreach (string city in cities)
        {
            Check(main.OpenCity(city) && main.StartCityBusiness(city, 1), "city initializes against active slot " + city);
            main.OpenCity(city); screen.PresentHome(); await Frames();
            Check(save.ContinueCityId == city, "business records resume city " + city);
            string saved = File.ReadAllText(Path.Combine(root, "slot-2.json"));
            await Click("Continue");
            Check(screen.Page == JourneyPage.Map
                && Find<Label>("MapJourneyTitle").Text.Contains(JourneyModel.City(city).Name)
                && Find<Label>("MapJourneyTitle").Text.Contains($"·第{save.Data.GetCity(city).HighestUnlockedDay}天·金币{save.Data.Coins}")
                && screen.FindChild("MapCurrentProgress", true, false) is null,
                "home continue shows active slot city and day on map " + city);
            await Click("Node" + Array.FindIndex(JourneyModel.Cities, c => c.Id == city));
            Check(screen.Page == JourneyPage.City && screen.SelectedCityId == city
                && screen.SelectedDay == save.Data.GetCity(city).HighestUnlockedDay,
                "continue map opens saved city and day " + city);
            Check(File.ReadAllText(Path.Combine(root, "slot-2.json")) == saved,
                "opening saved city preserves progress " + city);
        }
        screen.PresentMap(); await Click("Node1");
        Check(screen.Page == JourneyPage.City && screen.SelectedCityId == StableIds.Cities.Wuhan,
            "another unlocked city remains selectable from the journey map");
        if (!save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan))
            save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
        if (!ExperienceProfile.IsDemo)
        {
            save.Data.LastVisitedCityId = StableIds.Cities.Xian;
            Check(save.TrySave(out _), "save Xian postcard preview");
            screen.PresentHome(); await Click("JourneyArchives");
            Check(Find<Label>("ArchivePostcardCity").Text == "西安", "Xian uses its own postcard label");
            await capture("slots-archives-xian");
            await Click("CloseArchives");
        }
        save.Data.LastVisitedCityId = StableIds.Cities.Wuhan;
        save.Data.Wuhan.HighestUnlockedDay = 2;
        Check(save.TrySave(out _), "save Wuhan as the current archive city");
        screen.PresentHome(); await Click("JourneyArchives");
        Check(Find<TextureRect>("ArchiveCitySticker2").Texture is AtlasTexture wuhanStamp
            && wuhanStamp.Atlas.ResourcePath.Contains("武汉"),
            "Wuhan journey shows its city icon at top right");
        await capture("slots-archives-wuhan");
        await Click("ArchiveSelect1"); await Click("DeleteSlot1");
        Check(screen.ConfirmationOpen && save.GetSlots()[0].Exists, "archive asks before deleting another journey");
        Check(screen.FindChildren("Home", "Button", true, false).OfType<Button>()
            .All(button => !button.IsVisibleInTree() || button.FocusMode == Control.FocusModeEnum.None),
            "delete confirmation keeps archive navigation out of keyboard focus");
        await Click("CancelDeleteSave");
        Check(screen.ModalOpen && save.GetSlots()[0].Exists && Find<Button>("DeleteSlot1").HasFocus(),
            "cancel keeps the journey open and restores its delete action");
        await Click("DeleteSlot1"); await Click("ConfirmDeleteSave");
        Check(!save.GetSlots()[0].Exists && save.ActiveSlotId == 2,
            "deleting another journey preserves the active journey");
        await Click("DeleteSlot2"); await Click("ConfirmDeleteSave");
        Check(save.ActiveSlotId is null && !save.CanContinue, "deleting current journey clears continuation");
        GD.Print($"SAVE_SLOTS_TEST_RESULT passed={_checks} failed=0");

        async Task Frames()
        {
            for (int i = 0; i < 3; i++) await host.ToSignal(host.GetTree(), SceneTree.SignalName.ProcessFrame);
            while (JourneyTransition.For(host).Active) await host.ToSignal(host.GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        T Find<T>(string name) where T : Node => screen.FindChildren(name, "", true, false).OfType<T>().First(n => n is not Control c || c.IsVisibleInTree());
        async Task Click(string name)
        {
            await Frames(); var control = Find<Control>(name); Vector2 at = control.GetGlobalTransformWithCanvas() * (control.Size / 2);
            host.GetViewport().PushInput(new InputEventMouseMotion { Position = at, GlobalPosition = at }, true);
            host.GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = at, GlobalPosition = at }, true);
            await Frames();
            host.GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = at, GlobalPosition = at }, true);
            if (name.StartsWith("ArchiveSelect", StringComparison.Ordinal))
                Check(!JourneyTransition.For(host).Active, "selecting an archive does not replay a book transition");
            await Frames();
        }
    }

    private static void Storage(string directory, DataCatalog catalog)
    {
        string root = Path.Combine(directory, "storage");
        var save = new SaveService(); save.UseSlotsForTests(root);
        for (int id = 1; id <= 5; id++)
        {
            Check(save.TryCreateSlot(id, out _), "create " + id);
            save.Data.Coins = id * 100;
            save.Data.Tianjin.HighestUnlockedDay = id;
            save.Data.Tianjin.EquipmentLevels["pancake_stove"] = id;
            save.Data.Tianjin.LearnedWorkbenchActions.Add("learned-" + id);
            save.Data.BreakfastRecords["pancake"] = id;
            Check(save.TrySave(out _), "save " + id);
        }
        Check(!save.TryCreateSlot(1, out _), "occupied slots cannot be overwritten");
        for (int id = 1; id <= 5; id++)
        {
            Check(save.TryLoadSlot(id, out _) && save.Data.Coins == id * 100 && save.Data.Tianjin.HighestUnlockedDay == id
                && save.Data.Tianjin.EquipmentLevels["pancake_stove"] == id && save.Data.Tianjin.LearnedWorkbenchActions.SetEquals(new[] { "learned-" + id })
                && save.Data.BreakfastRecords["pancake"] == id, "profile data isolated " + id);
        }
        Check(!save.TryRenameSlot(1, new string('长', 21), out _) && !save.TryRenameSlot(1, "\n", out _), "invalid names rejected");
        Check(save.TryRenameSlot(1, string.Concat(Enumerable.Repeat("🍳", 20)), out _), "name length counts Unicode text elements");
        save.QueueJourneyCompletion(StableIds.Cities.Tianjin);
        var run = new DayPlan { Day = 1 }; save.BindRun(run);
        Check(save.TryLoadSlot(1, out _) && save.PendingJourneyCompletion is null, "switch clears pending presentation");
        catalog.TryGetDay(StableIds.Cities.Tianjin, 1, out var config);
        bool rejected = false;
        try { save.CommitDay(new() { Day = 1, SaleRevenue = 50 }, run, config); } catch (IOException) { rejected = true; }
        Check(rejected && save.Data.Coins == 100, "old session cannot credit a new journey");
        save.TryDeleteSlot(5, out _);
        string indexBefore = File.ReadAllText(Path.Combine(root, "index.json"));
        Directory.CreateDirectory(Path.Combine(root, "index.json.tmp"));
        Check(!save.TryCreateSlot(5, out _) && !save.GetSlots()[4].Exists && save.ActiveSlotId == 1, "new slot rolls back when index write fails");
        Check(!save.TryLoadSlot(2, out _) && save.ActiveSlotId == 1 && save.Data.Coins == 100, "failed selection preserves memory");
        Check(!save.TryDeleteSlot(1, out _) && save.GetSlots()[0].Exists && save.ActiveSlotId == 1, "failed deletion preserves current slot");
        Directory.Delete(Path.Combine(root, "index.json.tmp"));
        Check(File.ReadAllText(Path.Combine(root, "index.json")) == indexBefore, "failed operations preserve index");
        string first = File.ReadAllText(Path.Combine(root, "slot-1.json"));
        Directory.CreateDirectory(Path.Combine(root, "slot-1.json.tmp"));
        Check(!save.TryRenameSlot(1, "失败改名", out _) && save.GetSlots()[0].Name != "失败改名", "failed rename preserves file");
        save.BindRun(run = new DayPlan { Day = 1 }); rejected = false;
        try { save.CommitDay(new() { Day = 1, SaleRevenue = 50 }, run, config); } catch (IOException) { rejected = true; }
        Check(rejected && save.Data.Coins == 100 && File.ReadAllText(Path.Combine(root, "slot-1.json")) == first, "failed settlement rolls back memory and disk");
        Directory.Delete(Path.Combine(root, "slot-1.json.tmp"));
        save.CommitDay(new() { Day = 1, SaleRevenue = 50 }, run, config);
        Check(save.Data.Coins == 150, "failed settlement can retry");
        save.CommitDay(new() { Day = 1, SaleRevenue = 50 }, run, config);
        Check(save.Data.Coins == 150, "settlement remains idempotent");
        var incomplete = JsonNode.Parse(File.ReadAllText(Path.Combine(root, "slot-2.json")))!;
        incomplete["Data"]!["UnlockedCityIds"] = null;
        File.WriteAllText(Path.Combine(root, "slot-2.json"), incomplete.ToJsonString());
        string selection = File.ReadAllText(Path.Combine(root, "index.json"));
        Check(!save.TryLoadSlot(2, out _) && save.ActiveSlotId == 1 && save.Data.Coins == 150
            && File.ReadAllText(Path.Combine(root, "index.json")) == selection, "incomplete schema cannot partially activate a slot");
        File.WriteAllText(Path.Combine(root, "slot-2.json"), "corrupt");
        Check(save.GetSlots()[1].Corrupt && !save.TryLoadSlot(2, out _) && save.ActiveSlotId == 1, "bad profile cannot replace current journey");
        File.WriteAllText(Path.Combine(root, "index.json"), "bad index"); save.Load();
        Check(!save.CanContinue && save.GetSlots()[0].Exists && save.TryLoadSlot(1, out _), "invalid selection index requires explicit choice");
        File.Delete(Path.Combine(root, "index.json")); save.Load();
        Check(!save.CanContinue && save.GetSlots()[0].Exists, "missing index does not select a journey");
        Check(save.TryLoadSlot(1, out _) && save.TryDeleteSlot(1, out _) && !save.CanContinue, "delete active profile clears active state");
        save.Load(); Check(!save.CanContinue, "deleted active selection stays clear on restart");

        string oldPath = Path.Combine(directory, "legacy.json");
        string original = JsonSerializer.Serialize(new SaveData { Coins = 777 }); File.WriteAllText(oldPath, original);
        string migrated = Path.Combine(directory, "migration"); save.UseSlotsForTests(migrated, legacy: oldPath);
        Check(save.ActiveSlotId == 1 && save.Data.Coins == 777 && File.ReadAllText(oldPath) == original, "v3 migration preserves original");
        save.TryDeleteSlot(1, out _); save.Load(); Check(!save.GetSlots()[0].Exists, "deleted migration never reimports");
        string retry = Path.Combine(directory, "migration-retry"); Directory.CreateDirectory(Path.Combine(retry, "slot-1.json.tmp"));
        save.UseSlotsForTests(retry, legacy: oldPath); Check(!save.CanContinue && save.SlotError.Length > 0, "migration write failure is explicit");
        Directory.Delete(Path.Combine(retry, "slot-1.json.tmp")); save.Load(); Check(save.Data.Coins == 777, "migration retries without loss");
        File.WriteAllText(oldPath, "corrupt legacy"); save.UseSlotsForTests(Path.Combine(directory, "corrupt-migration"), legacy: oldPath);
        Check(save.GetSlots()[0].Corrupt && !save.CanContinue && save.TryCreateSlot(2, out _), "bad legacy occupies only first slot");
        foreach (int version in new[] { 1, 2 })
        {
            string legacyRoot = Path.Combine(directory, "v" + version); Directory.CreateDirectory(legacyRoot);
            string path = Path.Combine(legacyRoot, "old.json");
            var legacy = version == 1 ? JsonSerializer.SerializeToNode(new LegacySaveDataV1 { Version = 1, Coins = 432 })
                : JsonSerializer.SerializeToNode(new LegacySaveDataV2 { Version = 2, Coins = 432 });
            File.WriteAllText(path, legacy!.ToJsonString());
            // Supply the old-version fallback path as production does.
            save.UseLegacySlotsForTests(Path.Combine(legacyRoot, "slots"), Path.Combine(legacyRoot, "current.json"), path);
            Check(save.CanContinue && save.Data.Coins == 432 && JsonNode.Parse(File.ReadAllText(path))!["Version"]!.GetValue<int>() == version,
                "legacy version migrated without overwriting " + version);
            string retryRoot = Path.Combine(legacyRoot, "retry");
            string blocked = Path.Combine(retryRoot, ".legacy-import", "converted.json.tmp"); Directory.CreateDirectory(blocked);
            save.UseLegacySlotsForTests(retryRoot, Path.Combine(legacyRoot, "absent.json"), path);
            Check(!save.GetSlots()[0].Exists && save.SlotError.Length > 0, "legacy converter write failure is not classified as corruption");
            Directory.Delete(blocked); save.Load();
            Check(save.CanContinue && save.Data.Coins == 432, "legacy converter write failure retries " + version);
        }
        string demoRoot = Path.Combine(directory, "demo");
        string demoOld = Path.Combine(directory, "demo-old.json");
        string demoOriginal = JsonSerializer.Serialize(new DemoSaveFile(), DemoCatalog.JsonOptions); File.WriteAllText(demoOld, demoOriginal);
        save.UseSlotsForTests(demoRoot, demo: true, legacy: demoOld);
        Check(save.CanContinue && save.Data.Coins == 0 && File.ReadAllText(demoOld) == demoOriginal, "old Demo follows existing migration and preserves original");
        var formal = new SaveService(); formal.UseSlotsForTests(Path.Combine(directory, "formal")); formal.TryCreateSlot(1, out _);
        formal.Data.Coins = 123; formal.TrySave(out _); save.Load();
        Check(save.Data.Coins == 0 && formal.Data.Coins == 123 && save.IsDemo && !formal.IsDemo, "Demo and formal collections isolated");
        formal.Free(); save.Free();
    }
}
