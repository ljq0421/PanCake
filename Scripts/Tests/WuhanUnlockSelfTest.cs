using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class WuhanUnlockSelfTest : Node
{
    private int _checks;
    private string _dir = "";
    private SaveService _save = null!;
    public override async void _Ready()
    {
        try
        {
            _dir = ProjectSettings.GlobalizePath("res://.tmp/wuhan-unlock/" + (ExperienceProfile.IsDemo ? "demo" : "formal") + (OS.GetCmdlineUserArgs().Contains("--small") ? "-small" : ""));
            _dir = OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--capture-dir=", StringComparison.Ordinal))?[14..] ?? _dir;
            Directory.CreateDirectory(_dir);
            string fixture = Path.Combine(_dir, Guid.NewGuid().ToString("N")); Directory.CreateDirectory(fixture);
            _save = GetNode<SaveService>("/root/SaveService"); _save.UsePathForTests(Path.Combine(fixture, "save.json"));
            var settings = GetNode<JourneySettings>("/root/JourneySettings"); settings.UsePathForTests(Path.Combine(fixture, "settings.cfg")); InterfaceLessons.MarkAllSeen(settings);
            Check(_save.ResetProgress(out _), "isolated progress");
            if (OS.GetCmdlineUserArgs().Contains("--unlock-audio-only"))
            {
                CheckUnlockAudio();
                await Frames(); GC.Collect(); GC.WaitForPendingFinalizers(); await Frames();
                GD.Print($"WUHAN_UNLOCK_AUDIO_TEST_PASS checks={_checks} demo={ExperienceProfile.IsDemo}");
                GetTree().Quit(); return;
            }
            _save.Data.UpgradeTeachingCompleted = true; _save.Data.Tianjin.HighestUnlockedDay = 7; _save.TrySave(out _);
            GetWindow().Size = OS.GetCmdlineUserArgs().Contains("--small") ? new(1280, 720) : new(1920, 1080);
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); AddChild(main); await Frames();
            if (OS.GetCmdlineUserArgs().Contains("--record-demo"))
            {
                await RecordDemo(main); GetTree().Quit(); return;
            }
            var home = main.GetNode<StartScreen>("UI/StartScreen");
            var screen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            var day = main.GetNode<DayController>("DayController"); var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 7), "Day7 starts");
            day.AbandonDay(); Check(!_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan), "abandon does not unlock");
            Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 7), "Day7 can restart");
            day.SetProcess(false); screen.SetProcess(false);
            var model = BusinessBookModel.From(StableIds.Cities.Tianjin, new DayResult { Day = 7, SaleRevenue = 100, Tips = 0, CompletedCustomers = 1 }, Array.Empty<BusinessOrderRecord>(), catalog);
            var plan = day.CurrentPlan!; var config = day.CurrentConfig!;
            using (var blocked = new FileStream(Path.Combine(fixture, "save.json.tmp"), FileMode.OpenOrCreate, System.IO.FileAccess.ReadWrite, FileShare.None))
            {
                BusinessBookSettlement.Commit(model, _save, plan, config, catalog);
                Check(model.CanRetry && !model.NewWuhanUnlock && !_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan), "failed settlement rolls back unlock");
            }
            BusinessBookSettlement.Commit(model, _save, plan, config, catalog);
            Check(model.NewWuhanUnlock && _save.HasUnseenWuhanUnlock && _save.Data.Coins == 100 && _save.Data.Tianjin.BestStars == 0, "Day7 unlocks without star or purchase requirement");
            var repeat = BusinessBookModel.From(StableIds.Cities.Tianjin, model.Result, Array.Empty<BusinessOrderRecord>(), catalog);
            BusinessBookSettlement.Commit(repeat, _save, plan, config, catalog);
            Check(!repeat.NewWuhanUnlock, "a repeated result does not trigger another first unlock");
            _save.CommitDay(model.Result, plan, config); Check(_save.Data.Coins == 100, "same settlement cannot pay twice");
            _save.Load(); Check(_save.HasUnseenWuhanUnlock && _save.Data.Wuhan.HighestUnlockedDay == 1, "unlock persists before animation");
            day.AbandonDay(); var book = screen.BusinessDetails; book.Open(model);
            Check(book.CloseButton.Text == "开始第 8 天", "unlock keeps next-day primary caption");
            Check(book.Descendants<Button>().Any(b => b.Name == "NewCityUnlock"), "new city has a dedicated clickable notice");
            var unlock = book.Descendants<Button>().Single(b => b.Name == "NewCityUnlock");
            var entranceField = typeof(BusinessDetailsView).GetField("_entrance",
                System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!;
            Tween PauseEntrance()
            {
                var tween = (Tween)entranceField.GetValue(book)!;
                tween.Pause(); return tween;
            }
            var entrance = PauseEntrance();
            Check(!unlock.Visible, "unlock card is hidden when the book opens");
            await Frames();
            entrance.CustomStep(3.04);
            Check(!unlock.Visible, "unlock stays hidden until all summary content is shown");
            JourneyTransition.For(this).Finish();
            await Capture("settlement-before-unlock");
            Check(unlock.Scale == Vector2.One, "unlock waits for summary content");
            Check(book.GetNodeOrNull<AudioStreamPlayer>("NewCityCelebrationAudio") is null, "celebration waits for unlock emphasis");
            entrance.CustomStep(.29);
            Check(unlock.Visible, "unlock is revealed at the final celebration");
            Check(unlock.Scale.X > 1.04f, "unlock pops once after summary");
            var celebration = book.GetNode<AudioStreamPlayer>("NewCityCelebrationAudio");
            Check(celebration.Playing && celebration.Bus == JourneySettings.EffectsBus, "unlock celebration plays on effects bus");
            var nextPage = book.Descendants<Button>().Single(b => b.Name == "NextBookPage");
            await Frames(); // Let the newly visible button settle its control layout.
            Check(!unlock.GetGlobalRect().Intersects(nextPage.GetGlobalRect())
                && !unlock.GetGlobalRect().Intersects(book.CloseButton.GetGlobalRect()),
                $"enlarged unlock leaves navigation clear at peak: card={unlock.GetGlobalRect()}, next={nextPage.GetGlobalRect()}, close={book.CloseButton.GetGlobalRect()}");
            JourneyTransition.For(this).Finish();
            await Capture("settlement-unlock-pop");
            entrance.CustomStep(.4);
            Check(unlock.Scale == Vector2.One && unlock.PivotOffset == Vector2.Zero, "unlock returns to original bounds");
            await Delay(celebration.Stream.GetLength() + .25);
            Check(unlock.Scale == Vector2.One, "unlock does not loop");
            Check(!celebration.Playing, "celebration finishes without looping");
            book.Open(model); entrance = PauseEntrance(); entrance.CustomStep(3.33);
            unlock = book.Descendants<Button>().Single(b => b.Name == "NewCityUnlock");
            book.FinishAnimation();
            Check(unlock.Scale == Vector2.One && !entrance.IsValid(), "skip cancels unlock pop and restores bounds");
            Check(!celebration.Playing, "skip stops celebration");
            book.Open(model); entrance = PauseEntrance();
            unlock = book.Descendants<Button>().Single(b => b.Name == "NewCityUnlock");
            Check(!unlock.Visible, "reopening starts with a hidden unlock card");
            book.FinishAnimation();
            Check(unlock.Visible && unlock.Scale == Vector2.One && !celebration.Playing,
                "early skip reveals the complete card without delayed celebration");
            ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            book.Open(model);
            Check(book.Descendants<Button>().Single(b => b.Name == "NewCityUnlock").Scale == Vector2.One
                && entranceField.GetValue(book) is null, "reduced motion keeps unlock static");
            Check(celebration.Playing, "reduced motion retains celebration sound");
            book.Notification((int)NotificationApplicationFocusOut);
            Check(!celebration.Playing, "focus loss stops celebration");
            book.Notification((int)NotificationApplicationFocusIn);
            Check(!celebration.Playing, "focus return does not replay celebration");
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            book.SelectPage(true, false);
            Check(!book.Descendants<Button>().Single(b => b.Name == "NewCityUnlock").IsVisibleInTree(), "notice belongs to summary only");
            book.SelectPage(false, false);
            await Delay(4); await Capture("settlement");
            book.CloseButton.EmitSignal(BaseButton.SignalName.Pressed); await Delay(1);
            Check(screen.Visible && day.CurrentConfig?.Day == 8, "settlement continues Tianjin Day8 directly");
            Check(_save.HasUnseenWuhanUnlock, "continuing Tianjin preserves unseen city reminder");
            if (OS.GetCmdlineUserArgs().Contains("--settlement-only"))
            {
                GD.Print($"WUHAN_UNLOCK_SETTLEMENT_TEST_PASS checks={_checks} demo={ExperienceProfile.IsDemo}");
                GetTree().Quit(); return;
            }
            day.AbandonDay();
            home.PresentMap(); JourneyTransition.For(this).Finish(); await Frames();
            Check(home.Descendants<Button>().Any(b => b.Name == "Node1" && !b.Disabled), "unlocked Wuhan remains accessible on map");
            home.Hide(); screen.Show(); book.Open(model); book.FinishAnimation(); JourneyTransition.For(this).Finish();
            OpenNewJourney(book);
            var show = main.GetNode<WuhanUnlockPresentation>("WuhanUnlockPresentation");
            await Delay(2); await Capture("node-lit");
            // Exiting before the final postcard must never revert the unlock or mark it seen.
            show.QueueFree(); await Frames(); _save.Load(); Check(_save.HasUnseenWuhanUnlock, "interrupted animation keeps durable unlock and unseen flag");
            book.Open(model); book.FinishAnimation(); JourneyTransition.For(this).Finish(); OpenNewJourney(book);
            show = main.GetNode<WuhanUnlockPresentation>("WuhanUnlockPresentation");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            Check(show.FinalVisible && _save.Data.WuhanUnlockPresentationSeen, "Escape lands on final postcard and persists seen state");
            show.Notification((int)NotificationApplicationFocusOut); show.Notification((int)NotificationApplicationFocusIn);
            Check(show.FinalVisible, "focus changes after skip retain the final postcard");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, Pressed = true }, true);
            Check(_save.Data.LastVisitedCityId == StableIds.Cities.Tianjin && home.Page == JourneyPage.Opening,
                "skip cannot click through into Wuhan");
            await Delay(.4); await Capture("postcard");
            Check(home.Visible && home.ProcessMode != ProcessModeEnum.Disabled
                && home.Descendants<Label>().Any(l => l.Text == "江城过早"), "shared Wuhan introduction replaces the final postcard");
            Check(!home.Descendants<Button>().Any(b => b.Text is "前往武汉" or "留在天津"),
                "old departure and stay actions are absent");
            home.Descendants<Button>().Single(b => b.Name == "WuhanOpeningContinue").EmitSignal(BaseButton.SignalName.Pressed);
            JourneyTransition.For(this).Finish(); await Frames();
            Check(!home.Visible && main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen").Visible,
                "start Wuhan journey opens Day 1 business directly");
            Check(_save.Data.LastVisitedCityId == StableIds.Cities.Wuhan, "journey action saves the selected city");
            _save.TryRecordCityVisit(StableIds.Cities.Tianjin, out _);
            // Replay the fixture to check natural completion and keyboard navigation.
            home.Hide(); screen.Show(); book.Open(model); book.FinishAnimation(); JourneyTransition.For(this).Finish(); OpenNewJourney(book);
            await Delay(4.9);
            Check(home.Page == JourneyPage.Opening && home.ProcessMode != ProcessModeEnum.Disabled
                && _save.Data.LastVisitedCityId == StableIds.Cities.Tianjin, "natural ending waits on the introduction");
            await Capture("natural-postcard");
            var continueButton = home.Descendants<Button>().Single(b => b.Name == "WuhanOpeningContinue");
            continueButton.GrabFocus();
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, PhysicalKeycode = Key.Enter, Pressed = true }, true);
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, PhysicalKeycode = Key.Enter, Pressed = false }, true);
            JourneyTransition.For(this).Finish(); await Frames();
            Check(!home.Visible && main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen").Visible,
                "keyboard action starts Wuhan Day 1 directly");
            Check(_save.Data.Tianjin.HighestUnlockedDay == 8 && _save.Data.Coins == 100, "journey preserves Tianjin progress and earnings");
            await Capture("wuhan-business");
            ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            var reduced = new WuhanUnlockPresentation(); AddChild(reduced); reduced.Begin(_save, _ => { }); await Delay(.25);
            Check(reduced.FinalVisible, "reduced motion reaches full information with short fade"); reduced.QueueFree();
            CheckUnlockAudio();
            _save.Load(); Check(_save.Data.WuhanUnlockPresentationSeen, "seen flag survives reload");
            GD.Print($"WUHAN_UNLOCK_TEST_PASS checks={_checks} demo={ExperienceProfile.IsDemo}"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private void Check(bool value, string message) { if (!value) throw new InvalidOperationException(message); _checks++; GD.Print("PASS " + message); }
    private async Task RecordDemo(GameController main)
    {
        var day = main.GetNode<DayController>("DayController");
        var screen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 7), "recording fixture starts Day7");
        day.SetProcess(false); screen.SetProcess(false);
        var model = BusinessBookModel.From(StableIds.Cities.Tianjin,
            new DayResult { Day = 7, SaleRevenue = 386, Tips = 57, CompletedCustomers = 28,
                LostCustomers = 2, CorrectOrders = 28, PerfectOrders = 9, Satisfaction = 92, HighestCorrectStreak = 8 },
            Array.Empty<BusinessOrderRecord>(), catalog);
        BusinessBookSettlement.Commit(model, _save, day.CurrentPlan!, day.CurrentConfig!, catalog);
        day.AbandonDay(); JourneyTransition.For(this).Finish();
        await Delay(.5);
        GD.Print("MOVIE_SETTLEMENT_FRAME=" + Engine.GetProcessFrames());
        screen.BusinessDetails.Open(model);
        await Delay(6);
        OpenNewJourney(screen.BusinessDetails);
        await Delay(7.8);
        var home = main.GetNode<StartScreen>("UI/StartScreen");
        Check(home.Visible && home.Page == JourneyPage.Opening, "recording reaches Wuhan introduction");
        home.Descendants<Button>().Single(b => b.Name == "WuhanOpeningContinue").EmitSignal(BaseButton.SignalName.Pressed);
        await Delay(2);
        Check(!home.Visible && main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen").Visible
            && day.CurrentConfig?.Day == 1 && day.State is DayState.Opening or DayState.Running,
            "recording starts Wuhan Day 1 business directly");
        GD.Print("WUHAN_UNLOCK_MOVIE_COMPLETE");
    }
    private static void OpenNewJourney(BusinessDetailsView book) => book.Descendants<Button>().Single(b => b.Name == "NewCityUnlock").EmitSignal(BaseButton.SignalName.Pressed);
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Delay(double seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
    private async Task Capture(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        await Frames(); var drawn = ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw); RenderingServer.ForceDraw(); await drawn;
        using var image = GetViewport().GetTexture().GetImage(); image.SavePng(Path.Combine(_dir, name + ".png"));
    }
}
