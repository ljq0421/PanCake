using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class DaySixSoyMilkLessonSelfTest : Node
{
    private int _checks;

    private void Check(bool value, string message)
    {
        if (!value) throw new InvalidOperationException(message);
        _checks++;
        GD.Print("PASS " + message);
    }

    public override async void _Ready()
    {
        try
        {
            var save = GetNode<SaveService>("/root/SaveService");
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            string directory = ProjectSettings.GlobalizePath($"res://.tmp/day6-soy-lesson/{Guid.NewGuid():N}");
            Directory.CreateDirectory(directory);
            save.UseDemoPathForTests(Path.Combine(directory, "demo.json"), catalog.Demo!);
            Check(save.ResetProgress(out _), "isolated Day 6 demo save created");
            save.Data.Tianjin.HighestUnlockedDay = 6;

            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            AddChild(main);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 6), "Day 6 soy milk lesson starts");

            var controller = main.GetNode<DayController>("DayController");
            var screen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            for (int i = 0; i < 240 && controller.State != DayState.Running; i++)
            {
                controller.Tick(1);
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            }
            Check(controller.State == DayState.Running, "lesson waits for the city transition before serving");
            DropZone? target = null;
            for (int i = 0; i < 12 && target is null; i++)
            {
                controller.Tick(1);
                screen.RefreshForCapture(true);
                screen.TeachingFocus.Refresh();
                target = screen.Descendants<DropZone>().FirstOrDefault(zone => zone.Name.ToString().StartsWith("CustomerDropZone")
                    && zone.CanAccept("soy_milk_cup"));
            }

            Check(target is not null && screen.TeachingFocus.CurrentAction == "deliver:soy_milk_cup"
                && screen.DemoLessonHint.Contains("豆浆"), "lesson directs the first soy milk delivery");
            Check(target!.TryAccept("soy_milk_cup"), "real soy milk delivery is accepted");
            Check(screen.DemoLessonComplete && screen.TeachingFocus.CurrentAction is null
                && !screen.GetNode<Panel>("DemoLesson").Descendants<Label>().Any(label => label.Text == "先递一杯豆浆"),
                "accepted cup clears the Day 6 soy milk prompt");
            GD.Print($"DAY_SIX_SOY_MILK_LESSON_SELF_TEST_OK {_checks}");
            GetTree().Quit();
        }
        catch (Exception error)
        {
            GD.PushError(error.ToString());
            GetTree().Quit(1);
        }
    }
}
