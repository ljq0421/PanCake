using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Captures current Demo scenes for Steam asset review using an isolated save.</summary>
public partial class SteamStoreCapture : Node
{
    private static readonly string Output = ProjectSettings.GlobalizePath("res://artifacts/steam-demo-store-20260924/screenshots");

    private async Task Frames(int count = 12)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task Capture(string name)
    {
        await Frames(35);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage();
        if (image.SavePng(Path.Combine(Output, name + ".png")) != Error.Ok)
            throw new IOException("Could not save Steam screenshot " + name);
        GD.Print("STORE_CAPTURE " + name);
    }

    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(Output);
            GetWindow().Size = new(1920, 1080);
            var save = GetNode<SaveService>("/root/SaveService");
            save.UseDemoPathForTests(Path.Combine(Output, "capture-save.json"));
            if (!save.ResetProgress(out var error)) throw new IOException(error);
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Path.Combine(Output, "settings.cfg"));
            settings.SetLanguage("zh_CN");
            InterfaceLessons.MarkAllSeen(settings);
            save.Data.GetCity(StableIds.Cities.Tianjin).HighestUnlockedDay = 8;
            save.Data.GetCity(StableIds.Cities.Wuhan).HighestUnlockedDay = 3;
            save.Data.Wuhan.LearnedWorkbenchActions.Add(TutorialOrders.WuhanBaseNoodlesLesson);
            if (!save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan)) save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
            if (!save.TrySave(out error)) throw new IOException(error);

            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            AddChild(main); await Frames(25);
            var start = main.GetNode<StartScreen>("UI/StartScreen");
            start.PresentHome(); await Capture("01-home");
            start.PresentMap(); await Capture("02-map");
            start.PresentUpgrades(); await Capture("03-upgrades");

            foreach (var (city, day, label) in new[]
            {
                (StableIds.Cities.Tianjin, 8, "04-tianjin-day8"),
                (StableIds.Cities.Tianjin, 4, "05-tianjin-day4"),
                (StableIds.Cities.Wuhan, 2, "06-wuhan-day2")
            })
            {
                if (!main.StartCityBusiness(city, day)) throw new InvalidOperationException("Cannot open " + label);
                var active = city == StableIds.Cities.Tianjin
                    ? (Control)main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen")
                    : main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen");
                active._Notification((int)NotificationApplicationFocusIn);
                var controller = main.GetNode<DayController>("DayController");
                controller.Tick(.6); active._Process(0);
                await Frames(40);
                if (active is TianjinDayScreen tj) tj.FinishDemoLesson();
                else ((WuhanDayScreen)active).FinishWuhanDemoLesson();
                active._Notification((int)NotificationApplicationFocusIn);
                controller.Tick(12);
                active._Process(0);
                if (active is TianjinDayScreen tianjin) tianjin.TeachingFocus.Dismiss();
                else ((WuhanDayScreen)active).TeachingFocus.Dismiss();
                GD.Print($"STORE_STATE {label} {controller.State} tutorial={controller.TutorialActive} customers={controller.CustomerQueue?.Slots.Count}");
                await Capture(label);
                controller.AbandonDay();
            }
            GD.Print("STORE_CAPTURE_OK");
            GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
