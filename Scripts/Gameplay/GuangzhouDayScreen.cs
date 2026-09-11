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

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        void FitCanvas()
        {
            float scale = Math.Min(Size.X / 1920, Size.Y / 1080);
            _canvas.Scale = Vector2.One * scale;
            _canvas.Position = (Size - _canvas.Size * scale) * .5f;
        }
        Resized += FitCanvas;
        FitCanvas();

        for (int i = 0; i < _customers.Length; i++)
        {
            int slot = i;
            _customers[i].Pressed += () => SelectCustomer(slot);
            _customers[i].Accepts = payload => CanDropOnCustomer(slot, payload);
            _customers[i].Delivered = payload => DeliverPayload(payload, CustomerAt(slot)?.Id);
        }
        for (int i = 0; i < _trays.Length; i++)
        {
            int index = i;
            GuangzhouTrayView tray = _trays[i];
            tray.Index = i;
            tray.CanInteract = () => CanInteract;
            tray.SauceSelected = () => _tool == GuangzhouRules.Sauce;
            tray.SauceRequested = () => ApplySauce(index);
            tray.Selected = () => _selectedTray = index;
            tray.Feedback = Feedback;
            tray.IngredientDropped = id => ApplyIngredient(index, id);
            tray.IngredientAllowed = id => CanAddIngredient(index, id);
            _cuts[i].Pressed += () => { if (CanInteract) { Session.Trays[index].TryCut(); Render(); } };
            _deliverRolls[i].Payload = $"roll:{i}";
            _deliverRolls[i].CanDrag = () => CanInteract && Session.Trays.Count > index && Session.Trays[index].State == RiceRollState.Ready;
            _deliverRolls[i].Pressed += () => DeliverPayload($"roll:{index}", SelectedCustomerId);
            _discards[i].Pressed += () => { if (CanInteract) { Session.Trays[index].Reset(); _trays[index].CancelGesture(); } };
        }
        _pause.Pressed += () => { _manuallyPaused = !_manuallyPaused; CancelGestures(); };
        this.FindButton("返回经营").Pressed += RequestAbandon;
        _loadSiuMai.Pressed += () => LoadBasket(GuangzhouRules.SiuMai);
        _loadHarGow.Pressed += () => LoadBasket(GuangzhouRules.HarGow);
        for (int i = 0; i < _baskets.Length; i++)
        {
            int index = i;
            _baskets[i].Pressed += () =>
            {
                if (!CanInteract || Session.Cabinet is null) return;
                if (!Session.Cabinet.TryStock(index, Session.DimSum)) Feedback("尚未蒸熟，或该蒸点库存已满4笼。");
            };
        }

        GuangzhouDragSource[] looseSources = this.Descendants<GuangzhouDragSource>()
            .Where(source => !_deliverRolls.Contains(source) && source != _teaCup).ToArray();
        string[] ingredients = GuangzhouRules.Ingredients;
        GuangzhouDragSource[] ingredientSources = looseSources.Where(source => source.Position.Y > 880).OrderBy(source => source.Position.X).ToArray();
        for (int i = 0; i < Math.Min(ingredients.Length, ingredientSources.Length); i++)
        {
            string id = ingredients[i];
            GuangzhouDragSource source = ingredientSources[i];
            _ingredients[id] = source;
            source.Payload = id;
            source.CanDrag = () => CanInteract && Session.IngredientUnlocked(id) && !Session.Ingredients[id].Refilling && Session.Ingredients[id].Count > 0;
            source.Pressed += () =>
            {
                if (!CanInteract) return;
                if (id == GuangzhouRules.Sauce) { _tool = id; Feedback("已拿起豉油壶，在切好的肠粉上短划一下。"); }
                else if (id == GuangzhouRules.Batter) Feedback("把米浆拖到空蒸盘，再按住鼠标铺开。");
                else ApplyIngredient(_selectedTray, id);
            };
        }
        string[] dimIds = { GuangzhouRules.SiuMai, GuangzhouRules.HarGow };
        GuangzhouDragSource[] dimSources = looseSources.Where(source => source.Position.Y > 700 && source.Position.Y < 880).OrderBy(source => source.Position.X).ToArray();
        for (int i = 0; i < Math.Min(dimIds.Length, dimSources.Length); i++)
        {
            string id = dimIds[i];
            _dimSum[id] = dimSources[i];
            dimSources[i].Payload = "dim:" + id;
            dimSources[i].CanDrag = () => CanInteract && Session.DimSum.Count(id) > 0;
            dimSources[i].Pressed += () => DeliverPayload("dim:" + id, SelectedCustomerId);
        }
        Button[] refillButtons = this.Descendants<Button>().Where(button => button.Position.Y > 970 && button.Text.StartsWith("补满", StringComparison.Ordinal)).OrderBy(button => button.Position.X).ToArray();
        for (int i = 0; i < Math.Min(ingredients.Length, refillButtons.Length); i++)
        {
            string id = ingredients[i];
            _refills[id] = refillButtons[i];
            refillButtons[i].Pressed += () => { if (CanInteract && Session.IngredientUnlocked(id)) Session.Ingredients[id].TryRefill(); };
        }
        _pourTea.Pressed += () => { if (CanInteract) Session.Tea?.TryPour(); };
        _teaCup.Payload = "tea";
        _teaCup.CanDrag = () => CanInteract && Session.Tea?.HasCup == true;
        _teaCup.Pressed += () => DeliverPayload("tea", SelectedCustomerId);
        _refillTea.Pressed += () => { if (CanInteract) Session.Tea?.Stock.TryRefill(); };
        _abandon.Confirmed += () => { _controller.AbandonDay(); _controller.IsPaused = false; HubRequested?.Invoke(); };
        _back.Pressed += () => HubRequested?.Invoke();
        _retry.Pressed += CommitResult;
    }
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
            if (_customers[i].GetThemeStylebox("normal") is StyleBoxFlat customerStyle)
            {
                customerStyle.BgColor = c?.Id == SelectedCustomerId ? new Color("#D4E4CC") : GuangzhouUi.Paper;
                int border = c?.Id == SelectedCustomerId ? 3 : 1;
                customerStyle.BorderWidthLeft = customerStyle.BorderWidthTop = customerStyle.BorderWidthRight = customerStyle.BorderWidthBottom = border;
            }
            if (c is null) { _orders[i].Text = $"{i + 1:00}    等待街坊\n\n肠粉现蒸 · 点心提前备"; continue; }
            string lines = string.Join("\n", c.Order.Lines.Select((l, n) => $"{(c.Progress.GetRemainingQuantity(n) == 0 ? "✓" : "·")} {LineName(l)}  {c.Progress.GetDeliveredQuantity(n)}/{l.Quantity}"));
            _orders[i].Text = $"{c.Type.DisplayName}  ¥{c.Order.BasePrice}\n{lines}";
            PatienceBarPresentation.Render(_patience[i], 1 - c.PatienceProgress);
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
