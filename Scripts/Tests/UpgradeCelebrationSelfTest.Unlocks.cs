using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class UpgradeCelebrationSelfTest
{
    private async Task CheckDayUnlocks(DataCatalog catalog)
    {
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            for (int day = 1; day <= 18; day++)
            {
                Check(catalog.TryGetDay(city, day, out var config), "unlock day available");
                var items = DayUnlockPresentation.ForDay(catalog, config);
                int expected = city == StableIds.Cities.Tianjin
                    ? day switch { 2 => 2, 3 or 5 or 6 => 1, _ => 0 }
                    : day switch { 3 => 1, 4 => 6, _ => 0 };
                Check(items.Count == expected, $"{city} day {day}: expected {expected}, got {items.Count}");
                Check(items.Select(i => i.Id).Distinct().Count() == items.Count, "unique unlock entities");
                if (expected == 0) continue;
                var save = Fixture(ExperienceProfile.IsDemo, $"unlock-{city.Replace(':', '-')}-{day}");
                if (TutorialOrders.UnlockFor(config) is { } lesson)
                    save.Data.GetCity(city).LearnedWorkbenchActions.UnionWith(lesson.Actions);
                save.Data.Wuhan.LearnedWorkbenchActions.Add("take:" + StableIds.Ingredients.WuhanBraisedBeef);
                if (city == StableIds.Cities.Wuhan && day < 4) save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 0;
                var controller = new DayController(); AddChild(controller);
                Control screen;
                Action begin;
                TutorialFocusLayer teaching;
                if (city == StableIds.Cities.Tianjin)
                {
                    var view = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(view);
                    view.ConnectController(controller); Check(view.Initialize(catalog, save, controller, day), "unlock Tianjin initialize");
                    screen = view; begin = view.BeginDay; teaching = view.TeachingFocus;
                }
                else
                {
                    var view = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(view);
                    view.ConnectController(controller); Check(view.Initialize(catalog, save, controller, day), "unlock Wuhan initialize");
                    screen = view; begin = view.BeginDay; teaching = view.TeachingFocus;
                }
                teaching.Resolve = () => null; teaching.Refresh(); screen.SetProcess(false);
                var effect = screen.GetNode<EquipmentUpgradeCelebration>("UpgradeCelebration"); effect.SetProcess(false);
                string upgraded = city == StableIds.Cities.Tianjin ? "pancake_stove" : "noodle_cooker";
                save.Data.GetCity(city).PendingUpgradeCelebrations[upgraded] = 2;
                save.Data.GetCity(city).EquipmentLevels[upgraded] = 2;
                begin(); JourneyTransition.For(screen).Finish(); screen._Process(0);
                effect._Notification((int)NotificationApplicationFocusIn);
                Check(effect.IsPlaying, $"opening queues unlocks {city} {day}: state={controller.State}, tutorial={controller.TutorialActive}");
                effect.NotifyUse(upgraded); effect.NotifyUse(upgraded);
                effect._Process(.45);
                Check(effect.Visible && effect.CurrentCaption.StartsWith("新解锁："), "unlock caption is visible");
                Check(effect.HighlightedIds.Order().SequenceEqual(items.Select(item => item.Id).Order()), "all new unlocks highlight together");
                Check(items.All(item => effect.CurrentCaption.Contains(item.Name)), "unlock caption names every highlighted item");
                Check(save.Data.GetCity(city).PendingUpgradeCelebrations.ContainsKey(upgraded), "unlocks do not consume upgrade cue");
                if (_capture)
                {
                    await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                    using var image = GetViewport().GetTexture().GetImage();
                    Check(image.SavePng(Path.Combine(_dir, $"unlock-{city.Replace(':', '-')}-{day}-all.png")) == Error.Ok, "unlock capture");
                }
                controller.SetPauseReason("unlock-test", true); effect._Process(10);
                Check(effect.IsPlaying && !effect.Visible && !effect.AudioPlaying, "unlock pause retains queue");
                controller.SetPauseReason("unlock-test", false); effect._Process(.01);
                Check(effect.Visible && !effect.AudioPlaying, "unlock resume is silent");
                effect._Notification((int)NotificationApplicationFocusOut); effect._Process(10);
                Check(!effect.Visible && effect.IsPlaying && !effect.AudioPlaying, "focus suspends unlock");
                effect._Notification((int)NotificationApplicationFocusIn); effect._Process(.01);
                Check(effect.Visible && !effect.AudioPlaying, "focus resumes silently");
                effect._Process(3);
                effect._Process(.2);
                Check(effect.CurrentCaption.Contains(EquipmentUpgradePresentation.FirstUse(upgraded, 2)), $"upgrade follows unlocks {city} {day}: {effect.CurrentCaption}, pending={save.Data.GetCity(city).PendingUpgradeCelebrations.Count}, paused={controller.IsPaused}, playing={effect.IsPlaying}");
                effect._Process(3); Check(!effect.IsPlaying, "duplicate use does not duplicate upgrade");
                Check(controller.TryPrepareDay(city, day, catalog, out _), "prepare same day reentry");
                effect.BeforeTeaching(controller, () => controller.TryStartDay(out _)); Check(effect.IsPlaying, "same day reentry repeats unlocks");
                ProjectSettings.SetSetting("accessibility/reduce_motion", true);
                effect._Process(.5); Check(effect.Visible, "reduced motion keeps unlock caption");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                screen.Hide(); Check(!effect.IsPlaying && !effect.AudioPlaying, "leaving clears unlocks");
                Check(controller.TryPrepareTutorial(city, day, catalog, out _), "unlock tutorial prepare");
                controller.TryStartDay(out _); effect.Begin(save, controller, out _);
                Check(!effect.IsPlaying, "independent tutorial has no unlock cue");
                screen.QueueFree(); controller.QueueFree(); await Frames(); save.Free();
            }
        }
    }
}
