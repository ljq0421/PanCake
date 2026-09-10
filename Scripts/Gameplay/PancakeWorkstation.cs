using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Pancake;
using ProjectCake.Fryer;
using ProjectCake.UI;
using ProjectCake.Orders;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation : Control
{
    private static readonly Rect2 FryerAreaRect = new(24, 475, 520, 535);
    private static readonly Rect2 StoveAreaRect = new(446, 475, 760, 535);
    private static readonly Rect2 UtilityAreaRect = new(1090, 578, 794, 112);
    private static readonly Rect2 IngredientAreaRect = new(1090, 700, 794, 310);
    private static readonly Rect2 DeliveryDropZoneRect = new(40, 2, 190, 108);
    private static readonly Rect2 FinishedPancakeSlotRect = new(238, 10, 150, 92);
    private static readonly Rect2 SoyMilkSlotRect = new(396, 10, 178, 92);
    private static readonly Rect2 TrashZoneRect = new(582, 2, 130, 108);
    private static readonly Rect2 ServingTrayTextureRegion = new(0, 224, 1536, 576);

    private static readonly (string Id, string Name, Color Color, bool Drag)[] Ingredients =
    {
        (StableIds.Ingredients.Batter, "面糊", new Color("#E9C687"), true),
        (StableIds.Ingredients.Egg, "鸡蛋", new Color("#F4C84A"), false),
        (StableIds.Ingredients.Sauce, "酱料", new Color("#B95837"), false),
        (StableIds.Ingredients.Crispy, "薄脆", new Color("#D98A37"), true),
        (StableIds.Ingredients.Scallion, "香葱", new Color("#77A956"), false),
        (StableIds.Ingredients.Ham, "火腿", new Color("#D86A55"), true),
    };

    private const string StoredYoutiaoPayload = "stored_youtiao";
    private const string SoyMilkPayload = "soy_milk_cup";

    private readonly Dictionary<string, IngredientStockSlotView> _ingredientSlots = new(StringComparer.Ordinal);
    private readonly HashSet<string> _lowStockNotified = new(StringComparer.Ordinal);
    private readonly List<StockGesture> _stockGestures = new();
    private PressRepeatGesture _rawYoutiaoInput = null!;
    internal CoinTrayView? CoinTray { get; private set; }
    private ProgressBar? _soyHoldProgress;
    private readonly Dictionary<Control, Tween> _interactionTweens = new();
    private readonly HashSet<string> _enabledIngredients = new(StringComparer.Ordinal)
    {
        StableIds.Ingredients.Batter,
        StableIds.Ingredients.Egg,
        StableIds.Ingredients.Sauce,
        StableIds.Ingredients.Crispy,
        StableIds.Ingredients.Scallion,
    };
    private DragService _drag = null!;
    private DragItem _batterItem = null!;
    private StrokeInteractor _stroke = null!;
    private DropZone _stoveDropZone = null!;
    private PancakeCanvas _canvas = null!;
    private PancakeAudio _audio = null!;
    private TextureRect _batterLadle = null!;
    private Tween? _batterTween;
    private bool _batterDropAnimating;
    private TextureRect _bagTransfer = null!;
    private double _bagTransferRemaining;
    private bool _baggedPresented;
    private const double BagTransferDuration = 0.22;
    private DragItem _finished = null!;
    private Button? _previousPancake;
    private Button? _nextPancake;
    private Label _state = null!;
    private PanelContainer _pancakeStatusTag = null!;
    private Button _flip = null!;
    private Button _finishSauce = null!;
    private Button _fold = null!;
    private Button _bag = null!;
    private Button _discard = null!;
    private Control _pancakeActions = null!;
    private Control _fryerPanel = null!;
    private FryerVisualView _fryerVisual = null!;
    private Label _fryerStatus = null!;
    private Label _fryerStock = null!;
    private WorkstationSlotView _finishedYoutiaoSlot = null!;
    private SoyMilkStockView? _soyStockArt;
    private Button _lowerBasket = null!;
    private Button _raiseBasket = null!;
    private Button _discardBatch = null!;
    private Control _fryerActions = null!;
    private DragItem _storedYoutiao = null!;
    private Control _soyPanel = null!;
    private Label _soyStatus = null!;
    private DragItem _soyCup = null!;
    private Button _soyRefill = null!;
    private DropZone _deliveryZone = null!;
    private DropZone _trashZone = null!;
    private Label _directDeliveryHint = null!;
    private TianjinArtCatalog _art = null!;
    private int _stoveLevel = 1;
    private bool _initialized;
    private PancakeState? _lastPancakeState;
    private FryerState? _lastFryerState;
    private YoutiaoQuality? _lastFryerQuality;

    public event Action<string, bool>? Feedback;
    public event Action<int>? YoutiaoConsumed;
    public event Action<int>? YoutiaoBurnt;
    public PancakeStateMachine Machine { get; private set; } = null!;
    public IngredientInventory Inventory { get; private set; } = null!;
    public FryerStateMachine? FryerMachine { get; private set; }
    public SoyMilkTrayRuntime? SoyMilkTray { get; private set; }
    public PancakeTrayInventory PancakeTray { get; } = new();
    public Func<PancakeStateMachine, bool>? SubmitPrepared { get; set; }
    public Func<ProductKind, bool>? SubmitProduct { get; set; }
    public Func<bool>? CanSubmitToSelectedCustomer { get; set; }
    public Func<IReadOnlySet<string>?>? RequiredToppingsForSelectedCustomer { get; set; }
    public bool InteractionEnabled { get; set; } = true;
    public bool Paused { get; set; }
    public bool DirectCustomerDelivery { get; set; }
    // The scene variant defines these capabilities through its fixed nodes.
    private bool UseServingTray => CoinTray is not null;
    private bool ProductionShortcutsEnabled => UseServingTray;
    internal bool IsTransferringBag => _bagTransferRemaining > 0;
    private bool HasFinishedPancake => UseServingTray ? PancakeTray.Count > 0 : Machine.Runtime.State == PancakeState.Bagged;

    public DeliveryEvaluation DeliverPancakeTo(DayController controller, string? customerId, DataCatalog catalog)
    {
        if (!UseServingTray) return controller.TryDeliverPancakeTo(customerId, Machine, catalog);
        PreparedPancake? prepared = PancakeTray.Selected;
        if (!CanDeliverProduct("finished_pancake") || prepared is null)
            return new DeliveryEvaluation(DeliveryGrade.Rejected, 0, 0, 0, "托盘中没有可交付的煎饼。");
        DeliveryEvaluation result = controller.TryDeliverPreparedPancakeTo(customerId, prepared, catalog,
            () => PancakeTray.TryTake(prepared));
        Render();
        return result;
    }

    internal bool TryFinishSauceWithRightClick()
    {
        if (!ProductionShortcutsEnabled || !_initialized || !IsVisibleInTree()
            || !CanInteract || _drag.IsDragging || Machine.Runtime.State != PancakeState.Saucing) return false;
        return Execute(PancakeCommand.CompleteSauce);
    }

    internal bool TryInvokeProductionShortcut(Key key)
    {
        if (!ProductionShortcutsEnabled || !_initialized || !IsVisibleInTree()
            || !CanInteract || _drag.IsDragging) return false;

        // Resolve exactly one visible action before invoking it. Never include cleanup.
        Button? action = key switch
        {
            Key.F => _flip.Visible ? _flip : _finishSauce.Visible ? _finishSauce : _fold.Visible ? _fold : _bag.Visible ? _bag : null,
            Key.G => _lowerBasket.Visible ? _lowerBasket : _raiseBasket.Visible ? _raiseBasket : null,
            _ => null,
        };
        if (action is null || !action.IsVisibleInTree() || action.Disabled) return false;
        action.EmitSignal(Button.SignalName.Pressed);
        return true;
    }

    public void RegisterCustomerZone(DropZone zone) => _drag.RegisterZone(zone);

    public static ProductKind? DeliveryProduct(string payload) => payload switch
    {
        "finished_pancake" => ProductKind.Pancake,
        StoredYoutiaoPayload => ProductKind.Youtiao,
        SoyMilkPayload => ProductKind.SoyMilk,
        _ => null,
    };

    public bool CanDeliverProduct(string payload) => _initialized && CanInteract && payload switch
    {
        "finished_pancake" => HasFinishedPancake && !IsTransferringBag,
        StoredYoutiaoPayload => FryerMachine?.Inventory.Count > 0,
        SoyMilkPayload => SoyMilkTray?.CanStartDrag == true,
        _ => false,
    };

    public bool DeliverToCustomer(string payload, Func<bool> deliver)
    {
        if (!CanDeliverProduct(payload) || !deliver()) return false;
        LearnWorkbenchAction($"deliver:{payload}");
        if (payload == SoyMilkPayload) LearnWorkbenchAction("take:soy_milk");
        if (payload == StoredYoutiaoPayload) LearnWorkbenchAction("take:youtiao");
        _audio.Play(PancakeSound.Success);
        if (payload == "finished_pancake" && !UseServingTray)
        {
            Machine.TryExecute(PancakeCommand.Discard);
            _stroke.ResetCoverage();
        }
        Render();
        return true;
    }

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _art = new TianjinArtCatalog();
        _ingredientSlots.Clear();
        foreach (IngredientStockSlotView slot in this.Descendants<IngredientStockSlotView>())
        {
            string key = slot.Name.ToString();
            if (key.StartsWith("IngredientSlot_", StringComparison.Ordinal))
                _ingredientSlots[key["IngredientSlot_".Length..]] = slot;
        }

        if (UseServingTray) ConfigureTianjinPresentation();
        _drag.Configure(this);
        _drag.DragStarted += _ => _audio.Play(PancakeSound.PickUp);
        _drag.DragEnded += OnDragEnded;
        var rawYoutiaoSlot = _rawYoutiaoInput.GetParent().GetParent() as WorkstationSlotView
            ?? throw new InvalidOperationException("RawYoutiaoInput 必须预建在 WorkstationSlotView/ClickArea 下。");
        rawYoutiaoSlot.BindInteraction(_rawYoutiaoInput);
        ConfigureArtInteraction(_rawYoutiaoInput, rawYoutiaoSlot.HoverTarget);
        _rawYoutiaoInput.CanActivate = CanLoadRawYoutiao;
        _rawYoutiaoInput.Activate = () => ExecuteFryer(FryerCommand.LoadOne);
        _rawYoutiaoInput.Rejected = () => { if (CanInteract) Reject("炸篮当前不能继续装料。"); };
        _lowerBasket.Pressed += () => ExecuteFryer(FryerCommand.LowerBasket);
        _raiseBasket.Pressed += () => ExecuteFryer(FryerCommand.RaiseBasket);
        _discardBatch.Pressed += () => ExecuteFryer(FryerCommand.Discard);
        _storedYoutiao.BindRuntime(_drag, () => CanInteract && FryerMachine?.Inventory.Count > 0,
            CreateYoutiaoDragPreview);
        _finishedYoutiaoSlot.BindInteraction(_storedYoutiao);
        ConfigureArtInteraction(_storedYoutiao, _finishedYoutiaoSlot.HoverTarget);
        _storedYoutiao.StartRejected += () => Reject("没有可用的成品油条。");

        foreach ((string id, string name, Color color, bool drag) in Ingredients)
        {
            if (!_ingredientSlots.TryGetValue(id, out IngredientStockSlotView? slot)) continue;
            Control? input = slot.GetNodeOrNull<Control>($"ClickArea/IngredientInput_{id.Replace(':', '_')}");
            if (input is null) continue;
            slot.BindInteraction(input);
            ConfigureArtInteraction(input, slot.HoverTarget);
            if (input is DragItem item)
            {
                item.BindRuntime(_drag, () => CanUse(id));
                item.StartRejected += () => Reject("当前不能取用该食材。");
                if (id == StableIds.Ingredients.Batter) _batterItem = item;
            }
            else if (input is Button button)
            {
                button.Pressed += () =>
                {
                    if (id == StableIds.Ingredients.Egg) Execute(PancakeCommand.AddEgg);
                    else if (id == StableIds.Ingredients.Sauce) PickUpSauceBrush();
                    else Execute(PancakeCommand.AddIngredient, id);
                };
            }
            slot.RefillRequested += () => Refill(id);
            StockGesture? gesture = _stockGestures.FirstOrDefault(candidate => candidate.Name == $"StockGesture_{id}");
            if (gesture is null) continue;
            gesture.CanInteract = () => _initialized && CanInteract && !_drag.IsDragging && IsVisibleInTree();
            gesture.Contains = point => slot.ClickBounds.HasPoint(point + gesture.Position);
            gesture.CanRefill = () => CanInteract && _enabledIngredients.Contains(id) && Inventory.CanRefill(id);
            gesture.Refill = () => Refill(id);
            gesture.Progress = slot.RenderHoldProgress;
            gesture.Tap = () =>
            {
                if (!Inventory.HasAvailable(id)) Inform($"{name}已经用完，长按补货。", false);
                else if (input is Button tapButton) tapButton.EmitSignal(Button.SignalName.Pressed);
            };
            if (input is DragItem dragItem)
                gesture.Drag = () =>
                {
                    if (!Inventory.HasAvailable(id)) Inform($"{name}已经用完，长按补货。", false);
                    else dragItem.TryBeginDrag();
                };
        }

        _stoveDropZone.Configure(CanDrop, Drop, _ => _canvas.GetGlobalTransform() * _canvas.GetSurfaceRect().GetCenter());
        _drag.RegisterZone(_stoveDropZone);
        _stroke.ResolveMode = ResolveStroke;
        _stroke.ResolveSpreadGeometry = ResolveSpreadGeometry;
        _stroke.SpreadToolTexture = _art.Scraper;
        _stroke.SauceToolTexture = _art.Ingredient(StableIds.Ingredients.Sauce);
        _stroke.IsToolHeld = () => _initialized && IsVisibleInTree() && CanInteract && !_drag.IsDragging
            && Machine.Runtime.State == PancakeState.Saucing;
        _stroke.StrokeStarted = BeginStroke;
        _stroke.StrokeProgressed = (mode, progress) =>
        {
            if (mode == StrokeMode.Spread) Machine.SetSpreadCoverage(progress);
            else Machine.SetSauceCoverage(progress);
        };
        _stroke.StrokeCompleted = mode =>
        {
            Execute(mode == StrokeMode.Spread ? PancakeCommand.CompleteSpread : PancakeCommand.CompleteSauce);
            _canvas.PivotOffset = _canvas.Size * .5f;
            _canvas.Scale = new Vector2(.985f, .985f);
            CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out)
                .TweenProperty(_canvas, "scale", Vector2.One, .16);
        };
        _stroke.InvalidStroke = () => Reject("当前步骤不需要轨迹操作。");
        _canvas.Resized += LayoutStoveInputs;
        Callable.From(LayoutStoveInputs).CallDeferred();
        _flip.Pressed += () => Execute(PancakeCommand.Flip);
        _finishSauce.Pressed += () => Execute(PancakeCommand.CompleteSauce);
        _fold.Pressed += () => Execute(PancakeCommand.Fold);
        _bag.Pressed += () => Execute(PancakeCommand.Bag);
        _discard.Pressed += Discard;

        _deliveryZone.Configure(CanDeliverPayload, DeliverPayload, _ => _deliveryZone.GetGlobalRect().GetCenter());
        _drag.RegisterZone(_deliveryZone);
        _finished.BindRuntime(_drag, () => CanDeliverProduct("finished_pancake"));
        if (_previousPancake is not null) _previousPancake.Pressed += () => SelectTrayPancake(-1);
        if (_nextPancake is not null) _nextPancake.Pressed += () => SelectTrayPancake(1);
        if (_soyStockArt is not null) _soyStockArt.Configure(_art.Product(ProductKind.SoyMilk));
        _soyCup.BindRuntime(_drag, () => CanInteract && SoyMilkTray?.CanStartDrag == true);
        _soyCup.StartRejected += () => Reject("豆浆托盘正在取杯、补货或已经空了。");
        _soyRefill.Pressed += RefillSoyMilk;
        StockGesture? soyGesture = _stockGestures.FirstOrDefault(candidate => candidate.Name == "StockGesture_soy_milk");
        if (soyGesture is not null)
        {
            soyGesture.CanInteract = () => _initialized && CanInteract && !_drag.IsDragging && IsVisibleInTree();
            soyGesture.CanRefill = () => CanInteract && SoyMilkTray is { IsTaking: false, IsRefilling: false } soy && soy.Quantity < soy.Capacity;
            soyGesture.Refill = RefillSoyMilk;
            soyGesture.Drag = () => { if (SoyMilkTray?.Quantity == 0) Inform("豆浆已经用完，长按补货。", false); else _soyCup.TryBeginDrag(); };
            soyGesture.Tap = () => { if (SoyMilkTray?.Quantity == 0) Inform("豆浆已经用完，长按补货。", false); };
            soyGesture.Progress = progress =>
            {
                if (SoyMilkTray?.IsRefilling == true || _soyHoldProgress is null) return;
                _soyHoldProgress.Visible = progress > 0;
                _soyHoldProgress.Value = progress * 100;
            };
        }
        _trashZone.Configure(CanTrashPayload, DiscardPayload, _ => _trashZone.GetGlobalRect().GetCenter());
        if (UseServingTray)
        {
            _trashZone.HitPadding = 0;
            _trashZone.FixedHitRect = new Rect2(_trashZone.Position, _trashZone.Size);
            BuildFirstUseHints();
        }
        _drag.RegisterZone(_trashZone);
    }

    private void SelectTrayPancake(int direction)
    {
        if (!CanInteract || _drag.IsDragging || IsTransferringBag) return;
        PancakeTray.SelectNext(direction);
        Render();
    }

    public void Initialize(DataCatalog catalog, int stoveLevel, int stationLevel, int fryerLevel = 0, DayConfig? config = null, TianjinArtCatalog? art = null)
    {
        CancelInput();
        _art = art ?? _art;
        _stoveLevel = stoveLevel;
        _lastPancakeState = null;
        _lastFryerState = null;
        _lastFryerQuality = null;
        ResetBagPresentation();
        PancakeTray.Clear();
        if (Machine is not null) Machine.Changed -= Render;
        Machine = new PancakeStateMachine(catalog.StovesByLevel[stoveLevel]);
        Inventory = new IngredientInventory(catalog.IngredientStationsByLevel[stationLevel]);
        Machine.Changed += Render;
        Inventory.Changed += Render;
        _canvas.Bind(Machine.Runtime, _art, stoveLevel);
        LayoutStoveInputs();
        FryerMachine = fryerLevel > 0 ? new FryerStateMachine(catalog.FryersByLevel[fryerLevel]) : null;
        if (FryerMachine is not null)
        {
            FryerMachine.Changed += Render;
            FryerMachine.BatchBurnt += quantity => YoutiaoBurnt?.Invoke(quantity);
            _fryerVisual.Bind(_art, FryerMachine);
        }
        SoyMilkTray = config?.AvailableProductKinds.Contains(ProductKind.SoyMilk) == true ? new SoyMilkTrayRuntime() : null;
        if (SoyMilkTray is not null) SoyMilkTray.Changed += Render;
        if (config is not null)
        {
            _enabledIngredients.Clear();
            _enabledIngredients.UnionWith(new[] { StableIds.Ingredients.Batter, StableIds.Ingredients.Egg, StableIds.Ingredients.Sauce });
            foreach (string recipeId in config.AvailableRecipeIds)
                _enabledIngredients.UnionWith(catalog.RecipesById[recipeId].ExtraIngredients.Where(id => id != StableIds.Ingredients.Youtiao));
            if (config.AvailableRecipeIds.Any(id => id is StableIds.Recipes.Youtiao or StableIds.Recipes.ScallionYoutiao))
                _enabledIngredients.Add(StableIds.Ingredients.Youtiao);
        }
        _initialized = true;
        Render();
    }

    public void Tick(double deltaSeconds)
    {
        if (!_initialized || Paused || !InteractionEnabled)
        {
            foreach (StockGesture gesture in _stockGestures) gesture.Cancel();
            _rawYoutiaoInput?.Cancel();
            return;
        }
        Machine.Tick(deltaSeconds);
        TickBagTransfer(deltaSeconds);
        Inventory.Tick(deltaSeconds);
        FryerMachine?.Tick(deltaSeconds);
        _fryerVisual.Tick(deltaSeconds);
        SoyMilkTray?.Tick(deltaSeconds);
        foreach (StockGesture gesture in _stockGestures) gesture.Tick(deltaSeconds);
        _rawYoutiaoInput.Tick(deltaSeconds);
        RenderLive();
    }

    public void CancelInput()
    {
        foreach (StockGesture gesture in _stockGestures) gesture.Cancel();
        _rawYoutiaoInput?.Cancel();
        _drag.CancelDrag();
        _stroke.CancelStroke();
        FinishBatterDropAnimation();
    }

    internal void RefreshForCapture() => Render();

    public void ResetForDay()
    {
        CancelInput();
        CoinTray?.RenderRevenue(0);
        PancakeTray.Clear();
        ResetBagPresentation();
        FinishBatterDropAnimation();
        if (_initialized && Machine.Runtime.State != PancakeState.Empty)
        {
            Machine.TryExecute(PancakeCommand.Discard);
        }
        if (_initialized)
        {
            Inventory.FillAll();
            FryerMachine?.Reset();
            SoyMilkTray?.Reset();
        }
        _stroke.ResetCoverage();
        _canvas.BatterDropProgress = 1;
        Render();
    }

    public bool TrySwitchEquipment(DataCatalog catalog, int stoveLevel, int stationLevel)
    {
        if (!_initialized || !Machine.CanSwitchStove || Inventory.IsAnyRefilling)
        {
            return false;
        }
        if (!catalog.TryGetStove(stoveLevel, out PancakeStoveLevelData stove)
            || !catalog.TryGetIngredientStation(stationLevel, out IngredientStationLevelData station)
            || !Machine.TrySwitchStove(stove)
            || !Inventory.TrySwitchLevel(station))
        {
            return false;
        }
        _stoveLevel = stoveLevel;
        _canvas.Bind(Machine.Runtime, _art, stoveLevel);
        LayoutStoveInputs();
        Render();
        return true;
    }
    private static WorkstationSlotSpec RawYoutiaoSlotSpec() => new(
        new Vector2(170, 150),
        new Rect2(0, 28, 170, 88),
        new Rect2(25, 48, 120, 48),
        new Rect2(24, 116, 122, 26),
        new Rect2(),
        new Rect2(),
        new Rect2(0, 20, 170, 126),
        new Rect2(),
        1.0f);

    private static WorkstationSlotSpec FinishedYoutiaoSlotSpec() => new(
        new Vector2(170, 132),
        new Rect2(0, 16, 170, 88),
        new Rect2(26, 28, 118, 52),
        new Rect2(16, 101, 104, 27),
        new Rect2(118, 99, 48, 29),
        new Rect2(),
        new Rect2(0, 12, 170, 112),
        new Rect2(),
        1.0f);

    private static WorkstationSlotSpec IngredientSlotSpec(string id)
    {
        bool representative = id is StableIds.Ingredients.Egg
            or StableIds.Ingredients.Crispy
            or StableIds.Ingredients.Scallion
            or StableIds.Ingredients.Ham;
        return new WorkstationSlotSpec(
            new Vector2(386, 88),
            new Rect2(0, 0, 306, 82),
            representative ? new Rect2(38, 4, 190, 58) : new Rect2(65, 4, 180, 58),
            new Rect2(78, 56, 150, 25),
            new Rect2(238, 7, 66, 25),
            new Rect2(318, 16, 66, 56),
            new Rect2(8, 3, 290, 79),
            new Rect2(4, 82, 296, 6),
            1.0f);
    }

    private bool CanInteract => InteractionEnabled && !Paused && !_batterDropAnimating;
    private bool CanUse(string id) => _initialized && CanInteract && _enabledIngredients.Contains(id) && Inventory.HasAvailable(id);
    private bool CanDrop(string id) => CanInteract && id switch
    {
        StableIds.Ingredients.Batter => Machine.Runtime.State == PancakeState.Empty,
        StableIds.Ingredients.Crispy or StableIds.Ingredients.Ham or StoredYoutiaoPayload => Machine.Runtime.State is PancakeState.Sauced or PancakeState.Toppings,
        _ => false,
    };
    private void Drop(string id)
    {
        if (id == StableIds.Ingredients.Batter) TryPlaceBatter();
        else Execute(PancakeCommand.AddIngredient, id == StoredYoutiaoPayload ? StableIds.Ingredients.Youtiao : id);
    }
    private StrokeMode ResolveStroke() => !_initialized || !CanInteract ? StrokeMode.None : Machine.Runtime.State switch
    {
        PancakeState.BatterPlaced or PancakeState.Spreading => StrokeMode.Spread,
        PancakeState.Saucing => StrokeMode.Sauce,
        _ => StrokeMode.None,
    };
    private void BeginStroke(StrokeMode mode)
    {
        PancakeActionResult result = Machine.TryExecute(mode == StrokeMode.Spread ? PancakeCommand.BeginSpread : PancakeCommand.BeginSauce);
        if (!result.Success && Machine.Runtime.State is not (PancakeState.Spreading or PancakeState.Saucing)) Reject(result.Message);
        else _audio.Play(PancakeSound.Stroke);
    }
    private void PickUpSauceBrush()
    {
        if (!CanUse(StableIds.Ingredients.Sauce))
        {
            Reject("酱料不足、正在补货或当前不能操作。");
            return;
        }
        if (Machine.Runtime.State != PancakeState.Saucing && !Execute(PancakeCommand.BeginSauce)) return;
        _stroke.RefreshVisualState();
        Inform(ProductionShortcutsEnabled
            ? "按住左键刷酱，达到所需酱量后按鼠标右键、F 或点击收刷。"
            : "按住左键刷酱，达到所需酱量后点击收刷。", false);
    }
    private EllipseGeometry ResolveSpreadGeometry()
    {
        Rect2 surface = _canvas.GetSurfaceRect();
        Transform2D canvasToStroke = _stroke.GetGlobalTransform().AffineInverse() * _canvas.GetGlobalTransform();
        Vector2 center = canvasToStroke * surface.GetCenter();
        Vector2 right = canvasToStroke * (surface.GetCenter() + new Vector2(surface.Size.X * 0.5f, 0));
        Vector2 bottom = canvasToStroke * (surface.GetCenter() + new Vector2(0, surface.Size.Y * 0.5f));
        return new EllipseGeometry(center, new Vector2(center.DistanceTo(right), center.DistanceTo(bottom)));
    }

    private void LayoutStoveInputs()
    {
        if (!IsInstanceValid(_stoveDropZone) || !IsInstanceValid(_stroke) || _canvas.Size.X <= 0 || _canvas.Size.Y <= 0)
        {
            return;
        }

        Rect2 surface = _canvas.GetSurfaceRect();
        Rect2 surfaceOnStage = new(_canvas.Position + surface.Position, surface.Size);
        Rect2 inputRect = surfaceOnStage.Grow(42);
        _stoveDropZone.SetAnchorsPreset(LayoutPreset.TopLeft);
        _stroke.SetAnchorsPreset(LayoutPreset.TopLeft);
        Place(_stoveDropZone, inputRect.Position.X, inputRect.Position.Y, inputRect.Size.X, inputRect.Size.Y);
        Place(_stroke, inputRect.Position.X, inputRect.Position.Y, inputRect.Size.X, inputRect.Size.Y);
        _stroke.PancakeRadius = surface.Size.X * 0.5f;
    }

    private void TryPlaceBatter()
    {
        if (_batterDropAnimating)
        {
            return;
        }

        _canvas.BatterDropProgress = 0;
        if (!Execute(PancakeCommand.PlaceBatter))
        {
            _canvas.BatterDropProgress = 1;
            return;
        }

        _batterDropAnimating = true;
        Render();
        StartBatterDropAnimation();
    }
    private void StartBatterDropAnimation()
    {
        Vector2 size = _batterLadle.Size;
        Transform2D globalToLocal = GetGlobalTransform().AffineInverse();
        Vector2 source = globalToLocal * _batterItem.GetGlobalRect().GetCenter();
        Vector2 surfaceCenter = _canvas.GetGlobalTransform() * _canvas.GetSurfaceRect().GetCenter();
        Vector2 target = globalToLocal * surfaceCenter;

        _batterLadle.Position = source - size * 0.5f;
        _batterLadle.PivotOffset = size * 0.5f;
        _batterLadle.RotationDegrees = 0;
        _batterLadle.Scale = Vector2.One;
        _batterLadle.Modulate = Colors.White;
        _batterLadle.Visible = true;

        _batterTween?.Kill();
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _batterTween = tween;
        tween.TweenProperty(_batterLadle, "position", target - size * 0.5f, 0.22);
        tween.Parallel().TweenProperty(_batterLadle, "rotation_degrees", -24.0f, 0.22);
        tween.TweenMethod(Callable.From<float>(value => _canvas.BatterDropProgress = value), 0.0f, 1.0f, 0.13);
        tween.Parallel().TweenProperty(_batterLadle, "scale", new Vector2(0.92f, 0.92f), 0.13);
        tween.Finished += () =>
        {
            if (_batterTween != tween) return;
            _batterTween = null;
            FinishBatterDropAnimation();
        };
    }
    private void FinishBatterDropAnimation()
    {
        Tween? tween = _batterTween;
        _batterTween = null;
        tween?.Kill();
        if (_batterLadle is not null)
        {
            _batterLadle.Visible = false;
        }
        if (_canvas is not null)
        {
            _canvas.BatterDropProgress = 1;
        }
        if (!_batterDropAnimating)
        {
            return;
        }
        _batterDropAnimating = false;
        Render();
    }
    private bool Execute(PancakeCommand command, string? id = null)
    {
        if (!_initialized || !CanInteract) return false;
        YoutiaoQuality? consumedYoutiao = null;
        PancakeActionResult result = Machine.TryExecute(command, id, ingredient =>
        {
            if (ingredient != StableIds.Ingredients.Youtiao) return Inventory.TryConsume(ingredient);
            if (FryerMachine?.Inventory.TryTake(out YoutiaoQuality quality) != true) return false;
            consumedYoutiao = quality;
            return true;
        });
        if (!result.Success)
        {
            Reject(result.Message);
            return false;
        }

        LearnPancakeAction(command, id);
        if (command == PancakeCommand.CompleteSauce) _stroke.CancelStroke();

        if (consumedYoutiao is YoutiaoQuality quality)
        {
            Machine.TrySetInternalYoutiaoQuality(quality);
            YoutiaoConsumed?.Invoke(1);
        }

        if (command is PancakeCommand.CompleteSpread or PancakeCommand.AddEgg) _audio.Play(PancakeSound.Sizzle);
        else if (command == PancakeCommand.Flip) _audio.Play(PancakeSound.Flip);
        Inform(result.Message, false);
        return true;
    }
    private bool CanLoadRawYoutiao() => _initialized && CanInteract && !_drag.IsDragging && FryerMachine is not null
        && FryerMachine.Runtime.State is FryerState.Empty or FryerState.Loaded
        && FryerMachine.Runtime.Quantity < FryerMachine.Level.Capacity;

    private Control CreateYoutiaoDragPreview() => new TextureRect
    {
        Name = "YoutiaoQualityPreview",
        Texture = _art.Ingredient(StableIds.Ingredients.Youtiao),
        ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
        StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
        MouseFilter = MouseFilterEnum.Ignore,
        Modulate = FryerMachine?.Inventory.TryPeek(out YoutiaoQuality quality) == true
            ? YoutiaoPresentation.Tint(quality) : Colors.White,
    };
    private void ExecuteFryer(FryerCommand command)
    {
        if (FryerMachine is null || !CanInteract) return;
        FryerActionResult result = FryerMachine.TryExecute(command);
        if (!result.Success) Reject(result.Message);
        else
        {
            LearnWorkbenchAction(command switch
            {
                FryerCommand.LoadOne => "fryer:load",
                FryerCommand.LowerBasket => "fryer:lower",
                FryerCommand.RaiseBasket => "fryer:raise",
                _ => "discard",
            });
            if (command == FryerCommand.LoadOne) _audio.Play(PancakeSound.PickUp);
            else if (command == FryerCommand.LowerBasket) _audio.Play(PancakeSound.Sizzle);
            else if (command == FryerCommand.RaiseBasket) _audio.Play(PancakeSound.Flip);
            Inform(result.Message, false);
        }
    }
    private bool CanDeliverPayload(string id) => CanInteract && id switch
    {
        "finished_pancake" => HasDeliveryTarget && HasFinishedPancake && !IsTransferringBag,
        StoredYoutiaoPayload => HasDeliveryTarget && FryerMachine?.Inventory.Count > 0,
        SoyMilkPayload => HasDeliveryTarget && SoyMilkTray?.CanStartDrag == true,
        _ => false,
    };
    private bool HasDeliveryTarget => CanSubmitToSelectedCustomer?.Invoke() ?? true;
    private void DeliverPayload(string id)
    {
        if (id == "finished_pancake") Submit();
        else if (id == StoredYoutiaoPayload) SubmitStandalone(ProductKind.Youtiao);
        else if (id == SoyMilkPayload) SubmitStandalone(ProductKind.SoyMilk);
    }
    private bool CanTrashPayload(string id) => CanInteract && id switch
    {
        "finished_pancake" => HasFinishedPancake && !IsTransferringBag,
        StoredYoutiaoPayload => FryerMachine?.Inventory.Count > 0,
        _ => false,
    };
    private void DiscardPayload(string id)
    {
        if (id == "finished_pancake")
        {
            if (UseServingTray)
            {
                if (PancakeTray.Selected is PreparedPancake prepared && PancakeTray.TryTake(prepared))
                {
                    LearnWorkbenchAction("discard");
                    Render();
                    Inform("选中的装袋煎饼已丢弃。", false);
                }
                return;
            }
            if (Machine.TryExecute(PancakeCommand.Discard).Success)
            {
                LearnWorkbenchAction("discard");
                _stroke.ResetCoverage();
                Inform("装袋煎饼已丢弃。", false);
            }
            return;
        }
        if (id == StoredYoutiaoPayload && FryerMachine?.Inventory.TryTake(out _) == true)
        {
            LearnWorkbenchAction("discard");
            Inform("一根库存油条已丢弃。", false);
        }
    }
    private void SubmitStandalone(ProductKind kind)
    {
        if (SubmitProduct is null)
        {
            Reject("当前没有可用的出餐目标。");
            return;
        }
        if (SubmitProduct(kind)) _audio.Play(PancakeSound.Success);
    }
    private void RefillSoyMilk()
    {
        if (!CanInteract || SoyMilkTray?.TryBeginRefill() != true) Reject("豆浆托盘已满或当前不能补货。");
        else { LearnWorkbenchAction("refill:soy_milk"); Inform("开始补豆浆，0.6 秒后补满。", false); }
    }
    private void Refill(string id)
    {
        if (!CanInteract || !Inventory.TryBeginRefill(id)) Reject("料盒已满或正在补料。");
        else { LearnWorkbenchAction($"refill:{id}"); Inform($"{IngredientName(id)}开始补货，{Inventory.LevelData.RefillSeconds:0.0} 秒后补满。", false); }
    }
    private void Discard()
    {
        PancakeActionResult result = Machine.TryExecute(PancakeCommand.Discard);
        if (!result.Success) Reject(result.Message); else { LearnWorkbenchAction("discard"); _stroke.ResetCoverage(); Inform("炉面已清理。", false); }
    }
    private void Submit()
    {
        if (SubmitPrepared is null)
        {
            Reject("当前没有可用的出餐目标。");
            return;
        }

        PancakeQuality quality = Machine.TryGetPrepared(out PreparedPancake prepared)
            ? prepared.Quality
            : PancakeQuality.Burnt;
        if (SubmitPrepared(Machine))
        {
            _audio.Play(quality == PancakeQuality.Overdone ? PancakeSound.Overdone : PancakeSound.Success);
            Machine.TryExecute(PancakeCommand.Discard);
            _stroke.ResetCoverage();
        }
    }
    private void Render()
    {
        if (!_initialized) return;
        if (UseServingTray && Machine.TryGetPrepared(out PreparedPancake prepared))
        {
            PancakeTray.Add(prepared);
            _baggedPresented = true;
            _bagTransferRemaining = ReducedMotion ? 0 : BagTransferDuration;
            _stroke.ResetCoverage();
            // Discard resets only the stove; the tray owns the completed snapshot.
            Machine.TryExecute(PancakeCommand.Discard);
            TickBagTransfer(0);
            return;
        }
        PancakeState state = Machine.Runtime.State;
        IReadOnlySet<string>? requiredToppings = RequiredToppingsForSelectedCustomer?.Invoke();
        foreach ((string id, IngredientStockSlotView slot) in _ingredientSlots)
        {
            bool enabled = _enabledIngredients.Contains(id);
            slot.Visible = enabled;
            if (!enabled)
            {
                _lowStockNotified.Remove(id);
                continue;
            }
            int quantity = Inventory.GetQuantity(id);
            int capacity = Inventory.GetCapacity(id);
            IngredientStockStatus status = Inventory.GetStatus(id);
            slot.RenderStock(quantity, capacity, status, Inventory.GetRefillProgress(id), CanInteract, Inventory.IsUnlimited(id));
            slot.SetAttention(ResolveIngredientAttention(id, status, state, requiredToppings));
            if (status is IngredientStockStatus.Low or IngredientStockStatus.Empty)
            {
                if (_lowStockNotified.Add(id))
                {
                    string message = status == IngredientStockStatus.Empty
                        ? $"{IngredientName(id)}已经用完，{(UseServingTray ? "长按" : "点击 + ")}补货。"
                        : UseServingTray ? $"{IngredientName(id)}快用完了，长按补货。"
                        : $"{IngredientName(id)}只剩 {quantity} 份，可以点击 + 补货。";
                    if (_tutorialMemory && !NeedsTeaching($"refill:{id}"))
                        message = status == IngredientStockStatus.Empty ? $"{IngredientName(id)}已用完。" : $"{IngredientName(id)}余量不足。";
                    Inform(message, false);
                }
            }
            else if (status == IngredientStockStatus.Normal)
            {
                _lowStockNotified.Remove(id);
            }
        }
        UpdateBagPresentation(state);
        SetContextAction(_flip, state is PancakeState.SideAReady or PancakeState.SideAOverdone);
        SetContextAction(_finishSauce, state == PancakeState.Saucing);
        SetContextAction(_fold, state is PancakeState.Sauced or PancakeState.Toppings);
        SetContextAction(_bag, state == PancakeState.Folded);
        SetContextAction(_discard, state == PancakeState.Burnt);
        _pancakeActions.Visible = _flip.Visible || _finishSauce.Visible || _fold.Visible || _bag.Visible || _discard.Visible;
        if (UseServingTray)
        {
            Rect2 footer = _pancakeActions.Visible ? TianjinWorkbenchLayout.StoveFooterWithAction : TianjinWorkbenchLayout.StoveFooter;
            _pancakeStatusTag.CustomMinimumSize = footer.Size;
            Place(_pancakeStatusTag, footer);
        }
        if (_lastPancakeState is PancakeState previousPancake && previousPancake != state && IsPancakeAttentionState(state))
            PulseAttention(_canvas, state == PancakeState.Burnt ? TianjinUi.Red : state == PancakeState.SideAOverdone ? TianjinUi.Orange : TianjinUi.Yellow);
        _lastPancakeState = state;
        _fryerPanel.Visible = FryerMachine is not null;
        if (FryerMachine is not null)
        {
            FryerBatchRuntime fryer = FryerMachine.Runtime;
            _fryerVisual.Refresh();
            _fryerStatus.Text = FryerStatus(FryerMachine);
            _fryerStatus.Modulate = fryer.State == FryerState.Burnt ? TianjinUi.Red
                : fryer.State == FryerState.Frying && fryer.Quality == YoutiaoQuality.Golden ? TianjinUi.Orange
                : TianjinUi.BrownText;
            _fryerStock.Text = UseServingTray ? string.Empty : FryerMachine.Inventory.Count.ToString();
            if (UseServingTray)
            {
                _finishedYoutiaoSlot.SetStock(FryerMachine.Inventory.Count, FryerMachine.Inventory.Capacity);
                _finishedYoutiaoSlot.ShowEmptyCaption(FryerMachine.Inventory.Count == 0);
            }
            _finishedYoutiaoSlot.SetWideStockTints(YoutiaoPresentation.RackTints(
                FryerMachine.Inventory.Items, UseServingTray ? _finishedYoutiaoSlot.StockTier : 1));
            _storedYoutiao.TooltipText = FryerMachine.Inventory.TryPeek(out YoutiaoQuality nextQuality)
                ? $"熟油条 · 下一根{QualityName(nextQuality)} · 拖到煎饼或交给顾客"
                : "熟油条 · 暂无成品";
            _storedYoutiao.Visible = FryerMachine.Inventory.Count > 0;
            bool youtiaoRequired = state is PancakeState.Sauced or PancakeState.Toppings
                && requiredToppings?.Contains(StableIds.Ingredients.Youtiao) == true
                && !Machine.Runtime.ExtraIngredients.Contains(StableIds.Ingredients.Youtiao);
            _finishedYoutiaoSlot.SetIngredientAvailable(FryerMachine.Inventory.Count > 0);
            _finishedYoutiaoSlot.SetAttention(FryerMachine.Inventory.Count == 0 && youtiaoRequired
                ? WorkstationSlotAttentionState.Empty
                : youtiaoRequired
                    ? WorkstationSlotAttentionState.Required
                    : WorkstationSlotAttentionState.Normal);
            SetContextAction(_lowerBasket, fryer.State == FryerState.Loaded);
            SetContextAction(_raiseBasket, fryer.State == FryerState.Frying && !FryerMachine.Level.AutoRaise);
            SetContextAction(_discardBatch, fryer.State == FryerState.Burnt);
            _fryerActions.Visible = _lowerBasket.Visible || _raiseBasket.Visible || _discardBatch.Visible;
            bool fryerAttention = _lastFryerState is FryerState previousFryer && previousFryer != fryer.State
                && fryer.State is FryerState.Draining or FryerState.Raised or FryerState.Burnt;
            bool goldenAttention = _lastFryerQuality is YoutiaoQuality previousQuality
                && previousQuality != fryer.Quality && fryer.State == FryerState.Frying && fryer.Quality == YoutiaoQuality.Golden;
            if (fryerAttention || goldenAttention)
                PulseAttention(_fryerVisual, fryer.State == FryerState.Burnt ? TianjinUi.Red : TianjinUi.Yellow);
            if (goldenAttention) _audio.Play(PancakeSound.Ready);
            if (_lastFryerState is FryerState previousState && previousState != fryer.State)
            {
                if (fryer.State == FryerState.Stored) _audio.Play(PancakeSound.Success);
                else if (fryer.State == FryerState.Burnt) _audio.Play(PancakeSound.Error);
            }
            _lastFryerState = fryer.State;
            _lastFryerQuality = fryer.Quality;
        }
        _deliveryZone.Visible = !DirectCustomerDelivery;
        _directDeliveryHint.Visible = DirectCustomerDelivery || UseServingTray;
        _soyPanel.Visible = SoyMilkTray is not null;
        if (SoyMilkTray is not null)
        {
            int shownCups = SoyMilkTray.Quantity;
            if (SoyMilkTray.IsRefilling)
                shownCups += (int)Math.Floor((SoyMilkTray.Capacity - shownCups) * SoyMilkTray.RefillProgress);
            _soyStockArt?.RenderQuantity(shownCups);
            _soyStatus.Text = UseServingTray
                ? SoyMilkTray.IsRefilling ? "补货中" : SoyMilkTray.IsTaking ? "取杯中" : string.Empty
                : SoyMilkTray.IsRefilling ? $"豆浆 {SoyMilkTray.RefillProgress:P0}" : SoyMilkTray.IsTaking ? "豆浆 · 取杯中" : $"豆浆 ×{SoyMilkTray.Quantity}";
            if (UseServingTray && SoyMilkTray.Quantity <= 2 && !SoyMilkTray.IsRefilling && !SoyMilkTray.IsTaking)
                _soyStatus.Text = "长按补货";
            _soyStatus.Visible = !UseServingTray || !string.IsNullOrEmpty(_soyStatus.Text);
            _soyRefill.Text = SoyMilkTray.IsRefilling ? "…" : "+";
            _soyRefill.Visible = !UseServingTray && (SoyMilkTray.Quantity < SoyMilkTray.Capacity || SoyMilkTray.IsRefilling);
            _soyRefill.Disabled = !CanInteract || SoyMilkTray.Quantity >= SoyMilkTray.Capacity || SoyMilkTray.IsRefilling || SoyMilkTray.IsTaking;
            _soyRefill.TooltipText = SoyMilkTray.IsRefilling ? "豆浆补货中" : "补满豆浆";
            if (_soyHoldProgress is not null && SoyMilkTray.IsRefilling)
            {
                _soyHoldProgress.Visible = true;
                _soyHoldProgress.Value = SoyMilkTray.RefillProgress * 100;
            }
            else if (_soyHoldProgress is not null && !_stockGestures.Any(gesture => gesture.HoldProgress > 0))
                _soyHoldProgress.Visible = false;
        }
        RenderLive();
    }
    private void RenderLive()
    {
        if (!_initialized) return;
        _state.Text = _batterDropAnimating ? "正在落浆"
            : UseServingTray && IsTransferringBag && Machine.Runtime.State == PancakeState.Empty
                ? "正在放入成品托盘 · 可继续摊饼"
            : DirectCustomerDelivery && Machine.Runtime.State == PancakeState.Bagged ? "拖给顾客"
            : PancakeStatus(Machine.Runtime);
        _state.Modulate = Colors.White;
        _state.AddThemeColorOverride("font_color", Machine.Runtime.State switch
        {
            PancakeState.SideAReady => TianjinUi.Green,
            PancakeState.SideAOverdone => TianjinUi.Orange,
            PancakeState.Burnt => TianjinUi.Red,
            _ => TianjinUi.BrownText,
        });
        _canvas.QueueRedraw();
        _stroke.RefreshVisualState();
        RenderTutorial();
    }

    private void UpdateBagPresentation(PancakeState state)
    {
        if (UseServingTray)
        {
            _finished.Visible = HasFinishedPancake && !IsTransferringBag;
            _directDeliveryHint.Text = HasFinishedPancake ? "拖给顾客" : "成品盘";
            string recipe = PancakeTray.Selected is PreparedPancake selected
                ? selected.ExtraIngredients.Count == 0 ? "原味" : string.Join("、", selected.ExtraIngredients.OrderBy(id => id).Select(IngredientName))
                : string.Empty;
            string quality = PancakeTray.Selected?.Quality == PancakeQuality.Overdone ? "偏焦" : "火候正好";
            string sauce = PancakeTray.Selected is PreparedPancake sauced ? SauceRules.Describe(sauced.SauceAmount) : string.Empty;
            _finished.TooltipText = $"第 {PancakeTray.SelectedIndex + 1} 张 / 共 {PancakeTray.Count} 张\n{recipe} · {quality}\n酱量 {sauce}\n拖给顾客，或拖到垃圾桶丢弃";
            foreach (Button? button in new[] { _previousPancake, _nextPancake })
                if (button is not null)
                {
                    button.Visible = PancakeTray.Count > 1;
                    button.Disabled = !CanInteract || _drag.IsDragging || IsTransferringBag;
                }
            return;
        }
        if (state != PancakeState.Bagged) ResetBagPresentation();
        else if (UseServingTray && !_baggedPresented)
        {
            _baggedPresented = true;
            _bagTransferRemaining = ReducedMotion ? 0 : BagTransferDuration;
            TickBagTransfer(0);
        }
        _finished.Visible = state == PancakeState.Bagged && !IsTransferringBag;
    }

    private void TickBagTransfer(double delta)
    {
        if (!UseServingTray || !IsTransferringBag) return;
        _bagTransferRemaining = Math.Max(0, _bagTransferRemaining - delta);
        float progress = Mathf.SmoothStep(0, 1, (float)(1 - _bagTransferRemaining / BagTransferDuration));
        Transform2D toLocal = GetGlobalTransform().AffineInverse();
        Vector2 origin = toLocal * (_canvas.GetGlobalTransform() * _canvas.GetSurfaceRect().GetCenter());
        Vector2 target = toLocal * (_finished.GetGlobalTransform()
            * (TianjinWorkbenchLayout.FinishedArtPosition + TianjinWorkbenchLayout.FinishedVisual * 0.5f));
        _bagTransfer.Position = origin.Lerp(target, progress) - _bagTransfer.Size * 0.5f;
        _bagTransfer.Visible = IsTransferringBag;
        _finished.Visible = !IsTransferringBag && HasFinishedPancake;
        if (!IsTransferringBag) Render();
    }

    private void ResetBagPresentation()
    {
        _baggedPresented = false;
        _bagTransferRemaining = 0;
        if (IsInstanceValid(_bagTransfer)) _bagTransfer.Visible = false;
    }
    private void Reject(string message) { _audio.Play(PancakeSound.Error); Inform(message, true); }
    private void Inform(string message, bool error) => Feedback?.Invoke(message, error);
    private static string QualityName(YoutiaoQuality quality) => YoutiaoPresentation.Name(quality);
    private string FryerStatus(FryerStateMachine machine) => machine.Runtime.State switch
    {
        FryerState.Empty => UseServingTray ? "点击面坯 · 长按连续装入" : $"空篮 · 0/{machine.Level.Capacity} · 点击面坯装料",
        FryerState.Loaded => UseServingTray ? "待下锅" : $"待下锅 · {machine.Runtime.Quantity}/{machine.Level.Capacity}",
        FryerState.Frying when machine.Runtime.Quality == YoutiaoQuality.Golden && !machine.Level.AutoRaise => "金黄 · 可以抬篮",
        FryerState.Frying => $"炸制中 · {QualityName(machine.Runtime.Quality)}",
        FryerState.Raised => "成品区已满 · 等待空位",
        FryerState.Draining => "抬篮沥油中",
        FryerState.Burnt => "已经焦糊 · 需要清理",
        _ => "空篮",
    };
    internal static string PancakeStatus(PancakeRuntime runtime) => runtime.State switch
    {
        PancakeState.Empty => "拖入面糊 · 开始摊饼",
        PancakeState.BatterPlaced or PancakeState.Spreading => $"按住左键划动摊面 · {runtime.SpreadCoverage:P0}",
        PancakeState.Spread => "点击鸡蛋",
        PancakeState.SideACooking => $"第一面加热 · {runtime.CookingSeconds:0.0} 秒{(runtime.HasEgg ? "" : " · 可加鸡蛋")}",
        PancakeState.SideAReady => "火候正好 · 点击翻面",
        PancakeState.SideAOverdone => "颜色变深 · 立即翻面",
        PancakeState.SideBCooking or PancakeState.SideBReady => "点击酱罐 · 拿起酱刷",
        PancakeState.Saucing => $"按住刷酱 · {SauceRules.Describe(runtime.SauceCoverage)}",
        PancakeState.Sauced or PancakeState.Toppings => $"添加配料 · {SauceRules.Describe(runtime.SauceCoverage)}",
        PancakeState.Folded => "点击装袋",
        PancakeState.Bagged => "拖到出餐口",
        PancakeState.Burnt => "已经焦糊 · 点击清理",
        _ => "制作中",
    };

    private WorkstationSlotAttentionState ResolveIngredientAttention(
        string id,
        IngredientStockStatus stockStatus,
        PancakeState pancakeState,
        IReadOnlySet<string>? requiredToppings)
    {
        if (stockStatus == IngredientStockStatus.Refilling) return WorkstationSlotAttentionState.Refilling;
        if (stockStatus == IngredientStockStatus.Empty) return WorkstationSlotAttentionState.Empty;
        if (!CanInteract) return stockStatus == IngredientStockStatus.Low
            ? WorkstationSlotAttentionState.LowStock : WorkstationSlotAttentionState.Normal;
        if (UseServingTray && id == StableIds.Ingredients.Sauce && pancakeState is PancakeState.SideBCooking or PancakeState.SideBReady or PancakeState.Saucing)
            return WorkstationSlotAttentionState.Actionable;
        if (id == StableIds.Ingredients.Batter && pancakeState == PancakeState.Empty)
            return WorkstationSlotAttentionState.Required;
        if (id == StableIds.Ingredients.Egg && !Machine.Runtime.HasEgg
            && pancakeState is PancakeState.SideACooking or PancakeState.SideAReady or PancakeState.SideAOverdone)
            return WorkstationSlotAttentionState.Required;
        if (pancakeState is PancakeState.Sauced or PancakeState.Toppings)
        {
            bool alreadyAdded = Machine.Runtime.ExtraIngredients.Contains(id);
            if (!alreadyAdded && requiredToppings?.Contains(id) == true)
                return WorkstationSlotAttentionState.Required;
            if (!alreadyAdded && id is StableIds.Ingredients.Crispy or StableIds.Ingredients.Scallion or StableIds.Ingredients.Ham)
                return WorkstationSlotAttentionState.Actionable;
        }
        if (stockStatus == IngredientStockStatus.Low) return WorkstationSlotAttentionState.LowStock;
        return WorkstationSlotAttentionState.Normal;
    }

    private void SetContextAction(Button button, bool visible)
    {
        button.Visible = visible;
        button.Disabled = !CanInteract;
    }

    private static bool IsPancakeAttentionState(PancakeState state) => state is
        PancakeState.SideAReady or PancakeState.SideAOverdone or PancakeState.Folded or PancakeState.Bagged or PancakeState.Burnt;

    private static string IngredientName(string id) => id switch
    {
        StableIds.Ingredients.Batter => "面糊",
        StableIds.Ingredients.Egg => "鸡蛋",
        StableIds.Ingredients.Sauce => "酱料",
        StableIds.Ingredients.Crispy => "薄脆",
        StableIds.Ingredients.Scallion => "香葱",
        StableIds.Ingredients.Ham => "火腿",
        StableIds.Ingredients.Youtiao => "油条",
        _ => "食材",
    };

    private void OnDragEnded(DragResult result)
    {
        if (result.Completion is DragCompletion.Accepted or DragCompletion.Cancelled) return;
        if (result.Completion == DragCompletion.Rejected && result.Zone == _deliveryZone)
        {
            Reject(!HasDeliveryTarget ? "请先选择顾客，再把早餐送到出餐口。" : "当前商品还不能出餐。");
            return;
        }
        Reject(result.Completion == DragCompletion.Rejected ? "该位置当前不能接收这件物品。" : "拖放位置无效。");
    }

    private void PulseAttention(Control control, Color tint)
    {
        if (!IsInstanceValid(control) || control.IsQueuedForDeletion()) return;
        control.PivotOffset = control.Size * 0.5f;
        if (_interactionTweens.Remove(control, out Tween? previous)) previous.Kill();
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _interactionTweens[control] = tween;
        if (!ReducedMotion) tween.TweenProperty(control, "scale", new Vector2(1.025f, 1.025f), 0.12);
        tween.Parallel().TweenProperty(control, "modulate", new Color(tint, 1), 0.12);
        tween.TweenProperty(control, "scale", Vector2.One, 0.16);
        tween.Parallel().TweenProperty(control, "modulate", Colors.White, 0.16);
        tween.Finished += () => _interactionTweens.Remove(control);
    }

    private void ConfigureArtInteraction(Control control, Control? visualTarget = null)
    {
        Control target = visualTarget ?? control;
        control.MouseEntered += () => AnimateArtInteraction(target, 1.035f, new Color(1.08f, 1.08f, 1.04f, 1), 0.12);
        control.MouseExited += () => AnimateArtInteraction(target, 1f, Colors.White, 0.12);
        if (control is BaseButton button)
        {
            button.ButtonDown += () => AnimateArtInteraction(target, 0.98f, new Color(0.94f, 0.94f, 0.94f, 1), 0.10);
            button.ButtonUp += () =>
            {
                bool hovered = control.GetGlobalRect().HasPoint(control.GetGlobalMousePosition());
                AnimateArtInteraction(target, hovered ? 1.035f : 1f, hovered ? new Color(1.08f, 1.08f, 1.04f, 1) : Colors.White, 0.12);
            };
        }
        if (control is DragItem dragItem) dragItem.StartRejected += () => PulseRejected(target);
    }
    private void AnimateArtInteraction(Control control, float targetScale, Color targetModulate, double duration)
    {
        if (!IsInstanceValid(control) || control.IsQueuedForDeletion()) return;
        control.PivotOffset = control.Size * 0.5f;
        if (_interactionTweens.Remove(control, out Tween? previous)) previous.Kill();
        if (ReducedMotion)
        {
            control.Scale = Vector2.One;
            targetScale = 1f;
        }
        Tween tween = CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _interactionTweens[control] = tween;
        tween.TweenProperty(control, "scale", Vector2.One * targetScale, duration);
        tween.TweenProperty(control, "modulate", targetModulate, duration);
        tween.Finished += () => _interactionTweens.Remove(control);
    }
    private void PulseRejected(Control control)
    {
        if (!IsInstanceValid(control) || control.IsQueuedForDeletion()) return;
        control.PivotOffset = control.Size * 0.5f;
        if (_interactionTweens.Remove(control, out Tween? previous)) previous.Kill();
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _interactionTweens[control] = tween;
        if (!ReducedMotion) tween.TweenProperty(control, "scale", new Vector2(0.96f, 0.96f), 0.10);
        tween.Parallel().TweenProperty(control, "modulate", new Color(1f, 0.72f, 0.68f, 1), 0.10);
        tween.TweenProperty(control, "scale", Vector2.One, 0.14);
        tween.Parallel().TweenProperty(control, "modulate", Colors.White, 0.14);
        tween.Finished += () => _interactionTweens.Remove(control);
    }
    private static bool ReducedMotion => ProjectSettings.HasSetting("accessibility/reduce_motion")
        && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();
    private static void Place(Control control, float x, float y, float width, float height) { control.Position = new Vector2(x, y); control.Size = new Vector2(width, height); }
    private static void Place(Control control, Rect2 rect) { control.Position = rect.Position; control.Size = rect.Size; }
    private static void FullRect(Control c, float l, float t, float r, float b) { c.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); c.OffsetLeft = l; c.OffsetTop = t; c.OffsetRight = r; c.OffsetBottom = b; }
}
