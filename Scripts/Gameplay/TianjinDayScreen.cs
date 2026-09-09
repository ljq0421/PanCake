using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;
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
    private readonly OrderBubbleView[] _orderCards = new OrderBubbleView[5];
    private readonly CustomerPortraitView[] _portraits = new CustomerPortraitView[5];
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
    private readonly Dictionary<Control, Tween> _coinFlights = new();
    private CoinCollectionFeedback _collectionFeedback = null!;
    internal IReadOnlyCollection<Control> PaymentCoins => _coinFlights.Keys;

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        ClearCoinFlights();
        _collectionFeedback.Clear();
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
        if (_workstation.CoinTray is { } tray)
        {
            _collectionFeedback.Bind(tray, this, _coinTarget, _art.Coin, () =>
                _focused && IsVisibleInTree() && !_committed && !_manualPaused && !_focusPaused
                && !_abandonDialog.Visible && !_controller.IsPaused
                && _controller.State is DayState.Running or DayState.Closing);
        }
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

    public override void _Input(InputEvent @event)
    {
        if (@event is not InputEventMouseButton { ButtonIndex: MouseButton.Right, Pressed: true }) return;
        if (!IsVisibleInTree() || !_focused || _abandonDialog.Visible
            || _controller?.State is not (DayState.Running or DayState.Closing)
            || _manualPaused || _focusPaused || _pausePanel.Visible || _results.Visible) return;
        // Handle before GUI controls consume the click, including while brushing on the pancake.
        if (_workstation.TryFinishSauceWithRightClick()) GetViewport().SetInputAsHandled();
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is not InputEventKey { Pressed: true, Echo: false } key) return;
        if (!IsVisibleInTree() || !_focused) return;
        if (_abandonDialog.Visible) return;
        if (key.Keycode is Key.F or Key.G)
        {
            if (key.AltPressed || key.CtrlPressed || key.MetaPressed || key.ShiftPressed) return;
            if (_controller?.State is not (DayState.Running or DayState.Closing)
                || _manualPaused || _focusPaused || _pausePanel.Visible || _results.Visible) return;
            if (_workstation.TryInvokeProductionShortcut(key.Keycode)) GetViewport().SetInputAsHandled();
            return;
        }
        if (key.Keycode != Key.Escape) return;
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
        background.Name = "ShopBackground";
        background.Material = new ShaderMaterial
        {
            Shader = new Shader
            {
                Code = """
                    shader_type canvas_item;

                    void fragment() {
                        vec4 source = texture(TEXTURE, UV);
                        // Soften the storefront only; the painted counter retains its original color.
                        float storefront = 1.0 - smoothstep(0.475, 0.5324, UV.y);
                        float sides = smoothstep(0.18, 0.44, abs(UV.x - 0.5));
                        float softness = storefront * mix(0.065, 0.115, sides);
                        vec3 cream = vec3(1.0, 0.945, 0.824);
                        COLOR = vec4(mix(source.rgb, cream, softness), source.a);
                    }
                    """,
            },
        };
        TianjinUi.FullRect(background);
        AddChild(background);

        _workstation = new PancakeWorkstation { UseServingTray = true, ProductionShortcutsEnabled = true };
        TianjinUi.FullRect(_workstation);
        _workstation.Feedback += ShowFeedback;
        _workstation.YoutiaoConsumed += quantity => _controller?.Ledger?.RecordYoutiaoUsed(quantity);
        _workstation.YoutiaoBurnt += quantity => _controller?.Ledger?.RecordYoutiaoBurnt(quantity);
        AddChild(_workstation);

        BuildCustomers();
        BuildHud();
        _collectionFeedback = new CoinCollectionFeedback { Collecting = ClearCoinFlights }; AddChild(_collectionFeedback);
        VisibilityChanged += () => { if (!IsVisibleInTree()) { ClearCoinFlights(); _collectionFeedback.Clear(); } };
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
        var content = new Control { CustomMinimumSize = new Vector2(0, 52), MouseFilter = MouseFilterEnum.Ignore };
        hud.AddChild(content);
        HBoxContainer dayGroup = HudGroup(content, "DayContext", 0, 0.28f, BoxContainer.AlignmentMode.Begin);
        HBoxContainer serviceGroup = HudGroup(content, "ServiceProgress", 0.28f, 0.72f, BoxContainer.AlignmentMode.Center);
        serviceGroup.AddThemeConstantOverride("separation", 24);
        HBoxContainer actionsGroup = HudGroup(content, "IncomeAndPause", 0.72f, 1, BoxContainer.AlignmentMode.End);
        _dayTitle = TianjinUi.Label("Day 1", 28, TianjinUi.BrownDark);
        dayGroup.AddChild(_dayTitle);
        _completedOrders = TianjinUi.Label("完成订单 0/0", 20, TianjinUi.BrownText);
        _completedOrders.Name = "CompletedOrders";
        serviceGroup.AddChild(_completedOrders);
        _door = TianjinUi.Label("门外候场 0", 18, TianjinUi.Brown);
        serviceGroup.AddChild(_door);
        _clock = TianjinUi.Label("01:00", 28, TianjinUi.BrownDark);
        _clock.CustomMinimumSize = new Vector2(158, 0);
        serviceGroup.AddChild(_clock);
        _coinTarget = TianjinUi.Texture(_art.Coin, new Vector2(36, 36));
        _coinTarget.SizeFlagsVertical = SizeFlags.ShrinkCenter;
        actionsGroup.AddChild(_coinTarget);
        _income = TianjinUi.Label("今日收入 ¥0", 22, TianjinUi.BrownText);
        actionsGroup.AddChild(_income);
        var pause = TianjinUi.Button("暂停", false, new Vector2(112, 52));
        pause.Name = "PauseButton";
        pause.Pressed += () => SetManualPaused(true);
        actionsGroup.AddChild(pause);
    }

    private static HBoxContainer HudGroup(Control parent, string name, float left, float right, BoxContainer.AlignmentMode alignment)
    {
        var group = new HBoxContainer { Name = name, Alignment = alignment, MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(group);
        TianjinUi.FullRect(group);
        group.AnchorLeft = left;
        group.AnchorRight = right;
        group.AddThemeConstantOverride("separation", 16);
        return group;
    }

    private void BuildCustomers()
    {
        // Food on the back edge of the counter rises into this layout rectangle.
        // Delivery zones resolve drops themselves; the empty strip must not eat pickup clicks.
        var customers = new Control { MouseFilter = MouseFilterEnum.Ignore };
        customers.Name = "CustomerStrip";
        customers.Position = new Vector2(54, CustomerStripTop);
        customers.Size = new Vector2(1812, CustomerStripHeight);
        customers.ZIndex = 30;
        AddChild(customers);
        for (int index = 0; index < _customerSlots.Length; index++)
        {
            var button = new Control
            {
                Name = $"CustomerSlot{index + 1}",
                CustomMinimumSize = new Vector2(340, CustomerStripHeight),
                Position = new Vector2(32 + index * 352, 0),
                Size = new Vector2(340, CustomerStripHeight),
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
            column.AddThemeConstantOverride("separation", 16);
            button.AddChild(column);
            var bubble = new OrderBubbleView(_art);
            column.AddChild(bubble);
            _orderCards[index] = bubble;
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
        _feedbackPanel.Position = new Vector2(600, 100);
        _feedbackPanel.Size = new Vector2(720, 48);
        _feedbackPanel.MouseFilter = MouseFilterEnum.Ignore;
        _feedbackPanel.ZIndex = 80;
        _feedbackPanel.Visible = false;
        AddChild(_feedbackPanel);
        _feedback = TianjinUi.Label(string.Empty, 19, TianjinUi.Green, HorizontalAlignment.Center);
        _feedback.MouseFilter = MouseFilterEnum.Ignore;
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
        _collectionFeedback.Clear();
        ClearCoinFlights();
        if (_committed) return;
        _committed = true;
        _workstation.InteractionEnabled = false;
        _workstation.CancelInput();
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
            ProductKind.Pancake => _workstation.DeliverPancakeTo(_controller, customerId, _catalog),
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
        foreach (Tween tween in _coinFlights.Values)
        {
            if (paused) tween.Pause();
            else tween.Play();
        }
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
        _workstation.CoinTray?.RenderRevenue(progress?.TotalRevenue ?? 0);
        RenderCustomers();
    }

    private void RenderCustomers()
    {
        if (_controller?.CustomerQueue is null) return;
        _door.Text = $"门外候场 {_controller.CustomerQueue.DoorQueue.Count}";
        for (int index = 0; index < _customerSlots.Length; index++)
        {
            Control button = _customerSlots[index];
            CustomerRuntime? customer = _controller.CustomerQueue.CustomerAtSlot(index);
            if (customer is null)
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
            _orderCards[index].Patience.Value = Math.Clamp((1 - customer.PatienceProgress) * 100, 0, 100);
            ((StyleBoxFlat)_orderCards[index].Patience.GetThemeStylebox("fill")).BgColor = StateColor(customer.State);
        }
    }

    private void RenderOrder(int slot, CustomerRuntime customer) =>
        _orderCards[slot].Render(customer.Order, customer.Progress, _catalog.RecipesById);

    private void ShowFeedback(string message, bool error)
    {
        _feedback.Text = (error ? "！ " : "✓ ") + message;
        _feedback.Modulate = error ? TianjinUi.Red : TianjinUi.Green;
        _feedbackPanel.Visible = true;
        _feedbackPanel.Modulate = new Color(1, 1, 1, 0.2f);
        _feedbackPanel.Position = new Vector2(600, 96);
        _feedbackRemaining = 2.4;
        CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out)
            .TweenProperty(_feedbackPanel, "modulate", Colors.White, 0.18);
        CreateTween().SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out)
            .TweenProperty(_feedbackPanel, "position", new Vector2(600, 100), 0.18);
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
        if (evaluation.TotalRevenue > 0 && !ReducedMotion)
        {
            Vector2 target = GetGlobalTransform().AffineInverse() * (_workstation.CoinTray?.LandingPoint ?? _coinTarget.GetGlobalRect().GetCenter());
            for (int index = 0; index < 3; index++) SpawnFlyingCoin(origin + new Vector2(index * 13 - 13, 0), target, index * 0.08, index);
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

    private void SpawnFlyingCoin(Vector2 origin, Vector2 target, double delay, int index)
    {
        var coin = TianjinUi.Texture(_art.Coin, new Vector2(38, 38));
        coin.Name = "FlyingPaymentCoin";
        coin.Size = coin.CustomMinimumSize;
        coin.Position = origin - coin.Size * 0.5f;
        coin.PivotOffset = coin.Size * .5f;
        coin.MouseFilter = MouseFilterEnum.Ignore;
        coin.ZIndex = 87;
        AddChild(coin);
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.InOut);
        _coinFlights[coin] = tween;
        tween.TweenProperty(coin, "position", target - coin.Size * 0.5f, 0.62).SetDelay(delay);
        tween.Parallel().TweenProperty(coin, "scale", new Vector2(0.65f, 0.65f), 0.62).SetDelay(delay);
        if (_workstation.CoinTray is { } tray) tray.AppendPaymentLanding(tween, coin, this, index);
        else tween.TweenProperty(coin, "modulate", new Color(1, 1, 1, 0), 0.12);
        tween.Finished += () => { _coinFlights.Remove(coin); coin.QueueFree(); };
    }

    private void ClearCoinFlights()
    {
        foreach ((Control coin, Tween tween) in _coinFlights)
        {
            tween.Kill();
            if (IsInstanceValid(coin)) coin.QueueFree();
        }
        _coinFlights.Clear();
    }

    public override void _ExitTree() => ClearCoinFlights();

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
