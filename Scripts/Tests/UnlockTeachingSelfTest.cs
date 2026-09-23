using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class UnlockTeachingSelfTest : Node
{
    private int _checks;
    private SubViewport _viewport = null!;
    private string _output = "";
    private void Check(bool value, string message)
    { if (!value) throw new InvalidOperationException(message); _checks++; GD.Print("PASS " + message); }
    private async Task Frames() { for (int i = 0; i < 4; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Capture(string name)
    {
        if (!OS.GetCmdlineUserArgs().Contains("--capture")) return;
        await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = _viewport.GetTexture().GetImage();
        Check(image.SavePng(Path.Combine(_output, name + ".png")) == Error.Ok, "capture " + name);
    }
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--small");
            _output = ProjectSettings.GlobalizePath("res://.tmp/unlock-teaching/" + (small ? "720" : "1080"));
            Directory.CreateDirectory(_output);
            _viewport = new SubViewport { Size = small ? new(1280, 720) : new(1920, 1080),
                Size2DOverride = new(1920, 1080), Size2DOverrideStretch = true,
                RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Path.Combine(_output, "settings.cfg")); InterfaceLessons.MarkAllSeen(settings);
            if (OS.GetCmdlineUserArgs().Contains("--english")) TranslationServer.SetLocale("en");
            var save = new SaveService(); string path = Path.Combine(_output, Guid.NewGuid() + ".json");
            save.UsePathForTests(path); AddChild(save);
            save.Data.Tianjin.HighestUnlockedDay = 15; save.Data.Wuhan.HighestUnlockedDay = 12;
            foreach (var item in new[] { ("Tianjin", 1), ("Tianjin", 2), ("Tianjin", 3), ("Tianjin", 4), ("Tianjin", 5), ("Tianjin", 6),
                ("Wuhan", 1), ("Wuhan", 2), ("Wuhan", 3), ("Wuhan", 4) })
            {
                bool tianjin = item.Item1 == "Tianjin";
                var learned = tianjin ? save.Data.Tianjin.LearnedWorkbenchActions : save.Data.Wuhan.LearnedWorkbenchActions;
                learned.Clear();
                // Serving a dough stick must not suppress the later filling lesson.
                if (tianjin && item.Item2 == 4) learned.Add("take:youtiao");
                var controller = new DayController(); AddChild(controller);
                Control screen = GD.Load<PackedScene>($"res://Scenes/Gameplay/{item.Item1}DayScreen.tscn").Instantiate<Control>();
                _viewport.AddChild(screen); screen.SetProcess(false);
                var t = screen as TianjinDayScreen; var w = screen as WuhanDayScreen;
                EquipmentUpgradeCelebration? effect = null;
                if (t is not null) t.ConnectController(controller); else w!.ConnectController(controller);
                void Start()
                {
                    bool ok = t is not null ? t.Initialize(catalog, save, controller, item.Item2) : w!.Initialize(catalog, save, controller, item.Item2);
                    Check(ok, $"{item} initializes");
                    if (t is not null) t.BeginDay(); else w!.BeginDay();
                    screen._Notification((int)NotificationApplicationFocusIn);
                    effect = screen.GetNode<EquipmentUpgradeCelebration>("UpgradeCelebration");
                    effect.SetProcess(false);
                    effect._Notification((int)NotificationApplicationFocusIn);
                    int unlockCount = DayUnlockPresentation.ForDay(catalog, controller.CurrentConfig!).Count;
                    if (unlockCount > 0)
                    {
                        Check(controller.State == DayState.Preparing && !controller.TutorialActive
                            && controller.CustomerQueue!.Slots.Count == 0, "unlock cue precedes teaching and customer arrival");
                        effect._Process(.5);
                        Check(effect.Visible && effect.CurrentCaption.StartsWith("新解锁："), "unlock cue is visible before teaching");
                        Check(effect.HighlightedIds.Count == unlockCount, "all new unlocks are highlighted together before teaching");
                        controller.Tick(10);
                        Check(controller.DayElapsedSeconds == 0, "unlock cue does not consume business time");
                        effect._Process(3);
                    }
                    screen._Process(.5);
                }
                void Finish() { if (t is not null) t.FinishDemoLesson(); else w!.FinishWuhanDemoLesson(); }
                void Retry() { if (t is not null) t.RetryDemoLesson(); else w!.RetryWuhanDemoLesson(); }
                Start();
                if (item == ("Tianjin", 4))
                {
                    Check(TutorialOrders.UnlockFor(controller.CurrentConfig!) is null,
                        "youtiao pancake unlock has no lesson");
                    effect!._Process(3);
                    Check(!controller.TutorialActive && controller.CurrentPlan!.Customers.Count == controller.CurrentConfig!.CustomerCount,
                        "youtiao pancake unlock starts the full business day directly");
                    screen.QueueFree(); controller.QueueFree(); await Frames();
                    continue;
                }
                var lesson = TutorialOrders.UnlockFor(controller.CurrentConfig!)
                    ?? (tianjin
                        ? new TutorialOrders.UnlockLesson("第一张煎饼", ProductKind.Pancake, StableIds.Recipes.Basic, "deliver:finished_pancake")
                        : new TutorialOrders.UnlockLesson("基础热干面", ProductKind.HotDryNoodles,
                            StableIds.Recipes.HotDryNoodlesClassic, "deliver:hot_dry_noodles", TutorialOrders.WuhanBaseNoodlesLesson));
                Check(controller.TutorialActive && controller.CurrentPlan!.Customers.Count == 1, $"{item} starts one isolated guest");
                var guest = controller.CustomerQueue!.Slots.Single();
                Check(guest.Order.Lines.Single() == new OrderLineData(lesson.Kind, lesson.DefinitionId, 1), $"{item} practices the unlocked food");
                for (int i = 0; i < 10; i++) controller.Tick(100);
                Check(controller.DayElapsedSeconds == 0 && guest.WaitSeconds == 0 && controller.CustomerQueue.Slots.Count == 1,
                    $"{item} no extra arrivals or patience loss during long practice");
                var focus = t?.TeachingFocus ?? w!.TeachingFocus; focus.Refresh();
                if (item.Item1 == "Tianjin" && item.Item2 is 2 or 6)
                {
                    Check(focus.CurrentAction is null, $"{lesson.Title} skips the earlier pancake-spreading guidance");
                    var station = t!.GetNode<PancakeWorkstation>("PancakeWorkstation");
                    var machine = station.Machine;
                    Check(machine.TryExecute(PancakeCommand.PlaceBatter).Success && machine.TryExecute(PancakeCommand.BeginSpread).Success
                        && machine.TryExecute(PancakeCommand.CompleteSpread).Success && machine.TryExecute(PancakeCommand.AddEgg).Success,
                        $"{lesson.Title} allows the familiar pancake setup without guidance");
                    station.Tick(100);
                    Check(machine.TryExecute(PancakeCommand.Flip).Success, $"{lesson.Title} flips familiar pancake");
                    station.Tick(100);
                    Check(machine.TryExecute(PancakeCommand.BeginSauce).Success, $"{lesson.Title} starts familiar sauce step");
                    machine.SetSauceCoverage(1);
                    Check(machine.TryExecute(PancakeCommand.CompleteSauce).Success, $"{lesson.Title} completes familiar sauce step");
                    focus.Refresh();
                    Check(focus.CurrentAction is not null && lesson.Actions.Contains(focus.CurrentAction),
                        $"{lesson.Title} first guides a newly unlocked topping: {focus.CurrentAction}");
                    controller.AbandonDay(); Start();
                    focus = t.TeachingFocus; focus.Refresh();
                }
                else Check(focus.CurrentAction is not null, $"{item} has actionable guidance");
                await Capture($"{item.Item1}-{item.Item2}-practice");
                var beforeSkip = learned.ToHashSet();
                Finish();
                Check(!controller.TutorialActive && learned.SetEquals(beforeSkip), $"{item} skip starts business without learning");
                controller.AbandonDay(); Start();
                Check(controller.TutorialActive, $"{item} skipped lesson is available on reentry");

                void Deliver(bool wrong = false)
                {
                    var customer = controller.CustomerQueue!.Slots.Single();
                    if (t is not null)
                    {
                        var station = t.GetNode<PancakeWorkstation>("PancakeWorkstation"); t.RefreshForCapture(true);
                        string payload;
                        if (lesson.Kind == ProductKind.Pancake)
                        {
                            var m = station.Machine;
                            void Do(PancakeCommand command, string? ingredient = null) => Check(m.TryExecute(command, ingredient).Success, "practice " + command);
                            Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg);
                            station.Tick(100); Do(PancakeCommand.Flip); station.Tick(100);
                            Do(PancakeCommand.BeginSauce); m.SetSauceCoverage(1); Do(PancakeCommand.CompleteSauce);
                            if (!wrong) foreach (string topping in catalog.RecipesById[lesson.DefinitionId].ExtraIngredients)
                            {
                                Do(PancakeCommand.AddIngredient, topping);
                                if (topping == StableIds.Ingredients.Youtiao) m.TrySetInternalYoutiaoQuality(YoutiaoQuality.Golden);
                            }
                            Do(PancakeCommand.Fold); Do(PancakeCommand.Bag); station.Tick(1); payload = "finished_pancake";
                        }
                        else if (lesson.Kind == ProductKind.Youtiao)
                        {
                            var fryer = station.FryerMachine!;
                            Check(fryer.TryExecute(FryerCommand.LoadOne).Success && fryer.TryExecute(FryerCommand.LowerBasket).Success, "lesson fryer loads and cooks");
                            station.Tick(100);
                            Check(fryer.Runtime.Quality == YoutiaoQuality.Golden && fryer.TryExecute(FryerCommand.RaiseBasket).Success, "lesson protects fryer heat until raising");
                            station.Tick(10); station.Tick(10); payload = "stored_youtiao";
                        }
                        else payload = "soy_milk_cup";
                        t.RefreshForCapture(true);
                        Check(t.Descendants<DropZone>().First(z => z.Name.ToString().StartsWith("CustomerDropZone") && z.CanAccept(payload)).TryAccept(payload), "real customer drop accepts serving");
                    }
                    else
                    {
                        if (lesson.Kind == ProductKind.Doupi)
                        {
                            var pan = w!.Doupi!;
                            Check(pan.TryPourBatter() && pan.TryAddEgg(), "lesson griddle accepts batter and egg");
                            pan.Tick(100);
                            Check(pan.TryFlip() && pan.TryAddFilling(), "lesson protects first side and accepts filling");
                            pan.Tick(100);
                            Check(pan.TryCut(DoupiCutLine.Horizontal) && pan.TryCut(DoupiCutLine.Center)
                                && pan.TransferAvailable(w.DoupiStock) > 0, "lesson protects second side and stores cut doupi");
                        }
                        else
                        {
                            w!.Bowl.TryAddNoodles(NoodleQuality.Optimal); w.Bowl.TryAddBaseSeasoning();
                            if (!wrong) foreach (string topping in catalog.RecipesById[lesson.DefinitionId].ExtraIngredients.Where(id => id != StableIds.Ingredients.WuhanBraisedBeef)) w.Bowl.TryAddTopping(topping);
                            w.Bowl.AddMixDistance(500);
                            if (!wrong && catalog.RecipesById[lesson.DefinitionId].ExtraIngredients.Contains(StableIds.Ingredients.WuhanBraisedBeef)) w.Bowl.TryAddTopping(StableIds.Ingredients.WuhanBraisedBeef);
                        }
                        Check(w!.DeliverToCustomer(customer.Id, lesson.Kind), "real Wuhan delivery accepts serving");
                    }
                }
                if (item is ("Tianjin", 2) or ("Wuhan", 3))
                {
                    Deliver(true);
                    Check(t?.DemoLessonFailed ?? w!.DemoLessonFailed, "wrong recipe fails lesson");
                    Retry(); screen._Process(.5);
                    Check(controller.TutorialActive && controller.CurrentConfig!.Day == item.Item2
                        && controller.CurrentPlan!.Customers.Single().Order.Lines.Single().DefinitionId == lesson.DefinitionId,
                        "retry retains unlock lesson and restores only practice guest");
                }
                Deliver();
                Check(controller.Ledger!.Build().TotalRevenue == 0 && controller.CurrentPlan!.PendingCustomerVisits.Count == 0, "practice earns no revenue or album progress");
                for (int i = 0; i < 10; i++) controller.Tick(10);
                Check(controller.CustomerQueue!.IsResolved && controller.State == DayState.Running, "no replacement guest or settlement after practice");
                screen._Process(.01);
                await Capture($"{item.Item1}-{item.Item2}-complete");
                var beforeSave = learned.ToHashSet();
                Directory.CreateDirectory(path + ".tmp"); Finish();
                learned = tianjin ? save.Data.Tianjin.LearnedWorkbenchActions : save.Data.Wuhan.LearnedWorkbenchActions;
                Check(controller.TutorialActive && learned.SetEquals(beforeSave), "failed save preserves lesson and rolls back learning");
                Directory.Delete(path + ".tmp"); Finish();
                Check(!controller.TutorialActive && controller.CurrentConfig!.Day == item.Item2
                    && controller.CurrentPlan!.Customers.Count == controller.CurrentConfig.CustomerCount, "saved lesson restores full original business plan");
                learned = tianjin ? save.Data.Tianjin.LearnedWorkbenchActions : save.Data.Wuhan.LearnedWorkbenchActions;
                Check(lesson.IsLearned(learned), "successful unlock lesson is learned");
                controller.AbandonDay(); Start();
                Check(!controller.TutorialActive, "learned lesson does not repeat");
                if (item is ("Tianjin", 6) or ("Wuhan", 4))
                {
                    controller.AbandonDay();
                    if (t is not null) t.ForceDemoTutorial = true; else w!.ForceDemoTutorial = true;
                    Start();
                    Check(controller.TutorialActive && controller.CurrentConfig!.Day == 1, "first-course replay remains available from an unlock day");
                    Finish();
                    Check(!controller.TutorialActive && controller.CurrentConfig!.Day == item.Item2, "replay returns to requested business day");
                }
                screen.QueueFree(); controller.QueueFree(); await Frames();
            }
            GD.Print($"UNLOCK_TEACHING_SELF_TEST_OK {_checks} demo={ExperienceProfile.IsDemo}"); GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
}
