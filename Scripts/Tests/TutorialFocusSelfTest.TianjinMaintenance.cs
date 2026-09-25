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
        void CallNpc(int clicks = 1)
        {
            var bell = (Godot.Button)station.FindChild("SupplyBell", true, false);
            bell.EmitSignal(Godot.Button.SignalName.Pressed);
            var npc = (Godot.Button)station.FindChild("SupplyHelperClick", true, false);
            for (int i = 0; i < clicks; i++) npc.EmitSignal(Godot.Button.SignalName.Pressed);
        }
        station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions.Where(a => a != PancakeWorkstation.SupplyIntroductionAction));
        Focus();
        Check(focus.CurrentAction == PancakeWorkstation.SupplyIntroductionAction && focus.CurrentText.Contains("右侧"),
            "old saves see the new bell introduction immediately with full stock");
        await Shot("tianjin-supply-intro-bell");
        double introTime = controller.DayElapsedSeconds;
        screen._Process(1);
        Check(controller.DayElapsedSeconds == introTime, "bell introduction freezes the business clock");
        ((Godot.Button)station.FindChild("SupplyBell", true, false)).EmitSignal(Godot.Button.SignalName.Pressed);
        Focus();
        await ToSignal(GetTree().CreateTimer(1.1), SceneTreeTimer.SignalName.Timeout);
        Check(station.SupplyNpcCalled && focus.CurrentText.Contains("送货员"), "full-stock helper waits for the introduction click");
        await Shot("tianjin-supply-intro-helper");
        ((Godot.Button)station.FindChild("SupplyHelperClick", true, false)).EmitSignal(Godot.Button.SignalName.Pressed);
        Focus();
        Check(save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.SupplyIntroductionAction)
            && station.Inventory.GetQuantity("egg") == station.Inventory.GetCapacity("egg"),
            "helper click records the introduction without changing full inventory");
        station.ConfigureTutorial(save.Data.Tianjin.LearnedWorkbenchActions);
        Focus(); Check(focus.CurrentAction != PancakeWorkstation.SupplyIntroductionAction, "remembered introduction does not repeat");
        station.CancelInput();
        station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions.Where(a => a != "discard" && a != PancakeWorkstation.RefillLessonAction));
        Focus(); Check(focus.CurrentAction is null, "full stock does not prompt unnecessary maintenance");
        station.Inventory.TryConsume("egg", station.Inventory.GetCapacity("egg") - 2);
        Focus(); Check(focus.CurrentAction == "refill:egg" && focus.CurrentText.Contains("叫货铃"),
            $"low stock prompts restock before it is empty, even between customers: action={focus.CurrentAction}, text={focus.CurrentText}, paused={controller.IsPaused}, state={controller.State}, tutorial={controller.TutorialActive}");
        double refillLessonTime = controller.DayElapsedSeconds;
        screen._Process(1);
        Check(controller.DayElapsedSeconds == refillLessonTime, "refill lesson freezes the business clock while its instruction is active");
        await Shot("tianjin-low-stock");
        ((Godot.Button)station.FindChild("SupplyBell", true, false)).EmitSignal(Godot.Button.SignalName.Pressed);
        Focus();
        Check(station.SupplyNpcCalled && focus.CurrentText.Contains("送货员")
            && ((Control)station.FindChild("SupplyHelperClick", true, false)).Visible,
            "tutorial points from the bell to the clickable helper");
        await Shot("tianjin-supply-npc");
        station.CancelInput(); Focus();
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
        CallNpc(); Focus();
        Check(station.Inventory.GetQuantity("egg") == 1 && focus.CurrentAction == "refill:egg" && focus.CurrentText.Contains("送货员")
            && !save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction), "one NPC click adds one egg and mastery waits for a full tray");
        await Shot("tianjin-refill-progress");
        screen._Notification((int)NotificationApplicationFocusOut); station.Tick(100); focus.Refresh();
        Check(station.Inventory.GetQuantity("egg") == 1 && !focus.Visible && !save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction),
            "focus pause does not add stock or mark mastery");
        screen._Notification((int)NotificationApplicationFocusIn);
        CallNpc(station.Inventory.GetCapacity("egg") - station.Inventory.GetQuantity("egg")); Focus();
        Check(station.Inventory.GetQuantity("egg") == station.Inventory.GetCapacity("egg") && save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction)
            && focus.CurrentAction != "refill:egg", "completed refill persists mastery and removes the instruction");
        double afterRefillTime = controller.DayElapsedSeconds;
        screen._Process(1);
        Check(controller.DayElapsedSeconds > afterRefillTime, "business clock resumes after the refill lesson completes");
        station.Inventory.TryConsume("egg", station.Inventory.GetCapacity("egg")); station.Machine.Runtime.State = PancakeState.Burnt; Focus();
        Check(focus.CurrentAction is null, "successful maintenance does not repeat instructions");
        // A day reset fills stock without teaching an unfinished refill.
        station.ResetForDay(); station.ConfigureTutorial(Array.Empty<string>()); station.Inventory.TryConsume("egg", 2);
        CallNpc(); station.ResetForDay(); station.Tick(1);
        Check(!station.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction), "reset does not treat an abandoned refill as mastery");
        if (OS.GetCmdlineUserArgs().Contains("--supply-lesson-only"))
        {
            screen.QueueFree(); controller.QueueFree(); await Frames();
            return;
        }
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
        CallNpc(); Focus(); CheckFrozen("first NPC unit");
        Check(station.Inventory.GetQuantity("egg") == 1, "frozen cooking still permits adding one egg");
        screen._Process(.5); Focus(); CheckFrozen("waiting between NPC clicks");
        Check(station.Inventory.GetQuantity("egg") == 1, "stock does not advance without another click");
        CallNpc(station.Inventory.GetCapacity("egg") - 1); Focus(); CheckFrozen("final NPC click");
        Check(station.Inventory.GetQuantity("egg") == station.Inventory.GetCapacity("egg")
            && focus.CurrentAction != "refill:egg", "full egg tray ends the freeze");
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
        Check(focus.CurrentAction != "refill:soy_milk", "one completed restock suppresses soy's duplicate lesson");
        int beforeSoy = soy.Quantity;
        CallNpc(); Focus();
        Check(soy.Quantity == beforeSoy + 1 && station.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction),
            "one NPC click adds one soy cup without reopening the lesson");
        CallNpc(soy.Capacity - soy.Quantity); Focus();
        Check(soy.Quantity == soy.Capacity && station.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction), "soy clicks refill to ten cups and keep the shared lesson");
        station.ConfigureTutorial(new[] { "refill:egg" });
        while (soy.Quantity > 2) TakeSoy(); Focus();
        Check(focus.CurrentAction != "refill:soy_milk", "legacy ingredient-specific refill records suppress the shared lesson");
        screen.QueueFree(); controller.QueueFree(); await Frames();
    }
}
