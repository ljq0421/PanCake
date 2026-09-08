using Godot;
using ProjectCake.Core;
using ProjectCake.UI;
using ProjectCake.Yangzhou;

namespace ProjectCake.Gameplay;

public partial class YangzhouDayScreen : Control
{
    public event Action? HubRequested;
    public YangzhouSession Session { get; private set; } = null!;
    public bool Practice { get; private set; }
    private SaveService _save = null!;
    private YangzhouCatalog _catalog = null!;
    private Control _canvas = null!, _resultPanel = null!;
    private Label _header = null!, _hint = null!, _feedback = null!, _trayText = null!, _resultText = null!;
    private Button _pause = null!, _serve = null!, _return = null!;
    private ConfirmationDialog _leave = null!;
    private YangzhouSurface _board = null!, _cutStock = null!, _scald = null!, _tea = null!, _tray = null!;
    private readonly YangzhouSurface[] _steam = new YangzhouSurface[2], _stock = new YangzhouSurface[2];
    private readonly Button[] _steamActions = new Button[2];
    private readonly Button[,] _loadButtons = new Button[2, 2];
    private readonly List<Button> _workButtons = new();
    private readonly Button[] _customers = new Button[4];
    private readonly ProgressBar[] _patience = new ProgressBar[4];
    private readonly Dictionary<string, Button> _refills = new();
    private bool _committed, _focusLost, _pausedBeforeLeave;
    private double _feedbackSeconds;
    private PancakeAudio _audio = null!;
    private ulong _lastCutSound;
    public override void _Ready() => Build();
    public bool Initialize(YangzhouCatalog catalog, SaveService save, int day, bool practice = false)
    {
        if (practice && !OS.GetCmdlineUserArgs().Contains("--dev-ui")) return false;
        if (!practice && !save.PrepareYangzhou(day, out _)) return false;
        _catalog = catalog; _save = save; Practice = practice;
        var city = save.Data.Yangzhou;
        Session = new(catalog, day, practice ? 2 : city.EquipmentLevels.GetValueOrDefault(YangzhouCatalog.BoardId, 1), practice ? 2 : city.EquipmentLevels.GetValueOrDefault(YangzhouCatalog.SteamerId, 1));
        _committed = _focusLost = false; _resultPanel.Hide(); _leave.Hide(); _return.Text = "收好收入 · 返回经营首页";
        _feedback.Text = ""; Render(); return true;
    }
    public override void _Process(double delta)
    {
        if (!IsVisibleInTree() || Session is null) return;
        if (!_focusLost) Session.Tick(delta);
        if (_feedbackSeconds > 0) { _feedbackSeconds -= delta; if (_feedbackSeconds <= 0) _feedback.Text = ""; }
        if (Session.Phase == YangzhouPhase.Results && !_resultPanel.Visible) ShowResult();
        Render();
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut)
        {
            _focusLost = true; if (Session is not null) Session.Pause(true); CancelGestures();
        }
        if (what == NotificationApplicationFocusIn) _focusLost = false;
    }
    private bool CanWork() => IsVisibleInTree() && Session?.CanWork == true && !_focusLost && !_leave.Visible;
    private void Say(string text) { _feedback.Text = text; _feedbackSeconds = 3; }
    private void Act(Func<bool> action, string failure)
    {
        if (!CanWork()) return;
        if (!action()) { Say(failure); _audio.Play(PancakeSound.Error); }
        else _audio.Play(PancakeSound.PickUp);
        Render();
    }
    private void Stage(string id)
    {
        if (!CanWork()) return;
        if (Session.Selected is null) { Say("先选择一位茶客，再把成品放进他的托盘。"); return; }
        bool needed = Session.Selected.Needs(id);
        if (Session.Stage(id)) { Say($"已放入{_catalog.Product(id).Name}，切换顾客会保留托盘。"); _audio.Play(PancakeSound.PickUp); }
        else Say(needed ? "这份商品还没准备好。" : "这桌不需要这份商品，满意度降低；商品留在原位。");
        Render();
    }
    private Button Work(string text, Rect2 rect, Func<bool> action, string failure)
    {
        var button = GuangzhouUi.Button(_canvas, text, rect, () => Act(action, failure)); _workButtons.Add(button); return button;
    }
    private YangzhouSurface Surface(string name, string kind, Rect2 rect)
    {
        var target = new YangzhouSurface { Name = name, Kind = kind, Position = rect.Position, Size = rect.Size, CanInteract = CanWork };
        _canvas.AddChild(target); return target;
    }
    private void Build()
    {
        _audio = new PancakeAudio(); AddChild(_audio);
        _canvas = GuangzhouUi.Canvas(this);
        _canvas.AddChild(new ColorRect { Size = new(1920, 1080), Color = new("#E1EDE5"), MouseFilter = MouseFilterEnum.Ignore });
        _header = GuangzhouUi.Text(_canvas, "扬州 · 一席早茶", new(50, 25, 1430, 65), 30);
        _pause = GuangzhouUi.Button(_canvas, "暂停", new(1510, 30, 155, 58), () => { if (Session is null || _leave.Visible) return; Session.Pause(!Session.Paused); CancelGestures(); Render(); });
        GuangzhouUi.Button(_canvas, "返回店铺", new(1685, 30, 180, 58), RequestLeave).Name = "Exit";
        _hint = GuangzhouUi.Text(_canvas, "", new(55, 99, 1790, 46), 23);
        for (int i = 0; i < 4; i++)
        {
            int index = i;
            _customers[i] = GuangzhouUi.Button(_canvas, "等待茶客", new(55 + i * 455, 164, 435, 225), () => { if (CanWork() && index < Session.Waiting.Count) Session.Select(Session.Waiting[index].Plan.Id); Render(); });
            _customers[i].Name = $"Customer{i}"; _customers[i].AddThemeFontSizeOverride("font_size", 23);
            _patience[i] = new ProgressBar { Position = new(74 + i * 455, 366), Size = new(397, 12), ShowPercentage = false, MouseFilter = MouseFilterEnum.Ignore };
            _patience[i].AddThemeStyleboxOverride("background", new StyleBoxFlat { BgColor = new("#D5DFD3"), CornerRadiusTopLeft = 6, CornerRadiusTopRight = 6, CornerRadiusBottomLeft = 6, CornerRadiusBottomRight = 6 });
            _patience[i].AddThemeStyleboxOverride("fill", new StyleBoxFlat { BgColor = new("#719D79"), CornerRadiusTopLeft = 6, CornerRadiusTopRight = 6, CornerRadiusBottomLeft = 6, CornerRadiusBottomRight = 6 });
            _canvas.AddChild(_patience[i]);
        }
        GuangzhouUi.Text(_canvas, "竹蒸笼 · 批量备点", new(55, 411, 480, 47), 28);
        GuangzhouUi.Text(_canvas, "干丝台 · 切丝与三烫", new(570, 411, 820, 47), 28);
        GuangzhouUi.Text(_canvas, "茶与早茶托盘", new(1450, 411, 410, 47), 28);
        for (int i = 0; i < 2; i++)
        {
            int layer = i; float y = 466 + i * 223;
            _steam[i] = Surface($"Steamer{i}", "steam", new(55, y, 475, 154));
            _steam[i].AcceptToken = token => token is "raw:B01" or "raw:B02";
            _steam[i].Dropped = token => Act(() => Session.LoadSteamer(layer, token[4..], 1), "不能混蒸；请检查容量、解锁日期与生坯库存。");
            _loadButtons[i, 0] = Work("三丁包 +2", new(55, y + 162, 145, 50), () => Session.LoadSteamer(layer, "B01", 2), "装笼失败：检查库存、剩余格数；准备阶段只允许一笼。");
            _loadButtons[i, 1] = Work("烧卖 +2", new(209, y + 162, 145, 50), () => Session.LoadSteamer(layer, "B02", 2), "Day 5开放烧卖；同一层不能混蒸。");
            _steamActions[i] = Work("盖笼开蒸", new(363, y + 162, 167, 50), () => Session.SteamAction(layer), "请先装笼、等熟后揭盖；成品盘空间不足时先出餐。");
        }
        _board = Surface("CuttingBoard", "board", new(570, 466, 380, 271));
        _board.Pressed = () => { if (!Session.Kitchen.Board.Cutting) Session.Cut(); };
        _board.Motion = (_, movement, dt) =>
        {
            Session.Stroke(movement.X, dt);
            if (Session.Kitchen.Board.Cutting && Time.GetTicksMsec() - _lastCutSound > 150) { _lastCutSound = Time.GetTicksMsec(); _audio.Play(PancakeSound.Stroke); }
        };
        _cutStock = Surface("CutStock", "stock", new(570, 749, 380, 157));
        _cutStock.DragToken = () => Session.Kitchen.Board.Portions > 0 ? "cut" : "";
        _scald = Surface("Scalding", "scald", new(976, 466, 424, 330));
        _scald.AcceptToken = token => token == "cut";
        _scald.Dropped = _ => Act(Session.LoadGansi, "漏勺已有一份，先调味并放入托盘。");
        _scald.Motion = (position, _, _) =>
        {
            if (position.Y > 190) Session.Dip();
            else if (position.Y < 130 && Session.Lift()) _audio.Play(PancakeSound.Sizzle);
        };
        _scald.Released = () => Session?.Kitchen.Scald.CancelGesture();
        _scald.DragToken = () => Session.Kitchen.Scald.Ready ? "G01" : "";
        Work("调味 · 一次完成", new(976, 808, 424, 60), () => Session.Season(), "至少有效烫1次并提起漏勺；调味料不足请补满。").Name = "Season";
        GuangzhouUi.Text(_canvas, "按住漏勺，下拉浸入0.3秒，再上提。\n三次最佳；完成后拖入右侧托盘。", new(976, 875, 424, 64), 21);
        _tea = Surface("Tea", "stock", new(1450, 466, 415, 141));
        _tea.Pressed = () => { if (!Session.Kitchen.TeaReady) Act(Session.TakeTea, "茶在Day 2开放；无茶时补满茶盘。"); };
        _tea.DragToken = () => Session.Kitchen.TeaReady ? "T01" : "";
        _tray = Surface("Tray", "tray", new(1450, 621, 415, 278));
        _tray.AcceptToken = token => token is "G01" or "B01" or "B02" or "T01";
        _tray.Dropped = Stage;
        _trayText = GuangzhouUi.Text(_tray, "", new(20, 62, 375, 198), 24);
        _serve = Work("整套出餐", new(1450, 913, 415, 62), () => { bool ok = Session.Serve(); if (ok) Say("早茶上齐了！"); return ok; }, "还没凑齐这桌早茶。");
        _serve.Pressed += () => { if (CanWork()) _audio.Play(PancakeSound.Success); };
        for (int i = 0; i < 2; i++)
        {
            string id = i == 0 ? "B01" : "B02";
            _stock[i] = Surface($"Stock{id}", "stock", new(55 + i * 245, 917, 230, 121));
            _stock[i].DragToken = () => Session.Kitchen.HasFood(id) ? id : "";
        }
        var supplies = new[] { ("tofu", "补豆干"), ("B01", "补三丁坯"), ("B02", "补烧卖坯"), ("season", "补调味"), ("T01", "补茶") };
        for (int i = 0; i < supplies.Length; i++)
        {
            var supply = supplies[i];
            var button = new GuangzhouDragSource { Text = supply.Item2, Payload = "raw:" + supply.Item1, CanDrag = () => CanWork() && supply.Item1 is "B01" or "B02" };
            GuangzhouUi.Button(_canvas, button, new(570 + i * 169, 977, 159, 62), () => Act(() => Session.Refill(supply.Item1), "库存已满或正在补给。"));
            button.AddThemeFontSizeOverride("font_size", 18);
            _refills[supply.Item1] = button;
        }
        _feedback = GuangzhouUi.Text(_canvas, "", new(55, 1042, 1810, 36), 21, new Color("#8C4537"));
        _leave = new ConfirmationDialog { Title = "返回店铺", DialogText = "放弃本次营业并返回店铺？本次收入不保存。", OkButtonText = "放弃并返回", CancelButtonText = "继续营业" };
        AddChild(_leave); _leave.Confirmed += () => { _leave.Hide(); Session.Pause(true); HubRequested?.Invoke(); };
        _leave.Canceled += () => Session.Pause(_pausedBeforeLeave);
        _resultPanel = new Control { Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Stop }; _canvas.AddChild(_resultPanel);
        _resultPanel.AddChild(new ColorRect { Size = new(1920, 1080), Color = new(0, 0, 0, .4f), MouseFilter = MouseFilterEnum.Stop });
        GuangzhouUi.Panel(_resultPanel, new(500, 165, 920, 748));
        _resultText = GuangzhouUi.Text(_resultPanel, "", new(558, 201, 802, 564), 28);
        _return = GuangzhouUi.Button(_resultPanel, "收好收入 · 返回经营首页", new(558, 805, 802, 68), ReturnAfterResult, true);
        _resultPanel.Hide();
    }
    private void CancelGestures() { _board?.Cancel(); _scald?.Cancel(); }
    private void RequestLeave()
    {
        if (Session is null) return;
        if (Session.Phase == YangzhouPhase.Results) { ReturnAfterResult(); return; }
        _pausedBeforeLeave = Session.Paused; Session.Pause(true); CancelGestures(); _leave.PopupCentered(new(580, 230));
    }
    private void Render()
    {
        if (Session is null) return;
        var s = Session; var k = s.Kitchen;
        _header.Text = $"扬州 · Day {s.Day.Day}  {s.Day.Title}     " + (s.Phase == YangzhouPhase.Prep ? $"备货 {s.PrepRemaining:0.0}秒" : s.Phase == YangzhouPhase.Closing ? s.Day.Day == 1 ? "教学收尾 · 上齐最后的干丝" : $"收尾 {s.ClosingRemaining:0}秒" : $"营业剩余 {Math.Max(0, s.Day.Duration - s.Elapsed):0}秒") + $"     ¥{s.Revenue}   已完成{s.Served.Count}/{s.Day.Customers}组";
        _hint.Text = s.Paused ? "已暂停 · 点击继续营业恢复" : s.Phase == YangzhouPhase.Prep ? "开店前5秒：先切干丝或装第一笼；到时自动开门。" : s.Day.Hint;
        _pause.Text = s.Paused ? "继续营业" : "暂停";
        foreach (var button in _workButtons) button.Disabled = !CanWork();
        for (int i = 0; i < 4; i++)
        {
            var order = i < s.Waiting.Count ? s.Waiting[i] : null;
            _customers[i].Disabled = order is null || !CanWork();
            _customers[i].Text = order is null ? "静候下一桌茶客" : $"{(order == s.Selected ? "当前托盘 · " : "")}{order.Type.Name} #{order.Plan.Id}  {order.Mood}\n{order.Template.Name} · ¥{order.Price}\n" + string.Join("\n", order.Template.Items.Select(item => $"{_catalog.Product(item.Key).Name}  {order.Count(item.Key)}/{item.Value}"));
            _patience[i].Visible = order is not null; _patience[i].Value = order is null ? 0 : Math.Clamp(100 * (1 - order.WaitRatio), 0, 100);
            ((StyleBoxFlat)_patience[i].GetThemeStylebox("fill")).BgColor = order?.WaitRatio > .84 ? new("#B85B46") : order?.WaitRatio > .6 ? new("#B18A44") : new("#719D79");
        }
        _board.Title = $"豆干切丝 · Lv{k.Board.Data.Level}";
        _board.Detail = k.Board.Cutting ? $"按住往复切丝  {k.Board.Progress:P0}\n达到{k.Board.Data.Snap:P0}自动完成" : $"按住砧板，左右往复切丝\n每块{k.Board.Data.Yield}份 · 生豆干{k.Tofu.Count}/3";
        _board.Meter = k.Board.Progress; _board.Active = k.Board.Cutting;
        _cutStock.Title = $"干丝备料  {k.Board.Portions}/{k.Board.Data.Capacity}"; _cutStock.Detail = "拖一份到右侧漏勺"; _cutStock.Amount = k.Board.Portions;
        _scald.Title = k.Scald.Ready ? $"烫干丝 · {Quality(k.Scald.Quality)}" : $"漏勺三烫   {k.Scald.Dips}/3";
        _scald.Detail = k.Scald.Ready ? "已调味 · 拖入早茶托盘" : k.Scald.SeasonRemaining > 0 ? "正在淋入调味料…" : !k.Scald.Loaded ? "从备料盘拖入1份干丝" : k.Scald.Immersed ? $"浸入 {k.Scald.ImmersionSeconds:0.0}秒 · 0.3秒后上提" : k.Scald.Dips >= 3 ? "三烫已锁定 · 点击下方调味" : "按住从上向下拖，再提回上方";
        _scald.Amount = k.Scald.Dips; _scald.Active = k.Scald.Immersed;
        _tea.Title = s.Day.Day < 2 ? "绿杨春茶 · Day 2开放" : $"绿杨春茶  {k.Tea.Count}/6";
        _tea.Detail = k.TeaReady ? "已取一杯 · 拖入托盘" : k.TeaRemaining > 0 ? "取茶中…" : "点击取茶，0.3秒后拖入托盘"; _tea.Amount = s.Day.Day >= 2 ? k.Tea.Count : 0;
        _tray.Title = s.Selected is null ? "早茶托盘 · 先选茶客" : $"{s.Selected.Type.Name} #{s.Selected.Plan.Id} 的托盘"; _tray.Detail = "";
        _trayText.Text = s.Selected is null ? "选择上方顾客\n将成品拖到这里" : string.Join("\n", s.Selected.Template.Items.Select(i => $"{_catalog.Product(i.Key).Name}  {s.Selected.Count(i.Key)}/{i.Value}")) + (s.Selected.Complete ? "\n已经齐备，可以出餐" : "\n切换茶客，已放商品保留");
        _serve.Disabled = !CanWork() || s.Selected?.Complete != true;
        for (int i = 0; i < 2; i++)
        {
            var steamer = i < k.Steamers.Length ? k.Steamers[i] : null;
            _steam[i].Title = steamer is null ? i == 0 ? "蒸笼 · Day 3开放" : "第二层 · 蒸笼Lv3开放" : $"第{i + 1}层  {steamer.Quantity}/{steamer.Data.Capacity}  {(steamer.ProductId == "" ? "空笼" : _catalog.Product(steamer.ProductId).Name)}";
            _steam[i].Detail = steamer is null ? "" : steamer.State switch { YangzhouSteamState.Empty => "装入一种生坯，再盖笼开蒸", YangzhouSteamState.Loaded => "已装笼 · 可继续添加或盖笼", YangzhouSteamState.Steaming => $"蒸制中 {steamer.Elapsed:0.0}/{steamer.CookSeconds:0.0}秒", YangzhouSteamState.Ready => steamer.Holding ? "自动保温 · 请手动揭盖" : $"{Quality(steamer.Quality)} · 可以揭盖", _ => "已揭盖 · 点击出笼到成品盘" };
            _steam[i].Amount = steamer?.Quantity ?? 0; _steam[i].Meter = steamer is null || steamer.State == YangzhouSteamState.Empty ? 0 : steamer.Elapsed / steamer.CookSeconds;
            _steamActions[i].Text = steamer?.State switch { YangzhouSteamState.Ready => "揭开笼盖", YangzhouSteamState.Open => "出笼入盘", YangzhouSteamState.Steaming => "蒸制中…", _ => "盖笼开蒸" };
            _steamActions[i].Disabled = !CanWork() || steamer is null || steamer.State is YangzhouSteamState.Empty or YangzhouSteamState.Steaming;
            for (int p = 0; p < 2; p++) _loadButtons[i, p].Disabled = !CanWork() || steamer is null || steamer.State is not (YangzhouSteamState.Empty or YangzhouSteamState.Loaded) || p == 1 && s.Day.Day < 5;
            _stock[i].Title = $"{(i == 0 ? "三丁包" : "翡翠烧卖")}  {(i == 0 ? k.Buns.Count : k.Siumai.Count)}";
            _stock[i].Detail = "成品拖入托盘"; _stock[i].Amount = i == 0 ? k.Buns.Count : k.Siumai.Count;
            _steam[i].Refresh(); _stock[i].Refresh();
        }
        var stocks = new[] { k.Tofu, k.RawBuns, k.RawSiumai, k.Seasoning, k.Tea }; int index = 0;
        foreach (var pair in _refills)
        {
            var stock = stocks[index++]; pair.Value.Disabled = !CanWork() || pair.Key == "B01" && s.Day.Day < 3 || pair.Key == "B02" && s.Day.Day < 5 || pair.Key == "T01" && s.Day.Day < 2;
            pair.Value.Text = (pair.Key switch { "tofu" => "豆干", "B01" => "三丁坯", "B02" => "烧卖坯", "season" => "调味料", _ => "绿杨春茶" }) + $" {stock.Count}/{stock.Capacity}\n" + (stock.IsRefilling ? $"补给 {stock.RemainingSeconds:0.0}秒" : pair.Key is "B01" or "B02" ? "补满 / 拖1个" : "点击补满");
        }
        foreach (var surface in new[] { _board, _cutStock, _scald, _tea, _tray }) surface.Refresh();
    }
    private static string Quality(YangzhouQuality quality) => quality switch { YangzhouQuality.Perfect => "Perfect · 最佳", YangzhouQuality.Good => "Good · 轻微不足", _ => "品质欠佳 · 仍可出售" };
    private void ShowResult()
    {
        _resultPanel.Show(); var r = Session.Result();
        _resultText.Text = $"扬州 · Day {r.Day} 营业收据\n\n今日收入   ¥{r.Revenue}\n营业额 ¥{r.Sales}  +  小费 ¥{r.Tips}\n\n完成 {r.Completed}/{r.Planned}组    离店 {r.Lost}组\n满意度 {r.Satisfaction:0.0}% · 仅统计已完成顾客\nPerfect订单 {r.PerfectOrders}    Perfect干丝 {r.PerfectGansi}份\n\n" + (r.Day == 12 ? $"本次星级 {new string('★', r.Stars)}{new string('☆', 3 - r.Stars)}\n" : $"下一天：{_catalog.Day(r.Day + 1).Title}\n");
        SaveResult();
    }
    private bool SaveResult()
    {
        if (_committed) return true;
        if (Practice) { _committed = true; _resultText.Text += "练习营业 · 本次不保存"; return true; }
        try
        {
            var commit = _save.CommitYangzhou(Session); _committed = true;
            _resultText.Text += $"已入账 ¥{commit.PermanentCoinGain} · 共享金币 ¥{_save.Data.Coins}";
            if (Session.Result().Stars == 3) _resultText.Text += "\n已收藏蟹黄汤包图鉴与扬州三星徽章";
            return true;
        }
        catch (Exception exception) { _return.Text = "保存失败 · 点击重试"; Say(exception.Message); return false; }
    }
    private void ReturnAfterResult() { if (SaveResult()) HubRequested?.Invoke(); }
}
