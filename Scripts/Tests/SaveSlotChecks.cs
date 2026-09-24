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
        Check(screen.ModalOpen && !save.CanContinue, "new journey first selects an empty journal");
        await capture("slots-new-selection");
        await Click("CreateSlot1");
        Check(screen.Page == JourneyPage.Home && !save.CanContinue && Find<Label>("Status").Text.Length > 0,
            "failed creation stays on home and exposes error");
        Directory.Delete(blocked);
        await Click("NewGame");
        await Click("CreateSlot1");
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
        Check(Enumerable.Range(1, SaveService.SlotCount).All(id => Find<Control>("ArchiveCard" + id) is not null),
            "home archives lists all five slots");
        Check(Find<Label>("ArchiveProgress1").Text.Contains("天津 · 第 4 天")
            && Find<Label>("ArchiveProgress2").Text.Contains("天津 · 第 6 天"),
            "archive shows each journey's city and current day");
        await capture("slots-archives-two");
        await Click("ArchiveSlot2");
        Check(save.ActiveSlotId == 2 && save.Data.Coins == 654 && screen.Page == JourneyPage.Map && !screen.ModalOpen,
            "archives switch to the selected journey and show its map");
        await capture("slots-map-current");
        Check(File.ReadAllText(Path.Combine(root, "slot-1.json")) == first, "switching preserves the first journey");
        await Click("MapSwitchJourney");
        Check(screen.ModalOpen && Find<Button>("MapSwitchSlot1").Text.Contains("第 4 天"),
            "map offers a quick journey switch with progress");
        Check(Find<Button>("MapSwitchNewJourney") is not null,
            "map offers a new journey when an empty journal remains");
        await capture("slots-map-switch");
        await Click("MapSwitchSlot1");
        Check(save.ActiveSlotId == 1 && save.Data.Coins == 321 && screen.Page == JourneyPage.Map
            && Find<Label>("MapCurrentProgress").Text.Contains("旅程 1"),
            "quick switch refreshes the map from the selected journey");
        await Click("MapSwitchJourney"); await Click("MapSwitchSlot2");
        screen.PresentHome(); await Click("JourneyArchives");
        await Click("RenameSlot2");
        Find<LineEdit>("ArchiveRename").Text = "清晨武汉";
        await Click("SaveArchiveName");
        Check(save.GetSlots()[1].Name == "清晨武汉" && Find<Label>("ArchiveName2").Text == "清晨武汉",
            "archive renames a journey without changing its progress");
        await Click("CloseArchives");
        var settings = host.GetNode<JourneySettings>("/root/JourneySettings");
        settings.SetLanguage("en"); screen.PresentHome(); await Click("JourneyArchives");
        Check(Find<Label>("ArchivesTitle").Tr("我的旅程档案").ToString() == "My journeys",
            "archive title has an English translation");
        await capture("slots-archives-en");
        await Click("CloseArchives"); settings.SetLanguage("zh_CN"); screen.PresentHome();
        for (int id = 3; id <= 5; id++) Check(save.TryCreateSlot(id, out _), "fill slot " + id);
        save.TryLoadSlot(2, out _); screen.PresentHome(); await Click("NewGame");
        Check(screen.ModalOpen && Find<Label>("ArchivesHint").Text.Contains("写满") && save.ActiveSlotId == 2,
            "full slots show archive recovery without replacing current journey");
        await Click("CloseArchives");
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
        foreach (string city in cities)
        {
            Check(main.OpenCity(city) && main.StartCityBusiness(city, 1), "city initializes against active slot " + city);
            main.OpenCity(city); screen.PresentHome(); await Frames();
            Check(save.ContinueCityId == city, "business records resume city " + city);
            string saved = File.ReadAllText(Path.Combine(root, "slot-2.json"));
            await Click("Continue");
            Check(screen.Page == JourneyPage.Map && Find<Label>("MapCurrentProgress").Text.Contains(JourneyModel.City(city).Name)
                && Find<Label>("MapCurrentProgress").Text.Contains($"第 {save.Data.GetCity(city).HighestUnlockedDay} 天"),
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
        screen.PresentHome(); await Click("JourneyArchives");
        await Click("DeleteSlot1");
        Check(screen.ConfirmationOpen && save.GetSlots()[0].Exists, "archive asks before deleting another journey");
        Check(Find<Button>("Home").FocusMode == Control.FocusModeEnum.None,
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
