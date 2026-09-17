using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Pancake;
using ProjectCake.UI;
using ProjectCake.Interaction;

namespace ProjectCake.Tests;

public partial class DemoTutorialSelfTest : Node
{
    private int _checks;
    private void Check(bool value, string message)
    { if (!value) throw new InvalidOperationException(message); _checks++; GD.Print("PASS " + message); }

    private async Task Capture(string state)
    {
        if (!OS.GetCmdlineUserArgs().Contains("--capture")) return;
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string size = OS.GetCmdlineUserArgs().Contains("--small") ? "720" : "1080";
        string directory = ProjectSettings.GlobalizePath("res://.tmp/tutorial-panel/" + size);
        Directory.CreateDirectory(directory);
        using var capture = GetViewport().GetTexture().GetImage();
        Check(capture.SavePng(Path.Combine(directory, state + ".png")) == Error.Ok, "capture tutorial " + state);
    }

    public override async void _Ready()
    {
        try
        {
            var save = GetNode<SaveService>("/root/SaveService");
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            string directory = ProjectSettings.GlobalizePath($"res://.tmp/demo-tutorial-tests/{Guid.NewGuid():N}");
            Directory.CreateDirectory(directory);
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Path.Combine(directory, "settings.cfg"));
            settings.SetLanguage(OS.GetCmdlineUserArgs().Contains("--english") ? "en" : "zh_CN");
            if (settings.Language == "en")
                Check(TranslationServer.Translate("天津") == "Tianjin" && TranslationServer.Translate("第 3 天") == "Day 3", "native English translation supports exact and parameterized text");
            if (OS.GetCmdlineUserArgs().Contains("--small")) GetWindow().Size = new(1280, 720);
            save.UseDemoPathForTests(Path.Combine(directory, "demo.json"), catalog.Demo!);
            Check(save.ResetProgress(out _), "isolated tutorial save created");
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            AddChild(main);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 1), "native game entry starts first-stage lesson");
            var controller = main.GetNode<DayController>("DayController");
            var screen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            var station = screen.GetNode<PancakeWorkstation>("PancakeWorkstation");
            main.ProcessMode = ProcessModeEnum.Disabled;
            Check(controller.TutorialActive && station.Tutorial.ProtectPancakeHeat && screen.DemoLessonVisible, "tutorial owns separate clocks and visible instructions");
            controller.Tick(2);
            Check(controller.CustomerQueue!.Slots.Single().State == CustomerState.Happy, "example customer finishes entering while patience is frozen");
            controller.Tick(500);
            Check(controller.DayElapsedSeconds == 0 && controller.CustomerQueue.Slots.Single().WaitSeconds == 0
                && controller.State == DayState.Running, "waiting cannot expire tutorial or customer");
            station.InteractionEnabled = true;
            var machine = station.Machine;
            machine.TryExecute(PancakeCommand.PlaceBatter);
            machine.TryExecute(PancakeCommand.BeginSpread);
            machine.TryExecute(PancakeCommand.CompleteSpread);
            station.Tick(100);
            Check(machine.Runtime.State == PancakeState.SideACooking && machine.Runtime.CookingSeconds == 0, "teaching waits for the egg before heating");
            machine.TryExecute(PancakeCommand.AddEgg);
            station.Tick(100); station.Tick(100);
            Check(machine.Runtime.State == PancakeState.SideAReady && machine.Runtime.Quality == PancakeQuality.Perfect, "first side reaches ready then waits without burning");
            machine.TryExecute(PancakeCommand.Flip);
            station.Tick(100); station.Tick(100);
            Check(machine.Runtime.State == PancakeState.SideBReady && machine.Runtime.Quality == PancakeQuality.Perfect, "second side reaches ready then waits without burning");
            screen.RefreshForCapture(true);
            await Capture("compact");
            string blockedWrite = Path.Combine(directory, "demo.json.tmp");
            Directory.CreateDirectory(blockedWrite);
            screen.FinishDemoLesson(); screen.RefreshForCapture(true);
            Check(controller.TutorialActive && screen.DemoLessonHint.Contains("未保存"), "lesson save failure remains visible and retryable across rendering");
            await Capture("retry");
            Directory.Delete(blockedWrite);
            screen.FinishDemoLesson();
            Check(!controller.TutorialActive && !station.Tutorial.ProtectPancakeHeat && !screen.DemoLessonVisible
                && controller.State == DayState.Opening, "skip starts clean main business with normal clocks");
            Check(station.Machine.Runtime.State == PancakeState.Empty && station.PancakeTray.Count == 0
                && controller.Ledger!.Build().TotalRevenue == 0 && save.Data.Coins == 0, "example food and money cannot enter main business");
            Check(save.DemoProgress.SkippedTutorials.Contains("demo_tj_01")
                && !save.DemoProgress.CompletedTutorials.Contains("demo_tj_01"), "skip is distinct from mastery");
            Directory.CreateDirectory(blockedWrite);
            controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(1000); controller.Tick(1000);
            Check(screen.BusinessDetails.Model.CanRetry && !screen.BusinessDetails.Model.CanClose, "failed settlement keeps the ledger open with a save retry");
            Directory.Delete(blockedWrite);
            screen.BusinessDetails.Descendants<Button>().Single(b => b.Text == "重试保存").EmitSignal(Button.SignalName.Pressed);
            Check(controller.State == DayState.Results && save.Data.Tianjin.HighestUnlockedDay == 1
                && screen.BusinessDetails.Model.CanClose, "native zero-order settlement saves and offers free retry without unlocking");
            Check(!main.StartCityBusiness(StableIds.Cities.Wuhan, 1) && !main.StartCityBusiness(StableIds.Cities.Tianjin, 2), "native navigation rejects unshipped and locked content");
            screen.ForceDemoTutorial = true;
            Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 1), "skipped lesson can be replayed for free");
            controller.Tick(2); screen.RefreshForCapture(true); station.InteractionEnabled = true;
            machine = station.Machine;
            void Do(PancakeCommand command) { var result = machine.TryExecute(command); if (!result.Success) throw new InvalidOperationException($"{command}: {result.Message}; {machine.Runtime.State}; paused={station.Paused}"); }
            Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread);
            Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg);
            station.Tick(100); Do(PancakeCommand.Flip); station.Tick(100);
            Do(PancakeCommand.BeginSauce); machine.SetSauceCoverage(.7); screen.RefreshForCapture(true);
            var progress = screen.GetNode("DemoGestureProgress").GetChild<ProgressBar>(1);
            Check(progress.IsVisibleInTree() && Math.Abs(progress.Value - .7) < .001, "visible sauce progress comes from actual production state");
            screen.Notification((int)NotificationApplicationFocusOut); station.Tick(100);
            Check(station.Paused && Math.Abs(machine.Runtime.SauceCoverage - .7) < .001, "focus loss cancels input while retaining sauce progress");
            screen.Notification((int)NotificationApplicationFocusIn);
            Check(!station.Paused && controller.TutorialActive, "focus return resumes the same lesson");
            machine.SetSauceCoverage(1);
            Do(PancakeCommand.CompleteSauce); Do(PancakeCommand.Fold); Do(PancakeCommand.Bag);
            station.Tick(1); screen.RefreshForCapture(true);
            Check(station.CanDeliverProduct("finished_pancake"), $"lesson breakfast is ready to drag (state={machine.Runtime.State}, tray={station.PancakeTray.Count}, paused={station.Paused}, enabled={station.InteractionEnabled})");
            var target = screen.Descendants<DropZone>().FirstOrDefault(z => z.Name.ToString().StartsWith("CustomerDropZone") && z.CanAccept("finished_pancake"));
            Check(target is not null && target.TryAccept("finished_pancake"), "finished breakfast accepted by real customer drop callback");
            Check(screen.DemoLessonComplete && controller.Ledger!.Build().TotalRevenue == 0 && save.Data.Coins == 0, "correct lesson delivery completes teaching without income");
            await Capture("complete");
            screen.FinishDemoLesson();
            Check(save.DemoProgress.CompletedTutorials.Contains("demo_tj_01") && !controller.TutorialActive && station.Machine.Runtime.State == PancakeState.Empty, "completed lesson persists then clears example for independent practice");
            CheckDayOneClosing(controller, catalog, save, screen);
            main.QueueFree(); await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            await CheckReturningDayOne(save, false);
            Check(save.ResetProgress(out _), "isolated progress reset for skipped-lesson re-entry");
            Check(save.SaveDemoTutorial("demo_tj_01", true, out _), "skipped lesson persisted before re-entry");
            await CheckReturningDayOne(save, true);
            GD.Print($"DEMO_TUTORIAL_SELF_TEST_OK {_checks}"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }

    private async Task CheckReturningDayOne(SaveService save, bool skipped)
    {
        save.Load();
        var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
        AddChild(main);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 1), "fresh scene re-enters Day 1 after " + (skipped ? "skip" : "completion"));
        main.ProcessMode = ProcessModeEnum.Disabled;
        var controller = main.GetNode<DayController>("DayController");
        var screen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
        controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(2);
        screen.RefreshForCapture(true);
        Check(!controller.TutorialActive && !screen.DemoLessonVisible && controller.DayElapsedSeconds > 0,
            "returning Day 1 runs business without an empty teaching panel");
        await Capture(skipped ? "returning-skipped" : "returning-completed");
        main.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private void CheckDayOneClosing(DayController controller, DataCatalog catalog, SaveService save, TianjinDayScreen screen)
    {
        Check(controller.CurrentConfig!.FinishWhenAllCustomersServed && controller.CurrentConfig.CustomerCount == 4,
            "Demo Day 1 opts into completion without empty countdown waiting");
        Check(catalog.Demo!.Stages.Skip(1).All(s => !s.Config(catalog.RecipesById, catalog.ProductsById).FinishWhenAllCustomersServed),
            "other stages retain their configured closing policy");
        int finished = 0; controller.DayFinished += _ => finished++;
        controller.Tick(DayController.OpeningDurationSeconds);
        for (int served = 0; served < 4; served++)
        {
            for (int i = 0; i < 300 && !controller.CustomerQueue!.Slots.Any(c => c.State == CustomerState.Happy); i++) controller.Tick(.2);
            var customer = controller.CustomerQueue!.Slots.Single(c => c.State == CustomerState.Happy);
            var evaluation = controller.TryDeliverPreparedPancakeTo(customer.Id,
                new PreparedPancake(PancakeQuality.Perfect, new HashSet<string>()), catalog, () => true);
            Check(evaluation.CompletesOrder && controller.State == DayState.Running, "delivery waits for customer exit " + served);
            if (served < 3)
            {
                controller.Tick(.5);
                Check(controller.State == DayState.Running && controller.CustomerQueue.HasUnscheduled,
                    "empty counter does not skip future arrivals " + served);
            }
        }
        controller.IsPaused = true; controller.Tick(10);
        Check(finished == 0 && controller.State == DayState.Running, "paused last exit does not trigger settlement");
        controller.IsPaused = false; controller.Tick(.44);
        Check(finished == 0, "last customer's exit animation is preserved");
        controller.Tick(.02);
        Check(finished == 1 && controller.State == DayState.Results && controller.DayRemainingSeconds > 15
            && controller.CustomerQueue!.IsResolved, "4 of 4 exits settle with time remaining");
        Check(screen.BusinessDetails.Model.Result.CompletedCustomers == 4 && screen.BusinessDetails.Model.CanClose
            && save.Data.Coins == controller.Ledger!.Build().TotalRevenue && save.Data.Tianjin.HighestUnlockedDay == 2,
            "early settlement opens the real ledger, saves income and unlocks Day 2");
        int coins = save.Data.Coins; controller.Tick(1000);
        Check(finished == 1 && save.Data.Coins == coins, "further frames cannot settle or pay twice");
    }
}
