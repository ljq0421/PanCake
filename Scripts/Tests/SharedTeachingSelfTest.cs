using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Pancake;

namespace ProjectCake.Tests;

/// <summary>Exercise shared protection with full-game content, without enabling the Demo profile.</summary>
public partial class SharedTeachingSelfTest : Node
{
    private int _checks;
    private void Check(bool condition, string message)
    { if (!condition) throw new InvalidOperationException(message); _checks++; GD.Print("PASS " + message); }

    public override async void _Ready()
    {
        DayConfig? config = null;
        var original = TutorialProtection.None;
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = GetNode<SaveService>("/root/SaveService");
            Check(!save.IsDemo && catalog.Demo is null, "test uses full-game content and profile");
            string directory = ProjectSettings.GlobalizePath("res://.tmp/shared-teaching/" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(directory); save.UsePathForTests(Path.Combine(directory, "save.json"));
            Check(save.ResetProgress(out _), "isolated full-game progress created");
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); AddChild(main);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            main.ProcessMode = ProcessModeEnum.Disabled;
            var controller = main.GetNode<DayController>("DayController");
            // Yangzhou uses its own controller and is covered by YangzhouSelfTest.
            foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou })
            {
                Check(controller.TryPrepareDay(city, 1, catalog, out _) && !controller.TutorialActive, city + " ordinary shift has no new tutorial protection");
                controller.TryStartDay(out _); controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(1);
                Check(controller.DayElapsedSeconds == 1, city + " ordinary business clock advances"); controller.AbandonDay();
            }
            Check(controller.TryPrepareTutorial(StableIds.Cities.Tianjin, 1, catalog, out _), "shared guided-example entry accepts full-game content");
            controller.TryStartDay(out _); controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(500);
            Check(controller.CurrentPlan!.Customers.Count == 1 && controller.DayElapsedSeconds == 0
                && controller.CustomerQueue!.Slots.Single().WaitSeconds == 0, "full-game example isolates one customer and freezes business clocks");
            controller.AbandonDay(); Check(!controller.TutorialActive, "abandon clears shared tutorial context");

            catalog.TryGetDay(StableIds.Cities.Tianjin, 1, out config!); original = config.Tutorial;
            config.Tutorial = TutorialProtection.GuidedExample;
            Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 1), "full-game scene accepts explicit tutorial configuration");
            var station = main.GetNode<PancakeWorkstation>("UI/TianjinDayScreen/PancakeWorkstation");
            controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(2);
            station.Paused = false; station.InteractionEnabled = true;
            var machine = station.Machine;
            void Do(PancakeCommand command)
            { var result = machine.TryExecute(command); if (!result.Success) throw new InvalidOperationException(command + ": " + result.Message); }
            Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread);
            station.Tick(100);
            Check(machine.Runtime.CookingSeconds == 0, "configured workbench waits for egg");
            Do(PancakeCommand.AddEgg); station.Tick(100); station.Tick(100);
            Check(machine.Runtime.State == PancakeState.SideAReady, "configured workbench protects first-side heat");
            Do(PancakeCommand.Flip); station.Tick(100); station.Tick(100);
            Check(machine.Runtime.State == PancakeState.SideBReady, "configured workbench protects second-side heat");
            Do(PancakeCommand.BeginSauce); machine.SetSauceCoverage(1); Do(PancakeCommand.CompleteSauce);
            Do(PancakeCommand.Fold); Do(PancakeCommand.Bag); station.Tick(1);
            var result = station.DeliverPancakeTo(controller, controller.CustomerQueue!.Slots.Single().Id, catalog);
            Check(result.CompletesOrder && controller.Ledger!.Build().TotalRevenue == 0, "example delivery works without business income");
            controller.AbandonDay(); config.Tutorial = original;
            Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 1) && !controller.TutorialActive && !station.Tutorial.IsActive,
                "next normal shift clears controller and workbench protection");
            station.Paused = false; station.InteractionEnabled = true; machine = station.Machine;
            Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg);
            station.Tick(100);
            Check(machine.Runtime.State == PancakeState.Burnt, "ordinary unupgraded stove can still burn");
            GD.Print($"SHARED_TEACHING_SELF_TEST_OK {_checks}"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
        finally { if (config is not null) config.Tutorial = original; }
    }
}
