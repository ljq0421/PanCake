using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

/*
THESIS: the player returns to a warm shop ledger where opening the next day is always the clearest action; the old day-grid dashboard is not the product.
OWN-WORLD: cream paper, warm yellow and orange controls, dark-brown four-pixel outlines, round corners, one soft downward shadow, and real Tianjin equipment art.
STORY: read today's plan, inspect the shop, choose an upgrade, open the shutters, then return with a receipt.
FIRST VIEWPORT: today's wooden sign owns the left half, the three physical equipment stations own the right, and the opening button is the largest control.
FORM: a street-shop operating board built directly from the approved Tianjin art direction.
*/
public partial class MorningHub : Control
{
    public event Action<int>? DayRequested;
    public event Action? LabRequested;
    public event Action? DebugRequested;
    public event Action? MapRequested;

    private readonly List<Button> _dayButtons = new();
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private TianjinArtCatalog _art = null!;
    private Label _coins = null!;
    private Label _progress = null!;
    private Label _dayTitle = null!;
    private Label _daySubtitle = null!;
    private Label _dayRecord = null!;
    private Label _message = null!;
    private Button _openButton = null!;
    private HBoxContainer _equipment = null!;
    private PanelContainer _ledger = null!;
    private ConfirmationDialog _resetDialog = null!;

    public bool DeveloperToolsVisible => OS.GetCmdlineUserArgs().Contains("--dev-ui", StringComparer.Ordinal);

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog, SaveService save)
    {
        _catalog = catalog;
        _save = save;
        _save.Changed += Render;
        Render();
    }

    public override void _ExitTree()
    {
        if (_save is not null) _save.Changed -= Render;
    }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        Theme = TianjinUi.CreateTheme();
        _art = new TianjinArtCatalog();
        var background = new ColorRect { Color = new Color("#F1C47C"), MouseFilter = MouseFilterEnum.Ignore };
        TianjinUi.FullRect(background);
        AddChild(background);

        var topBand = new ColorRect { Color = new Color("#C95335"), MouseFilter = MouseFilterEnum.Ignore };
        topBand.SetAnchorsPreset(LayoutPreset.TopWide);
        topBand.OffsetBottom = 112;
        AddChild(topBand);

        var margin = new MarginContainer();
        TianjinUi.FullRect(margin, 58, 32, -58, -38);
        AddChild(margin);
        var root = new VBoxContainer();
        root.AddThemeConstantOverride("separation", 24);
        margin.AddChild(root);

        var header = new HBoxContainer { CustomMinimumSize = new Vector2(0, 76) };
        root.AddChild(header);
        var title = TianjinUi.Label("早餐铺子 · 天津", 42, TianjinUi.Paper);
        title.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        header.AddChild(title);
        var coin = TianjinUi.Texture(_art.Coin, new Vector2(58, 58));
        header.AddChild(coin);
        _coins = TianjinUi.Label("¥0", 30, TianjinUi.Paper);
        header.AddChild(_coins);
        _progress = TianjinUi.Label("Day 1 · 0星", 22, TianjinUi.Paper);
        _progress.CustomMinimumSize = new Vector2(230, 0);
        _progress.HorizontalAlignment = HorizontalAlignment.Right;
        header.AddChild(_progress);

        var content = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddThemeConstantOverride("separation", 28);
        root.AddChild(content);
        content.AddChild(BuildTodayBoard());
        content.AddChild(BuildEquipmentBoard());

        _message = TianjinUi.Label(string.Empty, 18, TianjinUi.BrownText, HorizontalAlignment.Center);
        _message.CustomMinimumSize = new Vector2(0, 30);
        root.AddChild(_message);

        BuildLedger();
        BuildResetDialog();
    }

    private Control BuildTodayBoard()
    {
        var board = TianjinUi.Panel(new Color("#FFF5DA"), 22);
        board.CustomMinimumSize = new Vector2(650, 0);
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 18);
        board.AddChild(column);

        column.AddChild(TianjinUi.Label("今天的营业牌", 28, TianjinUi.BrownText));
        _dayTitle = TianjinUi.Label("Day 1", 60, TianjinUi.BrownDark);
        column.AddChild(_dayTitle);
        _daySubtitle = TianjinUi.Label("基础煎饼", 28, TianjinUi.Orange);
        column.AddChild(_daySubtitle);
        var divider = new HSeparator();
        divider.AddThemeConstantOverride("separation", 18);
        column.AddChild(divider);
        _dayRecord = TianjinUi.Label("第一次开店，慢慢来。", 20, TianjinUi.BrownText);
        _dayRecord.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _dayRecord.SizeFlagsVertical = SizeFlags.ExpandFill;
        column.AddChild(_dayRecord);

        _openButton = TianjinUi.Button("打开铺门 · 开始营业", true, new Vector2(0, 84));
        _openButton.Pressed += StartPrimaryDay;
        column.AddChild(_openButton);

        var navigation = new HBoxContainer();
        navigation.AddThemeConstantOverride("separation", 12);
        var ledger = TianjinUi.Button("经营手账", false, new Vector2(0, 60));
        ledger.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        ledger.Pressed += ShowLedger;
        navigation.AddChild(ledger);
        var map = TianjinUi.Button("城市地图", false, new Vector2(0, 60));
        map.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        map.Pressed += () => MapRequested?.Invoke();
        navigation.AddChild(map);
        column.AddChild(navigation);

        if (DeveloperToolsVisible)
        {
            var dev = new HBoxContainer();
            dev.AddThemeConstantOverride("separation", 8);
            var lab = TianjinUi.Button("煎饼实验台");
            lab.Pressed += () => LabRequested?.Invoke();
            dev.AddChild(lab);
            var data = TianjinUi.Button("Day 数据");
            data.Pressed += () => DebugRequested?.Invoke();
            dev.AddChild(data);
            column.AddChild(dev);
        }
        return board;
    }

    private Control BuildEquipmentBoard()
    {
        var board = TianjinUi.Panel(new Color("#F9E4B7"), 22);
        board.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 16);
        board.AddChild(column);
        var heading = new HBoxContainer();
        var title = TianjinUi.Label("店里现在这样", 28, TianjinUi.BrownText);
        title.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        heading.AddChild(title);
        heading.AddChild(TianjinUi.Label("升级会直接改变设备", 18, TianjinUi.Brown));
        column.AddChild(heading);
        _equipment = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _equipment.AddThemeConstantOverride("separation", 14);
        column.AddChild(_equipment);
        return board;
    }

    private void BuildLedger()
    {
        _ledger = TianjinUi.Panel(TianjinUi.Paper, 22);
        _ledger.Position = new Vector2(240, 120);
        _ledger.Size = new Vector2(1440, 840);
        _ledger.ZIndex = 100;
        _ledger.Visible = false;
        AddChild(_ledger);
        var column = new VBoxContainer();
        column.AddThemeConstantOverride("separation", 16);
        _ledger.AddChild(column);
        var heading = new HBoxContainer();
        var title = TianjinUi.Label("经营手账", 34, TianjinUi.BrownText);
        title.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        heading.AddChild(title);
        var reset = TianjinUi.Button("重置进度");
        reset.Pressed += () => _resetDialog.PopupCentered();
        heading.AddChild(reset);
        var close = TianjinUi.Button("合上手账");
        close.Pressed += () => _ledger.Visible = false;
        heading.AddChild(close);
        column.AddChild(heading);
        column.AddChild(TianjinUi.Label("点击已经解锁的日期可以再次营业；重玩只补发超过历史最佳的收入差额。", 18, TianjinUi.Brown));
        var scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill, HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        column.AddChild(scroll);
        var grid = new GridContainer { Columns = 5, SizeFlagsHorizontal = SizeFlags.ExpandFill };
        grid.AddThemeConstantOverride("h_separation", 12);
        grid.AddThemeConstantOverride("v_separation", 12);
        scroll.AddChild(grid);
        for (int day = 1; day <= 15; day++)
        {
            int selected = day;
            var button = TianjinUi.Button($"Day {day}\n{DaySubtitle(day)}", false, new Vector2(250, 112));
            button.Pressed += () => { _ledger.Visible = false; DayRequested?.Invoke(selected); };
            grid.AddChild(button);
            _dayButtons.Add(button);
        }
    }

    private void BuildResetDialog()
    {
        _resetDialog = new ConfirmationDialog
        {
            Title = "重置进度",
            DialogText = "将清除金币、升级与每日最佳记录。此操作不可撤销。",
            OkButtonText = "确认重置",
        };
        _resetDialog.Confirmed += () =>
        {
            _save.ResetProgress(out string error);
            _message.Text = string.IsNullOrEmpty(error) ? "进度已重置，今天重新开张。" : error;
            _message.Modulate = string.IsNullOrEmpty(error) ? TianjinUi.Green : TianjinUi.Red;
        };
        AddChild(_resetDialog);
    }

    public void ShowLedger()
    {
        RenderLedger();
        _ledger.Visible = true;
    }

    private void Render()
    {
        if (_save is null) return;
        int day = Math.Clamp(_save.Data.HighestUnlockedDay, 1, 15);
        _coins.Text = $"¥{_save.Data.Coins}";
        _progress.Text = $"已到 Day {day}  ·  天津 {_save.Data.TianjinBestStars} 星";
        _dayTitle.Text = $"Day {day}";
        _daySubtitle.Text = DaySubtitle(day);
        _openButton.Text = _save.Data.TianjinCompleted ? "再次挑战 · Day 15" : $"打开铺门 · 开始 Day {day}";
        _openButton.Disabled = _save.HasLoadError;
        _dayRecord.Text = _save.Data.DayBestRecords.TryGetValue(day, out DayBestRecord? record)
            ? $"历史最佳营业额  ¥{record.TotalRevenue}\n满意度  {record.Satisfaction:0}%  ·  Perfect {record.PerfectOrders} 单\n设备和客流已经准备好，随时可以开门。"
            : $"{DayPlanText(day)}\n这是新的营业日，先看订单再安排工作台。";
        RenderEquipment();
        RenderLedger();
        if (_save.HasLoadError)
        {
            _message.Text = "！ 存档无法读取。请打开经营手账并重置进度后再营业。";
            _message.Modulate = TianjinUi.Red;
        }
    }

    private void RenderEquipment()
    {
        foreach (Node child in _equipment.GetChildren()) child.QueueFree();
        _equipment.AddChild(EquipmentCard(
            "煎饼炉",
            _art.Stove(_save.Data.PurchasedStoveLevel),
            _save.Data.PurchasedStoveLevel,
            NextStoveUpgrade()));
        _equipment.AddChild(EquipmentCard(
            "油条锅",
            _art.Fryer(Math.Max(1, _save.Data.PurchasedFryerLevel)),
            _save.Data.PurchasedFryerLevel,
            NextFryerUpgrade()));
        _equipment.AddChild(EquipmentCard(
            "配料台",
            _art.Ingredient(StableIds.Ingredients.Crispy),
            _save.Data.PurchasedIngredientStationLevel,
            NextStationUpgrade()));
    }

    private Control EquipmentCard(string name, Texture2D texture, int level, UpgradeOffer? offer)
    {
        var card = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        card.AddThemeConstantOverride("separation", 8);
        var image = TianjinUi.Texture(texture, new Vector2(0, 340));
        image.SizeFlagsVertical = SizeFlags.ExpandFill;
        card.AddChild(image);
        card.AddChild(TianjinUi.Label(level == 0 ? $"{name} · 尚未解锁" : $"{name} · Lv{level}", 22, TianjinUi.BrownText, HorizontalAlignment.Center));
        if (offer is UpgradeOffer upgrade)
        {
            var button = TianjinUi.Button($"{upgrade.Effect}\n¥{upgrade.Price}", true, new Vector2(0, 74));
            button.Disabled = _save.Data.Coins < upgrade.Price;
            button.Pressed += () => Purchase(upgrade.Id);
            card.AddChild(button);
        }
        else
        {
            string note = level == 0 ? "完成 Day 5 自动安装" : "当前可用的最好设备";
            card.AddChild(TianjinUi.Label(note, 17, TianjinUi.Brown, HorizontalAlignment.Center));
        }
        return card;
    }

    private void RenderLedger()
    {
        if (_save is null) return;
        for (int index = 0; index < _dayButtons.Count; index++)
        {
            int day = index + 1;
            Button button = _dayButtons[index];
            button.Disabled = _save.HasLoadError || day > _save.Data.HighestUnlockedDay;
            button.Text = _save.Data.DayBestRecords.TryGetValue(day, out DayBestRecord? best)
                ? $"Day {day} · {DaySubtitle(day)}\n最佳 ¥{best.TotalRevenue}\n满意 {best.Satisfaction:0}%"
                : day <= _save.Data.HighestUnlockedDay
                    ? $"Day {day} · {DaySubtitle(day)}\n等待开店"
                    : $"Day {day}\n尚未解锁";
        }
    }

    private void StartPrimaryDay() => DayRequested?.Invoke(Math.Clamp(_save.Data.HighestUnlockedDay, 1, 15));

    private void Purchase(string id)
    {
        bool ok = _save.TryPurchase(id, _catalog, out string error);
        _message.Text = ok ? "新设备已经装好，下次营业立即生效。" : error;
        _message.Modulate = ok ? TianjinUi.Green : TianjinUi.Red;
        Render();
    }

    private UpgradeOffer? NextStoveUpgrade() => FirstAvailable(
        ("equipment:pancake_stove_lv2", "恒温不焦", 120, _save.Data.PurchasedStoveLevel >= 2),
        ("equipment:pancake_stove_lv3", "恒温快热", 300, _save.Data.PurchasedStoveLevel >= 3));
    private UpgradeOffer? NextFryerUpgrade() => FirstAvailable(
        ("equipment:fryer_lv2", "扩容加速", 160, _save.Data.PurchasedFryerLevel >= 2),
        ("equipment:fryer_lv3", "自动抬篮", 320, _save.Data.PurchasedFryerLevel >= 3));
    private UpgradeOffer? NextStationUpgrade() => FirstAvailable(
        ("equipment:ingredient_station_lv2", "料盒扩容", 60, _save.Data.PurchasedIngredientStationLevel >= 2),
        ("equipment:ingredient_station_lv3", "再次扩容", 180, _save.Data.PurchasedIngredientStationLevel >= 3));

    private UpgradeOffer? FirstAvailable(params (string Id, string Effect, int Price, bool Owned)[] choices)
    {
        foreach ((string id, string effect, int price, bool owned) in choices)
            if (!owned && _save.Data.UnlockedUpgradeIds.Contains(id, StringComparer.Ordinal)) return new UpgradeOffer(id, effect, price);
        return null;
    }

    private static string DaySubtitle(int day) => day switch
    {
        1 => "第一张煎饼", 2 => "薄脆上桌", 3 => "香葱飘香", 4 => "第一次早高峰",
        5 => "油条开锅", 6 => "双线忙起来", 7 => "油条卷进煎饼", 8 => "火腿新品",
        9 => "豆浆套餐", 10 => "完整早餐铺", 11 => "赶时间的客人", 12 => "大订单来了",
        13 => "完整早高峰", 14 => "熟练挑战", _ => "天津最终高峰",
    };

    private static string DayPlanText(int day) => day switch
    {
        1 => "今天只做基础煎饼，熟悉摊、翻、抹、折。",
        5 => "油条锅开始工作，记得趁空提前备货。",
        9 => "豆浆加入套餐，出餐前看清每件商品。",
        11 => "上班族和熟客出现，先服务快等不及的人。",
        12 => "大订单开始出现，逐件补齐后再结算。",
        15 => "最后一场天津早高峰，一星即可点亮城市。",
        _ => "新的商品和客流会逐步加入，设备升级能减轻操作压力。",
    };

    private readonly record struct UpgradeOffer(string Id, string Effect, int Price);
}
