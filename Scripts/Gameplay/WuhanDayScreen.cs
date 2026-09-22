using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.UI;
using ProjectCake.Wuhan;
using ProjectCake.Interaction;

namespace ProjectCake.Gameplay;

public partial class WuhanDayScreen : Control
{
    private const float OrderCardWidth = OrderBubbleView.CompactWidth;
    public event Action? HubRequested;
    private readonly Control[] _customers = new Control[5];
    private readonly DropZone[] _customerDropZones = new DropZone[5];
    private readonly string?[] _deliveryCustomerIds = new string?[5];
    internal DragService DeliveryDrag { get; private set; } = null!;
    private readonly OrderBubbleView[] _orders = new OrderBubbleView[5];
    private readonly ProgressBar[] _patience = new ProgressBar[5];
    private readonly CustomerPortraitView[] _portraits = new CustomerPortraitView[5];
    private readonly Label[] _deliveryQuantityLabels = new Label[5];
    private readonly Label[] _basketLabels = new Label[2];
    private DataCatalog _catalog = null!; private SaveService _save = null!; private DayController _controller = null!; private WuhanArtCatalog _art = null!;
    private NoodleCookerStateMachine _cooker = null!; private HotDryNoodlesStateMachine _bowl = null!; private DoupiStateMachine? _doupi;
    private DoupiInventory _doupiStock = null!; private WuhanIngredientInventory _ingredients = null!;
    private int _stationLevel; private int _cookerLevel; private int _doupiLevel;
    private Label _day = null!, _clock = null!, _income = null!, _door = null!, _feedback = null!, _bowlStatus = null!, _doupiStatus = null!;
    internal WuhanWorkstationView Workstation { get; private set; } = null!;
    internal CoinTrayView CoinTray { get; private set; } = null!;
    internal CoinCollectionFeedback CollectionFeedback { get; private set; } = null!;
    private TextureRect _coinTarget = null!;
    internal NoodleCookerStateMachine Cooker => _cooker;
    internal HotDryNoodlesStateMachine Bowl => _bowl;
    internal DoupiStateMachine? Doupi => _doupi;
    internal DoupiInventory DoupiStock => _doupiStock;
    internal WuhanIngredientInventory Ingredients => _ingredients;
    private PanelContainer _results = null!; private ColorRect _blocker = null!; private RichTextLabel _resultText = null!; private Label _unlock = null!;
    private ConfirmationDialog _abandon = null!; private bool _committed; private bool _focused = true; private double _feedbackSeconds;
    private bool CanInteract => _focused && IsVisibleInTree() && !_committed && !_demoLessonComplete && !DemoLessonFailed && !_abandon.Visible
        && _controller is not null && !_controller.IsPaused && _controller.State is DayState.Running or DayState.Closing;

    public override void _Ready()
    {
        InteractionHighlightTheme.Set(this, InteractionHighlightTheme.Wuhan);
        // Order icons and the drag overlay are siblings of the workbench.
        TextureFilter = TextureFilterEnum.LinearWithMipmaps;
        SceneNodeBinder.Bind(this);
        CityDialogChrome.ApplyConfirmation(_abandon, StableIds.Cities.Wuhan);
        ConfigurePresentation();
        BuildTeachingFocus();
        _art = new WuhanArtCatalog();
        DeliveryDrag.Configure(GetNode<Control>("WuhanDragOverlay"));
        DeliveryDrag.DragEnded += result =>
        {
            if (result.Completion is DragCompletion.Missed or DragCompletion.Rejected)
            {
                bool delivery = result.PayloadId != WuhanWorkstationView.TrashPayload;
                if (delivery && CanInteract) _controller.Feedback.Reject();
                Feedback(delivery ? "请拖给仍需要这份餐品的顾客。"
                    : "未丢弃；请长按右键，将当前食物拖入底部垃圾桶。", true, sound: !delivery);
            }
        };
        for (int i = 0; i < _customerDropZones.Length; i++)
        {
            int customerSlot = i;
            _customerDropZones[i].HideInteractionFrame();
            _portraits[i].BindInteractionHighlight(() => CustomerHighlight(customerSlot));
            DeliveryDrag.RegisterZone(_customerDropZones[i]);
            _orders[i].Configure(_art.Shared, _art);
            _orders[i].ConfigureCompactLayout();
        }
        Workstation.CanInteract = () => CanInteract;
        Workstation.ConfigureDelivery(DeliveryDrag);
        CoinTray.Hide();
        CoinTray.CanCollect = () => false;
        BuildCashPendant();
        BuildBusinessHud();
        Workstation.RaiseRequested = RaiseBasket;
        Workstation.PourRequested = ReservePour;
        Workstation.CutRequested = CutDoupi;
        Workstation.BasketPressed += BasketAction;
        Workstation.IngredientPressed += IngredientAction;
        Workstation.BatterRequested = PourDoupiBatter;
        Workstation.EggRequested = AddDoupiEgg;
        Workstation.FillingRequested = AddDoupiFilling;
        Workstation.FlipRequested = FlipDoupi;
        Workstation.FoodDiscarded += () => { LearnTeachingAction("discard"); Workstation.PlaySound(WuhanSound.Discard); Feedback("食物已丢弃。", false, true); Render(); };
        Workstation.MixMoved += distance =>
        {
            if (CanInteract && !Workstation.Busy("bowl") && _bowl.AddMixDistance(distance))
            {
                Workstation.PlaySound(_bowl.State == NoodleBowlState.Ready ? WuhanSound.Ready : WuhanSound.Mix);
                if (_bowl.State == NoodleBowlState.Ready) LearnTeachingAction("mix:noodles");
            }
        };
        Workstation.GestureRejected += message => Feedback(message, true);
        GetNode<Button>("@PanelContainer@312/@HBoxContainer@313/@Button@319").Pressed += () => { Workstation.CancelInput(); _abandon.PopupCentered(); };
        this.FindButton("收好收入 · 返回武汉经营首页").Pressed += () => HubRequested?.Invoke();
        ButtonHoverFeedback.Attach(this.FindButton("收好收入 · 返回武汉经营首页"));
        _abandon.Confirmed += () => { Workstation.CancelAnimations(); _controller.AbandonDay(); HubRequested?.Invoke(); };
        VisibilityChanged += () =>
        {
            if (!IsVisibleInTree()) { CloseBusinessDetails(); _controller?.SetPauseReason("wuhan-focus", false); Workstation.CancelAnimations(); CollectionFeedback.Clear(); ClearPaymentFeedback(); }
        };
    }
    private void ConfigurePresentation()
    {
        var strip = GetNode<Control>("WuhanCustomerStrip");
        // Reserve the ornaments above the cards while preserving every customer's
        // world position and the existing counter crop at the bottom of the strip.
        const float ornamentRoom = 94;
        strip.Position = new Vector2(32, 190 - ornamentRoom);
        strip.Size = new Vector2(1650, 370 + ornamentRoom);
        for (int i = 0; i < _customers.Length; i++)
        {
            _customers[i].Position = new Vector2(i * 330, ornamentRoom);
            _customers[i].Size = new Vector2(350, 430);
            _customers[i].Scale = Vector2.One * .86f;
            _customers[i].ZIndex = 0;
        }
        // Orders must never determine the scale or counter crop of a customer.
        for (int i = 0; i < _customers.Length; i++)
        {
            _portraits[i].Reparent(_customers[i], false);
            _portraits[i].Position = new Vector2(5, 162);
            _portraits[i].Size = new Vector2(340, 268);
            _portraits[i].PivotOffset = new Vector2(_portraits[i].Size.X * .5f, _portraits[i].Size.Y);
            _portraits[i].Scale = Vector2.One * 1.1f;
            _orders[i].Reparent(_customers[i], false);
            _orders[i].CustomMinimumSize = new Vector2(OrderCardWidth, 0);
            // Counter the customer-column scale so both cities share readable icon sizes.
            _orders[i].Scale = Vector2.One / _customers[i].Scale;
            _patience[i].CustomMinimumSize = new Vector2(0, 6);
            foreach (string style in new[] { "background", "fill" })
            {
                var box = (StyleBoxFlat)_patience[i].GetThemeStylebox(style).Duplicate();
                box.SetBorderWidthAll(0);
                _patience[i].AddThemeStyleboxOverride(style, box);
            }
        }
        _door.Visible = false;
        foreach (Label label in _basketLabels) label.Visible = false;
        _bowlStatus.Visible = _doupiStatus.Visible = false;
        GetNode<Control>("@PanelContainer@312").Hide();

    }
    public void ConnectController(DayController controller)
    {
        _controller = controller; controller.StateChanged += OnStateChanged; controller.DayFinished += OnFinished;
    }
    public bool Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        EquipmentUpgradeCelebration.Attach(this, () => controller.CurrentConfig?.CityId == StableIds.Cities.Wuhan
            && (CanInteract || (controller.State == DayState.Preparing && _focused && IsVisibleInTree()
                && !_hudPaused && !_abandon.Visible && !controller.IsPaused))
            && TeachingFocus.CurrentAction is null);
        _demoLesson?.Hide(); _demoLessonSkipFrame?.Hide(); _demoLessonFailure = _demoLessonSaveError = ""; _demoLessonComplete = false; _demoPendingResult = null;
        TeachingFocus.ResetSession(); _teachingDoupiLast = false;
        _hudPaused = false; _hudPauseMenu.Hide(); controller.SetPauseReason("wuhan-hud", false); _sceneFeedback.Clear();
        BusinessFeedbackAudio.Attach(this, controller.Feedback, () => controller.CurrentConfig?.CityId == StableIds.Cities.Wuhan && (CanInteract), useCartoonCoin: true, useCartoonError: true, useCartoonCompletion: true);
        CloseBusinessDetails();
        ClearPaymentFeedback();
        Workstation.CancelAnimations();
        CollectionFeedback.Clear(); CoinTray.RenderRevenue(0);
        _catalog=catalog; _save=save; _controller=controller; _committed=false; _results.Visible=false; _blocker.Visible=false;
        if (!controller.TryPrepareDay(StableIds.Cities.Wuhan,day,catalog,out string error) || !save.ApplyStartUnlocks(controller.CurrentConfig!,out error)) { Feedback(error,true); return false; }
        CityProgressData city=save.Data.Wuhan; _cookerLevel=city.EquipmentLevels.GetValueOrDefault("noodle_cooker",1); _stationLevel=city.EquipmentLevels.GetValueOrDefault("ingredient_station",1); _doupiLevel=city.EquipmentLevels.GetValueOrDefault("doupi_griddle");
        _cooker=new NoodleCookerStateMachine(catalog.NoodleCookersByLevel[_cookerLevel]); _bowl=new HotDryNoodlesStateMachine(); _ingredients=new WuhanIngredientInventory(catalog.WuhanIngredientStationsByLevel[_stationLevel]); _doupiStock=new DoupiInventory();
        _doupi=_doupiLevel>0?new DoupiStateMachine(catalog.DoupiGriddlesByLevel[_doupiLevel]):null;
        _basketLabels[1].Visible=false;
        Workstation.AllowedIngredients = controller.CurrentConfig!.AvailableRecipeIds.SelectMany(id => catalog.RecipesById[id].ExtraIngredients).Append(StableIds.Ingredients.WuhanBaseSeasoning).ToHashSet();
        RefreshWorkbenchBackground();
        Workstation.Bind(_art,_cooker,_bowl,_doupi,_doupiStock,_ingredients,_cookerLevel,_doupiLevel);
        Render();
        return true;
    }
    private void RefreshWorkbenchBackground()
    {
        var background = GetNode<TextureRect>("WorkbenchBackground");
        background.Texture = _art.WorkbenchBackground(_doupi is not null, Workstation.BeefUnlocked);
        // Reuse the clean wall behind the independently animated cash pendant.
        // Keep the supplied basic-ingredients sheet intact on disk.
        var wall = background.GetNodeOrNull<TextureRect>("CashPendantWall");
        if (wall is null)
        {
            var target = WuhanWorkbenchLayout.Rect(1520, 110, 152, 295);
            wall = new TextureRect { Name = "CashPendantWall",
                Texture = new AtlasTexture { Atlas = _art.WorkbenchBackground(false), Region = new Rect2(1520, 110, 152, 295) },
                Position = target.Position, Size = target.Size,
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.Scale, MouseFilter = MouseFilterEnum.Ignore };
            background.AddChild(wall);
        }
        wall.Visible = _doupi is null && !Workstation.BeefUnlocked;
    }
    public void BeginDay()
    {
        if (!_resumeBusinessAfterLesson && !ForceDemoTutorial)
            GetNode<EquipmentUpgradeCelebration>("UpgradeCelebration").BeforeTeaching(_controller, BeginAfterUnlocks);
        else BeginAfterUnlocks();
    }

    private void BeginAfterUnlocks() { if (BeginWuhanDemoLesson()) return; if (!_controller.TryStartDay(out string error)) Feedback(error,true); else Feedback("铺门打开，准备迎接第一位客人。",false); }

    public override void _Process(double delta)
    {
        if (_demoLessonAction is not null) _demoLessonAction.Disabled = _demoLessonSkip!.Disabled = !DemoLessonControlsEnabled;
        if (_demoLesson?.Visible == true && _demoLessonLocale != TranslationServer.GetLocale()) LayoutWuhanDemoLesson();
        UpdatePendantState();
        Workstation.SetCookingAudioPaused(!CanInteract);
        if (!CanInteract) Workstation.CancelInput();
        if (_feedbackSeconds>0 && (_feedbackSeconds-=delta)<=0) _feedback.Visible=false;
        if (!_focused || !IsVisibleInTree() || _controller?.CurrentConfig is null || _controller.IsPaused || _abandon.Visible) { Workstation.EndMix(); return; }
        if (!DemoLessonFailed) _controller.Tick(delta);
        if (!CanInteract) { Render(); return; }
        _cooker?.Tick(delta); _doupi?.Tick(delta);
        Workstation.Tick(delta); AdvanceAutomaticTransfers(); Render();
    }
    public override void _Notification(int what)
    {
        if (what==NotificationApplicationFocusOut) { _focused=false; Workstation?.CancelInput(); ApplyPendantPause(); }
        if (what==NotificationApplicationFocusIn) { _focused=true; ApplyPendantPause(); }
    }
    internal bool RaiseBasket(int index)
    {
        if (!CanInteract || Workstation.Busy($"basket{index}")) return false;
        bool raised = _cooker.TryRaise(index);
        if (raised) { LearnTeachingAction("raise:noodles"); Workstation.PlayBasket(index, NoodleBasketState.Ready, _cooker.Baskets[index].Quality); }
        return raised;
    }
    internal bool ReservePour(int index)
    {
        if (!CanInteract || Workstation.Busy("bowl") || !_cooker.TryReservePour(index, _bowl)) return false;
        AdvanceAutomaticTransfers(); Render(); return true;
    }
    internal bool CutDoupi(DoupiCutLine direction)
    {
        if (!CanInteract || Workstation.Busy("pan") || _doupi?.TryCut(direction) != true) return false;
        if (_doupi.State == DoupiState.Cut) LearnTeachingAction("doupi:cut");
        ClearDoupiFeedback(); Workstation.PlayCut(direction); Feedback(_doupi.State == DoupiState.Cut ? "切块完成，将自动补入备餐盘。" : "已离火，品质锁定；继续沿其余虚线切块。", false); Render(); return true;
    }
    private void AdvanceAutomaticTransfers()
    {
        if (!CanInteract) return;
        if (!Workstation.Busy("bowl") && _cooker.TryCompletePendingPour(out int basket, out NoodleQuality quality))
        {
            LearnTeachingAction("pour:noodles");
            Workstation.PlayBasket(basket, NoodleBasketState.Drained, quality, Workstation.PourPosition);
        }
        if (_doupi is not null && !Workstation.Busy("pan") && !Workstation.Busy("stock"))
        {
            int start = _doupiStock.Count;
            int firstPiece = _doupi.FirstRemainingPiece;
            DoupiQuality doupiQuality = _doupi.Quality;
            int moved = _doupi.TransferAvailable(_doupiStock);
            if (moved > 0) Workstation.PlayStock(moved, start, firstPiece, doupiQuality);
        }
    }

    internal void BasketAction(int index)
    {
        if(!CanInteract||index<0||index>=_cooker.Baskets.Count||Workstation.Busy($"basket{index}"))return;
        NoodleBasketRuntime item=_cooker.Baskets[index]; bool ok=false; string message="";
        NoodleBasketState before=item.State;NoodleQuality quality=item.Quality;
        if(item.State==NoodleBasketState.Empty){if(_ingredients.TryConsume(StableIds.Ingredients.WuhanNoodles)){ok=_cooker.TryStart(index);message="面条下锅。";}}
        else if(item.State is NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked){ok=_cooker.TryRaise(index);message="提篮，开始沥水。";}
        else if(item.State is NoodleBasketState.Raised or NoodleBasketState.Draining){message="自然沥水中，可拖到空碗上方等待。";}
        else if(item.State==NoodleBasketState.Drained){if(!Workstation.Busy("bowl")&&_cooker.TryTransferTo(index,_bowl)){ok=true;message="熟面倒入碗中。";}else message="拌面碗还没有空出来。";}
        else message="面还在烫，等到最佳窗口再提篮。";
        if(ok)
        {
            if (before == NoodleBasketState.Empty)
                GetNode<EquipmentUpgradeCelebration>("UpgradeCelebration").NotifyUse("noodle_cooker",
                    Workstation.BasketRect(_cooker.Baskets.Count > 1 ? 1 - index : index));
            LearnTeachingAction(before == NoodleBasketState.Empty ? "take:noodles" : before == NoodleBasketState.Drained ? "pour:noodles" : "raise:noodles");
            Workstation.PlayBasket(index,before,quality);
        }
        if (!ok || before is not (NoodleBasketState.Empty or NoodleBasketState.Drained)) Feedback(message, !ok);
        Render();
    }
    internal void IngredientAction(string id)
    {
        if(!CanInteract||Workstation.Busy("bowl")||!_ingredients.IsUnlimited(id)||Workstation.AllowedIngredients is { } allowed && !allowed.Contains(id))return;
        bool ok=id==StableIds.Ingredients.WuhanBaseSeasoning?_bowl.TryAddBaseSeasoning():_bowl.TryAddTopping(id);
        if(ok){LearnTeachingAction("take:" + id);_ingredients.TryConsume(id);Workstation.PlayIngredient(id);}
        else
        {
            string message = _bowl.Toppings.Contains(id) ? "这份配料已经加入了。"
                : id == StableIds.Ingredients.WuhanBraisedBeef ? "先把热干面搅拌完成，再加入牛肉。"
                : id == StableIds.Ingredients.WuhanBaseSeasoning && _bowl.HasBaseSeasoning ? "芝麻酱已经加入了。"
                : _bowl.State is NoodleBowlState.Mixing or NoodleBowlState.Ready ? "辣油和葱花需要在开始拌面前加入。"
                : "先把熟面放进碗里；芝麻酱、辣油和葱花可按任意顺序加入。";
            Feedback(message,true);
        }
        Render();
    }
    internal bool DeliverToCustomer(string customerId, ProductKind kind)
    {
        if (!CanInteract) return false;
        if (!Workstation.CanDeliver(kind)) { _controller.Feedback.Reject(customerId); return false; }
        DeliveryEvaluation result;
        if (kind == ProductKind.Doupi) result = _controller.TryDeliverWuhanDoupiTo(customerId, _doupiStock);
        else
        {
            DeliveredItem item;
            Func<bool> consume;
            switch (kind)
            {
                case ProductKind.HotDryNoodles:
                    if (!_bowl.TryPrepare(_catalog.RecipesById, out PreparedHotDryNoodles prepared)) { _controller.Feedback.Reject(customerId); return false; }
                    item = new DeliveredItem(kind, prepared.RecipeId, null, null, null, HotDryNoodlesStateMachine.ToQuality(prepared));
                    consume = () => { _bowl.Reset(); return true; };
                    break;
                default: return false;
            }
            result = _controller.TryDeliverWuhanTo(customerId, item, consume);
        }
        if (result.CompletesOrder && result.TotalRevenue > 0 && !_committed)
        {
            int slot = Array.IndexOf(_deliveryCustomerIds, customerId);
            if (slot >= 0 && !WuhanWorkstationView.ReducedMotion)
            {
                Vector2 origin = GetGlobalTransform().AffineInverse() * _portraits[slot].GetGlobalRect().GetCenter();
                for (int i = 0; i < 3; i++) _paymentFeedback.Spawn(this, GD.Load<Texture2D>("res://resource/art/Global/HUDUI/小费飞行金币.png"), origin + new Vector2(i * 13 - 13, 0), WuhanWorkbenchLayout.CashSlot, i * .08, i == 2 ? ReceivePendantPayment : null);
            }
        }
        if (result.ItemAccepted || result.CompletesOrder)
            Workstation.FinishPresentation(kind == ProductKind.Doupi ? "stock" : "bowl");
        if ((result.ItemAccepted || result.CompletesOrder) && result.Grade != DeliveryGrade.Incorrect)
            LearnTeachingAction(kind == ProductKind.Doupi ? "deliver:doupi" : "deliver:hot_dry_noodles");
        int feedbackSlot = Array.IndexOf(_deliveryCustomerIds, customerId);
        if (feedbackSlot >= 0) _sceneFeedback.Delivery(result, _orders[feedbackSlot]);
        DemoLessonDelivered(result);
        Render();
        return result.ItemAccepted || result.CompletesOrder;
    }

    private void ClearDoupiFeedback() { _feedbackSeconds = 0; _feedback.Hide(); }
    private bool ApplyDoupi(Func<DoupiStateMachine, bool> action, string hint, bool animate = true)
    {
        if (!CanInteract || _doupi is null || Workstation.Busy("pan")) return false;
        DoupiState before = _doupi.State;
        bool ok = action(_doupi);
        if (ok) { ClearDoupiFeedback(); if (!animate) Workstation.PlaySound(_doupi.State == DoupiState.Empty ? WuhanSound.Discard : WuhanSound.Topping); }
        if (ok && animate)
        {
            string? actionId = _doupi.State switch {
                DoupiState.Batter => "doupi:batter", DoupiState.SkinCooking => "doupi:egg",
                DoupiState.Flipped => "doupi:flip", DoupiState.SecondCooking => "doupi:filling", _ => null,
            };
            if (actionId is not null) LearnTeachingAction(actionId);
            Workstation.PlayDoupi(before);
        }
        if (!ok) Feedback(hint, true);
        Render(); return ok;
    }
    internal bool PourDoupiBatter()
    {
        bool ok = ApplyDoupi(d => d.TryPourBatter(), "空锅才能倒浆；请先处理锅中豆皮。");
        if (ok) GetNode<EquipmentUpgradeCelebration>("UpgradeCelebration").NotifyUse("doupi_griddle");
        return ok;
    }
    internal bool AddDoupiEgg() => ApplyDoupi(d => d.TryAddEgg(), "先从浆碗拖浆入锅，再点击蛋液容器。");
    internal bool FlipDoupi() => ApplyDoupi(d => d.TryFlip(), "等面皮定型后，按住锅面向上划。");
    internal bool AddDoupiFilling() => ApplyDoupi(d => d.TryAddFilling(), "翻面后拖一份三鲜馅入锅，松手自动铺匀。");
    internal bool DiscardDoupi() => ApplyDoupi(d =>
    {
        if (d.State == DoupiState.Empty) return false;
        d.Discard(); return true;
    }, "长按右键拖入垃圾桶丢弃。", false);
    internal void RefreshForCapture() => Render();
    private void Render()
    {
        UpdatePendantState();
        Workstation.SetCookingAudioPaused(!CanInteract);
        if (_controller?.CurrentConfig is null || _cooker is null) return;
        RenderBusinessHud();
        int day = _controller.CurrentConfig.Day;
        _day.Text = $"{day}";
        _clock.Text = _controller.State switch
        {
            DayState.Opening => $"开门 {_controller.OpeningRemainingSeconds:0}",
            DayState.Closing => $"收尾 {_controller.ClosingRemainingSeconds:0}",
            _ => $"{(int)_controller.DayRemainingSeconds / 60:00}:{(int)_controller.DayRemainingSeconds % 60:00}",
        };
        _income.Text = $"{_controller.Ledger?.Build().TotalRevenue ?? 0}";
        Workstation.PendingDoupiDemand = _controller.CustomerQueue?.Slots
            .Where(customer => customer.State is CustomerState.Entering or CustomerState.Happy
                or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry)
            .Sum(customer => customer.Order.Lines.Select((line, index) => line.ProductKind == ProductKind.Doupi
                ? customer.Progress.GetRemainingQuantity(index) : 0).Sum()) ?? 0;
        Workstation.RefreshRefillControls();
        Workstation.RefreshDeliverySources(); Workstation.QueueRedraw();
        RenderCustomers();
    }
    private void RenderCustomers()
    {
        if (_controller.CustomerQueue is null) return;
        for (int i=0;i<_customers.Length;i++)
        {
            // Keep portraits, orders and delivery targets at the physical slot assigned on entry.
            CustomerRuntime? customer = _controller.CustomerQueue.CustomerAtSlot(i);
            _customers[i].Visible=customer is not null;
            string? id=customer?.Id;
            if (_deliveryCustomerIds[i]!=id)
            {
                int slot=i; _deliveryCustomerIds[i]=id;
                _customerDropZones[i].ConfigureResult(
                    payload => CanInteract && WuhanWorkstationView.DeliveryProduct(payload) is ProductKind kind
                        && Workstation.CanDeliver(kind) && _controller.CanDeliverTo(id,kind),
                    payload => id is not null && _deliveryCustomerIds[slot]==id
                        && WuhanWorkstationView.DeliveryProduct(payload) is ProductKind kind && DeliverToCustomer(id,kind),
                    _ => _portraits[slot].GetGlobalRect().GetCenter());
            }
            bool preview = Workstation.DraggedProduct == ProductKind.Doupi && _customerDropZones[i].VisualState == DropZoneVisualState.HoverValid;
            int quantity = preview ? _controller.GetWuhanDoupiDeliveryQuantity(id, _doupiStock) : 0;
            _deliveryQuantityLabels[i].Text = quantity > 0 ? $"豆皮×{quantity}" : "";
            _deliveryQuantityLabels[i].Visible = quantity > 0;
            if (customer is null)
            {
                CustomerArrivalMotion.Apply(_portraits[i], _orders[i], null);
                continue;
            }
            _orders[i].Render(customer.Order,customer.Progress,_catalog.RecipesById);
            // All Wuhan cards share one compact width, with the tail over the customer.
            _orders[i].Size = new Vector2(OrderCardWidth, _orders[i].GetCombinedMinimumSize().Y);
            _orders[i].Position = new Vector2(
                (_customers[i].Size.X - _orders[i].Size.X * _orders[i].Scale.X) * .5f,
                155 - _orders[i].Size.Y * _orders[i].Scale.Y);
            PatienceBarPresentation.Render(_patience[i], 1 - customer.PatienceProgress);
            _portraits[i].SetVisual(_art.CustomerPortrait(customer.AppearanceId,TianjinArtCatalog.ResolveCustomerExpression(customer.State,customer.WasServed)));
            _portraits[i].SetCounterCalibration(_art.CustomerLayout(customer.AppearanceId));
            CustomerArrivalMotion.Apply(_portraits[i], _orders[i], customer);
        }
    }
    private InteractionHighlightState CustomerHighlight(int slot)
    {
        if (!CanInteract || _controller.CustomerQueue?.CustomerAtSlot(slot) is not { WasServed: false })
            return InteractionHighlightState.None;
        DropZone zone = _customerDropZones[slot];
        if (DeliveryDrag.IsDragging) return InteractionHighlightPresentation.FromDropZone(zone.VisualState);
        return zone.ContainsPoint(GetGlobalMousePosition(), false)
            ? InteractionHighlightState.Hover : InteractionHighlightState.None;
    }
    private void Feedback(string text, bool error, bool force = false, bool sound = true)
    {
        if (error && sound) Workstation.PlaySound(WuhanSound.Error);
        _feedback.Hide();
        bool essential = _controller?.State is not (DayState.Running or DayState.Closing) || text.StartsWith("停止接新客");
        _sceneFeedback.Report(text, error, essential ? GetGlobalTransform() * new Vector2(960, 490) : GetGlobalMousePosition(), essential || text.StartsWith("停止接新客"));
    }

    private void OnStateChanged(DayState state)
    {
        if (state == DayState.Running)
        {
            Feedback("开始营业！做好餐品后，直接拖给对应顾客。", false);
            if (_controller.CurrentConfig?.CityId == StableIds.Cities.Wuhan
                && !GetNode<EquipmentUpgradeCelebration>("UpgradeCelebration").Begin(_save, _controller, out string error))
                Feedback(error, true);
        }
        else if (state == DayState.Closing) Feedback("停止接新客，最后 15 秒完成手中订单。", false);
    }
    public override void _ExitTree()
    {
        _controller?.SetPauseReason("wuhan-hud", false);
        ClearPendantOnExit();
        CollectionFeedback.Clear();
        Workstation.CancelAnimations();
        if(_controller is null)return;
        _controller.StateChanged-=OnStateChanged;_controller.DayFinished-=OnFinished;
    }
    private void OnFinished(DayResult result)
    {
        if (_committed || _controller.TutorialActive || _controller.CurrentConfig?.CityId != StableIds.Cities.Wuhan) return;
        _committed = true; CloseBusinessDetails(); ClearPaymentFeedback(); Workstation.CancelAnimations();
        var model = BusinessBookModel.From(StableIds.Cities.Wuhan, result, _controller.BusinessRecords, _catalog);
        _blocker.Hide(); _results.Hide();
        _demoPendingResult = model; RetryWuhanDemoSettlement();
    }
}
