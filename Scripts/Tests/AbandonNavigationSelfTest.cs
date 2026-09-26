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
                string[] cities = demo ? new[] { "Tianjin", "Wuhan" }
                    : new[] { "Tianjin", "Wuhan", "Xian", "Guangzhou", "Yangzhou" };
                foreach (string city in cities)
                {
                    string id = "city:" + city.ToLowerInvariant();
                    save.Data.UnlockedCityIds.Add(id);
                    save.Data.GetCity(id).HighestUnlockedDay = 2;
                }
                Require(save.TrySave(out _), "save fixture");
                var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
                AddChild(main);
                var controller = main.GetNode<DayController>("DayController");
                controller.SetProcess(false);
                foreach (string city in cities)
                {
                    string id = "city:" + city.ToLowerInvariant();
                    Require(main.StartCityBusiness(id, 2), "start " + city);
                    var screen = main.GetNode<Control>("UI/" + city + "DayScreen");
                    screen._Notification((int)NotificationApplicationFocusIn);
                    await Frames();
                    JourneyTransition.For(this).Finish();
                    var dialog = screen.Descendants<ConfirmationDialog>().First();
                    dialog.EmitSignal(ConfirmationDialog.SignalName.Confirmed);
                    await Frames();
                    var start = main.GetNode<StartScreen>("UI/StartScreen");
                    Require(start.Visible && !screen.Visible && start.Page == JourneyPage.City
                        && start.SelectedCityId == id && start.SelectedDay == 2, "return to current city/day");
                    Require(start.GetNode<Control>("Canvas/Background").Visible
                        && start.GetNode<Control>("Letterbox").Visible
                        && !main.GetNode<Node2D>("ShopRoot").Visible,
                        "abandon chapter uses home background");
                    Require(start.GetNode<Control>("Canvas/Modal").Visible
                        && start.GetNode<Control>("Canvas/Page").Visible,
                        "city book overlays home page");
                    Require(save.Data.GetCity(id).DayBestRecords.Count == 0, "abandon records no result");
                    JourneyTransition.For(this).Finish();
                    await Frames();
                    GetViewport().GetTexture()?.GetImage()?.SavePng(Path.Combine(output, $"{(demo ? "demo" : "full")}-{city}.png"));
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
