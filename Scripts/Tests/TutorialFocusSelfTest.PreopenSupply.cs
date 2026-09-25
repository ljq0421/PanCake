using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TutorialFocusSelfTest
{
    private async Task TianjinPreopenSupply(DataCatalog catalog, SaveService save, string savePath)
    {
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        settings.UsePathForTests(Path.Combine(_directory, "preopen-settings.cfg"));
        InterfaceLessons.MarkAllSeen(settings);
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
        _viewport.AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
        Check(screen.Initialize(catalog, save, controller, 1), "first day initializes");
        screen.BeginDay(); await Frames(); screen._Notification((int)NotificationApplicationFocusIn); screen._Process(.5); screen.RefreshForCapture(true);
        var station = screen.GetNode<PancakeWorkstation>("PancakeWorkstation");
        var focus = screen.TeachingFocus;
        var action = screen.Descendants<Godot.Button>().Single(b => b.Name == "LessonAction");
        Check(controller.TutorialActive && focus.CurrentAction == "take:batter", $"cooking practice precedes supply practice: tutorial={controller.TutorialActive}, focus={focus.CurrentAction}, state={controller.State}");
        void Do(PancakeCommand command) => Check(station.Machine.TryExecute(command).Success, "practice " + command);
        Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread);
        Check(station.Inventory.TryConsume("egg"), "consume the practice egg"); Do(PancakeCommand.AddEgg);
        station.Tick(100); Do(PancakeCommand.Flip); station.Tick(100);
        Do(PancakeCommand.BeginSauce); station.Machine.SetSauceCoverage(1); Do(PancakeCommand.CompleteSauce);
        Do(PancakeCommand.Fold); Do(PancakeCommand.Bag); station.Tick(1); screen.RefreshForCapture(true);
        Check(screen.Descendants<DropZone>().First(z => z.Name.ToString().StartsWith("CustomerDropZone") && z.CanAccept("finished_pancake"))
            .TryAccept("finished_pancake"), "deliver practice pancake");
        screen.RefreshForCapture();
        Check(!screen.DemoLessonComplete && !action.IsVisibleInTree() && controller.TutorialActive
            && focus.CurrentAction == PancakeWorkstation.SupplyIntroductionAction, "supply teaching occurs before start business becomes available");
        await Shot("tianjin-preopen-bell");
        var bell = station.Descendants<Godot.Button>().Single(b => b.Name == "SupplyBell");
        var helper = station.Descendants<Godot.Button>().Single(b => b.Name == "SupplyHelperClick");
        bell.EmitSignal(Godot.Button.SignalName.Pressed); screen.RefreshForCapture();
        await Shot("tianjin-preopen-helper");
        helper.EmitSignal(Godot.Button.SignalName.Pressed); screen.RefreshForCapture();
        Check(station.Inventory.GetQuantity("egg") == 1 && !action.IsVisibleInTree() && focus.CurrentAction == "refill:egg", "one click adds one egg and practice continues until full");
        screen._Notification((int)NotificationApplicationFocusOut);
        helper.EmitSignal(Godot.Button.SignalName.Pressed);
        Check(station.Inventory.GetQuantity("egg") == 1, "unfocused supply practice cannot add stock");
        screen._Notification((int)NotificationApplicationFocusIn);
        bell.EmitSignal(Godot.Button.SignalName.Pressed);
        for (int i = 1; i < station.Inventory.GetCapacity("egg"); i++) helper.EmitSignal(Godot.Button.SignalName.Pressed);
        screen._Process(1); screen.RefreshForCapture();
        Check(screen.DemoLessonComplete && action.IsVisibleInTree() && !focus.Visible, "full stock reveals start business and clears teaching focus");
        Check(controller.DayElapsedSeconds == 0 && controller.CustomerQueue!.Slots.Count <= 1
            && controller.Ledger!.Build().TotalRevenue == 0, "supply practice has no business time queue or income");
        int eggs = station.Inventory.GetQuantity("egg");
        await Shot("tianjin-preopen-complete");
        Directory.CreateDirectory(savePath + ".tmp");
        screen.FinishDemoLesson();
        Check(controller.TutorialActive && action.Text == "重试保存" && station.Inventory.GetQuantity("egg") == eggs,
            "failed save retains completed supply practice and inventory");
        Directory.Delete(savePath + ".tmp");
        screen.FinishDemoLesson(); controller.Tick(DayController.OpeningDurationSeconds); screen._Process(.01);
        Check(!controller.TutorialActive && station.Inventory.GetQuantity("egg") == eggs, "business inherits all replenished eggs");
        Check(save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.RefillLessonAction)
            && save.Data.Tianjin.LearnedWorkbenchActions.Contains(PancakeWorkstation.SupplyIntroductionAction)
            && focus.CurrentAction != PancakeWorkstation.SupplyIntroductionAction, "completed supply teaching persists and does not repeat after opening");
        await Shot("tianjin-preopen-business");
        screen.QueueFree(); controller.QueueFree(); await Frames();
    }
}
