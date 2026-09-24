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
    public event Action? MapRequested;

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
    private TianjinLedger _ledger = null!;
    private Button _soyPurchase = null!;

    public override void _Ready()
    {
        Callable.From(() => ButtonHoverFeedback.AttachTree(this)).CallDeferred();
        SceneNodeBinder.Bind(this);
        _art = new TianjinArtCatalog();
        _openButton.Pressed += StartPrimaryDay;
        this.FindButton("经营手账").Pressed += ShowLedger;
        this.FindButton("城市地图").Pressed += () => MapRequested?.Invoke();
        _ledger.DayRequested += day => DayRequested?.Invoke(day);
        GetNode<Button>("%StoveUpgrade").Pressed += () => Purchase(NextStoveUpgrade()?.Id ?? string.Empty);
        GetNode<Button>("%FryerUpgrade").Pressed += () => Purchase(NextFryerUpgrade()?.Id ?? string.Empty);
        GetNode<Button>("%StationUpgrade").Pressed += () => Purchase(NextStationUpgrade()?.Id ?? string.Empty);
        _soyPurchase = new Button { Name = "SoyMilkTrayPurchase", CustomMinimumSize = new(0, 60) };
        var plan = (VBoxContainer)_dayRecord.GetParent();
        plan.AddChild(_soyPurchase);
        plan.MoveChild(_soyPurchase, _dayRecord.GetIndex() + 1);
        _soyPurchase.Pressed += () => Purchase(BaseEquipmentPurchases.SoyTray);
    }

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
    public void ShowLedger() => _ledger.Open(_save);

    private void Render()
    {
        if (_save is null) return;
        int day = Math.Max(1, _save.Data.HighestUnlockedDay);
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
        bool soyOwned = _save.Data.Tianjin.EquipmentLevels.GetValueOrDefault("soy_milk_tray") > 0;
        _soyPurchase.Visible = !soyOwned;
        if (!soyOwned)
        {
            _soyPurchase.Text = day < 5 ? $"豆浆托盘 · Day 5 可购买 · ¥100"
                : _save.Data.Coins < 100 ? $"豆浆托盘 · {_save.Data.Coins} / 100 金币 · 还差 {100 - _save.Data.Coins}"
                : "购买豆浆托盘 · 100 金币 · 开始供应豆浆";
            _soyPurchase.Disabled = _save.HasLoadError || day < 5 || _save.Data.Coins < 100;
        }
        RenderLedger();
        if (_save.HasLoadError)
        {
            _message.Text = "！ 存档无法读取。请返回首页，在旅程档案中选择旅程。";
            _message.Modulate = TianjinUi.Red;
        }
    }

    private void RenderEquipment()
    {
        UpdateEquipmentCard("Stove", "煎饼炉", _save.Data.PurchasedStoveLevel, NextStoveUpgrade());
        GetNode<TextureRect>("%StoveImage").Texture = _art.WorkbenchStoveIcon;
        UpdateEquipmentCard("Fryer", "油条锅", _save.Data.PurchasedFryerLevel, NextFryerUpgrade());
        int fryerLevel = Math.Max(1, _save.Data.PurchasedFryerLevel);
        GetNode<TextureRect>("%FryerBody").Texture = _art.WorkbenchFryerIcon;
        GetNode<TextureRect>("%FryerBasket").Hide();
        UpdateEquipmentCard("Station", "配料台", _save.Data.PurchasedIngredientStationLevel, NextStationUpgrade());
    }

    private void UpdateEquipmentCard(string prefix, string name, int level, UpgradeOffer? offer)
    {
        GetNode<Label>($"%{prefix}Title").Text = level == 0 ? $"{name} · 尚未解锁" : $"{name} · Lv{level}";
        Label note = GetNode<Label>($"%{prefix}Note");
        Button upgrade = GetNode<Button>($"%{prefix}Upgrade");
        note.Visible = offer is null;
        note.Text = level == 0 ? "Day 3 起可购买 · 80 金币" : "当前可用的最好设备";
        upgrade.Visible = offer is not null;
        if (offer is UpgradeOffer value)
        {
            upgrade.Text = level == 0 && _save.Data.Coins < value.Price
                ? $"油条锅 {_save.Data.Coins}/{value.Price}\n还差 {value.Price - _save.Data.Coins} 金币"
                : $"{value.Effect}\n¥{value.Price}";
            upgrade.Disabled = _save.Data.Coins < value.Price;
        }
    }

    private void RenderLedger()
    {
        if (_save is not null) _ledger.Refresh(_save);
    }

    private void StartPrimaryDay() => DayRequested?.Invoke(Math.Max(1, _save.Data.HighestUnlockedDay));

    private void Purchase(string id)
    {
        bool ok = _save.TryPurchase(id, _catalog, out string error);
        _message.Text = ok ? "新设备已经装好，下次营业立即生效。" : error;
        _message.Modulate = ok ? TianjinUi.Green : TianjinUi.Red;
        Render();
        if (ok) PlayUpgradeStars();
    }

    private void PlayUpgradeStars()
    {
        Vector2 origin = new(1450, 730);
        for (int index = 0; index < 5; index++)
        {
            var star = TianjinUi.Texture(_art.StarEffect, new Vector2(58, 58));
            star.Position = origin + new Vector2((index - 2) * 48, Math.Abs(index - 2) * 8);
            star.PivotOffset = star.Size * 0.5f;
            star.Scale = new Vector2(0.35f, 0.35f);
            star.Modulate = new Color(1, 1, 1, 0);
            star.ZIndex = 150;
            star.MouseFilter = MouseFilterEnum.Ignore;
            AddChild(star);
            Tween tween = CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(star, "position", star.Position + new Vector2(0, -105 - index * 9), 0.62 + index * 0.04);
            tween.TweenProperty(star, "scale", Vector2.One, 0.38);
            tween.TweenProperty(star, "modulate", Colors.White, 0.18);
            tween.Chain().TweenProperty(star, "modulate", new Color(1, 1, 1, 0), 0.24).SetDelay(0.18);
            tween.Finished += star.QueueFree;
        }
    }

    private UpgradeOffer? NextStoveUpgrade() => FirstAvailable(
        ("equipment:pancake_stove_lv2", "恒温不焦", 80, _save.Data.PurchasedStoveLevel >= 2),
        ("equipment:pancake_stove_lv3", "恒温快热", 300, _save.Data.PurchasedStoveLevel >= 3));
    private UpgradeOffer? NextFryerUpgrade() => FirstAvailable(
        (BaseEquipmentPurchases.Fryer, "购买油条锅 · 开始炸油条", 80, _save.Data.PurchasedFryerLevel >= 1),
        ("equipment:fryer_lv2", "扩容加速", 160, _save.Data.PurchasedFryerLevel >= 2),
        ("equipment:fryer_lv3", "自动抬篮", 320, _save.Data.PurchasedFryerLevel >= 3));
    private UpgradeOffer? NextStationUpgrade() => FirstAvailable(
        ("equipment:ingredient_station_lv2", "四种小料各8份", 40, _save.Data.PurchasedIngredientStationLevel >= 2),
        ("equipment:ingredient_station_lv3", "四种小料各10份", 180, _save.Data.PurchasedIngredientStationLevel >= 3));

    private UpgradeOffer? FirstAvailable(params (string Id, string Effect, int Price, bool Owned)[] choices)
    {
        foreach ((string id, string effect, int price, bool owned) in choices)
        {
            if (id == BaseEquipmentPurchases.Fryer && !owned && _save.Data.HighestUnlockedDay >= 3)
                return new UpgradeOffer(id, effect, price);
            if (!owned && _save.Data.UnlockedUpgradeIds.Contains(id, StringComparer.Ordinal)) return new UpgradeOffer(id, effect, price);
        }
        return null;
    }

    internal static string DaySubtitle(int day) => day switch
    {
        1 => "第一张煎饼", 2 => "薄脆与葱香", 3 => "油条开锅", 4 => "油条卷进煎饼",
        5 => "豆浆套餐", 6 => "火腿新品", 7 => "熟客的早餐", 8 => "双线忙起来",
        9 => "赶时间的客人", 10 => "完整早餐铺", 11 => "大订单来了", 12 => "自动提篮新体验",
        13 => "完整早高峰", 14 => "熟练挑战", _ => "最终高峰",
    };

    private static string DayPlanText(int day) => day switch
    {
        1 => "今天只做基础煎饼，熟悉摊、翻、抹、折。",
        3 => "油条锅开始工作，记得趁空提前备货。",
        5 => "豆浆加入套餐，出餐前看清每件商品。",
        9 => "上班族和熟客出现，先服务快等不及的人。",
        11 => "大订单开始出现，逐件补齐后再结算。",
        15 => "最后一场天津早高峰，一星即可点亮城市。",
        _ => "新的商品和客流会逐步加入，设备升级能减轻操作压力。",
    };

    private readonly record struct UpgradeOffer(string Id, string Effect, int Price);
}
