using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Guangzhou;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class GuangzhouDayScreen : Control
{
    public event Action? HubRequested;
    public GuangzhouSession Session { get; private set; } = null!;
    public bool Practice { get; private set; }
    public IReadOnlyList<GuangzhouTrayView> TrayViews => _trays;
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private DayController _controller = null!;
    private Control _canvas = null!, _overlay = null!;
    private Label _title = null!, _clock = null!, _income = null!, _feedback = null!, _tutorial = null!, _results = null!;
    private readonly GuangzhouCustomerCard[] _customers = new GuangzhouCustomerCard[4];
    private readonly Label[] _orders = new Label[4];
    private readonly ProgressBar[] _patience = new ProgressBar[4];
    private readonly GuangzhouTrayView[] _trays = new GuangzhouTrayView[2];
    private readonly Button[] _cuts = new Button[2], _discards = new Button[2];
    private readonly GuangzhouDragSource[] _deliverRolls = new GuangzhouDragSource[2];
    private readonly Button[] _baskets = new Button[4];
    private readonly Dictionary<string, GuangzhouDragSource> _ingredients = new(), _dimSum = new();
    private readonly Dictionary<string, Button> _refills = new();
    private Button _loadSiuMai = null!, _loadHarGow = null!, _pourTea = null!, _refillTea = null!, _pause = null!, _back = null!, _retry = null!;
    private GuangzhouDragSource _teaCup = null!;
    private Label _cabinetTitle = null!, _stoveTitle = null!;
    private ConfirmationDialog _abandon = null!;
    private bool _focused = true, _manuallyPaused, _committed;
    private int _selectedTray;
    private string _tool = "";
    private DayResult? _pendingResult;
    private bool CanInteract => IsVisibleInTree() && _focused && !_manuallyPaused && !_abandon.Visible && !_committed
        && _controller is not null && _controller.State is DayState.Running or DayState.Closing;

    public override void _Ready() => Build();
    public void ConnectController(DayController controller)
    {
        if (_controller is not null) _controller.DayFinished -= OnFinished;
        _controller = controller; controller.DayFinished += OnFinished;
    }
    public override void _ExitTree() { if (_controller is not null) _controller.DayFinished -= OnFinished; }

    public bool Initialize(DataCatalog catalog, SaveService save, DayController controller, int day, bool practice = false)
    {
        _catalog = catalog; _save = save;
        if (_controller != controller) ConnectController(controller);
        if (!catalog.TryGetDay(StableIds.Cities.Guangzhou, day, out var config)) return false;
        if (!practice && (save.HasLoadError || day > save.Data.Guangzhou.HighestUnlockedDay)) return false;
        if (!practice && !save.ApplyStartUnlocks(config, out string saveError)) { Feedback(saveError); return false; }
        if (!controller.TryPrepareDay(StableIds.Cities.Guangzhou, day, catalog, out string error)) { Feedback(error); return false; }
        var city = practice ? SaveService.NewGuangzhouProgress() : save.Data.Guangzhou;
        if (practice) foreach (string id in GuangzhouRules.Equipment) city.EquipmentLevels[id] = 2;
        Session = new(catalog, city, config); Practice = practice;
        controller.GuangzhouStockCount = Session.DimSum.Count;
        _selectedTray = 0; _tool = ""; _committed = _manuallyPaused = false; _pendingResult = null;
        _focused = true; _overlay.Visible = false; _abandon.Hide(); controller.IsPaused = false;
        for (int i = 0; i < _trays.Length; i++)
        {
            _trays[i].CancelGesture(); _trays[i].Visible = i < Session.Trays.Count;
            if (_trays[i].Visible) _trays[i].Tray = Session.Trays[i];
        }
        _title.Text = $"广州 · 蒸汽早茶    /    DAY {day:00}" + (practice ? "    练习 · 不保存" : "");
        _tutorial.Text = Tutorial(day);
        _stoveTitle.Text = $"肠粉主操作    {Session.StoveData.DisplayName}";
        _cabinetTitle.Text = Session.Cabinet is null ? "点心蒸柜 · Day 5 开放" : $"点心蒸柜 · Lv{Session.CabinetData.Level}";
        Feedback("先看订单，再铺浆。拖动蒸屉手柄推入或拉出。"); Render(); return true;
    }
    public void BeginDay() { if (!_controller.TryStartDay(out string error)) Feedback(error); }

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree() || Session is null || _controller.CurrentConfig?.CityId != StableIds.Cities.Guangzhou) return;
        bool paused = !_focused || _manuallyPaused || _abandon.Visible;
        _controller.IsPaused = Session.Paused = paused;
        _controller.Tick(delta);
        if (_controller.State is DayState.Running or DayState.Closing) Session.Tick(delta);
        Render();
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) { _focused = false; CancelGestures(); }
        if (what == NotificationApplicationFocusIn) _focused = true;
        if (what == NotificationVisibilityChanged && !IsVisibleInTree()) CancelGestures();
    }
    private void CancelGestures() { foreach (var tray in _trays) tray?.CancelGesture(); }

    private void Build()
    {
        _canvas = GuangzhouUi.Canvas(this);
        var bg = new ColorRect { Color = GuangzhouUi.Background, Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Ignore }; _canvas.AddChild(bg);
        _title = GuangzhouUi.Text(_canvas, "广州 · 蒸汽早茶", new(48, 22, 950, 68), 36);
        _clock = GuangzhouUi.Text(_canvas, "", new(1070, 22, 210, 68), 27);
        _income = GuangzhouUi.Text(_canvas, "", new(1290, 22, 220, 68), 25, GuangzhouUi.Green);
        _pause = GuangzhouUi.Button(_canvas, "暂停", new(1550, 30, 120, 52), () => { _manuallyPaused = !_manuallyPaused; CancelGestures(); });
        GuangzhouUi.Button(_canvas, "返回经营", new(1690, 30, 180, 52), RequestAbandon);
        for (int i = 0; i < 4; i++)
        {
            int slot = i; float x = 48 + i * 460;
            _customers[i] = GuangzhouUi.Button(_canvas, new GuangzhouCustomerCard { Text = "", Alignment = HorizontalAlignment.Left }, new(x, 108, 444, 206), () => SelectCustomer(slot));
            _orders[i] = GuangzhouUi.Text(_customers[i], "", new(20, 12, 404, 157), 23);
            _patience[i] = new ProgressBar { Position = new(20, 178), Size = new(404, 10), ShowPercentage = false, MouseFilter = MouseFilterEnum.Ignore };
            _patience[i].AddThemeStyleboxOverride("background", GuangzhouUi.Style(new Color("#DDE5D6"), 0));
            _patience[i].AddThemeStyleboxOverride("fill", GuangzhouUi.Style(GuangzhouUi.Green, 0)); _customers[i].AddChild(_patience[i]);
            _customers[i].Accepts = payload => CanDropOnCustomer(slot, payload);
            _customers[i].Delivered = payload => DeliverPayload(payload, CustomerAt(slot)?.Id);
        }
        _feedback = GuangzhouUi.Text(_canvas, "", new(48, 322, 1824, 48), 22, GuangzhouUi.Green);
        BuildCabinet(); BuildTrays(); BuildTea(); BuildIngredients();
        _abandon = new ConfirmationDialog { Title = "结束本次营业？", DialogText = "本次尚未结算的收入和制作进度将不保存。", OkButtonText = "放弃本次营业", CancelButtonText = "继续营业" };
        _abandon.Confirmed += () => { _controller.AbandonDay(); _controller.IsPaused = false; HubRequested?.Invoke(); }; AddChild(_abandon);
        BuildResults();
    }
    private void BuildTrays()
    {
        _stoveTitle = GuangzhouUi.Text(_canvas, "肠粉主操作", new(466, 374, 1014, 42), 25);
        for (int i = 0; i < 2; i++)
        {
            int index = i; float x = 466 + i * 516;
            var tray = new GuangzhouTrayView { Position = new(x, 425), Size = new(494, 380), Index = i,
                CanInteract = () => CanInteract, SauceSelected = () => _tool == GuangzhouRules.Sauce,
                SauceRequested = () => ApplySauce(index), Selected = () => _selectedTray = index,
                Feedback = Feedback, IngredientDropped = id => ApplyIngredient(index, id), IngredientAllowed = id => CanAddIngredient(index, id) };
            _trays[i] = tray; _canvas.AddChild(tray);
            _cuts[i] = GuangzhouUi.Button(_canvas, "切段", new(x, 820, 112, 62), () => { if (CanInteract) { Session.Trays[index].TryCut(); Render(); } });
            _deliverRolls[i] = GuangzhouUi.Button(_canvas, new GuangzhouDragSource { Text = "交付肠粉", Payload = $"roll:{i}", CanDrag = () => CanInteract && Session.Trays.Count > index && Session.Trays[index].State == RiceRollState.Ready },
                new(x + 122, 820, 244, 62), () => DeliverPayload($"roll:{index}", SelectedCustomerId), true);
            _discards[i] = GuangzhouUi.Button(_canvas, "丢弃", new(x + 376, 820, 118, 62), () => { if (CanInteract) { Session.Trays[index].Reset(); _trays[index].CancelGesture(); } });
        }
    }
    private void BuildCabinet()
    {
        GuangzhouUi.Panel(_canvas, new(48, 374, 394, 508));
        _cabinetTitle = GuangzhouUi.Text(_canvas, "点心蒸柜", new(66, 382, 358, 40), 25);
        _loadSiuMai = GuangzhouUi.Button(_canvas, "放一笼烧卖", new(66, 431, 171, 54), () => LoadBasket(GuangzhouRules.SiuMai));
        _loadHarGow = GuangzhouUi.Button(_canvas, "放一笼虾饺", new(247, 431, 177, 54), () => LoadBasket(GuangzhouRules.HarGow));
        for (int i = 0; i < 4; i++)
        {
            int index = i;
            _baskets[i] = GuangzhouUi.Button(_canvas, $"第{i + 1}层", new(66, 498 + i * 59, 358, 51), () =>
            {
                if (!CanInteract || Session.Cabinet is null) return;
                if (!Session.Cabinet.TryStock(index, Session.DimSum)) Feedback("尚未蒸熟，或该蒸点库存已满4笼。");
            });
        }
        foreach (var pair in new[] { (GuangzhouRules.SiuMai, 66), (GuangzhouRules.HarGow, 247) })
        {
            string id = pair.Item1;
            _dimSum[id] = GuangzhouUi.Button(_canvas, new GuangzhouDragSource { Text = "", Payload = "dim:" + id, CanDrag = () => CanInteract && Session.DimSum.Count(id) > 0 },
                new(pair.Item2, 752, 171, 96), () => DeliverPayload("dim:" + id, SelectedCustomerId));
        }
        GuangzhouUi.Text(_canvas, "熟后点击层位取出 · 每种最多4笼", new(66, 851, 358, 25), 18, GuangzhouUi.Muted);
    }
    private void BuildTea()
    {
        GuangzhouUi.Panel(_canvas, new(1506, 374, 366, 508));
        GuangzhouUi.Text(_canvas, "一杯早茶", new(1530, 386, 316, 40), 27);
        _pourTea = GuangzhouUi.Button(_canvas, "取茶 · 0.3秒", new(1530, 440, 316, 62), () => { if (CanInteract) Session.Tea?.TryPour(); });
        _teaCup = GuangzhouUi.Button(_canvas, new GuangzhouDragSource { Text = "交付早茶", Payload = "tea", CanDrag = () => CanInteract && Session.Tea?.HasCup == true }, new(1530, 518, 316, 62), () => DeliverPayload("tea", SelectedCustomerId), true);
        _refillTea = GuangzhouUi.Button(_canvas, "补茶 · 0.5秒", new(1530, 596, 316, 54), () => { if (CanInteract) Session.Tea?.Stock.TryRefill(); });
        _tutorial = GuangzhouUi.Text(_canvas, "", new(1530, 674, 316, 190), 21, GuangzhouUi.Muted);
    }
    private void BuildIngredients()
    {
        for (int i = 0; i < GuangzhouRules.Ingredients.Length; i++)
        {
            string id = GuangzhouRules.Ingredients[i]; float x = 48 + i * 369;
            _ingredients[id] = GuangzhouUi.Button(_canvas, new GuangzhouDragSource { Text = GuangzhouRules.Name(id), Payload = id,
                CanDrag = () => CanInteract && Session.IngredientUnlocked(id) && !Session.Ingredients[id].Refilling && Session.Ingredients[id].Count > 0 },
                new(x, 916, 350, 65), () =>
                {
                    if (!CanInteract) return;
                    if (id == GuangzhouRules.Sauce) { _tool = id; Feedback("已拿起豉油壶，在切好的肠粉上短划一下。"); }
                    else if (id == GuangzhouRules.Batter) Feedback("把米浆拖到空蒸盘，再按住鼠标铺开。");
                    else ApplyIngredient(_selectedTray, id);
                });
            _refills[id] = GuangzhouUi.Button(_canvas, "补满 · 0.8秒", new(x, 991, 350, 48), () => { if (CanInteract && Session.IngredientUnlocked(id)) Session.Ingredients[id].TryRefill(); });
        }
        GuangzhouUi.Text(_canvas, "铺浆 → 加料 → 推入 → 拉出 → 刮卷 → 切段 → 淋汁 → 交付    ·    点击顾客可选中，成品也可直接拖给顾客", new(48, 1045, 1824, 25), 19, GuangzhouUi.Muted);
    }
    private bool CanAddIngredient(int tray, string id)
    {
        if (!CanInteract || tray >= Session.Trays.Count || !Session.IngredientUnlocked(id) || !Session.Ingredients.TryGetValue(id, out var stock) || stock.Count == 0 || stock.Refilling) return false;
        var t = Session.Trays[tray];
        return id == GuangzhouRules.Batter ? t.State == RiceRollState.Empty
            : id != GuangzhouRules.Sauce && t.State == RiceRollState.Spreading && t.SpreadProgress >= .65 && !t.Ingredients.Contains(id);
    }
    private void ApplyIngredient(int tray, string id)
    {
        if (!CanAddIngredient(tray, id)) { Feedback("先铺浆至65%，蒸前加料；重复配料不会消耗库存。"); return; }
        if (id == GuangzhouRules.Batter) Session.Trays[tray].TryPour(Session.Ingredients[id]); else Session.AddIngredient(tray, id);
        _selectedTray = tray; _tool = ""; Render();
    }
    private void ApplySauce(int tray)
    {
        if (!CanInteract) return;
        if (Session.Trays[tray].TrySauce(Session.Ingredients[GuangzhouRules.Sauce])) { _tool = ""; Feedback("淋汁完成，可以出餐。"); }
        else Feedback("豉油不足或正在补货。");
    }
    private void LoadBasket(string id)
    {
        if (!CanInteract || Session.Cabinet is null) return;
        int index = Enumerable.Range(0, Session.Cabinet.Baskets.Count).FirstOrDefault(i => Session.Cabinet.Baskets[i].Empty, -1);
        if (index < 0 || !Session.LoadBasket(index, id)) Feedback("蒸柜已满，请先取出熟蒸点。");
    }
    private CustomerRuntime? CustomerAt(int slot) => _controller?.CustomerQueue?.Slots.ElementAtOrDefault(slot);
    private string? SelectedCustomerId => _controller.CustomerQueue?.SelectedCustomerId;
    private void SelectCustomer(int slot) { if (CanInteract && CustomerAt(slot) is { } c) _controller.CustomerQueue!.TrySelect(c.Id); }
    private bool TryGetItem(string payload, out DeliveredItem item, out Func<bool> consume)
    {
        item = null!; consume = () => false;
        if (payload.StartsWith("roll:") && int.TryParse(payload.AsSpan(5), out int index) && index >= 0 && index < Session.Trays.Count)
        {
            var tray = Session.Trays[index]; if (tray.State != RiceRollState.Ready) return false;
            item = new(ProductKind.RiceRoll, tray.RecipeId, GuangzhouQuality: tray.FoodQuality); consume = tray.TryTake; return true;
        }
        if (payload.StartsWith("dim:"))
        {
            string id = payload[4..]; if (!Session.DimSum.TryPeek(id, out var quality)) return false;
            item = new(GuangzhouRules.DimSumKind(id), id, GuangzhouQuality: new(true, DimSum: quality)); consume = () => Session.DimSum.TryTake(id); return true;
        }
        if (payload == "tea" && Session.Tea?.HasCup == true)
        { item = new(ProductKind.MorningTea, GuangzhouRules.Tea, GuangzhouQuality: new(true)); consume = Session.Tea.TryTakeCup; return true; }
        return false;
    }
    private bool CanDropOnCustomer(int slot, string payload) => CanInteract && CustomerAt(slot) is { } c
        && c.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry
        && TryGetItem(payload, out var item, out _) && c.Progress.CanAccept(item, out _);
    public DeliveryEvaluation? DeliverPayload(string payload, string? customerId)
    {
        if (!CanInteract || !TryGetItem(payload, out var item, out var consume)) return null;
        var result = _controller.TryDeliverGuangzhouTo(customerId, item, consume); Feedback(result.Message); Render(); return result;
    }
    private void Feedback(string message) { if (_feedback is not null) _feedback.Text = message; }
    public void Render()
    {
        if (Session is null) return;
        _pause.Text = _manuallyPaused ? "继续" : "暂停";
        _clock.Text = _manuallyPaused || !_focused || _abandon.Visible ? "已暂停" : _controller.State switch
        {
            DayState.Opening => $"开店倒数 {_controller.OpeningRemainingSeconds:0}",
            DayState.Closing => $"收尾 {_controller.ClosingRemainingSeconds:0}s",
            DayState.Results => "营业结束", _ => $"剩余 {_controller.DayRemainingSeconds:0}s",
        };
        _income.Text = $"¥{(_controller.Ledger?.SaleRevenue ?? 0) + (_controller.Ledger?.Tips ?? 0)}  ·  {_controller.Ledger?.CompletedCustomers ?? 0}人";
        for (int i = 0; i < 4; i++)
        {
            var c = CustomerAt(i); _customers[i].Disabled = c is null || !CanInteract;
            _patience[i].Visible = c is not null;
            _customers[i].AddThemeStyleboxOverride("normal", GuangzhouUi.Style(c?.Id == SelectedCustomerId ? new Color("#D4E4CC") : GuangzhouUi.Paper, c?.Id == SelectedCustomerId ? 3 : 1));
            if (c is null) { _orders[i].Text = $"{i + 1:00}    等待街坊\n\n肠粉现蒸 · 点心提前备"; continue; }
            string lines = string.Join("\n", c.Order.Lines.Select((l, n) => $"{(c.Progress.GetRemainingQuantity(n) == 0 ? "✓" : "·")} {LineName(l)}  {c.Progress.GetDeliveredQuantity(n)}/{l.Quantity}"));
            _orders[i].Text = $"{c.Type.DisplayName}  ¥{c.Order.BasePrice}\n{lines}";
            _patience[i].Value = Math.Max(0, 100 * (1 - c.PatienceProgress));
        }
        for (int i = 0; i < 2; i++)
        {
            bool exists = i < Session.Trays.Count; _cuts[i].Visible = _deliverRolls[i].Visible = _discards[i].Visible = exists;
            if (!exists) continue;
            var t = Session.Trays[i]; _trays[i].Active = i == _selectedTray; _trays[i].QueueRedraw();
            _cuts[i].Disabled = !CanInteract || t.State != RiceRollState.Rolling || t.RollProgress < .75;
            _deliverRolls[i].Disabled = !CanInteract || t.State != RiceRollState.Ready;
            _discards[i].Disabled = !CanInteract || t.State == RiceRollState.Empty;
        }
        _loadSiuMai.Disabled = !CanInteract || Session.Cabinet is null;
        _loadHarGow.Disabled = !CanInteract || !Session.Config.AvailableProductKinds.Contains(ProductKind.HarGow);
        for (int i = 0; i < 4; i++)
        {
            var b = Session.Cabinet?.Baskets.ElementAtOrDefault(i); _baskets[i].Disabled = !CanInteract || b?.Cooked != true;
            _baskets[i].Text = b is null ? "尚未开放" : b.Empty ? $"第{i + 1}层 · 空闲" : $"{GuangzhouRules.Name(b.ProductId)} · " + (!b.Cooked ? $"蒸制 {b.Seconds:0.0}s" : b.Quality switch
            { DimSumQuality.Perfect => Session.Cabinet!.KeepWarm ? "保温 · 点击取出" : "最佳 · 点击取出", DimSumQuality.Normal => "普通 · 点击取出", _ => "过蒸 · 点击取出" });
        }
        foreach (var (id, button) in _dimSum) { button.Text = $"{GuangzhouRules.Name(id)}\n{Session.DimSum.Count(id)}/4 笼 · 交付"; button.Disabled = !CanInteract || Session.DimSum.Count(id) == 0; }
        var tea = Session.Tea;
        _pourTea.Text = tea is null ? "早茶 Day 8 开放" : tea.PourRemaining > 0 ? "取茶中…" : $"取茶 · {tea.Stock.Count}/6杯";
        _pourTea.Disabled = !CanInteract || tea is null || tea.HasCup || tea.PourRemaining > 0 || tea.Stock.Refilling || tea.Stock.Count == 0;
        _teaCup.Disabled = !CanInteract || tea?.HasCup != true;
        _refillTea.Disabled = !CanInteract || tea is null || tea.Stock.Count == tea.Stock.Capacity || tea.Stock.Refilling;
        _refillTea.Text = tea?.Stock.Refilling == true ? "补茶中…" : "补茶 · 0.5秒";
        foreach (string id in GuangzhouRules.Ingredients)
        {
            bool unlocked = Session.IngredientUnlocked(id); var stock = Session.Ingredients[id];
            _ingredients[id].Text = !unlocked ? $"{GuangzhouRules.Name(id)} · 未开放" : $"{GuangzhouRules.Name(id)}  {stock.Count}/{stock.Capacity}" + (_tool == id ? " · 已选中" : id == GuangzhouRules.Batter ? " · 拖到蒸盘" : "");
            _ingredients[id].Disabled = !CanInteract || !unlocked || stock.Refilling || stock.Count == 0;
            _refills[id].Text = stock.Refilling ? $"补货中 {stock.RefillRemaining:0.0}s" : "补满 · 0.8秒";
            _refills[id].Disabled = !CanInteract || !unlocked || stock.Refilling || stock.Count == stock.Capacity;
        }
    }
    private string LineName(OrderLineData line) => line.ProductKind == ProductKind.RiceRoll ? _catalog.RecipesById[line.DefinitionId].DisplayName : GuangzhouRules.Name(line.DefinitionId);
    private void RequestAbandon()
    {
        if (_controller is null || _controller.CurrentConfig?.CityId != StableIds.Cities.Guangzhou) return;
        if (_controller.State is DayState.Preparing || _committed) { HubRequested?.Invoke(); return; }
        CancelGestures(); _abandon.PopupCentered(new Vector2I(580, 230));
    }
    private void BuildResults()
    {
        _overlay = new ColorRect { Color = new(0.08f, .15f, .1f, .65f), Size = new(1920, 1080), Visible = false, ZIndex = 100 }; _canvas.AddChild(_overlay);
        GuangzhouUi.Panel(_overlay, new(450, 175, 1020, 730));
        GuangzhouUi.Text(_overlay, "广州 · 今日营业收据", new(500, 200, 920, 65), 38);
        _results = GuangzhouUi.Text(_overlay, "", new(510, 290, 900, 445), 27);
        _back = GuangzhouUi.Button(_overlay, "收好收入 · 返回经营", new(510, 790, 900, 64), () => HubRequested?.Invoke(), true);
        _retry = GuangzhouUi.Button(_overlay, "重试保存", new(510, 711, 900, 56), CommitResult);
    }
    private void OnFinished(DayResult result)
    {
        if (!IsVisibleInTree() || _controller.CurrentConfig?.CityId != StableIds.Cities.Guangzhou) return;
        _pendingResult = result; CancelGestures(); _overlay.Visible = true; CommitResult();
    }
    private void CommitResult()
    {
        if (_pendingResult is not { } r || _committed) return;
        try
        {
            var commit = Practice ? new DayCommitResult(0, false, SaveService.EvaluateStars(r, Session.Config)) : _save.CommitDay(r, _controller.CurrentPlan!, Session.Config);
            _committed = true; _retry.Visible = false; _back.Disabled = false;
            string unlocks = string.Join("、", Session.Config.CompletionUnlocks.Select(id => id.Replace("equipment:", "")).Select(id => _catalog.GuangzhouEquipment.TryGetValue(id, out var e) ? $"{GuangzhouRules.Name(e.EquipmentId)} Lv{e.Level}" : id));
            _results.Text = $"营业额    ¥{r.SaleRevenue}      小费    ¥{r.Tips}\n\n完成顾客    {r.CompletedCustomers}/{r.PlannedCustomers}      离店    {r.LostCustomers}\n\nPerfect    {r.PerfectOrders}      最高连续正确    {r.HighestCorrectStreak}\n\n满意度    {r.Satisfaction:0.0}%      本次星级    {new string('★', commit.EarnedStars)}\n\n" +
                (Practice ? "练习结束 · 不保存收入、设备或章节进度" : $"计入共享金币    ¥{commit.PermanentCoinGain}（历史最佳差额）") + (!Practice && unlocks.Length > 0 ? $"\n\n升级已开放：{unlocks}" : "");
        }
        catch (Exception e) { _results.Text = $"结算保存失败，成绩仍保留在本页面。\n\n{e.Message}\n\n请重试保存。"; _retry.Visible = true; _back.Disabled = true; }
    }
    public static string Tutorial(int day) => day switch
    {
        1 => "拖米浆入盘 → 铺浆 → 拉动手柄推进。熟后拉出，从边缘刮卷，再切段淋汁。",
        2 => "鸡蛋必须在推进蒸屉之前加入。忘记加料会做成斋肠。",
        3 => "猪肉肠已开放。先选蒸盘，再点配料；库存不足可免费补货。",
        4 => "第一次肠粉高峰。完成今天可购买双屉炉，两份独立计时。",
        5 or 6 => "烧卖蒸着时继续做肠粉。熟后点击蒸柜层位，收入成品库存。",
        7 => "虾仁肠与上班族加入。短耐心顾客需要更早安排。",
        8 => "早茶只需0.3秒。逐件交付，全部齐全后才结算订单。",
        9 => "虾饺比烧卖蒸得更久。提前备货，再交替处理两个蒸屉。",
        10 => "家庭大单需要两份肠粉。看清每行数量，优先交付配方相符的一份。",
        _ => "双屉错峰，蒸点预制。升级减少过蒸风险，铺浆和刮卷始终由你完成。",
    };
}
