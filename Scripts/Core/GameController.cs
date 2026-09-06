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
        string mapOriginCity = Data.StableIds.Cities.Tianjin;
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
        mapScreen.HubRequested += () => { if (mapOriginCity == Data.StableIds.Cities.Wuhan) ShowOnly(wuhanHub, hub, mapScreen, dayScreen, pancakeLab, debugPanel, wuhanDay); else ShowOnly(hub, wuhanHub, mapScreen, dayScreen, pancakeLab, debugPanel, wuhanDay); };
        mapScreen.CityRequested += cityId => { if (cityId == Data.StableIds.Cities.Wuhan) ShowOnly(wuhanHub, hub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanDay); else ShowOnly(hub, wuhanHub, dayScreen, pancakeLab, debugPanel, mapScreen, wuhanDay); };
        ShowOnly(hub, pancakeLab, dayScreen, debugPanel, mapScreen, wuhanHub, wuhanDay);
    }

    private static void ShowOnly(Control show, params Control[] hide)
    {
        foreach (Control control in hide) control.Visible = false;
        show.Visible = true;
    }
}
