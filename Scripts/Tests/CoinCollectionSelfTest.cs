using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class CoinCollectionSelfTest : Node
{
    private int _passed;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private void Check(bool ok, string message)
    {
        if (!ok) throw new InvalidOperationException(message);
        _passed++; GD.Print("PASS " + message);
    }
    private async Task Frames()
    {
        for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    public override async void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (bool wuhan in new[] { true, false })
            foreach (bool reduced in new[] { false, true })
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
                var save = new SaveService(); save.UsePathForTests($"res://.tmp/coin-test-{Guid.NewGuid():N}.json"); AddChild(save);
                save.Data.Wuhan.HighestUnlockedDay = 12;
                save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
                save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
                save.Data.Wuhan.EquipmentLevels["ingredient_station"] = 3;
                save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"] = 1;
                var controller = new DayController(); AddChild(controller);
                Control screen = wuhan ? ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn") : ProjectCake.Core.SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen); screen.SetProcess(false);
                void Init()
                {
                    if (screen is WuhanDayScreen ws) { ws.ConnectController(controller); ws.Initialize(catalog, save, controller, 8); ws.BeginDay(); }
                    else { var ts = (TianjinDayScreen)screen; ts.ConnectController(controller); ts.Initialize(catalog, save, controller, 11); ts.BeginDay(); }
                    controller.Tick(3.1);
                    screen._Notification((int)NotificationApplicationFocusIn);
                }
                Init();
                if (screen is TianjinDayScreen tianjin)
                {
                    await TestCashPendant(tianjin, controller, save, catalog, width, reduced);
                    screen.QueueFree(); controller.QueueFree(); save.QueueFree(); await Frames();
                    GC.Collect(); GC.WaitForPendingFinalizers(); await Frames();
                    continue;
                }
                await TestWuhanCashPendant((WuhanDayScreen)screen, controller, save, catalog, width, reduced);
                screen.QueueFree(); controller.QueueFree(); save.QueueFree(); await Frames();
                GC.Collect(); GC.WaitForPendingFinalizers(); await Frames();
            }
            GC.Collect(); GC.WaitForPendingFinalizers(); await Frames();
            GD.Print($"COIN_COLLECTION_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private async Task Shot(string name)
    {
        await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string directory = ProjectSettings.GlobalizePath("res://.tmp/coin-collection"); Directory.CreateDirectory(directory);
        GetViewport().GetTexture().GetImage().SavePng(Path.Combine(directory, name + ".png"));
    }
}
