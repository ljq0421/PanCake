using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

/// <summary>Rendered 60fps acceptance sequence; also usable with Godot --write-movie.</summary>
public partial class WuhanRepairCapture : Node
{
    private WuhanDayScreen _day = null!;
    private string _output = "";
    public override async void _Ready()
    {
        try
        {
            string[] args = OS.GetCmdlineUserArgs();
            bool small = args.Contains("--720");
            int level = args.Contains("--auto") ? 3 : 1;
            bool reduced = args.Contains("--reduced");
            GetWindow().Size = small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080);
            GetWindow().ContentScaleSize = new Vector2I(1920, 1080);
            ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
            _output = $"res://.tmp/wuhan-repair/{(small ? 720 : 1080)}-lv{level}-{(reduced ? "reduced" : "normal")}";
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests(_output + "/fixture.json"); AddChild(save);
            save.Data.Wuhan.HighestUnlockedDay = 12;
            save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = level;
            save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = level;
            save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"] = 1;
            var controller = new DayController(); AddChild(controller);
            _day = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(_day);
            _day.ConnectController(controller); _day.Initialize(catalog, save, controller, 8); _day.SetProcess(false);
            _day.BeginDay(); await Advance(3.1);
            var view = _day.Workstation;
            Drag(view.RawCenter, view.BasketRect(0).GetCenter()); await Advance(.25); await Shot("01-raw-basket");
            _day.PourDoupiBatter(); await Advance(.18); await Shot("02-batter-action"); await Advance(.22);
            _day.AddDoupiEgg(); await Advance(.18); await Shot("03-egg-action");
            await Advance(catalog.DoupiGriddlesByLevel[level].StageSeconds / catalog.DoupiGriddlesByLevel[level].SpeedMultiplier - .18 + .02);
            if (level == 1) Drag(view.PanCenter, view.PanCenter - new Vector2(0, 55));
            await Advance(.12); await Shot("04-flip-lift"); await Advance(.12); await Shot("05-flip-middle"); await Advance(.26);
            _day.AddDoupiFilling(); await Advance(.18); await Shot("06-filling-action"); await Advance(.23); await Shot("07-filling");DoupiTestFixture.Spread(_day.Doupi!);
            await Advance(1.2); await Shot("08-browning");
            await Advance(catalog.DoupiGriddlesByLevel[level].SecondStageReadySeconds / catalog.DoupiGriddlesByLevel[level].SpeedMultiplier - 1.61 + .01);
            await Shot("09-ready");
            Drag(view.PanPoint(.05f,.5f), view.PanPoint(.95f,.5f));
            await Advance(.18); await Shot("10-horizontal-cut"); await Advance(.22);
            Drag(view.PanPoint(.5f,.05f), view.PanPoint(.5f,.95f));
            await Advance(.18); await Shot("11-vertical-cut"); await Advance(.22);
            foreach(float x in new[]{.25f,.75f}){Drag(view.PanPoint(x,.05f),view.PanPoint(x,.95f));await Advance(.4);}
            await Advance(.18); await Shot("12-transfer"); await Advance(.36); await Shot("13-stocked");
            if (_day.DoupiStock.Count != 8 || _day.EggUnlocked) throw new InvalidOperationException("Repair capture ended with wrong supply state.");
            _day.PourDoupiBatter(); await Advance(.1); float paused = view.MotionProgress("pan");
            controller.IsPaused = true; await Advance(.5);
            if (view.MotionProgress("pan") != paused) throw new InvalidOperationException("Pause advanced the pan animation.");
            await Shot("14-paused"); controller.IsPaused = false; await Advance(.4);
            _day.Free(); controller.Free(); save.Free();
            GD.Print("WUHAN_REPAIR_CAPTURE_OK"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private async Task Advance(double seconds)
    {
        for (int i = 0; i < (int)Math.Ceiling(seconds * 60); i++)
        {
            _day._Notification((int)NotificationApplicationFocusIn);
            _day._Process(1.0 / 60);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
    }
    private async Task Shot(string name)
    {
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string path = ProjectSettings.GlobalizePath($"{_output}/{name}.png");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        using Image image = GetViewport().GetTexture().GetImage();
        if (image.SavePng(path) != Error.Ok) throw new IOException(path);
    }
    private void Drag(Vector2 start, Vector2 end)
    {
        Transform2D transform = _day.Workstation.GetGlobalTransformWithCanvas();
        start = transform * start; end = transform * end;
        GetViewport().PushInput(new InputEventMouseMotion { Position = start }, true);
        GetViewport().PushInput(new InputEventMouseButton { Position = start, ButtonIndex = MouseButton.Left, Pressed = true }, true);
        GetViewport().PushInput(new InputEventMouseMotion { Position = end, ButtonMask = MouseButtonMask.Left }, true);
        GetViewport().PushInput(new InputEventMouseButton { Position = end, ButtonIndex = MouseButton.Left, Pressed = false }, true);
    }
}
