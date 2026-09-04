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
    private readonly HashSet<string> _enabledIngredients = new(StringComparer.Ordinal)
    {
        StableIds.Ingredients.Batter,
        StableIds.Ingredients.Egg,
        StableIds.Ingredients.Sauce,
        StableIds.Ingredients.Crispy,
        StableIds.Ingredients.Scallion,
    };
    private DragService _drag = null!;
    private StrokeInteractor _stroke = null!;
    private PancakeCanvas _canvas = null!;
    private PancakeAudio _audio = null!;
    private DragItem _finished = null!;
    private Label _state = null!;
    private Button _flip = null!;
    private Button _fold = null!;
    private Button _bag = null!;
    private Button _discard = null!;
    private Control _fryerPanel = null!;
    private TextureRect _fryerArt = null!;
    private Label _fryerStatus = null!;
    private Label _fryerStock = null!;
    private Button _lowerBasket = null!;
    private Button _raiseBasket = null!;
    private Button _discardBatch = null!;
    private DragItem _storedYoutiao = null!;
    private Control _soyPanel = null!;
    private Label _soyStatus = null!;
    private DragItem _soyCup = null!;
    private Button _soyRefill = null!;
    private TianjinArtCatalog _art = null!;
    private int _stoveLevel = 1;
    private bool _initialized;

    public event Action<string, bool>? Feedback;
    public event Action<int>? YoutiaoConsumed;
    public event Action<int>? YoutiaoBurnt;
    public PancakeStateMachine Machine { get; private set; } = null!;
    public IngredientInventory Inventory { get; private set; } = null!;
    public FryerStateMachine? FryerMachine { get; private set; }
    public SoyMilkTrayRuntime? SoyMilkTray { get; private set; }
    public Func<PancakeStateMachine, bool>? SubmitPrepared { get; set; }
    public Func<ProductKind, bool>? SubmitProduct { get; set; }
    public bool InteractionEnabled { get; set; } = true;
    public bool Paused { get; set; }

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog, int stoveLevel, int stationLevel, int fryerLevel = 0, DayConfig? config = null, TianjinArtCatalog? art = null)
    {
        _art = art ?? _art;
        _stoveLevel = stoveLevel;
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
        SoyMilkTray?.Tick(deltaSeconds);
        RenderLive();
    }

    public void CancelInput()
    {
        _drag.CancelDrag();
        _stroke.CancelStroke();
    }

    public void ResetForDay()
    {
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
        Place(fryer, 24, 612, 348, 420);
        stage.AddChild(fryer);
        Control stove = BuildStove();
        Place(stove, 430, 486, 850, 546);
        stage.AddChild(stove);
        Control ingredients = BuildIngredients();
        Place(ingredients, 1320, 590, 576, 442);
        stage.AddChild(ingredients);
        Control delivery = BuildDelivery();
        Place(delivery, 1438, 458, 430, 120);
        stage.AddChild(delivery);
        _drag.DragStarted += _ => _audio.Play(PancakeSound.PickUp);
        _drag.DragEnded += (_, accepted) => { if (!accepted) Reject("拖放位置无效。"); };
    }

    private Control BuildFryer()
    {
        var panel = Panel(TianjinUi.Paper, 348);
        _fryerPanel = panel;
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 5);
        panel.AddChild(column);
        column.AddChild(Text("油条备货", 22, TianjinUi.BrownText));

        var equipmentRow = new HBoxContainer();
        equipmentRow.AddThemeConstantOverride("separation", 6);
        _fryerArt = TianjinUi.Texture(_art.Fryer(1), new Vector2(154, 166));
        equipmentRow.AddChild(_fryerArt);

        var loadColumn = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        var raw = new DragItem { CustomMinimumSize = new Vector2(0, 68), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        raw.AddThemeStyleboxOverride("panel", Box(new Color("#F7D892"), 12));
        var rawContent = new HBoxContainer();
        rawContent.AddChild(TianjinUi.Texture(_art.RawYoutiao, new Vector2(58, 58)));
        rawContent.AddChild(Text("生油条\n拖入炸篮", 16, TianjinUi.BrownText, HorizontalAlignment.Center));
        raw.AddChild(rawContent);
        raw.Configure(_drag, RawYoutiaoPayload, "生油条", new Color("#F7D892"), new DragVisualSpec(_art.RawYoutiao, new Vector2(105, 105)), CanLoadRawYoutiao);
        raw.StartRejected += () => Reject("炸篮当前不能继续装料。");
        loadColumn.AddChild(raw);
        var basket = new DropZone { CustomMinimumSize = new Vector2(0, 58), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        basket.AddThemeStyleboxOverride("panel", Box(TianjinUi.Cream, 12));
        basket.AddChild(Text("炸篮投放区", 16, TianjinUi.BrownText, HorizontalAlignment.Center));
        basket.Configure(id => id == RawYoutiaoPayload && CanLoadRawYoutiao(), _ => ExecuteFryer(FryerCommand.LoadOne));
        loadColumn.AddChild(basket);
        _drag.RegisterZone(basket);
        equipmentRow.AddChild(loadColumn);
        column.AddChild(equipmentRow);

        _fryerStatus = Text("尚未解锁", 16, TianjinUi.BrownText, HorizontalAlignment.Center);
        column.AddChild(_fryerStatus);
        var actions = new HBoxContainer();
        _lowerBasket = ActionButton("下锅", () => ExecuteFryer(FryerCommand.LowerBasket));
        _raiseBasket = ActionButton("抬篮", () => ExecuteFryer(FryerCommand.RaiseBasket));
        _discardBatch = ActionButton("清理", () => ExecuteFryer(FryerCommand.Discard));
        actions.AddChild(_lowerBasket); actions.AddChild(_raiseBasket); actions.AddChild(_discardBatch);
        column.AddChild(actions);

        var stockRow = new HBoxContainer();
        _fryerStock = Text("沥油区 0/0", 15, TianjinUi.BrownText, HorizontalAlignment.Center);
        _fryerStock.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        stockRow.AddChild(_fryerStock);
        _storedYoutiao = new DragItem { CustomMinimumSize = new Vector2(116, 54), Visible = false };
        _storedYoutiao.AddThemeStyleboxOverride("panel", Box(new Color("#F6C35A"), 10));
        var storedContent = new HBoxContainer();
        storedContent.AddChild(TianjinUi.Texture(_art.Ingredient(StableIds.Ingredients.Youtiao), new Vector2(52, 48)));
        storedContent.AddChild(Text("取油条", 15, TianjinUi.BrownText, HorizontalAlignment.Center));
        _storedYoutiao.AddChild(storedContent);
        _storedYoutiao.Configure(_drag, StoredYoutiaoPayload, "熟油条", TianjinUi.Yellow, new DragVisualSpec(_art.Ingredient(StableIds.Ingredients.Youtiao), new Vector2(115, 105)), () => InteractionEnabled && !Paused && FryerMachine?.Inventory.Count > 0);
        _storedYoutiao.StartRejected += () => Reject("沥油区没有可用油条。");
        stockRow.AddChild(_storedYoutiao);
        column.AddChild(stockRow);
        return panel;
    }

    private Control BuildIngredients()
    {
        var panel = Panel(TianjinUi.Paper, 576);
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 8);
        panel.AddChild(column);
        column.AddChild(Text("配料台 · 点击补满", 22, TianjinUi.BrownText));
        var grid = new GridContainer { Columns = 2, SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill };
        grid.AddThemeConstantOverride("h_separation", 8);
        grid.AddThemeConstantOverride("v_separation", 8);
        column.AddChild(grid);
        foreach ((string id, string name, Color color, bool drag) in Ingredients)
        {
            var slot = new PanelContainer { CustomMinimumSize = new Vector2(260, 80), SizeFlagsHorizontal = SizeFlags.ExpandFill };
            slot.AddThemeStyleboxOverride("panel", Box(color.Lightened(0.26f), 12));
            var row = new HBoxContainer { CustomMinimumSize = new Vector2(0, 68) };
            row.AddThemeConstantOverride("separation", 4);
            slot.AddChild(row);
            Control input;
            Texture2D texture = _art.Ingredient(id);
            if (drag)
            {
                var item = new DragItem { CustomMinimumSize = new Vector2(138, 62), SizeFlagsHorizontal = SizeFlags.ExpandFill };
                item.AddThemeStyleboxOverride("panel", Box(color.Lightened(0.13f), 10));
                var content = new HBoxContainer();
                content.AddChild(TianjinUi.Texture(texture, new Vector2(52, 52)));
                content.AddChild(Text(name + "\n拖动", 16, TianjinUi.BrownText, HorizontalAlignment.Center));
                item.AddChild(content);
                item.Configure(_drag, id, name, color, new DragVisualSpec(texture, new Vector2(105, 105)), () => CanUse(id));
                item.StartRejected += () => Reject("当前不能取用该食材。");
                input = item;
            }
            else
            {
                var button = new ClickInteractable
                {
                    Text = name + (id == StableIds.Ingredients.Sauce ? "\n抹酱" : "\n点击"),
                    Icon = texture,
                    ExpandIcon = true,
                    CustomMinimumSize = new Vector2(138, 62),
                    SizeFlagsHorizontal = SizeFlags.ExpandFill,
                };
                ApplyActionStyle(button, color.Lightened(0.13f));
                button.Invoked += () =>
                {
                    if (id == StableIds.Ingredients.Egg) Execute(PancakeCommand.AddEgg);
                    else if (id == StableIds.Ingredients.Scallion) Execute(PancakeCommand.AddIngredient, id);
                    else Inform("在煎饼上按住拖动来抹酱。", false);
                };
                input = button;
            }
            row.AddChild(input);
            var count = Text("0/0", 16, TianjinUi.BrownText, HorizontalAlignment.Center);
            count.CustomMinimumSize = new Vector2(48, 58);
            _counts[id] = count;
            row.AddChild(count);
            var refill = SmallButton("补");
            refill.CustomMinimumSize = new Vector2(48, 48);
            refill.Pressed += () => Refill(id);
            _refills[id] = refill;
            row.AddChild(refill);
            grid.AddChild(slot);
            _ingredientRows[id] = slot;
        }
        return panel;
    }

    private Control BuildStove()
    {
        var panel = Panel(new Color(1f, 0.95f, 0.82f, 0.94f), 850);
        var stage = new Control();
        TianjinUi.FullRect(stage);
        panel.AddChild(stage);
        _canvas = new PancakeCanvas { MouseFilter = MouseFilterEnum.Ignore };
        FullRect(_canvas, 10, -6, -10, -80);
        stage.AddChild(_canvas);
        var zone = new DropZone();
        FullRect(zone, 150, 30, -150, -118);
        stage.AddChild(zone);
        zone.Configure(CanDrop, Drop);
        _drag.RegisterZone(zone);
        _stroke = new StrokeInteractor { PancakeRadius = 142 };
        FullRect(_stroke, 150, 30, -150, -118);
        _stroke.ResolveMode = ResolveStroke;
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
        actions.SetAnchorsPreset(LayoutPreset.BottomWide);
        actions.OffsetLeft = 18;
        actions.OffsetRight = -18;
        actions.OffsetTop = -78;
        actions.OffsetBottom = -18;
        actions.AddThemeConstantOverride("separation", 8);
        stage.AddChild(actions);
        _flip = ActionButton("翻面", () => Execute(PancakeCommand.Flip));
        _fold = ActionButton("折叠", () => Execute(PancakeCommand.Fold));
        _bag = ActionButton("装袋", () => Execute(PancakeCommand.Bag));
        _discard = ActionButton("清理", Discard);
        _flip.Icon = _art.Spatula; _flip.ExpandIcon = true;
        _fold.Icon = _art.Scraper; _fold.ExpandIcon = true;
        _bag.Icon = _art.FinishedPancake; _bag.ExpandIcon = true;
        actions.AddChild(_flip); actions.AddChild(_fold); actions.AddChild(_bag); actions.AddChild(_discard);
        _state = Text("空炉 · 拖入面糊开始", 17, TianjinUi.BrownText, HorizontalAlignment.Center);
        _state.SetAnchorsPreset(LayoutPreset.TopWide);
        _state.OffsetTop = 8;
        _state.OffsetBottom = 42;
        stage.AddChild(_state);
        return panel;
    }

    private Control BuildDelivery()
    {
        var panel = Panel(new Color("#E7F0C7"), 430);
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 8);
        panel.AddChild(row);
        var delivery = new DropZone { CustomMinimumSize = new Vector2(126, 92) };
        delivery.AddChild(Text("出餐口\n拖到这里", 17, TianjinUi.BrownText, HorizontalAlignment.Center));
        delivery.Configure(CanDeliverPayload, DeliverPayload);
        row.AddChild(delivery);
        _drag.RegisterZone(delivery);
        _finished = new DragItem { CustomMinimumSize = new Vector2(126, 92), Visible = false };
        _finished.AddThemeStyleboxOverride("panel", Box(TianjinUi.Cream, 14));
        var finishedRow = new HBoxContainer();
        finishedRow.AddChild(TianjinUi.Texture(_art.FinishedPancake, new Vector2(70, 64)));
        finishedRow.AddChild(Text("煎饼\n拖动", 15, TianjinUi.BrownText, HorizontalAlignment.Center));
        _finished.AddChild(finishedRow);
        _finished.Configure(_drag, "finished_pancake", "装袋煎饼", TianjinUi.Cream, new DragVisualSpec(_art.FinishedPancake, new Vector2(150, 125)), () => InteractionEnabled && Machine.Runtime.State == PancakeState.Bagged);
        row.AddChild(_finished);
        _soyPanel = new HBoxContainer { CustomMinimumSize = new Vector2(126, 92) };
        _soyCup = new DragItem { CustomMinimumSize = new Vector2(74, 86) };
        _soyCup.AddThemeStyleboxOverride("panel", Box(new Color("#F4EFD8"), 12));
        var soyContent = new HBoxContainer();
        soyContent.AddChild(TianjinUi.Texture(_art.Product(ProductKind.SoyMilk), new Vector2(44, 58)));
        _soyCup.AddChild(soyContent);
        _soyCup.Configure(_drag, SoyMilkPayload, "豆浆", TianjinUi.Cream, new DragVisualSpec(_art.Product(ProductKind.SoyMilk), new Vector2(88, 98)), () => InteractionEnabled && !Paused && SoyMilkTray?.CanStartDrag == true);
        _soyCup.StartRejected += () => Reject("豆浆托盘正在取杯、补货或已经空了。");
        _soyPanel.AddChild(_soyCup);
        var soyActions = new VBoxContainer();
        _soyStatus = Text("6/6", 14, TianjinUi.BrownText, HorizontalAlignment.Center); soyActions.AddChild(_soyStatus);
        _soyRefill = SmallButton("补"); _soyRefill.CustomMinimumSize = new Vector2(48, 48); _soyRefill.Pressed += RefillSoyMilk; soyActions.AddChild(_soyRefill);
        _soyPanel.AddChild(soyActions);
        row.AddChild(_soyPanel);
        return panel;
    }

    private bool CanUse(string id) => _initialized && InteractionEnabled && !Paused && _enabledIngredients.Contains(id) && Inventory.GetQuantity(id) > 0 && !Inventory.IsRefilling(id);
    private bool CanDrop(string id) => InteractionEnabled && id switch
    {
        StableIds.Ingredients.Batter => Machine.Runtime.State == PancakeState.Empty,
        StableIds.Ingredients.Crispy or StableIds.Ingredients.Ham or StoredYoutiaoPayload => Machine.Runtime.State is PancakeState.Sauced or PancakeState.Toppings,
        _ => false,
    };
    private void Drop(string id)
    {
        if (id == StableIds.Ingredients.Batter) Execute(PancakeCommand.PlaceBatter);
        else Execute(PancakeCommand.AddIngredient, id == StoredYoutiaoPayload ? StableIds.Ingredients.Youtiao : id);
    }
    private StrokeMode ResolveStroke() => !InteractionEnabled ? StrokeMode.None : Machine.Runtime.State switch
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
    private void Execute(PancakeCommand command, string? id = null)
    {
        if (!_initialized || !InteractionEnabled || Paused) return;
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
            return;
        }

        if (consumedYoutiao is YoutiaoQuality quality)
        {
            Machine.TrySetInternalYoutiaoQuality(quality);
            YoutiaoConsumed?.Invoke(1);
        }

        if (command is PancakeCommand.PlaceBatter or PancakeCommand.AddEgg) _audio.Play(PancakeSound.Sizzle);
        else if (command == PancakeCommand.Flip) _audio.Play(PancakeSound.Flip);
        Inform(result.Message, false);
    }
    private bool CanLoadRawYoutiao() => _initialized && InteractionEnabled && !Paused && FryerMachine is not null
        && FryerMachine.Runtime.State is FryerState.Empty or FryerState.Loaded
        && FryerMachine.Runtime.Quantity < FryerMachine.Level.Capacity;
    private void ExecuteFryer(FryerCommand command)
    {
        if (FryerMachine is null || !InteractionEnabled || Paused) return;
        FryerActionResult result = FryerMachine.TryExecute(command);
        if (!result.Success) Reject(result.Message);
        else
        {
            if (command == FryerCommand.LowerBasket) _audio.Play(PancakeSound.Sizzle);
            else if (command == FryerCommand.RaiseBasket) _audio.Play(PancakeSound.Flip);
            Inform(result.Message, false);
        }
    }
    private bool CanDeliverPayload(string id) => InteractionEnabled && !Paused && id switch
    {
        "finished_pancake" => Machine.Runtime.State == PancakeState.Bagged,
        StoredYoutiaoPayload => FryerMachine?.Inventory.Count > 0,
        SoyMilkPayload => SoyMilkTray?.CanStartDrag == true,
        _ => false,
    };
    private void DeliverPayload(string id)
    {
        if (id == "finished_pancake") Submit();
        else if (id == StoredYoutiaoPayload) SubmitStandalone(ProductKind.Youtiao);
        else if (id == SoyMilkPayload) SubmitStandalone(ProductKind.SoyMilk);
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
        if (SoyMilkTray?.TryBeginRefill() != true) Reject("豆浆托盘已满或当前不能补货。");
        else Inform("开始补豆浆，0.6 秒后补满。", false);
    }
    private void Refill(string id)
    {
        if (!InteractionEnabled || !Inventory.TryBeginRefill(id)) Reject("料盒已满或正在补料。");
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
            _ingredientRows[id].Visible = _enabledIngredients.Contains(id);
            label.Text = Inventory.IsRefilling(id) ? $"{Inventory.GetRefillProgress(id):P0}" : $"{Inventory.GetQuantity(id)}/{Inventory.GetCapacity(id)}";
            _refills[id].Disabled = !InteractionEnabled || Inventory.IsRefilling(id) || Inventory.GetQuantity(id) >= Inventory.GetCapacity(id);
        }
        PancakeState state = Machine.Runtime.State;
        _finished.Visible = state == PancakeState.Bagged;
        _flip.Disabled = !InteractionEnabled || state is not (PancakeState.SideAReady or PancakeState.SideAOverdone);
        _fold.Disabled = !InteractionEnabled || state is not (PancakeState.Sauced or PancakeState.Toppings);
        _bag.Disabled = !InteractionEnabled || state != PancakeState.Folded;
        _discard.Disabled = !InteractionEnabled || state == PancakeState.Empty;
        _fryerPanel.Visible = FryerMachine is not null;
        if (FryerMachine is not null)
        {
            FryerBatchRuntime fryer = FryerMachine.Runtime;
            string automation = FryerMachine.Level.AutoRaise ? " · 自动抬篮" : string.Empty;
            _fryerArt.Texture = _art.Fryer(FryerMachine.Level.Level);
            _fryerStatus.Text = $"Lv{FryerMachine.Level.Level}{automation} · {FryerStateName(fryer.State)} · {fryer.Quantity}/{FryerMachine.Level.Capacity} · {QualityName(fryer.Quality)}";
            _fryerStock.Text = $"沥油区 {FryerMachine.Inventory.Count}/{FryerMachine.Inventory.Capacity}  金黄 {FryerMachine.Inventory.CountQuality(YoutiaoQuality.Golden)}";
            _storedYoutiao.Visible = FryerMachine.Inventory.Count > 0;
            _lowerBasket.Disabled = !InteractionEnabled || fryer.State != FryerState.Loaded;
            _raiseBasket.Disabled = !InteractionEnabled || fryer.State != FryerState.Frying || FryerMachine.Level.AutoRaise;
            _discardBatch.Disabled = !InteractionEnabled || fryer.State == FryerState.Empty;
        }
        _soyPanel.Visible = SoyMilkTray is not null;
        if (SoyMilkTray is not null)
        {
            _soyStatus.Text = SoyMilkTray.IsRefilling ? $"补货 {SoyMilkTray.RefillProgress:P0}" : SoyMilkTray.IsTaking ? $"取杯 {SoyMilkTray.TakingProgress:P0}" : $"{SoyMilkTray.Quantity}/{SoyMilkTray.Capacity}";
            _soyRefill.Disabled = !InteractionEnabled || SoyMilkTray.Quantity >= SoyMilkTray.Capacity || SoyMilkTray.IsRefilling || SoyMilkTray.IsTaking;
        }
        RenderLive();
    }
    private void RenderLive()
    {
        if (!_initialized) return;
        _state.Text = PancakeStatus(Machine.Runtime);
        _canvas.QueueRedraw();
    }
    private void Reject(string message) { _audio.Play(PancakeSound.Error); Inform(message, true); }
    private void Inform(string message, bool error) => Feedback?.Invoke(message, error);
    private static string QualityName(YoutiaoQuality quality) => quality switch { YoutiaoQuality.Light => "偏浅", YoutiaoQuality.Golden => "金黄", YoutiaoQuality.Deep => "偏深", _ => "焦糊" };
    private static string FryerStateName(FryerState state) => state switch
    {
        FryerState.Empty => "空篮",
        FryerState.Loaded => "待下锅",
        FryerState.Frying => "炸制中",
        FryerState.Raised or FryerState.Draining => "沥油中",
        FryerState.Burnt => "已焦糊",
        _ => "空篮",
    };
    private static string PancakeStatus(PancakeRuntime runtime) => runtime.State switch
    {
        PancakeState.Empty => "空炉 · 拖入面糊开始",
        PancakeState.BatterPlaced or PancakeState.Spreading => $"用刮板摊开 · {runtime.SpreadCoverage:P0}",
        PancakeState.Spread => "点击鸡蛋，开始煎第一面",
        PancakeState.SideACooking => $"第一面加热中 · {runtime.CookingSeconds:0.0} 秒",
        PancakeState.SideAReady => "火候正好 · 点击铲子翻面",
        PancakeState.SideAOverdone => "颜色变深了 · 尽快翻面",
        PancakeState.SideBCooking => $"第二面加热中 · {runtime.CookingSeconds:0.0} 秒",
        PancakeState.SideBReady or PancakeState.Saucing => $"抹上酱料 · {runtime.SauceCoverage:P0}",
        PancakeState.Sauced or PancakeState.Toppings => "按订单加料，完成后折叠",
        PancakeState.Folded => "已经折好 · 点击装袋",
        PancakeState.Bagged => "装袋完成 · 拖到出餐口",
        PancakeState.Burnt => "煎饼焦了 · 清理炉面",
        _ => "制作中",
    };

    private static PanelContainer Panel(Color color, float width) { var p = TianjinUi.Panel(color); p.CustomMinimumSize = new Vector2(width, 0); return p; }
    private static PanelContainer Panel(string color, float width) => Panel(new Color(color), width);
    private static StyleBoxFlat Box(Color color, int radius) => TianjinUi.Box(color, radius, 3, false);
    private static Label Text(string text, int size, Color color, HorizontalAlignment alignment = HorizontalAlignment.Left) => TianjinUi.Label(text, size, color, alignment);
    private static Label Text(string text, int size, string color, HorizontalAlignment alignment = HorizontalAlignment.Left) => Text(text, size, new Color(color), alignment);
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
