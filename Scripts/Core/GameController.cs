using Godot;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Core;

public partial class GameController : Node
{
    [Export]
    public NodePath DayControllerPath { get; set; } = new("DayController");

    [Export]
    public NodePath DebugPanelPath { get; set; } = new("UI/DataDebugPanel");

    [Export]
    public NodePath PancakeLabPath { get; set; } = new("UI/PancakeLab");

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
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var dayController = GetNode<DayController>(DayControllerPath);
        var debugPanel = GetNode<DataDebugPanel>(DebugPanelPath);
        var pancakeLab = GetNode<PancakeLab>(PancakeLabPath);
        var hub = GetNode<MorningHub>(HubPath);
        var dayScreen = GetNode<TianjinDayScreen>(TianjinDayPath);
        var mapScreen = GetNode<TianjinMapScreen>(MapPath);
        var wuhanHub = GetNode<WuhanHub>(WuhanHubPath);
        var wuhanDay = GetNode<WuhanDayScreen>(WuhanDayPath);
        var save = GetNode<SaveService>("/root/SaveService");
        _save = save;
        _startScreen = GetNode<StartScreen>("UI/StartScreen");
        _navigationError = GetNode<AcceptDialog>("NavigationError");
        _navigationError.Theme = StartScreenTheme.Create();
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
        _yangzhouHub.PracticeRequested += () =>
        {
            if (_yangzhouDay.Initialize(yangzhouCatalog, save, 8, true)) ShowOnly(_yangzhouDay);
        };
        _yangzhouHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Yangzhou; ShowOnly(mapScreen); };
        _yangzhouDay.HubRequested += () => { _yangzhouHub.Render(); ShowOnly(_yangzhouHub); };
        debugPanel.Initialize(catalog, dayController);
        pancakeLab.Initialize(catalog);
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
        hub.LabRequested += () => ShowOnly(pancakeLab);
        hub.DebugRequested += () => ShowOnly(debugPanel);
        hub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Tianjin; ShowOnly(mapScreen); };
        pancakeLab.HubRequested += () => ShowOnly(hub);
        pancakeLab.DataDebugRequested += () => ShowOnly(debugPanel);
        debugPanel.PancakeLabRequested += () => ShowOnly(pancakeLab);
        debugPanel.HubRequested += () => ShowOnly(hub);
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
        _guangzhouHub.PracticeRequested += () =>
        {
            if (!_guangzhouDay.Initialize(catalog, save, dayController, 9, true)) return;
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
        mapScreen.WuhanPreviewRequested += () => OpenCity(Data.StableIds.Cities.Wuhan, allowDeveloperPreview: true);
        mapScreen.CityRequested += cityId =>
        {
            OpenCity(cityId, mapScreen.DeveloperToolsVisible);
        };
        ShowOnly(_startScreen);
        _startScreen.Present();
    }

    public bool OpenCity(string cityId, bool allowDeveloperPreview = false)
    {
        if (!_cityHubs.TryGetValue(cityId, out Control? target)) return false;
        if (!_save.Data.UnlockedCityIds.Contains(cityId) && !allowDeveloperPreview) return false;
        if (!_save.TryRecordCityVisit(cityId, out string error))
        {
            if (_startScreen.Visible) _startScreen.ShowError(error);
            else { _navigationError.DialogText = "当前位置保存失败，请检查存档写入权限和可用空间。\n当前位置未变更，请重试。"; _navigationError.PopupCentered(); }
            return false;
        }
        _xianHub.Render(); _guangzhouHub.Render(); _yangzhouHub.Render();
        ShowOnly(target);
        return true;
    }

    private void ShowOnly(Control show)
    {
        foreach (Control page in GetNode("UI").GetChildren().OfType<Control>()) page.Visible = page == show;
        GetNode<Node2D>("ShopRoot").Visible = show != _startScreen;
    }
}
