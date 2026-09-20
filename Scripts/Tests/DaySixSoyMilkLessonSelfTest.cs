using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
namespace ProjectCake.Tests;
// Guard the shared Day 5 unlock and removal of the old isolated pilot Day 6 lesson.
public partial class DaySixSoyMilkLessonSelfTest : Node
{
    public override async void _Ready()
    {
        try
        {
            var save = GetNode<SaveService>("/root/SaveService");
            string dir = ProjectSettings.GlobalizePath("user://demo-qa-artifacts/formal-soy-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(dir); save.UseDemoPathForTests(Path.Combine(dir, "save.json")); save.ResetProgress(out _);
            save.Data.Tianjin.HighestUnlockedDay = 9; save.TrySave(out _);
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); AddChild(main);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            var controller = main.GetNode<DayController>("DayController");
            foreach (int day in new[] { 4, 5, 6, 9 })
            {
                if (!main.StartCityBusiness(StableIds.Cities.Tianjin, day) || controller.TutorialActive
                    || controller.CurrentConfig!.AvailableProductKinds.Contains(ProductKind.SoyMilk) != (day >= 5))
                    throw new Exception("Both profiles unlock soy milk on Day 5 without a separate Day 6 lesson.");
                controller.AbandonDay();
            }
            GD.Print("DAY_SIX_SOY_MILK_LESSON_SELF_TEST_OK"); GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
}
