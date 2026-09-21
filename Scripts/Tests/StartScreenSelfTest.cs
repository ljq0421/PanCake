using System.Text.Json.Nodes;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

/// <summary>Exercises real menu input and disk failures using only an isolated workspace save.</summary>
public partial class StartScreenSelfTest : Node
{
    private SaveService _save = null!;
    private GameController _main = null!;
    private PackedScene? _mainScene;
    private StartScreen _screen = null!;
    private string _path = string.Empty;
    private int _passed;
    private bool _capture;
    private int _width;

    public override async void _Ready()
    {
        try
        {
            string[] args = OS.GetCmdlineUserArgs();
            _capture = args.Contains("--capture");
            _width = args.Contains("--small") ? 1280 : args.Contains("--wide") ? 1600 : args.Contains("--square") ? 1080 : 1920;
            GetWindow().Size = new(_width, _width is 1280 or 1600 ? 720 : 1080);
            string directory = ProjectSettings.GlobalizePath($"res://.tmp/start-tests/{Guid.NewGuid():N}");
            Directory.CreateDirectory(directory);
            _path = Path.Combine(directory, "save.json");
            _save = GetNode<SaveService>("/root/SaveService");
            _save.UsePathForTests(_path);
            GetNode<JourneySettings>("/root/JourneySettings").UsePathForTests(Path.Combine(directory, "settings.cfg"));
            InterfaceLessons.MarkAllSeen(GetNode<JourneySettings>("/root/JourneySettings"));
            await Launch();
            if (args.Contains("--new-journey-only")) { await NewJourneyChecks(directory); GD.Print($"NEW_JOURNEY_TEST_PASS checks={_passed} demo={ExperienceProfile.IsDemo}"); GetTree().Quit(); return; }
            if (args.Contains("--collection-only"))
            {
                await CollectionNavigation();
                GD.Print($"COLLECTION_NAVIGATION_OK {_passed}"); GetTree().Quit(); return;
            }
            if (args.Contains("--dialogs-only"))
            {
                await PanelPreview();
                _save.ResetProgress(out _);
                _screen.PresentCity(StableIds.Cities.Tianjin); _screen.PresentLedger(); await Frames();
                Check(!_screen.FindChildren("ResetLedgerProgress", "Button", true, false).Any(), "ledger has no reset entry");
                await Click(Find<Button>("Settings"));
                var settings = GetNode<JourneySettings>("/root/JourneySettings");
                Vector2I originalSize = GetWindow().Size;
                await Click(Find<Button>("Fullscreen"));
                Check(settings.DisplayPending && Find<Button>("RevertDisplay").HasFocus(), "display defaults to revert");
                await Capture("display-confirmation");
                settings._Process(16); await Frames();
                Check(!settings.DisplayPending && GetWindow().Size == originalSize, "display timeout restores dimensions");
                KeyPress(Key.Escape);
                GD.Print($"DIALOGS_SELF_TEST_PASS checks={_passed}"); GetTree().Quit(); return;
            }
            if (args.Contains("--settings-only"))
            {
                await SettingsPageChecks.Run(_screen, _save, GetNode<JourneySettings>("/root/JourneySettings"), Capture);
                GD.Print("SETTINGS_FULL_SELF_TEST_OK"); GetTree().Quit(); return;
            }
            if (args.Contains("--help-only"))
            {
                await HelpPageChecks.Run(_screen, _save, GetNode<JourneySettings>("/root/JourneySettings"), Capture);
                GD.Print("HELP_FULL_SELF_TEST_OK"); GetTree().Quit(); return;
            }
            if (args.Contains("--journey-preview")) { await JourneyPreview(); GD.Print($"JOURNEY_PREVIEW_OK {_passed}"); GetTree().Quit(); return; }
            if (args.Contains("--panel-preview")) { await PanelPreview(); GD.Print($"PANEL_PREVIEW_OK {_passed}"); GetTree().Quit(); return; }
            if (args.Contains("--focus-gallery")) { await FocusGallery(); GD.Print("BUTTON_FOCUS_GALLERY_OK"); GetTree().Quit(); return; }
            if (args.Contains("--home-gallery")) { await HomeGallery(); GD.Print("HOME_GALLERY_OK"); GetTree().Quit(); return; }
            if (args.Contains("--gallery")) { await Gallery(); GD.Print("JOURNEY_GALLERY_OK"); GetTree().Quit(); return; }
            await SaveSlotChecks.Run(this, _screen, _main, _save, directory, Capture);
            SettlementChecks();
            GD.Print($"START_SCREEN_TEST_RESULT passed={_passed} failed=0");
            GetTree().Quit();
        }
        catch (Exception exception)
        {
            GD.PushError(exception.ToString());
            GD.Print($"START_SCREEN_TEST_RESULT passed={_passed} failed=1");
            GetTree().Quit(1);
        }
    }


    private async Task PanelPreview()
    {
        string root = Path.Combine(Path.GetDirectoryName(_path)!, "panel-slots");
        _save.UseSlotsForTests(root);
        Check(_save.TryCreateSlot(1, out _) && _save.TryCreateSlot(2, out _), "panel fixture creates two isolated slots");
        _save.TryLoadSlot(1, out _);
        _screen.PresentHome(); await Click(Find<Button>("Settings"));
        var choice = Find<OptionButton>("SaveSlot");
        Check(choice.ItemCount == SaveService.SlotCount && !choice.IsItemDisabled(0) && !choice.IsItemDisabled(1)
            && choice.IsItemDisabled(2), "settings lists five slots and blocks empty slots");
        choice.EmitSignal(OptionButton.SignalName.ItemSelected, 1); await Frames();
        Check(_save.ActiveSlotId == 2 && _screen.ModalOpen, "settings selector switches slots without opening a manager page");
        await Capture("panel-after");
        _screen.PresentHome();
    }

    private async Task JourneyPreview()
    {
        _save.UseSlotsForTests(Path.Combine(Path.GetDirectoryName(_path)!, "journey-preview"));
        await SelectNewSlot();
        await Click(Find<Button>("Skip"));
        await Capture("new-journey");
        Check(!_screen.Descendants<Button>().Any(b => b.Name == "JournalMap"), "new journey has no map bookmark");
        await Click(Find<Button>("Depart"));
        Check(_save.CanContinue && _screen.Page == JourneyPage.City, "new departure artwork starts the journey through viewport input");
        _screen.PresentHome(); await Frames(); await Click(Find<Button>("Continue"));
        Check(!_screen.Descendants<Button>().Any(b => b.Name == "MapTab"), "continue journey has no map bookmark");
        await Capture("continue-no-map-tab");
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        settings.SetLanguage("en"); await Frames();
        foreach (string tabName in new[] { "LedgerTab", "UpgradeTab" })
        {
            var tabCaption = Find<Button>(tabName).GetNode<Label>("Caption");
            Check(!tabCaption.Tr(tabCaption.Text).ToString().Contains('\n') && tabCaption.GetLineCount() <= 2,
                tabName + " translates and fits after a live language change");
        }
        await Capture("continue-bookmarks-english");
        settings.SetLanguage("zh_CN"); await Frames();
        int? active = _save.ActiveSlotId;
        await SelectNewSlot();
        KeyPress(Key.Escape);
        Check(_save.ActiveSlotId == active && _save.GetSlots().Count(s => s.Exists) == 1, "cancelled second journey preserves first slot");
    }

    private async Task SelectNewSlot()
    {
        if (_screen.Page != JourneyPage.Home) _screen.PresentHome();
        if (!_save.UsesSlots) _save.UseSlotsForTests(Path.Combine(Path.GetDirectoryName(_path)!, "gallery-slots"));
        await Frames(); await Click(Find<Button>("NewGame"));
        Check(_screen.Page == JourneyPage.Map, "new journey opens map");
    }
    private async Task TravelChecks()
    {
        _screen.PresentHome(); await Frames();
        await Click(Find<Button>("WorldMap"));
        Check(_screen.Page == JourneyPage.Map, "wall opens world map");
        await Capture("map-first");
        string before = File.ReadAllText(_path);
        _screen.OpenCard(StableIds.Cities.Wuhan);
        if (_screen.DeveloperToolsVisible)
        {
            Check(_screen.Page == JourneyPage.City && Find<Button>("OpenBusiness").Disabled == false && File.ReadAllText(_path) == before,
                "developer preview opens locked Wuhan Day 1 without changing the save");
            _screen.PresentMap(); await Frames();
        }
        else
            Check(_screen.Page == JourneyPage.Map && File.ReadAllText(_path) == before, "locked card cannot open or mutate save");
        await Click(Find<Button>("Node0"));
        Check(!_screen.Visible && _screen.SelectedDay == 1, "Tianjin node directly starts business");
        await Capture("city-tianjin");
        _main.OpenCity(StableIds.Cities.Tianjin); _screen.PresentMap(); await Frames();
        await Click(Find<Button>("Back"));
        Check(_screen.Page == JourneyPage.Home, "map returns to home source");
        await Click(Find<Button>("Continue"));
        Check(_screen.Page == JourneyPage.City && _screen.SelectedCityId == _save.ContinueCityId, "continue opens saved city");
        foreach (var city in JourneyModel.Cities) { if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id); _save.Data.GetCity(city.Id); }
        _save.Data.GetCity(StableIds.Cities.Tianjin).Completed = true;
        _save.Data.GetCity(StableIds.Cities.Tianjin).BestStars = 1;
        _save.TrySave(out _);
        _screen.PresentMap(); await Frames(); await Capture("map-progress");
        foreach (var city in JourneyModel.Cities)
        {
            _screen.OpenCard(city.Id); await Frames(); await Capture("city-" + city.Name);
            Check(_screen.Page == JourneyPage.City, city.Name + " postcard renders");
            KeyPress(Key.Escape);
            Check(Find<Button>("Node" + Array.IndexOf(JourneyModel.Cities, city)).HasFocus(), city.Name + " card return restores selected map node focus");
        }
        _screen.PresentCompletion(StableIds.Cities.Tianjin, () => _screen.PresentHome());
        await Capture("completion-tianjin"); await Click(Find<Button>("Skip"));
        Check(_screen.Page == JourneyPage.City, "skip completion reaches next postcard");
        _screen.PresentCompletion(StableIds.Cities.Yangzhou, () => _screen.PresentHome());
        await Capture("completion-yangzhou"); await Click(Find<Button>("Skip"));
        Check(_screen.Page == JourneyPage.Map, "last city has no invented overseas destination");
        _save.QueueJourneyCompletion(StableIds.Cities.Tianjin);
        _main.OpenCity(StableIds.Cities.Tianjin);
        Check(_screen.Page == JourneyPage.Completion && _save.PendingJourneyCompletion is null, "return to hub consumes pending completion exactly once");
        Check(_main.GetNode<Control>("UI/MorningHub").Visible && !_screen.GetNode<TextureRect>("Canvas/Background").Visible,
            "completion overlays the finished city workbench without the home backdrop");
        await Click(Find<Button>("Skip"));
        _main.OpenCity(StableIds.Cities.Tianjin);
        Check(_screen.Page == JourneyPage.City, "second hub return never replays completion");
        _screen.PresentHome(); await Frames();
        await Click(Find<Button>("Settings")); await Capture("settings");
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        await SettingsPageChecks.SelectLanguage(_screen, 1);
        Check(settings.Language == "en" && Find<Label>("LanguageLabel").Tr("语言").ToString() == "Language", "full game language choice changes displayed text to English");
        await Capture("settings-english");
        settings.LoadPreferences();
        Check(settings.Language == "en" && _screen.Tr("新的旅程").ToString() == "New journey", "full game language preference persists");
        Check(_screen.Tr("尚未翻译的城市文案").ToString() == "尚未翻译的城市文案", "missing English translation retains source text");
        await SettingsPageChecks.SelectLanguage(_screen, 0);
        Check(settings.Language == "zh_CN" && _screen.Tr("旅途设置").ToString() == "旅途设置", "full game switches back to Chinese without English fallback");
        await Capture("settings-chinese");
        Find<HSlider>("Volumemaster").Value = 63;
        Find<HSlider>("Volumemusic").Value = 28;
        Find<HSlider>("Volumeeffects").Value = 41;
        await Click(Find<Button>("Mute"));
        Check(settings.Muted && AudioServer.IsBusMute(0), "mute affects master");
        Check(Find<TextureRect>("ChannelIconmusic").Texture.ResourcePath.Contains("音乐关闭") && Find<TextureRect>("ChannelIconeffects").Texture.ResourcePath.Contains("音效关闭"), "global mute updates both channel icons");
        settings.LoadPreferences();
        Check(settings.Master == 63 && settings.Music == 28 && settings.Effects == 41 && settings.Muted, "audio preferences persist independently");
        Check(AudioServer.GetBusSend(AudioServer.GetBusIndex(JourneySettings.EffectsBus)) == "Master", "effects bus feeds master");
        await Click(Find<Button>("Mute"));
        Check(!settings.Muted && settings.Master == 63, "unmute preserves volume");
        Find<HSlider>("Volumemusic").Value = 0;
        Check(Find<TextureRect>("ChannelIconmusic").Texture.ResourcePath.Contains("音乐关闭") && Find<TextureRect>("ChannelIconeffects").Texture.ResourcePath.Contains("音效开启"), "zero music volume leaves effects icon active");
        Vector2I oldSize = GetWindow().Size;
        await Click(Find<Button>("Fullscreen")); await Capture("display-confirmation");
        Check(settings.DisplayPending, "display asks for confirmation");
        Check(Find<Panel>("DisplayConfirmationPanel").GetThemeStylebox("panel") is StyleBoxTexture
            && ((StyleBoxTexture)Find<Panel>("DisplayConfirmationPanel").GetThemeStylebox("panel")).Texture.ResourcePath
                == "res://resource/art/TianJin/DialogUI/dialog-panel-v1.png"
            && Find<Label>("DisplayConfirmationTitle").Text == "保留这个显示设置？",
            "display confirmation uses the shared illustrated panel treatment");
        settings._Process(16);
        Check(!settings.DisplayPending && GetWindow().Size == oldSize, "display timeout restores original dimensions");
        KeyPress(Key.Escape);
        Check(!_screen.ModalOpen, "settings closes with Escape");
        await Click(Find<Button>("Help")); await Capture("help");
        KeyPress(Key.Tab); Check(Find<Button>("Close").HasFocus(), "help traps focus"); KeyPress(Key.Escape);
        Check(!_screen.ModalOpen, "help restores page");
        _save.ResetProgress(out _);
        Check(settings.Master == 63 && settings.Effects == 41, "new journey retains preferences");
        _screen.PresentHome(); await Frames();
        await SelectNewSlot();
        Check(_screen.Page == JourneyPage.Map && !_screen.Descendants<Button>().Any(b => b.Name == "JournalMap") && _save.Data.Coins == 0, "new journal has no map bookmark and preserves progress");
        _screen.PresentHome(); await Frames();
        string bad = Path.Combine(Path.GetDirectoryName(_path)!, "blocked-settings"); Directory.CreateDirectory(bad);
        settings.UsePathForTests(bad); settings.SetVolume("effects", 44);
        Check(settings.ErrorMessage.Contains("未能保存"), "settings write failure is visible");
        settings.UsePathForTests(Path.Combine(Path.GetDirectoryName(_path)!, "settings.cfg"));
        settings.SetVolume("master", 100); settings.SetVolume("effects", 100); settings.SetVolume("music", 100);
        if (settings.Muted) settings.ToggleMute();
    }

    private void SettlementChecks()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        string path = Path.Combine(Path.GetDirectoryName(_path)!, "settlement.json");
        var save = new SaveService(); save.UsePathForTests(path);
        foreach (var city in JourneyModel.Cities.Take(ExperienceProfile.IsDemo ? 2 : 4))
        {
            save.ResetProgress(out _);
            var config = catalog.GetDays(city.Id)[city.Days];
            var plan = new DayPlan { Day = city.Days };
            var model = new BusinessBookModel { CityId = city.Id.Replace("city:", ""), Result = new DayResult
                { Day = city.Days, PlannedCustomers = 100, CompletedCustomers = 100, PerfectOrders = 100, Satisfaction = 100, SaleRevenue = 500 } };
            Directory.CreateDirectory(path + ".tmp");
            BusinessBookSettlement.Commit(model, save, plan, config, catalog);
            Check(save.PendingJourneyCompletion is null && !JourneyModel.Progress(save, city.Id).Completed, city.Name + " failed save cannot queue chapter presentation");
            Directory.Delete(path + ".tmp");
            BusinessBookSettlement.Commit(model, save, plan, config, catalog);
            Check(save.TakeJourneyCompletion() == city.Id && save.Data.GetCity(city.Id).Completed, city.Name + " first saved completion queues chapter presentation");
            int coins = save.Data.Coins;
            BusinessBookSettlement.Commit(model, save, plan, config, catalog);
            Check(save.PendingJourneyCompletion is null && save.Data.Coins == coins, city.Name + " repeat cannot replay or repay");
            save.Load(); Check(save.PendingJourneyCompletion is null, city.Name + " loading completed save does not replay");
        }
        save.ResetProgress(out _);
        var yc = YangzhouCatalog.Load(); var session = YangzhouSelfTest.Play(yc, 12, 3, 3);
        Directory.CreateDirectory(path + ".tmp"); YangzhouBusinessBook.Commit(session, yc, save);
        Check(save.PendingJourneyCompletion is null && !save.Data.Yangzhou.Completed, "Yangzhou failed save never queues completion");
        Directory.Delete(path + ".tmp"); YangzhouBusinessBook.Commit(session, yc, save);
        Check(save.TakeJourneyCompletion() == StableIds.Cities.Yangzhou, "Yangzhou first saved completion queues presentation");
        YangzhouBusinessBook.Commit(session, yc, save);
        Check(save.PendingJourneyCompletion is null, "Yangzhou repeat never queues presentation");
        save.Free();
    }

    private void AuditButtonFocus()
    {
        int inspected = 0;
        foreach (var button in _main.FindChildren("*", "Button", true, false).OfType<Button>())
        {
            if (button.FocusMode == Control.FocusModeEnum.None) continue;
            var normal = button.GetThemeStylebox("normal");
            var focus = button.GetThemeStylebox("focus");
            if (normal is StyleBoxEmpty)
                Check(focus is StyleBoxEmpty, "image button has no rectangular focus: " + button.GetPath());
            else if (normal is StyleBoxFlat shape && focus is StyleBoxFlat outline)
                Check(shape.CornerRadiusTopLeft == outline.CornerRadiusTopLeft
                    && shape.CornerRadiusTopRight == outline.CornerRadiusTopRight
                    && shape.CornerRadiusBottomLeft == outline.CornerRadiusBottomLeft
                    && shape.CornerRadiusBottomRight == outline.CornerRadiusBottomRight,
                    "native focus matches button corners: " + button.GetPath());
            inspected++;
        }
        GD.Print("BUTTON_FOCUS_AUDIT inspected=" + inspected);
    }

    private async Task FocusGallery()
    {
        AuditButtonFocus();
        Find<Button>("NewGame").GrabFocus(); await Capture("focus-home-action");
        Find<Button>("Settings").GrabFocus(); await Capture("focus-home-round");
        await Click(Find<Button>("Settings"));
        Find<Button>("Mute").GrabFocus(); await Capture("focus-settings-patch");
        KeyPress(Key.Escape);
        await Click(Find<Button>("WorldMap"));
        Find<Button>("Node0").GrabFocus(); await Capture("focus-map-node");
        AuditButtonFocus();
        await Click(Find<Button>("Back"));
        await SelectNewSlot();
        Find<Button>("Node0").GrabFocus(); await Capture("focus-new-map-node");
        _save.ResetProgress(out _);
        foreach (var city in JourneyModel.Cities)
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
        foreach (string city in new[] { StableIds.Cities.Guangzhou, StableIds.Cities.Yangzhou })
        {
            Check(_main.OpenCity(city), "focus review opens " + city); await Frames();
            var action = _main.FindChildren("*", "Button", true, false).OfType<Button>()
                .First(b => b.IsVisibleInTree() && !b.Disabled && b.FocusMode != Control.FocusModeEnum.None);
            action.GrabFocus(); await Capture("focus-hub-" + city.Replace(':', '-'));
        }
    }

    private async Task HomeGallery()
    {
        Check(_screen.GetNodeOrNull("Canvas/Page/Audio") is null, "home exposes no separate mute button");
        Check(Find<Control>("HomeMap").GetChildren().Count(n => n.Name.ToString().StartsWith("HomeCity")) == 1, "new player sees only Tianjin");
        await Capture("home-first-run");
        await Click(Find<Button>("WorldMap"));
        Check(_screen.Page == JourneyPage.Map, "tabletop map opens existing map flow");
        await Click(Find<Button>("Back"));
        await Click(Find<Button>("WallMap"));
        Check(_screen.Page == JourneyPage.Map, "wall map opens existing map flow");
        await Click(Find<Button>("Back"));
        _save.ResetProgress(out _);
        foreach (var city in JourneyModel.Cities)
        {
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            _save.Data.GetCity(city.Id).HighestUnlockedDay = 5;
        }
        _save.Data.Tianjin.Completed = true;
        _save.Data.LastVisitedCityId = StableIds.Cities.Wuhan;
        Check(_save.TrySave(out _), "home gallery fixture persists");
        _screen.PresentHome(); await Frames();
        var markers = Find<Control>("HomeMap").GetChildren().OfType<Control>().Where(n => n.Name.ToString().StartsWith("HomeCity")).ToArray();
        Check(markers.Length == 5, "home shows all five unlocked cities");
        Check(markers.All(a => markers.All(b => a == b || !a.GetRect().Intersects(b.GetRect()))), "five city callouts do not overlap");
        Check(_save.ContinueCityId == StableIds.Cities.Wuhan && Find<Button>("Continue").TooltipText.Length == 0, "continue retains saved city without hover text");
        await Capture("home-five-cities");
        await Click(Find<Button>("Settings"));
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        await Click(Find<Button>("Mute"));
        Check(settings.Muted && AudioServer.IsBusMute(0), "settings mute controls all sound from home");
        await Capture("home-settings"); KeyPress(Key.Escape);
        await Click(Find<Button>("Help"));
        Check(_screen.ModalOpen, "home help remains available");
        KeyPress(Key.Escape);
    }

    private async Task Gallery()
    {
        await Capture("first-run");
        await SelectNewSlot(); await Capture("new-journey-map");
        _save.ResetProgress(out _);
        foreach (var city in JourneyModel.Cities)
        {
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            var p = _save.Data.GetCity(city.Id); p.HighestUnlockedDay = 5;
        }
        _save.Data.Tianjin.Completed = true; _save.Data.Tianjin.BestStars = 1; _save.Data.Coins = 1280;
        _save.Data.LastVisitedCityId = StableIds.Cities.Wuhan; _save.TrySave(out _);
        _screen.PresentHome(); await Capture("continue");
        await Click(Find<Button>("Continue")); await Capture("journal");
        _screen.PresentHome(); await Frames(); await Click(Find<Button>("WorldMap")); await Capture("map-progress");
        foreach (var city in JourneyModel.Cities) { _screen.OpenCard(city.Id); await Capture("city-" + city.Name); }
        _screen.PresentCompletion(StableIds.Cities.Tianjin, () => _screen.PresentHome());
        await ToSignal(GetTree().CreateTimer(.5), SceneTreeTimer.SignalName.Timeout); await Capture("completion-tianjin");
        await ToSignal(GetTree().CreateTimer(1.65), SceneTreeTimer.SignalName.Timeout); await Capture("completion-route");
        await ToSignal(GetTree().CreateTimer(2), SceneTreeTimer.SignalName.Timeout);
        Check(_screen.Page == JourneyPage.City, "unskipped completion ends at next postcard");
        foreach (string cityId in new[] { StableIds.Cities.Wuhan, StableIds.Cities.Xian })
        {
            _screen.PresentCompletion(cityId, () => _screen.PresentHome());
            await ToSignal(GetTree().CreateTimer(.5), SceneTreeTimer.SignalName.Timeout);
            await Capture("completion-" + JourneyModel.City(cityId).Name);
            await Click(Find<Button>("Skip"));
        }
        foreach (var city in JourneyModel.Cities) { _save.Data.GetCity(city.Id).Completed = true; _save.Data.GetCity(city.Id).BestStars = 1; }
        _screen.PresentCompletion(StableIds.Cities.Yangzhou, () => _screen.PresentHome());
        await Click(Find<Button>("Skip")); await Capture("five-cities");
        _screen.PresentHome(); await Click(Find<Button>("Settings")); await Capture("settings");
        KeyPress(Key.Escape); await Click(Find<Button>("Help")); await Capture("help"); KeyPress(Key.Escape);
        await PanelPreview();
    }

    private async Task CollectionNavigation()
    {
        Check(!_save.CanContinue, "collection fixture starts without a save");
        KeyPress(Key.Down);
        Check(Find<Button>("BreakfastRecords").HasFocus(), "new journey leads to collection in keyboard order");
        KeyPress(Key.Down);
        Check(Find<Button>("WorldMap").HasFocus(), "collection leads to world map in keyboard order");
        await Capture("collection-home-new");
        await Click(Find<Button>("BreakfastRecords"));
        Check(_screen.Page == JourneyPage.Collection && Find<Label>("BreakfastOrigin").Text.Contains("正确送出"), "new players can browse uncollected breakfasts");
        Check(!File.Exists(_path), "browsing does not create a save");
        await Click(Find<Button>("Breakfast_youtiao"));
        await Click(Find<Button>("Back"));
        Check(_screen.Page == JourneyPage.Home && Find<Button>("BreakfastRecords").HasFocus(), "back returns home and restores collection focus");
        Check(_save.ResetProgress(out _), "create isolated journey");
        _save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
        Check(_save.TrySave(out _), "persist unlocked city fixture");
        string before = File.ReadAllText(_path);
        _screen.PresentHome(); await Frames(); await Capture("collection-home");
        await Click(Find<Button>("BreakfastRecords"));
        Check(_screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("Breakfast_")) == 5, "home collection includes both unlocked cities");
        await Click(Find<Button>("Breakfast_doupi"));
        Check(_screen.Page == JourneyPage.Collection && Find<Label>("BreakfastName").Text.Length > 0, "cross-city selection remains in collection");
        Check(!_screen.Descendants<Button>().Any(b => b.Name == "LedgerTab" || b.Name == "UpgradeTab"), "global collection has no city navigation tabs");
        await Capture("collection-global");
        KeyPress(Key.Escape); await Frames();
        Check(_screen.Page == JourneyPage.Home && Find<Button>("BreakfastRecords").HasFocus(), "Escape returns home after selecting a different city");
        await Click(Find<Button>("BreakfastRecords")); await Click(Find<Button>("CollectionHome"));
        Check(_screen.Page == JourneyPage.Home, "footer returns home");
        Check(File.ReadAllText(_path) == before, "collection navigation preserves saved progress and resume city");
        foreach (var city in JourneyModel.Cities.Where(c => !_save.IsDemo || _save.Data.UnlockedCityIds.Contains(c.Id)))
        {
            _screen.PresentCity(city.Id); _screen.PresentLedger(); await Frames();
            Check(!_screen.Descendants<Button>().Any(b => b.Name == "BreakfastRecords" || b.Name == "BusinessRecords"), "ledger keeps only business content " + city.Id);
        }
        File.WriteAllText(_path, "{broken"); _save.Load(); _screen.PresentHome(); await Frames();
        await Click(Find<Button>("BreakfastRecords")); KeyPress(Key.Escape); await Frames();
        Check(_screen.Page == JourneyPage.Home && File.ReadAllText(_path) == "{broken", "corrupt-save browsing returns safely without overwriting data");
    }

    private async Task Launch()
    {
        if (_main is not null) { RemoveChild(_main); _main.Free(); }
        // Keep the scene's managed resources alive across the simulated restarts.
        _mainScene ??= ResourceLoader.Load<PackedScene>("res://Scenes/Main/Main.tscn");
        _main = _mainScene.Instantiate<GameController>();
        AddChild(_main);
        _screen = _main.GetNode<StartScreen>("UI/StartScreen");
        await Frames(3);
        Check(_screen.Page == JourneyPage.Home, "first frame opens home");
        foreach (string name in new[] { "Continue", "NewGame", "BreakfastRecords", "WorldMap" })
            Check(Find<Button>(name).Visible, "home action visible " + name);
        Check(!_screen.FindChildren("Skip", "Button", true, false).Any(), "splash prompt removed");
        if (_capture) await ToSignal(GetTree().CreateTimer(0.3), SceneTreeTimer.SignalName.Timeout);
    }

    private T Find<T>(string name) where T : Node => (T)_screen.FindChildren(name, typeof(T).Name, true, false).First(n => n is not Control c || c.IsVisibleInTree());
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++; GD.Print("PASS " + message);
    }
    private async Task Frames(int count = 2) { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); while (JourneyTransition.For(this).Active) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Click(Control control)
    {
        // Include the canvas scale when dispatching actual viewport input.
        Vector2 point = control.GetGlobalTransformWithCanvas() * (control.Size / 2);
        GetViewport().PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point }, true);
        GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point, GlobalPosition = point }, true);
        await Frames(1);
        GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = point, GlobalPosition = point }, true);
        await Frames();
    }
    private void KeyPress(Key key)
    {
        GetViewport().PushInput(new InputEventKey { Keycode = key, Pressed = true }, true);
        GetViewport().PushInput(new InputEventKey { Keycode = key, Pressed = false }, true);
    }
    private async Task Capture(string state)
    {
        if (!_capture) return;
        await Frames(3);
        await ToSignal(GetTree().CreateTimer(.3), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string directory = ProjectSettings.GlobalizePath($"res://.tmp/start-review/{_width}");
        Directory.CreateDirectory(directory);
        Check(GetViewport().GetTexture().GetImage().SavePng(Path.Combine(directory, state + ".png")) == Error.Ok, "capture " + state);
    }
}
