using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Gameplay;

public partial class TianjinDayScreen : Control
{
    public event Action? HubRequested;
    public event Action<int>? NextDayRequested;

    private readonly Button[] _customerCards = new Button[5];
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private DayController _controller = null!;
    private PancakeWorkstation _workstation = null!;
    private Label _dayTitle = null!;
    private Label _clock = null!;
    private Label _income = null!;
    private Label _feedback = null!;
    private Label _door = null!;
    private PanelContainer _prepare = null!;
    private Label _prepareText = null!;
    private Label _countdown = null!;
    private PanelContainer _results = null!;
    private RichTextLabel _resultText = null!;
    private VBoxContainer _resultUpgrades = null!;
    private Button _nextButton = null!;
    private ConfirmationDialog _abandonDialog = null!;
    private DayCommitResult _commit;
    private bool _committed;
    private bool _focused = true;

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        _catalog = catalog; _save = save; _controller = controller; _committed = false; _results.Visible = false;
        if (!controller.TryPrepareDay(day, catalog, out string error))
        {
            ShowFeedback(error, true); return;
        }
        if (!save.ApplyStartUnlocks(controller.CurrentConfig!, out error))
        {
            ShowFeedback(error, true); return;
        }
        int fryerLevel = controller.CurrentConfig!.AvailableProductKinds.Contains(ProductKind.Youtiao)
            ? Math.Max(1, save.Data.PurchasedFryerLevel)
            : 0;
        _workstation.Initialize(catalog, save.Data.PurchasedStoveLevel, save.Data.PurchasedIngredientStationLevel, fryerLevel, controller.CurrentConfig);
        _workstation.SubmitPrepared = SubmitPrepared;
        _workstation.SubmitProduct = SubmitProduct;
        _workstation.InteractionEnabled = false;
        _workstation.ResetForDay();
        _prepare.Visible = true; _countdown.Visible = false;
        string fryer = fryerLevel > 0 ? $" · 油条锅 Lv{fryerLevel}" : string.Empty;
        _prepareText.Text = $"Day {day}\n{controller.CurrentConfig.DurationSeconds:0} 秒 · {controller.CurrentConfig.CustomerCount} 位顾客\n煎饼炉 Lv{save.Data.PurchasedStoveLevel} · 配料台 Lv{save.Data.PurchasedIngredientStationLevel}{fryer}\n{TutorialText(day)}";
        Render();
    }

    public void ConnectController(DayController controller)
    {
        _controller = controller;
        controller.StateChanged += OnStateChanged;
        controller.DayFinished += OnDayFinished;
        controller.DeliveryCompleted += evaluation => ShowFeedback(evaluation.Message, evaluation.Grade == DeliveryGrade.Incorrect);
    }

    public override void _Process(double delta)
    {
        if (_controller is null || !_focused || !IsVisibleInTree()) return;
        _controller.Tick(delta);
        _workstation.InteractionEnabled = _controller.State is DayState.Running or DayState.Closing;
        _workstation.Tick(delta);
        Render();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut)
        {
            _focused = false; if (_controller is not null) _controller.IsPaused = true; _workstation?.CancelInput(); if (_workstation is not null) _workstation.Paused = true;
        }
        else if (what == NotificationApplicationFocusIn)
        {
            _focused = true; if (_controller is not null) _controller.IsPaused = false; if (_workstation is not null) _workstation.Paused = false;
        }
    }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var bg = new ColorRect { Color = new Color("#211713"), MouseFilter = MouseFilterEnum.Ignore }; bg.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); AddChild(bg);
        var root = new VBoxContainer(); root.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); root.OffsetLeft = 24; root.OffsetTop = 16; root.OffsetRight = -24; root.OffsetBottom = -16; root.AddThemeConstantOverride("separation", 10); AddChild(root);
        var hud = new HBoxContainer { CustomMinimumSize = new Vector2(0, 58) }; root.AddChild(hud);
        _dayTitle = Text("Day", 28, "#FFD596"); _dayTitle.SizeFlagsHorizontal = SizeFlags.ExpandFill; hud.AddChild(_dayTitle);
        _clock = Text("00:00", 25, "#F5E0C5"); hud.AddChild(_clock); _income = Text("营业额 ¥0", 23, "#7DDA96"); hud.AddChild(_income);
        var back = new Button { Text = "返回大厅", CustomMinimumSize = new Vector2(140, 48) }; back.Pressed += RequestAbandon; hud.AddChild(back);
        var customerPanel = Panel("#30241E"); root.AddChild(customerPanel);
        var customerColumn = new VBoxContainer(); customerPanel.AddChild(customerColumn);
        var customerHeader = new HBoxContainer(); customerColumn.AddChild(customerHeader); var waiting = Text("顾客队列 · 点击订单选择出餐目标", 18, "#DCC3A6"); waiting.SizeFlagsHorizontal = SizeFlags.ExpandFill; customerHeader.AddChild(waiting); _door = Text("门外候场 0", 16, "#A99788"); customerHeader.AddChild(_door);
        var row = new HBoxContainer(); row.AddThemeConstantOverride("separation", 10); customerColumn.AddChild(row);
        for (int index = 0; index < _customerCards.Length; index++)
        {
            int slot = index; var card = new Button { Text = "空位", CustomMinimumSize = new Vector2(0, 112), SizeFlagsHorizontal = SizeFlags.ExpandFill, Disabled = true };
            card.AddThemeFontSizeOverride("font_size", 17); card.Pressed += () => SelectSlot(slot); row.AddChild(card); _customerCards[index] = card;
        }
        _feedback = Text("点击开店，准备营业。", 18, "#78D892"); _feedback.HorizontalAlignment = HorizontalAlignment.Center; root.AddChild(_feedback);
        _workstation = new PancakeWorkstation { SizeFlagsVertical = SizeFlags.ExpandFill }; _workstation.Feedback += ShowFeedback; root.AddChild(_workstation);
        _workstation.YoutiaoConsumed += quantity => _controller?.Ledger?.RecordYoutiaoUsed(quantity);
        _workstation.YoutiaoBurnt += quantity => _controller?.Ledger?.RecordYoutiaoBurnt(quantity);
        BuildPrepareOverlay(); BuildResultOverlay();
        _abandonDialog = new ConfirmationDialog { Title = "放弃本日营业？", DialogText = "本日收入和成绩不会保存，重新开始会生成相同顾客计划。", OkButtonText = "放弃并返回" };
        _abandonDialog.Confirmed += () => { _controller.AbandonDay(); _workstation.ResetForDay(); HubRequested?.Invoke(); }; AddChild(_abandonDialog);
    }

    private void BuildPrepareOverlay()
    {
        _prepare = OverlayPanel("#382820"); var box = new VBoxContainer { Alignment = BoxContainer.AlignmentMode.Center }; box.AddThemeConstantOverride("separation", 24); _prepare.AddChild(box);
        _prepareText = Text("营业准备", 32, "#FFD596"); _prepareText.HorizontalAlignment = HorizontalAlignment.Center; box.AddChild(_prepareText);
        var open = new Button { Text = "开店", CustomMinimumSize = new Vector2(280, 70), SizeFlagsHorizontal = SizeFlags.ShrinkCenter }; open.AddThemeFontSizeOverride("font_size", 25); open.Pressed += StartDay; box.AddChild(open);
        _countdown = Text("3", 76, "#FFF0D4"); _countdown.HorizontalAlignment = HorizontalAlignment.Center; _countdown.Visible = false; box.AddChild(_countdown);
        AddChild(_prepare);
    }

    private void BuildResultOverlay()
    {
        _results = OverlayPanel("#34251E"); _results.Visible = false; var box = new VBoxContainer(); box.AddThemeConstantOverride("separation", 14); _results.AddChild(box);
        var title = Text("今日结算", 36, "#FFD596"); title.HorizontalAlignment = HorizontalAlignment.Center; box.AddChild(title);
        _resultText = new RichTextLabel { BbcodeEnabled = true, FitContent = true, CustomMinimumSize = new Vector2(700, 280) }; _resultText.AddThemeFontSizeOverride("normal_font_size", 22); box.AddChild(_resultText);
        _resultUpgrades = new VBoxContainer(); box.AddChild(_resultUpgrades);
        var actions = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center }; actions.AddThemeConstantOverride("separation", 12); box.AddChild(actions);
        var hub = new Button { Text = "返回大厅", CustomMinimumSize = new Vector2(180, 58) }; hub.Pressed += () => HubRequested?.Invoke(); actions.AddChild(hub);
        _nextButton = new Button { Text = "下一天", CustomMinimumSize = new Vector2(180, 58) }; _nextButton.Pressed += () => NextDayRequested?.Invoke(Math.Min(15, _controller.CurrentConfig!.Day + 1)); actions.AddChild(_nextButton);
        AddChild(_results);
    }

    private void StartDay()
    {
        if (_controller.TryStartDay(out string error)) { _countdown.Visible = true; ShowFeedback("准备开店……", false); }
        else ShowFeedback(error, true);
    }

    private void OnStateChanged(DayState state)
    {
        if (state == DayState.Running) { _prepare.Visible = false; ShowFeedback("开始营业！点击顾客选择订单。", false); }
        else if (state == DayState.Closing) ShowFeedback("停止接单，还有 15 秒完成当前队列。", false);
    }

    private void OnDayFinished(DayResult result)
    {
        if (_committed) return;
        _committed = true;
        _commit = _save.CommitDay(result, _controller.CurrentPlan!, _controller.CurrentConfig!);
        _workstation.InteractionEnabled = false;
        string stars = result.Day == 15 ? $"\n天津评级  {new string('★', _commit.EarnedStars)}{new string('☆', 3 - _commit.EarnedStars)}{(_commit.EarnedStars >= 1 ? " · 天津已点亮" : " · 尚未达到一星")}" : string.Empty;
        _resultText.Text = $"[center]销售额  ¥{result.SaleRevenue}    小费  ¥{result.Tips}\n[font_size=30][color=#FFD596]今日总收入  ¥{result.TotalRevenue}[/color][/font_size]\n永久金币增加  ¥{_commit.PermanentCoinGain}{(_commit.NewBest ? "  ·  新纪录" : "")}\n完成 / 流失  {result.CompletedCustomers} / {result.LostCustomers}\nPerfect / Correct / Incorrect  {result.PerfectOrders} / {result.CorrectOrders} / {result.IncorrectOrders}\n最高连击  {result.HighestCorrectStreak}    满意度  {result.Satisfaction:0}%\n油条使用  {result.YoutiaoUsed}    炸焦  {result.YoutiaoBurnt}{stars}[/center]";
        RenderResultUpgrades();
        _nextButton.Visible = result.Day < 15;
        _results.Visible = true;
    }

    private bool SubmitPrepared(Pancake.PancakeStateMachine machine)
    {
        DeliveryEvaluation evaluation = _controller.TryDeliverSelected(machine, _catalog);
        ShowFeedback(evaluation.Message, evaluation.Grade is DeliveryGrade.Incorrect or DeliveryGrade.Rejected);
        return evaluation.ItemAccepted || evaluation.CompletesOrder;
    }

    private bool SubmitProduct(ProductKind kind)
    {
        DeliveryEvaluation evaluation = kind switch
        {
            ProductKind.Youtiao when _workstation.FryerMachine is not null => _controller.TryDeliverYoutiaoSelected(_workstation.FryerMachine.Inventory),
            ProductKind.SoyMilk when _workstation.SoyMilkTray is not null => _controller.TryDeliverSoyMilkSelected(_workstation.SoyMilkTray),
            _ => new DeliveryEvaluation(DeliveryGrade.Rejected, 0, 0, 0, "当前商品不可交付。"),
        };
        if (kind == ProductKind.Youtiao && (evaluation.ItemAccepted || evaluation.CompletesOrder)) _controller.Ledger?.RecordYoutiaoUsed();
        ShowFeedback(evaluation.Message, evaluation.Grade is DeliveryGrade.Incorrect or DeliveryGrade.Rejected);
        return evaluation.ItemAccepted || evaluation.CompletesOrder;
    }

    private void SelectSlot(int index)
    {
        if (index < _controller.CustomerQueue!.Slots.Count && !_controller.CustomerQueue.TrySelect(_controller.CustomerQueue.Slots[index].Id)) ShowFeedback("该顾客当前不能选择。", true);
        RenderCustomers();
    }

    private void RequestAbandon()
    {
        if (_controller.State is DayState.Opening or DayState.Running or DayState.Closing) _abandonDialog.PopupCentered(); else HubRequested?.Invoke();
    }

    private void Render()
    {
        if (_controller?.CurrentConfig is null) return;
        _dayTitle.Text = $"Day {_controller.CurrentConfig.Day} · {_controller.State}";
        _clock.Text = _controller.State == DayState.Opening ? $"开店 {_controller.OpeningRemainingSeconds:0.0}" : _controller.State == DayState.Closing ? $"收尾 {_controller.ClosingRemainingSeconds:0.0}" : $"剩余 {FormatTime(_controller.DayRemainingSeconds)}";
        if (_controller.State == DayState.Opening) _countdown.Text = Math.Max(1, (int)Math.Ceiling(_controller.OpeningRemainingSeconds)).ToString();
        _income.Text = $"营业额 ¥{_controller.Ledger?.Build().TotalRevenue ?? 0}";
        RenderCustomers();
    }

    private void RenderCustomers()
    {
        if (_controller?.CustomerQueue is null) return;
        IReadOnlyList<CustomerRuntime> slots = _controller.CustomerQueue.Slots;
        _door.Text = $"门外候场 {_controller.CustomerQueue.DoorQueue.Count}";
        for (int index = 0; index < _customerCards.Length; index++)
        {
            Button card = _customerCards[index];
            if (index >= slots.Count) { card.Text = "空位"; card.Disabled = true; card.Modulate = Colors.White; continue; }
            CustomerRuntime customer = slots[index];
            bool selected = _controller.CustomerQueue.SelectedCustomerId == customer.Id;
            card.Text = $"{(selected ? "▶ " : "")}{Emotion(customer.State)} · {customer.Type.DisplayName}\n{FormatOrder(customer)}\n耐心 {(1 - customer.PatienceProgress):P0}";
            card.Disabled = customer.State is CustomerState.Entering or CustomerState.Leaving or CustomerState.Served;
            card.Modulate = selected ? new Color("#FFD596") : StateColor(customer.State);
        }
    }

    private void RenderResultUpgrades()
    {
        foreach (Node child in _resultUpgrades.GetChildren()) child.QueueFree();
        foreach (string id in _save.Data.UnlockedUpgradeIds)
        {
            (string name, int price, bool owned) = UpgradeInfo(id);
            if (string.IsNullOrEmpty(name) || owned) continue;
            var button = new Button { Text = $"购买 {name} · ¥{price}", Disabled = _save.Data.Coins < price };
            button.Pressed += () => { _save.TryPurchase(id, _catalog, out string error); ShowFeedback(string.IsNullOrEmpty(error) ? "升级购买成功。" : error, !string.IsNullOrEmpty(error)); RenderResultUpgrades(); }; _resultUpgrades.AddChild(button);
        }
    }

    private void ShowFeedback(string message, bool error) { _feedback.Text = message; _feedback.Modulate = error ? new Color("#FF756A") : new Color("#78D892"); }
    private string FormatOrder(CustomerRuntime customer)
    {
        var parts = new List<string>();
        for (int index = 0; index < customer.Order.Lines.Count; index++)
        {
            OrderLineData line = customer.Order.Lines[index];
            int done = customer.Progress.GetDeliveredQuantity(index);
            string name = line.ProductKind switch
            {
                ProductKind.Pancake => $"煎饼〔{_catalog.RecipesById[line.DefinitionId].DisplayName.Replace("煎饼", string.Empty)}〕",
                ProductKind.Youtiao => "独立油条",
                _ => "豆浆",
            };
            parts.Add($"{name} {done}/{line.Quantity}");
        }
        return string.Join(" + ", parts);
    }
    private (string Name, int Price, bool Owned) UpgradeInfo(string id) => id switch
    {
        "equipment:ingredient_station_lv2" => ("配料台 Lv2", 60, _save.Data.PurchasedIngredientStationLevel >= 2),
        "equipment:ingredient_station_lv3" => ("配料台 Lv3", 180, _save.Data.PurchasedIngredientStationLevel >= 3),
        "equipment:pancake_stove_lv2" => ("煎饼炉 Lv2", 120, _save.Data.PurchasedStoveLevel >= 2),
        "equipment:pancake_stove_lv3" => ("煎饼炉 Lv3", 300, _save.Data.PurchasedStoveLevel >= 3),
        "equipment:fryer_lv2" => ("油条锅 Lv2", 160, _save.Data.PurchasedFryerLevel >= 2),
        "equipment:fryer_lv3" => ("油条锅 Lv3", 320, _save.Data.PurchasedFryerLevel >= 3),
        _ => (string.Empty, 0, true),
    };
    private static string TutorialText(int day) => day switch
    {
        5 => "教学：逐根装入油条，放下炸篮；金黄后抬篮。",
        7 => "教学：把沥油区的熟油条拖进煎饼。",
        8 => "新配料：火腿已经加入配料台。",
        9 => "教学：成品豆浆可直接拖到出餐口。",
        11 => "特殊顾客出现：优先留意上班族。",
        12 => "大订单出现：逐件补齐后才会结算。",
        15 => "天津最终高峰：至少一星即可点亮天津。",
        _ => string.Empty,
    };
    private static string Emotion(CustomerState state) => state switch { CustomerState.Happy => "开心", CustomerState.Normal => "等待", CustomerState.Impatient => "不耐烦", CustomerState.Angry => "生气", CustomerState.Entering => "进店", _ => "离开" };
    private static Color StateColor(CustomerState state) => state switch { CustomerState.Happy => new Color("#BDE6C5"), CustomerState.Normal => Colors.White, CustomerState.Impatient => new Color("#FFD185"), CustomerState.Angry => new Color("#FF8A78"), _ => new Color("#AAAAAA") };
    private static string FormatTime(double seconds) => $"{(int)seconds / 60:00}:{(int)seconds % 60:00}";
    private static Label Text(string text, int size, string color) { var l = new Label { Text = text }; l.AddThemeFontSizeOverride("font_size", size); l.AddThemeColorOverride("font_color", new Color(color)); return l; }
    private static PanelContainer Panel(string color) { var p = new PanelContainer(); p.AddThemeStyleboxOverride("panel", new StyleBoxFlat { BgColor = new Color(color), CornerRadiusTopLeft = 14, CornerRadiusTopRight = 14, CornerRadiusBottomLeft = 14, CornerRadiusBottomRight = 14, ContentMarginLeft = 14, ContentMarginRight = 14, ContentMarginTop = 10, ContentMarginBottom = 10 }); return p; }
    private static PanelContainer OverlayPanel(string color) { var p = Panel(color); p.SetAnchorsPreset(LayoutPreset.Center); p.Position = new Vector2(-430, -310); p.Size = new Vector2(860, 620); p.ZIndex = 1000; return p; }
}
