using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using System.Text.Json;

namespace ProjectCake.Tests;

// Capture-only fixture: isolated saves and production scenes, with native tooltip timing.
public partial class HoverTooltipCapture : Node
{
    private const string Output = "res://artifacts/hover-review-20260917";
    private SubViewport _viewport = null!;
    private GameController _main = null!;
    private SaveService _save = null!;
    private DataCatalog _catalog = null!;
    private readonly List<object> _shots = new();
    private async Task Frames(int n = 5) { for (int i = 0; i < n; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private static IEnumerable<Node> All(Node node)
    { foreach (Node child in node.GetChildren(true)) { yield return child; foreach (var next in All(child)) yield return next; } }
    private Control Find(Node root, string name) => All(root).OfType<Control>().First(c => c.Name == name);
    private Control Tip(Node root, string text) => All(root).OfType<Control>().First(c => c.IsVisibleInTree() && c.TooltipText.Contains(text));
    private void Move(Vector2 p) => _viewport.PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
    private void Click(Control control)
    {
        Vector2 p = control.GetGlobalRect().GetCenter();
        if (control.GetViewport() is Window window) p += window.Position;
        Move(p);
        foreach (bool pressed in new[] { true, false })
            _viewport.PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = pressed }, true);
    }
    private async Task Shot(string id, string title, Control target, Vector2? point = null)
    {
        Move(new(1915, 1075)); await Frames();
        if (!target.IsVisibleInTree()) throw new Exception(id + " target hidden");
        Vector2 p = point ?? target.GetGlobalRect().GetCenter();
        if (target.GetViewport() is Window window) p += window.Position;
        Move(p);
        await ToSignal(GetTree().CreateTimer(1.2), SceneTreeTimer.SignalName.Timeout);
        await Frames(); RenderingServer.ForceDraw(false);
        var popups = All(_viewport).OfType<PopupPanel>().Where(w => w.Visible).ToArray();
        string shown = string.Join(" | ", popups.SelectMany(All).OfType<Label>().Select(l => l.Text));
        string path = ProjectSettings.GlobalizePath(Output + "/" + id + ".png");
        using var capture = _viewport.GetTexture().GetImage();
        if (capture.SavePng(path) != Error.Ok) throw new Exception("Save failed: " + path);
        Rect2 area = new(p - new Vector2(180, 110), new(360, 220));
        foreach (var popup in popups) area = area.Merge(new Rect2(popup.Position, popup.Size));
        area = area.Grow(75).Intersection(new Rect2(0, 0, 1920, 1080));
        var region = new Rect2I((int)area.Position.X, (int)area.Position.Y, (int)area.Size.X, (int)area.Size.Y);
        using var crop = capture.GetRegion(region); crop.SavePng(ProjectSettings.GlobalizePath(Output + "/" + id + "-detail.png"));
        _shots.Add(new { id, title, requested = target.TooltipText, shown, target = target.GetPath().ToString(), x = p.X, y = p.Y, popupCount = popups.Length });
        File.WriteAllText(ProjectSettings.GlobalizePath(Output + "/manifest.json"), JsonSerializer.Serialize(_shots, new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }));
        GD.Print($"SHOT {id}: popups={popups.Length} shown={shown} hover={_viewport.GuiGetHoveredControl()?.GetPath()}");
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            GetWindow().Position = new(-10000, -10000);
            _catalog = GetNode<DataCatalog>("/root/DataCatalog");
            _save = GetNode<SaveService>("/root/SaveService");
            _save.UsePathForTests(Output + "/save.json"); _save.ResetProgress(out _);
            GetNode<JourneySettings>("/root/JourneySettings").UsePathForTests(ProjectSettings.GlobalizePath(Output + "/settings.cfg"));
            _save.Data.Coins = 10000;
            foreach (string id in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian })
            {
                if (!_save.Data.UnlockedCityIds.Contains(id)) _save.Data.UnlockedCityIds.Add(id);
                var progress = _save.Data.GetCity(id); progress.HighestUnlockedDay = id == StableIds.Cities.Tianjin ? 15 : 12;
                progress.UnlockedContentIds = _catalog.GetDays(id).Values.SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
                for (int d = 1; d <= progress.HighestUnlockedDay; d++) progress.DayBestRecords[d] = new() { TotalRevenue = 386, Satisfaction = 96, CompletedCustomers = 18 };
            }
            _save.TrySave(out _);
            _viewport = new SubViewport { Size = new(1920, 1080), GuiEmbedSubwindows = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport); _viewport.NotifyMouseEntered();
            _main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); _viewport.AddChild(_main);
            var start = _main.GetNode<StartScreen>("UI/StartScreen"); start.PresentHome(); await Frames(15);
            await Shot("01-continue", "1 · 首页继续旅程", Find(start, "Continue"));
            await Shot("02-map", "2 · 首页墙面地图入口", Find(start, "WallMap"));
            start.PresentCity(StableIds.Cities.Tianjin); start.PresentLedger(); await Frames();
            await Shot("03-calendar", "3 · 经营日历日期", Find(start, "Date8"));
            if (OS.GetCmdlineUserArgs().Contains("--probe")) { GD.Print("HOVER_PROBE_OK"); GetTree().Quit(); return; }
            var controller = _main.GetNode<DayController>("DayController"); controller.SetProcess(false);
            _main.StartCityBusiness(StableIds.Cities.Tianjin, 15);
            var tianjin = _main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen"); tianjin.SetProcess(false); tianjin._Notification((int)NotificationApplicationFocusIn);
            controller.Tick(4); tianjin.RefreshForCapture(true); await Frames(10);
            var hud = Find(tianjin, "BusinessHud");
            await Shot("04-day", "4 · 天津营业日签", Tip(hud, "天津 ·"));
            await Shot("05-orders", "5 · 订单数量", Tip(hud, "今日已完成订单"));
            await Shot("06-time", "6 · 营业计时器", Tip(hud, "剩余营业时间"));
            await Shot("07-income", "7 · 收入数字", Tip(hud, "今日收入"));
            await Shot("08-pause", "8 · 暂停按钮", Find(hud, "HudPause"));
            await Shot("09-pendant", "9 · 天津收银挂件", tianjin.CashPendant);
            _main.StartCityBusiness(StableIds.Cities.Wuhan, 12);
            var wuhan = _main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen"); wuhan.SetProcess(false); wuhan._Notification((int)NotificationApplicationFocusIn);
            controller.Tick(4); wuhan.RefreshForCapture(); await Frames(10);
            await Shot("04b-wuhan-day", "4 · 武汉日签与教学说明", Tip(Find(wuhan, "BusinessHud"), "武汉 ·"));
            _main.StartCityBusiness(StableIds.Cities.Xian, 12);
            var xian = _main.GetNode<XianDayScreen>("UI/XianDayScreen"); xian.SetProcess(false); xian._Notification((int)NotificationApplicationFocusIn);
            controller.Tick(4); xian.Render(); await Frames(10);
            await Shot("10a-book-entry", "10 · 西安账本入口", Tip(xian, "营业账本"));
            await Shot("10b-collect", "10 · 西安收钱入口", xian.CoinTray);
            Click(Find(xian, "HudPause")); await Frames();
            var menu = xian.GetNode<Control>("Workbench/PauseMenu");
            Click(menu.Descendants<Button>().First(b => b.Text.Contains("放弃") || b.Text.Contains("离开") || b.Text.Contains("返回首页"))); await Frames();
            var dialog = xian.Descendants<ConfirmationDialog>().First(d => d.Visible);
            await Shot("15-close-dialog", "15 · 西安确认弹窗关闭叉号", dialog.GetNode<Button>("CityDialogHeader/Artwork/Close"));
            Click(dialog.GetCancelButton()); await Frames();
            Click(menu.Descendants<Button>().First(b => b.Text.Contains("继续营业"))); await Frames();
            await CaptureBook(xian);
            GD.Print("HOVER_CAPTURE_OK count=" + _shots.Count); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private async Task CaptureBook(XianDayScreen screen)
    {
        var view = screen.BusinessDetails;
        var model = new BusinessBookModel
        {
            CityId = "xian", Closing = true,
            Result = new() { Day = 12, CompletedCustomers = 18, LostCustomers = 2, SaleRevenue = 350, Tips = 36, Satisfaction = 96, PerfectOrders = 8 },
            Orders = new[] { new BookOrder(1, "capture-order", "街坊老熟客", "elder_regular", new[] { new BookProduct("roujiamo", "多肉加汁肉夹馍", 12, "Roujiamo") }, BookOutcome.Perfect, 350, 36, 96) },
            SaveMessage = "已保存 · 已入账 ¥386 · 新纪录",
            Stickers = new[] { "本次评级 ★★★", "章节已点亮", "新开放内容 · 回店查看" },
            Upgrades = new BookUpgradeSource(_save, _catalog, StableIds.Cities.Xian)
        };
        view.Open(model); view.FinishAnimation(); await Frames(10);
        await Shot("11a-next", "11 · 账本翻页：顾客明细", Find(view, "NextBookPage"));
        await Shot("11b-close-book", "11 · 收好账本", view.CloseButton);
        await Shot("12a-completion", "12 · 完成率统计说明", Tip(view, "完成率 ="));
        await Shot("12b-satisfaction", "12 · 满意度统计说明", Tip(view, "仅按已完成"));
        await Shot("13a-food-name", "13 · 热销菜品完整名称", Tip(view, "多肉加汁肉夹馍"));
        await Shot("13b-unlock", "13 · 解锁贴片完整信息", Find(view, "UnlockSticker"));
        await Shot("13c-upgrade", "13 · 查看升级效果与价格", Find(view, "OpenBookUpgrades"));
        await Shot("14a-save-message", "14 · 保存消息", Tip(view, "已保存 ·"));
        Click(Find(view, "NextBookPage")); view.FinishAnimation(); await Frames();
        await Shot("11c-previous", "11 · 账本翻页：营业小结", Find(view, "PreviousBookPage"));
        view.SelectPage(false, false); await Frames();
        Click(Find(view, "OpenBookUpgrades")); await Frames();
        // Make a real purchase in the isolated fixture so the game's own feedback text is shown.
        var purchase = view.Descendants<Button>().First(b => b.IsVisibleInTree() && !b.Disabled && b.Text.Contains("升级"));
        Click(purchase); await Frames(10);
        await Shot("14b-upgrade-feedback", "14 · 升级反馈完整消息", Find(view, "UpgradeFeedback"));
    }
}
