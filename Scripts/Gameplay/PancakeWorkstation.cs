using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Pancake;
using ProjectCake.Fryer;
using ProjectCake.UI;

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

    private const string RawYoutiaoPayload = "raw_youtiao";
    private const string StoredYoutiaoPayload = "stored_youtiao";
    private const string SoyMilkPayload = "soy_milk_cup";

    private readonly Dictionary<string, IngredientStockSlotView> _ingredientSlots = new(StringComparer.Ordinal);
    private readonly HashSet<string> _lowStockNotified = new(StringComparer.Ordinal);
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
    private Label? _finishedTrayLabel;
    private Label _state = null!;
    private Button _flip = null!;
    private Button _fold = null!;
    private Button _bag = null!;
    private Button _discard = null!;
    private Control _pancakeActions = null!;
    private Control _fryerPanel = null!;
    private FryerVisualView _fryerVisual = null!;
    private Label _fryerStatus = null!;
    private Label _fryerStock = null!;
    private WorkstationSlotView _finishedYoutiaoSlot = null!;
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
    public Func<PancakeStateMachine, bool>? SubmitPrepared { get; set; }
    public Func<ProductKind, bool>? SubmitProduct { get; set; }
    public Func<bool>? CanSubmitToSelectedCustomer { get; set; }
    public Func<IReadOnlySet<string>?>? RequiredToppingsForSelectedCustomer { get; set; }
    public bool InteractionEnabled { get; set; } = true;
    public bool Paused { get; set; }
    public bool DirectCustomerDelivery { get; set; }
    // Set before adding the workstation to the tree. Legacy/practice views opt out.
    public bool UseServingTray { get; init; }
    internal bool IsTransferringBag => _bagTransferRemaining > 0;

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
        "finished_pancake" => Machine.Runtime.State == PancakeState.Bagged && !IsTransferringBag,
        StoredYoutiaoPayload => FryerMachine?.Inventory.Count > 0,
        SoyMilkPayload => SoyMilkTray?.CanStartDrag == true,
        _ => false,
    };

    public bool DeliverToCustomer(string payload, Func<bool> deliver)
    {
        if (!CanDeliverProduct(payload) || !deliver()) return false;
        _audio.Play(PancakeSound.Success);
        if (payload == "finished_pancake")
        {
            Machine.TryExecute(PancakeCommand.Discard);
            _stroke.ResetCoverage();
        }
        Render();
        return true;
    }

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog, int stoveLevel, int stationLevel, int fryerLevel = 0, DayConfig? config = null, TianjinArtCatalog? art = null)
    {
        _art = art ?? _art;
        _stoveLevel = stoveLevel;
        _lastPancakeState = null;
        _lastFryerState = null;
        _lastFryerQuality = null;
        ResetBagPresentation();
        Machine = new PancakeStateMachine(catalog.StovesByLevel[stoveLevel]);
        Inventory = new IngredientInventory(catalog.IngredientStationsByLevel[stationLevel]);
        Machine.Changed += Render;
        Inventory.Changed += Render;
        _canvas.Bind(Machine.Runtime, _art, stoveLevel);
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
            return;
        }
        Machine.Tick(deltaSeconds);
        TickBagTransfer(deltaSeconds);
        Inventory.Tick(deltaSeconds);
        FryerMachine?.Tick(deltaSeconds);
        _fryerVisual.Tick(deltaSeconds);
        SoyMilkTray?.Tick(deltaSeconds);
        RenderLive();
    }

    public void CancelInput()
    {
        _drag.CancelDrag();
        _stroke.CancelStroke();
        FinishBatterDropAnimation();
    }

    internal void RefreshForCapture() => Render();

    public void ResetForDay()
    {
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
        Render();
        return true;
    }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        _art = new TianjinArtCatalog();
        _drag = new DragService();
        AddChild(_drag);
        _drag.Configure(this);
        _audio = new PancakeAudio();
        AddChild(_audio);

        var stage = new Control();
        TianjinUi.FullRect(stage);
        AddChild(stage);
        Control fryer = BuildFryer();
        Place(fryer, FryerAreaRect);
        stage.AddChild(fryer);
        Control stove = BuildStove();
        Place(stove, StoveAreaRect);
        stage.AddChild(stove);
        Control ingredients = BuildIngredients();
        Place(ingredients, UseServingTray ? TianjinWorkbenchLayout.Ingredients : IngredientAreaRect);
        stage.AddChild(ingredients);
        Control delivery = BuildDelivery();
        Place(delivery, UseServingTray ? TianjinWorkbenchLayout.Utilities : UtilityAreaRect);
        stage.AddChild(delivery);
        _batterLadle = new TextureRect
        {
            Texture = _art.Ingredient(StableIds.Ingredients.Batter),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            MouseFilter = MouseFilterEnum.Ignore,
            Size = new Vector2(112, 112),
            CustomMinimumSize = new Vector2(112, 112),
            Visible = false,
            ZIndex = 900,
        };
        AddChild(_batterLadle);
        _bagTransfer = TianjinUi.Texture(_art.FinishedPancake, TianjinWorkbenchLayout.FinishedVisual);
        _bagTransfer.Name = "BagTransferVisual";
        _bagTransfer.Visible = false;
        _bagTransfer.ZIndex = 900;
        AddChild(_bagTransfer);
        _drag.DragStarted += _ => _audio.Play(PancakeSound.PickUp);
        _drag.DragEnded += OnDragEnded;
    }

    private Control BuildFryer()
    {
        var root = FramelessRoot("FryerArea", 520);
        _fryerPanel = root;
        Label title = FloatingText("油条", 21, TianjinUi.BrownText);
        if (UseServingTray) title.HorizontalAlignment = HorizontalAlignment.Center;
        Place(title, UseServingTray ? 12 : 4, UseServingTray ? 306 : 0, UseServingTray ? 304 : 330, 32);
        root.AddChild(title);

        var fryerStack = new Control { Name = "FryerStack" };
        Place(fryerStack, 0, 18, 340, 340);
        _fryerVisual = new FryerVisualView { Name = "FryerVisual", MouseFilter = MouseFilterEnum.Ignore };
        FullRect(_fryerVisual, 0, 0, 0, 0);
        fryerStack.AddChild(_fryerVisual);
        var basket = new DropZone { Name = "FryerBasketDropZone", HitPadding = 18 };
        FullRect(basket, 40, 54, -40, -106);
        basket.Configure(
            id => id == RawYoutiaoPayload && CanLoadRawYoutiao(),
            _ => ExecuteFryer(FryerCommand.LoadOne),
            _ => _fryerVisual.NextLoadSlotGlobalCenter());
        fryerStack.AddChild(basket);
        _drag.RegisterZone(basket);
        root.AddChild(fryerStack);

        var loadColumn = new VBoxContainer();
        Place(loadColumn, UseServingTray ? TianjinWorkbenchLayout.RawYoutiao : new Rect2(342, 48, 170, 150));
        var rawSlot = new WorkstationSlotView { Name = "RawYoutiaoSlot", SizeFlagsHorizontal = SizeFlags.ExpandFill };
        rawSlot.Configure(_art.IngredientTray, _art.RawYoutiao, "生油条",
            UseServingTray ? TianjinWorkbenchLayout.RawYoutiaoSlot() : RawYoutiaoSlotSpec(), IngredientVisualMode.WideSingle);
        var raw = new DragItem { Name = "RawYoutiaoInput" };
        raw.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        raw.Configure(_drag, RawYoutiaoPayload, "生油条", new Color("#F7D892"), new DragVisualSpec(_art.RawYoutiao, UseServingTray ? TianjinWorkbenchLayout.RawYoutiaoDragVisual : new Vector2(105, 105)), CanLoadRawYoutiao);
        raw.StartRejected += () => Reject("炸篮当前不能继续装料。");
        rawSlot.SetInteraction(raw);
        ConfigureArtInteraction(raw, rawSlot.HoverTarget);
        loadColumn.AddChild(rawSlot);
        root.AddChild(loadColumn);

        PanelContainer fryerStatusTag = StatusTag("FryerStatusTag", new Vector2(UseServingTray ? 304 : 330, 40));
        Place(fryerStatusTag, 12, 350, UseServingTray ? 304 : 330, 40);
        _fryerStatus = Text("尚未解锁", 17, TianjinUi.BrownText, HorizontalAlignment.Center);
        _fryerStatus.VerticalAlignment = VerticalAlignment.Center;
        fryerStatusTag.AddChild(_fryerStatus);
        root.AddChild(fryerStatusTag);
        var actions = new HBoxContainer();
        Place(actions, UseServingTray ? 12 : 80, 398, UseServingTray ? 304 : 270, 54);
        _fryerActions = actions;
        _lowerBasket = ActionButton("下锅", () => ExecuteFryer(FryerCommand.LowerBasket));
        _raiseBasket = ActionButton("抬篮", () => ExecuteFryer(FryerCommand.RaiseBasket));
        _discardBatch = ActionButton("清理炸锅", () => ExecuteFryer(FryerCommand.Discard));
        _lowerBasket.Name = "FryerLowerAction";
        _raiseBasket.Name = "FryerRaiseAction";
        _discardBatch.Name = "FryerDiscardAction";
        actions.AddChild(_lowerBasket); actions.AddChild(_raiseBasket); actions.AddChild(_discardBatch);
        root.AddChild(actions);

        _finishedYoutiaoSlot = new WorkstationSlotView { Name = "FinishedYoutiaoArea" };
        Place(_finishedYoutiaoSlot, UseServingTray ? TianjinWorkbenchLayout.FinishedYoutiao : new Rect2(342, 224, 170, 132));
        _finishedYoutiaoSlot.Configure(
            _art.YoutiaoRack,
            _art.Ingredient(StableIds.Ingredients.Youtiao),
            "熟油条",
            UseServingTray ? TianjinWorkbenchLayout.FinishedYoutiaoSlot() : FinishedYoutiaoSlotSpec(),
            IngredientVisualMode.WideSingle);
        _fryerStock = _finishedYoutiaoSlot.CountLabel;
        _fryerStock.Name = "FinishedYoutiaoStock";
        _fryerStock.Text = "0";
        _storedYoutiao = new DragItem { Name = "FinishedYoutiaoDrag", Visible = false };
        _storedYoutiao.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        _storedYoutiao.Configure(_drag, StoredYoutiaoPayload, "熟油条", TianjinUi.Yellow, new DragVisualSpec(_art.Ingredient(StableIds.Ingredients.Youtiao), UseServingTray ? TianjinWorkbenchLayout.FinishedYoutiaoDragVisual : new Vector2(115, 105)), () => InteractionEnabled && !Paused && FryerMachine?.Inventory.Count > 0);
        _storedYoutiao.StartRejected += () => Reject("没有可用的成品油条。");
        ConfigureArtInteraction(_storedYoutiao, _finishedYoutiaoSlot.HoverTarget);
        _finishedYoutiaoSlot.SetInteraction(_storedYoutiao);
        root.AddChild(_finishedYoutiaoSlot);
        return root;
    }

    private Control BuildIngredients()
    {
        if (UseServingTray)
        {
            var fixedRoot = FramelessRoot("IngredientArea", TianjinWorkbenchLayout.Ingredients.Size.X);
            for (int index = 0; index < TianjinWorkbenchLayout.IngredientOrder.Length; index++)
            {
                string id = TianjinWorkbenchLayout.IngredientOrder[index];
                var ingredient = Ingredients.Single(item => item.Id == id);
                var slot = BuildIngredientSlot(id, ingredient.Name, ingredient.Color, ingredient.Drag);
                Place(slot, TianjinWorkbenchLayout.IngredientPlacement(index));
                fixedRoot.AddChild(slot);
            }
            return fixedRoot;
        }
        var root = FramelessRoot("IngredientArea", 794);
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 4);
        FullRect(column, 4, 0, -4, 0);
        root.AddChild(column);
        column.AddChild(FloatingText("配料", 21, TianjinUi.BrownText));
        var grid = new GridContainer
        {
            Columns = 2,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };
        grid.AddThemeConstantOverride("h_separation", 8);
        grid.AddThemeConstantOverride("v_separation", 6);
        column.AddChild(grid);
        foreach ((string id, string name, Color color, bool drag) in Ingredients)
            grid.AddChild(BuildIngredientSlot(id, name, color, drag));
        return root;
    }

    private IngredientStockSlotView BuildIngredientSlot(string id, string name, Color color, bool drag)
    {
        var slot = new IngredientStockSlotView { Name = $"IngredientSlot_{id.Replace(':', '_')}", SizeFlagsHorizontal = SizeFlags.ExpandFill };
        Texture2D containerTexture = id switch
        {
            StableIds.Ingredients.Batter => _art.BatterContainer,
            StableIds.Ingredients.Sauce => _art.SauceContainer,
            _ => _art.IngredientTray,
        };
        Texture2D texture = _art.Ingredient(id);
        IngredientVisualMode visualMode = id is StableIds.Ingredients.Egg
            or StableIds.Ingredients.Crispy
            or StableIds.Ingredients.Scallion
            or StableIds.Ingredients.Ham
            ? IngredientVisualMode.RepresentativeCluster
            : IngredientVisualMode.Single;
        slot.ConfigureStock(containerTexture, texture, name,
            UseServingTray ? TianjinWorkbenchLayout.IngredientSlot(id) : IngredientSlotSpec(id), visualMode);
        if (UseServingTray)
        {
            Label hint = FloatingText(TianjinWorkbenchLayout.ActionHint(id), 16, TianjinUi.BrownText, HorizontalAlignment.Center);
            hint.Name = "IngredientActionHint";
            Place(hint, TianjinWorkbenchLayout.HintPlacement(id));
            hint.MouseFilter = MouseFilterEnum.Ignore;
            slot.AddChild(hint);
        }
        Control input;
        if (drag)
        {
            var item = new DragItem();
            item.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
            item.Configure(_drag, id, name, color, new DragVisualSpec(texture, new Vector2(105, 105)), () => CanUse(id));
            item.StartRejected += () => Reject("当前不能取用该食材。");
            ConfigureArtInteraction(item, slot.HoverTarget);
            if (id == StableIds.Ingredients.Batter) _batterItem = item;
            input = item;
        }
        else if (id is StableIds.Ingredients.Egg or StableIds.Ingredients.Scallion)
        {
            var button = new ClickInteractable
            {
                Text = string.Empty,
            };
            ApplyFramelessButtonStyle(button);
            ConfigureArtInteraction(button, slot.HoverTarget);
            button.Invoked += () =>
            {
                if (id == StableIds.Ingredients.Egg) Execute(PancakeCommand.AddEgg);
                else Execute(PancakeCommand.AddIngredient, id);
            };
            input = button;
        }
        else
        {
            input = new Control { MouseFilter = MouseFilterEnum.Ignore };
        }
        input.Name = $"IngredientInput_{id.Replace(':', '_')}";
        slot.SetInteraction(input);
        slot.StockLabel.Name = $"IngredientCount_{id.Replace(':', '_')}";
        slot.RefillButton.Name = $"IngredientRefill_{id.Replace(':', '_')}";
        slot.StockBar.Name = $"IngredientStock_{id.Replace(':', '_')}";
        slot.RefillRequested += () => Refill(id);
        _ingredientSlots[id] = slot;
        return slot;
    }

    private Control BuildStove()
    {
        var root = FramelessRoot("StoveArea", 760);
        var stage = new Control();
        TianjinUi.FullRect(stage);
        root.AddChild(stage);
        _canvas = new PancakeCanvas
        {
            Name = "PancakeCanvas",
            MouseFilter = MouseFilterEnum.Ignore,
            DisplayScale = 0.90f,
            DisplayOffset = new Vector2(-16, 0),
            ShowBaggedPancake = !UseServingTray,
        };
        FullRect(_canvas, 8, -8, -8, -64);
        stage.AddChild(_canvas);
        var zone = new DropZone { Name = "PancakeDropZone", HitPadding = 24 };
        _stoveDropZone = zone;
        FullRect(zone, 118, 24, -118, -104);
        stage.AddChild(zone);
        zone.Configure(
            CanDrop,
            Drop,
            _ => _canvas.GetGlobalTransform() * _canvas.GetSurfaceRect().GetCenter());
        _drag.RegisterZone(zone);
        _stroke = new StrokeInteractor { Name = "PancakeStrokeInput", PancakeRadius = 128 };
        FullRect(_stroke, 118, 24, -118, -104);
        _stroke.ResolveMode = ResolveStroke;
        _stroke.ResolveSpreadGeometry = ResolveSpreadGeometry;
        _stroke.SpreadToolTexture = _art.Scraper;
        _stroke.SauceToolTexture = _art.Ingredient(StableIds.Ingredients.Sauce);
        _stroke.StrokeStarted = BeginStroke;
        _stroke.StrokeProgressed = (mode, progress) =>
        {
            if (mode == StrokeMode.Spread) Machine.SetSpreadCoverage(progress);
            else Machine.SetSauceCoverage(progress);
        };
        _stroke.StrokeCompleted = mode =>
        {
            Execute(mode == StrokeMode.Spread ? PancakeCommand.CompleteSpread : PancakeCommand.CompleteSauce);
            _canvas.PivotOffset = _canvas.Size * 0.5f;
            _canvas.Scale = new Vector2(0.985f, 0.985f);
            CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out).TweenProperty(_canvas, "scale", Vector2.One, 0.16);
        };
        _stroke.InvalidStroke = () => Reject("当前步骤不需要轨迹操作。");
        stage.AddChild(_stroke);
        _canvas.Resized += LayoutStoveInputs;
        Callable.From(LayoutStoveInputs).CallDeferred();

        var actions = new HBoxContainer();
        Place(actions, 189, 438, 350, 56);
        _pancakeActions = actions;
        actions.AddThemeConstantOverride("separation", 8);
        stage.AddChild(actions);
        _flip = ActionButton("翻面", () => Execute(PancakeCommand.Flip));
        _fold = ActionButton("折叠", () => Execute(PancakeCommand.Fold));
        _bag = ActionButton("装袋", () => Execute(PancakeCommand.Bag));
        _discard = ActionButton("清理炉面", Discard);
        _flip.Name = "PancakeFlipAction";
        _fold.Name = "PancakeFoldAction";
        _bag.Name = "PancakeBagAction";
        _discard.Name = "PancakeDiscardAction";
        _flip.Icon = _art.Spatula; _flip.ExpandIcon = true;
        _fold.Icon = _art.Scraper; _fold.ExpandIcon = true;
        _bag.Icon = _art.FinishedPancake; _bag.ExpandIcon = true;
        actions.AddChild(_flip); actions.AddChild(_fold); actions.AddChild(_bag); actions.AddChild(_discard);
        PanelContainer pancakeStatusTag = StatusTag("PancakeStatusTag", new Vector2(410, 42));
        Place(pancakeStatusTag, 160, 382, 410, 42);
        _state = Text("拖入面糊", 18, TianjinUi.BrownText, HorizontalAlignment.Center);
        _state.Name = "PancakeStatusText";
        _state.VerticalAlignment = VerticalAlignment.Center;
        pancakeStatusTag.AddChild(_state);
        stage.AddChild(pancakeStatusTag);
        return root;
    }

    private Control BuildDelivery()
    {
        var root = FramelessRoot("DeliveryArea", UseServingTray ? TianjinWorkbenchLayout.Utilities.Size.X : 794);
        var delivery = new DropZone { Name = "DeliveryDropZone", CustomMinimumSize = DeliveryDropZoneRect.Size };
        Place(delivery, DeliveryDropZoneRect);
        _deliveryZone = delivery;
        var servingTrayTexture = new AtlasTexture
        {
            Atlas = _art.ServingTray,
            Region = ServingTrayTextureRegion,
            FilterClip = true,
        };
        TextureRect servingTray = TianjinUi.Texture(
            servingTrayTexture,
            DeliveryDropZoneRect.Size);
        servingTray.Name = "ServingTrayArt";
        servingTray.Modulate = new Color(1, 1, 1, 0.82f);
        servingTray.MouseFilter = MouseFilterEnum.Ignore;
        AddDropZoneFill(delivery, servingTray, DeliveryDropZoneRect.Size);
        Label deliveryLabel = FloatingText("出餐口", 18, TianjinUi.BrownText, HorizontalAlignment.Center);
        deliveryLabel.VerticalAlignment = VerticalAlignment.Bottom;
        delivery.AddChild(deliveryLabel);
        delivery.Configure(CanDeliverPayload, DeliverPayload, _ => delivery.GetGlobalRect().GetCenter());
        root.AddChild(delivery);
        _drag.RegisterZone(delivery);
        _directDeliveryHint = FloatingText(UseServingTray ? "拖给顾客" : "成品拖给顾客", UseServingTray ? 16 : 20, TianjinUi.BrownText, HorizontalAlignment.Center);
        _directDeliveryHint.Name = "DirectDeliveryHint";
        _directDeliveryHint.VerticalAlignment = VerticalAlignment.Center;
        _directDeliveryHint.MouseFilter = MouseFilterEnum.Ignore;
        Place(_directDeliveryHint, UseServingTray
            ? new Rect2(TianjinWorkbenchLayout.Finished.Position + TianjinWorkbenchLayout.FinishedPickupHint.Position, TianjinWorkbenchLayout.FinishedPickupHint.Size)
            : DeliveryDropZoneRect);
        root.AddChild(_directDeliveryHint);
        Rect2 finishedRect = UseServingTray ? TianjinWorkbenchLayout.Finished : FinishedPancakeSlotRect;
        var finishedSlot = new Control { Name = "FinishedPancakeSlot", CustomMinimumSize = finishedRect.Size, MouseFilter = MouseFilterEnum.Ignore };
        Place(finishedSlot, finishedRect);
        if (UseServingTray)
        {
            finishedSlot.ZIndex = 40;
            _directDeliveryHint.ZIndex = 41;
            var tray = TianjinUi.Texture(_art.ServingTray, finishedRect.Size);
            tray.Name = "FinishedTrayArt";
            FullRect(tray, 0, 0, 0, 0);
            finishedSlot.AddChild(tray);
            var emptyLabel = FloatingText("成品托盘", 18, TianjinUi.BrownText, HorizontalAlignment.Center);
            emptyLabel.Name = "FinishedTrayLabel";
            Place(emptyLabel, TianjinWorkbenchLayout.FinishedCaption);
            emptyLabel.MouseFilter = MouseFilterEnum.Ignore;
            finishedSlot.AddChild(emptyLabel);
            _finishedTrayLabel = emptyLabel;
        }
        _finished = new DragItem { Name = "FinishedPancakeDrag", CustomMinimumSize = UseServingTray ? TianjinWorkbenchLayout.FinishedInput.Size : finishedRect.Size, Visible = false };
        _finished.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        if (UseServingTray)
        {
            var content = new Control { MouseFilter = MouseFilterEnum.Ignore };
            var bag = TianjinUi.Texture(_art.FinishedPancake, TianjinWorkbenchLayout.FinishedVisual);
            bag.Name = "FinishedPancakeArt";
            Place(bag, new Rect2(TianjinWorkbenchLayout.FinishedArtPosition, TianjinWorkbenchLayout.FinishedVisual));
            content.AddChild(bag);
            _finished.AddChild(content);
        }
        else
        {
            var finishedRow = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center };
            FullRect(finishedRow, 0, 0, 0, 0);
            finishedRow.AddChild(TianjinUi.Texture(_art.FinishedPancake, new Vector2(78, 68)));
            finishedRow.AddChild(FloatingText("煎饼", 17, TianjinUi.BrownText, HorizontalAlignment.Center));
            _finished.AddChild(finishedRow);
        }
        _finished.Configure(_drag, "finished_pancake", "装袋煎饼", TianjinUi.Cream, new DragVisualSpec(_art.FinishedPancake, UseServingTray ? TianjinWorkbenchLayout.FinishedVisual : new Vector2(150, 125)), () => CanDeliverProduct("finished_pancake"));
        ConfigureArtInteraction(_finished);
        finishedSlot.AddChild(_finished);
        if (UseServingTray) Place(_finished, TianjinWorkbenchLayout.FinishedInput);
        else FullRect(_finished, 0, 0, 0, 0);
        root.AddChild(finishedSlot);
        Rect2 soyRect = UseServingTray ? TianjinWorkbenchLayout.SoyMilk : SoyMilkSlotRect;
        _soyPanel = new Control { Name = "SoyMilkSlot", CustomMinimumSize = soyRect.Size, MouseFilter = MouseFilterEnum.Ignore };
        Place(_soyPanel, soyRect);
        TextureRect soyTray = TianjinUi.Texture(_art.SoyTray, soyRect.Size);
        FullRect(soyTray, 0, 0, 0, 0);
        soyTray.Modulate = new Color(1, 1, 1, UseServingTray ? 1f : 0.68f);
        soyTray.MouseFilter = MouseFilterEnum.Ignore;
        _soyPanel.AddChild(soyTray);
        _soyCup = new DragItem { Name = "SoyMilkCupDrag", CustomMinimumSize = new Vector2(72, 82) };
        Place(_soyCup, UseServingTray ? TianjinWorkbenchLayout.SoyCupInput : new Rect2(8, 7, 72, 82));
        _soyCup.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        if (UseServingTray)
        {
            var content = new Control { MouseFilter = MouseFilterEnum.Ignore };
            var cup = TianjinUi.Texture(_art.Product(ProductKind.SoyMilk), TianjinWorkbenchLayout.SoyVisual);
            cup.Name = "SoyMilkCupArt";
            Place(cup, new Rect2(TianjinWorkbenchLayout.SoyArtPosition, TianjinWorkbenchLayout.SoyVisual));
            content.AddChild(cup);
            _soyCup.AddChild(content);
        }
        else
        {
            var soyContent = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center };
            soyContent.AddChild(TianjinUi.Texture(_art.Product(ProductKind.SoyMilk), new Vector2(48, 64)));
            _soyCup.AddChild(soyContent);
        }
        _soyCup.Configure(_drag, SoyMilkPayload, "豆浆", TianjinUi.Cream, new DragVisualSpec(_art.Product(ProductKind.SoyMilk), UseServingTray ? TianjinWorkbenchLayout.SoyVisual : new Vector2(88, 98)), () => CanInteract && SoyMilkTray?.CanStartDrag == true);
        _soyCup.StartRejected += () => Reject("豆浆托盘正在取杯、补货或已经空了。");
        ConfigureArtInteraction(_soyCup);
        _soyPanel.AddChild(_soyCup);
        var soyActions = new VBoxContainer();
        Place(soyActions, UseServingTray ? TianjinWorkbenchLayout.SoyActions : new Rect2(78, 2, 96, 88));
        soyActions.AddThemeConstantOverride("separation", 2);
        _soyStatus = FloatingText("豆浆 ×6", UseServingTray ? 18 : 17, TianjinUi.BrownText, HorizontalAlignment.Center);
        _soyStatus.CustomMinimumSize = new Vector2(UseServingTray ? 84 : 96, 26);
        soyActions.AddChild(_soyStatus);
        _soyRefill = SmallButton("+");
        _soyRefill.CustomMinimumSize = new Vector2(66, 56);
        _soyRefill.SizeFlagsHorizontal = SizeFlags.ShrinkCenter;
        _soyRefill.TooltipText = "补满豆浆";
        _soyRefill.Pressed += RefillSoyMilk;
        soyActions.AddChild(_soyRefill);
        _soyPanel.AddChild(soyActions);
        root.AddChild(_soyPanel);

        Rect2 trashRect = UseServingTray ? TianjinWorkbenchLayout.Trash : TrashZoneRect;
        _trashZone = new DropZone { Name = "TrashZone", CustomMinimumSize = trashRect.Size, HitPadding = 8 };
        if (UseServingTray) _trashZone.ZIndex = 40;
        Place(_trashZone, trashRect);
        _trashZone.Configure(CanTrashPayload, DiscardPayload, _ => _trashZone.GetGlobalRect().GetCenter());
        TextureRect trashArt = TianjinUi.Texture(_art.Trash, trashRect.Size);
        trashArt.Name = "TrashArt";
        trashArt.MouseFilter = MouseFilterEnum.Ignore;
        AddDropZoneFill(_trashZone, trashArt, trashRect.Size);
        Label trashLabel = FloatingText("拖入丢弃", 17, TianjinUi.BrownText, HorizontalAlignment.Center);
        trashLabel.Name = "TrashLabel";
        trashLabel.VerticalAlignment = VerticalAlignment.Bottom;
        trashLabel.MouseFilter = MouseFilterEnum.Ignore;
        AddDropZoneFill(_trashZone, trashLabel, trashRect.Size);
        root.AddChild(_trashZone);
        _drag.RegisterZone(_trashZone);
        return root;
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
    private bool CanUse(string id) => _initialized && CanInteract && _enabledIngredients.Contains(id) && Inventory.GetQuantity(id) > 0 && !Inventory.IsRefilling(id);
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
        PancakeState.SideBReady or PancakeState.Saucing => StrokeMode.Sauce,
        _ => StrokeMode.None,
    };
    private void BeginStroke(StrokeMode mode)
    {
        PancakeActionResult result = Machine.TryExecute(mode == StrokeMode.Spread ? PancakeCommand.BeginSpread : PancakeCommand.BeginSauce);
        if (!result.Success && Machine.Runtime.State is not (PancakeState.Spreading or PancakeState.Saucing)) Reject(result.Message);
        else _audio.Play(PancakeSound.Stroke);
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

        if (consumedYoutiao is YoutiaoQuality quality)
        {
            Machine.TrySetInternalYoutiaoQuality(quality);
            YoutiaoConsumed?.Invoke(1);
        }

        if (command is PancakeCommand.PlaceBatter or PancakeCommand.AddEgg) _audio.Play(PancakeSound.Sizzle);
        else if (command == PancakeCommand.Flip) _audio.Play(PancakeSound.Flip);
        Inform(result.Message, false);
        return true;
    }
    private bool CanLoadRawYoutiao() => _initialized && CanInteract && FryerMachine is not null
        && FryerMachine.Runtime.State is FryerState.Empty or FryerState.Loaded
        && FryerMachine.Runtime.Quantity < FryerMachine.Level.Capacity;
    private void ExecuteFryer(FryerCommand command)
    {
        if (FryerMachine is null || !CanInteract) return;
        FryerActionResult result = FryerMachine.TryExecute(command);
        if (!result.Success) Reject(result.Message);
        else
        {
            if (command == FryerCommand.LowerBasket) _audio.Play(PancakeSound.Sizzle);
            else if (command == FryerCommand.RaiseBasket) _audio.Play(PancakeSound.Flip);
            Inform(result.Message, false);
        }
    }
    private bool CanDeliverPayload(string id) => CanInteract && id switch
    {
        "finished_pancake" => HasDeliveryTarget && Machine.Runtime.State == PancakeState.Bagged,
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
        "finished_pancake" => Machine.Runtime.State == PancakeState.Bagged && !IsTransferringBag,
        StoredYoutiaoPayload => FryerMachine?.Inventory.Count > 0,
        _ => false,
    };
    private void DiscardPayload(string id)
    {
        if (id == "finished_pancake")
        {
            if (Machine.TryExecute(PancakeCommand.Discard).Success)
            {
                _stroke.ResetCoverage();
                Inform("装袋煎饼已丢弃。", false);
            }
            return;
        }
        if (id == StoredYoutiaoPayload && FryerMachine?.Inventory.TryTake(out _) == true)
            Inform("一根库存油条已丢弃。", false);
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
        else Inform("开始补豆浆，0.6 秒后补满。", false);
    }
    private void Refill(string id)
    {
        if (!CanInteract || !Inventory.TryBeginRefill(id)) Reject("料盒已满或正在补料。");
        else Inform($"{IngredientName(id)}开始补货，{Inventory.LevelData.RefillSeconds:0.0} 秒后补满。", false);
    }
    private void Discard()
    {
        PancakeActionResult result = Machine.TryExecute(PancakeCommand.Discard);
        if (!result.Success) Reject(result.Message); else { _stroke.ResetCoverage(); Inform("炉面已清理。", false); }
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
            slot.RenderStock(quantity, capacity, status, Inventory.GetRefillProgress(id), CanInteract);
            slot.SetAttention(ResolveIngredientAttention(id, status, state, requiredToppings));
            if (status is IngredientStockStatus.Low or IngredientStockStatus.Empty)
            {
                if (_lowStockNotified.Add(id))
                {
                    string message = status == IngredientStockStatus.Empty
                        ? $"{IngredientName(id)}已经用完，点击 + 补货。"
                        : $"{IngredientName(id)}只剩 {quantity} 份，可以点击 + 补货。";
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
        SetContextAction(_fold, state is PancakeState.Sauced or PancakeState.Toppings);
        SetContextAction(_bag, state == PancakeState.Folded);
        SetContextAction(_discard, state == PancakeState.Burnt);
        _pancakeActions.Visible = _flip.Visible || _fold.Visible || _bag.Visible || _discard.Visible;
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
            _fryerStock.Text = FryerMachine.Inventory.Count.ToString();
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
        _directDeliveryHint.Visible = DirectCustomerDelivery && (!UseServingTray || state == PancakeState.Bagged);
        _soyPanel.Visible = SoyMilkTray is not null;
        if (SoyMilkTray is not null)
        {
            _soyStatus.Text = SoyMilkTray.IsRefilling ? $"豆浆 {SoyMilkTray.RefillProgress:P0}" : SoyMilkTray.IsTaking ? "豆浆 · 取杯中" : $"豆浆 ×{SoyMilkTray.Quantity}";
            _soyRefill.Text = SoyMilkTray.IsRefilling ? "…" : "+";
            _soyRefill.Visible = SoyMilkTray.Quantity < SoyMilkTray.Capacity || SoyMilkTray.IsRefilling;
            _soyRefill.Disabled = !CanInteract || SoyMilkTray.Quantity >= SoyMilkTray.Capacity || SoyMilkTray.IsRefilling || SoyMilkTray.IsTaking;
            _soyRefill.TooltipText = SoyMilkTray.IsRefilling ? "豆浆补货中" : "补满豆浆";
        }
        RenderLive();
    }
    private void RenderLive()
    {
        if (!_initialized) return;
        _state.Text = _batterDropAnimating ? "正在落浆"
            : UseServingTray && Machine.Runtime.State == PancakeState.Bagged
                ? IsTransferringBag ? "正在放入成品托盘" : "从炉边托盘拖给顾客"
            : DirectCustomerDelivery && Machine.Runtime.State == PancakeState.Bagged ? "拖给顾客"
            : PancakeStatus(Machine.Runtime);
        _state.Modulate = Machine.Runtime.State switch
        {
            PancakeState.SideAReady => TianjinUi.Green,
            PancakeState.SideAOverdone => TianjinUi.Orange,
            PancakeState.Burnt => TianjinUi.Red,
            _ => TianjinUi.BrownText,
        };
        _canvas.QueueRedraw();
        _stroke.RefreshVisualState();
    }

    private void UpdateBagPresentation(PancakeState state)
    {
        if (_finishedTrayLabel is not null) _finishedTrayLabel.Visible = state != PancakeState.Bagged;
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
        _finished.Visible = !IsTransferringBag && Machine.Runtime.State == PancakeState.Bagged;
    }

    private void ResetBagPresentation()
    {
        _baggedPresented = false;
        _bagTransferRemaining = 0;
        if (IsInstanceValid(_bagTransfer)) _bagTransfer.Visible = false;
    }
    private void Reject(string message) { _audio.Play(PancakeSound.Error); Inform(message, true); }
    private void Inform(string message, bool error) => Feedback?.Invoke(message, error);
    private static string QualityName(YoutiaoQuality quality) => quality switch { YoutiaoQuality.Light => "偏浅", YoutiaoQuality.Golden => "金黄", YoutiaoQuality.Deep => "偏深", _ => "焦糊" };
    private static string FryerStatus(FryerStateMachine machine) => machine.Runtime.State switch
    {
        FryerState.Empty => $"空篮 · 0/{machine.Level.Capacity}",
        FryerState.Loaded => $"待下锅 · {machine.Runtime.Quantity}/{machine.Level.Capacity}",
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
        PancakeState.SideACooking => $"第一面加热 · {runtime.CookingSeconds:0.0} 秒",
        PancakeState.SideAReady => "火候正好 · 点击翻面",
        PancakeState.SideAOverdone => "颜色变深 · 立即翻面",
        PancakeState.SideBCooking => $"第二面加热 · {runtime.CookingSeconds:0.0} 秒",
        PancakeState.SideBReady or PancakeState.Saucing => $"按住左键划动抹酱 · {runtime.SauceCoverage:P0}",
        PancakeState.Sauced or PancakeState.Toppings => "按订单拖入或点击配料",
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
        if (UseServingTray && id == StableIds.Ingredients.Sauce && pancakeState is PancakeState.SideBReady or PancakeState.Saucing)
            return WorkstationSlotAttentionState.Actionable;
        if (id == StableIds.Ingredients.Batter && pancakeState == PancakeState.Empty)
            return WorkstationSlotAttentionState.Required;
        if (id == StableIds.Ingredients.Egg && pancakeState == PancakeState.Spread)
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

    private static Control FramelessRoot(string name, float width) => new()
    {
        Name = name,
        CustomMinimumSize = new Vector2(width, 0),
        MouseFilter = MouseFilterEnum.Ignore,
    };
    private static PanelContainer StatusTag(string name, Vector2 minimumSize)
    {
        PanelContainer panel = TianjinUi.Panel(new Color(1f, 0.96f, 0.84f, 0.94f), 12, 3, false);
        panel.Name = name;
        panel.CustomMinimumSize = minimumSize;
        panel.MouseFilter = MouseFilterEnum.Ignore;
        return panel;
    }
    private static StyleBoxFlat Box(Color color, int radius) => TianjinUi.Box(color, radius, 3, false);
    private static Label Text(string text, int size, Color color, HorizontalAlignment alignment = HorizontalAlignment.Left) => TianjinUi.Label(text, size, color, alignment);
    private static Label Text(string text, int size, string color, HorizontalAlignment alignment = HorizontalAlignment.Left) => Text(text, size, new Color(color), alignment);
    private static Label FloatingText(string text, int size, Color color, HorizontalAlignment alignment = HorizontalAlignment.Left)
    {
        Label label = Text(text, size, color, alignment);
        label.AddThemeConstantOverride("outline_size", 4);
        label.AddThemeColorOverride("font_outline_color", new Color(1f, 0.94f, 0.79f, 0.92f));
        label.AddThemeConstantOverride("shadow_offset_x", 1);
        label.AddThemeConstantOverride("shadow_offset_y", 2);
        label.AddThemeColorOverride("font_shadow_color", new Color(0.18f, 0.08f, 0.03f, 0.22f));
        return label;
    }
    private static void ApplyFramelessButtonStyle(Button button)
    {
        foreach (string state in new[] { "normal", "hover", "pressed", "focus", "disabled" })
            button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        button.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        button.AddThemeColorOverride("font_hover_color", TianjinUi.BrownText);
        button.AddThemeColorOverride("font_pressed_color", TianjinUi.BrownText);
        button.AddThemeColorOverride("font_focus_color", TianjinUi.BrownText);
        button.AddThemeColorOverride("font_disabled_color", new Color("#826F5D"));
        button.AddThemeFontSizeOverride("font_size", 16);
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
    private static Button SmallButton(string text) { Button button = TianjinUi.Button(text, false, new Vector2(74, 48)); button.AddThemeFontSizeOverride("font_size", 16); return button; }
    private static Button ActionButton(string text, Action action)
    {
        var button = new ClickInteractable { Text = text, SizeFlagsHorizontal = SizeFlags.ExpandFill, CustomMinimumSize = new Vector2(0, 56) };
        ApplyActionStyle(button, TianjinUi.Cream);
        button.Invoked += action;
        return button;
    }
    private static void ApplyActionStyle(Button button, Color color)
    {
        button.AddThemeStyleboxOverride("normal", TianjinUi.Box(color, 12, 3, false));
        button.AddThemeStyleboxOverride("hover", TianjinUi.Box(color.Lightened(0.08f), 12, 4, false));
        button.AddThemeStyleboxOverride("pressed", TianjinUi.Box(color.Darkened(0.08f), 12, 3, false));
        button.AddThemeStyleboxOverride("disabled", TianjinUi.Box(new Color("#D8C5A8"), 12, 2, false));
        button.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        button.AddThemeColorOverride("font_hover_color", TianjinUi.BrownText);
        button.AddThemeColorOverride("font_pressed_color", TianjinUi.BrownText);
        button.AddThemeColorOverride("font_disabled_color", new Color("#826F5D"));
        button.AddThemeFontSizeOverride("font_size", 17);
    }
    private static void AddDropZoneFill(DropZone zone, Control child, Vector2 outerSize)
    {
        var layer = new Control
        {
            Name = $"{child.Name}Layer",
            CustomMinimumSize = new Vector2(outerSize.X - 6, outerSize.Y - 6),
            MouseFilter = MouseFilterEnum.Ignore,
        };
        zone.AddChild(layer);
        layer.AddChild(child);
        FullRect(child, 0, 0, 6, 6);
    }
    private static void Place(Control control, float x, float y, float width, float height) { control.Position = new Vector2(x, y); control.Size = new Vector2(width, height); }
    private static void Place(Control control, Rect2 rect) { control.Position = rect.Position; control.Size = rect.Size; }
    private static void FullRect(Control c, float l, float t, float r, float b) { c.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); c.OffsetLeft = l; c.OffsetTop = t; c.OffsetRight = r; c.OffsetBottom = b; }
}
