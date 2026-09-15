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
            await Launch();
            if (args.Contains("--panel-preview")) { await PanelPreview(); GD.Print($"PANEL_PREVIEW_OK {_passed}"); GetTree().Quit(); return; }
            if (args.Contains("--focus-gallery")) { await FocusGallery(); GD.Print("BUTTON_FOCUS_GALLERY_OK"); GetTree().Quit(); return; }
            if (args.Contains("--home-gallery")) { await HomeGallery(); GD.Print("HOME_GALLERY_OK"); GetTree().Quit(); return; }
            if (args.Contains("--gallery")) { await Gallery(); GD.Print("JOURNEY_GALLERY_OK"); GetTree().Quit(); return; }
            Check(!_save.CanContinue && !_save.RequiresNewGameConfirmation, "missing save is distinct from an empty valid save");
            Check(Find<Button>("Continue").Disabled && Find<Button>("Continue").TooltipText.Contains("暂无存档"), "continue stays visible and disabled without a save");
            Check(_main.GetNode("UI").GetChildren().OfType<Control>().Count(c => c.Visible) == 1 && _screen.Visible, "only the title page is visible at startup");
            Check(Find<Button>("NewGame").HasFocus(), "first run focuses new game");
            KeyPress(Key.Down);
            Check(Find<Button>("WorldMap").HasFocus(), "keyboard reaches the new tabletop map entrance");
            KeyPress(Key.Down);
            Check(Find<Button>("Settings").HasFocus(), "keyboard skips unavailable continue");
            KeyPress(Key.Up);
            Check(Find<Button>("WorldMap").HasFocus(), "keyboard returns through map entrance");
            KeyPress(Key.Up);
            Check(Find<Button>("NewGame").HasFocus(), "keyboard navigates back to new journey");
            await Capture("first-run");
            await NewJourney();
            Check(_save.CanContinue && _save.Data.Coins == 0 && _save.Data.LastVisitedCityId == StableIds.Cities.Tianjin, "new game creates an empty valid save");
            Check(_screen.Visible && _screen.Page == JourneyPage.City && _screen.SelectedCityId == StableIds.Cities.Tianjin, "new game enters shared Tianjin hub");

            string[] cities = { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou, StableIds.Cities.Yangzhou };
            string[] hubs = { "MorningHub", "WuhanHub", "XianHub", "GuangzhouHub", "YangzhouHub" };
            _save.Data.UnlockedCityIds = cities.ToList();
            foreach (string city in cities) _save.Data.GetCity(city);
            _save.Data.Coins = 321;
            Check(_save.TrySave(out _), "save fixture persists");
            for (int i = 0; i < cities.Length; i++)
            {
                Check(_main.OpenCity(cities[i]), $"enter {cities[i]}");
                Check(_main.StartCityBusiness(cities[i], 1), "start city to update resume");
                _save.Load();
                await Launch();
                Check(_save.ContinueCityId == cities[i] && Find<Button>("Continue").HasFocus(), $"restart retains {cities[i]} and focuses continue");
                await Click(Find<Button>("Continue"));
                Check(_screen.Page == JourneyPage.City && _screen.SelectedCityId == cities[i], "continue directly opens shared hub");
                await Capture("journal-" + i);
                Check(!_main.GetNode<Control>("UI/" + hubs[i]).Visible && _save.Data.Coins == 321, "legacy hub remains hidden");
            }

            await Launch();
            await Capture("continue");
            string before = File.ReadAllText(_path);
            await NewJourney();
            Check(_screen.ConfirmationOpen && Find<Button>("Cancel").HasFocus(), "existing save requires confirmation with cancel focused");
            await Capture("confirmation");
            await NewJourney();
            Check(File.ReadAllText(_path) == before && _screen.ConfirmationOpen, "confirmation blocks clicks on background controls");
            KeyPress(Key.Tab);
            Check(Find<Button>("Confirm").HasFocus(), "Tab remains within confirmation");
            KeyPress(Key.Tab);
            Check(Find<Button>("Cancel").HasFocus(), "confirmation focus wraps");
            KeyPress(Key.Escape);
            Check(!_screen.ConfirmationOpen && Find<Button>("Depart").HasFocus() && File.ReadAllText(_path) == before, "Escape cancels without touching progress and restores focus");

            // An empty directory at the atomic-save temporary path makes writes fail deterministically.
            Directory.CreateDirectory(_path + ".tmp");
            await NewJourney();
            await Click(Find<Button>("Confirm"));
            Check(_screen.Visible && _save.CanContinue && _save.Data.Coins == 321 && File.ReadAllText(_path) == before, "failed overwrite retains disk and memory progress on title page");
            Check(Find<Label>("Status").Text.Contains("保存失败"), "failed overwrite gives a visible error");
            await Capture("save-error");
            string previousCity = _save.Data.LastVisitedCityId;
            Check(!_save.TryRecordCityVisit(StableIds.Cities.Wuhan, out _) && _save.Data.LastVisitedCityId == previousCity, "failed location save restores prior city");
            Directory.Delete(_path + ".tmp");

            await NewJourney();
            await Click(Find<Button>("Confirm"));
            Check(_save.Data.Coins == 0 && _save.Data.UnlockedCityIds.SequenceEqual(new[] { StableIds.Cities.Tianjin })
                && _save.Data.Cities.Values.All(city => city.HighestUnlockedDay == 1 && city.BestStars == 0 && !city.Completed
                    && city.DayBestRecords.Count == 0 && city.EquipmentLevels.Values.All(level => level <= 1)), "confirmed new game clears every city and returns to Tianjin");
            Check(_main.OpenCity(StableIds.Cities.Wuhan, true) && _save.ContinueCityId == StableIds.Cities.Tianjin, "developer preview of locked city does not alter resume city");
            Check(!_main.OpenCity(StableIds.Cities.Wuhan), "normal navigation rejects locked city");

            JsonObject old = JsonNode.Parse(File.ReadAllText(_path))!.AsObject();
            old.Remove("LastVisitedCityId"); File.WriteAllText(_path, old.ToJsonString());
            _save.Load();
            Check(_save.CanContinue && _save.ContinueCityId == StableIds.Cities.Tianjin, "old v3 save without city field loads without data loss");
            foreach (string invalid in new[] { "city:future", StableIds.Cities.Wuhan })
            {
                old["LastVisitedCityId"] = invalid; File.WriteAllText(_path, old.ToJsonString()); _save.Load();
                Check(_save.CanContinue && _save.ContinueCityId == StableIds.Cities.Tianjin, "invalid or locked city falls back to Tianjin");
            }

            File.WriteAllText(_path, "broken save"); _save.Load();
            await Launch();
            Check(!_save.CanContinue && Find<Button>("Continue").Disabled && Find<Label>("Status").Text.Contains("无法读取"), "corrupt save cannot be continued");
            Check(File.Exists(_save.CorruptBackupPath), "corrupt save backup is preserved");
            await Capture("corrupt");
            Directory.CreateDirectory(_path + ".tmp");
            await NewJourney(); await Click(Find<Button>("Confirm"));
            Check(_save.HasLoadError && !_save.CanContinue && File.ReadAllText(_path) == "broken save", "failed corrupt reset preserves error state and original file");
            Directory.Delete(_path + ".tmp");
            await NewJourney();
            KeyPress(Key.Escape);
            Check(_save.HasLoadError, "cancelled corrupt reset keeps the protection");
            await NewJourney(); await Click(Find<Button>("Confirm"));
            Check(_save.CanContinue && !_save.HasLoadError, "confirmed corrupt reset creates a valid new game");

            await Launch();
            await Click(Find<Button>("Continue"));
            int requests = 0;
            _screen.BusinessRequested += (_, _) => requests++;
            var resumeButton = Find<Button>("OpenBusiness");
            resumeButton.EmitSignal(BaseButton.SignalName.Pressed);
            resumeButton.EmitSignal(BaseButton.SignalName.Pressed);
            Check(requests == 1, "repeated activation dispatches only one transition");
            _main.OpenCity(StableIds.Cities.Tianjin);
            await TravelChecks();
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
        Check(_save.ResetProgress(out _), "panel preview uses an isolated existing save");
        string before = File.ReadAllText(_path);
        await NewJourney();
        Check(_screen.ConfirmationOpen && Find<Button>("Cancel").HasFocus(), "painted confirmation defaults to cancel");
        var panel = Find<Panel>("ConfirmationPanel");
        var group = Find<Panel>("ConfirmationMessagePanel");
        var decorations = Find<Control>("ConfirmationDecorations");
        var painted = panel.GetThemeStylebox("panel");
        panel.AddThemeStyleboxOverride("panel", StartScreenTheme.Box(StartScreenTheme.Cream, 3, true));
        group.Hide(); decorations.Hide();
        await Capture("panel-before");
        panel.AddThemeStyleboxOverride("panel", painted); group.Show(); decorations.Show();
        await Capture("panel-after");
        foreach (string name in new[] { "ConfirmationTitle", "ConfirmationText", "Cancel", "Confirm" })
        {
            var control = Find<Control>(name);
            Check(panel.GetGlobalRect().Encloses(control.GetGlobalRect()), name + " stays inside the panel");
        }
        KeyPress(Key.Tab);
        Check(Find<Button>("Confirm").HasFocus(), "Tab reaches confirmation action");
        KeyPress(Key.Tab);
        Check(Find<Button>("Cancel").HasFocus(), "Tab wraps inside the modal");
        KeyPress(Key.Escape);
        Check(!_screen.ConfirmationOpen && Find<Button>("Depart").HasFocus() && File.ReadAllText(_path) == before,
            "Escape restores focus without modifying progress");
        await NewJourney();
        await Click(Find<Button>("Cancel"));
        Check(!_screen.ConfirmationOpen && File.ReadAllText(_path) == before, "cancel button remains clickable and preserves progress");
        File.WriteAllText(_path, "broken save"); _save.Load();
        await NewJourney();
        Check(Find<Label>("ConfirmationText").Text.Contains("无法读取"), "long corrupt-save message is included");
        await Capture("panel-long-message");
        KeyPress(Key.Escape);

        // Real Godot rendering at wide, tall and compact sizes, over light and dark surfaces.
        var gallery = new Control { Size = new(1920, 1080), MouseFilter = Control.MouseFilterEnum.Ignore };
        _screen.GetNode("Canvas").AddChild(gallery);
        gallery.AddChild(new ColorRect { Size = gallery.Size, Color = new Color("#332D28") });
        gallery.AddChild(new ColorRect { Size = new(960, 1080), Color = new Color("#E9DDC7") });
        for (int column = 0; column < 2; column++)
        {
            string asset = column == 0 ? "main" : "group";
            var style = GD.Load<StyleBoxTexture>($"res://resource/art/Global/PanelUI/panel-{asset}-v1.tres");
            var heading = new Label { Position = new(60 + column * 960, 30), Text = column == 0 ? "01 通用纸卡 · 九宫格" : "03 轻量分组 · 九宫格" };
            heading.AddThemeFontSizeOverride("font_size", 32);
            heading.AddThemeColorOverride("font_color", column == 0 ? new Color("#4A3024") : new Color("#FFF8E8"));
            gallery.AddChild(heading);
            var regions = new[] { new Rect2(60, 110, 840, 190), new Rect2(60, 350, 360, 520), new Rect2(480, 350, 310, 170) };
            foreach (var region in regions)
            {
                var sample = new Panel { Position = region.Position + new Vector2(column * 960, 0), Size = region.Size };
                sample.AddThemeStyleboxOverride("panel", style); gallery.AddChild(sample);
            }
        }
        await Capture("panel-nine-slice");
        gallery.GetParent().RemoveChild(gallery); gallery.QueueFree();
    }

    private async Task NewJourney()
    {
        if (_screen.ConfirmationOpen) { Find<Button>("Depart").EmitSignal(BaseButton.SignalName.Pressed); return; }
        if (_screen.Page != JourneyPage.NewJourney) { _screen.PresentHome(); await Frames(); await Click(Find<Button>("NewGame")); }
        if (_screen.Page == JourneyPage.Opening) { await Capture("opening"); await Click(Find<Button>("Skip")); }
        await Capture("new-journey");
        await Click(Find<Button>("Depart"));
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
        Check(_screen.Page == JourneyPage.Map, "node selects map summary");
        await Click(Find<Button>("EnterCity"));
        Check(_screen.Page == JourneyPage.City, "summary opens shared city hub");
        await Capture("city-tianjin");
        await Click(Find<Button>("Back"));
        await Click(Find<Button>("Back"));
        Check(_screen.Page == JourneyPage.Home, "map returns to home source");
        await Click(Find<Button>("Continue")); await Click(Find<Button>("MapTab")); await Click(Find<Button>("Back"));
        Check(_screen.Page == JourneyPage.City, "map returns to city source");
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
        await Click(Find<Button>("Skip"));
        _main.OpenCity(StableIds.Cities.Tianjin);
        Check(_screen.Page == JourneyPage.City, "second hub return never replays completion");
        _screen.PresentHome(); await Frames();
        await Click(Find<Button>("Settings")); await Capture("settings");
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        await Click(Find<Button>("Language"));
        Check(settings.Language == "en" && Find<Label>("DisplayTitle").Tr("旅途设置").ToString() == "Settings", "full game language button changes displayed text to English");
        await Capture("settings-english");
        settings.LoadPreferences();
        Check(settings.Language == "en" && _screen.Tr("新的旅程").ToString() == "New journey", "full game language preference persists");
        Check(_screen.Tr("尚未翻译的城市文案").ToString() == "尚未翻译的城市文案", "missing English translation retains source text");
        await Click(Find<Button>("Language"));
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
        await Click(Find<Button>(_width == 1280 ? "Size1280" : "Fullscreen")); await Capture("display-confirmation");
        Check(settings.DisplayPending, "display asks for confirmation");
        Check(Find<Panel>("DisplayConfirmationPanel").GetThemeStylebox("panel") is StyleBoxTexture
            && Find<Panel>("DisplayConfirmationMessagePanel").Visible
            && Find<Control>("DisplayConfirmationDecorations").Visible
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
        await Click(Find<Button>("NewGame")); await Click(Find<Button>("Skip"));
        await Click(Find<Button>("JournalMap")); await Click(Find<Button>("Back"));
        Check(_screen.Page == JourneyPage.NewJourney && _save.Data.Coins == 0, "new journal map bookmark returns without creating progress");
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
        foreach (var city in JourneyModel.Cities.Take(4))
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
        await Click(Find<Button>("NewGame")); await Click(Find<Button>("Skip"));
        Find<Button>("Depart").GrabFocus(); await Capture("focus-journey-patch");
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
        Check(Find<Button>("Continue").TooltipText.Contains("武汉"), "continue tooltip shows actual saved city");
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
        await Click(Find<Button>("NewGame")); await Capture("opening"); await Click(Find<Button>("Skip")); await Capture("new-journey");
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
        await Click(Find<Button>("MapTab")); await Capture("map-progress");
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
        await Click(Find<Button>("NewGame")); await Click(Find<Button>("Skip")); await Click(Find<Button>("Depart")); await Capture("confirmation");
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
        if (_screen.Page == JourneyPage.Splash) { await Capture("splash"); await Click(Find<Button>("Skip")); }
        if (_capture) await ToSignal(GetTree().CreateTimer(0.3), SceneTreeTimer.SignalName.Timeout);
    }

    private T Find<T>(string name) where T : Node => (T)_screen.FindChildren(name, typeof(T).Name, true, false).First(n => n is not Control c || c.IsVisibleInTree());
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++; GD.Print("PASS " + message);
    }
    private async Task Frames(int count = 2) { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
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
