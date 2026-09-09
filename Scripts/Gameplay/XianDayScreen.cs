using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.UI;
using ProjectCake.Xian;

namespace ProjectCake.Gameplay;

public partial class XianDayScreen : Control
{
    public event Action? HubRequested;
    public XianSession Session { get; private set; } = null!;
    public IReadOnlyDictionary<string, XianSurface> Surfaces => _surfaces;
    public bool CanInteract => Session is not null && IsVisibleInTree() && _focused && !_exitDialog.Visible && !_results.Visible
        && !_controller.IsPaused && _controller.CurrentConfig?.CityId == StableIds.Cities.Xian && _controller.State is DayState.Running or DayState.Closing;
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private DayController _controller = null!;
    private bool _focused = true, _committed;
    private DayResult? _pendingResult;
    private readonly Dictionary<string, XianSurface> _surfaces = new();
    private readonly List<XianSurface> _customers = new();
    private readonly Dictionary<string, Button> _buttons = new();
    private Label _heading = null!, _clock = null!, _feedback = null!, _tutorial = null!, _inventory = null!;
    private PanelContainer _results = null!;
    private Label _resultText = null!;
    private ColorRect _blocker = null!;
    private ConfirmationDialog _exitDialog = null!;
    private SpinBox _batch = null!;
    private double _cutDistance, _feedbackTime;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        foreach (XianSurface surface in this.Descendants<XianSurface>())
        {
            _surfaces[surface.Name] = surface;
            surface.CanInteract = () => CanInteract;
        }
        foreach (Button button in this.Descendants<Button>())
            if (!string.IsNullOrEmpty(button.Name)) _buttons[button.Name] = button;

        void Wire(string id, Action action, bool gameplay = true)
        {
            if (!_buttons.TryGetValue(id, out Button? button)) return;
            button.Pressed += () => { if (!gameplay || CanInteract) { action(); Render(); } };
        }

        Wire("pause", Pause, false);
        Wire("exit", AskExit, false);
        Wire("oven", OvenAction);
        Wire("chop", StartChop);
        Wire("refill_meat", () => Action(Session.Meat.TryRefill(), "补肉中，0.8秒后补满。", "肉锅已满或正在补充。"));
        Wire("wrap", () => Action(Session.Sandwich.TryWrap(), "包装好了，拖给顾客或点击交付。", "切开馍并填入肉后才能包装。"));
        Wire("deliver", () => Deliver("sandwich"));
        Wire("refill_juice", () => Action(Session.Juice.TryRefill(), "补汁中，0.6秒后补满。", "腊汁已满或正在补充。"));
        Wire("deliver_soup", () => Deliver("soup"));
        Wire("refill_soup", () => Action(Session.Soup?.Stock.TryRefill() == true, "正在补汤。", "汤锅未开放、已满或正在补充。"));
        Wire("retry_save", SaveResult, false);
        Wire("result_back", () => { if (_committed) HubRequested?.Invoke(); }, false);

        for (int i = 0; i < _customers.Count; i++)
        {
            int slot = i;
            XianSurface customer = _customers[i];
            customer.Pressed = () => { if (CustomerAt(slot) is { } c) _controller.CustomerQueue!.TrySelect(c.Id); };
            customer.AcceptToken = token => token is "sandwich" or "soup" && CustomerAt(slot) is { } c
                && c.Progress.CanAccept(token == "soup" ? ProductKind.Hulatang : ProductKind.Roujiamo);
            customer.Dropped = token => { if (CustomerAt(slot) is { } c) Deliver(token, c.Id); };
        }
        XianSurface oven = _surfaces["oven"];
        oven.Pressed = OvenAction;
        XianSurface board = _surfaces["board"];
        board.Pressed = StartChop;
        board.HorizontalStroke = dx => { if (CanInteract) { Session.Board.AddMotion(dx); board.QueueRedraw(); } };
        board.GestureEnded = () => Session?.Board.EndGesture();
        XianSurface bun = _surfaces["bun"];
        bun.Pressed = () => { _cutDistance = 0; if (Session.Sandwich.State == RoujiamoState.Empty) Action(Session.Sandwich.TryTakeBun(Session.Buns), "取好馍了，从侧面划过切开。", "缺馍，请先烙一炉。"); };
        bun.HorizontalStroke = dx => { if (CanInteract && Session.Sandwich.State == RoujiamoState.Whole) { _cutDistance += dx; if (Session.Sandwich.TryCut(_cutDistance)) Feedback("馍已切开，把右边的肉拖进来。", false); } };
        bun.GestureEnded = () => _cutDistance = 0;
        bun.DragToken = () => Session.Sandwich.Prepared is null ? "" : "sandwich";
        bun.AcceptToken = token => Session.Sandwich.State == RoujiamoState.Open && token is "meat" or "juice";
        bun.Dropped = token => { if (token == "meat") AddMeat(); else AddJuice(); };
        _surfaces["meat"].DragToken = () => Session.Board.Portions > 0 ? "meat" : "";
        XianSurface juice = _surfaces["juice"];
        juice.Pressed = AddJuice;
        juice.DragToken = () => Session.Day >= 2 && Session.Juice.Count > 0 ? "juice" : "";
        XianSurface soup = _surfaces["soup"];
        soup.Pressed = ServeSoup;
        soup.DragToken = () => Session.Soup?.HasBowl == true ? "soup" : "";
        _exitDialog.Confirmed += () => { _controller.AbandonDay(); _controller.IsPaused = false; CancelGestures(); HubRequested?.Invoke(); };
    }
    public void ConnectController(DayController controller)
    {
        if (_controller is not null) _controller.DayFinished -= OnFinished;
        _controller = controller; _controller.DayFinished += OnFinished;
    }
    public override void _ExitTree() { if (_controller is not null) _controller.DayFinished -= OnFinished; }
    public bool Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        _catalog = catalog; _save = save;
        if (_controller != controller) ConnectController(controller);
        if (day < 1 || day > save.Data.Xian.HighestUnlockedDay || save.HasLoadError)
        { Feedback("当前营业日尚未解锁或存档无法读取。", true); return false; }
        if (!catalog.TryGetDay(StableIds.Cities.Xian, day, out var config)) return false;
        if (!save.ApplyStartUnlocks(config, out string error) || !controller.TryPrepareDay(StableIds.Cities.Xian, day, catalog, out error))
        { Feedback(error, true); return false; }
        Session = new XianSession(catalog, save.Data.Xian, day);
        _committed = false; _pendingResult = null; _controller.IsPaused = false;
        _results.Visible = _blocker.Visible = false; _exitDialog.Hide(); CancelGestures();
        _batch.MaxValue = Session.OvenData.Capacity; _batch.Value = Session.OvenData.Capacity;
        _tutorial.Text = Tutorial(day); Render(); return true;
    }
    public void BeginDay() { if (!_controller.TryStartDay(out string error)) Feedback(error, true); }
    public override void _Process(double delta)
    {
        if (Session is null || !IsVisibleInTree() || _controller.CurrentConfig?.CityId != StableIds.Cities.Xian) return;
        if (!_focused || _exitDialog.Visible || _controller.IsPaused || _results.Visible) { CancelGestures(); Render(); return; }
        bool working = _controller.State is DayState.Running or DayState.Closing;
        if (working) Session.Tick(delta);
        _controller.Tick(delta);
        if (_feedbackTime > 0) _feedbackTime = Math.Max(0, _feedbackTime - delta);
        Render();
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) { _focused = false; CancelGestures(); }
        if (what == NotificationApplicationFocusIn) _focused = true;
        if (what == NotificationVisibilityChanged && !IsVisibleInTree()) CancelGestures();
    }
    public override void _UnhandledKeyInput(InputEvent input)
    {
        if (IsVisibleInTree() && Session is not null && input is InputEventKey { Pressed: true, Echo: false, Keycode: Key.Escape })
        { Pause(); GetViewport().SetInputAsHandled(); }
    }
    public void CancelGestures()
    {
        _cutDistance = 0; Session?.Board.EndGesture();
        foreach (var surface in _surfaces.Values) surface.CancelGesture();
    }
    public void StartChop()
    {
        if (!CanInteract || Session.Board.IsChopping) return;
        Action(Session.Board.TryStart(Session.Meat), "按住砧板上的菜刀左右拖动。", Session.Board.Capacity - Session.Board.Portions < 2 ? "预剁肉盘还需要2个空位。" : "肉锅不足2份，请先补肉。");
    }
    public void AddMeat() { if (CanInteract) Action(Session.AddMeat(), "夹入1份肉。", "需要打开的馍、可用肉和剩余肉量空间。"); }
    public void AddJuice() { if (CanInteract) Action(Session.AddJuice(), "浇好腊汁了。", "当前不能加汁，请检查配方日期、制作步骤或库存。"); }
    public void ServeSoup()
    {
        if (!CanInteract || Session.Soup?.HasBowl == true) return;
        Action(Session.Soup?.TryServe() == true, "正在盛汤。", Session.Soup is null ? "胡辣汤Day 6开放。" : "汤锅正在工作或需要补充。");
    }
    public void OvenAction()
    {
        if (!CanInteract || Session.Oven is null) return;
        var oven = Session.Oven;
        bool ok = oven.State switch
        {
            BunOvenState.Empty => oven.TryStart((int)_batch.Value),
            BunOvenState.FirstSide => oven.TryFlip(),
            BunOvenState.Ready => oven.TryCollect(Session.Buns),
            BunOvenState.Burnt => oven.TryDiscard(),
            _ => false,
        };
        Action(ok, "白吉馍炉已操作。", oven.State == BunOvenState.Ready ? "熟馍篮装不下整批，先取用一些馍。" : "这一面还没烙好，请等提示。");
    }
    public DeliveryEvaluation? Deliver(string token, string? customerId = null)
    {
        if (!CanInteract) return null;
        DeliveredItem? item = token == "soup" ? Session.Soup?.HasBowl == true ? new DeliveredItem(ProductKind.Hulatang, "hulatang") : null : Session.Sandwich.Prepared;
        if (item is null) { Feedback(token == "soup" ? "先点击汤锅盛一碗汤。" : "请先完成肉夹馍并包装。", true); return null; }
        var result = _controller.TryDeliverXianTo(customerId ?? _controller.CustomerQueue?.SelectedCustomerId, item, token == "soup" ? () => Session.Soup!.TryTake() : Session.Sandwich.TryTake);
        Feedback(result.Message, result.Grade is DeliveryGrade.Rejected or DeliveryGrade.Incorrect); Render(); return result;
    }
    private CustomerRuntime? CustomerAt(int i) => _controller?.CustomerQueue is { } queue && i < queue.Slots.Count ? queue.Slots[i] : null;
    private void Action(bool ok, string success, string failure) => Feedback(ok ? success : failure, !ok);
    private void Feedback(string text, bool error) { if (_feedback is null) return; _feedback.Text = text; _feedback.Modulate = error ? new Color("#872F29") : new Color("#455D33"); _feedbackTime = 3; }
    private void Pause()
    {
        if (Session is null || _results.Visible || _exitDialog.Visible) return;
        _controller.IsPaused = !_controller.IsPaused; CancelGestures(); Render();
    }
    private void AskExit() { if (Session is null) return; CancelGestures(); _exitDialog.PopupCentered(); }
    public void Render()
    {
        if (Session is null) return;
        var s = Session;
        _heading.Text = $"西安 Day {s.Day} · {XianRules.Titles[s.Day - 1]}";
        _clock.Text = !_focused || _controller.IsPaused ? "已暂停" : _controller.State switch { DayState.Opening => $"开门 {_controller.OpeningRemainingSeconds:0.0}s", DayState.Closing => $"收尾 {_controller.ClosingRemainingSeconds:0.0}s", DayState.Results => "今日已打烊", _ => $"剩余 {_controller.DayRemainingSeconds:0}s  ·  ¥{_controller.Ledger?.Build().TotalRevenue ?? 0}" };
        _inventory.Text = $"熟馍 {(s.Buns.Tutorial ? "教学供应" : $"{s.Buns.Count}/{s.Buns.Capacity}")}   ·   预剁肉 {s.Board.Portions}/{s.Board.Capacity}   ·   肉锅 {s.Meat.Count}/{s.Meat.Capacity}   ·   腊汁 {(s.Day < 2 ? "明日开放" : $"{s.Juice.Count}/{s.Juice.Capacity}")}";
        if (_feedbackTime == 0) { _feedback.Text = !s.Buns.Tutorial && s.Buns.Count <= 3 ? s.Buns.Count == 0 ? "缺馍：记得再开一炉。" : "熟馍只剩3个以内，可以提前开下一炉。" : "趁空档剁肉备货，高峰时快速组装。"; _feedback.Modulate = new Color("#513D32"); }
        _buttons["pause"].Text = _controller.IsPaused ? "继续" : "暂停";
        foreach (var (id, button) in _buttons) if (id is not ("pause" or "exit" or "result_back" or "retry_save")) button.Disabled = !CanInteract;
        _buttons["oven"].Disabled |= s.Oven is null; _batch.Editable = CanInteract && s.Oven?.State == BunOvenState.Empty;
        _buttons["refill_juice"].Disabled |= s.Day < 2;
        _buttons["deliver_soup"].Disabled |= s.Soup is null; _buttons["refill_soup"].Disabled |= s.Soup is null;
        _surfaces["board"].Title = $"剁肉台 Lv{s.BoardData.Level}"; _surfaces["board"].Amount = s.Board.IsChopping ? 6 : 0;
        _surfaces["board"].Meter = s.Board.IsChopping ? s.Board.Progress / 100 : 0;
        _surfaces["board"].Detail = s.Board.IsChopping ? $"按住左右拖动 · {s.Board.Progress:0}%\n完成后得到2份肉" : s.Meat.IsRefilling ? $"肉锅补充中 {s.Meat.RemainingSeconds:0.0}s" : "点击取2份肉\n按住菜刀左右剁碎";
        var bun = _surfaces["bun"]; bun.Title = "肉夹馍组装"; bun.Stage = (int)s.Sandwich.State; bun.Amount = s.Sandwich.MeatPortions; bun.FoodColor = s.Sandwich.Quality == BunQuality.Overbrowned ? new Color("#A77547") : new Color("#E9B963");
        bun.Detail = s.Sandwich.State switch { RoujiamoState.Empty => "点击取熟馍", RoujiamoState.Whole => "按住从侧面划过，切开馍", RoujiamoState.Open => $"已夹{s.Sandwich.MeatPortions}份肉 · {(s.Sandwich.HasJuice ? "已加汁" : "未加汁")}\n把肉盘里的肉拖进来，完成后包装", _ => $"{XianRules.RecipeNames[Array.IndexOf(XianRules.Recipes, s.Sandwich.Prepared!.DefinitionId)]}\n拖给顾客，或选中顾客后交付" };
        if (s.Sandwich.Quality == BunQuality.Overbrowned) bun.Detail += "\n偏焦 · 可出餐";
        _surfaces["meat"].Title = "预剁肉盘"; _surfaces["meat"].Amount = s.Board.Portions; _surfaces["meat"].Detail = $"{s.Board.Portions}/{s.Board.Capacity}份 · 拖入馍中";
        _surfaces["juice"].Title = "腊汁"; _surfaces["juice"].Detail = s.Day < 2 ? "Day 2 开放" : s.Juice.IsRefilling ? $"补充中 {s.Juice.RemainingSeconds:0.0}s" : "点击浇汁"; _surfaces["juice"].Unavailable = s.Day < 2;
        var oven = _surfaces["oven"]; oven.Title = s.Oven is null ? "白吉馍炉 · Day 3" : $"白吉馍炉 Lv{s.OvenData.Level}"; oven.Amount = s.Oven?.Quantity ?? 0;
        oven.FoodColor = s.Oven?.Quality switch { BunQuality.Burnt => new Color("#3F342F"), BunQuality.Overbrowned => new Color("#A77547"), _ => new Color("#E9B963") };
        oven.Detail = s.Oven is null ? "先熟悉切、剁、夹\n今日提供现成熟馍" : s.Oven.State switch { BunOvenState.Empty => "选择数量，整批下炉", BunOvenState.FirstSide => s.Oven.SideSeconds >= s.OvenData.ActionSeconds ? "第一面已好 · 点击翻面" : $"第一面 {s.Oven.SideSeconds:0.0}/{s.OvenData.ActionSeconds:0.0}s", BunOvenState.SecondSide => $"第二面 {s.Oven.SideSeconds:0.0}/{s.OvenData.ActionSeconds:0.0}s", BunOvenState.Ready => s.OvenData.Automatic ? "已弹起 · 等待篮子腾出空间" : "烙好了 · 点击整批收取", _ => "焦糊了 · 点击清理" };
        if (s.Oven?.Quality == BunQuality.Overbrowned) oven.Detail += "\n偏焦 · 尽快处理";
        _buttons["oven"].Text = s.Oven?.State switch { BunOvenState.FirstSide => "整批翻面", BunOvenState.Ready => "整批收取", BunOvenState.Burnt => "清理焦馍", _ => "整批下炉" };
        var soup = _surfaces["soup"]; soup.Title = s.Soup is null ? "胡辣汤 · Day 6" : $"胡辣汤 Lv{s.SoupData.Level}";
        soup.Detail = s.Soup is null ? "快速盛汤，配成套餐" : s.Soup.HasBowl ? "汤已盛好 · 拖给顾客\n或选中顾客后点击交付" : s.Soup.RemainingSeconds > 0 ? $"盛汤中 {s.Soup.RemainingSeconds:0.0}s" : s.Soup.Stock.IsRefilling ? $"补锅中 {s.Soup.Stock.RemainingSeconds:0.0}s" : $"锅内 {s.Soup.Stock.Count}/{s.Soup.Stock.Capacity}份\n点击盛一碗";
        soup.Unavailable = s.Soup is null;
        for (int i = 0; i < _customers.Count; i++)
        {
            var view = _customers[i]; var customer = CustomerAt(i);
            view.Title = customer is null ? "等待来客" : $"{customer.Type.DisplayName}  ·  {(customer.WasServed ? "已完成" : $"还可等{Math.Max(0, customer.Type.LeaveAtSeconds * (1 - customer.PatienceProgress)):0}s")}";
            view.Selected = customer is not null && _controller.CustomerQueue?.SelectedCustomerId == customer.Id;
            view.Amount = customer is null ? 0 : 1;
            view.Meter = customer?.PatienceProgress ?? 0;
            view.Detail = customer is null ? "空档可以提前备货" : string.Join("\n", customer.Order.Lines.Select((line, index) => $"{(customer.Progress.GetRemainingQuantity(index) == 0 ? "✓" : "·")} {(line.ProductKind == ProductKind.Hulatang ? "胡辣汤" : _catalog.RecipesById[line.DefinitionId].DisplayName)}  {customer.Progress.GetDeliveredQuantity(index)}/{line.Quantity}"));
        }
        foreach (var surface in _surfaces.Values) surface.Refresh();
    }
    private void OnFinished(DayResult result)
    {
        if (_controller.CurrentConfig?.CityId != StableIds.Cities.Xian || _committed) return;
        CancelGestures(); _pendingResult = result; _results.Visible = _blocker.Visible = true; SaveResult();
    }
    private void SaveResult()
    {
        if (_pendingResult is not { } result || _committed) return;
        try
        {
            var commit = _save.CommitDay(result, _controller.CurrentPlan!, _controller.CurrentConfig!); _committed = true;
            string stars = result.Day == 12 ? $"\n西安评级 {new string('★', commit.EarnedStars)}{new string('☆', 3 - commit.EarnedStars)}" : "";
            _resultText.Text = $"Day {result.Day} · {XianRules.Titles[result.Day - 1]}\n\n今日收入 ¥{result.TotalRevenue}\n营业额 ¥{result.SaleRevenue} + 小费 ¥{result.Tips}\n金币增加 ¥{commit.PermanentCoinGain}\n\n完成 {result.CompletedCustomers} 位 · 流失 {result.LostCustomers} 位\n满意度 {result.Satisfaction:0.0}%\nPerfect {result.PerfectOrders} 单 · 错误 {result.IncorrectOrders} 单{stars}\n\n{(commit.NewChapterCompletion ? "西安已点亮！" : _controller.CurrentConfig!.CompletionUnlocks.Count > 0 ? "新的设备升级已开放，回首页选购。" : "成绩已写入西安经营手账。")}";
            GD.Print($"XIAN_SHIFT day={result.Day} completed={result.CompletedCustomers}/{result.PlannedCustomers} chops={Session.Board.CompletedChops} no_bun_seconds={Session.NoBunSeconds:0.0} no_meat_seconds={Session.NoChoppedMeatSeconds:0.0}");
        }
        catch (IOException error) { _resultText.Text = $"保存失败：{error.Message}\n\n收入和进度已回滚，可重试保存。"; }
        _buttons["retry_save"].Visible = !_committed; _buttons["result_back"].Disabled = !_committed;
    }
    private static string Tutorial(int day) => day switch
    {
        1 => "① 点击取馍，按住横划切开　② 点击砧板，按住左右剁肉　③ 把肉拖入馍中　④ 包装，拖给顾客",
        2 => "加汁肉夹馍：填肉后点击腊汁，再包装。注意订单是否需要加汁。",
        3 => "白吉馍炉到了：整批下炉 → 3秒翻面 → 第二面3秒 → 收进熟馍篮。先用开店备好的4个馍。",
        4 => "提前备货：没客人时先剁肉；每次剁肉产2份，高峰时直接从肉盘取用。",
        5 => "多肉肉夹馍需要2份肉：从肉盘拖两次。多肉加汁将在Day 7开放。",
        6 => "胡辣汤：点击锅盛汤，0.6秒后拖给顾客。套餐可分次交付，商品齐全才结算。",
        7 => "四种肉夹馍已齐全。上班族耐心36秒，及时服务可获得20% Perfect小费。",
        8 => "熟客经常点加汁馍配汤，偶尔换标准馍；提前备货，也要看清订单。",
        9 => "双份订单来了：最多2个肉夹馍，可逐件交付。今天同屏只会等待一位双份顾客。",
        10 => "完成今天可购买自动馍炉：最后两天自动翻面和出炉，把注意力留给组装。",
        11 => "长安早高峰：观察肉盘、熟馍和上班族耐心，趁空档补一炉、剁两次。",
        _ => "三星：完成24名顾客，满意度90%，错误订单不超过2。高级设备减轻操作，库存预判决定节奏。",
    };
}
