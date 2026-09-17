using Godot;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Core;

public partial class GameController : Node
{
    [Export]
    public NodePath DayControllerPath { get; set; } = new("DayController");

    [Export] public NodePath HubPath { get; set; } = new("UI/MorningHub");
    [Export] public NodePath TianjinDayPath { get; set; } = new("UI/TianjinDayScreen");
    [Export] public NodePath MapPath { get; set; } = new("UI/TianjinMapScreen");
    [Export] public NodePath WuhanHubPath { get; set; } = new("UI/WuhanHub");
    [Export] public NodePath WuhanDayPath { get; set; } = new("UI/WuhanDayScreen");

    private XianHub _xianHub = null!;
    private XianDayScreen _xianDay = null!;
    private GuangzhouHub _guangzhouHub = null!;
    private GuangzhouDayScreen _guangzhouDay = null!;
    private YangzhouHub _yangzhouHub = null!;
    private YangzhouDayScreen _yangzhouDay = null!;
    private StartScreen _startScreen = null!;
    private SaveService _save = null!;
    private AcceptDialog _navigationError = null!;
    private readonly Dictionary<string, Control> _cityHubs = new(StringComparer.Ordinal);

    public override void _Ready()
    {
        if (ExperienceProfile.IsDemo) { InitializeDemo(); return; }
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var dayController = GetNode<DayController>(DayControllerPath);
        var hub = GetNode<MorningHub>(HubPath);
        var dayScreen = GetNode<TianjinDayScreen>(TianjinDayPath);
        var mapScreen = GetNode<TianjinMapScreen>(MapPath);
        var wuhanHub = GetNode<WuhanHub>(WuhanHubPath);
        var wuhanDay = GetNode<WuhanDayScreen>(WuhanDayPath);
        var save = GetNode<SaveService>("/root/SaveService");
        _save = save;
        _startScreen = GetNode<StartScreen>("UI/StartScreen");
        _navigationError = GetNode<AcceptDialog>("NavigationError");
        CityDialogChrome.ApplyConfirmation(_navigationError, StableIds.Cities.Tianjin);
        var yangzhouCatalog = ProjectCake.Yangzhou.YangzhouCatalog.Load();
        _yangzhouHub = GetNode<YangzhouHub>("UI/YangzhouHub");
        _yangzhouDay = GetNode<YangzhouDayScreen>("UI/YangzhouDayScreen");
        _yangzhouHub.Initialize(yangzhouCatalog, save);
        _guangzhouHub = GetNode<GuangzhouHub>("UI/GuangzhouHub");
        _guangzhouDay = GetNode<GuangzhouDayScreen>("UI/GuangzhouDayScreen");
        _guangzhouHub.Initialize(catalog, save); _guangzhouDay.ConnectController(dayController);
        _xianHub = GetNode<XianHub>("UI/XianHub");
        _xianDay = GetNode<XianDayScreen>("UI/XianDayScreen");
        _xianHub.Initialize(catalog, save);
        _xianDay.ConnectController(dayController);
        string mapOriginCity = Data.StableIds.Cities.Tianjin;
        _yangzhouHub.DayRequested += day =>
        {
            if (!_yangzhouDay.Initialize(yangzhouCatalog, save, day)) { _yangzhouHub.ShowError("无法开店，请检查日期解锁和存档状态。"); return; }
            ShowOnly(_yangzhouDay);
        };
        _yangzhouHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Yangzhou; ShowOnly(mapScreen); };
        _yangzhouDay.HubRequested += () => { _yangzhouHub.Render(); ShowOnly(_yangzhouHub); };
        hub.Initialize(catalog, save);
        dayScreen.ConnectController(dayController);
        mapScreen.Initialize(save);
        wuhanHub.Initialize(catalog, save);
        wuhanDay.ConnectController(dayController);
        _cityHubs[Data.StableIds.Cities.Tianjin] = hub;
        _cityHubs[Data.StableIds.Cities.Wuhan] = wuhanHub;
        _cityHubs[Data.StableIds.Cities.Xian] = _xianHub;
        _cityHubs[Data.StableIds.Cities.Guangzhou] = _guangzhouHub;
        _cityHubs[Data.StableIds.Cities.Yangzhou] = _yangzhouHub;
        _startScreen.Initialize(save);
        _startScreen.ConfigureCities(catalog, yangzhouCatalog);
        _startScreen.BusinessRequested += (city, day) => StartCityBusiness(city, day);
        _startScreen.DemoTutorialRequested += () =>
        {
            if (_startScreen.SelectedCityId == StableIds.Cities.Wuhan) wuhanDay.ForceDemoTutorial = true;
            else if (_startScreen.SelectedCityId == StableIds.Cities.Tianjin) dayScreen.ForceDemoTutorial = true;
            else return;
            if (!StartCityBusiness(_startScreen.SelectedCityId, _startScreen.SelectedDay))
            { dayScreen.ForceDemoTutorial = false; wuhanDay.ForceDemoTutorial = false; }
        };
        _startScreen.UpgradeRequested += (city, id) =>
        {
            string error;
            bool ok = !save.HasLoadError && save.Data.UnlockedCityIds.Contains(city);
            if (!ok) error = "存档或城市状态不允许升级。";
            else ok = city == Data.StableIds.Cities.Yangzhou ? save.PurchaseYangzhou(id, yangzhouCatalog, out error) : save.TryPurchase(city, id, catalog, out error);
            _startScreen.RefreshCityPage();
            _startScreen.ShowError(ok ? "设备已升级，下次营业生效。" : error);
        };
        _startScreen.NewGameRequested += () =>
        {
            if (!save.ResetProgress(out string error)) { _startScreen.ShowError(error); return; }
            ShowOnly(hub);
        };
        _startScreen.ContinueRequested += () =>
        {
            if (!save.CanContinue) { _startScreen.ShowError("存档无法继续，请检查存档状态。"); return; }
            OpenCity(save.ContinueCityId);
        };
        _startScreen.QuitRequested += () => GetTree().Quit();
        hub.DayRequested += day =>
        {
            dayScreen.Initialize(catalog, save, dayController, day);
            ShowOnly(dayScreen);
            dayScreen.BeginDay();
        };
        hub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Tianjin; ShowOnly(mapScreen); };
        dayScreen.HubRequested += () => ShowOnly(hub);
        wuhanHub.DayRequested += day => { wuhanDay.Initialize(catalog, save, dayController, day); ShowOnly(wuhanDay); wuhanDay.BeginDay(); };
        wuhanHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Wuhan; ShowOnly(mapScreen); };
        wuhanDay.HubRequested += () => ShowOnly(wuhanHub);
        _xianHub.DayRequested += day => { if (_xianDay.Initialize(catalog, save, dayController, day)) { ShowOnly(_xianDay); _xianDay.BeginDay(); } };
        _xianHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Xian; ShowOnly(mapScreen); };
        _xianDay.HubRequested += () => { _xianHub.Render(); ShowOnly(_xianHub); };
        _guangzhouHub.DayRequested += day =>
        {
            if (!_guangzhouDay.Initialize(catalog, save, dayController, day)) return;
            ShowOnly(_guangzhouDay);
            _guangzhouDay.BeginDay();
        };
        _guangzhouHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Guangzhou; ShowOnly(mapScreen); };
        _guangzhouDay.HubRequested += () => { _guangzhouHub.Render(); ShowOnly(_guangzhouHub); };
        mapScreen.HubRequested += () =>
        {
            Control target = mapOriginCity switch { Data.StableIds.Cities.Yangzhou => _yangzhouHub, Data.StableIds.Cities.Guangzhou => _guangzhouHub, Data.StableIds.Cities.Xian => _xianHub, Data.StableIds.Cities.Wuhan => wuhanHub, _ => hub };
            ShowOnly(target);
        };
        mapScreen.XianPreviewRequested += () => OpenCity(Data.StableIds.Cities.Xian, allowDeveloperPreview: true);
        mapScreen.WuhanPreviewRequested += () => OpenCity(Data.StableIds.Cities.Wuhan, allowDeveloperPreview: true);
        mapScreen.CityRequested += cityId =>
        {
            OpenCity(cityId, mapScreen.DeveloperToolsVisible);
        };
        InitializeMusic();
        ShowOnly(_startScreen);
        _startScreen.Present();
    }

    public bool OpenCity(string cityId, bool allowDeveloperPreview = false)
    {
        if (!_cityHubs.TryGetValue(cityId, out Control? target))
        {
            ShowNavigationError(cityId, "这座城市暂时无法前往，请返回地图后重试。");
            return false;
        }
        if (!_save.Data.UnlockedCityIds.Contains(cityId) && !allowDeveloperPreview)
        {
            ShowNavigationError(cityId, "这座城市尚未解锁，完成当前城市的营业后再出发吧。");
            return false;
        }
        ShowOnly(target);
        return true;
    }

    private void ShowNavigationError(string cityId, string message)
    {
        // Guangzhou and Yangzhou remain outside this visual pass.
        if (cityId is not (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan or StableIds.Cities.Xian)) return;
        if (_navigationError is null)
        {
            _startScreen.ShowError(message);
            return;
        }
        // Wuhan's green frame belongs to its business screen, not the home/map pages.
        string themeCity = GetNode<Control>(WuhanDayPath).Visible ? StableIds.Cities.Wuhan
            : cityId == StableIds.Cities.Wuhan ? StableIds.Cities.Tianjin : cityId;
        CityDialogChrome.ApplyConfirmation(_navigationError, themeCity);
        _navigationError.Title = "暂时无法前往";
        _navigationError.DialogText = message;
        _navigationError.PopupCentered(new Vector2I(680, 300));
    }

    public bool StartCityBusiness(string cityId, int day)
    {
        if (_save.IsDemo && !_save.CanEnter(cityId, day))
        { _startScreen.ShowError("本次试玩尚未开放该营业日。"); return false; }
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var controller = GetNode<DayController>(DayControllerPath);
        bool cityAvailable = _save.Data.UnlockedCityIds.Contains(cityId)
            || _startScreen.DeveloperToolsVisible && cityId == Data.StableIds.Cities.Wuhan;
        if (!_save.CanContinue || !catalog.IsValid || !cityAvailable
            || !JourneyModel.Cities.Any(c => c.Id == cityId) || day < 1 || day > SaveService.ChapterDays(cityId)
            || day > JourneyModel.Progress(_save, cityId).HighestUnlockedDay)
        { _startScreen.ShowError("无法开张，请检查营业日、城市解锁和存档状态。"); return false; }
        Control screen; bool ready;
        switch (cityId)
        {
            case Data.StableIds.Cities.Tianjin:
                var t = GetNode<TianjinDayScreen>(TianjinDayPath); screen = t; ready = t.Initialize(catalog, _save, controller, day); break;
            case Data.StableIds.Cities.Wuhan:
                var w = GetNode<WuhanDayScreen>(WuhanDayPath); screen = w; ready = w.Initialize(catalog, _save, controller, day); break;
            case Data.StableIds.Cities.Xian: screen = _xianDay; ready = _xianDay.Initialize(catalog, _save, controller, day); break;
            case Data.StableIds.Cities.Guangzhou: screen = _guangzhouDay; ready = _guangzhouDay.Initialize(catalog, _save, controller, day); break;
            default: screen = _yangzhouDay; ready = _yangzhouDay.Initialize(ProjectCake.Yangzhou.YangzhouCatalog.Load(), _save, day); break;
        }
        if (!ready) { _startScreen.ShowError("营业准备失败，请检查配置或存档写入权限后重试。"); return false; }
        if (!_save.TryRecordDemoStart(cityId, day, out string demoError)) { _startScreen.ShowError(demoError); return false; }
        if (!_save.TryRecordCityVisit(cityId, out string error)) { _startScreen.ShowError(error); return false; }
        ShowOnly(screen);
        if (screen is TianjinDayScreen td) td.BeginDay();
        else if (screen is WuhanDayScreen wd) wd.BeginDay();
        else if (screen is XianDayScreen xd) xd.BeginDay();
        else if (screen is GuangzhouDayScreen gd) gd.BeginDay();
        return true;
    }

    private void ShowOnly(Control show)
    {
        if (show is TianjinMapScreen)
        {
            Control? origin = _cityHubs.Values.FirstOrDefault(c => c.Visible);
            ShowOnly(_startScreen);
            _startScreen.PresentMap(() => { if (origin is not null) ShowOnly(origin); else _startScreen.PresentHome(); });
            return;
        }
        if (_cityHubs.Values.Contains(show) && _save.TakeJourneyCompletion() is { } completedCity)
        {
            ShowOnly(_startScreen);
            _startScreen.PresentCompletion(completedCity, () => ShowOnly(show));
            return;
        }
        if (_cityHubs.Values.Contains(show))
        {
            string city = _cityHubs.First(pair => pair.Value == show).Key;
            ShowOnly(_startScreen); _startScreen.PresentCity(city); return;
        }
        foreach (Control page in GetNode("UI").GetChildren().OfType<Control>()) page.Visible = page == show;
        GetNode<Node2D>("ShopRoot").Visible = show != _startScreen;
    }
}
