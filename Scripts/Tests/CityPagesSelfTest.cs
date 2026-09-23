using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class CityPagesSelfTest : Node
{
    private StartScreen _screen = null!;
    private GameController _main = null!;
    private SaveService _save = null!;
    private int _passed, _width;
    private bool _capture;
    private string _path = "";
    public override async void _Ready()
    {
        try
        {
            var args = OS.GetCmdlineUserArgs(); _capture = args.Contains("--capture");
            _width = args.Contains("--small") ? 1280 : args.Contains("--wide") ? 1600 : 1920;
            GetWindow().Size = new(_width, _width == 1920 ? 1080 : 720);
            string dir = ProjectSettings.GlobalizePath("res://.tmp/city-pages-tests/" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(dir); _path = Path.Combine(dir, "save.json");
            _save = GetNode<SaveService>("/root/SaveService"); _save.UsePathForTests(_path); _save.ResetProgress(out _);
            GetNode<JourneySettings>("/root/JourneySettings").UsePathForTests(Path.Combine(dir, "settings.cfg"));
            InterfaceLessons.MarkAllSeen(GetNode<JourneySettings>("/root/JourneySettings"));
            _main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); AddChild(_main);
            _screen = _main.GetNode<StartScreen>("UI/StartScreen");
            await Frames();
            if (args.Contains("--upgrade-feedback"))
            {
                await CheckUpgradeFeedback();
                GD.Print($"UPGRADE_FEEDBACK_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--fryer-preview"))
            {
                await CaptureFryerPreview();
                GD.Print($"FRYER_PREVIEW_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--upgrade-experience"))
            {
                await CheckUpgradeExperience();
                GD.Print($"UPGRADE_EXPERIENCE_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--tabs-only"))
            {
                await ReviewCityTabs();
                GD.Print($"CITY_TABS_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--completion-overlay-only"))
            {
                _save.QueueJourneyCompletion(StableIds.Cities.Tianjin);
                _main.OpenCity(StableIds.Cities.Tianjin);
                Check(_screen.Page == JourneyPage.Completion, "chapter completion opens after returning from business");
                Check(_main.GetNode<Control>("UI/MorningHub").Visible && !_screen.GetNode<TextureRect>("Canvas/Background").Visible,
                    "completion keeps the finished city workbench behind the book");
                GD.Print($"COMPLETION_OVERLAY_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--note-review"))
            {
                await ReviewBusinessNote();
                GD.Print($"CITY_NOTE_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--ledger-review"))
            {
                await ReviewWuhanLedger();
                GD.Print($"CITY_LEDGER_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--ledger-food-board-only"))
            {
                await ReviewLedgerFoodBoard();
                GD.Print($"LEDGER_FOOD_BOARD_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--ledger-chrome-only"))
            {
                await ReviewLedgerChrome();
                GD.Print($"CITY_LEDGER_CHROME_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--map-only"))
            {
                GetNode<JourneySettings>("/root/JourneySettings").SetLanguage(args.Contains("--english") ? "en" : "zh_CN");
                await ReviewWorldMap();
                GD.Print($"WORLD_MAP_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            if (args.Contains("--upgrades-only"))
            {
                await CheckSharedUpgradePage();
                GD.Print($"CITY_UPGRADE_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
            }
            _main.OpenCity(StableIds.Cities.Tianjin);
            _screen.PresentMap(); await Capture("map-locked");
            _main.OpenCity(StableIds.Cities.Tianjin);
            _screen.PresentLedger(); await Frames();
            Click("Date15"); Check(Find<Button>("StartSelectedDay").Disabled, "locked day only previews");
            Check(Find<Label>("BestRevenue").Text.Contains("14"), "locked date shows predecessor");
            await Capture("ledger-locked");
            _screen.PresentUpgrades(); Check(Find<Button>("UpgradeEquipment").Disabled, "locked upgrade disabled"); await Capture("upgrades-locked");
            _save.Data.Coins = 453;
            var catalog = GetNode<DataCatalog>("/root/DataCatalog"); var yz = YangzhouCatalog.Load();
            foreach (var city in JourneyModel.Cities)
            {
                if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
                var p = _save.Data.GetCity(city.Id); p.HighestUnlockedDay = city.Days;
                for (int day = 1; day <= city.Days; day++) p.DayBestRecords[day] = new() { TotalRevenue = 140, Satisfaction = 38, PerfectOrders = 7 };
                foreach (var id in p.EquipmentLevels.Keys.ToArray()) p.EquipmentLevels[id] = 2;
                if (city.Id != StableIds.Cities.Yangzhou)
                    foreach (var config in catalog.GetDays(city.Id).Values) foreach (var id in config.CompletionUnlocks) if (!p.UnlockedContentIds.Contains(id)) p.UnlockedContentIds.Add(id);
            }
            _save.Data.PurchasedIngredientStationLevel = 3; _save.TrySave(out _);
            var model = new CityPageModel(catalog, _save, yz);
            CheckOverviewModel(model);
            _screen.PresentMap(); await Frames();
            for (int i = 0; i < JourneyModel.Cities.Length; i++)
            {
                var city = JourneyModel.Cities[i];
                Click("Node" + i); await Frames();
                Check(!_screen.Visible && _screen.SelectedCityId == city.Id && _screen.SelectedDay == city.Days, "unlocked node starts latest day " + city.Name);
                _main.OpenCity(city.Id); _screen.PresentMap(); await Frames();
                CheckMapLayout();
                await Capture("map-card-" + city.Name);
            }
            foreach (var city in JourneyModel.Cities)
            {
                string before = File.ReadAllText(_path);
                Check(_main.OpenCity(city.Id), "open " + city.Name); await Frames();
                Check(_screen.Visible && _screen.Page == JourneyPage.City, "shared hub visible " + city.Name);
                Rect2 rect = Find<TextureRect>("SharedBook").GetGlobalRect();
                CheckBookTheme(city.Id);
                var hubMaterial = Find<TextureRect>("SharedBook").Material;
                await Capture(city.Name + "-hub");
                Click("LedgerTab"); await Frames();
                Check(Find<TextureRect>("SharedBook").GetGlobalRect() == rect, "ledger book geometry matches " + city.Name);
                CheckBookTheme(city.Id);
                Check(city.Id == StableIds.Cities.Wuhan
                    ? Find<TextureRect>("SharedBook").Material is ShaderMaterial
                    : Find<TextureRect>("SharedBook").Material is null, "ledger palette scope " + city.Name);
                Check(!_screen.FindChildren("Back", "Button", true, false).Any()
                    && !_screen.FindChildren("PageTitle", "Label", true, false).Any(), "ledger omits top return and title " + city.Name);
                var ledgerStart = Find<Button>("StartSelectedDay");
                var plate = ledgerStart.GetNode<NinePatchRect>("StartSelectedDayButtonPlate");
                Check(plate.Texture is AtlasTexture plateAtlas
                    && plateAtlas.Atlas.ResourcePath.EndsWith("首页地图按钮底板.png"), "ledger action uses supplied map button plate " + city.Name);
                Check(ledgerStart.GetGlobalRect().GetCenter().X > Find<TextureRect>("SharedBook").GetGlobalRect().GetCenter().X,
                    "ledger action stays on right book page " + city.Name);
                Check(_screen.SelectedDay == city.Days, "ledger selects latest " + city.Name);
                Check(Find<Label>("BestRevenue").Text == "140 金币", "ledger record " + city.Name);
                Check(Find<TextureRect>("LedgerFoodBoard").Texture?.ResourcePath.EndsWith("UpgradeUI/设备涂鸦背景-v1.png") == true,
                    "ledger food board uses supplied artwork " + city.Name);
                Check(Find<TextureRect>("FinalDayCrown") is not null && Find<TextureRect>("PerfectStamp") is not null, "final day and perfect badges " + city.Name);
                Check(((AtlasTexture)Find<Button>("Date1").GetNode<TextureRect>("SatisfactionFace").Texture).Atlas.ResourcePath.EndsWith("棕平脸.png"), "38 percent uses neutral face " + city.Name);
                Check(_screen.FindChildren("Date*", "Button", true, false).Count == city.Days, "calendar day count " + city.Name);
                var dateMetrics = Find<Button>("Date1").GetNode<Label>("Record");
                Check(dateMetrics.Position.Y + dateMetrics.GetMinimumSize().Y <= Find<Button>("Date1").Size.Y - 4, "date metrics fit card height " + city.Name);
                await Capture(city.Name + "-ledger");
                Click("UpgradeTab"); await Frames();
                Check(Find<TextureRect>("SharedBook").GetGlobalRect() == rect, "upgrade book geometry matches " + city.Name);
                CheckBookTheme(city.Id);
                Check(_screen.FindChildren("Select_*", "Button", true, false).Count == (city.Id == StableIds.Cities.Yangzhou ? 2 : 3), "equipment count " + city.Name);
                Check(_screen.FindChildren("UpgradeEquipment", "Button", true, false).Count == 1, "single purchase action " + city.Name);
                var equipment = model.Equipment(city.Id);
                Check(equipment.All(e => e.Effects.Count > 0), "structured effects exist " + city.Name);
                if (city.Id == StableIds.Cities.Wuhan) {
                    Click("Select_ingredient_station");
                    Check(Find<Button>("UpgradeEquipment").Disabled && equipment.Last().TargetLevel is null, "fixed Wuhan station cannot upgrade");
                    await Capture("wuhan-fixed-station"); Click("Select_noodle_cooker");
                }
                foreach (var label in _screen.FindChild("UpgradeView", true, false).Descendants<Label>().Where(l => l.GetParent() is not Container))
                    Check(label.Position.Y + label.Size.Y <= ((Control)label.GetParent()).Size.Y + 1, "fixed label fits " + city.Name + "/" + label.Name);
                await Capture(city.Name + "-upgrades");
                Check(File.ReadAllText(_path) == before, "browsing never writes " + city.Name);
                Check(_screen.Page == JourneyPage.Upgrades && !_screen.Descendants<Button>().Any(b => b.Name == "MapTab"), "upgrade page has no map bookmark " + city.Name);
                Click("Settings"); await Frames();
                var settingsBooks = _screen.GetNode<Control>("Canvas/Modal").GetChildren().OfType<TextureRect>().ToArray();
                Check(settingsBooks.Length > 0 && settingsBooks.All(t => t.Material is null), "settings book remains original " + city.Name);
                Click("Close"); _screen.PresentCity(city.Id); await Frames(); CheckBookTheme(city.Id);
            }
            _main.OpenCity(StableIds.Cities.Tianjin); _screen.PresentUpgrades();
            Directory.CreateDirectory(_path + ".tmp"); Click("UpgradeEquipment");
            Check(_save.Data.Coins == 453 && _save.Data.PurchasedStoveLevel == 2, "failed purchase rolls back coins and equipment");
            Check(Find<Label>("Status").Text.Contains("保存失败"), "purchase failure is visible");
            Directory.Delete(_path + ".tmp"); Click("UpgradeEquipment");
            Check(_save.Data.PurchasedStoveLevel == 3 && _save.Data.Coins == 153, "purchase uses real upgrade price");
            Check(_save.ContinueCityId == StableIds.Cities.Tianjin, "purchase does not change resume");
            Check(Find<Button>("UpgradeEquipment").Disabled, "max level disabled");
            Click("Select_fryer"); Check(Find<Button>("UpgradeEquipment").Disabled, "insufficient coins disabled");
            await Capture("upgrades-purchased");
            foreach (var city in JourneyModel.Cities.Skip(1))
            {
                _save.Data.Coins = 2000; _save.TrySave(out _); _main.OpenCity(city.Id); _screen.PresentUpgrades();
                var offer = model.Equipment(city.Id).First(e => e.CanBuy);
                int slot = Array.FindIndex(model.Equipment(city.Id), e => e.Id == offer.Id);
                Click("Select_" + offer.Id);
                Check(_save.Data.Coins == 2000, "selecting equipment never buys " + city.Name);
                Click("UpgradeEquipment");
                Check(((EquipmentUpgradeView)_screen.FindChild("UpgradeView", true, false)).SelectedId == offer.Id, "purchase preserves selection " + city.Name);
                Check(_save.Data.GetCity(city.Id).EquipmentLevels[offer.Id] == offer.Level + 1 && _save.Data.Coins == 2000 - offer.Price, "purchase routes correct city and price " + city.Name);
                Check(_save.ContinueCityId == StableIds.Cities.Tianjin, "other-city upgrade preserves resume " + city.Name);
            }
            _save.Data.Coins = 153; _save.TrySave(out _);
            _main.OpenCity(StableIds.Cities.Wuhan);
            Directory.CreateDirectory(_path + ".tmp");
            Check(!_main.StartCityBusiness(StableIds.Cities.Wuhan, 1), "location write failure prevents starting");
            Check(_screen.Visible && _save.ContinueCityId == StableIds.Cities.Tianjin, "failed start preserves resume and hub");
            Check(_main.GetNode<DayController>("DayController").State != DayState.Running, "failed start does not run timer");
            Directory.Delete(_path + ".tmp");
            foreach (var city in JourneyModel.Cities)
            {
                _main.OpenCity(city.Id);
                Check(!_main.StartCityBusiness(city.Id, city.Days + 1), "invalid date rejected " + city.Name);
                Check(_main.StartCityBusiness(city.Id, 1), "start " + city.Name);
                Check(!_screen.Visible && _save.ContinueCityId == city.Id, "actual business updates resume " + city.Name);
                _main.OpenCity(city.Id);
            }
            _main.OpenCity(StableIds.Cities.Tianjin);
            _save.Data.Tianjin.DayBestRecords[15].TotalRevenue = int.MaxValue; _screen.PresentLedger();
            var maxRecord = Find<Button>("Date15").GetNode<Label>("Record");
            Check(maxRecord.GetThemeFont("font").GetStringSize(maxRecord.Text.Split('\n')[0], HorizontalAlignment.Left, -1, maxRecord.GetThemeFontSize("font_size")).X <= maxRecord.Size.X, "largest saved revenue fits date card");
            var big = Find<Label>("BestRevenue");
            Check(big.GetThemeFont("font").GetStringSize(big.Text, HorizontalAlignment.Left, -1, big.GetThemeFontSize("font_size")).X <= big.Size.X, "largest saved revenue fits detail");
            Check(!big.GetGlobalRect().Intersects(Find<TextureRect>("PerfectStamp").GetGlobalRect()), "largest revenue keeps clear of stamp");
            await Capture("ledger-large");
            _save.Data.Tianjin.DayBestRecords[15].TotalRevenue = 140;
            foreach (var sample in new (double? Value, string Art)[] { (null, "灰脸"), (0, "红难过"), (29.99, "红难过"), (30, "棕平脸"), (59.99, "棕平脸"), (60, "绿笑脸"), (100, "绿笑脸") })
                Check(StartScreen.LedgerMoodArt(sample.Value) == sample.Art, "mood boundary " + sample.Value);
            _save.Data.Tianjin.DayBestRecords[15].PerfectOrders = 0; _screen.PresentLedger();
            Check(_screen.FindChildren("PerfectStamp", "TextureRect", true, false).Count == 0, "zero perfect has no stamp");
            Click("Date1");
            Check(_screen.FindChildren("FinalDayCrown", "TextureRect", true, false).Count == 0, "ordinary day has no crown");
            Check(_screen.Page == JourneyPage.Ledger && _screen.SelectedDay == 1 && !_screen.Descendants<Button>().Any(b => b.Name == "MapTab"), "ledger retains selected date without map bookmark");
            _screen.PresentHome(); Click("Continue");
            Check(_screen.Page == JourneyPage.Map, "continue opens map"); await Capture("continue-map");
            _save.Data.LastVisitedCityId = StableIds.Cities.Tianjin; _save.TrySave(out _);
            _screen.PresentMap(); await Capture("map");
            foreach (var city in JourneyModel.Cities) { var p = _save.Data.GetCity(city.Id); p.Completed = true; p.BestStars = 3; }
            _screen.PresentMap(); await Capture("map-complete");
            _save.QueueJourneyCompletion(StableIds.Cities.Tianjin); _main.OpenCity(StableIds.Cities.Tianjin);
            Check(_screen.Page == JourneyPage.Completion, "completion presentation retained");
            Check(_main.GetNode<Control>("UI/MorningHub").Visible && !_screen.GetNode<TextureRect>("Canvas/Background").Visible,
                "completion keeps the finished city's workbench behind the book");
            Check(Find<TextureRect>("SharedBook").GetRect() == StartScreen.BookBounds, "completion uses same book bounds");
            Check(Find<TextureRect>("SharedBook").Material is null, "completion book remains original");
            await Capture("completion"); Click("Skip"); Check(_screen.SelectedCityId == StableIds.Cities.Wuhan, "completion goes to next city");
            _screen.PresentLedger();
            Check(!_screen.FindChildren("ResetLedgerProgress", "Button", true, false).Any(), "city ledgers have no reset entry");
            File.WriteAllText(_path, "broken save"); _save.Load(); _screen.PresentCity(StableIds.Cities.Tianjin); _screen.PresentLedger();
            Check(Find<Button>("StartSelectedDay").Disabled, "corrupt save cannot start"); await Capture("ledger-corrupt");
            Check(Find<Label>("BestRevenue").Text.Contains("首页"), "corrupt save directs player to home management");
            GD.Print($"CITY_PAGES_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print("CITY_PAGES_TEST_RESULT failed=1"); GetTree().Quit(1); }
    }
    private async Task ReviewBusinessNote()
    {
        var model = new CityPageModel(GetNode<DataCatalog>("/root/DataCatalog"), _save, YangzhouCatalog.Load());
        CheckOverviewModel(model);
        foreach (var city in JourneyModel.Cities)
        {
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            var progress = _save.Data.GetCity(city.Id);
            foreach (string state in new[] { "first", "unlocks", "long-title", "complete" })
            {
                progress.HighestUnlockedDay = state == "first" ? 1 : state == "unlocks" ? 3 : state == "complete" ? city.Days :
                    Enumerable.Range(1, city.Days).OrderByDescending(d => model.DayTitle(city.Id, d).Length).First();
                progress.Completed = state == "complete";
                progress.DayBestRecords.Clear();
                for (int day = 1; day < progress.HighestUnlockedDay; day++) progress.DayBestRecords[day] = new() { TotalRevenue = 100 + day * 10 };
                if (progress.Completed) progress.DayBestRecords[city.Days] = new() { TotalRevenue = int.MaxValue };
                _save.Data.Coins = state == "first" ? 0 : int.MaxValue;
                if (progress.Completed && city.Id == StableIds.Cities.Yangzhou)
                    progress.UnlockedCollectibleIds.Add("collectible:yangzhou_crab_soup_bun");
                _screen.PresentCity(city.Id); await Frames();
                var note = Find<Control>("BusinessNote");
                CheckBookTheme(city.Id);
                Check(note.Size == new Vector2(460, 380) && note.GetChildCount() == 5, "five rows stay within note " + city.Name + state);
                Check(_screen.FindChildren("PageTitle", "Label", true, false).Count == 0
                    && _screen.FindChildren("CityTitle", "Label", true, false).Count == 0
                    && _screen.FindChildren("Food0", "Label", true, false).Count == 0, "old heading and food list removed");
                Check(Find<Label>("PostcardCity").Text == city.Name, "postcard identifies city");
                Check(Find<Label>("DayTitle").Text == $"第{progress.HighestUnlockedDay}天 {model.DayTitle(city.Id, progress.HighestUnlockedDay)}", "day ribbon matches business destination");
                if (city.Id == StableIds.Cities.Wuhan)
                {
                    Check(IsWuhanPalette(Find<TextureRect>("DayRibbon")), "Wuhan day ribbon uses city palette");
                    Check(Find<Button>("OpenBusiness").GetChildren().OfType<TextureRect>().Any(IsWuhanPalette), "Wuhan business button uses city palette");
                    Check(note.FindChildren("*Icon", "TextureRect", true, false).OfType<TextureRect>().Count() == 5
                        && note.FindChildren("*Icon", "TextureRect", true, false).OfType<TextureRect>().All(IsWuhanPalette), "Wuhan five note icons use city palette");
                    Check(_screen.FindChildren("LedgerTab", "Button", true, false).Single().GetChildren().OfType<TextureRect>().Any(IsWuhanPalette)
                        && _screen.FindChildren("UpgradeTab", "Button", true, false).Single().GetChildren().OfType<TextureRect>().Any(IsWuhanPalette), "Wuhan page tabs use city palette");
                }
                foreach (var node in note.FindChildren("*", "Label", true, false))
                {
                    var label = (Label)node;
                    Check(label.Size.X <= note.Size.X, "label fits note width " + label.Name);
                    Check(label.GetLineCount() <= label.GetVisibleLineCount(), "all lines visible " + label.Name);
                    Check(label.Position.Y + label.Size.Y <= ((Control)label.GetParent()).Size.Y + 1, "row text fits height " + label.Name);
                }
                bool embeddedChallenge = city.Id is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan;
                if (embeddedChallenge)
                {
                    Check(Find<Label>("ProgressLabel").Text == "每日挑战" && Find<Label>("Progress").Text.Contains("奖励"),
                        "daily challenge occupies the progress row " + city.Name + state);
                    Check(!_screen.FindChildren("DailyChallengePreview", "Label", true, false).Any()
                        && !_screen.FindChildren("JourneyGoals", "Control", true, false).Any(),
                        "no duplicate daily challenge below card " + city.Name + state);
                }
                else foreach (var node in Find<Control>("JourneyGoals").FindChildren("*", "Label", true, false))
                {
                    var label = (Label)node;
                    Check(label.GetLineCount() <= label.GetVisibleLineCount(), "goal and collection lines visible " + label.Name);
                }
                Check(Find<Label>("Coins").GetLineCount() == 1, "coin amount fits one row");
                var button = Find<Button>("OpenBusiness");
                Check(!button.Disabled && button.HasFocus(), "primary action available and focused");
                Check(button.Text == "继续营业" && button.Size == new Vector2(360, 78)
                    && button.Position.X >= StartScreen.BookBounds.GetCenter().X
                    && button.Position.X + button.Size.X <= StartScreen.BookBounds.End.X
                    && button.Position.Y == (embeddedChallenge ? 752 : 862)
                    && button.Position.Y + button.Size.Y <= StartScreen.BookBounds.End.Y,
                    "primary action is compact and contained on right page " + city.Name + state);
                var continueTab = Find<Button>("ContinueTab");
                var continueArt = continueTab.GetChildren().OfType<TextureRect>().Single();
                Check(continueTab.GetNode<Label>("Caption").Text == "继续\n营业"
                    && continueArt.Texture is AtlasTexture continueAtlas
                    && continueAtlas.Atlas.ResourcePath.EndsWith("书页标签-继续旅程.png")
                    && continueArt.Material is null,
                    "continue tab uses supplied journey artwork without train overlay");
                var ledgerArt = Find<Button>("LedgerTab").GetChildren().OfType<TextureRect>().Single();
                Check(!ReferenceEquals(continueArt.Texture, ledgerArt.Texture),
                    "three book tabs keep distinguishable colors");
                string before = File.ReadAllText(_path);
                _screen.RefreshCityPage(); await Frames();
                Check(File.ReadAllText(_path) == before, "overview refresh leaves save untouched");
                await Capture(city.Name + "-note-" + state);
            }
            int requests = 0; string requestedCity = ""; int requestedDay = 0;
            void ObserveBusiness(string id, int day) { requests++; requestedCity = id; requestedDay = day; }
            _screen.BusinessRequested += ObserveBusiness;
            var open = Find<Button>("OpenBusiness");
            Vector2 point = open.GetGlobalTransformWithCanvas() * (open.Size / 2);
            GetViewport().PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point }, true);
            GetViewport().PushInput(new InputEventMouseButton { Position = point, GlobalPosition = point, ButtonIndex = MouseButton.Left, Pressed = true }, true);
            GetViewport().PushInput(new InputEventMouseButton { Position = point, GlobalPosition = point, ButtonIndex = MouseButton.Left, Pressed = false }, true);
            await Frames();
            Check(requests == 1 && requestedCity == city.Id && requestedDay == city.Days, "central button click starts displayed city/day " + city.Name);
            open.EmitSignal(BaseButton.SignalName.Pressed);
            Check(requests == 1, "duplicate business activation ignored " + city.Name);
            _screen.BusinessRequested -= ObserveBusiness;
            _main.OpenCity(city.Id);
        }
    }
    private async Task ReviewWuhanLedger()
    {
        var progress = _save.Data.GetCity(StableIds.Cities.Wuhan);
        if (!_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan)) _save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
        progress.HighestUnlockedDay = 1;
        progress.DayBestRecords.Clear();
        _main.OpenCity(StableIds.Cities.Wuhan); await Frames();
        _screen.PresentLedger(); await Frames();
        Check(_screen.Page == JourneyPage.Ledger && _screen.SelectedCityId == StableIds.Cities.Wuhan, "Wuhan ledger opens from its city page");
        CheckBookTheme(StableIds.Cities.Wuhan);
        var selectedDate = Find<Button>("Date1").GetChildren().OfType<Panel>().Single().GetThemeStylebox("panel") as StyleBoxFlat;
        Check(selectedDate is not null && selectedDate.BgColor == CitySettlementTheme.Paper.Lerp(CitySettlementTheme.For("wuhan").Primary, .32f), "Wuhan ledger date card uses city palette");
        var start = Find<Button>("StartSelectedDay");
        var plate = start.GetNode<NinePatchRect>("StartSelectedDayButtonPlate");
        Check(plate.Texture is AtlasTexture atlas && atlas.Atlas.ResourcePath.EndsWith("首页地图按钮底板.png"), "Wuhan ledger action uses supplied map button plate");
        Check(!_screen.FindChildren("Back", "Button", true, false).Any()
            && !_screen.FindChildren("PageTitle", "Label", true, false).Any(), "Wuhan ledger omits top return and title");
        await Capture("武汉-ledger-review");
    }
    private async Task ReviewLedgerFoodBoard()
    {
        _main.OpenCity(StableIds.Cities.Tianjin); await Frames();
        _screen.PresentLedger(); await Frames();
        var board = Find<TextureRect>("LedgerFoodBoard");
        Check(board.Texture?.ResourcePath.EndsWith("UpgradeUI/设备涂鸦背景-v1.png") == true,
            "ledger food board uses the supplied artwork");
        Check(board.GetGlobalRect() == new Rect2(1005, 372, 500, 210),
            "ledger food board fills the right-side food presentation area");
        Check(board.MouseFilter == Control.MouseFilterEnum.Ignore,
            "ledger food board does not block the ledger controls");
        await Capture("ledger-food-board");
    }
    private async Task ReviewLedgerChrome()
    {
        foreach (var city in JourneyModel.Cities)
        {
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            _save.Data.GetCity(city.Id).HighestUnlockedDay = city.Days;
            _screen.PresentCity(city.Id); await Frames();
            _screen.PresentLedger(); await Frames();
            Check(!_screen.FindChildren("Back", "Button", true, false).Any()
                && !_screen.FindChildren("PageTitle", "Label", true, false).Any(), "ledger omits top return and title " + city.Name);
            var start = Find<Button>("StartSelectedDay");
            var plate = start.GetNode<NinePatchRect>("StartSelectedDayButtonPlate");
            Check(plate.Texture is AtlasTexture atlas && atlas.Atlas.ResourcePath.EndsWith("首页地图按钮底板.png"),
                "ledger action uses supplied map button plate " + city.Name);
            Check(start.GetGlobalRect().GetCenter().X > Find<TextureRect>("SharedBook").GetGlobalRect().GetCenter().X,
                "ledger action stays on right book page " + city.Name);
            Check(start.Position.Y > Find<Label>("BestMetrics").Position.Y + Find<Label>("BestMetrics").Size.Y
                && start.Position.Y + start.Size.Y <= 845, "ledger action clears record labels and page edge " + city.Name);
            await Capture(city.Name + "-ledger-chrome");
        }
    }
    private void CheckOverviewModel(CityPageModel model)
    {
        var city = _save.Data.GetCity(StableIds.Cities.Tianjin);
        int highest = city.HighestUnlockedDay;
        var records = city.DayBestRecords;
        city.DayBestRecords = new(); city.HighestUnlockedDay = 1;
        var first = model.Overview(StableIds.Cities.Tianjin, 1);
        Check(first.CompletedDays == 0 && first.BestDay is null && first.BestRevenue is null, "new city has no invented record");
        city.HighestUnlockedDay = 5;
        city.DayBestRecords[2] = new() { TotalRevenue = 453 };
        city.DayBestRecords[4] = new() { TotalRevenue = 453 };
        city.DayBestRecords[16] = new() { TotalRevenue = int.MaxValue };
        var ready = model.Overview(StableIds.Cities.Tianjin, 1);
        Check(ready.Day == 5 && ready.CompletedDays == 2 && ready.BestDay == 2 && ready.BestRevenue == 453, "valid records counted; income ties use earlier day");
        Check(ready.LatestUnlocks.Select(u => u.Name).SequenceEqual(new[] { "油条" }), "next open day exposes oil sticks before business starts");
        city.HighestUnlockedDay = 3;
        var batch = model.Overview(StableIds.Cities.Tianjin, 1).LatestUnlocks;
        Check(batch.Count > 1 && batch.Select(u => u.Id).Distinct().Count() == batch.Count && batch.All(u => !u.Id.StartsWith("equipment:")), "same-day food and ingredient batch is distinct and excludes upgrades");
        city.HighestUnlockedDay = highest; city.DayBestRecords = records;
        foreach (var destination in JourneyModel.Cities)
        {
            var p = _save.Data.GetCity(destination.Id); int old = p.HighestUnlockedDay;
            p.HighestUnlockedDay = destination.Days;
            var overview = model.Overview(destination.Id, 1);
            Check(overview.LatestUnlocks.Count > 0 && overview.TotalDays == destination.Days, "overview uses city content " + destination.Name);
            p.HighestUnlockedDay = old;
        }
    }
    private async Task ReviewCityTabs()
    {
        _save.Data.GetCity(StableIds.Cities.Tianjin).HighestUnlockedDay = 2;
        Check(_main.OpenCity(StableIds.Cities.Tianjin), "open city tab review"); await Frames();
        Check(_screen.Page == JourneyPage.City, "city tab review shows overview");
        var button = Find<Button>("OpenBusiness");
        Check(button.Text == "继续营业" && button.Size == new Vector2(360, 78)
            && button.Position.X >= StartScreen.BookBounds.GetCenter().X
            && button.Position.X + button.Size.X <= StartScreen.BookBounds.End.X
            && button.Position.Y == 752 && button.Position.Y + button.Size.Y <= StartScreen.BookBounds.End.Y,
            "Tianjin action sits below the five-row card");
        Check(Find<Label>("ProgressLabel").Text == "每日挑战" && Find<Label>("Progress").Text.Contains("奖励")
            && !_screen.FindChildren("DailyChallengePreview", "Label", true, false).Any(),
            "Tianjin embeds daily challenge without duplicate preview");
        var continueTab = Find<Button>("ContinueTab");
        var continueArt = continueTab.GetChildren().OfType<TextureRect>().Single();
        Check(continueTab.GetNode<Label>("Caption").Text == "继续\n营业"
            && continueArt.Texture is AtlasTexture continueAtlas
            && continueAtlas.Atlas.ResourcePath.EndsWith("书页标签-继续旅程.png")
            && continueArt.Material is null,
            "continue tab uses supplied journey artwork without train overlay");
        var ledgerArt = Find<Button>("LedgerTab").GetChildren().OfType<TextureRect>().Single();
        Check(!ReferenceEquals(continueArt.Texture, ledgerArt.Texture),
            "three book tabs keep distinguishable colors");
        // Capture the settled page, not the temporary book-spread transition frame.
        await ToSignal(GetTree().CreateTimer(.8), SceneTreeTimer.SignalName.Timeout); await Frames();
        await Capture("city-tabs-tianjin");
        if (!_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan)) _save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
        _save.Data.GetCity(StableIds.Cities.Wuhan).HighestUnlockedDay = 2;
        _screen.PresentCity(StableIds.Cities.Wuhan); await Frames();
        Check(Find<Button>("OpenBusiness").Position.Y == 752 && Find<Label>("ProgressLabel").Text == "每日挑战"
            && Find<Label>("Progress").Text.Contains("奖励") && !_screen.FindChildren("JourneyGoals", "Control", true, false).Any(),
            "Wuhan embeds daily challenge and action below card");
        await ToSignal(GetTree().CreateTimer(.8), SceneTreeTimer.SignalName.Timeout); await Frames();
        await Capture("city-tabs-wuhan");
    }
    private void CheckBookTheme(string city)
    {
        if (_screen.Page == JourneyPage.Ledger)
        {
            var ledger = Find<TextureRect>("SharedBook");
            Check(((AtlasTexture)ledger.Texture).Atlas.ResourcePath.EndsWith("旅行手账双页母版-经营手账.png"), "ledger uses supplied master " + city);
            if (city == StableIds.Cities.Wuhan)
            {
                var ledgerMaterial = ledger.Material as ShaderMaterial;
                Check(ledgerMaterial is not null && ledgerMaterial.GetShaderParameter("primary").AsColor() == CitySettlementTheme.For("wuhan").Primary
                    && ledgerMaterial.GetShaderParameter("secondary").AsColor() == CitySettlementTheme.For("wuhan").Secondary, "Wuhan ledger uses city palette");
            }
            else Check(ledger.Material is null, "other ledgers retain supplied colors " + city);
            return;
        }
        Check(_screen.FindChildren("DeveloperMenu", "Button", true, false).Count == 0, "developer menu removed " + city);
        var book = Find<TextureRect>("SharedBook");
        var atlas = (AtlasTexture)book.Texture;
        Check(atlas.Atlas.ResourcePath.EndsWith(_screen.Page == JourneyPage.City ? "旅行手账双页母版-带便签.png" : "旅行手账双页母版.png"), "only city overview uses note master");
        if (city is not (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan or StableIds.Cities.Xian))
        {
            Check(book.Material is null, "unthemed city retains original book " + city);
            return;
        }
        var material = book.Material as ShaderMaterial;
        Check(material is not null, "city book uses shader " + city);
        var theme = CitySettlementTheme.For(city switch {
            StableIds.Cities.Wuhan => "wuhan", StableIds.Cities.Xian => "xian", _ => "tianjin"
        });
        Check(material!.GetShaderParameter("cover_color").AsColor() == theme.Primary
            && material.GetShaderParameter("ornament_color").AsColor() == theme.Secondary, "book palette matches city " + city);
        if (city == StableIds.Cities.Wuhan && _screen.Page == JourneyPage.City)
            Check(material.GetShaderParameter("note_enabled").AsSingle() == 1f
                && material.GetShaderParameter("note_color").AsColor() == CitySettlementTheme.Paper.Lerp(theme.Secondary, .48f), "Wuhan information slip uses city palette");
        var mask = material.GetShaderParameter("region_mask").AsGodotObject() as Texture2D;
        Check(mask!.ResourcePath.EndsWith(_screen.Page == JourneyPage.City ? "旅行手账双页分区遮罩-带便签.png" : "旅行手账双页分区遮罩.png"), "mask matches page artwork");
        var source = ((AtlasTexture)book.Texture).Atlas;
        Check(mask is not null && mask.GetSize() == source.GetSize(), "mask uses original atlas coordinates " + city);
    }
    private T Find<T>(string name) where T : Node => (T)_screen.FindChildren(name, typeof(T).Name, true, false).First(n => n is not Control c || c.IsVisibleInTree());
    private static bool IsWuhanPalette(CanvasItem item) => item.Material is ShaderMaterial material
        && material.GetShaderParameter("primary").AsColor() == CitySettlementTheme.For("wuhan").Primary
        && material.GetShaderParameter("secondary").AsColor() == CitySettlementTheme.For("wuhan").Secondary;
    private void Click(string name) => Find<Button>(name).EmitSignal(BaseButton.SignalName.Pressed);
    private void Check(bool ok, string message) { if (!ok) throw new InvalidOperationException(message); _passed++; GD.Print("PASS " + message); }
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Capture(string name)
    {
        if (!_capture) return;
        await ToSignal(GetTree().CreateTimer(.35), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string dir = ProjectSettings.GlobalizePath($"res://.tmp/city-pages-review/{_width}"); Directory.CreateDirectory(dir);
        using var image = GetViewport().GetTexture().GetImage(); image.SavePng(Path.Combine(dir, name + ".png"));
    }
}
