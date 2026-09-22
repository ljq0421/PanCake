using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class AbandonNavigationSelfTest : Node
{
    public override async void _Ready()
    {
        try
        {
            var save = GetNode<SaveService>("/root/SaveService");
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            string output = Path.Combine(Path.GetTempPath(), "cake-abandon-navigation");
            Directory.CreateDirectory(output);
            settings.UsePathForTests(Path.Combine(output, "settings.cfg"));
            InterfaceLessons.MarkAllSeen(settings);
            foreach (bool demo in new[] { ExperienceProfile.IsDemo })
            {
                string path = Path.Combine(output, (demo ? "demo" : "full") + ".json");
                if (demo) save.UseDemoPathForTests(path); else save.UsePathForTests(path);
                Require(save.ResetProgress(out _), "reset isolated save");
                save.Data.UnlockedCityIds.Add("city:wuhan");
                save.Data.Tianjin.HighestUnlockedDay = save.Data.Wuhan.HighestUnlockedDay = 2;
                Require(save.TrySave(out _), "save fixture");
                var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
                AddChild(main);
                var controller = main.GetNode<DayController>("DayController");
                controller.SetProcess(false);
                foreach (string city in new[] { "Tianjin", "Wuhan" })
                {
                    string id = "city:" + city.ToLowerInvariant();
                    Require(main.StartCityBusiness(id, 2), "start " + city);
                    var screen = main.GetNode<Control>("UI/" + city + "DayScreen");
                    screen._Notification((int)NotificationApplicationFocusIn);
                    controller.Tick(4);
                    await Frames();
                    JourneyTransition.For(this).Finish();
                    ((BusinessHud)screen.FindChild("BusinessHud", true, false)).PauseButton.EmitSignal(Button.SignalName.Pressed);
                    Require(controller.IsPaused, "pause " + city);
                    screen.Descendants<Button>().First(b => b.IsVisibleInTree() && b.Text == "放弃本日").EmitSignal(Button.SignalName.Pressed);
                    await Frames();
                    var dialog = screen.Descendants<ConfirmationDialog>().First(d => d.Visible);
                    dialog.Hide();
                    dialog.EmitSignal(ConfirmationDialog.SignalName.Confirmed);
                    await Frames();
                    var start = main.GetNode<StartScreen>("UI/StartScreen");
                    Require(start.Visible && !screen.Visible && start.Page == JourneyPage.City
                        && start.SelectedCityId == id && start.SelectedDay == 2, "return to current city/day");
                    Require(save.Data.GetCity(id).DayBestRecords.Count == 0, "abandon records no result");
                    GD.Print($"PASS abandon navigation {(demo ? "demo" : "full")} {city}");
                }
                main.QueueFree();
                await Frames();
            }
            GD.Print("ABANDON_NAVIGATION_PASS");
            GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private static void Require(bool ok, string message) { if (!ok) throw new Exception(message); }
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
}
