using Godot;
using System.Text.Json;
using System.Text.Json.Nodes;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Inventory;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;
using ProjectCake.Interaction;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class FullJourneyFeaturesSelfTest : Node
{
    private int _checks;
    private string _dir = "";
    private SubViewport? _captureViewport;
    private void Check(bool ok, string message)
    { if (!ok) throw new InvalidOperationException(message); _checks++; GD.Print("PASS " + message); }
    private async Task Frames(int count = 3)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        for (int i = 0; i < 240 && GetTree().Root.GetNodeOrNull<JourneyTransition>("JourneyTransition")?.Active == true; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    private async Task Capture(string name)
    {
        if (!OS.GetCmdlineUserArgs().Contains("--capture")) return;
        await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = (_captureViewport ?? GetViewport()).GetTexture().GetImage(); image.SavePng(Path.Combine(_dir, name + ".png"));
    }
    private async Task Click(Control control)
    {
        var viewport = control.GetViewport();
        viewport.NotifyMouseEntered();
        var p = control.GetGlobalTransformWithCanvas() * (control.Size / 2);
        viewport.PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
        foreach (bool down in new[] { true, false })
            viewport.PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, Pressed = down, ButtonIndex = MouseButton.Left }, true);
        await Frames();
    }
    public override async void _Ready()
    {
        try
        {
            _dir = ProjectSettings.GlobalizePath("res://.tmp/full-journey-features/" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_dir);
            GetWindow().Size = OS.GetCmdlineUserArgs().Contains("--small") ? new(1280, 720) : new(1920, 1080);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = GetNode<SaveService>("/root/SaveService");
            Check(catalog.IsValid, "full profile uses full content");
            string path = Path.Combine(_dir, "save.json"); save.UsePathForTests(path); Check(save.ResetProgress(out _), "isolated save");
            var old = JsonNode.Parse(File.ReadAllText(path))!; old.AsObject().Remove("BreakfastRecords");
            File.WriteAllText(path, old.ToJsonString()); save.Load();
            Check(!save.HasLoadError && save.Data.BreakfastRecords.Count == 0, "old v3 saves load with empty collection");
            save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
            save.Data.Tianjin.HighestUnlockedDay = 15; save.Data.Wuhan.HighestUnlockedDay = 12;
            save.TrySave(out _);
            var controller = new DayController(); AddChild(controller);
            foreach (var (city, day) in new[] { (StableIds.Cities.Tianjin, 9), (StableIds.Cities.Wuhan, 6) })
            {
                Check(controller.TryPrepareDay(city, day, catalog, out _), "prepare real shift " + city);
                controller.TryStartDay(out _); controller.Tick(3);
                for (int tick = 0; tick < 5000 && controller.State != DayState.Results; tick++)
                {
                    controller.Tick(.2);
                    foreach (var customer in controller.CustomerQueue!.Slots.Where(c => c.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry).ToArray())
                        for (int n = 0; n < customer.Order.Lines.Count; n++)
                        {
                            var line = customer.Order.Lines[n]; int count = customer.Progress.GetRemainingQuantity(n);
                            for (int k = 0; k < count; k++)
                            {
                                DeliveryEvaluation delivery;
                                if (line.ProductKind == ProductKind.Pancake)
                                    delivery = controller.TryDeliverPreparedPancakeTo(customer.Id, new PreparedPancake(PancakeQuality.Perfect,
                                        catalog.RecipesById[line.DefinitionId].ExtraIngredients.ToHashSet(), YoutiaoQuality.Golden), catalog, () => true);
                                else if (line.ProductKind == ProductKind.Youtiao)
                                { var stock = new YoutiaoInventory(1); stock.TryStore(1, YoutiaoQuality.Golden); delivery = controller.TryDeliverYoutiaoTo(customer.Id, stock); }
                                else if (line.ProductKind == ProductKind.SoyMilk) delivery = controller.TryDeliverSoyMilkTo(customer.Id, new SoyMilkTrayRuntime(1));
                                else delivery = controller.TryDeliverWuhanTo(customer.Id, new(line.ProductKind, line.DefinitionId,
                                    WuhanQuality: line.ProductKind == ProductKind.HotDryNoodles ? WuhanFoodQuality.MixedComplete : WuhanFoodQuality.None), () => true);
                                Check(delivery.ItemAccepted || delivery.CompletesOrder, "actual delivery accepted");
                            }
                        }
                }
                Check(controller.State == DayState.Results && controller.Ledger!.Build().LostCustomers == 0, "all orders resolve " + city);
                string before = JsonSerializer.Serialize(save.Data);
                Directory.CreateDirectory(path + ".tmp");
                var model = BusinessBookModel.From(city, controller.Ledger!.Build(), controller.BusinessRecords, catalog);
                BusinessBookSettlement.Commit(model, save, controller.CurrentPlan!, controller.CurrentConfig!, catalog);
                Check(model.CanRetry && JsonSerializer.Serialize(save.Data) == before, "failed save rolls back money, progress and cards");
                Directory.Delete(path + ".tmp");
                BusinessBookSettlement.Commit(model, save, controller.CurrentPlan!, controller.CurrentConfig!, catalog);
                Check(!model.CanRetry && model.Stickers.Any(s => s.StartsWith("早餐新记录：")), "successful retry announces new cards");
                before = JsonSerializer.Serialize(save.Data);
                save.CommitDay(model.Result, controller.CurrentPlan!, controller.CurrentConfig!);
                Check(JsonSerializer.Serialize(save.Data) == before, "duplicate settlement changes nothing");
                save.Load(); Check(!save.HasLoadError, "collection survives reload");
            }
            Check(save.CollectedBreakfastIds.Count() == 5 && save.BreakfastRecordDay("soy_milk") == 9 && save.BreakfastRecordDay("doupi") == 6,
                "five cards retain full-game origin days");
            var plan = new DayPlan(); var stale = new DayPlan();
            var receipt = new DeliveryReceipt(stale.RunId, stale.StageId, new(ProductKind.SoyMilk, "soy_milk"), true, true, false);
            DemoBreakfastCollection.Observe(receipt, plan);
            Check(plan.PendingBreakfastRecords.Count == 0, "full-game run IDs reject stale receipts");
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            if (OS.GetCmdlineUserArgs().Contains("--capture"))
            {
                _captureViewport = new SubViewport { Size = GetWindow().Size, Size2DOverride = new(1920, 1080),
                    Size2DOverrideStretch = true, Disable3D = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
                AddChild(_captureViewport); _captureViewport.AddChild(main);
            }
            else AddChild(main);
            await Frames();
            foreach (var node in main.Descendants<Control>().Where(n => n is TianjinDayScreen or WuhanDayScreen or XianDayScreen or GuangzhouDayScreen or YangzhouDayScreen))
                node.SetProcess(false);
            var screen = main.GetNode<StartScreen>("UI/StartScreen");
            var music = main.GetNode<DemoMusicPlayer>("DemoMusic"); music.SetProcess(false);
            music._Notification((int)NotificationApplicationFocusIn);
            music.SetContext("home", false, 2);
            Check(music.CurrentKey == "home" && music.GetChildren().OfType<AudioStreamPlayer>().Any(p => p.Playing), "full home plays actual stream");
            music.SetContext(StableIds.Cities.Tianjin, false, 2); music.SetContext(StableIds.Cities.Wuhan, true, 2);
            Check(music.CurrentKey == StableIds.Cities.Wuhan && music.DuckGain == .25f && music.GetChildCount() == 2, "bounded city crossfade and pause duck");
            music._Notification((int)NotificationApplicationFocusOut);
            Check(music.GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing || p.StreamPaused), "focus loss freezes streams");
            music._Notification((int)NotificationApplicationFocusIn);
            var settings = GetNode<JourneySettings>("/root/JourneySettings"); settings.UsePathForTests(Path.Combine(_dir, "settings.cfg"));
            settings.SetVolume("music", 0); Check(AudioServer.IsBusMute(AudioServer.GetBusIndex(JourneySettings.MusicBus)), "music slider controls shared bus");
            settings.SetVolume("music", 100);
            music.SetContext(StableIds.Cities.Xian, false, 2);
            Check(music.GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing), "unassigned city does not retain previous city music");
            Button Find(string name) => screen.Descendants<Button>().Single(b => b.Name == name && b.IsVisibleInTree());
            screen.PresentCity(StableIds.Cities.Tianjin); await Frames(); await Capture("full-preparation");
            music._Process(2); Check(music.CurrentKey == StableIds.Cities.Tianjin, "full preparation routes city music");
            screen.PresentHome(); await Frames(); await Click(Find("BreakfastRecords"));
            Check(screen.Page == JourneyPage.Collection && screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("Breakfast_")) == 5, "real home entry opens all five cards");
            await Click(Find("Breakfast_doupi"));
            Check(screen.Descendants<Label>().Any(l => l.Name == "BreakfastOrigin" && l.Text.Contains("第 6 天")), "full collection displays saved origin");
            await Capture("full-collection-zh");
            settings.SetLanguage("en"); screen.PresentBreakfastCollection(); await Capture("full-collection-en"); settings.SetLanguage("zh_CN");
            var dayController = main.GetNode<DayController>("DayController");
            foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
            {
                screen.PresentCity(city); await Frames(); int requestedDay = screen.SelectedDay;
                int coins = save.Data.Coins, highest = save.Data.GetCity(city).HighestUnlockedDay;
                string records = JsonSerializer.Serialize(save.Data.BreakfastRecords);
                string learnedBefore = string.Join(',', save.Data.GetCity(city).LearnedWorkbenchActions.Order());
                var lesson = city == StableIds.Cities.Tianjin ? (Control)main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen") : main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen");
                bool Failed() => lesson is TianjinDayScreen t ? t.DemoLessonFailed : ((WuhanDayScreen)lesson).DemoLessonFailed;
                void TickLesson() { if (lesson is TianjinDayScreen t) t._Process(.1); else ((WuhanDayScreen)lesson)._Process(.1); }
                void WrongDelivery()
                {
                    if (lesson is TianjinDayScreen t)
                    {
                        t.RefreshForCapture(true);
                        var station = t.GetNode<PancakeWorkstation>("PancakeWorkstation"); var machine = station.Machine;
                        void Do(PancakeCommand command) => Check(machine.TryExecute(command).Success, "prepare incorrect practice pancake " + command);
                        Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg);
                        station.Tick(100); Do(PancakeCommand.Flip); station.Tick(100);
                        Do(PancakeCommand.BeginSauce); machine.SetSauceCoverage(.1); Do(PancakeCommand.CompleteSauce); Do(PancakeCommand.Fold); Do(PancakeCommand.Bag);
                        station.Tick(1); t.RefreshForCapture(true);
                        Check(t.Descendants<DropZone>().First(z => z.Name.ToString().StartsWith("CustomerDropZone") && z.CanAccept("finished_pancake")).TryAccept("finished_pancake"), "incorrect pancake uses real drop handler");
                    }
                    else
                    {
                        var w = (WuhanDayScreen)lesson;
                        w.Bowl.TryAddNoodles(NoodleQuality.Optimal); w.Bowl.TryAddBaseSeasoning();
                        w.Bowl.TryAddTopping(StableIds.Ingredients.WuhanChiliOil); w.Bowl.AddMixDistance(500);
                        Check(w.DeliverToCustomer(dayController.CustomerQueue!.Slots.Single().Id, ProductKind.HotDryNoodles), "incorrect noodles use real delivery handler");
                    }
                    Check(Failed(), "incorrect lesson waits for retry " + city);
                }
                Check(!screen.Descendants<Button>().Any(b => b.IsVisibleInTree() && (b.Name == "Back" || b.Name == "ReplayTutorial")), "preparation omits back and tutorial links");
                await Click(Find("Help"));
                await Capture("full-help-" + city.Replace(':', '-'));
                await Click(Find("ReplayTutorial"));
                lesson._Notification((int)NotificationApplicationFocusIn);
                Check(dayController.TutorialActive && dayController.CurrentConfig!.Day == 1 && dayController.CurrentConfig.CityId == city,
                    "replay opens isolated first lesson " + city);
                dayController.Tick(500); dayController.Tick(.01); dayController.Tick(2);
                Check(dayController.DayElapsedSeconds == 0 && dayController.CustomerQueue!.Slots.Single().WaitSeconds == 0, "lesson clocks and patience frozen");
                Check(save.Data.Coins == coins && save.Data.GetCity(city).HighestUnlockedDay == highest
                    && JsonSerializer.Serialize(save.Data.BreakfastRecords) == records, "lesson leaves business rewards unchanged");
                if (city == StableIds.Cities.Tianjin) main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen").RefreshForCapture(true);
                await Capture("full-lesson-" + city.Replace(':', '-'));
                var skip = lesson.Descendants<Button>().Single(b => b.Name == "SkipLesson");
                Check(lesson.Descendants<Button>().Count(b => b.IsVisibleInTree() && b.Text == "跳过教学") == 1, "replayed lesson has only one skip button");
                var pause = lesson.Descendants<Button>().Single(b => b.Name == "HudPause");
                Check(skip.GetGlobalRect().Position.X > 1500 && !skip.GetGlobalRect().Intersects(pause.GetGlobalRect()) && !skip.HasFocus(), "skip fixed clear of pause without default focus");
                WrongDelivery(); TickLesson(); await Frames();
                var action = lesson.Descendants<Button>().Single(b => b.Name == "LessonAction");
                Check(Failed() && action.Text == "重新练习" && !action.Disabled && skip.IsVisibleInTree(), "failure persists with retry and skip");
                Check(!(lesson is TianjinDayScreen focusT ? focusT.TeachingFocus : ((WuhanDayScreen)lesson).TeachingFocus).Visible, "failed lesson stops spotlight");
                await Capture("lesson-failed-zh-" + city.Replace(':', '-'));
                settings.SetLanguage("en"); TickLesson(); await Capture("lesson-failed-en-" + city.Replace(':', '-')); settings.SetLanguage("zh_CN");
                Check(lesson.GetNode<Panel>("DemoLesson").GetChildren().OfType<Label>()
                    .Where(l => l.Visible).All(l => l.GetGlobalRect().End.Y <= action.GetGlobalRect().Position.Y), "translated result text stays above retry button");
                dayController.IsPaused = true; TickLesson();
                var pausedQueue = dayController.CustomerQueue;
                if (lesson is TianjinDayScreen pausedT) pausedT.RetryDemoLesson(); else ((WuhanDayScreen)lesson).RetryWuhanDemoLesson();
                Check(action.Disabled && skip.Disabled && ReferenceEquals(pausedQueue, dayController.CustomerQueue), "paused lesson cannot retry or skip");
                dayController.IsPaused = false; TickLesson();
                lesson._Notification((int)NotificationApplicationFocusOut); TickLesson();
                Check(action.Disabled && skip.Disabled, "failure actions disabled while unfocused");
                lesson._Notification((int)NotificationApplicationFocusIn); TickLesson();
                Check(Failed() && !action.Disabled && !skip.Disabled, "failure survives focus restore");
                Directory.CreateDirectory(path + ".tmp");
                await Click(skip);
                Check(Failed() && action.Text == "重试保存" && dayController.TutorialActive, "failed skip save retains failure and offers save retry");
                Directory.Delete(path + ".tmp");
                await Click(action);
                Check(!dayController.TutorialActive && dayController.CurrentConfig!.Day == requestedDay && dayController.State == DayState.Running,
                    "skip resumes original full-game day " + city);
                Check(dayController.CurrentPlan!.PendingBreakfastRecords.Count == 0, "practice records do not leak");
                Check(string.Join(',', save.Data.GetCity(city).LearnedWorkbenchActions.Order()) == learnedBefore, "failed practice does not persist learned actions");
                dayController.AbandonDay(); main.OpenCity(city); await Frames();
                await Click(Find("Help"));
                await Click(Find("ReplayTutorial")); dayController.Tick(2);
                lesson._Notification((int)NotificationApplicationFocusIn); dayController.Tick(3); dayController.Tick(2);
                WrongDelivery();
                await Click(lesson.Descendants<Button>().Single(b => b.Name == "LessonAction"));
                Check(!Failed() && dayController.TutorialActive, "retry button starts fresh lesson");
                var retryQueue = dayController.CustomerQueue;
                if (lesson is TianjinDayScreen retryT) retryT.RetryDemoLesson(); else ((WuhanDayScreen)lesson).RetryWuhanDemoLesson();
                Check(ReferenceEquals(retryQueue, dayController.CustomerQueue), "duplicate retry does not restart active practice");
                dayController.Tick(2);
                TickLesson();
                if (city == StableIds.Cities.Tianjin)
                {
                    var t = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen"); t.RefreshForCapture(true);
                    var station = t.GetNode<PancakeWorkstation>("PancakeWorkstation"); var machine = station.Machine;
                    void Do(PancakeCommand command) { if (!machine.TryExecute(command).Success) throw new Exception("practice command " + command); }
                    Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg);
                    station.Tick(100); Do(PancakeCommand.Flip); station.Tick(100);
                    Do(PancakeCommand.BeginSauce); machine.SetSauceCoverage(1); Do(PancakeCommand.CompleteSauce); Do(PancakeCommand.Fold); Do(PancakeCommand.Bag);
                    station.Tick(1); t.RefreshForCapture(true);
                    Check(t.Descendants<DropZone>().First(z => z.Name.ToString().StartsWith("CustomerDropZone") && z.CanAccept("finished_pancake")).TryAccept("finished_pancake")
                        && !t.DemoLessonComplete, "pancake replay proceeds to supply practice before opening");
                    t.RefreshForCapture(true);
                    station.Descendants<Button>().Single(b => b.Name == "SupplyBell").EmitSignal(Button.SignalName.Pressed);
                    station.Descendants<Button>().Single(b => b.Name == "SupplyHelperClick").EmitSignal(Button.SignalName.Pressed);
                    t.RefreshForCapture();
                    Check(t.DemoLessonComplete, "supply practice completes before opening");
                }
                else
                {
                    var w = main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen");
                    w.Bowl.TryAddNoodles(NoodleQuality.Optimal); w.Bowl.TryAddBaseSeasoning(); w.Bowl.AddMixDistance(500);
                    Check(w.DeliverToCustomer(dayController.CustomerQueue!.Slots.Single().Id, ProductKind.HotDryNoodles), "full noodle replay completes through real delivery handler");
                }
                Check(dayController.Ledger!.Build().TotalRevenue == 0 && dayController.CurrentPlan!.PendingBreakfastRecords.Count == 0, "completed practice earns no income or cards");
                Directory.CreateDirectory(path + ".tmp");
                void Finish() { if (city == StableIds.Cities.Tianjin) main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen").FinishDemoLesson();
                    else main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen").FinishWuhanDemoLesson(); }
                Finish(); Check(dayController.TutorialActive, "failed lesson save retains retry context");
                Directory.Delete(path + ".tmp"); Finish();
                Check(!dayController.TutorialActive && dayController.CurrentConfig!.Day == requestedDay && save.Data.Coins == coins
                    && JsonSerializer.Serialize(save.Data.BreakfastRecords) == records, "completed practice restores original business without rewards");
                dayController.AbandonDay(); main.OpenCity(city); await Frames();
            }
            await Click(Find("Help")); await Click(Find("MusicCredits"));
            Check(screen.Descendants<Label>().Any(l => l.Name == "CreditsTracks" && l.Text.Contains("Wholesome")), "full help contains credits");
            await Capture("full-credits");
            GD.Print($"FULL_JOURNEY_FEATURES_SELF_TEST_OK {_checks} artifacts={_dir}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
