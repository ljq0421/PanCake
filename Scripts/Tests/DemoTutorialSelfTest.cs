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

    private async Task CheckLessonCard(TianjinDayScreen screen, string state)
    {
        screen.RefreshForCapture(true);
        screen.TeachingFocus.Refresh();
        var card = screen.GetNode<Panel>("DemoLesson");
        Check(card.IsVisibleInTree() && !screen.TeachingFocus.DefaultCardVisible, state + " uses one teaching card");
        Check(card.Descendants<Button>().Single(b => b.Text == "跳过教学").IsVisibleInTree(), state + " keeps the skip action in the instruction card");
        Rect2 bounds = card.GetGlobalRect();
        Check(new Rect2(0, 0, 1920, 1080).Encloses(bounds), state + " card stays inside the viewport");
        foreach (var order in screen.Descendants<OrderBubbleView>().Where(o => o.IsVisibleInTree()))
            Check(!bounds.Grow(10).Intersects(order.GetGlobalRect()), state + " keeps customer orders readable");
        var step = screen.TeachingFocus.Resolve();
        Check(step is not null, state + " resolves an operation target");
        float distance = float.MaxValue;
        foreach (var target in step!.Targets)
        {
            Vector2[] points = target.Points.Select(p => target.Owner.GetGlobalTransform() * p).ToArray();
            var targetBounds = new Rect2(points[0], Vector2.Zero);
            foreach (var p in points) targetBounds = targetBounds.Expand(p);
            Check(!bounds.Intersects(targetBounds), state + " instruction does not cover the operation");
            float dx = Mathf.Max(0, Mathf.Max(bounds.Position.X - targetBounds.End.X, targetBounds.Position.X - bounds.End.X));
            float dy = Mathf.Max(0, Mathf.Max(bounds.Position.Y - targetBounds.End.Y, targetBounds.Position.Y - bounds.End.Y));
            distance = Mathf.Min(distance, new Vector2(dx, dy).Length());
        }
        Check(distance <= 36, state + " instruction sits beside its operation");
        Check(screen.DemoLessonHint == step.Text, state + " shows the current operation in the merged card");
        await Capture(state);
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
            InterfaceLessons.MarkAllSeen(settings);
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
            Check(station.Inventory.GetQuantity("egg") == 1, "first guided pancake starts with exactly one egg");
            await CheckLessonCard(screen, "batter");
            Check(screen.TeachingFocus.CurrentAction == "take:batter", "single starting egg does not trigger early refill teaching");
            machine.TryExecute(PancakeCommand.PlaceBatter);
            machine.TryExecute(PancakeCommand.BeginSpread);
            await CheckLessonCard(screen, "spread");
            machine.TryExecute(PancakeCommand.CompleteSpread);
            await CheckLessonCard(screen, "egg");
            station.Tick(100);
            Check(machine.Runtime.State == PancakeState.SideACooking && machine.Runtime.CookingSeconds == 0, "teaching waits for the egg before heating");
            station.Descendants<StockGesture>().Single(g => g.Name == "StockGesture_egg").Tap!.Invoke();
            Check(machine.Runtime.HasEgg && station.Inventory.GetQuantity("egg") == 0, "real egg action consumes the only lesson egg");
            station.Tick(100); station.Tick(100);
            Check(machine.Runtime.State == PancakeState.SideAReady && machine.Runtime.Quality == PancakeQuality.Perfect, "first side reaches ready then waits without burning");
            await CheckLessonCard(screen, "flip");
            machine.TryExecute(PancakeCommand.Flip);
            station.Tick(100); station.Tick(100);
            Check(machine.Runtime.State == PancakeState.SideBReady && machine.Runtime.Quality == PancakeQuality.Perfect, "second side reaches ready then waits without burning");
            await CheckLessonCard(screen, "sauce-brush");
            string blockedWrite = Path.Combine(directory, "demo.json.tmp");
            Directory.CreateDirectory(blockedWrite);
            screen.GetNode<Panel>("DemoLesson").Descendants<Button>().Single(b => b.Text == "跳过教学").EmitSignal(Button.SignalName.Pressed);
            screen.RefreshForCapture(true); screen.TeachingFocus.Refresh();
            Check(controller.TutorialActive && screen.DemoLessonHint.Contains("未保存"), "lesson save failure remains visible and retryable across rendering");
            await Capture("retry");
            Directory.Delete(blockedWrite);
            screen.GetNode<Panel>("DemoLesson").Descendants<Button>().Single(b => b.Text == "重试保存").EmitSignal(Button.SignalName.Pressed);
            Check(!controller.TutorialActive && !station.Tutorial.ProtectPancakeHeat && !screen.DemoLessonVisible
                && controller.State == DayState.Opening, "skip starts clean main business with normal clocks");
            Check(station.Machine.Runtime.State == PancakeState.Empty && station.PancakeTray.Count == 0
                && controller.Ledger!.Build().TotalRevenue == 0 && save.Data.Coins == 0, "example food and money cannot enter main business");
            Check(station.Inventory.GetQuantity("egg") == station.Inventory.GetCapacity("egg"), "skipping the unfinished example keeps the normal stock reset");
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
            Do(PancakeCommand.CompleteSpread);
            Check(station.Inventory.GetQuantity("egg") == 1, "replayed first lesson starts with one egg again");
            station.Descendants<StockGesture>().Single(g => g.Name == "StockGesture_egg").Tap!.Invoke();
            Check(machine.Runtime.HasEgg && station.Inventory.GetQuantity("egg") == 0, "completed example uses the only egg through the real callback");
            station.Tick(100); Do(PancakeCommand.Flip); station.Tick(100);
            Do(PancakeCommand.BeginSauce); machine.SetSauceCoverage(.7); screen.RefreshForCapture(true);
            await CheckLessonCard(screen, "sauce-stroke");
            var stroke = station.Descendants<StrokeInteractor>().Single();
            stroke.RefreshVisualState();
            Check(screen.GetNodeOrNull("DemoGestureProgress") is null, "redundant gesture progress panel is removed");
            Check(stroke.SauceMeterVisible && Math.Abs(stroke.ResolveSauceAmount!() - .7) < .001, "brush-side sauce progress comes from actual production state");
            screen.Notification((int)NotificationApplicationFocusOut); station.Tick(100);
            Check(!stroke.SauceMeterVisible, "brush-side sauce progress hides on focus loss");
            Check(station.Paused && Math.Abs(machine.Runtime.SauceCoverage - .7) < .001, "focus loss cancels input while retaining sauce progress");
            screen.Notification((int)NotificationApplicationFocusIn);
            Check(!station.Paused && controller.TutorialActive, "focus return resumes the same lesson");
            machine.SetSauceCoverage(1);
            Do(PancakeCommand.CompleteSauce); Do(PancakeCommand.Fold); Do(PancakeCommand.Bag);
            station.Tick(1); screen.RefreshForCapture(true);
            await CheckLessonCard(screen, "delivery");
            Check(station.CanDeliverProduct("finished_pancake"), $"lesson breakfast is ready to drag (state={machine.Runtime.State}, tray={station.PancakeTray.Count}, paused={station.Paused}, enabled={station.InteractionEnabled})");
            var target = screen.Descendants<DropZone>().FirstOrDefault(z => z.Name.ToString().StartsWith("CustomerDropZone") && z.CanAccept("finished_pancake"));
            Check(target is not null && target.TryAccept("finished_pancake"), "finished breakfast accepted by real customer drop callback");
            Check(screen.DemoLessonComplete && controller.Ledger!.Build().TotalRevenue == 0 && save.Data.Coins == 0, "correct lesson delivery completes teaching without income");
            screen.TeachingFocus.Refresh();
            Check(!screen.TeachingFocus.Visible && screen.GetNode<Panel>("DemoLesson").IsVisibleInTree(), "completion retains only the merged lesson card");
            await Capture("complete");
            screen.GetNode<Panel>("DemoLesson").Descendants<Button>().Single(b => b.Text == "开始营业").EmitSignal(Button.SignalName.Pressed);
            Check(save.DemoProgress.CompletedTutorials.Contains("demo_tj_01") && !controller.TutorialActive && station.Machine.Runtime.State == PancakeState.Empty, "completed lesson persists then clears example for independent practice");
            await CheckSecondPancakeRefill(controller, screen, station, save);
            CheckDayOneClosing(controller, catalog, save, screen);
            await CheckDayTwoLearnedActions(main, controller, screen, station, save);
            await CheckContextHintPlacement(main, controller, screen, save);
            main.QueueFree(); await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            await CheckReturningDayOne(save, false);
            Check(save.ResetProgress(out _), "isolated progress reset for skipped-lesson re-entry");
            Check(save.SaveDemoTutorial("demo_tj_01", true, out _), "skipped lesson persisted before re-entry");
            await CheckReturningDayOne(save, true);
            GD.Print($"DEMO_TUTORIAL_SELF_TEST_OK {_checks}"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }

    private async Task CheckSecondPancakeRefill(DayController controller, TianjinDayScreen screen, PancakeWorkstation station, SaveService save)
    {
        Check(station.Inventory.GetQuantity("egg") == 0, "starting business preserves the egg used by the first guided pancake");
        controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(2);
        void Focus() { screen.RefreshForCapture(true); screen.TeachingFocus.Refresh(); }
        Focus();
        Check(screen.TeachingFocus.CurrentAction != "refill:egg", "empty eggs do not interrupt the start of the second pancake");
        var machine = station.Machine;
        Check(machine.TryExecute(PancakeCommand.PlaceBatter).Success && machine.TryExecute(PancakeCommand.BeginSpread).Success,
            "second pancake starts normally");
        Focus();
        Check(screen.TeachingFocus.CurrentAction != "refill:egg", "second pancake spreading is not interrupted by refill teaching");
        Check(machine.TryExecute(PancakeCommand.CompleteSpread).Success, "second pancake reaches the egg step");
        Focus();
        Check(screen.TeachingFocus.CurrentAction == "refill:egg" && screen.TeachingFocus.CurrentText.Contains("0.45"),
            "second pancake egg step triggers long-hold refill teaching");
        await Capture("second-pancake-refill");
        var stock = station.Descendants<StockGesture>().Single(g => g.Name == "StockGesture_egg");
        stock.Tap!.Invoke();
        Check(!machine.Runtime.HasEgg && !station.Inventory.IsRefilling("egg"), "tapping the empty egg box cannot add an egg or refill it");
        using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = stock.Size / 2 }) stock._GuiInput(press);
        station.Tick(.44);
        Check(!station.Inventory.IsRefilling("egg"), "refill waits for the full hold duration");
        station.Tick(.01); stock.Cancel(); Focus();
        Check(station.Inventory.IsRefilling("egg") && screen.TeachingFocus.CurrentText.Contains("等待补满")
            && !save.Data.Tianjin.LearnedWorkbenchActions.Contains("refill:egg"), "long hold begins refill without prematurely completing teaching");
        station.Tick(station.Inventory.LevelData.RefillSeconds); Focus();
        Check(station.Inventory.GetQuantity("egg") == station.Inventory.GetCapacity("egg")
            && save.Data.Tianjin.LearnedWorkbenchActions.Contains("refill:egg"), "refill restores normal capacity and records completion");
        stock.Tap.Invoke();
        Check(machine.Runtime.HasEgg && station.Inventory.GetQuantity("egg") == station.Inventory.GetCapacity("egg") - 1,
            "second pancake can add its egg after refill");
        station.ResetForDay();
        Check(station.Inventory.GetQuantity("egg") == station.Inventory.GetCapacity("egg"), "ordinary reset restores normal stock after the lesson handoff");
    }

    private async Task CheckDayTwoLearnedActions(GameController main, DayController controller, TianjinDayScreen screen,
        PancakeWorkstation station, SaveService save)
    {
        // Earlier cooking fixtures bypass input callbacks. Seed the saved history of a completed first pancake.
        string[] basics = { "take:batter", "spread", "take:egg", "flip", "take:sauce", "sauce", "fold", "bag", "deliver:finished_pancake" };
        foreach (string action in basics) station.LearnWorkbenchAction(action);
        Check(save.TrySave(out _), "first-day learned actions saved before advancing");
        save.Load();
        Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 2), "Day 2 starts its new topping lesson");
        controller.Tick(2);
        void Focus() { screen.RefreshForCapture(true); screen.TeachingFocus.Refresh(); }
        void Known(string state)
        {
            Focus();
            Check(screen.TeachingFocus.CurrentAction is null && screen.DemoLessonHint.Length == 0,
                "Day 2 does not repeat learned " + state + " in spotlight or lesson copy");
        }
        void Do(PancakeCommand command)
        {
            var result = station.Machine.TryExecute(command);
            Check(result.Success, "Day 2 fixture " + command);
        }
        void CookToToppings()
        {
            Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Known("spreading");
            Do(PancakeCommand.CompleteSpread); Known("egg"); Do(PancakeCommand.AddEgg);
            station.Tick(100); Known("flip"); Do(PancakeCommand.Flip);
            station.Tick(100); Known("take sauce"); Do(PancakeCommand.BeginSauce); Known("brushing");
            station.Machine.SetSauceCoverage(1); Do(PancakeCommand.CompleteSauce); Focus();
        }
        void Deliver()
        {
            Do(PancakeCommand.Fold); Known("bagging"); Do(PancakeCommand.Bag);
            station.Tick(1); Known("delivery");
            var target = screen.Descendants<DropZone>().First(z => z.Name.ToString().StartsWith("CustomerDropZone") && z.CanAccept("finished_pancake"));
            Check(target.TryAccept("finished_pancake"), "Day 2 uses the real delivery callback");
        }
        Focus();
        Check(controller.TutorialActive && basics.All(station.LearnedWorkbenchActions.Contains)
            && !station.LearnedWorkbenchActions.Contains("take:crispy"), "new lesson inherits saved basics but keeps the new topping unlearned");
        Known("batter");
        Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Known("spreading");
        await Capture("day2-known-spread");
        // Finish a wrong example without the newly required topping, then exercise its automatic retry.
        Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg); station.Tick(100);
        Do(PancakeCommand.Flip); station.Tick(100); Do(PancakeCommand.BeginSauce);
        station.Machine.SetSauceCoverage(1); Do(PancakeCommand.CompleteSauce); Focus();
        Check(screen.TeachingFocus.CurrentAction == "take:crispy", "Day 2 still teaches the new crispy topping");
        Deliver();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        controller.Tick(2); Focus();
        Check(controller.TutorialActive && !screen.DemoLessonComplete && basics.All(station.LearnedWorkbenchActions.Contains),
            "wrong delivery retries the new lesson without clearing learned basics");
        Known("batter after retry");
        CookToToppings();
        Check(screen.TeachingFocus.CurrentAction == "take:crispy" && screen.DemoLessonHint.Contains("薄脆"),
            "retried lesson targets crispy in the merged teaching card");
        await Capture("day2-crispy");
        Check(station.Descendants<DropZone>().Single(z => z.Name == "PancakeDropZone").TryAccept("crispy"),
            "real ingredient drop teaches crispy");
        Known("folding after crispy");
        Check(!save.Data.Tianjin.LearnedWorkbenchActions.Contains("take:crispy"), "new action waits for successful lesson completion before saving");
        Deliver();
        Check(screen.DemoLessonComplete, "correct crispy pancake completes the new lesson");
        screen.FinishDemoLesson();
        save.Load();
        Check(save.DemoProgress.CompletedTutorials.Contains("demo_tj_02")
            && basics.All(save.Data.Tianjin.LearnedWorkbenchActions.Contains)
            && save.Data.Tianjin.LearnedWorkbenchActions.Contains("take:crispy"), "completion saves the new action alongside all previous actions");
        screen.ForceDemoTutorial = true;
        Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 2), "explicit replay can reopen a completed topping lesson");
        controller.Tick(2); Focus();
        Check(screen.TeachingFocus.CurrentAction == "take:batter" && !station.LearnedWorkbenchActions.Contains("spread"),
            "explicit replay shows the full basic sequence");
        Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Focus();
        Check(screen.TeachingFocus.CurrentAction == "spread" && screen.DemoLessonHint.Contains("摊"), "explicit replay teaches spreading again");
        await Capture("day2-explicit-replay");
        screen.FinishDemoLesson();
        Check(basics.All(save.Data.Tianjin.LearnedWorkbenchActions.Contains)
            && save.Data.Tianjin.LearnedWorkbenchActions.Contains("take:crispy"), "skipping replay preserves all saved learning");
    }

    private async Task CheckContextHintPlacement(GameController main, DayController controller, TianjinDayScreen screen, SaveService save)
    {
        save.Data.Tianjin.HighestUnlockedDay = 3;
        Check(save.SaveDemoTutorial("demo_tj_03", true, out _), "skip Day 3 guided lesson to exercise its context hint");
        var card = screen.GetNode<Panel>("DemoLesson");
        card.Position = new(700, 160);
        Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 3), "Day 3 starts context guidance after an earlier lesson");
        controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(2);
        screen.RefreshForCapture(true); screen.TeachingFocus.Refresh();
        Check(screen.DemoLessonVisible && card.Descendants<Button>().Any(b => b.Text == "收起提示"), "Day 3 context hint remains dismissible");
        Check(screen.TeachingFocus.CurrentAction is null && screen.DemoLessonHint.Contains("香葱"), "Day 3 shows context without repeating learned batter teaching");
        var orders = screen.Descendants<OrderBubbleView>().Where(o => o.IsVisibleInTree()).ToArray();
        Check(orders.Length > 0, "context fixture displays a customer order");
        Check(orders.All(o => !card.GetGlobalRect().Grow(10).Intersects(o.GetGlobalRect())), "context hint clears orders after changing lessons");
        Check(new Rect2(0, 0, 1920, 1080).Encloses(card.GetGlobalRect()), "context hint stays in the viewport");
        await Capture("day3-context-orders");
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
        Check(controller.CurrentConfig!.CustomerCount == 4,
            "Demo Day 1 retains four customers under the shared closing policy");
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
