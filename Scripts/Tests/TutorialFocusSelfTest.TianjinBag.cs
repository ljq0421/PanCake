using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TutorialFocusSelfTest
{
    private async Task TianjinBag(DataCatalog catalog, SaveService save)
    {
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        settings.UsePathForTests(Path.Combine(_directory, "bag-settings.cfg"));
        InterfaceLessons.MarkAllSeen(settings);
        var scene = GD.Load<PackedScene>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
        foreach (int day in new[] { 1, 3, 8 })
        {
            save.Data.Tianjin.LearnedWorkbenchActions.Remove("bag");
            save.Data.Tianjin.HighestUnlockedDay = 12;
            var controller = new DayController(); AddChild(controller);
            var screen = scene.Instantiate<TianjinDayScreen>();
            _viewport.AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
            Check(screen.Initialize(catalog, save, controller, day), "bag shift initializes");
            Check(controller.TryStartDay(out _), "start capture shift without unlock celebration");
            controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(1);
            screen._Notification((int)NotificationApplicationFocusIn);
            var station = screen.GetNode<PancakeWorkstation>("PancakeWorkstation");
            station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions.Where(a => a != "bag"));
            station.Machine.Runtime.State = PancakeState.Folded;
            screen.RefreshForCapture(true); screen.TeachingFocus.Refresh(); await Frames();
            screen._Notification((int)NotificationApplicationFocusIn);
            screen.RefreshForCapture(true); screen.TeachingFocus.Refresh();
            var focus = screen.TeachingFocus;
            Check(focus.CurrentAction == "bag", $"folded pancake highlights paper stack: day={day}, action={focus.CurrentAction}, paused={controller.IsPaused}");
            var target = focus.Resolve()!.Targets.Single();
            Check(target.Texture is not null, "resting paper uses background silhouette matte");
            await Shot($"tianjin-bag-day-{day}");
            Vector2 stack = station.BagStackBounds.GetCenter();
            Move(station, stack); Button(station, stack, true);
            Move(station, TianjinWorkbenchLayout.EmbeddedSurface.GetCenter(), true);
            focus.Refresh();
            Check(station.IsDirectDragging && focus.CurrentAction == "bag", "paper pickup keeps bag lesson active");
            Check(focus.Resolve()!.Targets.Single().Texture is null, "held paper highlights stove instead of stack");
            await Shot($"tianjin-bag-held-day-{day}");
            Button(station, TianjinWorkbenchLayout.EmbeddedSurface.GetCenter(), false);
            station.Tick(.4);
            Check(station.Machine.Runtime.State == PancakeState.Bagged, "highlight preserves packaging interaction");
            controller.AbandonDay(); screen.QueueFree(); controller.QueueFree(); await Frames();
        }
    }
}
