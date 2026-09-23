using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class WuhanIntroductionSelfTest : Node
{
    private int _checks;
    private void Check(bool ok, string message)
    { if (!ok) throw new Exception(message); _checks++; }
    private async Task Settle()
    { await ToSignal(GetTree().CreateTimer(.9), SceneTreeTimer.SignalName.Timeout); }

    public override async void _Ready()
    {
        try
        {
            string directory = ProjectSettings.GlobalizePath("res://artifacts/wuhan-opening");
            Directory.CreateDirectory(directory);
            GetWindow().Size = new(1280, 720);
            var save = GetNode<SaveService>("/root/SaveService");
            save.UseSlotsForTests(Path.Combine(directory, Guid.NewGuid().ToString("N")), demo: true);
            Check(save.TryCreateSlot(1, out string saveError), "isolated demo save: " + saveError);
            save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Path.Combine(directory, "settings.cfg"));
            InterfaceLessons.MarkAllSeen(settings);
            var screen = GD.Load<PackedScene>("res://Scenes/UI/StartScreen.tscn").Instantiate<StartScreen>();
            AddChild(screen); screen.Initialize(save);
            string? requestedCity = null;
            int requestedDay = 0;
            screen.BusinessRequested += (city, day) => { requestedCity = city; requestedDay = day; };
            await Settle();
            foreach (bool reduced in new[] { false, true })
            {
                settings.SetReduceMotion(reduced);
                settings.SetLanguage("zh_CN");
                screen.PresentCompletion(StableIds.Cities.Tianjin, screen.PresentHome);
                screen.Descendants<Button>().Single(b => b.Name == "Skip").EmitSignal(Button.SignalName.Pressed);
                await Settle();
                Check(screen.Page == JourneyPage.Opening, "Tianjin completion reaches Wuhan introduction");
                var marker = screen.Descendants<TextureRect>().Single(n => n.Name == "WuhanPostcardMarker");
                Check(marker.Modulate == Colors.White && marker.Material is null, "location marker retains original colors");
                Check(!screen.Descendants<Button>().Any(b => b.Name == "Back"), "no extra back action");
                foreach (string locale in new[] { "zh_CN", "en", "zh_CN" })
                {
                    settings.SetLanguage(locale); await Settle();
                    foreach (var label in screen.Descendants<Label>().Where(l => l.Name.ToString().StartsWith("Wuhan")))
                    {
                        Check(label.GetVisibleLineCount() == label.GetLineCount(), "unclipped label " + label.Name);
                        if (locale == "en") Check(!System.Text.RegularExpressions.Regex.IsMatch(label.Tr(label.Text), "[\u4e00-\u9fff]"), "translated " + label.Name);
                    }
                    var button = screen.Descendants<Button>().Single(b => b.Name == "WuhanOpeningContinue");
                    Check(button.HasFocus(), "departure retains keyboard focus");
                    if (!reduced && OS.GetCmdlineUserArgs().Contains("--capture"))
                    {
                        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                        using var picture = GetViewport().GetTexture().GetImage();
                        picture.SavePng(Path.Combine(directory, "wuhan-opening-" + locale + ".png"));
                    }
                }
                screen.Descendants<Button>().Single(b => b.Name == "WuhanOpeningContinue").EmitSignal(Button.SignalName.Pressed);
                await Settle();
                Check(requestedCity == StableIds.Cities.Wuhan && requestedDay == 1,
                    "departure requests Wuhan Day 1 directly");
                requestedCity = null; requestedDay = 0;
            }
            GD.Print("WUHAN_INTRODUCTION_SELF_TEST_OK checks=" + _checks);
            GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
