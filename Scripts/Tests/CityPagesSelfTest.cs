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
            foreach (var city in JourneyModel.Cities)
            {
                string before = File.ReadAllText(_path);
                Check(_main.OpenCity(city.Id), "open " + city.Name); await Frames();
                Check(_screen.Visible && _screen.Page == JourneyPage.City, "shared hub visible " + city.Name);
                Rect2 rect = Find<TextureRect>("SharedBook").GetGlobalRect();
                await Capture(city.Name + "-hub");
                Click("LedgerTab"); await Frames();
                Check(Find<TextureRect>("SharedBook").GetGlobalRect() == rect, "ledger book geometry matches " + city.Name);
                Check(_screen.SelectedDay == city.Days, "ledger selects latest " + city.Name);
                Check(Find<Label>("BestRevenue").Text == "140 金币", "ledger record " + city.Name);
                Check(_screen.FindChildren("Date*", "Button", true, false).Count == city.Days, "calendar day count " + city.Name);
                var dateMetrics = Find<Button>("Date1").GetNode<Label>("Record");
                Check(dateMetrics.Position.Y + dateMetrics.GetMinimumSize().Y <= Find<Button>("Date1").Size.Y - 4, "date metrics fit card height " + city.Name);
                await Capture(city.Name + "-ledger");
                Click("UpgradeTab"); await Frames();
                Check(Find<TextureRect>("SharedBook").GetGlobalRect() == rect, "upgrade book geometry matches " + city.Name);
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
            await Capture("ledger-large");
            _save.Data.Tianjin.DayBestRecords[15].TotalRevenue = 140;
            _screen.PresentHome(); Click("NewGame"); Click("Skip");
            Check(Find<TextureRect>("SharedBook").GetRect() == StartScreen.BookBounds, "new journey shares book geometry"); await Capture("new-journey");
            _save.Data.LastVisitedCityId = StableIds.Cities.Tianjin; _save.TrySave(out _);
            _screen.PresentMap(); await Capture("map");
            foreach (var city in JourneyModel.Cities) { var p = _save.Data.GetCity(city.Id); p.Completed = true; p.BestStars = 3; }
            _screen.PresentMap(); await Capture("map-complete");
            _save.QueueJourneyCompletion(StableIds.Cities.Tianjin); _main.OpenCity(StableIds.Cities.Tianjin);
            Check(_screen.Page == JourneyPage.Completion, "completion presentation retained");
            Check(Find<TextureRect>("SharedBook").GetRect() == StartScreen.BookBounds, "completion uses same book bounds");
            await Capture("completion"); Click("Skip"); Check(_screen.SelectedCityId == StableIds.Cities.Wuhan, "completion goes to next city");
            _screen.PresentLedger(); Click("ResetLedgerProgress"); Click("Cancel"); Check(_save.Data.Coins == 153, "reset cancel preserves progress");
            File.WriteAllText(_path, "broken save"); _save.Load(); _screen.PresentCity(StableIds.Cities.Tianjin); _screen.PresentLedger();
            Check(Find<Button>("StartSelectedDay").Disabled, "corrupt save cannot start"); await Capture("ledger-corrupt");
            Click("ResetLedgerProgress"); Click("Confirm"); Check(!_save.HasLoadError && _screen.Page == JourneyPage.City, "confirmed reset restores valid city hub");
            GD.Print($"CITY_PAGES_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print("CITY_PAGES_TEST_RESULT failed=1"); GetTree().Quit(1); }
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
