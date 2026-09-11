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
    private DoupiInventory _doupiStock = null!; private WuhanIngredientInventory _ingredients = null!; private bool _eggUnlocked;
    private int _stationLevel; private int _cookerLevel; private int _doupiLevel;
    private Label _day = null!, _clock = null!, _income = null!, _door = null!, _feedback = null!, _bowlStatus = null!, _doupiStatus = null!, _eggStatus = null!, _tutorial = null!;
    internal WuhanWorkstationView Workstation { get; private set; } = null!;
    internal CoinTrayView CoinTray { get; private set; } = null!;
    internal CoinCollectionFeedback CollectionFeedback { get; private set; } = null!;
    private TextureRect _coinTarget = null!;
    internal NoodleCookerStateMachine Cooker => _cooker;
    internal HotDryNoodlesStateMachine Bowl => _bowl;
    internal DoupiStateMachine? Doupi => _doupi;
    internal DoupiInventory DoupiStock => _doupiStock;
    internal bool EggUnlocked => _eggUnlocked;
    internal WuhanIngredientInventory Ingredients => _ingredients;
    private PanelContainer _results = null!; private ColorRect _blocker = null!; private RichTextLabel _resultText = null!; private Label _unlock = null!;
    private ConfirmationDialog _abandon = null!; private bool _committed; private bool _focused = true; private double _feedbackSeconds;
    private bool CanInteract => _focused && IsVisibleInTree() && !_committed && !_abandon.Visible
        && _controller is not null && !_controller.IsPaused && _controller.State is DayState.Running or DayState.Closing;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        ConfigurePresentation();
        _art = new WuhanArtCatalog();
        DeliveryDrag.Configure(GetNode<Control>("WuhanDragOverlay"));
        DeliveryDrag.DragEnded += result =>
        {
            if (result.Completion is DragCompletion.Missed or DragCompletion.Rejected)
                Feedback("请拖给仍需要这份餐品的顾客。", true);
        };
        for (int i = 0; i < _customerDropZones.Length; i++)
        {
            DeliveryDrag.RegisterZone(_customerDropZones[i]);
            _orders[i].Configure(_art.Shared, _art);
        }
        Workstation.CanInteract = () => CanInteract;
        Workstation.ConfigureDelivery(DeliveryDrag);
        CollectionFeedback.Bind(CoinTray, this, _coinTarget, _art.Shared.Coin, () => CanInteract);
        CoinTray.CanCollect = () => CanInteract && !DeliveryDrag.IsDragging && !Workstation.HasProductionGesture;
        Workstation.RaiseRequested = RaiseBasket;
        Workstation.PourRequested = ReservePour;
        Workstation.CutRequested = CutDoupi;
        Workstation.BasketPressed += BasketAction;
        Workstation.IngredientPressed += IngredientAction;
        Workstation.DoupiPressed += DoupiAction;
        Workstation.MixMoved += distance => { if (CanInteract && !Workstation.Busy("bowl")) _bowl.AddMixDistance(distance); };
        Workstation.GestureRejected += message => Feedback(message, true);
        GetNode<Button>("@PanelContainer@312/@HBoxContainer@313/@Button@319").Pressed += () => { Workstation.CancelInput(); _abandon.PopupCentered(); };
        this.FindButton("收好收入 · 返回武汉经营首页").Pressed += () => HubRequested?.Invoke();
        _abandon.Confirmed += () => { Workstation.CancelAnimations(); _controller.AbandonDay(); HubRequested?.Invoke(); };
        VisibilityChanged += () =>
        {
            if (!IsVisibleInTree()) { Workstation.CancelAnimations(); CollectionFeedback.Clear(); }
        };
    }
    private void ConfigurePresentation()
    {
        // Orders must never determine the scale or counter crop of a customer.
        for (int i = 0; i < _customers.Length; i++)
        {
            _portraits[i].Reparent(_customers[i], false);
            _portraits[i].Position = new Vector2(5, 162);
            _portraits[i].Size = new Vector2(340, 268);
            _orders[i].Reparent(_customers[i], false);
            _orders[i].Position = new Vector2(29, 5);
            _orders[i].Scale = Vector2.One * .88f;
            _patience[i].CustomMinimumSize = new Vector2(0, 6);
            foreach (string style in new[] { "background", "fill" })
            {
                var box = (StyleBoxFlat)_patience[i].GetThemeStylebox(style).Duplicate();
                box.SetBorderWidthAll(0);
                _patience[i].AddThemeStyleboxOverride(style, box);
            }
        }
        _door.Visible = false;
        _tutorial.Visible = false;
        foreach (Label label in _basketLabels) label.Visible = false;
        _bowlStatus.Visible = _doupiStatus.Visible = _eggStatus.Visible = false;
        var header = GetNode<PanelContainer>("@PanelContainer@312");
        var headerStyle = (StyleBoxFlat)header.GetThemeStylebox("panel").Duplicate();
        headerStyle.ContentMarginTop = headerStyle.ContentMarginBottom = 6;
        header.AddThemeStyleboxOverride("panel", headerStyle);
        header.Position = new Vector2(1236, 18);
        header.Size = new Vector2(660, 60);
        var row = (HBoxContainer)_day.GetParent();
        void IconBefore(Control target, string kind)
        {
            var icon = new WuhanHudIcon { Kind = kind, CustomMinimumSize = new Vector2(30, 30), SizeFlagsVertical = SizeFlags.ShrinkCenter, MouseFilter = MouseFilterEnum.Ignore };
            row.AddChild(icon); row.MoveChild(icon, target.GetIndex());
        }
        IconBefore(_day, "day"); IconBefore(_clock, "clock");
        _day.AddThemeFontSizeOverride("font_size", 24);
        _coinTarget.CustomMinimumSize = new Vector2(32, 32);
        var close = this.FindButton("提前打烊");
        close.Text = ""; close.TooltipText = "提前打烊";
        close.CustomMinimumSize = new Vector2(48, 48);
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled", "focus" })
        {
            var style = (StyleBoxFlat)close.GetThemeStylebox(state).Duplicate();
            style.ContentMarginLeft = style.ContentMarginRight = style.ContentMarginTop = style.ContentMarginBottom = 0;
            close.AddThemeStyleboxOverride(state, style);
        }
        var exit = new WuhanHudIcon { Kind = "exit", Position = new Vector2(9, 9), Size = new Vector2(30, 30), MouseFilter = MouseFilterEnum.Ignore };
        close.AddChild(exit);
        CoinTray.AmountOnly = true;
        CoinTray.Position = WuhanWorkbenchLayout.CoinUi.Position;
        CoinTray.Size = WuhanWorkbenchLayout.CoinUi.Size;
        CoinTray.Scale = Vector2.One;
        CoinTray.PivotOffset = CoinTray.Size * .5f;
        CoinTray.ConfigureButtonPresentation();
    }
    public void ConnectController(DayController controller)
    {
        _controller = controller; controller.StateChanged += OnStateChanged; controller.DayFinished += OnFinished;
        controller.DeliveryCompleted += OnDeliveryCompleted;
    }
    public void Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        Workstation.CancelAnimations();
        CollectionFeedback.Clear(); CoinTray.RenderRevenue(0);
        _catalog=catalog; _save=save; _controller=controller; _committed=false; _results.Visible=false; _blocker.Visible=false;
        if (!controller.TryPrepareDay(StableIds.Cities.Wuhan,day,catalog,out string error) || !save.ApplyStartUnlocks(controller.CurrentConfig!,out error)) { Feedback(error,true); return; }
        CityProgressData city=save.Data.Wuhan; _cookerLevel=city.EquipmentLevels.GetValueOrDefault("noodle_cooker",1); _stationLevel=city.EquipmentLevels.GetValueOrDefault("ingredient_station",1); _doupiLevel=city.EquipmentLevels.GetValueOrDefault("doupi_griddle");
        _cooker=new NoodleCookerStateMachine(catalog.NoodleCookersByLevel[_cookerLevel]); _bowl=new HotDryNoodlesStateMachine(); _ingredients=new WuhanIngredientInventory(catalog.WuhanIngredientStationsByLevel[_stationLevel]); _doupiStock=new DoupiInventory();
        _doupi=_doupiLevel>0?new DoupiStateMachine(catalog.DoupiGriddlesByLevel[_doupiLevel]):null; _eggUnlocked=false;
        GetNode<TextureRect>("WorkbenchBackground").Texture = _art.WorkbenchBackground(_doupi is not null);
        _basketLabels[1].Visible=false;
        Workstation.Bind(_art,_cooker,_bowl,_doupi,_doupiStock,_eggUnlocked,_ingredients,_cookerLevel,_doupiLevel);
        Render();
    }
    public void BeginDay() { if (!_controller.TryStartDay(out string error)) Feedback(error,true); else Feedback("铺门打开，准备迎接第一位客人。",false); }

    public override void _Process(double delta)
    {
        if (!CanInteract) Workstation.CancelInput();
        if (_feedbackSeconds>0 && (_feedbackSeconds-=delta)<=0) _feedback.Visible=false;
        if (!_focused || !IsVisibleInTree() || _controller?.CurrentConfig is null || _controller.IsPaused || _abandon.Visible) { Workstation.EndMix(); return; }
        _controller.Tick(delta);
        if (!CanInteract) { Render(); return; }
        _cooker?.Tick(delta); _doupi?.Tick(delta);
        Workstation.Tick(delta); AdvanceAutomaticTransfers(); Render();
    }
    public override void _Notification(int what)
    {
        if (what==NotificationApplicationFocusOut) { _focused=false; Workstation?.CancelInput(); }
        if (what==NotificationApplicationFocusIn) _focused=true;
    }
    internal bool RaiseBasket(int index)
    {
        if (!CanInteract || Workstation.Busy($"basket{index}")) return false;
        bool raised = _cooker.TryRaise(index);
        if (raised) Workstation.RememberProductionState();
        return raised;
    }
    internal bool ReservePour(int index)
    {
        if (!CanInteract || Workstation.Busy("bowl") || !_cooker.TryReservePour(index, _bowl)) return false;
        AdvanceAutomaticTransfers(); Render(); return true;
    }
    internal bool CutDoupi(DoupiCutDirection direction)
    {
        if (!CanInteract || Workstation.Busy("pan") || _doupi?.TryCut(direction) != true) return false;
        Workstation.PlayCut(direction); Feedback(_doupi.State == DoupiState.Cut ? "切块完成，将自动补入备餐盘。" : "已离火，品质锁定；再划另一个方向。", false); Render(); return true;
    }
    private void AdvanceAutomaticTransfers()
    {
        if (!CanInteract) return;
        if (!Workstation.Busy("bowl") && _cooker.TryCompletePendingPour(out int basket, out NoodleQuality quality))
            Workstation.PlayBasket(basket, NoodleBasketState.Drained, quality, Workstation.PourPosition);
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
        if(ok)Workstation.PlayBasket(index,before,quality);
        Feedback(message,!ok);Render();
    }
    internal void IngredientAction(string id)
    {
        if(!CanInteract||Workstation.Busy("bowl")||!_ingredients.IsUnlimited(id))return;
        bool ok=id==StableIds.Ingredients.WuhanBaseSeasoning?_bowl.TryAddBaseSeasoning():_bowl.TryAddTopping(id);
        if(ok){_ingredients.TryConsume(id);Workstation.PlayIngredient(id);Feedback("配料已经加入。",false);}else Feedback("先把熟面和基础调味放进碗里。",true);Render();
    }
    internal bool DeliverToCustomer(string customerId, ProductKind kind)
    {
        if (!CanInteract || !Workstation.CanDeliver(kind)) return false;
        DeliveryEvaluation result;
        if (kind == ProductKind.Doupi) result = _controller.TryDeliverWuhanDoupiTo(customerId, _doupiStock);
        else
        {
            DeliveredItem item;
            Func<bool> consume;
            switch (kind)
            {
                case ProductKind.HotDryNoodles:
                    if (!_bowl.TryPrepare(_catalog.RecipesById, out PreparedHotDryNoodles prepared)) return false;
                    item = new DeliveredItem(kind, prepared.RecipeId, null, null, null, HotDryNoodlesStateMachine.ToQuality(prepared));
                    consume = () => { _bowl.Reset(); return true; };
                    break;
                default: return false;
            }
            result = _controller.TryDeliverWuhanTo(customerId, item, consume);
        }
        if (result.CompletesOrder && result.TotalRevenue > 0 && !_committed)
        {
            CoinTray.RenderRevenue(_controller.Ledger!.Build().TotalRevenue, _controller.Ledger.PaidCustomers);
            int slot = Array.IndexOf(_deliveryCustomerIds, customerId);
            if (slot >= 0) CollectionFeedback.PaymentFrom(_portraits[slot].GetGlobalRect().GetCenter());
        }
        Feedback(result.Message, result.Grade is DeliveryGrade.Rejected or DeliveryGrade.Incorrect);
        Render();
        return result.ItemAccepted || result.CompletesOrder;
    }

    internal void DoupiAction()
    {
        if(!CanInteract||Workstation.Busy("pan"))return;
        if(_doupi?.State==DoupiState.Cut&&Workstation.Busy("stock"))return;
        DoupiState before=_doupi?.State??DoupiState.Empty;
        if(_doupi is null){Feedback("豆皮锅将在 Day 4 解锁。",true);return;} bool ok=_doupi.State switch{DoupiState.Empty=>_doupi.TryPourBatter(),DoupiState.Batter=>_doupi.TryAddEgg(),DoupiState.ReadyToFlip=>_doupi.TryFlip(),DoupiState.Flipped=>_doupi.TryAddFilling(),DoupiState.Burnt=>DiscardDoupi(),_=>false};
        if(ok)Workstation.PlayDoupi(before);
        Feedback(ok?"豆皮操作完成一步。":before==DoupiState.Cut?"备餐盘已满，豆皮保留在锅中。":"豆皮正在煎制，请观察状态。",!ok);Render();
    }
    private bool DiscardDoupi(){_doupi!.Discard();return true;}
    internal void RefreshForCapture() => Render();
    private void Render()
    {
        CoinTray.RenderRevenue(_controller?.Ledger?.Build().TotalRevenue ?? 0, _controller?.Ledger?.PaidCustomers ?? 0);
        if (_controller?.CurrentConfig is null || _cooker is null) return;
        int day = _controller.CurrentConfig.Day;
        _day.Text = $"{day}";
        _day.TooltipText = $"武汉 Day {day} · {Subtitle(day)}\n{Tutorial(day)}";
        _clock.Text = _controller.State switch
        {
            DayState.Opening => $"开门 {_controller.OpeningRemainingSeconds:0}",
            DayState.Closing => $"收尾 {_controller.ClosingRemainingSeconds:0}",
            _ => $"{(int)_controller.DayRemainingSeconds / 60:00}:{(int)_controller.DayRemainingSeconds % 60:00}",
        };
        _clock.TooltipText = $"候场 {_controller.CustomerQueue?.DoorQueue.Count ?? 0}";
        _income.Text = $"{_controller.Ledger?.Build().TotalRevenue ?? 0}";
        _tutorial.Text = $"武汉 Day {day} · {Subtitle(day)}\n{Tutorial(day)}";
        _tutorial.Visible = _controller.State == DayState.Opening;
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
        var slots = _controller.CustomerQueue.Slots;
        for (int i=0;i<_customers.Length;i++)
        {
            CustomerRuntime? customer=i<slots.Count?slots[i]:null;
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
            if (customer is null) continue;
            _orders[i].Render(customer.Order,customer.Progress,_catalog.RecipesById);
            _orders[i].Size = new Vector2(332, _orders[i].GetCombinedMinimumSize().Y);
            _patience[i].Value=(1-customer.PatienceProgress)*100;
            double remaining = 1 - customer.PatienceProgress;
            ((StyleBoxFlat)_patience[i].GetThemeStylebox("fill")).BgColor = remaining < .2
                ? new Color("#B95035") : remaining < .4 ? new Color("#C69536") : new Color("#9AB88A");
            _patience[i].Modulate = new Color(1, 1, 1, remaining > .85 ? .4f : 1);
            _portraits[i].SetVisual(_art.Shared.CustomerPortrait(customer.AppearanceId,TianjinArtCatalog.ResolveCustomerExpression(customer.State,customer.WasServed)));
        }
    }
    private void Feedback(string text,bool error){if (!error && _controller?.State is not (DayState.Opening or DayState.Closing)) return;_feedback.Text=(error?"！ ":"✓ ")+text;_feedback.Modulate=Colors.White;_feedback.AddThemeColorOverride("font_color",error?new Color("#9A3528"):WuhanUi.Ink);_feedback.Visible=true;_feedbackSeconds=2.4;}
    private void OnStateChanged(DayState state){if(state==DayState.Running)Feedback("开始营业！做好餐品后，直接拖给对应顾客。",false);else if(state==DayState.Closing)Feedback("停止接新客，最后 15 秒完成手中订单。",false);}
    private void OnDeliveryCompleted(DeliveryEvaluation result)=>Feedback(result.Message,result.Grade is DeliveryGrade.Incorrect or DeliveryGrade.Rejected);
    public override void _ExitTree()
    {
        CollectionFeedback.Clear();
        Workstation.CancelAnimations();
        if(_controller is null)return;
        _controller.StateChanged-=OnStateChanged;_controller.DayFinished-=OnFinished;_controller.DeliveryCompleted-=OnDeliveryCompleted;
    }
    private void OnFinished(DayResult result)
    {
        CollectionFeedback.Clear();
        if(_committed||_controller.CurrentConfig?.CityId!=StableIds.Cities.Wuhan)return;_committed=true;Workstation.CancelAnimations();try{DayCommitResult commit=_save.CommitDay(result,_controller.CurrentPlan!,_controller.CurrentConfig!);string stars=result.Day==12?$"\n武汉评级 {new string('★',commit.EarnedStars)}{new string('☆',3-commit.EarnedStars)}":"";_resultText.Text=$"[center][font_size=28]武汉 Day {result.Day} 打烊[/font_size]\n\n[font_size=42]今日总收入 ¥{result.TotalRevenue}[/font_size]\n永久金币增加 ¥{commit.PermanentCoinGain}\n\n完成 {result.CompletedCustomers} 位 · 流失 {result.LostCustomers} 位\n满意度 {result.Satisfaction:0}% · Perfect {result.PerfectOrders} 单{stars}[/center]";_unlock.Text=commit.NewChapterCompletion?"武汉 · 过早之城已经点亮！获得两件早餐收藏与章节徽章。西安章节已开放。":_controller.CurrentConfig.CompletionUnlocks.Count>0?"新的武汉设备升级已经开放。":"成绩已写入武汉经营手账。";}catch(IOException e){_resultText.Text=$"保存失败：{e.Message}";_unlock.Text="本次结果已回退。";}_blocker.Visible=true;_results.Visible=true;
    }
    private static string Subtitle(int day)=>day switch{1=>"初到武汉",4=>"豆皮开锅",6=>"双线熟练",7=>"牛肉与上班族",8=>"完整早餐",9=>"带走大单",12=>"最终挑战",_=>"过早高峰"};
    private static string Tutorial(int day)=>day switch{1=>"拖面入锅 → 提篮连续拖到空碗，自动沥水 → 点击调味 → 划动拌匀 → 拖给顾客",4=>"豆皮一次做 8 块：点浆碗、加蛋、上划翻面、点馅碗、横竖各划一次，自动入盘",6=>"热干面与豆皮搭配出餐；豆皮一次拖拽按顾客所需数量交付",7=>"上班族耐心只有 34 秒，牛肉配方已经加入",8=>"熟客和游客加入：短耐心不一定是最高价值订单",_=>string.Empty};
}
