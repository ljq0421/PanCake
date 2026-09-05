using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

/*
THESIS: the shop itself is the interface; customers, food, and equipment carry the service rhythm instead of a workflow dashboard.
OWN-WORLD: the approved Tianjin storefront fills the frame while cream paper, warm status colors, dark-brown outlines, and one soft shadow hold the HUD.
STORY: read visual orders above the queue, prepare food across the physical counter, deliver to the selected guest, and close on a printed receipt.
FIRST VIEWPORT: five guests own the open window; the fryer, large pancake stove, ingredients, and delivery shelf sit exactly on the painted counter.
FORM: a single-screen casual management workbench at a fixed 16:9 design resolution.
*/
public partial class TianjinDayScreen : Control
{
    public event Action? HubRequested;

    private readonly Button[] _customerButtons = new Button[5];
    private readonly HBoxContainer[] _orderRows = new HBoxContainer[5];
    private readonly CustomerPortraitView[] _portraits = new CustomerPortraitView[5];
    private readonly Label[] _customerBadges = new Label[5];
    private readonly ProgressBar[] _patienceBars = new ProgressBar[5];
    private readonly string[] _customerSignatures = new string[5];
    private readonly string[] _portraitSignatures = new string[5];
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private DayController _controller = null!;
    private TianjinArtCatalog _art = null!;
    private PancakeWorkstation _workstation = null!;
    private Label _dayTitle = null!;
    private Label _clock = null!;
    private Label _income = null!;
    private TextureRect _coinTarget = null!;
    private PanelContainer _feedbackPanel = null!;
    private Label _feedback = null!;
    private Label _door = null!;
    private Label _countdown = null!;
    private PanelContainer _results = null!;
    private ColorRect _resultBlocker = null!;
    private RichTextLabel _resultText = null!;
    private Label _unlockText = null!;
    private ConfirmationDialog _abandonDialog = null!;
    private DayCommitResult _commit;
    private bool _committed;
    private bool _focused = true;
    private double _feedbackRemaining;

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        _catalog = catalog;
        _save = save;
        _controller = controller;
        _committed = false;
        _results.Visible = false;
        _resultBlocker.Visible = false;
        _countdown.Visible = false;
        Array.Fill(_customerSignatures, string.Empty);
        Array.Fill(_portraitSignatures, string.Empty);
        if (!controller.TryPrepareDay(day, catalog, out string error))
        {
            ShowFeedback(error, true);
            return;
        }
        if (!save.ApplyStartUnlocks(controller.CurrentConfig!, out error))
        {
            ShowFeedback(error, true);
            return;
        }
        int fryerLevel = controller.CurrentConfig!.AvailableProductKinds.Contains(ProductKind.Youtiao)
            ? Math.Max(1, save.Data.PurchasedFryerLevel)
            : 0;
        _workstation.Initialize(catalog, save.Data.PurchasedStoveLevel, save.Data.PurchasedIngredientStationLevel, fryerLevel, controller.CurrentConfig, _art);
        _workstation.SubmitPrepared = SubmitPrepared;
        _workstation.SubmitProduct = SubmitProduct;
        _workstation.InteractionEnabled = false;
        _workstation.ResetForDay();
        Render();
    }

    public void BeginDay()
    {
        if (_controller is null) return;
        if (_controller.TryStartDay(out string error))
        {
            _countdown.Visible = true;
            ShowFeedback("铺门打开，准备迎接第一位客人。", false);
        }
        else ShowFeedback(error, true);
    }

    public void ConnectController(DayController controller)
    {
        _controller = controller;
        controller.StateChanged += OnStateChanged;
        controller.DayFinished += OnDayFinished;
        controller.DeliveryCompleted += evaluation => ShowFeedback(evaluation.Message, evaluation.Grade is DeliveryGrade.Incorrect or DeliveryGrade.Rejected);
    }

    public override void _Process(double delta)
    {
        if (_feedbackRemaining > 0)
        {
            _feedbackRemaining -= delta;
            if (_feedbackRemaining <= 0) _feedbackPanel.Visible = false;
        }
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
            _focused = false;
            if (_controller is not null) _controller.IsPaused = true;
            _workstation?.CancelInput();
            if (_workstation is not null) _workstation.Paused = true;
        }
        else if (what == NotificationApplicationFocusIn)
        {
            _focused = true;
            if (_controller is not null) _controller.IsPaused = false;
            if (_workstation is not null) _workstation.Paused = false;
        }
    }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        Theme = TianjinUi.CreateTheme();
        _art = new TianjinArtCatalog();
        var background = TianjinUi.Texture(_art.Background, Vector2.Zero, TextureRect.StretchModeEnum.Scale);
        TianjinUi.FullRect(background);
        AddChild(background);

        _workstation = new PancakeWorkstation();
        TianjinUi.FullRect(_workstation);
        _workstation.Feedback += ShowFeedback;
        _workstation.YoutiaoConsumed += quantity => _controller?.Ledger?.RecordYoutiaoUsed(quantity);
        _workstation.YoutiaoBurnt += quantity => _controller?.Ledger?.RecordYoutiaoBurnt(quantity);
        AddChild(_workstation);

        BuildCustomers();
        BuildHud();
        BuildFeedback();
        BuildResultOverlay();

        _countdown = TianjinUi.Label("3", 112, TianjinUi.Paper, HorizontalAlignment.Center);
        _countdown.Position = new Vector2(850, 450);
        _countdown.Size = new Vector2(220, 180);
        _countdown.AddThemeConstantOverride("outline_size", 12);
        _countdown.AddThemeColorOverride("font_outline_color", TianjinUi.BrownDark);
        _countdown.ZIndex = 90;
        _countdown.Visible = false;
        AddChild(_countdown);

        _abandonDialog = new ConfirmationDialog
        {
            Title = "提前打烊？",
            DialogText = "本日收入和成绩不会保存，重新开始仍会遇到同一批顾客。",
            OkButtonText = "打烊并返回",
        };
        _abandonDialog.Confirmed += () =>
        {
            _controller.AbandonDay();
            _workstation.ResetForDay();
            HubRequested?.Invoke();
        };
        AddChild(_abandonDialog);
    }

    private void BuildHud()
    {
        var hud = TianjinUi.Panel(new Color("#FFF4D5"), 16);
        hud.SetAnchorsPreset(LayoutPreset.TopWide);
        hud.OffsetLeft = 24;
        hud.OffsetTop = 18;
        hud.OffsetRight = -24;
        hud.OffsetBottom = 90;
        hud.ZIndex = 70;
        AddChild(hud);
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 20);
        hud.AddChild(row);
        _dayTitle = TianjinUi.Label("Day 1", 28, TianjinUi.BrownDark);
        _dayTitle.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        row.AddChild(_dayTitle);
        _door = TianjinUi.Label("门外候场 0", 18, TianjinUi.Brown);
        row.AddChild(_door);
        _clock = TianjinUi.Label("01:00", 26, TianjinUi.BrownDark);
        row.AddChild(_clock);
        _coinTarget = TianjinUi.Texture(_art.Coin, new Vector2(44, 44));
        row.AddChild(_coinTarget);
        _income = TianjinUi.Label("¥0", 25, TianjinUi.Green);
        row.AddChild(_income);
        var back = TianjinUi.Button("提前打烊", false, new Vector2(148, 52));
        back.Pressed += RequestAbandon;
        row.AddChild(back);
    }

    private void BuildCustomers()
    {
        var customers = new HBoxContainer();
        customers.Position = new Vector2(54, 98);
        customers.Size = new Vector2(1812, 340);
        customers.AddThemeConstantOverride("separation", 12);
        customers.ZIndex = 30;
        AddChild(customers);
        for (int index = 0; index < _customerButtons.Length; index++)
        {
            int slot = index;
            var button = new Button
            {
                Text = string.Empty,
                CustomMinimumSize = new Vector2(352, 340),
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
                FocusMode = FocusModeEnum.All,
                Visible = false,
            };
            button.AddThemeStyleboxOverride("normal", TianjinUi.Box(new Color(1, 1, 1, 0), 16, 0, false));
            button.AddThemeStyleboxOverride("hover", TianjinUi.Box(new Color(1, 0.95f, 0.76f, 0.18f), 16, 3, false));
            button.AddThemeStyleboxOverride("pressed", TianjinUi.Box(new Color(1, 0.89f, 0.48f, 0.24f), 16, 4, false));
            button.Pressed += () => SelectSlot(slot);
            customers.AddChild(button);
            _customerButtons[index] = button;

            var column = new VBoxContainer();
            TianjinUi.FullRect(column, 4, 4, -4, -4);
            column.MouseFilter = MouseFilterEnum.Ignore;
            column.AddThemeConstantOverride("separation", 2);
            button.AddChild(column);
            var bubble = TianjinUi.Panel(TianjinUi.Paper, 14, 4, true);
            bubble.CustomMinimumSize = new Vector2(0, 142);
            bubble.MouseFilter = MouseFilterEnum.Ignore;
            column.AddChild(bubble);
            _orderRows[index] = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center, MouseFilter = MouseFilterEnum.Ignore };
            _orderRows[index].AddThemeConstantOverride("separation", 4);
            bubble.AddChild(_orderRows[index]);
            CustomerPortraitVisual customerVisual = _art.CustomerPortrait("normal", CustomerExpression.Normal);
            _portraits[index] = new CustomerPortraitView();
            _portraits[index].SetVisual(customerVisual);
            _portraits[index].SizeFlagsVertical = SizeFlags.ExpandFill;
            column.AddChild(_portraits[index]);
            _customerBadges[index] = TianjinUi.Label("普通顾客", 17, TianjinUi.BrownText, HorizontalAlignment.Center);
            column.AddChild(_customerBadges[index]);
            _patienceBars[index] = new ProgressBar
            {
                MinValue = 0,
                MaxValue = 100,
                Value = 100,
                ShowPercentage = false,
                CustomMinimumSize = new Vector2(0, 18),
                MouseFilter = MouseFilterEnum.Ignore,
            };
            _patienceBars[index].AddThemeStyleboxOverride("background", TianjinUi.Box(new Color("#E2CDA8"), 8, 3, false));
            _patienceBars[index].AddThemeStyleboxOverride("fill", TianjinUi.Box(TianjinUi.Green, 7, 0, false));
            column.AddChild(_patienceBars[index]);
        }
    }

    private void BuildFeedback()
    {
        _feedbackPanel = TianjinUi.Panel(TianjinUi.Paper, 14);
        _feedbackPanel.Position = new Vector2(600, 104);
        _feedbackPanel.Size = new Vector2(720, 62);
        _feedbackPanel.ZIndex = 80;
        _feedbackPanel.Visible = false;
        AddChild(_feedbackPanel);
        _feedback = TianjinUi.Label(string.Empty, 19, TianjinUi.Green, HorizontalAlignment.Center);
        _feedbackPanel.AddChild(_feedback);
    }

    private void BuildResultOverlay()
    {
        _resultBlocker = new ColorRect
        {
            Color = new Color(0.20f, 0.09f, 0.04f, 0.48f),
            MouseFilter = MouseFilterEnum.Stop,
            ZIndex = 95,
            Visible = false,
        };
        TianjinUi.FullRect(_resultBlocker);
        AddChild(_resultBlocker);
        _results = TianjinUi.Panel(TianjinUi.Paper, 22);
        _results.Position = new Vector2(530, 150);
        _results.Size = new Vector2(860, 780);
        _results.ZIndex = 100;
        _results.Visible = false;
        AddChild(_results);
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 16);
        _results.AddChild(column);
        var title = TianjinUi.Label("今日营业收据", 38, TianjinUi.BrownDark, HorizontalAlignment.Center);
        column.AddChild(title);
        _resultText = new RichTextLabel
        {
            BbcodeEnabled = true,
            FitContent = false,
            CustomMinimumSize = new Vector2(760, 450),
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };
        _resultText.AddThemeFontSizeOverride("normal_font_size", 22);
        _resultText.AddThemeColorOverride("default_color", TianjinUi.BrownText);
        column.AddChild(_resultText);
        _unlockText = TianjinUi.Label(string.Empty, 18, TianjinUi.Orange, HorizontalAlignment.Center);
        _unlockText.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        column.AddChild(_unlockText);
        var hub = TianjinUi.Button("收好收入 · 返回经营首页", true, new Vector2(0, 76));
        hub.Pressed += () => HubRequested?.Invoke();
        column.AddChild(hub);
    }

    private void OnStateChanged(DayState state)
    {
        if (state == DayState.Running)
        {
            _countdown.Visible = false;
            ShowFeedback("开始营业！先点选顾客，再把早餐送到出餐口。", false);
        }
        else if (state == DayState.Closing)
            ShowFeedback("停止接新客，最后 15 秒把手上的订单做完。", false);
    }

    private void OnDayFinished(DayResult result)
    {
        if (_committed) return;
        _committed = true;
        _workstation.InteractionEnabled = false;
        try
        {
            _commit = _save.CommitDay(result, _controller.CurrentPlan!, _controller.CurrentConfig!);
        }
        catch (IOException exception)
        {
            _resultText.Text = $"[center][font_size=34][color=#D95D47]！ 本次成绩未能保存[/color][/font_size]\n\n{exception.Message}\n\n请检查存档目录后返回经营首页。[/center]";
            _unlockText.Text = "本次金币、纪录与解锁均已回退，不会留下半份存档。";
            _resultBlocker.Visible = true;
            _results.Visible = true;
            return;
        }
        string stars = result.Day == 15
            ? $"\n[font_size=30][color=#E9873D]天津评级  {new string('★', _commit.EarnedStars)}{new string('☆', 3 - _commit.EarnedStars)}[/color][/font_size]"
            : string.Empty;
        _resultText.Text = $"[center][font_size=24]Day {result.Day} 打烊[/font_size]\n\n[font_size=42][color=#4A291C]今日总收入  ¥{result.TotalRevenue}[/color][/font_size]\n销售额 ¥{result.SaleRevenue}  ·  小费 ¥{result.Tips}\n永久金币增加 ¥{_commit.PermanentCoinGain}{(_commit.NewBest ? "  ·  新纪录" : string.Empty)}\n\n完成 {result.CompletedCustomers} 位  ·  流失 {result.LostCustomers} 位\n满意度 {result.Satisfaction:0}%  ·  Perfect {result.PerfectOrders} 单\n最高连续正确 {result.HighestCorrectStreak} 单\n油条使用 {result.YoutiaoUsed} 根  ·  炸焦 {result.YoutiaoBurnt} 根{stars}[/center]";
        string[] unlocks = _controller.CurrentConfig!.CompletionUnlocks.ToArray();
        _unlockText.Text = unlocks.Length > 0 ? "新设备或新内容已经送到店里，回到经营首页查看。" : "今天的记录已经写进经营手账。";
        _resultBlocker.Visible = true;
        _results.Visible = true;
    }

    private bool SubmitPrepared(Pancake.PancakeStateMachine machine)
    {
        int selectedSlot = SelectedSlotIndex();
        DeliveryEvaluation evaluation = _controller.TryDeliverSelected(machine, _catalog);
        ShowFeedback(evaluation.Message, evaluation.Grade is DeliveryGrade.Incorrect or DeliveryGrade.Rejected);
        PlayDeliveryEffects(evaluation, selectedSlot);
        return evaluation.ItemAccepted || evaluation.CompletesOrder;
    }

    private bool SubmitProduct(ProductKind kind)
    {
        int selectedSlot = SelectedSlotIndex();
        DeliveryEvaluation evaluation = kind switch
        {
            ProductKind.Youtiao when _workstation.FryerMachine is not null => _controller.TryDeliverYoutiaoSelected(_workstation.FryerMachine.Inventory),
            ProductKind.SoyMilk when _workstation.SoyMilkTray is not null => _controller.TryDeliverSoyMilkSelected(_workstation.SoyMilkTray),
            _ => new DeliveryEvaluation(DeliveryGrade.Rejected, 0, 0, 0, "当前商品不可交付。"),
        };
        if (kind == ProductKind.Youtiao && (evaluation.ItemAccepted || evaluation.CompletesOrder)) _controller.Ledger?.RecordYoutiaoUsed();
        ShowFeedback(evaluation.Message, evaluation.Grade is DeliveryGrade.Incorrect or DeliveryGrade.Rejected);
        PlayDeliveryEffects(evaluation, selectedSlot);
        return evaluation.ItemAccepted || evaluation.CompletesOrder;
    }

    private void SelectSlot(int index)
    {
        if (index < _controller.CustomerQueue!.Slots.Count && !_controller.CustomerQueue.TrySelect(_controller.CustomerQueue.Slots[index].Id))
            ShowFeedback("这位顾客还没有站稳，请稍等一下。", true);
        RenderCustomers();
    }

    private void RequestAbandon()
    {
        if (_controller.State is DayState.Opening or DayState.Running or DayState.Closing) _abandonDialog.PopupCentered();
        else HubRequested?.Invoke();
    }

    private void Render()
    {
        if (_controller?.CurrentConfig is null) return;
        _dayTitle.Text = $"Day {_controller.CurrentConfig.Day} · {DaySubtitle(_controller.CurrentConfig.Day)}";
        _clock.Text = _controller.State switch
        {
            DayState.Opening => $"开门 {_controller.OpeningRemainingSeconds:0.0}",
            DayState.Closing => $"收尾 {_controller.ClosingRemainingSeconds:0.0}",
            _ => $"剩余 {FormatTime(_controller.DayRemainingSeconds)}",
        };
        if (_controller.State == DayState.Opening)
            _countdown.Text = Math.Max(1, (int)Math.Ceiling(_controller.OpeningRemainingSeconds)).ToString();
        _income.Text = $"¥{_controller.Ledger?.Build().TotalRevenue ?? 0}";
        RenderCustomers();
    }

    private void RenderCustomers()
    {
        if (_controller?.CustomerQueue is null) return;
        IReadOnlyList<CustomerRuntime> slots = _controller.CustomerQueue.Slots;
        _door.Text = $"门外候场 {_controller.CustomerQueue.DoorQueue.Count}";
        for (int index = 0; index < _customerButtons.Length; index++)
        {
            Button button = _customerButtons[index];
            if (index >= slots.Count)
            {
                button.Visible = false;
                _portraits[index].Rotation = 0;
                _customerSignatures[index] = string.Empty;
                _portraitSignatures[index] = string.Empty;
                continue;
            }
            CustomerRuntime customer = slots[index];
            button.Visible = true;
            bool selected = _controller.CustomerQueue.SelectedCustomerId == customer.Id;
            string progress = string.Join(',', customer.Order.Lines.Select((_, line) => customer.Progress.GetDeliveredQuantity(line)));
            string signature = customer.Id + ":" + progress;
            if (!string.Equals(_customerSignatures[index], signature, StringComparison.Ordinal))
            {
                _customerSignatures[index] = signature;
                RenderOrder(index, customer);
                button.Modulate = new Color(1, 1, 1, 0.25f);
                button.Scale = new Vector2(0.96f, 0.96f);
                button.PivotOffset = button.Size * 0.5f;
                CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out)
                    .TweenProperty(button, "modulate", Colors.White, 0.24);
                CreateTween().SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out)
                    .TweenProperty(button, "scale", selected ? new Vector2(1.025f, 1.025f) : Vector2.One, 0.24);
            }
            else button.Scale = selected ? new Vector2(1.025f, 1.025f) : Vector2.One;
            button.Disabled = customer.State is CustomerState.Entering or CustomerState.Leaving or CustomerState.Served;
            CustomerExpression expression = TianjinArtCatalog.ResolveCustomerExpression(customer.State, customer.WasServed);
            string portraitSignature = $"{customer.Type.Id}:{expression}";
            if (!string.Equals(_portraitSignatures[index], portraitSignature, StringComparison.Ordinal))
            {
                _portraitSignatures[index] = portraitSignature;
                _portraits[index].SetVisual(_art.CustomerPortrait(customer.Type.Id, expression));
            }
            double motionTime = Time.GetTicksMsec() / 1000.0;
            _portraits[index].PivotOffset = _portraits[index].Size * 0.5f;
            _portraits[index].Rotation = customer.State switch
            {
                CustomerState.Impatient => Mathf.DegToRad(Mathf.Sin((float)(motionTime * 7.0 + index)) * 0.8f),
                CustomerState.Angry => Mathf.DegToRad(Mathf.Sin((float)(motionTime * 11.0 + index)) * 1.7f),
                _ => 0,
            };
            _customerBadges[index].Text = (selected ? "➜ 正在出餐 · " : string.Empty) + CustomerBadge(customer.Type.Id) + CustomerStateText(customer.State);
            _customerBadges[index].Modulate = selected ? TianjinUi.Orange : StateColor(customer.State);
            _patienceBars[index].Value = Math.Clamp((1 - customer.PatienceProgress) * 100, 0, 100);
            _patienceBars[index].AddThemeStyleboxOverride("fill", TianjinUi.Box(StateColor(customer.State), 7, 0, false));
            button.AddThemeStyleboxOverride("normal", TianjinUi.Box(selected ? new Color(1, 0.84f, 0.33f, 0.26f) : new Color(1, 1, 1, 0), 16, selected ? 4 : 0, false));
        }
    }

    private void RenderOrder(int slot, CustomerRuntime customer)
    {
        HBoxContainer row = _orderRows[slot];
        foreach (Node child in row.GetChildren()) child.QueueFree();
        for (int index = 0; index < customer.Order.Lines.Count; index++)
        {
            OrderLineData line = customer.Order.Lines[index];
            int delivered = customer.Progress.GetDeliveredQuantity(index);
            var item = new VBoxContainer { CustomMinimumSize = new Vector2(96, 98), MouseFilter = MouseFilterEnum.Ignore };
            item.AddThemeConstantOverride("separation", 0);
            ArtVisual productVisual = _art.ProductVisual(line.ProductKind);
            item.AddChild(TianjinUi.Texture(productVisual.Texture, new Vector2(58, 46)));
            string name = line.ProductKind switch { ProductKind.Pancake => "煎饼", ProductKind.Youtiao => "单卖油条", _ => "豆浆" };
            item.AddChild(TianjinUi.Label(name, 16, TianjinUi.BrownText, HorizontalAlignment.Center));
            item.AddChild(TianjinUi.Label(delivered >= line.Quantity ? $"✓ {delivered}/{line.Quantity}" : $"{delivered}/{line.Quantity}", 18, delivered >= line.Quantity ? TianjinUi.Green : TianjinUi.BrownText, HorizontalAlignment.Center));
            if (line.ProductKind == ProductKind.Pancake && _catalog.RecipesById.TryGetValue(line.DefinitionId, out RecipeData? recipe) && recipe.ExtraIngredients.Count > 0)
            {
                var toppings = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center, MouseFilter = MouseFilterEnum.Ignore };
                foreach (string ingredient in recipe.ExtraIngredients)
                    toppings.AddChild(TianjinUi.Texture(_art.Ingredient(ingredient), new Vector2(21, 18)));
                item.AddChild(toppings);
            }
            row.AddChild(item);
        }
    }

    private void ShowFeedback(string message, bool error)
    {
        _feedback.Text = (error ? "！ " : "✓ ") + message;
        _feedback.Modulate = error ? TianjinUi.Red : TianjinUi.Green;
        _feedbackPanel.Visible = true;
        _feedbackPanel.Modulate = new Color(1, 1, 1, 0.2f);
        _feedbackPanel.Position = new Vector2(600, 94);
        _feedbackRemaining = 2.4;
        CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out)
            .TweenProperty(_feedbackPanel, "modulate", Colors.White, 0.18);
        CreateTween().SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out)
            .TweenProperty(_feedbackPanel, "position", new Vector2(600, 104), 0.18);
    }

    private int SelectedSlotIndex()
    {
        if (_controller?.CustomerQueue is null) return -1;
        string? selected = _controller.CustomerQueue.SelectedCustomerId;
        for (int index = 0; index < _controller.CustomerQueue.Slots.Count; index++)
            if (_controller.CustomerQueue.Slots[index].Id == selected) return index;
        return -1;
    }

    private void PlayDeliveryEffects(DeliveryEvaluation evaluation, int slot)
    {
        if (slot < 0 || slot >= _customerButtons.Length || !evaluation.CompletesOrder) return;
        Vector2 origin = GetGlobalTransform().AffineInverse() * _customerButtons[slot].GetGlobalRect().GetCenter();
        if (evaluation.Grade is DeliveryGrade.Perfect or DeliveryGrade.Correct)
        {
            for (int index = 0; index < (evaluation.Grade == DeliveryGrade.Perfect ? 5 : 3); index++)
                SpawnCelebration(_art.HeartEffect, origin + new Vector2((index - 2) * 28, 12), new Vector2((index - 2) * 20, -100 - index * 12), index * 0.035);
        }
        if (evaluation.Grade == DeliveryGrade.Perfect)
        {
            for (int index = 0; index < 3; index++)
                SpawnCelebration(_art.StarEffect, origin + new Vector2((index - 1) * 44, -20), new Vector2((index - 1) * 25, -142), 0.05 + index * 0.04);
        }
        if (evaluation.TotalRevenue > 0)
        {
            Vector2 target = GetGlobalTransform().AffineInverse() * _coinTarget.GetGlobalRect().GetCenter();
            for (int index = 0; index < 3; index++) SpawnFlyingCoin(origin + new Vector2(index * 13 - 13, 0), target, index * 0.08);
        }
    }

    private void SpawnCelebration(Texture2D texture, Vector2 position, Vector2 travel, double delay)
    {
        var effect = TianjinUi.Texture(texture, new Vector2(58, 58));
        effect.Position = position - effect.Size * 0.5f;
        effect.PivotOffset = effect.Size * 0.5f;
        effect.Scale = new Vector2(0.35f, 0.35f);
        effect.Modulate = new Color(1, 1, 1, 0);
        effect.MouseFilter = MouseFilterEnum.Ignore;
        effect.ZIndex = 86;
        AddChild(effect);
        Tween tween = CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(effect, "position", effect.Position + travel, 0.72).SetDelay(delay);
        tween.TweenProperty(effect, "scale", Vector2.One, 0.34).SetDelay(delay);
        tween.TweenProperty(effect, "modulate", Colors.White, 0.18).SetDelay(delay);
        tween.Chain().TweenProperty(effect, "modulate", new Color(1, 1, 1, 0), 0.24).SetDelay(0.24);
        tween.Finished += effect.QueueFree;
    }

    private void SpawnFlyingCoin(Vector2 origin, Vector2 target, double delay)
    {
        var coin = TianjinUi.Texture(_art.Coin, new Vector2(38, 38));
        coin.Position = origin - coin.Size * 0.5f;
        coin.MouseFilter = MouseFilterEnum.Ignore;
        coin.ZIndex = 87;
        AddChild(coin);
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.InOut);
        tween.TweenProperty(coin, "position", target - coin.Size * 0.5f, 0.62).SetDelay(delay);
        tween.Parallel().TweenProperty(coin, "scale", new Vector2(0.65f, 0.65f), 0.62).SetDelay(delay);
        tween.TweenProperty(coin, "modulate", new Color(1, 1, 1, 0), 0.12);
        tween.Finished += coin.QueueFree;
    }

    private static string CustomerBadge(string id) => id switch
    {
        "office_worker" => "赶时间上班族 · 优先",
        "regular" => "老顾客 · 很有耐心",
        "big_order" => "大订单顾客 · 多件",
        _ => "普通顾客",
    };

    private static string CustomerStateText(CustomerState state) => state switch
    {
        CustomerState.Entering => " · 入场中",
        CustomerState.Impatient => " · ！着急",
        CustomerState.Angry => " · ！生气",
        CustomerState.Leaving => " · 已离开",
        CustomerState.Served => " · ✓ 已取餐",
        _ => string.Empty,
    };

    private static string DaySubtitle(int day) => day switch
    {
        1 => "第一张煎饼", 5 => "油条开锅", 9 => "豆浆套餐", 11 => "特殊顾客", 12 => "大订单", 15 => "天津最终高峰", _ => "早餐高峰",
    };

    private static Color StateColor(CustomerState state) => state switch
    {
        CustomerState.Happy => TianjinUi.Green,
        CustomerState.Normal => TianjinUi.Brown,
        CustomerState.Impatient => TianjinUi.Orange,
        CustomerState.Angry => TianjinUi.Red,
        _ => new Color("#8A7766"),
    };

    private static string FormatTime(double seconds) => $"{(int)seconds / 60:00}:{(int)seconds % 60:00}";
}
