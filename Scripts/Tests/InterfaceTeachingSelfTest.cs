using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class InterfaceTeachingSelfTest : Node
{
    private static string Output => OS.GetCmdlineUserArgs().Contains("--teaching-layout")
        ? "res://artifacts/teaching-layout-20260917/interface" : "res://artifacts/day1-interface-teaching-20260921" + (ExperienceProfile.IsDemo ? "-demo" : "");
    private SubViewport _viewport = null!;
    private GameController _main = null!;
    private JourneySettings _settings = null!;
    private SaveService _save = null!;
    private int _checks;
    private async Task Frames(int n = 5)
    {
        for (int i = 0; i < n; i++)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            JourneyTransition.For(this).Finish();
        }
    }
    private void Check(bool value, string message) { if (!value) throw new Exception(message); GD.Print("PASS " + message); _checks++; }
    private static IEnumerable<Node> All(Node parent)
    { foreach (Node child in parent.GetChildren(true)) { yield return child; foreach (Node node in All(child)) yield return node; } }
    private T Find<T>(Node parent, string name) where T : Node => All(parent).OfType<T>().First(n => n.Name == name);
    private InterfaceTeaching? Guide(Node owner) => All(owner).OfType<InterfaceTeaching>().FirstOrDefault(g => g.Visible && !g.IsQueuedForDeletion());
    private void Move(Vector2 p) => _viewport.PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
    private void Click(Control target)
    {
        Vector2 p = target.GetGlobalTransformWithCanvas() * (target.Size / 2);
        if (target.GetViewport() is Window window) p += window.Position;
        Move(p);
        foreach (bool pressed in new[] { true, false })
            _viewport.PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = pressed }, true);
    }
    private void Key(Key key)
    { foreach (bool pressed in new[] { true, false }) _viewport.PushInput(new InputEventKey { Keycode = key, Pressed = pressed }, true); }
    private async Task Shot(string name)
    {
        await Frames(); RenderingServer.ForceDraw(false);
        Check(_viewport.GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath(Output + "/" + name + ".png")) == Error.Ok, "capture " + name);
    }
    private async Task NoHover(Control target)
    {
        Check(target.TooltipText.Length == 0, target.Name + " has no hover text");
        Move(new(1915, 1075)); await Frames(2);
        Move(target.GetGlobalTransformWithCanvas() * (target.Size / 2));
        await ToSignal(GetTree().CreateTimer(.85), SceneTreeTimer.SignalName.Timeout);
        Check(!All(_viewport).OfType<PopupPanel>().Any(p => p.Visible), target.Name + " opens no native tooltip after dwell");
    }
    private async Task Finish(InterfaceTeaching guide)
    {
        int count = guide.StepCount - guide.StepIndex;
        for (int i = 0; i < count; i++) { Click(Find<Button>(guide, "NextTeaching")); await Frames(); }
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            GetWindow().Position = new(-10000, -10000);
            _settings = GetNode<JourneySettings>("/root/JourneySettings");
            string settingsPath = Output + "/settings-" + Guid.NewGuid().ToString("N") + ".cfg";
            _settings.UsePathForTests(settingsPath);
            _save = GetNode<SaveService>("/root/SaveService");
            if (ExperienceProfile.IsDemo) _save.UseDemoPathForTests(Output + "/fixture.json");
            else _save.UsePathForTests(Output + "/fixture.json");
            Check(_save.ResetProgress(out _), "isolated save");
            var catalog = GetNode<DataCatalog>("/root/DataCatalog"); _save.Data.Coins = 10000;
            foreach (string id in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian })
            {
                if (!_save.IsCityAvailable(id)) continue;
                if (!_save.Data.UnlockedCityIds.Contains(id)) _save.Data.UnlockedCityIds.Add(id);
                var progress = _save.Data.GetCity(id); progress.HighestUnlockedDay = id == StableIds.Cities.Tianjin ? 15 : 12;
                progress.UnlockedContentIds = catalog.GetDays(id).Values.SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
                for (int d = 1; d <= progress.HighestUnlockedDay; d++) progress.DayBestRecords[d] = new() { TotalRevenue = 386, Satisfaction = 96, CompletedCustomers = 18 };
            }
            Check(_save.TrySave(out _), "fixture saved");
            _viewport = new SubViewport { Size = new(1920, 1080), GuiEmbedSubwindows = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport); _viewport.NotifyMouseEntered();
            _main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); _viewport.AddChild(_main);
            var start = _main.GetNode<StartScreen>("UI/StartScreen"); start.PresentHome(); await Frames(10);
            await NoHover(Find<Button>(start, "Continue")); await Shot("01-home-no-tooltip");
            start.PresentCity(StableIds.Cities.Tianjin); start.PresentLedger(); await Frames(10);
            var guide = Guide(start); Check(guide is not null && guide.LessonKey == InterfaceLessons.CalendarKey, "calendar first-use teaching");
            await Shot("02-calendar-teaching");
            int selected = start.SelectedDay; Click(Find<Button>(start, "Date8")); await Frames();
            Check(start.SelectedDay == selected, "teaching blocks underlying date clicks");
            Key(Godot.Key.Escape); await Frames();
            Check(Guide(start) is null && start.Page == JourneyPage.Ledger, "Esc skips only teaching and preserves calendar");
            Check(_settings.HasSeenInterfaceLesson(InterfaceLessons.CalendarKey), "skip remembers calendar teaching");
            start.PresentLedger(); await Frames(); Check(Guide(start) is null, "calendar teaching does not repeat");
            await NoHover(Find<Button>(start, "Date8")); await Shot("03-calendar-no-tooltip");

            var controller = _main.GetNode<DayController>("DayController"); controller.SetProcess(false);
            Check(_main.StartCityBusiness(StableIds.Cities.Tianjin, 15), "start Tianjin");
            var tianjin = _main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen"); tianjin.SetProcess(false); tianjin._Notification((int)NotificationApplicationFocusIn);
            controller.Tick(4); tianjin.RefreshForCapture(true); await Frames(10);
            Check(Guide(tianjin) is null, "unread business teaching does not appear after Tianjin Day 1");
            Check(_main.StartCityBusiness(StableIds.Cities.Tianjin, 1), "start Tianjin Day 1");
            controller.Tick(4); tianjin.RefreshForCapture(true); await Frames(10);
            // Keep a cooking focus visible to verify the interface lesson waits its turn.
            tianjin.TeachingFocus.SetProcess(false); tianjin.TeachingFocus.Show();
            await Frames(); Check(Guide(tianjin) is null, "business teaching waits for cooking focus");
            tianjin.TeachingFocus.Hide(); await Frames(10);
            guide = Guide(tianjin); Check(guide is not null && guide.LessonKey == InterfaceLessons.BusinessKey, "HUD first-use teaching");
            double before = controller.DayElapsedSeconds; controller.Tick(12);
            Check(controller.IsPaused && controller.DayElapsedSeconds == before, "teaching freezes business time");
            await Shot("04-business-teaching");
            _viewport.Size = new(1280, 720); await Frames(); await Shot("04-business-teaching-1280");
            _viewport.Size = new(1920, 1080); await Frames();
            Click(Find<Button>(guide!, "NextTeaching")); await Frames();
            Check(guide!.StepIndex == 1, "next teaching step");
            Click(Find<Button>(guide, "PreviousTeaching")); await Frames(); Check(guide.StepIndex == 0, "previous teaching step");
            await Finish(guide); Check(!controller.IsPaused, "completion releases its pause");
            tianjin.RefreshForCapture(true); await Frames(); guide = Guide(tianjin);
            Check(guide?.LessonKey == InterfaceLessons.PendantKey, "pendant first-use teaching follows HUD");
            await Shot("05-pendant-teaching"); await Finish(guide!);
            var hud = Find<BusinessHud>(tianjin, "BusinessHud");
            Check(!hud.Descendants<Control>().Any(c => c.TooltipText.Length > 0), "HUD has no text tooltips");
            await NoHover(hud.PauseButton); await NoHover(tianjin.CashPendant); await Shot("06-business-no-tooltip");

            Check(_main.StartCityBusiness(StableIds.Cities.Wuhan, 12), "start Wuhan");
            var wuhan = _main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen"); wuhan.SetProcess(false); wuhan._Notification((int)NotificationApplicationFocusIn);
            controller.Tick(4); wuhan.RefreshForCapture(); await Frames();
            Check(Guide(wuhan) is null, "shared HUD and pendant lessons do not repeat in Wuhan");
            Check(!Find<BusinessHud>(wuhan, "BusinessHud").Descendants<Control>().Any(c => c.TooltipText.Length > 0), "Wuhan HUD cleared");
            var xian = _main.GetNode<XianDayScreen>("UI/XianDayScreen");
            if (!ExperienceProfile.IsDemo)
            {
                Check(_main.StartCityBusiness(StableIds.Cities.Xian, 12), "start Xian");
                xian.SetProcess(false); xian._Notification((int)NotificationApplicationFocusIn);
                controller.Tick(4); xian.Render(); await Frames();
                await NoHover(Find<Button>(xian, "OpenBusinessBook"));
                Check(xian.CoinTray.TooltipText.Length == 0 && xian.CoinTray.Descendants<Control>().All(c => c.TooltipText.Length == 0), "coin tray and collect button cleared");
                await NoHover(xian.CoinTray.Descendants<Button>().Single());
                Click(Find<Button>(xian, "HudPause")); await Frames();
                var menu = xian.GetNode<Control>("Workbench/PauseMenu");
                Click(menu.Descendants<Button>().First(b => b.Text.Contains("放弃") || b.Text.Contains("离开") || b.Text.Contains("返回首页"))); await Frames();
                var dialog = xian.Descendants<ConfirmationDialog>().First(d => d.Visible);
                Check(dialog.GetNode<Button>("CityDialogHeader/Artwork/Close").TooltipText.Length == 0, "dialog close hover text removed");
                await Shot("07-dialog-no-tooltip"); Click(dialog.GetCancelButton()); await Frames();
                Click(menu.Descendants<Button>().First(b => b.Text.Contains("继续营业"))); await Frames();

                Click(Find<Button>(xian, "OpenBusinessBook")); await Frames();
            }
            BusinessDetailsView book = xian.BusinessDetails;
            var model = new BusinessBookModel { CityId = "xian", Closing = false,
                Result = new() { Day = 12, CompletedCustomers = 18, LostCustomers = 2, SaleRevenue = 350, Tips = 36, Satisfaction = 96 },
                Orders = new[] { new BookOrder(1, "fixture", "街坊老熟客", "elder_regular", new[] { new BookProduct("roujiamo", "多肉加汁肉夹馍", 12, "Roujiamo") }, BookOutcome.Perfect, 350, 36, 96) },
                SaveMessage = "已保存 · 已入账 ¥386 · 新纪录", Stickers = new[] { "新解锁 · 回店查看" },
                Upgrades = new BookUpgradeSource(_save, catalog, StableIds.Cities.Xian) };
            if (!ExperienceProfile.IsDemo)
            {
                book.Open(model); book.FinishAnimation(); await Frames(10);
                Check(Guide(book) is null, "unread book teaching does not appear in Xian");
                book.Hide();
            }
            var xianModel = model;
            Check(_main.StartCityBusiness(StableIds.Cities.Tianjin, 1), "return to Tianjin Day 1 for settlement");
            tianjin._Notification((int)NotificationApplicationFocusIn);
            controller.Tick(4); tianjin.RefreshForCapture(true); await Frames();
            tianjin.OpenBusinessDetails(); book = tianjin.BusinessDetails;
            BusinessBookModel TianjinBook(int day, bool closing) => new() { CityId = "tianjin", Closing = closing,
                Result = new() { Day = day, CompletedCustomers = 18, LostCustomers = 2, SaleRevenue = 350, Tips = 36, Satisfaction = 96 },
                Orders = model.Orders, SaveMessage = model.SaveMessage, Stickers = model.Stickers,
                Upgrades = new BookUpgradeSource(_save, catalog, StableIds.Cities.Tianjin) };
            model = TianjinBook(1, false);
            book.Open(model); book.FinishAnimation(); await Frames();
            Check(Guide(book) is null, "Day 1 live business details do not teach settlement");
            model = TianjinBook(2, true);
            book.Open(model); book.FinishAnimation(); await Frames();
            Check(Guide(book) is null, "unread book teaching does not appear on Day 2 settlement");
            model = TianjinBook(1, true); book.Open(model); book.FinishAnimation(); await Frames(10);
            guide = Guide(book); Check(guide?.LessonKey == InterfaceLessons.BookKey, "Tianjin Day 1 settlement teaching");
            await Shot("08-book-teaching"); await Finish(guide!);
            Check(controller.IsPaused, "book teaching preserves the book's existing pause");
            _viewport.Size = new(1280, 720); await Frames(); await Shot("08-book-1280");
            _viewport.Size = new(1920, 1080); await Frames();
            book.Hide();
            if (!ExperienceProfile.IsDemo)
            {
                model = xianModel; book = xian.BusinessDetails;
                Check(_main.StartCityBusiness(StableIds.Cities.Xian, 12), "return to Xian for existing book hover checks");
                book.Open(model); book.FinishAnimation(); await Frames();
                Check(book.Descendants<Control>().All(c => c.TooltipText.Length == 0), "all book labels and buttons cleared");
                await NoHover(Find<Label>(book, "BookCompletionRate")); await NoHover(Find<Label>(book, "BookSatisfaction"));
                await NoHover(Find<Label>(book, "BookBestSeller")); await NoHover(book.CloseButton); await Shot("09-book-no-tooltip");
                model.Closing = true; book.Open(model); book.FinishAnimation(); await Frames();
                await NoHover(Find<Button>(book, "OpenBookUpgrades")); Click(Find<Button>(book, "OpenBookUpgrades")); await Frames();
                var upgrade = Find<Button>(book, "UpgradeEquipment"); Check(!upgrade.Disabled, "upgrade remains enabled");
                Click(upgrade); await Frames(10);
                await NoHover(Find<Label>(book, "UpgradeFeedback")); await Shot("10-upgrade-no-tooltip");
                book.Hide();
            }

            Check(_main.OpenCity(StableIds.Cities.Tianjin), "return to city"); await Frames();
            Click(Find<Button>(start, "Help")); await Frames();
            Check(!All(start).Any(n => n.Name == "ReplayInterfaceTeaching"), "help removes business teaching entry");
            Check(Find<Button>(start, "ReplayTutorial").IsVisibleInTree(), "help retains first breakfast replay");
            await Shot("11-help-entry");
            _viewport.Size = new(1280, 720); await Frames(10); await Shot("12-help-1280");
            _viewport.Size = new(1920, 1080); _settings.SetLanguage("en"); await Frames();
            // Exercise translated lesson layout directly; help no longer exposes replay.
            guide = InterfaceTeaching.Offer(start, "layout-check", InterfaceLessons.Replay(StableIds.Cities.Tianjin), replay: true)!;
            await Frames();
            foreach (var lesson in InterfaceLessons.Replay(StableIds.Cities.Tianjin))
            {
                var text = Find<Label>(guide, "TeachingText");
                Check(!text.Tr(text.Text).ToString().Any(c => c >= '\u4e00' && c <= '\u9fff'), "English lesson translated");
                Check(text.GetMinimumSize().Y <= text.Size.Y, "English lesson fits its measured text area");
                var next = Find<Button>(guide, "NextTeaching");
                float gap = next.GetParent<Control>().Position.Y - text.Position.Y - text.Size.Y;
                Check(gap >= 20 && gap <= 28, "body and actions keep compact spacing");
                if (guide.StepIndex == guide.StepCount - 1) await Shot("13-help-replay-en");
                Click(Find<Button>(guide, "NextTeaching")); await Frames();
            }
            Check(start.ModalOpen, "completing replay keeps help open");
            _settings.UsePathForTests(settingsPath); GetWindow().Position = new(-10000, -10000);
            Check(InterfaceLessons.Keys.Append(InterfaceLessons.PendantKey).All(_settings.HasSeenInterfaceLesson), "lesson completion persists across settings reload");
            GD.Print($"INTERFACE_TEACHING_PASS checks={_checks}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print("INTERFACE_TEACHING_FAIL"); GetTree().Quit(1); }
    }
}
