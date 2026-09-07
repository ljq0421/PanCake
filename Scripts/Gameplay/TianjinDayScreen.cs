using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

/*
THESIS: the shop itself is the interface; customers, food, and equipment carry the service rhythm instead of a workflow dashboard.
OWN-WORLD: the approved Tianjin storefront fills the frame while cream paper, warm status colors, dark-brown outlines, and one soft shadow hold the HUD.
STORY: read visual orders above the queue, prepare food across the physical counter, drag food to its guest, and close on a printed receipt.
FIRST VIEWPORT: five guests own the open window; the fryer, large pancake stove, ingredients, and delivery shelf sit exactly on the painted counter.
FORM: a single-screen casual management workbench at a fixed 16:9 design resolution.
*/
public partial class TianjinDayScreen : Control
{
    private const float CustomerStripTop = 160;
    private const float CountertopTop = 575;
    private const float CustomerStripHeight = CountertopTop - CustomerStripTop;

    public event Action? HubRequested;

    private readonly Control[] _customerSlots = new Control[5];
    private readonly DropZone[] _customerDropZones = new DropZone[5];
    private readonly string?[] _deliveryCustomerIds = new string?[5];
    private readonly PanelContainer[] _orderCards = new PanelContainer[5];
    private readonly HBoxContainer[] _orderRows = new HBoxContainer[5];
    private readonly CustomerPortraitView[] _portraits = new CustomerPortraitView[5];
    private readonly Label[] _customerBadges = new Label[5];
    private readonly Label[] _customerStateBadges = new Label[5];
    private readonly ProgressBar[] _patienceBars = new ProgressBar[5];
    private readonly string[] _customerSignatures = new string[5];
    private readonly string[] _portraitSignatures = new string[5];
    private readonly CustomerState?[] _displayedCustomerStates = new CustomerState?[5];
    private readonly Dictionary<Control, Tween> _uiTweens = new();
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private DayController _controller = null!;
    private TianjinArtCatalog _art = null!;
    private PancakeWorkstation _workstation = null!;
    private Label _dayTitle = null!;
    private Label _completedOrders = null!;
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
    private ColorRect _pauseBlocker = null!;
    private PanelContainer _pausePanel = null!;
    private DayCommitResult _commit;
    private bool _committed;
    private bool _focused = true;
    private bool _manualPaused;
    private bool _focusPaused;
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
        _manualPaused = false;
        _focusPaused = false;
        _pauseBlocker.Visible = false;
        _pausePanel.Visible = false;
        Array.Fill(_customerSignatures, string.Empty);
        Array.Fill(_portraitSignatures, string.Empty);
        Array.Fill(_displayedCustomerStates, null);
        Array.Fill(_deliveryCustomerIds, null);
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
        _workstation.DirectCustomerDelivery = true;
        _workstation.InteractionEnabled = false;
        _workstation.ResetForDay();
        ApplyPauseState();
        Render();
    }

    public void BeginDay()
    {
        if (_controller is null) return;
        if (_controller.TryStartDay(out string error))
        {
            SetManualPaused(false);
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

    internal void RefreshForCapture(bool forceWorkstationActive = false)
    {
        if (forceWorkstationActive)
        {
            _workstation.InteractionEnabled = true;
            _workstation.Paused = false;
        }
        _workstation.RefreshForCapture();
        Render();
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
            _focusPaused = true;
            _workstation?.CancelInput();
            ApplyPauseState();
        }
        else if (what == NotificationApplicationFocusIn)
        {
            _focused = true;
            _focusPaused = false;
            ApplyPauseState();
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is not InputEventKey { Keycode: Key.Escape, Pressed: true, Echo: false }) return;
        if (_abandonDialog.Visible) return;
        if (_controller?.State is not (DayState.Opening or DayState.Running or DayState.Closing)) return;
        SetManualPaused(!_manualPaused);
        GetViewport().SetInputAsHandled();
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
        BuildPauseOverlay();
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
            Title = "放弃本日？",
            DialogText = "本日收入和成绩不会保存，重新开始仍会遇到同一批顾客。",
            OkButtonText = "确认放弃",
            CancelButtonText = "继续营业",
        };
        _abandonDialog.Confirmed += () =>
        {
            _controller.AbandonDay();
            _workstation.ResetForDay();
            SetManualPaused(false);
            HubRequested?.Invoke();
        };
        _abandonDialog.Canceled += () =>
        {
            if (_manualPaused) _pausePanel.Visible = true;
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
        row.AddThemeConstantOverride("separation", 16);
        hud.AddChild(row);
        _dayTitle = TianjinUi.Label("Day 1", 28, TianjinUi.BrownDark);
        _dayTitle.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        row.AddChild(_dayTitle);
        _completedOrders = TianjinUi.Label("完成订单 0/0", 18, TianjinUi.BrownText);
        _completedOrders.Name = "CompletedOrders";
        row.AddChild(_completedOrders);
        _door = TianjinUi.Label("门外候场 0", 18, TianjinUi.Brown);
        row.AddChild(_door);
        _clock = TianjinUi.Label("01:00", 26, TianjinUi.BrownDark);
        row.AddChild(_clock);
        _coinTarget = TianjinUi.Texture(_art.Coin, new Vector2(44, 44));
        row.AddChild(_coinTarget);
        _income = TianjinUi.Label("今日收入 ¥0", 21, TianjinUi.Green);
        row.AddChild(_income);
        var pause = TianjinUi.Button("暂停", false, new Vector2(112, 52));
        pause.Name = "PauseButton";
        pause.Pressed += () => SetManualPaused(true);
        row.AddChild(pause);
    }

    private void BuildCustomers()
    {
        var customers = new HBoxContainer();
        customers.Name = "CustomerStrip";
        customers.Position = new Vector2(54, CustomerStripTop);
        customers.Size = new Vector2(1812, CustomerStripHeight);
        customers.Alignment = BoxContainer.AlignmentMode.Center;
        customers.AddThemeConstantOverride("separation", 12);
        customers.ZIndex = 30;
        AddChild(customers);
        for (int index = 0; index < _customerSlots.Length; index++)
        {
            var button = new Control
            {
                Name = $"CustomerSlot{index + 1}",
                CustomMinimumSize = new Vector2(340, CustomerStripHeight),
                SizeFlagsHorizontal = SizeFlags.ShrinkCenter,
                MouseFilter = MouseFilterEnum.Ignore,
                Visible = false,
            };
            customers.AddChild(button);
            _customerSlots[index] = button;
            var dropZone = new DropZone { Name = $"CustomerDropZone{index + 1}", HitPadding = 5, ZIndex = 1 };
            TianjinUi.FullRect(dropZone);
            button.AddChild(dropZone);
            _customerDropZones[index] = dropZone;
            _workstation.RegisterCustomerZone(dropZone);

            var column = new VBoxContainer { Name = "CustomerColumn" };
            TianjinUi.FullRect(column, 4, 4, -4, 0);
            column.MouseFilter = MouseFilterEnum.Ignore;
            column.AddThemeConstantOverride("separation", 2);
            button.AddChild(column);
            var bubble = TianjinUi.Panel(TianjinUi.Paper, 14, 4, true);
            bubble.AddThemeStyleboxOverride("panel", OrderCardStyle());
            bubble.CustomMinimumSize = new Vector2(220, 108);
            bubble.SizeFlagsHorizontal = SizeFlags.ShrinkCenter;
            bubble.MouseFilter = MouseFilterEnum.Ignore;
            column.AddChild(bubble);
            _orderCards[index] = bubble;
            button.MouseEntered += () => AnimateControl(bubble, new Vector2(1.012f, 1.012f), Colors.White, 0.12);
            button.MouseExited += () => AnimateControl(bubble, Vector2.One, Colors.White, 0.12);
            var orderContent = new Control
            {
                Name = "OrderContent",
                CustomMinimumSize = new Vector2(188, 96),
                MouseFilter = MouseFilterEnum.Ignore,
            };
            bubble.AddChild(orderContent);
            _orderRows[index] = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center, MouseFilter = MouseFilterEnum.Ignore };
            _orderRows[index].AddThemeConstantOverride("separation", 6);
            TianjinUi.FullRect(_orderRows[index], 0, 16, 0, -8);
            orderContent.AddChild(_orderRows[index]);

            _customerBadges[index] = OrderBadge("CustomerTypeBadge", HorizontalAlignment.Left);
            _customerBadges[index].Position = new Vector2(4, 0);
            _customerBadges[index].Size = new Vector2(84, 16);
            orderContent.AddChild(_customerBadges[index]);
            _customerStateBadges[index] = OrderBadge("CustomerStateBadge", HorizontalAlignment.Right);
            _customerStateBadges[index].SetAnchorsPreset(LayoutPreset.TopRight);
            _customerStateBadges[index].OffsetLeft = -96;
            _customerStateBadges[index].OffsetTop = 0;
            _customerStateBadges[index].OffsetRight = -4;
            _customerStateBadges[index].OffsetBottom = 16;
            orderContent.AddChild(_customerStateBadges[index]);

            _patienceBars[index] = new ProgressBar
            {
                Name = "OrderPatience",
                MinValue = 0,
                MaxValue = 100,
                Value = 100,
                ShowPercentage = false,
                CustomMinimumSize = new Vector2(0, 8),
                MouseFilter = MouseFilterEnum.Ignore,
            };
            _patienceBars[index].SetAnchorsPreset(LayoutPreset.BottomWide);
            _patienceBars[index].OffsetTop = -8;
            _patienceBars[index].OffsetBottom = 0;
            _patienceBars[index].AddThemeStyleboxOverride("background", TianjinUi.Box(new Color("#E2CDA8"), 4, 2, false));
            _patienceBars[index].AddThemeStyleboxOverride("fill", TianjinUi.Box(TianjinUi.Green, 4, 0, false));
            orderContent.AddChild(_patienceBars[index]);
            CustomerPortraitVisual customerVisual = _art.CustomerPortrait(CustomerAppearanceCatalog.DefaultAppearanceId, CustomerExpression.Normal);
            _portraits[index] = new CustomerPortraitView
            {
                Presentation = CustomerPortraitPresentation.CounterHalfBody,
            };
            _portraits[index].SetVisual(customerVisual);
            var portraitStack = new Control
            {
                Name = "PortraitStack",
                ClipContents = true,
                MouseFilter = MouseFilterEnum.Ignore,
                SizeFlagsVertical = SizeFlags.ExpandFill,
            };
            column.AddChild(portraitStack);
            portraitStack.AddChild(_portraits[index]);
            TianjinUi.FullRect(_portraits[index]);
        }
    }

    private void BuildFeedback()
    {
        _feedbackPanel = TianjinUi.Panel(TianjinUi.Paper, 14);
        _feedbackPanel.Name = "FeedbackPanel";
        _feedbackPanel.Position = new Vector2(600, 506);
        _feedbackPanel.Size = new Vector2(720, 58);
        _feedbackPanel.ZIndex = 80;
        _feedbackPanel.Visible = false;
        AddChild(_feedbackPanel);
        _feedback = TianjinUi.Label(string.Empty, 19, TianjinUi.Green, HorizontalAlignment.Center);
        _feedbackPanel.AddChild(_feedback);
    }

    private void BuildPauseOverlay()
    {
        _pauseBlocker = new ColorRect
        {
            Name = "PauseBlocker",
            Color = new Color(0.20f, 0.09f, 0.04f, 0.42f),
            MouseFilter = MouseFilterEnum.Stop,
            ZIndex = 91,
            Visible = false,
        };
        TianjinUi.FullRect(_pauseBlocker);
        AddChild(_pauseBlocker);

        _pausePanel = TianjinUi.Panel(TianjinUi.Paper, 22);
        _pausePanel.Name = "PausePanel";
        _pausePanel.Position = new Vector2(680, 330);
        _pausePanel.Size = new Vector2(560, 360);
        _pausePanel.ZIndex = 92;
        _pausePanel.Visible = false;
        AddChild(_pausePanel);

        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 18);
        _pausePanel.AddChild(column);
        column.AddChild(TianjinUi.Label("营业暂停", 38, TianjinUi.BrownDark, HorizontalAlignment.Center));
        Label explanation = TianjinUi.Label("计时、顾客耐心和工作台都已暂停。", 20, TianjinUi.BrownText, HorizontalAlignment.Center);
        explanation.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        column.AddChild(explanation);
        Button resume = TianjinUi.Button("继续营业", true, new Vector2(0, 72));
        resume.Name = "ResumeButton";
        resume.Pressed += () => SetManualPaused(false);
        column.AddChild(resume);
        Button abandon = TianjinUi.Button("放弃本日", false, new Vector2(0, 58));
        abandon.Name = "AbandonDayButton";
        abandon.Pressed += RequestAbandon;
        column.AddChild(abandon);
        Label warning = TianjinUi.Label("放弃后，本日收入与成绩不会保存。", 17, TianjinUi.Red, HorizontalAlignment.Center);
        column.AddChild(warning);
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
            ShowFeedback("开始营业！做好早餐后，直接拖给对应顾客。", false);
        }
        else if (state == DayState.Closing)
            ShowFeedback("停止接新客，最后 15 秒把手上的订单做完。", false);
        else if (state is DayState.Preparing or DayState.Results)
            SetManualPaused(false);
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

    private bool SubmitToCustomer(string customerId, int slot, string payload)
    {
        ProductKind? kind = PancakeWorkstation.DeliveryProduct(payload);
        DeliveryEvaluation evaluation = kind switch
        {
            ProductKind.Pancake => _controller.TryDeliverPancakeTo(customerId, _workstation.Machine, _catalog),
            ProductKind.Youtiao when _workstation.FryerMachine is not null => _controller.TryDeliverYoutiaoTo(customerId, _workstation.FryerMachine.Inventory),
            ProductKind.SoyMilk when _workstation.SoyMilkTray is not null => _controller.TryDeliverSoyMilkTo(customerId, _workstation.SoyMilkTray),
            _ => new DeliveryEvaluation(DeliveryGrade.Rejected, 0, 0, 0, "当前商品不可交付。"),
        };
        if (kind == ProductKind.Youtiao && (evaluation.ItemAccepted || evaluation.CompletesOrder)) _controller.Ledger?.RecordYoutiaoUsed();
        ShowFeedback(evaluation.Message, evaluation.Grade is DeliveryGrade.Incorrect or DeliveryGrade.Rejected);
        PlayDeliveryEffects(evaluation, slot);
        return evaluation.ItemAccepted || evaluation.CompletesOrder;
    }

    private void BindDeliveryCustomer(int slot, string customerId)
    {
        if (_deliveryCustomerIds[slot] == customerId) return;
        _deliveryCustomerIds[slot] = customerId;
        _customerDropZones[slot].ConfigureResult(
            payload => _workstation.CanDeliverProduct(payload)
                && PancakeWorkstation.DeliveryProduct(payload) is ProductKind kind
                && _controller.CanDeliverTo(customerId, kind),
            payload => _workstation.DeliverToCustomer(payload, () => SubmitToCustomer(customerId, slot, payload)),
            _ => _portraits[slot].GetGlobalRect().GetCenter());
    }

    private void RequestAbandon()
    {
        if (_controller.State is DayState.Opening or DayState.Running or DayState.Closing)
        {
            SetManualPaused(true);
            _pausePanel.Visible = false;
            _abandonDialog.PopupCentered();
        }
        else HubRequested?.Invoke();
    }

    private void SetManualPaused(bool paused)
    {
        _manualPaused = paused;
        if (paused) _workstation?.CancelInput();
        bool active = _controller?.State is DayState.Opening or DayState.Running or DayState.Closing;
        _pauseBlocker.Visible = paused && active;
        _pausePanel.Visible = paused && active && !_abandonDialog.Visible;
        ApplyPauseState();
    }

    private void ApplyPauseState()
    {
        bool paused = _manualPaused || _focusPaused;
        if (_controller is not null) _controller.IsPaused = paused;
        if (_workstation is not null) _workstation.Paused = paused;
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
        DayResult? progress = _controller.Ledger?.Build();
        _completedOrders.Text = $"完成订单 {progress?.CompletedCustomers ?? 0}/{_controller.CurrentConfig.CustomerCount}";
        _income.Text = $"今日收入 ¥{progress?.TotalRevenue ?? 0}";
        RenderCustomers();
    }

    private void RenderCustomers()
    {
        if (_controller?.CustomerQueue is null) return;
        IReadOnlyList<CustomerRuntime> slots = _controller.CustomerQueue.Slots;
        _door.Text = $"门外候场 {_controller.CustomerQueue.DoorQueue.Count}";
        for (int index = 0; index < _customerSlots.Length; index++)
        {
            Control button = _customerSlots[index];
            if (index >= slots.Count)
            {
                button.Visible = false;
                _portraits[index].Rotation = 0;
                _portraits[index].Scale = Vector2.One;
                _customerSignatures[index] = string.Empty;
                _portraitSignatures[index] = string.Empty;
                _displayedCustomerStates[index] = null;
                _deliveryCustomerIds[index] = null;
                continue;
            }
            CustomerRuntime customer = slots[index];
            button.Visible = true;
            BindDeliveryCustomer(index, customer.Id);
            string progress = string.Join(',', customer.Order.Lines.Select((_, line) => customer.Progress.GetDeliveredQuantity(line)));
            string signature = customer.Id + ":" + progress;
            if (!string.Equals(_customerSignatures[index], signature, StringComparison.Ordinal))
            {
                _customerSignatures[index] = signature;
                RenderOrder(index, customer);
                if (!ReducedMotion)
                {
                    button.Modulate = new Color(1, 1, 1, 0.35f);
                    AnimateControl(button, Vector2.One, Colors.White, 0.22);
                }
            }
            CustomerExpression expression = TianjinArtCatalog.ResolveCustomerExpression(customer.State, customer.WasServed);
            string portraitSignature = $"{customer.AppearanceId}:{expression}";
            if (!string.Equals(_portraitSignatures[index], portraitSignature, StringComparison.Ordinal))
            {
                _portraitSignatures[index] = portraitSignature;
                _portraits[index].SetVisual(_art.CustomerPortrait(customer.AppearanceId, expression));
            }
            if (_displayedCustomerStates[index] is CustomerState previousState && previousState != customer.State
                && customer.State is CustomerState.Impatient or CustomerState.Angry)
                PulseCustomer(_portraits[index], customer.State == CustomerState.Angry ? TianjinUi.Red : TianjinUi.Orange, false);
            _displayedCustomerStates[index] = customer.State;
            string badge = CustomerTypeBadge(customer.Type.Id);
            _customerBadges[index].Text = badge;
            _customerBadges[index].Modulate = badge.Length == 0 ? Colors.Transparent : CustomerBadgeColor(customer.Type.Id);
            string stateBadge = CustomerStateBadge(customer.State);
            _customerStateBadges[index].Text = stateBadge;
            _customerStateBadges[index].Modulate = stateBadge.Length == 0 ? Colors.Transparent : StateColor(customer.State);
            _patienceBars[index].Value = Math.Clamp((1 - customer.PatienceProgress) * 100, 0, 100);
            _patienceBars[index].AddThemeStyleboxOverride("fill", TianjinUi.Box(StateColor(customer.State), 7, 0, false));
            _orderCards[index].AddThemeStyleboxOverride("panel", OrderCardStyle());
        }
    }

    private void RenderOrder(int slot, CustomerRuntime customer)
    {
        HBoxContainer row = _orderRows[slot];
        foreach (Node child in row.GetChildren()) child.QueueFree();
        float contentWidth = customer.Order.Lines.Sum(line => line.ProductKind == ProductKind.Pancake ? 104 : 76)
            + Math.Max(0, customer.Order.Lines.Count - 1) * 6;
        _orderCards[slot].CustomMinimumSize = new Vector2(Math.Clamp(contentWidth + 20, 220, 328), 108);
        for (int index = 0; index < customer.Order.Lines.Count; index++)
        {
            OrderLineData line = customer.Order.Lines[index];
            int delivered = customer.Progress.GetDeliveredQuantity(index);
            bool completed = delivered >= line.Quantity;
            float itemWidth = line.ProductKind == ProductKind.Pancake ? 104 : 76;
            var item = new Control
            {
                Name = "OrderItem",
                CustomMinimumSize = new Vector2(itemWidth, 72),
                MouseFilter = MouseFilterEnum.Ignore,
                Modulate = completed ? new Color(0.78f, 0.85f, 0.72f, 1f) : Colors.White,
            };
            ArtVisual productVisual = _art.ProductVisual(line.ProductKind);
            TextureRect productIcon = TianjinUi.Texture(productVisual.Texture, new Vector2(52, 36));
            productIcon.Name = "OrderProductIcon";
            productIcon.Position = new Vector2((itemWidth - 52) * 0.5f, 0);
            productIcon.Size = new Vector2(52, 36);
            item.AddChild(productIcon);
            string name = line.ProductKind switch { ProductKind.Pancake => "煎饼", ProductKind.Youtiao => "单卖油条", _ => "豆浆" };
            Label nameLabel = TianjinUi.Label(name, 14, TianjinUi.BrownText, HorizontalAlignment.Center);
            nameLabel.Position = new Vector2(0, 36);
            nameLabel.Size = new Vector2(itemWidth, 17);
            item.AddChild(nameLabel);
            string quantity = completed
                ? line.Quantity > 1 ? $"✓ {line.Quantity}/{line.Quantity}" : "✓"
                : line.Quantity > 1 ? $"{delivered}/{line.Quantity}" : string.Empty;
            if (quantity.Length > 0)
            {
                Label quantityLabel = TianjinUi.Label(quantity, 13, completed ? TianjinUi.Green : TianjinUi.BrownText, HorizontalAlignment.Center);
                quantityLabel.Name = "OrderQuantity";
                float quantityWidth = completed && line.Quantity == 1 ? 24 : 48;
                quantityLabel.Position = new Vector2(itemWidth - quantityWidth, 0);
                quantityLabel.Size = new Vector2(quantityWidth, 20);
                quantityLabel.AddThemeConstantOverride("outline_size", 3);
                quantityLabel.AddThemeColorOverride("font_outline_color", TianjinUi.Paper);
                item.AddChild(quantityLabel);
            }
            if (line.ProductKind == ProductKind.Pancake && _catalog.RecipesById.TryGetValue(line.DefinitionId, out RecipeData? recipe) && recipe.ExtraIngredients.Count > 0)
            {
                var toppings = new HBoxContainer
                {
                    Name = "OrderToppings",
                    Alignment = BoxContainer.AlignmentMode.Center,
                    MouseFilter = MouseFilterEnum.Ignore,
                    Position = new Vector2(0, 51),
                    Size = new Vector2(itemWidth, 21),
                };
                toppings.AddThemeConstantOverride("separation", 2);
                foreach (string ingredient in recipe.ExtraIngredients)
                    toppings.AddChild(OrderTopping(ingredient));
                item.AddChild(toppings);
            }
            row.AddChild(item);
        }
    }

    private Control OrderTopping(string ingredientId)
    {
        var group = new HBoxContainer
        {
            CustomMinimumSize = new Vector2(50, 22),
            MouseFilter = MouseFilterEnum.Ignore,
            Alignment = BoxContainer.AlignmentMode.Center,
        };
        group.AddThemeConstantOverride("separation", 1);
        group.AddChild(TianjinUi.Texture(_art.Ingredient(ingredientId), new Vector2(28, 22)));
        Label label = TianjinUi.Label(IngredientDisplayName(ingredientId), 12, TianjinUi.BrownText, HorizontalAlignment.Left);
        label.CustomMinimumSize = new Vector2(21, 22);
        label.VerticalAlignment = VerticalAlignment.Center;
        group.AddChild(label);
        return group;
    }

    private void ShowFeedback(string message, bool error)
    {
        _feedback.Text = (error ? "！ " : "✓ ") + message;
        _feedback.Modulate = error ? TianjinUi.Red : TianjinUi.Green;
        _feedbackPanel.Visible = true;
        _feedbackPanel.Modulate = new Color(1, 1, 1, 0.2f);
        _feedbackPanel.Position = new Vector2(600, 496);
        _feedbackRemaining = 2.4;
        CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out)
            .TweenProperty(_feedbackPanel, "modulate", Colors.White, 0.18);
        CreateTween().SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out)
            .TweenProperty(_feedbackPanel, "position", new Vector2(600, 506), 0.18);
    }

    private void PlayDeliveryEffects(DeliveryEvaluation evaluation, int slot)
    {
        if (slot < 0 || slot >= _customerSlots.Length || !evaluation.CompletesOrder) return;
        Vector2 origin = GetGlobalTransform().AffineInverse() * _customerSlots[slot].GetGlobalRect().GetCenter();
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

    private static string CustomerTypeBadge(string id)
    {
        return id switch
        {
            "office_worker" => "赶时间",
            "regular" => "耐心等待",
            "big_order" => "多件订单",
            _ => string.Empty,
        };
    }

    private static string CustomerStateBadge(CustomerState state) => state switch
    {
        CustomerState.Impatient => "着急",
        CustomerState.Angry => "即将离开",
        CustomerState.Leaving => "正在离开",
        CustomerState.Served => "已取餐",
        _ => string.Empty,
    };

    private static string IngredientDisplayName(string id) => id switch
    {
        StableIds.Ingredients.Crispy => "薄脆",
        StableIds.Ingredients.Scallion => "香葱",
        StableIds.Ingredients.Ham => "火腿",
        StableIds.Ingredients.Youtiao => "油条",
        _ => string.Empty,
    };

    private static Color CustomerBadgeColor(string id) => id switch
    {
        "office_worker" => TianjinUi.Orange,
        "regular" => TianjinUi.Green,
        "big_order" => TianjinUi.Brown,
        _ => TianjinUi.BrownText,
    };

    private static Label OrderBadge(string name, HorizontalAlignment alignment)
    {
        Label label = TianjinUi.Label(string.Empty, 13, TianjinUi.BrownText, alignment);
        label.Name = name;
        label.MouseFilter = MouseFilterEnum.Ignore;
        label.AddThemeConstantOverride("outline_size", 3);
        label.AddThemeColorOverride("font_outline_color", new Color(1f, 0.94f, 0.79f, 0.96f));
        return label;
    }

    private static StyleBoxFlat OrderCardStyle(bool selected = false)
    {
        StyleBoxFlat style = TianjinUi.Box(selected ? new Color("#FFF2C4") : TianjinUi.Paper, 14, selected ? 5 : 4, true);
        if (selected) style.BorderColor = TianjinUi.Orange;
        style.ContentMarginLeft = 10;
        style.ContentMarginTop = 6;
        style.ContentMarginRight = 10;
        style.ContentMarginBottom = 6;
        return style;
    }

    private void AnimateControl(Control control, Vector2 targetScale, Color targetModulate, double duration)
    {
        if (!IsInstanceValid(control) || control.IsQueuedForDeletion()) return;
        control.PivotOffset = control.Size * 0.5f;
        if (_uiTweens.Remove(control, out Tween? previous)) previous.Kill();
        if (ReducedMotion)
        {
            control.Scale = Vector2.One;
            control.Modulate = targetModulate;
            return;
        }
        Tween tween = CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
        _uiTweens[control] = tween;
        tween.TweenProperty(control, "scale", targetScale, duration);
        tween.TweenProperty(control, "modulate", targetModulate, duration);
        tween.Finished += () => _uiTweens.Remove(control);
    }

    private void PulseCustomer(Control portrait, Color tint, bool selected)
    {
        if (!IsInstanceValid(portrait) || portrait.IsQueuedForDeletion()) return;
        portrait.PivotOffset = portrait.Size * 0.5f;
        if (_uiTweens.Remove(portrait, out Tween? previous)) previous.Kill();
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _uiTweens[portrait] = tween;
        if (!ReducedMotion) tween.TweenProperty(portrait, "scale", new Vector2(1.035f, 1.035f), 0.12);
        tween.Parallel().TweenProperty(portrait, "modulate", new Color(tint, 1), 0.12);
        tween.TweenProperty(portrait, "scale", selected ? new Vector2(1.018f, 1.018f) : Vector2.One, 0.16);
        tween.Parallel().TweenProperty(portrait, "modulate", Colors.White, 0.16);
        tween.Finished += () => _uiTweens.Remove(portrait);
    }

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

    private static bool ReducedMotion => ProjectSettings.HasSetting("accessibility/reduce_motion")
        && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();

    private static string FormatTime(double seconds) => $"{(int)seconds / 60:00}:{(int)seconds % 60:00}";
}
