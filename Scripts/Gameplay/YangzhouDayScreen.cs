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
    private readonly Button[] _customers = new Button[5];
    private readonly ProgressBar[] _patience = new ProgressBar[5];
    private readonly Dictionary<string, Button> _refills = new();
    private bool _committed, _focusLost, _pausedBeforeLeave;
    private double _feedbackSeconds;
    private PancakeAudio _audio = null!;
    private ulong _lastCutSound;
    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        BuildBusinessBook();
        void FitCanvas()
        {
            float scale = Math.Min(Size.X / 1920, Size.Y / 1080);
            _canvas.Scale = Vector2.One * scale;
            _canvas.Position = (Size - _canvas.Size * scale) * .5f;
        }
        Resized += FitCanvas;
        FitCanvas();
        foreach (YangzhouSurface surface in this.Descendants<YangzhouSurface>()) surface.CanInteract = CanWork;

        _pause.Pressed += () =>
        {
            if (Session is null || _leave.Visible) return;
            Session.Pause(!Session.Paused); CancelGestures(); Render();
        };
        this.FindButton("返回店铺").Pressed += RequestLeave;
        for (int i = 0; i < _customers.Length; i++)
        {
            int index = i;
            _customers[i].Pressed += () => { if (CanWork() && index < Session.Waiting.Count) Session.Select(Session.Waiting[index].Plan.Id); Render(); };
        }
        for (int i = 0; i < _steam.Length; i++)
        {
            int layer = i;
            _steam[i].AcceptToken = token => token is "raw:B01" or "raw:B02";
            _steam[i].Dropped = token => Act(() => Session.LoadSteamer(layer, token[4..], 1), "不能混蒸；请检查容量、解锁日期与生坯库存。");
            Button[] loads = this.Descendants<Button>()
                .Where(button => button.Position.Y > _steam[i].Position.Y + 140 && button.Position.Y < _steam[i].Position.Y + 225
                    && (button.Text.StartsWith("三丁包", StringComparison.Ordinal) || button.Text.StartsWith("烧卖", StringComparison.Ordinal)))
                .OrderBy(button => button.Position.X).ToArray();
            if (loads.Length >= 2)
            {
                _loadButtons[i, 0] = loads[0];
                _loadButtons[i, 1] = loads[1];
                loads[0].Pressed += () => Act(() => Session.LoadSteamer(layer, "B01", 2), "装笼失败：检查库存、剩余格数；准备阶段只允许一笼。");
                loads[1].Pressed += () => Act(() => Session.LoadSteamer(layer, "B02", 2), "Day 5开放烧卖；同一层不能混蒸。");
            }
            _steamActions[i].Pressed += () => Act(() => Session.SteamAction(layer), "请先装笼、等熟后揭盖；成品盘空间不足时先出餐。");
        }
        _board.Pressed = () => { if (!Session.Kitchen.Board.Cutting) Session.Cut(); };
        _board.Motion = (_, movement, dt) =>
        {
            Session.Stroke(movement.X, dt);
            if (Session.Kitchen.Board.Cutting && Time.GetTicksMsec() - _lastCutSound > 150)
            { _lastCutSound = Time.GetTicksMsec(); _audio.Play(PancakeSound.Stroke); }
        };
        _cutStock.DragToken = () => Session.Kitchen.Board.Portions > 0 ? "cut" : "";
        _scald.AcceptToken = token => token == "cut";
        _scald.Dropped = _ => Act(Session.LoadGansi, "漏勺已有一份，先调味并放入托盘。");
        _scald.Motion = (position, _, _) =>
        {
            if (position.Y > 190) Session.Dip();
            else if (position.Y < 130 && Session.Lift()) _audio.Play(PancakeSound.Sizzle);
        };
        _scald.Released = () => Session?.Kitchen.Scald.CancelGesture();
        _scald.DragToken = () => Session.Kitchen.Scald.Ready ? "G01" : "";
        this.FindButton("调味 · 一次完成").Pressed += () => Act(() => Session.Season(), "至少有效烫1次并提起漏勺；调味料不足请补满。");
        _tea.Pressed = () => { if (!Session.Kitchen.TeaReady) Act(Session.TakeTea, "茶在Day 2开放；无茶时补满茶盘。"); };
        _tea.DragToken = () => Session.Kitchen.TeaReady ? "T01" : "";
        _tray.AcceptToken = token => token is "G01" or "B01" or "B02" or "T01";
        _tray.Dropped = Stage;
        _serve.Pressed += () =>
        {
            Act(() => { bool ok = Session.Serve(); if (ok) Say("早茶上齐了！"); return ok; }, "还没凑齐这桌早茶。");
            if (CanWork()) _audio.Play(PancakeSound.Success);
        };
        _stock[0].DragToken = () => Session.Kitchen.HasFood("B01") ? "B01" : "";
        _stock[1].DragToken = () => Session.Kitchen.HasFood("B02") ? "B02" : "";
        var supplies = new[] { ("tofu", "补豆干"), ("B01", "补三丁坯"), ("B02", "补烧卖坯"), ("season", "补调味"), ("T01", "补茶") };
        foreach ((string id, string text) in supplies)
        {
            Button button = this.FindButton(text);
            _refills[id] = button;
            if (button is GuangzhouDragSource source)
            {
                source.Payload = "raw:" + id;
                source.CanDrag = () => CanWork() && id is "B01" or "B02";
            }
            button.Pressed += () => Act(() => Session.Refill(id), "库存已满或正在补给。");
        }
        _leave.Confirmed += () => { _leave.Hide(); Session.Pause(true); HubRequested?.Invoke(); };
        _leave.Canceled += () => Session.Pause(_pausedBeforeLeave);
        _return.Pressed += ReturnAfterResult;
    }
    public bool Initialize(YangzhouCatalog catalog, SaveService save, int day, bool practice = false)
    {
        if (practice && !OS.GetCmdlineUserArgs().Contains("--dev-ui")) return false;
        if (!practice && !save.PrepareYangzhou(day, out _)) return false;
        _catalog = catalog; _save = save; Practice = practice;
        var city = save.Data.Yangzhou;
        Session = new(catalog, day, practice ? 2 : city.EquipmentLevels.GetValueOrDefault(YangzhouCatalog.BoardId, 1), practice ? 2 : city.EquipmentLevels.GetValueOrDefault(YangzhouCatalog.SteamerId, 1));
        _book.Reset(); _committed = _focusLost = false; _resultPanel.Hide(); _leave.Hide(); _return.Text = "收好收入 · 返回经营首页";
        _feedback.Text = ""; Render(); return true;
    }
    public override void _Process(double delta)
    {
        if (!IsVisibleInTree() || Session is null) return;
        if (!_focusLost && !_book.IsOpen) Session.Tick(delta);
        if (_feedbackSeconds > 0) { _feedbackSeconds -= delta; if (_feedbackSeconds <= 0) _feedback.Text = ""; }
        if (Session.Phase == YangzhouPhase.Results && !_book.IsOpen) ShowResult();
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
    private bool CanWork() => IsVisibleInTree() && !_book.IsOpen && Session?.CanWork == true && !_focusLost && !_leave.Visible;
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
        for (int i = 0; i < _customers.Length; i++)
        {
            var order = i < s.Waiting.Count ? s.Waiting[i] : null;
            _customers[i].Disabled = order is null || !CanWork();
            _customers[i].Text = order is null ? "静候下一桌茶客" : $"{(order == s.Selected ? "当前托盘 · " : "")}{order.Type.Name} #{order.Plan.Id}  {order.Mood}\n{order.Template.Name} · ¥{order.Price}\n" + string.Join("\n", order.Template.Items.Select(item => $"{_catalog.Product(item.Key).Name}  {order.Count(item.Key)}/{item.Value}"));
            _patience[i].Visible = order is not null;
            PatienceBarPresentation.Render(_patience[i], order is null ? 0 : 1 - order.WaitRatio);
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
    private void ShowResult() { _resultPanel.Hide(); SaveResult(); }
    private bool SaveResult()
    {
        if (_committed) return true;
        var model = YangzhouBusinessBook.Commit(Session, _catalog, _save, Practice);
        _committed = !model.CanRetry; _book.ShowResult(model); return _committed;
    }
    private void ReturnAfterResult() { if (SaveResult()) HubRequested?.Invoke(); }
}
