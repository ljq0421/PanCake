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

    private readonly Dictionary<string, Label> _counts = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Button> _refills = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Control> _ingredientRows = new(StringComparer.Ordinal);
    private readonly Dictionary<string, ProgressBar> _stockBars = new(StringComparer.Ordinal);
    private readonly Dictionary<string, StyleBoxFlat> _stockFills = new(StringComparer.Ordinal);
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
    private PancakeCanvas _canvas = null!;
    private PancakeAudio _audio = null!;
    private TextureRect _batterLadle = null!;
    private Tween? _batterTween;
    private bool _batterDropAnimating;
    private DragItem _finished = null!;
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
    private Button _trashButton = null!;
    private TianjinArtCatalog _art = null!;
    private int _stoveLevel = 1;
    private bool _initialized;
    private bool _showOperationHints;
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
    public bool InteractionEnabled { get; set; } = true;
    public bool Paused { get; set; }

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog, int stoveLevel, int stationLevel, int fryerLevel = 0, DayConfig? config = null, TianjinArtCatalog? art = null)
    {
        _art = art ?? _art;
        _stoveLevel = stoveLevel;
        _showOperationHints = config is null || config.Day <= 3;
        _lastPancakeState = null;
        _lastFryerState = null;
        _lastFryerQuality = null;
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
        Place(fryer, 24, 500, 520, 510);
        stage.AddChild(fryer);
        Control stove = BuildStove();
        Place(stove, 446, 500, 760, 510);
        stage.AddChild(stove);
        Control ingredients = BuildIngredients();
        Place(ingredients, 1218, 590, 666, 420);
        stage.AddChild(ingredients);
        Control delivery = BuildDelivery();
        Place(delivery, 1192, 468, 692, 110);
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
        _drag.DragStarted += _ => _audio.Play(PancakeSound.PickUp);
        _drag.DragEnded += OnDragEnded;
    }

    private Control BuildFryer()
    {
        var root = FramelessRoot("FryerArea", 520);
        _fryerPanel = root;
        Label title = FloatingText("油条", 21, TianjinUi.BrownText);
        Place(title, 4, 0, 430, 32);
        root.AddChild(title);

        var fryerStack = new Control { Name = "FryerStack" };
        Place(fryerStack, 0, 18, 350, 350);
        _fryerVisual = new FryerVisualView { Name = "FryerVisual", MouseFilter = MouseFilterEnum.Ignore };
        FullRect(_fryerVisual, 0, 0, 0, 0);
        fryerStack.AddChild(_fryerVisual);
        var basket = new DropZone { Name = "FryerBasketDropZone" };
        FullRect(basket, 40, 54, -40, -106);
        basket.Configure(
            id => id == RawYoutiaoPayload && CanLoadRawYoutiao(),
            _ => ExecuteFryer(FryerCommand.LoadOne),
            _ => _fryerVisual.NextLoadSlotGlobalCenter());
        fryerStack.AddChild(basket);
        _drag.RegisterZone(basket);
        root.AddChild(fryerStack);

        var loadColumn = new VBoxContainer();
        Place(loadColumn, 350, 58, 150, 160);
        var raw = new DragItem { CustomMinimumSize = new Vector2(0, 160), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        raw.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        TextureRect rawTray = TianjinUi.Texture(_art.IngredientTray, new Vector2(0, 160));
        rawTray.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        rawTray.Modulate = new Color(1, 1, 1, 0.72f);
        rawTray.MouseFilter = MouseFilterEnum.Ignore;
        raw.AddChild(rawTray);
        var rawContent = new VBoxContainer { Alignment = BoxContainer.AlignmentMode.Center };
        rawContent.AddChild(TianjinUi.Texture(_art.RawYoutiao, new Vector2(76, 94)));
        rawContent.AddChild(FloatingText("生油条", 15, TianjinUi.BrownText, HorizontalAlignment.Center));
        raw.AddChild(rawContent);
        raw.Configure(_drag, RawYoutiaoPayload, "生油条", new Color("#F7D892"), new DragVisualSpec(_art.RawYoutiao, new Vector2(105, 105)), CanLoadRawYoutiao);
        raw.StartRejected += () => Reject("炸篮当前不能继续装料。");
        ConfigureArtInteraction(raw);
        loadColumn.AddChild(raw);
        root.AddChild(loadColumn);

        _fryerStatus = FloatingText("尚未解锁", 16, TianjinUi.BrownText, HorizontalAlignment.Center);
        Place(_fryerStatus, 20, 360, 330, 28);
        root.AddChild(_fryerStatus);
        var actions = new HBoxContainer();
        Place(actions, 80, 398, 270, 54);
        _fryerActions = actions;
        _lowerBasket = ActionButton("下锅", () => ExecuteFryer(FryerCommand.LowerBasket));
        _raiseBasket = ActionButton("抬篮", () => ExecuteFryer(FryerCommand.RaiseBasket));
        _discardBatch = ActionButton("清理", () => ExecuteFryer(FryerCommand.Discard));
        _lowerBasket.Name = "FryerLowerAction";
        _raiseBasket.Name = "FryerRaiseAction";
        _discardBatch.Name = "FryerDiscardAction";
        actions.AddChild(_lowerBasket); actions.AddChild(_raiseBasket); actions.AddChild(_discardBatch);
        root.AddChild(actions);

        var stockRow = new VBoxContainer { Name = "FinishedYoutiaoArea" };
        stockRow.AddThemeConstantOverride("separation", 0);
        Place(stockRow, 350, 235, 150, 105);
        _fryerStock = FloatingText("成品油条 0/0", 16, TianjinUi.BrownText, HorizontalAlignment.Center);
        _fryerStock.Name = "FinishedYoutiaoStock";
        _fryerStock.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        stockRow.AddChild(_fryerStock);
        _storedYoutiao = new DragItem { Name = "FinishedYoutiaoDrag", CustomMinimumSize = new Vector2(150, 70), Visible = false };
        _storedYoutiao.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        var storedContent = new HBoxContainer();
        storedContent.AddChild(TianjinUi.Texture(_art.Ingredient(StableIds.Ingredients.Youtiao), new Vector2(58, 54)));
        storedContent.AddChild(FloatingText("取用", 16, TianjinUi.BrownText, HorizontalAlignment.Center));
        _storedYoutiao.AddChild(storedContent);
        _storedYoutiao.Configure(_drag, StoredYoutiaoPayload, "熟油条", TianjinUi.Yellow, new DragVisualSpec(_art.Ingredient(StableIds.Ingredients.Youtiao), new Vector2(115, 105)), () => InteractionEnabled && !Paused && FryerMachine?.Inventory.Count > 0);
        _storedYoutiao.StartRejected += () => Reject("没有可用的成品油条。");
        ConfigureArtInteraction(_storedYoutiao);
        stockRow.AddChild(_storedYoutiao);
        root.AddChild(stockRow);
        return root;
    }

    private Control BuildIngredients()
    {
        var root = FramelessRoot("IngredientArea", 666);
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 6);
        FullRect(column, 4, 0, -4, 0);
        root.AddChild(column);
        column.AddChild(FloatingText("配料", 21, TianjinUi.BrownText));
        var groups = new HBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill };
        groups.AddThemeConstantOverride("separation", 8);
        var core = new VBoxContainer { CustomMinimumSize = new Vector2(321, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        var extras = new VBoxContainer { CustomMinimumSize = new Vector2(321, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        core.AddThemeConstantOverride("separation", 6);
        extras.AddThemeConstantOverride("separation", 6);
        groups.AddChild(core);
        groups.AddChild(extras);
        column.AddChild(groups);
        foreach ((string id, string name, Color color, bool drag) in Ingredients)
        {
            Control group = id is StableIds.Ingredients.Crispy or StableIds.Ingredients.Ham ? extras : core;
            group.AddChild(BuildIngredientSlot(id, name, color, drag));
        }
        return root;
    }

    private PanelContainer BuildIngredientSlot(string id, string name, Color color, bool drag)
    {
        var slot = new PanelContainer
        {
            Name = $"IngredientSlot_{id.Replace(':', '_')}",
            CustomMinimumSize = new Vector2(316, 82),
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        slot.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        Texture2D containerTexture = id switch
        {
            StableIds.Ingredients.Batter => _art.BatterContainer,
            StableIds.Ingredients.Sauce => _art.SauceContainer,
            _ => _art.IngredientTray,
        };
        TextureRect containerArt = TianjinUi.Texture(containerTexture, new Vector2(316, 82));
        containerArt.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        containerArt.Modulate = new Color(1, 1, 1, 0.88f);
        containerArt.MouseFilter = MouseFilterEnum.Ignore;
        slot.AddChild(containerArt);
        var contentColumn = new VBoxContainer { Alignment = BoxContainer.AlignmentMode.Center };
        contentColumn.AddThemeConstantOverride("separation", 0);
        slot.AddChild(contentColumn);
        var row = new HBoxContainer { CustomMinimumSize = new Vector2(0, 66), SizeFlagsVertical = SizeFlags.ExpandFill };
        row.AddThemeConstantOverride("separation", 4);
        contentColumn.AddChild(row);
        Texture2D texture = _art.Ingredient(id);
        Control input;
        if (drag)
        {
            var item = new DragItem { CustomMinimumSize = new Vector2(170, 62), SizeFlagsHorizontal = SizeFlags.ExpandFill };
            item.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
            var content = new HBoxContainer();
            content.AddChild(TianjinUi.Texture(texture, new Vector2(56, 54)));
            content.AddChild(FloatingText(name, 17, TianjinUi.BrownText, HorizontalAlignment.Center));
            item.AddChild(content);
            item.Configure(_drag, id, name, color, new DragVisualSpec(texture, new Vector2(105, 105)), () => CanUse(id));
            item.StartRejected += () => Reject("当前不能取用该食材。");
            ConfigureArtInteraction(item);
            if (id == StableIds.Ingredients.Batter) _batterItem = item;
            input = item;
        }
        else if (id is StableIds.Ingredients.Egg or StableIds.Ingredients.Scallion)
        {
            var button = new ClickInteractable
            {
                Text = name,
                Icon = texture,
                ExpandIcon = true,
                CustomMinimumSize = new Vector2(170, 62),
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
            };
            ApplyFramelessButtonStyle(button);
            ConfigureArtInteraction(button);
            button.Invoked += () =>
            {
                if (id == StableIds.Ingredients.Egg) Execute(PancakeCommand.AddEgg);
                else Execute(PancakeCommand.AddIngredient, id);
            };
            input = button;
        }
        else
        {
            var display = new HBoxContainer
            {
                CustomMinimumSize = new Vector2(170, 62),
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
                MouseFilter = MouseFilterEnum.Ignore,
            };
            display.AddChild(TianjinUi.Texture(texture, new Vector2(56, 54)));
            display.AddChild(FloatingText(name, 17, TianjinUi.BrownText, HorizontalAlignment.Center));
            input = display;
        }
        input.Name = $"IngredientInput_{id.Replace(':', '_')}";
        row.AddChild(input);
        var count = FloatingText("×0", 16, TianjinUi.BrownText, HorizontalAlignment.Center);
        count.Name = $"IngredientCount_{id.Replace(':', '_')}";
        count.CustomMinimumSize = new Vector2(50, 58);
        _counts[id] = count;
        row.AddChild(count);
        var refill = SmallButton("补料");
        refill.Name = $"IngredientRefill_{id.Replace(':', '_')}";
        refill.CustomMinimumSize = new Vector2(62, 48);
        refill.Pressed += () => Refill(id);
        _refills[id] = refill;
        row.AddChild(refill);
        var stock = new ProgressBar
        {
            Name = $"IngredientStock_{id.Replace(':', '_')}",
            MinValue = 0,
            MaxValue = 100,
            Value = 100,
            ShowPercentage = false,
            CustomMinimumSize = new Vector2(0, 4),
            MouseFilter = MouseFilterEnum.Ignore,
            Visible = false,
        };
        stock.AddThemeStyleboxOverride("background", StockBarStyle(new Color(0.40f, 0.25f, 0.16f, 0.20f)));
        StyleBoxFlat stockFill = StockBarStyle(TianjinUi.Orange);
        stock.AddThemeStyleboxOverride("fill", stockFill);
        _stockBars[id] = stock;
        _stockFills[id] = stockFill;
        contentColumn.AddChild(stock);
        _ingredientRows[id] = slot;
        return slot;
    }

    private Control BuildStove()
    {
        var root = FramelessRoot("StoveArea", 760);
        var stage = new Control();
        TianjinUi.FullRect(stage);
        root.AddChild(stage);
        _canvas = new PancakeCanvas { MouseFilter = MouseFilterEnum.Ignore };
        FullRect(_canvas, 8, -8, -8, -64);
        stage.AddChild(_canvas);
        var zone = new DropZone();
        FullRect(zone, 118, 24, -118, -104);
        stage.AddChild(zone);
        zone.Configure(
            CanDrop,
            Drop,
            _ => _canvas.GetGlobalTransform() * _canvas.GetSurfaceRect().GetCenter());
        _drag.RegisterZone(zone);
        _stroke = new StrokeInteractor { PancakeRadius = 142 };
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

        var actions = new HBoxContainer();
        Place(actions, 205, 438, 350, 56);
        _pancakeActions = actions;
        actions.AddThemeConstantOverride("separation", 8);
        stage.AddChild(actions);
        _flip = ActionButton("翻面", () => Execute(PancakeCommand.Flip));
        _fold = ActionButton("折叠", () => Execute(PancakeCommand.Fold));
        _bag = ActionButton("装袋", () => Execute(PancakeCommand.Bag));
        _discard = ActionButton("清理", Discard);
        _flip.Name = "PancakeFlipAction";
        _fold.Name = "PancakeFoldAction";
        _bag.Name = "PancakeBagAction";
        _discard.Name = "PancakeDiscardAction";
        _flip.Icon = _art.Spatula; _flip.ExpandIcon = true;
        _fold.Icon = _art.Scraper; _fold.ExpandIcon = true;
        _bag.Icon = _art.FinishedPancake; _bag.ExpandIcon = true;
        actions.AddChild(_flip); actions.AddChild(_fold); actions.AddChild(_bag); actions.AddChild(_discard);
        _state = FloatingText("空炉", 17, TianjinUi.BrownText, HorizontalAlignment.Center);
        _state.SetAnchorsPreset(LayoutPreset.TopWide);
        _state.OffsetTop = 8;
        _state.OffsetBottom = 42;
        stage.AddChild(_state);
        return root;
    }

    private Control BuildDelivery()
    {
        var root = FramelessRoot("DeliveryArea", 692);
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 8);
        FullRect(row, 0, 0, 0, 0);
        root.AddChild(row);
        var delivery = new DropZone { Name = "DeliveryDropZone", CustomMinimumSize = new Vector2(138, 92) };
        _deliveryZone = delivery;
        TextureRect servingTray = TianjinUi.Texture(_art.ServingTray, new Vector2(138, 92));
        servingTray.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        servingTray.Modulate = new Color(1, 1, 1, 0.82f);
        servingTray.MouseFilter = MouseFilterEnum.Ignore;
        delivery.AddChild(servingTray);
        delivery.AddChild(FloatingText("出餐", 17, TianjinUi.BrownText, HorizontalAlignment.Center));
        delivery.Configure(CanDeliverPayload, DeliverPayload, _ => delivery.GetGlobalRect().GetCenter());
        row.AddChild(delivery);
        _drag.RegisterZone(delivery);
        _finished = new DragItem { CustomMinimumSize = new Vector2(138, 92), Visible = false };
        _finished.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        var finishedRow = new HBoxContainer();
        finishedRow.AddChild(TianjinUi.Texture(_art.FinishedPancake, new Vector2(70, 64)));
        finishedRow.AddChild(FloatingText("煎饼", 15, TianjinUi.BrownText, HorizontalAlignment.Center));
        _finished.AddChild(finishedRow);
        _finished.Configure(_drag, "finished_pancake", "装袋煎饼", TianjinUi.Cream, new DragVisualSpec(_art.FinishedPancake, new Vector2(150, 125)), () => CanInteract && Machine.Runtime.State == PancakeState.Bagged);
        ConfigureArtInteraction(_finished);
        row.AddChild(_finished);
        _soyPanel = new Control { CustomMinimumSize = new Vector2(144, 92) };
        TextureRect soyTray = TianjinUi.Texture(_art.SoyTray, new Vector2(144, 92));
        soyTray.Modulate = new Color(1, 1, 1, 0.42f);
        soyTray.MouseFilter = MouseFilterEnum.Ignore;
        _soyPanel.AddChild(soyTray);
        var soyContentRow = new HBoxContainer();
        FullRect(soyContentRow, 0, 0, 0, 0);
        _soyPanel.AddChild(soyContentRow);
        _soyCup = new DragItem { CustomMinimumSize = new Vector2(74, 86) };
        _soyCup.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        var soyContent = new HBoxContainer();
        soyContent.AddChild(TianjinUi.Texture(_art.Product(ProductKind.SoyMilk), new Vector2(44, 58)));
        _soyCup.AddChild(soyContent);
        _soyCup.Configure(_drag, SoyMilkPayload, "豆浆", TianjinUi.Cream, new DragVisualSpec(_art.Product(ProductKind.SoyMilk), new Vector2(88, 98)), () => CanInteract && SoyMilkTray?.CanStartDrag == true);
        _soyCup.StartRejected += () => Reject("豆浆托盘正在取杯、补货或已经空了。");
        ConfigureArtInteraction(_soyCup);
        soyContentRow.AddChild(_soyCup);
        var soyActions = new VBoxContainer();
        _soyStatus = FloatingText("6/6", 14, TianjinUi.BrownText, HorizontalAlignment.Center); soyActions.AddChild(_soyStatus);
        _soyRefill = SmallButton("补料"); _soyRefill.CustomMinimumSize = new Vector2(62, 48); _soyRefill.Pressed += RefillSoyMilk; soyActions.AddChild(_soyRefill);
        soyContentRow.AddChild(soyActions);
        row.AddChild(_soyPanel);

        _trashZone = new DropZone { Name = "TrashZone", CustomMinimumSize = new Vector2(108, 92) };
        _trashZone.Configure(CanTrashPayload, DiscardPayload, _ => _trashZone.GetGlobalRect().GetCenter());
        TextureRect trashArt = TianjinUi.Texture(_art.Trash, new Vector2(68, 72));
        trashArt.Position = new Vector2(20, 0);
        trashArt.MouseFilter = MouseFilterEnum.Ignore;
        _trashZone.AddChild(trashArt);
        _trashButton = new Button { Text = "丢弃", Flat = true, CustomMinimumSize = new Vector2(108, 92) };
        _trashButton.AddThemeFontSizeOverride("font_size", 14);
        _trashButton.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        _trashButton.Pressed += ClearCurrentWaste;
        _trashZone.AddChild(_trashButton);
        row.AddChild(_trashZone);
        _drag.RegisterZone(_trashZone);
        ConfigureArtInteraction(_trashButton);
        return root;
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
        "finished_pancake" => Machine.Runtime.State == PancakeState.Bagged,
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
    private void ClearCurrentWaste()
    {
        if (!CanInteract) return;
        if (FryerMachine?.Runtime.State == FryerState.Burnt)
        {
            ExecuteFryer(FryerCommand.Discard);
            return;
        }
        if (Machine.Runtime.State == PancakeState.Burnt)
        {
            Discard();
            return;
        }
        Inform("可把装袋煎饼或库存油条拖到垃圾桶；焦糊食物也可点击垃圾桶清理。", false);
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
        else Inform("开始补料，1 秒后补满。", false);
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
        foreach ((string id, Label label) in _counts)
        {
            bool enabled = _enabledIngredients.Contains(id);
            _ingredientRows[id].Visible = enabled;
            if (!enabled)
            {
                _lowStockNotified.Remove(id);
                _stockBars[id].Visible = false;
                _refills[id].Visible = false;
                continue;
            }
            int quantity = Inventory.GetQuantity(id);
            int capacity = Inventory.GetCapacity(id);
            bool refilling = Inventory.IsRefilling(id);
            double fraction = capacity > 0 ? (double)quantity / capacity : 0;
            label.Text = refilling ? $"{Inventory.GetRefillProgress(id):P0}" : $"×{quantity}";
            label.Modulate = InventoryColor(fraction);
            ProgressBar stock = _stockBars[id];
            double shownFraction = refilling ? Inventory.GetRefillProgress(id) : fraction;
            stock.Value = shownFraction * 100;
            stock.Visible = refilling || fraction <= 0.50;
            stock.CustomMinimumSize = new Vector2(0, !refilling && fraction <= 0.20 ? 6 : 4);
            _stockFills[id].BgColor = refilling ? TianjinUi.Green : fraction <= 0.20 ? TianjinUi.Red : TianjinUi.Orange;
            _refills[id].Text = refilling ? "补料中" : "补料";
            _refills[id].Visible = refilling || fraction <= 0.50;
            _refills[id].Disabled = !CanInteract || refilling || quantity >= capacity;
            _refills[id].Modulate = !refilling && fraction is > 0.20 and <= 0.50 ? new Color(1, 1, 1, 0.65f) : Colors.White;
            if (!refilling && fraction <= 0.20)
            {
                if (_lowStockNotified.Add(id)) Inform($"{IngredientName(id)}库存不足。", false);
            }
            else if (fraction > 0.20)
            {
                _lowStockNotified.Remove(id);
            }
        }
        PancakeState state = Machine.Runtime.State;
        _finished.Visible = state == PancakeState.Bagged;
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
            _fryerStock.Text = $"成品 ×{FryerMachine.Inventory.Count}";
            _storedYoutiao.Visible = FryerMachine.Inventory.Count > 0;
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
        _trashButton.Disabled = !CanInteract;
        _soyPanel.Visible = SoyMilkTray is not null;
        if (SoyMilkTray is not null)
        {
            _soyStatus.Text = SoyMilkTray.IsRefilling ? $"{SoyMilkTray.RefillProgress:P0}" : SoyMilkTray.IsTaking ? "取杯中" : $"×{SoyMilkTray.Quantity}";
            _soyRefill.Text = SoyMilkTray.IsRefilling ? "补料中" : "补料";
            _soyRefill.Visible = SoyMilkTray.Quantity < SoyMilkTray.Capacity || SoyMilkTray.IsRefilling;
            _soyRefill.Disabled = !CanInteract || SoyMilkTray.Quantity >= SoyMilkTray.Capacity || SoyMilkTray.IsRefilling || SoyMilkTray.IsTaking;
        }
        RenderLive();
    }
    private void RenderLive()
    {
        if (!_initialized) return;
        _state.Text = _batterDropAnimating ? "正在落浆" : PancakeStatus(Machine.Runtime, _showOperationHints);
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
    private static string PancakeStatus(PancakeRuntime runtime, bool showHints) => runtime.State switch
    {
        PancakeState.Empty => showHints ? "空炉 · 点击面糊开始" : "空炉",
        PancakeState.BatterPlaced or PancakeState.Spreading => showHints ? $"按住左键，沿饼面摊开 · {runtime.SpreadCoverage:P0}" : $"摊面 · {runtime.SpreadCoverage:P0}",
        PancakeState.Spread => showHints ? "点击鸡蛋" : "等待鸡蛋",
        PancakeState.SideACooking => $"第一面 · {runtime.CookingSeconds:0.0} 秒",
        PancakeState.SideAReady => "火候正好 · 可以翻面",
        PancakeState.SideAOverdone => "颜色变深 · 尽快翻面",
        PancakeState.SideBCooking => $"第二面 · {runtime.CookingSeconds:0.0} 秒",
        PancakeState.SideBReady or PancakeState.Saucing => showHints ? $"用刷子抹一圈 · {runtime.SauceCoverage:P0}" : $"抹酱 · {runtime.SauceCoverage:P0}",
        PancakeState.Sauced or PancakeState.Toppings => "按订单加料",
        PancakeState.Folded => "可以装袋",
        PancakeState.Bagged => "等待出餐",
        PancakeState.Burnt => "已经焦糊 · 需要清理",
        _ => "制作中",
    };

    private void SetContextAction(Button button, bool visible)
    {
        button.Visible = visible;
        button.Disabled = !CanInteract;
    }

    private static bool IsPancakeAttentionState(PancakeState state) => state is
        PancakeState.SideAReady or PancakeState.SideAOverdone or PancakeState.Folded or PancakeState.Bagged or PancakeState.Burnt;

    private static Color InventoryColor(double fraction) => fraction switch
    {
        <= 0 => TianjinUi.Red,
        <= 0.30 => TianjinUi.Orange,
        _ => TianjinUi.Green,
    };

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

    private static StyleBoxFlat StockBarStyle(Color color) => new()
    {
        BgColor = color,
        CornerRadiusTopLeft = 3,
        CornerRadiusTopRight = 3,
        CornerRadiusBottomLeft = 3,
        CornerRadiusBottomRight = 3,
    };

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
    private void ConfigureArtInteraction(Control control)
    {
        control.MouseEntered += () => AnimateArtInteraction(control, 1.035f, new Color(1.08f, 1.08f, 1.04f, 1), 0.12);
        control.MouseExited += () => AnimateArtInteraction(control, 1f, Colors.White, 0.12);
        if (control is BaseButton button)
        {
            button.ButtonDown += () => AnimateArtInteraction(control, 0.98f, new Color(0.94f, 0.94f, 0.94f, 1), 0.10);
            button.ButtonUp += () =>
            {
                bool hovered = control.GetGlobalRect().HasPoint(control.GetGlobalMousePosition());
                AnimateArtInteraction(control, hovered ? 1.035f : 1f, hovered ? new Color(1.08f, 1.08f, 1.04f, 1) : Colors.White, 0.12);
            };
        }
        if (control is DragItem dragItem) dragItem.StartRejected += () => PulseRejected(control);
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
    private static void Place(Control control, float x, float y, float width, float height) { control.Position = new Vector2(x, y); control.Size = new Vector2(width, height); }
    private static void FullRect(Control c, float l, float t, float r, float b) { c.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); c.OffsetLeft = l; c.OffsetTop = t; c.OffsetRight = r; c.OffsetBottom = b; }
}
