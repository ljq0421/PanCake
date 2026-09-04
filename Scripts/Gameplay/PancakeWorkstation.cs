using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Pancake;
using ProjectCake.Fryer;

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

    public void Initialize(DataCatalog catalog, int stoveLevel, int stationLevel, int fryerLevel = 0, DayConfig? config = null)
    {
        Machine = new PancakeStateMachine(catalog.StovesByLevel[stoveLevel]);
        Inventory = new IngredientInventory(catalog.IngredientStationsByLevel[stationLevel]);
        Machine.Changed += Render;
        Inventory.Changed += Render;
        _canvas.Bind(Machine.Runtime);
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
        _drag = new DragService();
        AddChild(_drag);
        _drag.Configure(this);
        _audio = new PancakeAudio();
        AddChild(_audio);

        var root = new HBoxContainer();
        root.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        root.AddThemeConstantOverride("separation", 14);
        AddChild(root);
        root.AddChild(BuildLeftColumn());
        root.AddChild(BuildStove());
        root.AddChild(BuildDelivery());
        _drag.DragStarted += _ => _audio.Play(PancakeSound.PickUp);
        _drag.DragEnded += (_, accepted) => { if (!accepted) Reject("拖放位置无效。"); };
    }

    private Control BuildLeftColumn()
    {
        var column = new VBoxContainer { CustomMinimumSize = new Vector2(300, 0) };
        column.AddThemeConstantOverride("separation", 10);
        column.AddChild(BuildFryer());
        column.AddChild(BuildIngredients());
        return column;
    }

    private Control BuildFryer()
    {
        var panel = Panel("#2F2924", 300);
        panel.CustomMinimumSize = new Vector2(300, 258);
        _fryerPanel = panel;
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 6);
        panel.AddChild(column);
        column.AddChild(Text("油条锅", 22, "#FFD596"));

        var loadRow = new HBoxContainer();
        var raw = new DragItem { CustomMinimumSize = new Vector2(120, 46), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        raw.AddThemeStyleboxOverride("panel", Box(new Color("#E8C987"), 10));
        raw.AddChild(Text("生油条 · 拖", 15, "#2A211A", HorizontalAlignment.Center));
        raw.Configure(_drag, RawYoutiaoPayload, "生油条", new Color("#E8C987"), CanLoadRawYoutiao);
        raw.StartRejected += () => Reject("炸篮当前不能继续装料。");
        loadRow.AddChild(raw);
        var basket = new DropZone { CustomMinimumSize = new Vector2(120, 46), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        basket.AddChild(Text("拖入炸篮", 15, "#EFD4B2", HorizontalAlignment.Center));
        basket.Configure(id => id == RawYoutiaoPayload && CanLoadRawYoutiao(), _ => ExecuteFryer(FryerCommand.LoadOne));
        loadRow.AddChild(basket);
        _drag.RegisterZone(basket);
        column.AddChild(loadRow);

        _fryerStatus = Text("尚未解锁", 14, "#E8D3B8", HorizontalAlignment.Center);
        column.AddChild(_fryerStatus);
        var actions = new HBoxContainer();
        _lowerBasket = ActionButton("下锅", () => ExecuteFryer(FryerCommand.LowerBasket));
        _raiseBasket = ActionButton("抬篮", () => ExecuteFryer(FryerCommand.RaiseBasket));
        _discardBatch = ActionButton("清理", () => ExecuteFryer(FryerCommand.Discard));
        actions.AddChild(_lowerBasket); actions.AddChild(_raiseBasket); actions.AddChild(_discardBatch);
        column.AddChild(actions);

        _fryerStock = Text("沥油区 0/0", 14, "#BDE6C5", HorizontalAlignment.Center);
        column.AddChild(_fryerStock);
        _storedYoutiao = new DragItem { CustomMinimumSize = new Vector2(0, 42), Visible = false };
        _storedYoutiao.AddThemeStyleboxOverride("panel", Box(new Color("#D98A37"), 10));
        _storedYoutiao.AddChild(Text("熟油条 · 拖", 15, "#2A211A", HorizontalAlignment.Center));
        _storedYoutiao.Configure(_drag, StoredYoutiaoPayload, "熟油条", new Color("#D98A37"), () => InteractionEnabled && !Paused && FryerMachine?.Inventory.Count > 0);
        _storedYoutiao.StartRejected += () => Reject("沥油区没有可用油条。");
        column.AddChild(_storedYoutiao);
        return panel;
    }

    private Control BuildIngredients()
    {
        var panel = Panel("#35251E", 300);
        panel.SizeFlagsVertical = SizeFlags.ExpandFill;
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 7);
        panel.AddChild(column);
        column.AddChild(Text("配料台", 24, "#FFD596"));
        foreach ((string id, string name, Color color, bool drag) in Ingredients)
        {
            var row = new HBoxContainer { CustomMinimumSize = new Vector2(0, 62) };
            Control input;
            if (drag)
            {
                var item = new DragItem { CustomMinimumSize = new Vector2(112, 52) };
                item.AddThemeStyleboxOverride("panel", Box(color, 12));
                item.AddChild(Text(name + " 拖", 17, "#2A211A", HorizontalAlignment.Center));
                item.Configure(_drag, id, name, color, () => CanUse(id));
                item.StartRejected += () => Reject("当前不能取用该食材。");
                input = item;
            }
            else
            {
                var button = new ClickInteractable { Text = name + (id == StableIds.Ingredients.Sauce ? " 轨迹" : " 点击"), CustomMinimumSize = new Vector2(112, 52) };
                button.AddThemeStyleboxOverride("normal", Box(color, 12));
                button.AddThemeColorOverride("font_color", new Color("#2A211A"));
                button.Invoked += () =>
                {
                    if (id == StableIds.Ingredients.Egg) Execute(PancakeCommand.AddEgg);
                    else if (id == StableIds.Ingredients.Scallion) Execute(PancakeCommand.AddIngredient, id);
                    else Inform("在煎饼上按住拖动来抹酱。", false);
                };
                input = button;
            }
            row.AddChild(input);
            var count = Text("0/0", 16, "#F0DDC3", HorizontalAlignment.Center);
            count.CustomMinimumSize = new Vector2(64, 52);
            count.VerticalAlignment = VerticalAlignment.Center;
            _counts[id] = count;
            row.AddChild(count);
            var refill = SmallButton("补料");
            refill.Pressed += () => Refill(id);
            _refills[id] = refill;
            row.AddChild(refill);
            column.AddChild(row);
            _ingredientRows[id] = row;
        }
        return panel;
    }

    private Control BuildStove()
    {
        var panel = Panel("#402F27", 660);
        panel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        var stage = new Control { CustomMinimumSize = new Vector2(640, 650) };
        panel.AddChild(stage);
        _canvas = new PancakeCanvas { MouseFilter = MouseFilterEnum.Ignore };
        FullRect(_canvas, 10, 0, -10, -112);
        stage.AddChild(_canvas);
        var zone = new DropZone();
        FullRect(zone, 70, 30, -70, -150);
        stage.AddChild(zone);
        zone.Configure(CanDrop, Drop);
        _drag.RegisterZone(zone);
        _stroke = new StrokeInteractor { PancakeRadius = 178 };
        FullRect(_stroke, 70, 30, -70, -150);
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
            CreateTween().SetTrans(Tween.TransitionType.Back).TweenProperty(_canvas, "scale", Vector2.One, 0.16);
        };
        _stroke.InvalidStroke = () => Reject("当前步骤不需要轨迹操作。");
        stage.AddChild(_stroke);

        var actions = new HBoxContainer();
        actions.SetAnchorsPreset(LayoutPreset.BottomWide);
        actions.OffsetLeft = 10;
        actions.OffsetRight = -10;
        actions.OffsetTop = -96;
        actions.OffsetBottom = -36;
        actions.AddThemeConstantOverride("separation", 8);
        stage.AddChild(actions);
        _flip = ActionButton("翻面", () => Execute(PancakeCommand.Flip));
        _fold = ActionButton("折叠", () => Execute(PancakeCommand.Fold));
        _bag = ActionButton("装袋", () => Execute(PancakeCommand.Bag));
        _discard = ActionButton("清理", Discard);
        actions.AddChild(_flip); actions.AddChild(_fold); actions.AddChild(_bag); actions.AddChild(_discard);
        _state = Text("炉面空闲", 17, "#EED5B5", HorizontalAlignment.Center);
        _state.SetAnchorsPreset(LayoutPreset.BottomWide);
        _state.OffsetTop = -30;
        stage.AddChild(_state);
        return panel;
    }

    private Control BuildDelivery()
    {
        var panel = Panel("#302925", 250);
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 14);
        panel.AddChild(column);
        column.AddChild(Text("出餐", 24, "#BCE3C5", HorizontalAlignment.Center));
        var delivery = new DropZone { CustomMinimumSize = new Vector2(0, 150) };
        delivery.AddChild(Text("将装袋成品\n拖到这里", 20, "#BCE3C5", HorizontalAlignment.Center));
        delivery.Configure(CanDeliverPayload, DeliverPayload);
        column.AddChild(delivery);
        _drag.RegisterZone(delivery);
        _finished = new DragItem { CustomMinimumSize = new Vector2(0, 68), Visible = false };
        _finished.AddThemeStyleboxOverride("panel", Box(new Color("#F3D39A"), 14));
        _finished.AddChild(Text("装袋煎饼 · 拖", 18, "#3A281B", HorizontalAlignment.Center));
        _finished.Configure(_drag, "finished_pancake", "装袋煎饼", new Color("#F3D39A"), () => InteractionEnabled && Machine.Runtime.State == PancakeState.Bagged);
        column.AddChild(_finished);
        _soyPanel = new VBoxContainer();
        _soyPanel.AddChild(Text("成品豆浆", 18, "#D9F1DE", HorizontalAlignment.Center));
        _soyCup = new DragItem { CustomMinimumSize = new Vector2(0, 58) };
        _soyCup.AddThemeStyleboxOverride("panel", Box(new Color("#EDE5C9"), 12));
        _soyCup.AddChild(Text("豆浆杯 · 拖", 16, "#3A3028", HorizontalAlignment.Center));
        _soyCup.Configure(_drag, SoyMilkPayload, "豆浆", new Color("#EDE5C9"), () => InteractionEnabled && !Paused && SoyMilkTray?.CanStartDrag == true);
        _soyCup.StartRejected += () => Reject("豆浆托盘正在取杯、补货或已经空了。");
        _soyPanel.AddChild(_soyCup);
        _soyStatus = Text("6/6", 14, "#D9F1DE", HorizontalAlignment.Center); _soyPanel.AddChild(_soyStatus);
        _soyRefill = SmallButton("补满豆浆"); _soyRefill.Pressed += RefillSoyMilk; _soyPanel.AddChild(_soyRefill);
        column.AddChild(_soyPanel);
        column.AddChild(Text("选中顾客后再出餐", 15, "#A69382", HorizontalAlignment.Center));
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
            _fryerStatus.Text = $"Lv{FryerMachine.Level.Level}{automation} · {fryer.State} · 篮{fryer.Quantity}/{FryerMachine.Level.Capacity} · {fryer.FrySeconds:0.0}s · {QualityName(fryer.Quality)}";
            _fryerStock.Text = $"沥油 {FryerMachine.Inventory.Count}/{FryerMachine.Inventory.Capacity} · 浅{FryerMachine.Inventory.CountQuality(YoutiaoQuality.Light)} 金{FryerMachine.Inventory.CountQuality(YoutiaoQuality.Golden)} 深{FryerMachine.Inventory.CountQuality(YoutiaoQuality.Deep)}";
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
        _state.Text = $"{Machine.Runtime.State} · {Machine.Runtime.CookingSeconds:0.0}s · 摊{Machine.Runtime.SpreadCoverage:P0} / 酱{Machine.Runtime.SauceCoverage:P0}";
        _canvas.QueueRedraw();
    }
    private void Reject(string message) { _audio.Play(PancakeSound.Error); Inform(message, true); }
    private void Inform(string message, bool error) => Feedback?.Invoke(message, error);
    private static string QualityName(YoutiaoQuality quality) => quality switch { YoutiaoQuality.Light => "偏浅", YoutiaoQuality.Golden => "金黄", YoutiaoQuality.Deep => "偏深", _ => "焦糊" };

    private static PanelContainer Panel(string color, float width) { var p = new PanelContainer { CustomMinimumSize = new Vector2(width, 0) }; p.AddThemeStyleboxOverride("panel", Box(new Color(color), 16)); return p; }
    private static StyleBoxFlat Box(Color color, int radius) => new() { BgColor = color, CornerRadiusTopLeft = radius, CornerRadiusTopRight = radius, CornerRadiusBottomLeft = radius, CornerRadiusBottomRight = radius, ContentMarginLeft = 14, ContentMarginTop = 12, ContentMarginRight = 14, ContentMarginBottom = 12 };
    private static Label Text(string text, int size, string color, HorizontalAlignment alignment = HorizontalAlignment.Left) { var l = new Label { Text = text, HorizontalAlignment = alignment, VerticalAlignment = VerticalAlignment.Center }; l.AddThemeFontSizeOverride("font_size", size); l.AddThemeColorOverride("font_color", new Color(color)); return l; }
    private static Button SmallButton(string text) => new() { Text = text, CustomMinimumSize = new Vector2(66, 48) };
    private static Button ActionButton(string text, Action action) { var b = new ClickInteractable { Text = text, SizeFlagsHorizontal = SizeFlags.ExpandFill }; b.Invoked += action; return b; }
    private static void FullRect(Control c, float l, float t, float r, float b) { c.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); c.OffsetLeft = l; c.OffsetTop = t; c.OffsetRight = r; c.OffsetBottom = b; }
}
