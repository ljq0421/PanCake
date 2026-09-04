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

    public override void _Ready()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var dayController = GetNode<DayController>(DayControllerPath);
        var debugPanel = GetNode<DataDebugPanel>(DebugPanelPath);
        var pancakeLab = GetNode<PancakeLab>(PancakeLabPath);
        var hub = GetNode<MorningHub>(HubPath);
        var dayScreen = GetNode<TianjinDayScreen>(TianjinDayPath);
        var mapScreen = GetNode<TianjinMapScreen>(MapPath);
        var save = GetNode<SaveService>("/root/SaveService");
        debugPanel.Initialize(catalog, dayController);
        pancakeLab.Initialize(catalog);
        hub.Initialize(catalog, save);
        dayScreen.ConnectController(dayController);
        mapScreen.Initialize(save);
        hub.DayRequested += day =>
        {
            dayScreen.Initialize(catalog, save, dayController, day);
            ShowOnly(dayScreen, hub, pancakeLab, debugPanel, mapScreen);
            dayScreen.BeginDay();
        };
        hub.LabRequested += () => ShowOnly(pancakeLab, hub, dayScreen, debugPanel, mapScreen);
        hub.DebugRequested += () => ShowOnly(debugPanel, hub, dayScreen, pancakeLab, mapScreen);
        hub.MapRequested += () => ShowOnly(mapScreen, hub, dayScreen, pancakeLab, debugPanel);
        pancakeLab.HubRequested += () => ShowOnly(hub, pancakeLab, dayScreen, debugPanel, mapScreen);
        pancakeLab.DataDebugRequested += () => ShowOnly(debugPanel, hub, pancakeLab, dayScreen, mapScreen);
        debugPanel.PancakeLabRequested += () => ShowOnly(pancakeLab, hub, debugPanel, dayScreen, mapScreen);
        debugPanel.HubRequested += () => ShowOnly(hub, debugPanel, pancakeLab, dayScreen, mapScreen);
        dayScreen.HubRequested += () => ShowOnly(hub, dayScreen, pancakeLab, debugPanel, mapScreen);
        mapScreen.HubRequested += () => ShowOnly(hub, mapScreen, dayScreen, pancakeLab, debugPanel);
        ShowOnly(hub, pancakeLab, dayScreen, debugPanel, mapScreen);
    }

    private static void ShowOnly(Control show, params Control[] hide)
    {
        foreach (Control control in hide) control.Visible = false;
        show.Visible = true;
    }
}
