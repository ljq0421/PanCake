using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Gameplay;

public partial class WuhanDayScreen : Control
{
    public event Action? HubRequested;
    private readonly Button[] _customers = new Button[4];
    private readonly Label[] _orders = new Label[4];
    private readonly ProgressBar[] _patience = new ProgressBar[4];
    private readonly CustomerPortraitView[] _portraits = new CustomerPortraitView[4];
    private readonly Label[] _basketLabels = new Label[2];
    private readonly Button[] _basketButtons = new Button[2];
    private readonly Dictionary<string,double> _refills = new(StringComparer.Ordinal);
    private DataCatalog _catalog = null!; private SaveService _save = null!; private DayController _controller = null!; private WuhanArtCatalog _art = null!;
    private NoodleCookerStateMachine _cooker = null!; private HotDryNoodlesStateMachine _bowl = null!; private DoupiStateMachine? _doupi;
    private DoupiInventory _doupiStock = null!; private WuhanIngredientInventory _ingredients = null!; private EggRiceWineRuntime? _egg;
    private int _stationLevel; private int _cookerLevel; private int _doupiLevel;
    private Label _day = null!, _clock = null!, _income = null!, _door = null!, _feedback = null!, _bowlStatus = null!, _doupiStatus = null!, _eggStatus = null!, _tutorial = null!;
    private Button _doupiButton = null!, _eggButton = null!, _deliverNoodles = null!, _deliverDoupi = null!;
    private HBoxContainer _basketRow = null!, _ingredientRow = null!;
    internal WuhanWorkstationView Workstation { get; private set; } = null!;
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

    public override void _Ready() => Build();
    public void ConnectController(DayController controller)
    {
        _controller = controller; controller.StateChanged += OnStateChanged; controller.DayFinished += OnFinished;
        controller.DeliveryCompleted += OnDeliveryCompleted;
    }
    public void Initialize(DataCatalog catalog, SaveService save, DayController controller, int day)
    {
        Workstation.CancelAnimations(); _refills.Clear();
        _catalog=catalog; _save=save; _controller=controller; _committed=false; _results.Visible=false; _blocker.Visible=false;
        if (!controller.TryPrepareDay(StableIds.Cities.Wuhan,day,catalog,out string error) || !save.ApplyStartUnlocks(controller.CurrentConfig!,out error)) { Feedback(error,true); return; }
        CityProgressData city=save.Data.Wuhan; _cookerLevel=city.EquipmentLevels.GetValueOrDefault("noodle_cooker",1); _stationLevel=city.EquipmentLevels.GetValueOrDefault("ingredient_station",1); _doupiLevel=city.EquipmentLevels.GetValueOrDefault("doupi_griddle");
        _cooker=new NoodleCookerStateMachine(catalog.NoodleCookersByLevel[_cookerLevel]); _bowl=new HotDryNoodlesStateMachine(); _ingredients=new WuhanIngredientInventory(catalog.WuhanIngredientStationsByLevel[_stationLevel]); _doupiStock=new DoupiInventory();
        _doupi=_doupiLevel>0?new DoupiStateMachine(catalog.DoupiGriddlesByLevel[_doupiLevel]):null; _egg=city.EquipmentLevels.GetValueOrDefault("egg_rice_wine_station")>0?new EggRiceWineRuntime():null;
        ((Control)_basketButtons[1].GetParent()).Visible=_cooker.Baskets.Count>1;
        Workstation.Bind(_art,_cooker,_bowl,_doupi,_doupiStock,_egg,_ingredients,_cookerLevel,_doupiLevel);
        Render();
    }
    public void BeginDay() { if (!_controller.TryStartDay(out string error)) Feedback(error,true); else Feedback("铺门打开，准备迎接第一位客人。",false); }

    public override void _Process(double delta)
    {
        if (_feedbackSeconds>0 && (_feedbackSeconds-=delta)<=0) _feedback.Visible=false;
        if (!_focused || !IsVisibleInTree() || _controller?.CurrentConfig is null || _controller.IsPaused || _abandon.Visible) { Workstation.EndMix(); return; }
        _controller.Tick(delta);
        if (!CanInteract) { Render(); return; }
        _cooker?.Tick(delta); _doupi?.Tick(delta); _egg?.Tick(delta);
        foreach (string id in _refills.Keys.ToArray()) { _refills[id]-=delta; if (_refills[id]<=0) { _ingredients.Refill(id); _refills.Remove(id); Feedback("备料已补满。",false); } }
        Workstation.Tick(delta); Render();
    }
    public override void _Notification(int what)
    {
        if (what==NotificationApplicationFocusOut) { _focused=false; Workstation?.EndMix(); }
        if (what==NotificationApplicationFocusIn) _focused=true;
    }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); Theme=TianjinUi.CreateTheme(); _art=new WuhanArtCatalog();
        var bg=TianjinUi.Texture(_art.Background,Vector2.Zero,TextureRect.StretchModeEnum.Scale); TianjinUi.FullRect(bg); AddChild(bg);
        BuildHud(); BuildCustomers(); BuildWorkstation(); BuildResults();
        _feedback=TianjinUi.Label("",20,TianjinUi.Green,HorizontalAlignment.Center); _feedback.Position=new Vector2(560,522); _feedback.Size=new Vector2(800,46); _feedback.ZIndex=80; _feedback.Visible=false; _feedback.AddThemeConstantOverride("outline_size",5); _feedback.AddThemeColorOverride("font_outline_color",TianjinUi.Paper); AddChild(_feedback);
        _tutorial=TianjinUi.Label("",18,TianjinUi.BrownDark,HorizontalAlignment.Center); _tutorial.Position=new Vector2(400,92); _tutorial.Size=new Vector2(1120,44); _tutorial.ZIndex=65; _tutorial.AddThemeConstantOverride("outline_size",5); _tutorial.AddThemeColorOverride("font_outline_color",TianjinUi.Paper); AddChild(_tutorial);
        _abandon=new ConfirmationDialog { Title="提前打烊？",DialogText="本日收入和成绩不会保存。",OkButtonText="打烊并返回" }; _abandon.Confirmed+=()=>{Workstation.CancelAnimations();_controller.AbandonDay();HubRequested?.Invoke();}; AddChild(_abandon);
        VisibilityChanged += () => { if (!IsVisibleInTree()) Workstation.CancelAnimations(); };
    }
    private void BuildHud()
    {
        var panel=TianjinUi.Panel(new Color("#FFF4D5"),15); panel.Position=new Vector2(24,18); panel.Size=new Vector2(1872,70); panel.ZIndex=70; AddChild(panel);
        var row=new HBoxContainer(); row.AddThemeConstantOverride("separation",20); panel.AddChild(row); _day=TianjinUi.Label("武汉 Day 1",27,TianjinUi.BrownDark); _day.SizeFlagsHorizontal=SizeFlags.ExpandFill; row.AddChild(_day);
        _door=TianjinUi.Label("候场 0",18,TianjinUi.Brown); row.AddChild(_door); _clock=TianjinUi.Label("00:00",26,TianjinUi.BrownDark); row.AddChild(_clock); row.AddChild(TianjinUi.Texture(_art.Shared.Coin,new Vector2(42,42))); _income=TianjinUi.Label("¥0",25,TianjinUi.Green); row.AddChild(_income);
        var back=TianjinUi.Button("提前打烊",false,new Vector2(145,50)); back.Pressed+=()=>_abandon.PopupCentered(); row.AddChild(back);
    }
    private void BuildCustomers()
    {
        var row=new HBoxContainer { Position=new Vector2(70,135),Size=new Vector2(1780,375),Alignment=BoxContainer.AlignmentMode.Center,ZIndex=25 }; row.AddThemeConstantOverride("separation",20); AddChild(row);
        for(int i=0;i<4;i++)
        {
            int slot=i; var button=new Button { CustomMinimumSize=new Vector2(425,370),Visible=false }; button.Pressed+=()=>Select(slot); button.AddThemeStyleboxOverride("normal",TianjinUi.Box(new Color(1,1,1,.04f),14,0,false)); button.AddThemeStyleboxOverride("hover",TianjinUi.Box(new Color(1,.9f,.45f,.16f),14,3,false)); row.AddChild(button); _customers[i]=button;
            var col=new VBoxContainer(); TianjinUi.FullRect(col,5,5,-5,-5); col.MouseFilter=MouseFilterEnum.Ignore; button.AddChild(col);
            var bubble=TianjinUi.Panel(TianjinUi.Paper,12,3,true); bubble.CustomMinimumSize=new Vector2(0,104); col.AddChild(bubble); _orders[i]=TianjinUi.Label("",16,TianjinUi.BrownDark,HorizontalAlignment.Center); _orders[i].AutowrapMode=TextServer.AutowrapMode.WordSmart; bubble.AddChild(_orders[i]);
            _portraits[i]=new CustomerPortraitView(); _portraits[i].SetVisual(_art.Shared.CustomerPortrait(CustomerAppearanceCatalog.DefaultAppearanceId,CustomerExpression.Normal)); _portraits[i].SizeFlagsVertical=SizeFlags.ExpandFill; col.AddChild(_portraits[i]);
            _patience[i]=new ProgressBar { MaxValue=100,Value=100,ShowPercentage=false,CustomMinimumSize=new Vector2(0,12) }; col.AddChild(_patience[i]);
        }
    }
    private void BuildWorkstation()
    {
        Workstation=new WuhanWorkstationView { Name="WuhanWorkstation",Position=new Vector2(0,555),Size=new Vector2(1920,365),ZIndex=45 };
        AddChild(Workstation); Workstation.CanInteract=()=>CanInteract;
        Workstation.BasketPressed+=BasketAction; Workstation.IngredientPressed+=IngredientAction;
        Workstation.DoupiPressed+=DoupiAction; Workstation.StockPressed+=DeliverDoupi; Workstation.EggPressed+=EggAction;
        Workstation.NoodlesPressed+=DeliverNoodles; Workstation.MixMoved+=distance=>{if(CanInteract&&!Workstation.Busy("bowl"))_bowl.AddMixDistance(distance);};
        var cookerCol=ActionColumn(30,410);_basketRow=new HBoxContainer();_basketRow.AddThemeConstantOverride("separation",6);cookerCol.AddChild(_basketRow);
        for(int i=0;i<2;i++){int slot=i;_basketButtons[i]=TianjinUi.Button($"漏勺 {i+1}",true,new Vector2(0,54));_basketButtons[i].SizeFlagsHorizontal=SizeFlags.ExpandFill;_basketButtons[i].Pressed+=()=>BasketAction(slot);_basketLabels[i]=TianjinUi.Label("空",15,TianjinUi.BrownDark,HorizontalAlignment.Center);var col=new VBoxContainer{SizeFlagsHorizontal=SizeFlags.ExpandFill};col.AddChild(_basketButtons[i]);col.AddChild(_basketLabels[i]);_basketRow.AddChild(col);}
        var bowlCol=ActionColumn(455,520);_bowlStatus=TianjinUi.Label("空碗",16,TianjinUi.BrownDark,HorizontalAlignment.Center);bowlCol.AddChild(_bowlStatus);
        _ingredientRow=new HBoxContainer();_ingredientRow.AddThemeConstantOverride("separation",4);bowlCol.AddChild(_ingredientRow);
        AddIngredient("基础调味",StableIds.Ingredients.WuhanBaseSeasoning);AddIngredient("葱花",StableIds.Ingredients.WuhanScallion);AddIngredient("辣油",StableIds.Ingredients.WuhanChiliOil);AddIngredient("牛肉",StableIds.Ingredients.WuhanBraisedBeef);
        _deliverNoodles=TianjinUi.Button("热干面出餐",true,new Vector2(0,46));_deliverNoodles.Pressed+=DeliverNoodles;bowlCol.AddChild(_deliverNoodles);
        var doupiCol=ActionColumn(990,430);_doupiButton=TianjinUi.Button("浇浆",true,new Vector2(0,46));_doupiButton.Pressed+=DoupiAction;doupiCol.AddChild(_doupiButton);
        _doupiStatus=TianjinUi.Label("Day 4 解锁",16,TianjinUi.BrownDark,HorizontalAlignment.Center);doupiCol.AddChild(_doupiStatus);
        _deliverDoupi=TianjinUi.Button("交付豆皮",false,new Vector2(0,46));_deliverDoupi.Pressed+=DeliverDoupi;doupiCol.AddChild(_deliverDoupi);
        var eggCol=ActionColumn(1435,455);_eggButton=TianjinUi.Button("冲一杯蛋酒",true,new Vector2(0,54));_eggButton.Pressed+=EggAction;eggCol.AddChild(_eggButton);
        _eggStatus=TianjinUi.Label("Day 6 解锁",16,TianjinUi.BrownDark,HorizontalAlignment.Center);eggCol.AddChild(_eggStatus);
    }
    private VBoxContainer ActionColumn(float x,float width){var col=new VBoxContainer{Position=new Vector2(x,920),Size=new Vector2(width,130),ZIndex=46};col.AddThemeConstantOverride("separation",4);AddChild(col);return col;}
    private void AddIngredient(string name,string id){var button=TianjinUi.Button(name,false,new Vector2(0,46));button.SizeFlagsHorizontal=SizeFlags.ExpandFill;button.Pressed+=()=>IngredientAction(id);button.SetMeta("ingredient_id",id);_ingredientRow.AddChild(button);}

    internal void BasketAction(int index)
    {
        if(!CanInteract||index<0||index>=_cooker.Baskets.Count||Workstation.Busy($"basket{index}"))return;
        NoodleBasketRuntime item=_cooker.Baskets[index]; bool ok=false; string message="";
        NoodleBasketState before=item.State;NoodleQuality quality=item.Quality;
        if(item.State==NoodleBasketState.Empty){if(_ingredients.TryConsume(StableIds.Ingredients.WuhanNoodles)){ok=_cooker.TryStart(index);message="面条下锅。";}else message="面条用完了，再点一次补料。";}
        else if(item.State is NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked){ok=_cooker.TryRaise(index);message="提篮，开始沥水。";}
        else if(item.State is NoodleBasketState.Raised or NoodleBasketState.Draining){ok=_cooker.TryQuickDrain(index);message="快速抖水完成。";}
        else if(item.State==NoodleBasketState.Drained){if(!Workstation.Busy("bowl")&&_cooker.TryTransferTo(index,_bowl)){ok=true;message="熟面倒入碗中。";}else message="拌面碗还没有空出来。";}
        else message="面还在烫，等到最佳窗口再提篮。";
        if(ok)Workstation.PlayBasket(index,before,quality);
        if(!ok&&item.State==NoodleBasketState.Empty&&_ingredients.Count(StableIds.Ingredients.WuhanNoodles)==0)StartRefill(StableIds.Ingredients.WuhanNoodles);Feedback(message,!ok);Render();
    }
    internal void IngredientAction(string id)
    {
        if(!CanInteract||Workstation.Busy("bowl")||Workstation.Busy("refill:"+id))return;
        if(_ingredients.Count(id)<=0){StartRefill(id);Feedback("开始补料，约 1 秒后补满。",false);return;}
        bool ok=id==StableIds.Ingredients.WuhanBaseSeasoning?_bowl.TryAddBaseSeasoning():_bowl.TryAddTopping(id);
        if(ok){_ingredients.TryConsume(id);Workstation.PlayIngredient(id);Feedback("配料已经加入。",false);}else if(_ingredients.Count(id)<=2){StartRefill(id);Feedback("当前步骤不能加料，已开始补充低库存。",false);}else Feedback("先把熟面和基础调味放进碗里。",true);Render();
    }
    private void StartRefill(string id){if(!_refills.ContainsKey(id)){_refills[id]=1.0;Workstation.PlayRefill(id);}}
    internal void DeliverNoodles()
    {
        if(!CanInteract||Workstation.Busy("bowl"))return;
        if(!_bowl.TryPrepare(_catalog.RecipesById,out PreparedHotDryNoodles prepared)){Feedback("热干面还没有拌匀。",true);return;}
        Vector2 target=DeliveryTarget();string[] toppings=_bowl.Toppings.ToArray();NoodleQuality quality=_bowl.Quality;bool consumed=false;
        var item=new DeliveredItem(ProductKind.HotDryNoodles,prepared.RecipeId,null,null,null,HotDryNoodlesStateMachine.ToQuality(prepared));
        DeliveryEvaluation result=_controller.TryDeliverWuhanSelected(item,()=>{_bowl.Reset();consumed=true;return true;});
        if(consumed&&!_committed)Workstation.PlayDelivery(ProductKind.HotDryNoodles,target,quality,toppings);
        Feedback(result.Message,result.Grade is DeliveryGrade.Rejected or DeliveryGrade.Incorrect);Render();
    }
    internal void DoupiAction()
    {
        if(!CanInteract||Workstation.Busy("pan"))return;
        if(_doupi?.State==DoupiState.Cut&&Workstation.Busy("stock"))return;
        DoupiState before=_doupi?.State??DoupiState.Empty;
        if(_doupi is null){Feedback("豆皮锅将在 Day 4 解锁。",true);return;} bool ok=_doupi.State switch{DoupiState.Empty=>_doupi.TryPourBatter(),DoupiState.Batter=>_doupi.TryAddEgg(),DoupiState.ReadyToFlip=>_doupi.TryFlip(),DoupiState.Flipped=>_doupi.TryAddFilling(),DoupiState.ReadyToCut or DoupiState.Overbrowned=>_doupi.TryCut(),DoupiState.Cut=>_doupi.TryStock(_doupiStock),DoupiState.Burnt=>DiscardDoupi(),_=>false};
        if(ok)Workstation.PlayDoupi(before);
        Feedback(ok?"豆皮操作完成一步。":before==DoupiState.Cut?"备餐盘已满，豆皮保留在锅中。":"豆皮正在煎制，请观察状态。",!ok);Render();
    }
    private bool DiscardDoupi(){_doupi!.Discard();return true;}
    internal void DeliverDoupi()
    {
        if(!CanInteract||Workstation.Busy("stock"))return;
        if(!_doupiStock.TryPeek(out DoupiQuality quality)){Feedback("备餐盘里没有豆皮。",true);return;} WuhanFoodQuality flags=quality==DoupiQuality.Overbrowned?WuhanFoodQuality.DoupiOverbrowned:WuhanFoodQuality.None;
        Vector2 target=DeliveryTarget();bool consumed=false;
        DeliveryEvaluation result=_controller.TryDeliverWuhanSelected(new DeliveredItem(ProductKind.Doupi,StableIds.Products.Doupi,null,null,null,flags),()=>consumed=_doupiStock.TryTake(1,out _));
        if(consumed&&!_committed)Workstation.PlayDelivery(ProductKind.Doupi,target);
        Feedback(result.Message,result.Grade is DeliveryGrade.Rejected or DeliveryGrade.Incorrect);Render();
    }
    internal void EggAction()
    {
        if(!CanInteract||Workstation.Busy("egg"))return;
        if(_egg is null){Feedback("蛋酒台将在 Day 6 解锁。",true);return;}
        if(_egg.HasFinishedCup){Vector2 target=DeliveryTarget();bool consumed=false;DeliveryEvaluation result=_controller.TryDeliverWuhanSelected(new DeliveredItem(ProductKind.EggRiceWine,StableIds.Products.EggRiceWine),()=>consumed=_egg.TryTake());if(consumed&&!_committed)Workstation.PlayDelivery(ProductKind.EggRiceWine,target);Feedback(result.Message,result.Grade is DeliveryGrade.Rejected or DeliveryGrade.Incorrect);Render();return;}
        if(_egg.BaseCups==0){bool refill=_egg.TryRefill();if(refill)Workstation.PlayEgg(true);Feedback(refill?"补充蛋酒底料，0.6 秒后完成。":"蛋酒台正在工作。",!refill);Render();return;}
        bool started=_egg.TryStart();if(started)Workstation.PlayEgg(false);Feedback(started?"正在冲蛋酒，0.6 秒后再次点击交付。":"蛋酒台正在工作。",!started);Render();
    }
    private Vector2 DeliveryTarget()
    {
        var queue=_controller.CustomerQueue;
        if(queue is not null)for(int i=0;i<queue.Slots.Count&&i<_customers.Length;i++)
            if(queue.Slots[i].Id==queue.SelectedCustomerId)return Workstation.GetGlobalTransform().AffineInverse()*(_customers[i].GlobalPosition+_customers[i].Size*new Vector2(.5f,.65f));
        return new Vector2(960,-200);
    }
    private void Select(int slot){if(slot<_controller.CustomerQueue!.Slots.Count&&!_controller.CustomerQueue.TrySelect(_controller.CustomerQueue.Slots[slot].Id))Feedback("顾客还没有站稳。",true);}

    private void Render()
    {
        if(_controller?.CurrentConfig is null||_cooker is null)return;_day.Text=$"武汉 Day {_controller.CurrentConfig.Day} · {Subtitle(_controller.CurrentConfig.Day)}";_clock.Text=_controller.State switch{DayState.Opening=>$"开门 {_controller.OpeningRemainingSeconds:0.0}",DayState.Closing=>$"收尾 {_controller.ClosingRemainingSeconds:0.0}",_=>$"剩余 {(int)_controller.DayRemainingSeconds/60:00}:{(int)_controller.DayRemainingSeconds%60:00}"};_income.Text=$"¥{_controller.Ledger?.Build().TotalRevenue??0}";_door.Text=$"候场 {_controller.CustomerQueue?.DoorQueue.Count??0}";_tutorial.Text=Tutorial(_controller.CurrentConfig.Day);
        for(int i=0;i<_basketButtons.Length;i++){if(i>=_cooker.Baskets.Count)continue;NoodleBasketRuntime b=_cooker.Baskets[i];_basketLabels[i].Text=b.State switch{NoodleBasketState.Empty=>"空 · 点击下面",NoodleBasketState.Cooking=>$"烫制 {b.CookSeconds:0.0}s",NoodleBasketState.Ready=>"最佳 · 点击提篮",NoodleBasketState.Soft=>"偏软 · 点击提篮",NoodleBasketState.Overcooked=>"煮过头 · 点击提篮",NoodleBasketState.Locked=>"已锁熟 · 点击提篮",NoodleBasketState.Raised or NoodleBasketState.Draining=>"沥水中 · 点击抖水",_=>"已沥干 · 点击倒入碗"};}
        _bowlStatus.Text=$"{BowlName(_bowl.State)} · 拌匀 {_bowl.MixProgress:0}%";foreach(Node node in _ingredientRow.GetChildren()){var button=(Button)node;string id=button.GetMeta("ingredient_id").AsString();button.Text=$"{IngredientName(id)} {_ingredients.Count(id)}{(_refills.ContainsKey(id)?" 补料中":"")}";}
        _doupiStatus.Text=_doupi is null?"Day 4 解锁":$"{DoupiName(_doupi.State)} · 已切 {_doupi.CompletedCuts}/4 · 库存 {_doupiStock.Count}/16";_doupiButton.Text=_doupi?.State switch{DoupiState.Empty=>"浇浆",DoupiState.Batter=>"加鸡蛋",DoupiState.ReadyToFlip=>"翻面",DoupiState.Flipped=>"铺三鲜糯米馅",DoupiState.ReadyToCut or DoupiState.Overbrowned=>"切块",DoupiState.Cut=>"收入备餐盘",DoupiState.Burnt=>"丢弃焦糊豆皮",_=>"煎制中"};
        _eggStatus.Text=_egg is null?"Day 6 解锁":_egg.HasFinishedCup?$"成品待交付 · 底料 {_egg.BaseCups}/6":_egg.IsPreparing?$"冲泡 {_egg.RemainingSeconds:0.0}s":_egg.IsRefilling?$"补料 {_egg.RemainingSeconds:0.0}s":$"底料 {_egg.BaseCups}/6";
        for(int i=0;i<_cooker.Baskets.Count;i++)_basketButtons[i].Disabled=!CanInteract||Workstation.Busy($"basket{i}");
        foreach(Button button in _ingredientRow.GetChildren().OfType<Button>())button.Disabled=!CanInteract||Workstation.Busy("bowl")||Workstation.Busy("refill:"+button.GetMeta("ingredient_id").AsString());
        _deliverNoodles.Disabled=!CanInteract||Workstation.Busy("bowl");
        _doupiButton.Disabled=!CanInteract||_doupi is null||Workstation.Busy("pan")||(_doupi.State==DoupiState.Cut&&Workstation.Busy("stock"));
        _deliverDoupi.Disabled=!CanInteract||_doupi is null||Workstation.Busy("stock");
        _eggButton.Disabled=!CanInteract||_egg is null||Workstation.Busy("egg");
        _eggButton.Text=_egg?.HasFinishedCup==true?"交付蛋酒":_egg?.BaseCups==0?"补充蛋酒底料":"冲一杯蛋酒";
        Workstation.QueueRedraw();
        RenderCustomers();
    }
    private void RenderCustomers()
    {
        if(_controller.CustomerQueue is null)return;var slots=_controller.CustomerQueue.Slots;for(int i=0;i<4;i++){if(i>=slots.Count){_customers[i].Visible=false;continue;}CustomerRuntime c=slots[i];_customers[i].Visible=true;_orders[i].Text=$"{c.Type.DisplayName}\n{string.Join("  +  ",c.Order.Lines.Select(LineText))}";_patience[i].Value=(1-c.PatienceProgress)*100;bool selected=_controller.CustomerQueue.SelectedCustomerId==c.Id;_customers[i].AddThemeStyleboxOverride("normal",TianjinUi.Box(selected?new Color(1,.82f,.25f,.25f):new Color(1,1,1,.04f),14,selected?4:0,false));_portraits[i].SetVisual(_art.Shared.CustomerPortrait(c.AppearanceId,TianjinArtCatalog.ResolveCustomerExpression(c.State,c.WasServed)));}
    }
    private string LineText(OrderLineData line){string name=line.ProductKind switch{ProductKind.HotDryNoodles=>_catalog.RecipesById.TryGetValue(line.DefinitionId,out RecipeData? r)?r.DisplayName:"热干面",ProductKind.Doupi=>"三鲜豆皮",_=>"蛋酒"};return line.Quantity>1?$"{name}×{line.Quantity}":name;}
    private void Feedback(string text,bool error){_feedback.Text=(error?"！ ":"✓ ")+text;_feedback.Modulate=error?TianjinUi.Red:TianjinUi.Green;_feedback.Visible=true;_feedbackSeconds=2.4;}
    private void OnStateChanged(DayState state){if(state==DayState.Running)Feedback("开始营业！先选顾客，再制作并逐件交付。",false);else if(state==DayState.Closing)Feedback("停止接新客，最后 15 秒完成手中订单。",false);}
    private void OnDeliveryCompleted(DeliveryEvaluation result)=>Feedback(result.Message,result.Grade is DeliveryGrade.Incorrect or DeliveryGrade.Rejected);
    public override void _ExitTree()
    {
        Workstation.CancelAnimations();
        if(_controller is null)return;
        _controller.StateChanged-=OnStateChanged;_controller.DayFinished-=OnFinished;_controller.DeliveryCompleted-=OnDeliveryCompleted;
    }
    private static string BowlName(NoodleBowlState state)=>state switch { NoodleBowlState.Empty=>"空碗",NoodleBowlState.Noodles=>"熟面待调味",NoodleBowlState.Seasoned=>"已调味 · 按住碗内拌面",NoodleBowlState.Mixing=>"正在拌面",_=>"已拌匀 · 可出餐" };
    private static string DoupiName(DoupiState state)=>state switch { DoupiState.Empty=>"空锅",DoupiState.Batter=>"已浇浆",DoupiState.SkinCooking=>"蛋皮煎制中",DoupiState.ReadyToFlip=>"可以翻面",DoupiState.Flipped=>"已翻面 · 待铺馅",DoupiState.SecondCooking=>"三鲜馅煎制中",DoupiState.ReadyToCut=>"已熟 · 可以切块",DoupiState.Overbrowned=>"偏焦 · 可以切块",DoupiState.Burnt=>"焦糊 · 请丢弃",_=>"已切好 · 待入盘" };
    private void OnFinished(DayResult result)
    {
        if(_committed||_controller.CurrentConfig?.CityId!=StableIds.Cities.Wuhan)return;_committed=true;Workstation.CancelAnimations();try{DayCommitResult commit=_save.CommitDay(result,_controller.CurrentPlan!,_controller.CurrentConfig!);string stars=result.Day==12?$"\n武汉评级 {new string('★',commit.EarnedStars)}{new string('☆',3-commit.EarnedStars)}":"";_resultText.Text=$"[center][font_size=28]武汉 Day {result.Day} 打烊[/font_size]\n\n[font_size=42]今日总收入 ¥{result.TotalRevenue}[/font_size]\n永久金币增加 ¥{commit.PermanentCoinGain}\n\n完成 {result.CompletedCustomers} 位 · 流失 {result.LostCustomers} 位\n满意度 {result.Satisfaction:0}% · Perfect {result.PerfectOrders} 单{stars}[/center]";_unlock.Text=commit.NewChapterCompletion?"武汉 · 过早之城已经点亮！获得三件早餐收藏与章节徽章。西安章节已开放。":_controller.CurrentConfig.CompletionUnlocks.Count>0?"新的武汉设备升级已经开放。":"成绩已写入武汉经营手账。";}catch(IOException e){_resultText.Text=$"保存失败：{e.Message}";_unlock.Text="本次结果已回退。";}_blocker.Visible=true;_results.Visible=true;
    }
    private void BuildResults(){_blocker=new ColorRect{Color=new Color(0.2f,.09f,.04f,.48f),Visible=false,ZIndex=95};TianjinUi.FullRect(_blocker);AddChild(_blocker);_results=TianjinUi.Panel(TianjinUi.Paper,22);_results.Position=new Vector2(550,170);_results.Size=new Vector2(820,700);_results.Visible=false;_results.ZIndex=100;AddChild(_results);var col=new VBoxContainer();col.AddThemeConstantOverride("separation",18);_results.AddChild(col);col.AddChild(TianjinUi.Label("武汉今日营业收据",36,TianjinUi.BrownDark,HorizontalAlignment.Center));_resultText=new RichTextLabel{BbcodeEnabled=true,CustomMinimumSize=new Vector2(740,430),SizeFlagsVertical=SizeFlags.ExpandFill};_resultText.AddThemeFontSizeOverride("normal_font_size",22);col.AddChild(_resultText);_unlock=TianjinUi.Label("",18,TianjinUi.Orange,HorizontalAlignment.Center);_unlock.AutowrapMode=TextServer.AutowrapMode.WordSmart;col.AddChild(_unlock);var back=TianjinUi.Button("收好收入 · 返回武汉经营首页",true,new Vector2(0,70));back.Pressed+=()=>HubRequested?.Invoke();col.AddChild(back);}
    private static string IngredientName(string id)=>id switch{StableIds.Ingredients.WuhanBaseSeasoning=>"调味",StableIds.Ingredients.WuhanScallion=>"葱花",StableIds.Ingredients.WuhanChiliOil=>"辣油",_=>"牛肉"};
    private static string Subtitle(int day)=>day switch{1=>"初到武汉",4=>"豆皮开锅",6=>"蛋酒",7=>"牛肉与上班族",8=>"完整早餐",9=>"带走大单",12=>"最终挑战",_=>"过早高峰"};
    private static string Tutorial(int day)=>day switch{1=>"下锅 → 最佳时提篮 → 抖水 → 倒入碗 → 基础调味 → 按住画圈拌匀 → 出餐",4=>"豆皮一次做 8 块：浇浆、加蛋、翻面、铺馅、煎熟、切四刀、收入备餐盘",6=>"蛋酒需点击冲泡 0.6 秒，再点击一次交付；底料用完后补满",7=>"上班族耐心只有 34 秒，牛肉配方已经加入",8=>"熟客和游客加入：短耐心不一定是最高价值订单",_=>string.Empty};
}
