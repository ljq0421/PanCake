using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;
using System.Reflection;

namespace ProjectCake.Tests;

// Render the actual production surface and both preview paths at fixed cooking times.
public partial class WuhanDoupiMaterialCapture : Node
{
    private WuhanDayScreen _day = null!;
    private string _output = "";
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--720");
            GetWindow().Size = small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080);
            GetWindow().ContentScaleSize = new Vector2I(1920, 1080);
            _output = ProjectSettings.GlobalizePath($"res://.tmp/doupi-materials/{(small ? 720 : 1080)}");
            Directory.CreateDirectory(_output);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests(_output + "/fixture.json"); AddChild(save);
            save.Data.Wuhan.HighestUnlockedDay = 12;
            save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 1;
            save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 1;
            var controller = new DayController(); AddChild(controller);
            _day = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
            AddChild(_day); _day.ConnectController(controller); _day.Initialize(catalog, save, controller, 8);
            _day.SetProcess(false); _day.BeginDay(); Step(3.1);
            var pan = _day.Doupi!;
            _day.PourDoupiBatter(); Step(.5); await Shot("01-batter", true);
            _day.AddDoupiEgg(); Step(.65); await Shot("02-egg-spread");
            Step(2); await Shot("03-egg-ready");
            _day.FlipDoupi(); Step(.23); await Shot("04-flip"); Step(.4);
            _day.AddDoupiFilling();
            _day.SpreadDoupi(new(.02f, .15f), new(.5f, .15f));
            await Shot("05-partial-filling", true);
            DoupiTestFixture.Spread(pan); await Shot("06-uncooked", true);
            Step(1.75); await Shot("07-half-cooked", true);
            Step(1.76); Require(pan.State == DoupiState.ReadyToCut, "ready to cut");
            await Shot("08-cooked", true);
            _day.CutDoupi(DoupiCutLine.Horizontal); Step(.4); await Shot("09-horizontal", true);
            _day.CutDoupi(DoupiCutLine.Center); await Shot("10-eight-pieces");
            Step(.4); Step(.15); await Shot("11-transfer"); Step(.6);
            Require(_day.DoupiStock.Count == 8, "two cuts supply eight pieces");
            await Shot("12-stock", stockPreview: true);
            _day.PourDoupiBatter(); Step(.5); _day.AddDoupiEgg(); Step(2.6); _day.FlipDoupi(); Step(.6);
            _day.AddDoupiFilling(); DoupiTestFixture.Spread(pan);
            Step(7); Require(pan.State == DoupiState.Overbrowned, "overbrowned"); await Shot("13-overbrowned", true);
            Step(2); Require(pan.State == DoupiState.Burnt, "burnt"); await Shot("14-burnt", true);
            _day.Free(); controller.Free(); save.Free();
            GD.Print("WUHAN_DOUPI_MATERIAL_CAPTURE_OK"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private static void Require(bool ok, string message) { if (!ok) throw new InvalidOperationException(message); }
    private void Step(double seconds)
    {
        for (int i=0; i<(int)Math.Ceiling(seconds*60); i++)
        { _day._Notification((int)NotificationApplicationFocusIn); _day._Process(1.0/60); }
    }
    private async Task Shot(string name, bool panPreview = false, bool stockPreview = false)
    {
        Control? preview = null;
        if (panPreview || stockPreview)
        {
            string method = panPreview ? "CreatePanDoupiPreview" : "CreateDeliveryPreview";
            object argument = panPreview ? new Vector2(180,85) : ProductKind.Doupi;
            preview = (Control)typeof(WuhanWorkstationView).GetMethod(method, BindingFlags.Instance|BindingFlags.NonPublic)!.Invoke(_day.Workstation,new[]{argument})!;
            preview.Position = new Vector2(900, 620); _day.Workstation.AddChild(preview);
        }
        _day.RefreshForCapture();
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using Image image = GetViewport().GetTexture().GetImage();
        Require(image.SavePng(Path.Combine(_output, name+".png")) == Error.Ok, "save capture");
        preview?.Free();
    }
}
