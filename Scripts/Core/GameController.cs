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
        var yangzhouCatalog = ProjectCake.Yangzhou.YangzhouCatalog.Load();
        _yangzhouHub = new YangzhouHub { Name = "YangzhouHub", Visible = false };
        _yangzhouDay = new YangzhouDayScreen { Name = "YangzhouDayScreen", Visible = false };
        GetNode("UI").AddChild(_yangzhouHub); GetNode("UI").AddChild(_yangzhouDay);
        _yangzhouHub.Initialize(yangzhouCatalog, save);
        _guangzhouHub = GD.Load<PackedScene>("res://Scenes/UI/GuangzhouHub.tscn").Instantiate<GuangzhouHub>();
        _guangzhouDay = GD.Load<PackedScene>("res://Scenes/Gameplay/GuangzhouDayScreen.tscn").Instantiate<GuangzhouDayScreen>();
        _guangzhouHub.Visible = _guangzhouDay.Visible = false;
        GetNode("UI").AddChild(_guangzhouHub); GetNode("UI").AddChild(_guangzhouDay);
        _guangzhouHub.Initialize(catalog, save); _guangzhouDay.ConnectController(dayController);
        _xianHub = GetNode<XianHub>("UI/XianHub");
        _xianDay = GetNode<XianDayScreen>("UI/XianDayScreen");
        _xianHub.Initialize(catalog, save);
        _xianDay.ConnectController(dayController);
        string mapOriginCity = Data.StableIds.Cities.Tianjin;
        _yangzhouHub.DayRequested += day =>
        {
            if (!_yangzhouDay.Initialize(yangzhouCatalog, save, day)) { _yangzhouHub.ShowError("无法开店，请检查日期解锁和存档状态。"); return; }
            ShowOnly(_yangzhouDay, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay);
        };
        _yangzhouHub.PracticeRequested += () =>
        {
            if (_yangzhouDay.Initialize(yangzhouCatalog, save, 8, true)) ShowOnly(_yangzhouDay, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay);
        };
        _yangzhouHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Yangzhou; ShowOnly(mapScreen, hub, dayScreen, pancakeLab, debugPanel, wuhanHub, wuhanDay); };
        _yangzhouDay.HubRequested += () => { _yangzhouHub.Render(); ShowOnly(_yangzhouHub, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay); };
        debugPanel.Initialize(catalog, dayController);
        pancakeLab.Initialize(catalog);
        hub.Initialize(catalog, save);
        dayScreen.ConnectController(dayController);
        mapScreen.Initialize(save);
        wuhanHub.Initialize(catalog, save);
        wuhanDay.ConnectController(dayController);
        hub.DayRequested += day =>
        {
            dayScreen.Initialize(catalog, save, dayController, day);
            ShowOnly(dayScreen, hub, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay);
            dayScreen.BeginDay();
        };
        hub.LabRequested += () => ShowOnly(pancakeLab, hub, dayScreen, debugPanel, mapScreen, wuhanHub, wuhanDay);
        hub.DebugRequested += () => ShowOnly(debugPanel, hub, dayScreen, pancakeLab, mapScreen, wuhanHub, wuhanDay);
        hub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Tianjin; ShowOnly(mapScreen, hub, dayScreen, pancakeLab, debugPanel, wuhanHub, wuhanDay); };
        pancakeLab.HubRequested += () => ShowOnly(hub, pancakeLab, dayScreen, debugPanel, mapScreen, wuhanHub, wuhanDay);
        pancakeLab.DataDebugRequested += () => ShowOnly(debugPanel, hub, pancakeLab, dayScreen, mapScreen, wuhanHub, wuhanDay);
        debugPanel.PancakeLabRequested += () => ShowOnly(pancakeLab, hub, debugPanel, dayScreen, mapScreen, wuhanHub, wuhanDay);
        debugPanel.HubRequested += () => ShowOnly(hub, debugPanel, pancakeLab, dayScreen, mapScreen, wuhanHub, wuhanDay);
        dayScreen.HubRequested += () => ShowOnly(hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay);
        wuhanHub.DayRequested += day => { wuhanDay.Initialize(catalog, save, dayController, day); ShowOnly(wuhanDay, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub); wuhanDay.BeginDay(); };
        wuhanHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Wuhan; ShowOnly(mapScreen, hub, dayScreen, pancakeLab, debugPanel, wuhanHub, wuhanDay); };
        wuhanDay.HubRequested += () => ShowOnly(wuhanHub, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanDay);
        _xianHub.DayRequested += day => { if (_xianDay.Initialize(catalog, save, dayController, day)) { ShowOnly(_xianDay, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay); _xianDay.BeginDay(); } };
        _xianHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Xian; ShowOnly(mapScreen, hub, dayScreen, pancakeLab, debugPanel, wuhanHub, wuhanDay); };
        _xianDay.HubRequested += () => { _xianHub.Render(); ShowOnly(_xianHub, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay); };
        _guangzhouHub.DayRequested += day =>
        {
            if (!_guangzhouDay.Initialize(catalog, save, dayController, day)) return;
            ShowOnly(_guangzhouDay, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay);
            _guangzhouDay.BeginDay();
        };
        _guangzhouHub.PracticeRequested += () =>
        {
            if (!_guangzhouDay.Initialize(catalog, save, dayController, 9, true)) return;
            ShowOnly(_guangzhouDay, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay);
            _guangzhouDay.BeginDay();
        };
        _guangzhouHub.MapRequested += () => { mapOriginCity = Data.StableIds.Cities.Guangzhou; ShowOnly(mapScreen, hub, dayScreen, pancakeLab, debugPanel, wuhanHub, wuhanDay); };
        _guangzhouDay.HubRequested += () => { _guangzhouHub.Render(); ShowOnly(_guangzhouHub, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanHub, wuhanDay); };
        mapScreen.HubRequested += () =>
        {
            Control target = mapOriginCity switch { Data.StableIds.Cities.Yangzhou => _yangzhouHub, Data.StableIds.Cities.Guangzhou => _guangzhouHub, Data.StableIds.Cities.Xian => _xianHub, Data.StableIds.Cities.Wuhan => wuhanHub, _ => hub };
            ShowOnly(target, hub, wuhanHub, mapScreen, dayScreen, pancakeLab, debugPanel, wuhanDay);
        };
        mapScreen.CityRequested += cityId =>
        {
            if (cityId == Data.StableIds.Cities.Yangzhou && !save.Data.UnlockedCityIds.Contains(cityId) && !mapScreen.DeveloperToolsVisible) return;
            if (cityId == Data.StableIds.Cities.Xian && !save.Data.UnlockedCityIds.Contains(cityId) && !mapScreen.DeveloperToolsVisible) return;
            Control target = cityId switch { Data.StableIds.Cities.Yangzhou => _yangzhouHub, Data.StableIds.Cities.Guangzhou => _guangzhouHub, Data.StableIds.Cities.Xian => _xianHub, Data.StableIds.Cities.Wuhan => wuhanHub, _ => hub };
            _xianHub.Render(); _guangzhouHub.Render(); _yangzhouHub.Render();
            ShowOnly(target, hub, wuhanHub, mapScreen, dayScreen, pancakeLab, debugPanel, wuhanDay);
        };
        ShowOnly(hub, pancakeLab, dayScreen, debugPanel, mapScreen, wuhanHub, wuhanDay);
    }

    private void ShowOnly(Control show, params Control[] hide)
    {
        if (_yangzhouHub is not null && show != _yangzhouHub) _yangzhouHub.Visible = false;
        if (_yangzhouDay is not null && show != _yangzhouDay) _yangzhouDay.Visible = false;
        if (_guangzhouHub is not null && show != _guangzhouHub) _guangzhouHub.Visible = false;
        if (_guangzhouDay is not null && show != _guangzhouDay) _guangzhouDay.Visible = false;
        if (_xianHub is not null && show != _xianHub) _xianHub.Visible = false;
        if (_xianDay is not null && show != _xianDay) _xianDay.Visible = false;
        foreach (Control control in hide) control.Visible = false;
        show.Visible = true;
    }
}
