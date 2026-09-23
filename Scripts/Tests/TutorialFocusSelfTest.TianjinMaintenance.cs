using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TutorialFocusSelfTest
{
    private async Task TianjinMaintenance(DataCatalog catalog, SaveService save)
    {
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        settings.UsePathForTests(Path.Combine(_directory, "maintenance-settings.cfg"));
        InterfaceLessons.MarkAllSeen(settings);
        // Exercise ordinary business maintenance rather than the separate first-meal/unlock lessons.
        save.Data.Tianjin.LearnedWorkbenchActions.UnionWith(PancakeWorkstation.AllWorkbenchActions
            .Where(a => a != "discard" && a != PancakeWorkstation.RefillLessonAction));
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
        _viewport.AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
        Check(screen.Initialize(catalog, save, controller, 1), "maintenance shift initializes");
        screen.BeginDay(); controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(1);
        screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
        var station = screen.GetNode<PancakeWorkstation>("PancakeWorkstation");
        var focus = screen.TeachingFocus;
        var drag = station.GetChildren().OfType<DragService>().Single();
        var stock = station.Descendants<StockGesture>().Single(g => g.Name == "StockGesture_egg");
        var trash = station.Descendants<DropZone>().Single(z => z.Name == "TrashZone");
        Control canvas = (Control)station.FindChild("PancakeCanvas", true, false);
        station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions.Where(a => a != "discard" && a != PancakeWorkstation.RefillLessonAction));
        void Focus() { screen.RefreshForCapture(); focus.Refresh(); }
        void Right(bool pressed, Vector2 at)
        {
            using var input = new InputEventMouseButton { ButtonIndex = MouseButton.Right, Pressed = pressed, Position = at };
            if (drag.IsDragging) drag._Input(input); else station.HandleRightFoodInput(input);
        }
        void HoldEgg(double seconds)
        {
            using var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = stock.Size / 2 };
            stock._GuiInput(press); station.Tick(seconds);
        }
        void ReleaseEgg()
        {
            using var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = stock.GetGlobalRect().GetCenter() };
            stock._Input(release);
        }
        Focus(); Check(focus.CurrentAction is null, "full stock does not prompt unnecessary maintenance");
        station.Inventory.TryConsume("egg", station.Inventory.GetCapacity("egg") - 2);
        Focus(); Check(focus.CurrentAction == "refill:egg" && focus.CurrentText.Contains("左键") && focus.CurrentText.Contains("0.45"),
            $"low stock prompts restock before it is empty, even between customers: action={focus.CurrentAction}, text={focus.CurrentText}, paused={controller.IsPaused}, state={controller.State}, tutorial={controller.TutorialActive}");
        double refillLessonTime = controller.DayElapsedSeconds;
        screen._Process(1);
        Check(controller.DayElapsedSeconds == refillLessonTime, "refill lesson freezes the business clock while its instruction is active");
        await Shot("tianjin-low-stock");
        station.Descendants<DragItem>().Single(d => d.PayloadId == "batter").TryBeginDrag(); Focus();
        Check(focus.CurrentAction != "refill:egg", "restock hint does not interrupt a held ingredient"); station.CancelInput();
        station.Machine.TryExecute(PancakeCommand.PlaceBatter); Focus();
        Check(focus.CurrentAction != "refill:egg" && focus.CurrentAction != "discard", "normal food and spreading do not prompt maintenance");
        station.Machine.TryExecute(PancakeCommand.BeginSpread); station.Machine.TryExecute(PancakeCommand.CompleteSpread);
        station.Inventory.TryConsume("egg", 2); Focus();
        Check(focus.CurrentAction == "refill:egg", "missing egg immediately prompts refill while production is blocked");
        station.Machine.Runtime.State = PancakeState.Saucing; Focus();
        Check(focus.CurrentAction != "refill:egg", "restocking does not interrupt brushing");
        station.Machine.Runtime.State = PancakeState.Burnt; station.Machine.Runtime.Quality = PancakeQuality.Burnt; Focus();
        Check(focus.CurrentAction == "discard" && focus.CurrentText.Contains("右键 0.45"), "first burnt pancake takes priority over low stock");
        await Shot("tianjin-discard-hold");
        Vector2 food = canvas.GetGlobalRect().GetCenter();
        Right(true, food); station.Tick(.44); Right(false, food); Focus();
        Check(!drag.IsDragging && focus.CurrentAction == "discard" && !save.Data.Tianjin.LearnedWorkbenchActions.Contains("discard"),
            "short right click neither discards nor teaches");
        Right(true, food); station.Tick(.45); Focus();
        Check(drag.IsDragging && focus.CurrentAction == "discard" && focus.CurrentText == "拖入垃圾桶，松手丢弃。",
            "real right hold changes the instruction to the bin target");
        await Shot("tianjin-discard-drag");
        station.CancelInput(); Focus();
        Check(station.Machine.Runtime.State == PancakeState.Burnt && focus.CurrentAction == "discard"
            && !save.Data.Tianjin.LearnedWorkbenchActions.Contains("discard"), "cancelled discard remains teachable");
        controller.SetPauseReason("maintenance-test", true); focus.Refresh(); Check(!focus.Visible, "paused maintenance hint is hidden");
        controller.SetPauseReason("maintenance-test", false);
        screen._Notification((int)NotificationApplicationFocusOut); focus.Refresh(); Check(!focus.Visible, "unfocused maintenance hint is hidden");
        screen._Notification((int)NotificationApplicationFocusIn); Focus(); Check(focus.CurrentAction == "discard", "focus return restores needed cleanup");
        Right(true, food); station.Tick(.45);
        Right(false, trash.GetParent<Control>().GetGlobalTransform() * trash.FixedHitRect!.Value.GetCenter());
        await ToSignal(GetTree().CreateTimer(.4), SceneTreeTimer.SignalName.Timeout); Focus();
        Check(station.Machine.Runtime.State == PancakeState.Empty && save.Data.Tianjin.LearnedWorkbenchActions.Contains("discard"),
            "actual drop in bin teaches discard");
        Check(focus.CurrentAction == "refill:egg", "cleanup hands off to missing stock");
        HoldEgg(.2); ReleaseEgg(); Focus();
        Check(!station.Inventory.IsRefilling("egg") && !save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction),
            "short left hold does not restock or teach");
        HoldEgg(.45); ReleaseEgg(); Focus();
        Check(station.Inventory.IsRefilling("egg") && focus.CurrentAction == "refill:egg" && focus.CurrentText.Contains("等待补满")
            && !save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction), "hold starts real refill but mastery waits for completion");
        await Shot("tianjin-refill-progress");
        screen._Notification((int)NotificationApplicationFocusOut); station.Tick(100); focus.Refresh();
        Check(station.Inventory.IsRefilling("egg") && !focus.Visible && !save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction),
            "focus pause freezes refill and does not mark mastery");
        screen._Notification((int)NotificationApplicationFocusIn); station.Tick(station.Inventory.LevelData.RefillSeconds); Focus();
        Check(station.Inventory.GetQuantity("egg") == station.Inventory.GetCapacity("egg") && save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction)
            && focus.CurrentAction != "refill:egg", "completed refill persists mastery and removes the instruction");
        double afterRefillTime = controller.DayElapsedSeconds;
        screen._Process(1);
        Check(controller.DayElapsedSeconds > afterRefillTime, "business clock resumes after the refill lesson completes");
        station.Inventory.TryConsume("egg", station.Inventory.GetCapacity("egg")); station.Machine.Runtime.State = PancakeState.Burnt; Focus();
        Check(focus.CurrentAction is null, "successful maintenance does not repeat instructions");
        // A day reset fills stock without teaching an unfinished refill.
        station.ResetForDay(); station.ConfigureTutorial(Array.Empty<string>()); station.Inventory.TryConsume("egg", 1);
        HoldEgg(.45); ReleaseEgg(); station.ResetForDay(); station.Tick(1);
        Check(!station.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction), "reset does not treat an abandoned refill as mastery");
        controller.AbandonDay(); save.Data.Tianjin.HighestUnlockedDay = 12;
        Check(screen.Initialize(catalog, save, controller, 9), "maintenance with fryer and soy initializes");
        screen.BeginDay(); controller.Tick(DayController.OpeningDurationSeconds); controller.Tick(1); screen.RefreshForCapture(true);
        station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions.Where(a => a != "discard" && a != "fryer:lower" && a != PancakeWorkstation.RefillLessonAction));
        station.LearnWorkbenchAction("fryer:load");
        station.FryerMachine!.Runtime.State = ProjectCake.Fryer.FryerState.Loaded; station.FryerMachine.Runtime.Quantity = 1;
        station.Inventory.TryConsume("egg", station.Inventory.GetCapacity("egg"));
        station.Machine.Runtime.State = PancakeState.SideACooking; Focus();
        Check(focus.CurrentAction == "refill:egg", "missing ingredient has priority over last-used fryer's next step");
        station.FryerMachine.Runtime.State = ProjectCake.Fryer.FryerState.Frying;
        double cookingTime = station.Machine.Runtime.CookingSeconds;
        double fryingTime = station.FryerMachine.Runtime.FrySeconds;
        double businessTime = controller.DayElapsedSeconds;
        var guests = controller.CustomerQueue!.Slots.Select(guest => (Guest: guest, Wait: guest.WaitSeconds)).ToArray();
        void CheckFrozen(string phase)
        {
            Check(station.Machine.Runtime.CookingSeconds == cookingTime
                && station.FryerMachine.Runtime.FrySeconds == fryingTime
                && station.Machine.Runtime.State == PancakeState.SideACooking
                && station.FryerMachine.Runtime.State == ProjectCake.Fryer.FryerState.Frying,
                phase + " freezes pancake and fryer without burning food");
            Check(controller.DayElapsedSeconds == businessTime && guests.All(g => g.Guest.WaitSeconds == g.Wait),
                phase + " freezes business and customer patience");
        }
        screen._Process(100); CheckFrozen("refill instruction");
        stock = station.Descendants<StockGesture>().Single(g => g.Name == "StockGesture_egg");
        HoldEgg(.45); ReleaseEgg(); Focus(); CheckFrozen("refill long hold");
        Check(station.Inventory.IsRefilling("egg"), "frozen cooking still permits starting refill");
        screen._Process(station.Inventory.LevelData.RefillSeconds / 2); Focus(); CheckFrozen("refill progress");
        Check(station.Inventory.IsRefilling("egg") && station.Inventory.GetRefillProgress("egg") > 0,
            "refill itself advances while cooking is frozen");
        screen._Process(station.Inventory.LevelData.RefillSeconds); Focus(); CheckFrozen("refill completion frame");
        Check(!station.Inventory.IsRefilling("egg") && focus.CurrentAction != "refill:egg", "completed refill ends the freeze");
        screen._Process(.05);
        Check(station.Machine.Runtime.CookingSeconds > cookingTime && station.FryerMachine.Runtime.FrySeconds > fryingTime
            && controller.DayElapsedSeconds > businessTime, "all clocks resume after refill without catching up paused time");
        station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions.Where(a => a != "discard" && a != PancakeWorkstation.RefillLessonAction));
        station.Inventory.TryConsume("egg", station.Inventory.GetCapacity("egg")); Focus();
        Check(focus.CurrentAction == "refill:egg", "unlearned refill can be skipped");
        focus.Dismiss(); cookingTime = station.Machine.Runtime.CookingSeconds; fryingTime = station.FryerMachine.Runtime.FrySeconds;
        businessTime = controller.DayElapsedSeconds; screen._Process(.05);
        Check(station.Machine.Runtime.CookingSeconds > cookingTime && station.FryerMachine.Runtime.FrySeconds > fryingTime
            && controller.DayElapsedSeconds > businessTime, "skipping refill guidance releases every clock");
        focus.ResetSession();
        station.Machine.Runtime.State = PancakeState.Burnt; Focus();
        Check(focus.CurrentAction == "discard" && focus.CurrentText.Contains("焦饼"), "burnt pancake wins even after using fryer");
        station.ResetForDay(); station.FryerMachine.Runtime.State = ProjectCake.Fryer.FryerState.Burnt; station.FryerMachine.Runtime.Quantity = 1; Focus();
        Check(focus.CurrentAction == "discard" && focus.CurrentText.Contains("0.45"), "burnt fryer teaches the same right hold");
        station.ResetForDay();
        station.LearnWorkbenchAction(PancakeWorkstation.RefillLessonAction);
        var soy = station.SoyMilkTray!;
        void TakeSoy() { Check(soy.TryConsumeForDelivery(), "consume soy fixture"); soy.Tick(SoyMilkTrayRuntime.TakeSeconds); }
        TakeSoy(); Focus(); Check(focus.CurrentAction != "refill:soy_milk", "one used soy cup does not prompt low-stock restocking");
        while (soy.Quantity > 2) TakeSoy(); Focus();
        Check(focus.CurrentAction != "refill:soy_milk", "one completed restock suppresses soy's duplicate long-press lesson");
        var soyGesture = station.Descendants<StockGesture>().Single(g => g.Name == "StockGesture_soy_milk");
        using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = soyGesture.Size / 2 }) soyGesture._GuiInput(press);
        station.Tick(.45); soyGesture.Cancel(); Focus();
        Check(soy.IsRefilling && station.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction),
            "soy long hold still starts a refill without reopening the lesson");
        station.Tick(SoyMilkTrayRuntime.RefillSeconds); Focus();
        Check(soy.Quantity == soy.Capacity && station.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction), "soy refill completion keeps the single shared lesson");
        station.ConfigureTutorial(new[] { "refill:egg" });
        while (soy.Quantity > 2) TakeSoy(); Focus();
        Check(focus.CurrentAction != "refill:soy_milk", "legacy ingredient-specific refill records suppress the shared lesson");
        screen.QueueFree(); controller.QueueFree(); await Frames();
    }
}
