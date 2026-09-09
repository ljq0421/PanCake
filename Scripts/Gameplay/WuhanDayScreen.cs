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
    private readonly Control[] _customers = new Control[4];
    private readonly DropZone[] _customerDropZones = new DropZone[4];
    private readonly string?[] _deliveryCustomerIds = new string?[4];
    internal DragService DeliveryDrag { get; private set; } = null!;
    private readonly OrderBubbleView[] _orders = new OrderBubbleView[4];
    private readonly ProgressBar[] _patience = new ProgressBar[4];
    private readonly CustomerPortraitView[] _portraits = new CustomerPortraitView[4];
    private readonly Label[] _deliveryQuantityLabels = new Label[4];
    private readonly Label[] _basketLabels = new Label[2];
    private readonly Dictionary<string,double> _refills = new(StringComparer.Ordinal);
    private DataCatalog _catalog = null!; private SaveService _save = null!; private DayController _controller = null!; private WuhanArtCatalog _art = null!;
    private NoodleCookerStateMachine _cooker = null!; private HotDryNoodlesStateMachine _bowl = null!; private DoupiStateMachine? _doupi;
    private DoupiInventory _doupiStock = null!; private WuhanIngredientInventory _ingredients = null!; private EggRiceWineRuntime? _egg;
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
    internal EggRiceWineRuntime? Egg => _egg;
    internal WuhanIngredientInventory Ingredients => _ingredients;
    private PanelContainer _results = null!; private ColorRect _blocker = null!; private RichTextLabel _resultText = null!; private Label _unlock = null!;
    private ConfirmationDialog _abandon = null!; private bool _committed; private bool _focused = true; private double _feedbackSeconds;
    private bool CanInteract => _focused && IsVisibleInTree() && !_committed && !_abandon.Visible
        && _controller is not null && !_controller.IsPaused && _controller.State is DayState.Running or DayState.Closing;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
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
        Workstation.EggPressed += EggAction;
        Workstation.MixMoved += distance => { if (CanInteract && !Workstation.Busy("bowl")) _bowl.AddMixDistance(distance); };
        Workstation.RefillRequested += RefillIngredient;
        Workstation.EggRefillRequested += () =>
        {
            if (CanInteract && !Workstation.Busy("egg") && _egg?.TryRefill() == true) Workstation.PlayEgg(true);
        };
        Workstation.GestureRejected += message => Feedback(message, true);
        this.FindButton("提前打烊").Pressed += () => { Workstation.CancelInput(); _abandon.PopupCentered(); };
        this.FindButton("收好收入 · 返回武汉经营首页").Pressed += () => HubRequested?.Invoke();
        _abandon.Confirmed += () => { Workstation.CancelAnimations(); _controller.AbandonDay(); HubRequested?.Invoke(); };
        VisibilityChanged += () =>
        {
            if (!IsVisibleInTree()) { Workstation.CancelAnimations(); CollectionFeedback.Clear(); }
        };
    }
    public void ConnectController(DayController controller)
    {
        _controller = controller; controller.StateChanged += OnStateChanged; controller.DayFinished += OnFinished;
        controller.DeliveryCompleted += OnDeliveryCompleted;
    }
    public void Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        Workstation.CancelAnimations(); _refills.Clear();
        CollectionFeedback.Clear(); CoinTray.RenderRevenue(0);
        _catalog=catalog; _save=save; _controller=controller; _committed=false; _results.Visible=false; _blocker.Visible=false;
        if (!controller.TryPrepareDay(StableIds.Cities.Wuhan,day,catalog,out string error) || !save.ApplyStartUnlocks(controller.CurrentConfig!,out error)) { Feedback(error,true); return; }
        CityProgressData city=save.Data.Wuhan; _cookerLevel=city.EquipmentLevels.GetValueOrDefault("noodle_cooker",1); _stationLevel=city.EquipmentLevels.GetValueOrDefault("ingredient_station",1); _doupiLevel=city.EquipmentLevels.GetValueOrDefault("doupi_griddle");
        _cooker=new NoodleCookerStateMachine(catalog.NoodleCookersByLevel[_cookerLevel]); _bowl=new HotDryNoodlesStateMachine(); _ingredients=new WuhanIngredientInventory(catalog.WuhanIngredientStationsByLevel[_stationLevel]); _doupiStock=new DoupiInventory();
        _doupi=_doupiLevel>0?new DoupiStateMachine(catalog.DoupiGriddlesByLevel[_doupiLevel]):null; _egg=city.EquipmentLevels.GetValueOrDefault("egg_rice_wine_station")>0?new EggRiceWineRuntime():null;
        _basketLabels[1].Visible=_cooker.Baskets.Count>1;
        Workstation.Bind(_art,_cooker,_bowl,_doupi,_doupiStock,_egg,_ingredients,_cookerLevel,_doupiLevel);
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
        _cooker?.Tick(delta); _doupi?.Tick(delta); _egg?.Tick(delta);
        foreach (string id in _refills.Keys.ToArray()) { _refills[id]-=delta; if (_refills[id]<=0) { _ingredients.Refill(id); _refills.Remove(id); Feedback("备料已补满。",false); } }
        Workstation.Tick(delta); AdvanceAutomaticTransfers(); Render();
    }
    public override void _Notification(int what)
    {
        if (what==NotificationApplicationFocusOut) { _focused=false; Workstation?.CancelInput(); }
        if (what==NotificationApplicationFocusIn) _focused=true;
    }
    private void RefillIngredient(string id) {
        if(!CanInteract || Workstation.Busy("refill:"+id) || _refills.ContainsKey(id))return;
        if(_ingredients.Count(id)>=_catalog.WuhanIngredientStationsByLevel[_stationLevel].GetCapacity(id))return;
        StartRefill(id);Feedback("开始补料，约 1 秒后补满。",false);
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
            int moved = _doupi.TransferAvailable(_doupiStock);
            if (moved > 0) Workstation.PlayStock(moved, start);
        }
    }

    internal void BasketAction(int index)
    {
        if(!CanInteract||index<0||index>=_cooker.Baskets.Count||Workstation.Busy($"basket{index}"))return;
        NoodleBasketRuntime item=_cooker.Baskets[index]; bool ok=false; string message="";
        NoodleBasketState before=item.State;NoodleQuality quality=item.Quality;
        if(item.State==NoodleBasketState.Empty){if(_ingredients.TryConsume(StableIds.Ingredients.WuhanNoodles)){ok=_cooker.TryStart(index);message="面条下锅。";}else message="面条用完了，请点旁边的补货。";}
        else if(item.State is NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked){ok=_cooker.TryRaise(index);message="提篮，开始沥水。";}
        else if(item.State is NoodleBasketState.Raised or NoodleBasketState.Draining){message="自然沥水中，可拖到空碗上方等待。";}
        else if(item.State==NoodleBasketState.Drained){if(!Workstation.Busy("bowl")&&_cooker.TryTransferTo(index,_bowl)){ok=true;message="熟面倒入碗中。";}else message="拌面碗还没有空出来。";}
        else message="面还在烫，等到最佳窗口再提篮。";
        if(ok)Workstation.PlayBasket(index,before,quality);
        Feedback(message,!ok);Render();
    }
    internal void IngredientAction(string id)
    {
        if(!CanInteract||Workstation.Busy("bowl")||Workstation.Busy("refill:"+id))return;
        if(_ingredients.Count(id)<=0){Feedback("配料用完了，点旁边的补货。",true);return;}
        bool ok=id==StableIds.Ingredients.WuhanBaseSeasoning?_bowl.TryAddBaseSeasoning():_bowl.TryAddTopping(id);
        if(ok){_ingredients.TryConsume(id);Workstation.PlayIngredient(id);Feedback("配料已经加入。",false);}else Feedback("先把熟面和基础调味放进碗里。",true);Render();
    }
    private void StartRefill(string id){if(!_refills.ContainsKey(id)){_refills[id]=1.0;Workstation.PlayRefill(id);}}
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
                case ProductKind.EggRiceWine:
                    item = new DeliveredItem(kind, StableIds.Products.EggRiceWine);
                    consume = () => _egg?.TryTake() == true;
                    break;
                default: return false;
            }
            result = _controller.TryDeliverWuhanTo(customerId, item, consume);
        }
        if (result.CompletesOrder && result.TotalRevenue > 0 && !_committed)
        {
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
    internal void EggAction()
    {
        if(!CanInteract||Workstation.Busy("egg"))return;
        if(_egg is null){Feedback("蛋酒台将在 Day 6 解锁。",true);return;}
        if(_egg.HasFinishedCup){Feedback("按住成品杯拖给顾客。",false);return;}
        if(_egg.BaseCups==0){Feedback("底料用完了，请点旁边的补货。",true);return;}
        bool started=_egg.TryStart();if(started)Workstation.PlayEgg(false);Feedback(started?"正在冲蛋酒，0.6 秒后拖动成品杯交付。":"蛋酒台正在工作。",!started);Render();
    }
    internal void RefreshForCapture() => Render();
    private void Render()
    {
        CoinTray.RenderRevenue(_controller?.Ledger?.Build().TotalRevenue ?? 0);
        if(_controller?.CurrentConfig is null||_cooker is null)return;_day.Text=$"武汉 Day {_controller.CurrentConfig.Day} · {Subtitle(_controller.CurrentConfig.Day)}";_clock.Text=_controller.State switch{DayState.Opening=>$"开门 {_controller.OpeningRemainingSeconds:0.0}",DayState.Closing=>$"收尾 {_controller.ClosingRemainingSeconds:0.0}",_=>$"剩余 {(int)_controller.DayRemainingSeconds/60:00}:{(int)_controller.DayRemainingSeconds%60:00}"};_income.Text=$"¥{_controller.Ledger?.Build().TotalRevenue??0}";_door.Text=$"候场 {_controller.CustomerQueue?.DoorQueue.Count??0}";_tutorial.Text=Tutorial(_controller.CurrentConfig.Day);
        for(int i=0;i<_cooker.Baskets.Count;i++) {
            NoodleBasketRuntime b=_cooker.Baskets[i];
            _basketLabels[i].Text=$"漏勺 {i+1} · "+(b.State switch {
                NoodleBasketState.Empty=>"拖面入锅",NoodleBasketState.Cooking=>$"烫制 {b.CookSeconds:0.0}s",
                NoodleBasketState.Ready=>"最佳，向上提",NoodleBasketState.Soft=>"偏软，向上提",
                NoodleBasketState.Overcooked=>"过熟，向上提",NoodleBasketState.Locked=>"锁熟，向上提",
                NoodleBasketState.Raised or NoodleBasketState.Draining=>_cooker.PendingPourBasket==i?"碗上方沥水中":"沥水，可拖入碗",_=>"沥干，拖入碗"});
        }
        _bowlStatus.Text=_bowl.State switch {
            NoodleBowlState.Empty=>_cooker.PendingPourBasket.HasValue?"漏勺沥水中 · 稍后自动倒面":"热干面 · 等待熟面入碗",
            NoodleBowlState.Noodles=>"点击酱罐加入基础调味",
            NoodleBowlState.Ready=>"热干面已拌好 · 拖给顾客",
            _=>$"点击小料 · 在碗中划动拌匀 {_bowl.MixProgress:0}%"};
        _doupiStatus.Text=_doupi is null?"豆皮 · Day 4 解锁":_doupi.State switch {
            DoupiState.Empty=>"豆皮 · 点击浆碗浇浆",DoupiState.Batter=>"点击锅面加蛋",
            DoupiState.ReadyToFlip=>"向上划动锅面翻面",DoupiState.Flipped=>"点击馅碗铺馅",
            DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting=>$"{(_doupi.CutDirections.Contains(DoupiCutDirection.Horizontal)?"横切完成":"请横划") } · {(_doupi.CutDirections.Contains(DoupiCutDirection.Vertical)?"竖切完成":"请竖划")} · {(_doupi.Quality==DoupiQuality.Overbrowned?"偏焦":_doupi.State==DoupiState.Cutting?"已离火":"已熟")}",
            DoupiState.Cut=>$"锅内余 {_doupi.RemainingPieces} 块 · 腾位后自动补入",DoupiState.Burnt=>"已焦糊 · 点击锅面清理",_=>"豆皮煎制中"};
        _eggStatus.Text=_egg is null?"蛋酒 · Day 6 解锁":_egg.HasFinishedCup?"蛋酒已冲好 · 拖给顾客":_egg.IsPreparing?$"冲泡 {_egg.RemainingSeconds:0.0}s":_egg.IsRefilling?"正在补充底料":"点击底料杯冲泡 · 成品拖给顾客";
        Workstation.RefreshRefillControls();
        Workstation.RefreshDeliverySources(); Workstation.QueueRedraw();
        RenderCustomers();
    }
    private void RenderCustomers()
    {
        if (_controller.CustomerQueue is null) return;
        var slots = _controller.CustomerQueue.Slots;
        for (int i=0;i<4;i++)
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
            _patience[i].Value=(1-customer.PatienceProgress)*100;
            _portraits[i].SetVisual(_art.Shared.CustomerPortrait(customer.AppearanceId,TianjinArtCatalog.ResolveCustomerExpression(customer.State,customer.WasServed)));
        }
    }
    private void Feedback(string text,bool error){_feedback.Text=(error?"！ ":"✓ ")+text;_feedback.Modulate=Colors.White;_feedback.AddThemeColorOverride("font_color",error?new Color("#9A3528"):WuhanUi.Ink);_feedback.Visible=true;_feedbackSeconds=2.4;}
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
        if(_committed||_controller.CurrentConfig?.CityId!=StableIds.Cities.Wuhan)return;_committed=true;Workstation.CancelAnimations();try{DayCommitResult commit=_save.CommitDay(result,_controller.CurrentPlan!,_controller.CurrentConfig!);string stars=result.Day==12?$"\n武汉评级 {new string('★',commit.EarnedStars)}{new string('☆',3-commit.EarnedStars)}":"";_resultText.Text=$"[center][font_size=28]武汉 Day {result.Day} 打烊[/font_size]\n\n[font_size=42]今日总收入 ¥{result.TotalRevenue}[/font_size]\n永久金币增加 ¥{commit.PermanentCoinGain}\n\n完成 {result.CompletedCustomers} 位 · 流失 {result.LostCustomers} 位\n满意度 {result.Satisfaction:0}% · Perfect {result.PerfectOrders} 单{stars}[/center]";_unlock.Text=commit.NewChapterCompletion?"武汉 · 过早之城已经点亮！获得三件早餐收藏与章节徽章。西安章节已开放。":_controller.CurrentConfig.CompletionUnlocks.Count>0?"新的武汉设备升级已经开放。":"成绩已写入武汉经营手账。";}catch(IOException e){_resultText.Text=$"保存失败：{e.Message}";_unlock.Text="本次结果已回退。";}_blocker.Visible=true;_results.Visible=true;
    }
    private static string Subtitle(int day)=>day switch{1=>"初到武汉",4=>"豆皮开锅",6=>"蛋酒",7=>"牛肉与上班族",8=>"完整早餐",9=>"带走大单",12=>"最终挑战",_=>"过早高峰"};
    private static string Tutorial(int day)=>day switch{1=>"拖面入锅 → 提篮连续拖到空碗，自动沥水 → 点击调味 → 划动拌匀 → 拖给顾客",4=>"豆皮一次做 8 块：点浆碗、加蛋、上划翻面、点馅碗、横竖各划一次，自动入盘",6=>"点击底料杯，冲泡后拖给顾客；豆皮一次拖拽按顾客所需数量交付",7=>"上班族耐心只有 34 秒，牛肉配方已经加入",8=>"熟客和游客加入：短耐心不一定是最高价值订单",_=>string.Empty};
}
