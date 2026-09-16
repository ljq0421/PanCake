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
            _main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); AddChild(_main);
            _screen = _main.GetNode<StartScreen>("UI/StartScreen");
            await Frames();
            if (args.Contains("--note-review"))
            {
                await ReviewBusinessNote();
                GD.Print($"CITY_NOTE_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit(); return;
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
            _screen.PresentMap(); await Frames();
            for (int i = 0; i < JourneyModel.Cities.Length; i++)
            {
                var city = JourneyModel.Cities[i];
                Click("Node" + i); await Frames();
                var mapCard = Find<Panel>("MapJourneyCard");
                Check(mapCard.GetThemeStylebox("panel") is StyleBoxTexture, "map uses illustrated journey card " + city.Name);
                Check(Find<Control>("MapJourneyTitlePlate").IsVisibleInTree(), "map keeps title plate " + city.Name);
                Check(Find<Label>("SummaryCity").Text == city.Name + "早餐铺", "map card selects city " + city.Name);
                Check(Find<Button>("EnterCity").GetParent() == mapCard, "map action stays inside card " + city.Name);
                if (city.Art is null)
                    Check(Find<TextureRect>("MapGenericPostcard").IsVisibleInTree(), "map uses shared postcard placeholder " + city.Name);
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
                Check(Find<TextureRect>("SharedBook").Material is null, "ledger preserves supplied art colors " + city.Name);
                Check(_screen.SelectedDay == city.Days, "ledger selects latest " + city.Name);
                Check(Find<Label>("BestRevenue").Text == "140 金币", "ledger record " + city.Name);
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
                Click("MapTab"); await Frames(); Click("Back");
                Check(_screen.Page == JourneyPage.Upgrades && _screen.SelectedCityId == city.Id, "map restores source city and tab " + city.Name);
                Click("Home"); Click("Settings"); await Frames();
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
            Click("MapTab"); Click("Back");
            Check(_screen.Page == JourneyPage.Ledger && _screen.SelectedDay == 1, "map restores selected ledger date");
            _screen.PresentHome(); Click("NewGame"); Click("Skip");
            Check(Find<TextureRect>("SharedBook").GetRect() == StartScreen.BookBounds, "new journey shares book geometry"); await Capture("new-journey");
            Check(Find<TextureRect>("SharedBook").Material is null, "new journey book remains original");
            _save.Data.LastVisitedCityId = StableIds.Cities.Tianjin; _save.TrySave(out _);
            _screen.PresentMap(); await Capture("map");
            foreach (var city in JourneyModel.Cities) { var p = _save.Data.GetCity(city.Id); p.Completed = true; p.BestStars = 3; }
            _screen.PresentMap(); await Capture("map-complete");
            _save.QueueJourneyCompletion(StableIds.Cities.Tianjin); _main.OpenCity(StableIds.Cities.Tianjin);
            Check(_screen.Page == JourneyPage.Completion, "completion presentation retained");
            Check(Find<TextureRect>("SharedBook").GetRect() == StartScreen.BookBounds, "completion uses same book bounds");
            Check(Find<TextureRect>("SharedBook").Material is null, "completion book remains original");
            await Capture("completion"); Click("Skip"); Check(_screen.SelectedCityId == StableIds.Cities.Wuhan, "completion goes to next city");
            _screen.PresentLedger(); Click("ResetLedgerProgress");
            var resetPanel = Find<Panel>("ResetLedgerPanel");
            Check(resetPanel.GetThemeStylebox("panel") is StyleBoxTexture
                && Find<Panel>("ResetLedgerMessagePanel").Visible
                && Find<Control>("ResetLedgerDecorations").Visible,
                "reset confirmation uses the shared illustrated panel treatment");
            await Capture("reset-confirmation");
            Click("Cancel"); Check(_save.Data.Coins == 153, "reset cancel preserves progress");
            File.WriteAllText(_path, "broken save"); _save.Load(); _screen.PresentCity(StableIds.Cities.Tianjin); _screen.PresentLedger();
            Check(Find<Button>("StartSelectedDay").Disabled, "corrupt save cannot start"); await Capture("ledger-corrupt");
            Click("ResetLedgerProgress"); Click("Confirm"); Check(!_save.HasLoadError && _screen.Page == JourneyPage.City, "confirmed reset restores valid city hub");
            GD.Print($"CITY_PAGES_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print("CITY_PAGES_TEST_RESULT failed=1"); GetTree().Quit(1); }
    }
    private async Task ReviewBusinessNote()
    {
        var model = new CityPageModel(GetNode<DataCatalog>("/root/DataCatalog"), _save, YangzhouCatalog.Load());
        foreach (var city in JourneyModel.Cities)
        {
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            var progress = _save.Data.GetCity(city.Id);
            foreach (string state in new[] { "first", "long-title", "complete" })
            {
                progress.HighestUnlockedDay = state == "first" ? 1 : state == "complete" ? city.Days :
                    Enumerable.Range(1, city.Days).OrderByDescending(d => model.DayTitle(city.Id, d).Length).First();
                progress.Completed = state == "complete";
                _save.Data.Coins = state == "first" ? 0 : int.MaxValue;
                if (progress.Completed && city.Id == StableIds.Cities.Yangzhou)
                    progress.UnlockedCollectibleIds.Add("collectible:yangzhou_crab_soup_bun");
                _screen.PresentCity(city.Id); await Frames();
                var note = Find<Control>("BusinessNote");
                CheckBookTheme(city.Id);
                Check(note.Size == new Vector2(430, 400), "note stays within page " + city.Name + state);
                foreach (var node in note.FindChildren("*", "Label", true, false))
                {
                    var label = (Label)node;
                    Check(label.Size.X <= note.Size.X, "label fits note width " + label.Name);
                    Check(label.GetLineCount() <= label.GetVisibleLineCount(), "all lines visible " + label.Name);
                }
                foreach (var node in Find<Control>("JourneyGoals").FindChildren("*", "Label", true, false))
                {
                    var label = (Label)node;
                    Check(label.GetLineCount() <= label.GetVisibleLineCount(), "goal and collection lines visible " + label.Name);
                }
                Check(Find<Label>("Coins").GetLineCount() == 1, "coin amount fits one row");
                var button = Find<Button>("OpenBusiness");
                Check(!button.Disabled && button.HasFocus(), "primary action available and focused");
                Check(button.Text.StartsWith(progress.Completed ? "再次营业" : "开张"), "primary action reflects completion");
                await Capture(city.Name + "-note-" + state);
            }
        }
    }
    private void CheckBookTheme(string city)
    {
        if (_screen.Page == JourneyPage.Ledger)
        {
            var ledger = Find<TextureRect>("SharedBook");
            Check(ledger.Material is null && ((AtlasTexture)ledger.Texture).Atlas.ResourcePath.EndsWith("旅行手账双页母版-经营手账.png"), "ledger uses supplied master without old mask " + city);
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
        var mask = material.GetShaderParameter("region_mask").AsGodotObject() as Texture2D;
        Check(mask!.ResourcePath.EndsWith(_screen.Page == JourneyPage.City ? "旅行手账双页分区遮罩-带便签.png" : "旅行手账双页分区遮罩.png"), "mask matches page artwork");
        var source = ((AtlasTexture)book.Texture).Atlas;
        Check(mask is not null && mask.GetSize() == source.GetSize(), "mask uses original atlas coordinates " + city);
    }
    private T Find<T>(string name) where T : Node => (T)_screen.FindChildren(name, typeof(T).Name, true, false).First(n => n is not Control c || c.IsVisibleInTree());
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
