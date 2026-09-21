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
            Directory.CreateDirectory(_dir);
            string fixture = Path.Combine(_dir, Guid.NewGuid().ToString("N")); Directory.CreateDirectory(fixture);
            _save = GetNode<SaveService>("/root/SaveService"); _save.UsePathForTests(Path.Combine(fixture, "save.json"));
            var settings = GetNode<JourneySettings>("/root/JourneySettings"); settings.UsePathForTests(Path.Combine(fixture, "settings.cfg")); InterfaceLessons.MarkAllSeen(settings);
            Check(_save.ResetProgress(out _), "isolated progress");
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
            Check(book.CloseButton.Text == "展开新旅程", "stable first-frame primary caption");
            await Delay(4); await Capture("settlement");
            book.Descendants<Button>().Single(b => b.Text == "留在天津").EmitSignal(BaseButton.SignalName.Pressed); await Delay(1);
            Check(home.Visible && home.Page == JourneyPage.Ledger && home.SelectedDay == 8 && home.SelectedCityId == StableIds.Cities.Tianjin, "settlement stay opens Tianjin Day8 ledger");
            home.PresentMap(); JourneyTransition.For(this).Finish(); await Frames();
            Check(home.Descendants<Label>().Any(l => l.Name == "WuhanNewTag"), "unseen unlock has a quiet map reminder");
            home.Hide(); screen.Show(); book.Open(model); book.FinishAnimation(); JourneyTransition.For(this).Finish();
            book.CloseButton.EmitSignal(BaseButton.SignalName.Pressed);
            var show = main.GetNode<WuhanUnlockPresentation>("WuhanUnlockPresentation");
            await Delay(2); await Capture("node-lit");
            // Exiting before the final postcard must never revert the unlock or mark it seen.
            show.QueueFree(); await Frames(); _save.Load(); Check(_save.HasUnseenWuhanUnlock, "interrupted animation keeps durable unlock and unseen flag");
            book.Open(model); book.FinishAnimation(); JourneyTransition.For(this).Finish(); book.CloseButton.EmitSignal(BaseButton.SignalName.Pressed);
            show = main.GetNode<WuhanUnlockPresentation>("WuhanUnlockPresentation");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            Check(show.FinalVisible && _save.Data.WuhanUnlockPresentationSeen, "Escape lands on final postcard and persists seen state");
            show.Notification((int)NotificationApplicationFocusOut); show.Notification((int)NotificationApplicationFocusIn);
            Check(show.FinalVisible, "focus changes after skip retain the final postcard");
            show.Descendants<Button>().Single(b => b.Text == "前往武汉").EmitSignal(BaseButton.SignalName.Pressed);
            Check(_save.Data.LastVisitedCityId == StableIds.Cities.Tianjin, "skip cannot click through into Wuhan");
            await Delay(.4); await Capture("postcard");
            show.Descendants<Button>().Single(b => b.Text == "留在天津").EmitSignal(BaseButton.SignalName.Pressed); await Delay(1);
            Check(home.SelectedDay == 8 && home.Page == JourneyPage.Ledger && _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan), "postcard stay retains both cities");
            // Replay the visual fixture to test natural completion and the real departure callback.
            home.Hide(); screen.Show(); book.Open(model); book.FinishAnimation(); JourneyTransition.For(this).Finish(); book.CloseButton.EmitSignal(BaseButton.SignalName.Pressed);
            show = main.GetNode<WuhanUnlockPresentation>("WuhanUnlockPresentation");
            await Delay(4.9); Check(show.FinalVisible && _save.Data.LastVisitedCityId == StableIds.Cities.Tianjin, "natural ending waits for player");
            show.Notification((int)NotificationApplicationFocusOut); show.Notification((int)NotificationApplicationFocusIn);
            await Capture("natural-postcard");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Tab, Pressed = true }, true);
            Check(GetViewport().GuiGetFocusOwner() is Button { Text: "前往武汉" }, "Tab focuses postcard action without reaching underlying ledger");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, Pressed = true }, true);
            await Delay(.38); await Capture("departure"); await Delay(.6);
            Check(!home.Visible && main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen").Visible, "departure opens Wuhan business without the calendar");
            Check(_save.Data.LastVisitedCityId == StableIds.Cities.Wuhan && day.CurrentConfig?.Day == 1
                && day.State == DayState.Opening, "visit saved and Wuhan Day1 starts opening");
            Check(_save.Data.Tianjin.HighestUnlockedDay == 8 && _save.Data.Coins == 100, "departure preserves Tianjin progress and earnings");
            await Capture("wuhan-business");
            ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            var reduced = new WuhanUnlockPresentation(); AddChild(reduced); reduced.Begin(_save, _ => ""); await Delay(.25);
            Check(reduced.FinalVisible, "reduced motion reaches full information with short fade"); reduced.QueueFree();
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
        screen.BusinessDetails.CloseButton.EmitSignal(BaseButton.SignalName.Pressed);
        var show = main.GetNode<WuhanUnlockPresentation>("WuhanUnlockPresentation");
        await Delay(7.8);
        Check(show.FinalVisible, "recording reaches final postcard");
        show.Descendants<Button>().Single(b => b.Text == "前往武汉").EmitSignal(BaseButton.SignalName.Pressed);
        day.SetProcess(true);
        await Delay(8);
        Check(!main.GetNode<StartScreen>("UI/StartScreen").Visible
            && main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen").Visible
            && day.CurrentConfig?.Day == 1 && day.State is DayState.Opening or DayState.Running, "recording starts Wuhan Day1 business");
        GD.Print("WUHAN_UNLOCK_MOVIE_COMPLETE");
    }
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Delay(double seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
    private async Task Capture(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        await Frames(); var drawn = ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw); RenderingServer.ForceDraw(); await drawn;
        using var image = GetViewport().GetTexture().GetImage(); image.SavePng(Path.Combine(_dir, name + ".png"));
    }
}
