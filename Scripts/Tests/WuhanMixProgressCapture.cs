using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class WuhanMixProgressCapture : Node
{
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--720");
            GetWindow().Size = small ? new(1280, 720) : new(1920, 1080);
            GetWindow().ContentScaleSize = new(1920, 1080);
            string output = $"res://.tmp/wuhan-mix/{(small ? 720 : 1080)}";
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(output));
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests(output + "/fixture.json"); AddChild(save);
            save.Data.Wuhan.HighestUnlockedDay = 12;
            foreach (int dayNumber in new[] { 1, 8 })
            {
                if (dayNumber == 8) save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 1;
                var controller = new DayController(); AddChild(controller);
                var day = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(day);
                day.ConnectController(controller); day.Initialize(catalog, save, controller, dayNumber); day.SetProcess(false);
                var bowl = day.Bowl; var view = day.Workstation;
                var progress = view.GetNode<EquipmentProgressView>("BowlMixProgress");
                void Check(bool ok, string message) { if (!ok) throw new InvalidOperationException(message); }
                async Task Shot(string name)
                {
                    progress.Refresh();
                    await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                    using var image = GetViewport().GetTexture().GetImage();
                    Check(image.SavePng(ProjectSettings.GlobalizePath($"{output}/day{dayNumber}-{name}.png")) == Error.Ok, "save image");
                }
                progress.Refresh(); Check(!progress.Visible, "empty bowl hides progress");
                bowl.TryAddNoodles(NoodleQuality.Optimal); bowl.TryAddBaseSeasoning();
                await Shot("start"); Check(progress.Visible && progress.Presentation.Progress == 0, "seasoning shows prompt");
                bowl.AddMixDistance(212.5); view.Tick(.01);
                await Shot("half"); Check(Math.Abs(progress.Presentation.Progress - .5) < .001, "half of actual completion distance");
                view.EndMix(); view.Tick(.5); Check(progress.Presentation.Progress == .5, "release preserves progress");
                bowl.AddMixDistance(212.5); view.Tick(.01);
                await Shot("ready"); Check(progress.Presentation.Ready && progress.Presentation.Caption == "已拌匀", "ready caption");
                view.Tick(1.3); Check(progress.Modulate.A > 0 && progress.Modulate.A < 1, "completion fades");
                view.Tick(.3); Check(!progress.Visible, "completion hides");
                bowl.TryAddTopping(StableIds.Ingredients.WuhanBraisedBeef); progress.Refresh();
                Check(!progress.Visible, "adding beef does not replay completion");
                bowl.Reset(); bowl.TryAddNoodles(NoodleQuality.Optimal); bowl.TryAddBaseSeasoning(); progress.Refresh();
                Check(progress.Visible && progress.Modulate.A == 1 && progress.Presentation.Progress == 0, "new bowl resets feedback");
                day.Free(); controller.Free();
            }
            GD.Print("WUHAN_MIX_PROGRESS_OK"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
}
