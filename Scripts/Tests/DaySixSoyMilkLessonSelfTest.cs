using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
namespace ProjectCake.Tests;
// Soy milk is taught independently on its shared Day 5 unlock, not the old pilot Day 6.
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
                if (!main.StartCityBusiness(StableIds.Cities.Tianjin, day)) throw new Exception("Cannot start unlock day.");
                var celebration = main.GetNode<EquipmentUpgradeCelebration>("UI/TianjinDayScreen/UpgradeCelebration");
                celebration._Notification((int)NotificationApplicationFocusIn);
                for (int step = 0; step < 20 && controller.State == DayState.Preparing; step++) celebration._Process(.5);
                if (controller.TutorialActive != (day <= 6)
                    || controller.CurrentConfig!.AvailableProductKinds.Contains(ProductKind.SoyMilk) != (day >= 5))
                    throw new Exception("Both profiles run independent lessons on the actual unlock days.");
                if (day == 5 && controller.CurrentPlan!.Customers.Single().Order.Lines.Single().ProductKind != ProductKind.SoyMilk
                    || day == 6 && controller.CurrentPlan!.Customers.Single().Order.Lines.Single().DefinitionId != StableIds.Recipes.Ham)
                    throw new Exception("Day 5 teaches soy milk; Day 6 teaches ham, not soy milk.");
                controller.AbandonDay();
            }
            GD.Print("DAY_SIX_SOY_MILK_LESSON_SELF_TEST_OK"); GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
}
