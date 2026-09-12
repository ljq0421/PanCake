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
    private bool _detailsPaused;
    private Control? _detailsReturnFocus;
    internal Button CashPendant { get; private set; } = null!;
    internal TianjinBusinessDetails BusinessDetails { get; private set; } = null!;
    private double _feedbackRemaining;
    private readonly CashPendantFeedback _paymentFeedback = new();
    private CoinCollectionFeedback _collectionFeedback = null!;
    internal IReadOnlyCollection<Control> PaymentCoins => _paymentFeedback.Coins;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _art = new TianjinArtCatalog();
        _workstation.Feedback += ShowFeedback;
        _workstation.WorkbenchActionLearned += RememberWorkbenchAction;
        _workstation.YoutiaoConsumed += quantity => _controller?.Ledger?.RecordYoutiaoUsed(quantity);
        _workstation.YoutiaoBurnt += quantity => _controller?.Ledger?.RecordYoutiaoBurnt(quantity);
        for (int i = 0; i < _customerDropZones.Length; i++)
        {
            _workstation.RegisterCustomerZone(_customerDropZones[i]);
            _orderCards[i].Configure(_art);
            // Reserve the painted pendant between slots four and five, including large orders.
            _customerSlots[i].Position += new Vector2(i < 4 ? -28 * i : 56, 0);
            _customerDropZones[i].FixedHitRect = new Rect2(18, 0, 304, CustomerStripHeight);
            OrderBubbleView card = _orderCards[i];
            card.CustomMinimumSize = new Vector2(304, card.CustomMinimumSize.Y);
            card.Size = new Vector2(304, card.Size.Y);
            card.Resized += () => AlignOrderCard(card);
            AlignOrderCard(card);
        }
        var feedbackStyle = (StyleBoxFlat)_feedbackPanel.GetThemeStylebox("panel").Duplicate();
        feedbackStyle.ContentMarginTop = feedbackStyle.ContentMarginBottom = 0;
        _feedbackPanel.AddThemeStyleboxOverride("panel", feedbackStyle);
        _feedback.AddThemeFontSizeOverride("font_size", 16);
        _feedbackPanel.CustomMinimumSize = new Vector2(720, 0);
        _feedbackPanel.ResetSize();
        BuildCashPendant();
        VisibilityChanged += () =>
        {
            if (!IsVisibleInTree()) { CloseBusinessDetails(); ClearCoinFlights(); _collectionFeedback.Clear(); }
        };
        this.FindButton("暂停").Pressed += () => SetManualPaused(true);
        this.FindButton("继续营业").Pressed += () => SetManualPaused(false);
        this.FindButton("放弃本日").Pressed += RequestAbandon;
        this.FindButton("收好收入 · 返回经营首页").Pressed += () => HubRequested?.Invoke();
        _abandonDialog.Confirmed += () =>
        {
            _controller.AbandonDay();
            _workstation.ResetForDay();
            SetManualPaused(false);
            HubRequested?.Invoke();
        };
        _abandonDialog.Canceled += () => { if (_manualPaused) _pausePanel.Visible = true; };
    }

    public void Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        CloseBusinessDetails();
        ClearCoinFlights();
        _collectionFeedback.Clear();
        _catalog = catalog;
        _save = save;
        _controller = controller;
        _workstation.ConfigureTutorial(save.Data.Tianjin.LearnedWorkbenchActions);
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
        GetNode<TextureRect>("ShopBackground").Texture = _art.WorkbenchBackground(controller.CurrentConfig.AvailableProductKinds);
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

    public override void _Input(InputEvent @event)
    {
        if (!IsVisibleInTree() || !_focused || _abandonDialog.Visible
            || _controller?.State is not (DayState.Running or DayState.Closing)
            || _manualPaused || _focusPaused || _detailsPaused || _pausePanel.Visible || _results.Visible) return;
        // Handle before GUI controls consume the click, including while brushing on the pancake.
        if (_workstation.HandleRightFoodInput(@event)) GetViewport().SetInputAsHandled();
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is not InputEventKey { Pressed: true, Echo: false } key) return;
        if (!IsVisibleInTree() || !_focused) return;
        if (_abandonDialog.Visible) return;
        if (_detailsPaused) return;
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
        // All city screens share this controller, including uninitialized hidden screens.
        if (_controller.CurrentConfig?.CityId != StableIds.Cities.Tianjin) return;
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
        bool paused = _manualPaused || _focusPaused || _detailsPaused;
        if (_controller is not null) _controller.IsPaused = paused;
        if (_workstation is not null) _workstation.Paused = paused;
        _paymentFeedback.SetPaused(paused);
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
        CashPendant.Disabled = !_focused || _manualPaused || _focusPaused || _detailsPaused || _committed
            || _abandonDialog.Visible || _workstation.IsDragging;
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
                _portraits[index].SetCounterCalibration(_art.CustomerLayout(customer.AppearanceId));
            }
            if (_displayedCustomerStates[index] is CustomerState previousState && previousState != customer.State
                && customer.State is CustomerState.Impatient or CustomerState.Angry)
                PulseCustomer(_portraits[index], customer.State == CustomerState.Angry ? TianjinUi.Red : TianjinUi.Orange, false);
            _displayedCustomerStates[index] = customer.State;
            PatienceBarPresentation.Render(_orderCards[index].Patience, 1 - customer.PatienceProgress);
        }
    }

    private void RenderOrder(int slot, CustomerRuntime customer)
    {
        OrderBubbleView card = _orderCards[slot];
        card.Render(customer.Order, customer.Progress, _catalog.RecipesById);
        card.ResetSize();
        AlignOrderCard(card);
    }

    private static void AlignOrderCard(OrderBubbleView card) =>
        card.Position = new Vector2(14, TianjinWorkbenchLayout.OrderCardBottom - card.Size.Y);

    private void RememberWorkbenchAction(string action)
    {
        if (_save is null || !_save.Data.Tianjin.LearnedWorkbenchActions.Add(action)) return;
        // Keep the session's learned action even if storage is temporarily unavailable.
        if (!_save.TrySave(out string error)) Callable.From(() => ShowFeedback(error, true)).CallDeferred();
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
            Vector2 target = TianjinWorkbenchLayout.CashSlot;
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

    private void SpawnFlyingCoin(Vector2 origin, Vector2 target, double delay, int index) =>
        _paymentFeedback.Spawn(this, _art.Coin, origin, target, delay);

    private void ClearCoinFlights() => _paymentFeedback.Clear();

    public override void _ExitTree() => ClearCoinFlights();

    private void BuildCashPendant()
    {
        Rect2 bounds = TianjinWorkbenchLayout.CashPendant;
        CashPendant = new Button { Name = "CashPendant", Position = bounds.Position, Size = bounds.Size,
            TooltipText = "查看营业明细", MouseDefaultCursorShape = CursorShape.PointingHand, ZIndex = 80 };
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            CashPendant.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        var focus = TianjinUi.Box(Colors.Transparent, 20, 2, false);
        focus.BorderColor = TianjinUi.Yellow;
        CashPendant.AddThemeStyleboxOverride("focus", focus);
        AddChild(CashPendant);
        CashPendant.Pressed += OpenBusinessDetails;
        BusinessDetails = new TianjinBusinessDetails { Name = "BusinessDetails" };
        AddChild(BusinessDetails);
        BusinessDetails.CloseRequested += CloseBusinessDetails;
    }

    internal void OpenBusinessDetails()
    {
        if (_controller?.Ledger is null || !IsVisibleInTree() || !_focused || _manualPaused || _focusPaused
            || _detailsPaused || _committed || _abandonDialog.Visible || _workstation.IsDragging) return;
        _detailsReturnFocus = GetViewport().GuiGetFocusOwner();
        _workstation.CancelInput();
        _detailsPaused = true;
        ApplyPauseState();
        BusinessDetails.Open(_controller.Ledger.Build(), _controller.BusinessRecords, _catalog);
    }

    internal void CloseBusinessDetails()
    {
        if (BusinessDetails is null) return;
        BusinessDetails.Hide();
        bool wasOpen = _detailsPaused;
        _detailsPaused = false;
        if (wasOpen) ApplyPauseState();
        if (wasOpen && IsVisibleInTree())
        {
            CashPendant.Disabled = false;
            if (IsInstanceValid(_detailsReturnFocus) && _detailsReturnFocus!.IsVisibleInTree()) _detailsReturnFocus.GrabFocus();
            else CashPendant.GrabFocus();
        }
        _detailsReturnFocus = null;
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
        1 => "第一张煎饼", 5 => "油条开锅", 9 => "豆浆套餐", 11 => "特殊顾客", 12 => "大订单", 15 => "最终高峰", _ => "早餐高峰",
    };

    private static bool ReducedMotion => ProjectSettings.HasSetting("accessibility/reduce_motion")
        && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();

    private static string FormatTime(double seconds) => $"{(int)seconds / 60:00}:{(int)seconds % 60:00}";
}
