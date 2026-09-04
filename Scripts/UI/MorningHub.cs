using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class MorningHub : Control
{
    public event Action<int>? DayRequested;
    public event Action? LabRequested;
    public event Action? DebugRequested;
    public event Action? MapRequested;

    private readonly List<Button> _dayButtons = new();
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private Label _coins = null!;
    private Label _equipment = null!;
    private Label _message = null!;
    private VBoxContainer _upgrades = null!;
    private PanelContainer _errorPanel = null!;
    private Label _errorText = null!;
    private ConfirmationDialog _resetDialog = null!;

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog, SaveService save)
    {
        _catalog = catalog; _save = save; _save.Changed += Render; Render();
    }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var bg = new ColorRect { Color = new Color("#1E1512"), MouseFilter = MouseFilterEnum.Ignore }; bg.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); AddChild(bg);
        var margin = new MarginContainer(); margin.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); margin.OffsetLeft = 130; margin.OffsetTop = 70; margin.OffsetRight = -130; margin.OffsetBottom = -70; AddChild(margin);
        var root = new VBoxContainer(); root.AddThemeConstantOverride("separation", 22); margin.AddChild(root);
        var title = Label("早餐铺子 · 天津", 48, "#FFD596"); root.AddChild(title);
        root.AddChild(Label("选择一天，准备迎接清晨的第一批顾客", 22, "#BDAA96"));
        var info = new HBoxContainer(); info.AddThemeConstantOverride("separation", 20); root.AddChild(info);
        var progress = Panel("#30231D"); progress.SizeFlagsHorizontal = SizeFlags.ExpandFill; info.AddChild(progress);
        var progressBox = new VBoxContainer(); progress.AddChild(progressBox);
        _coins = Label("金币 ¥0", 30, "#FFD596"); _equipment = Label("设备", 21, "#E9D4B7"); progressBox.AddChild(_coins); progressBox.AddChild(_equipment);
        var nav = Panel("#28221F"); nav.SizeFlagsHorizontal = SizeFlags.ExpandFill; info.AddChild(nav);
        var navBox = new HBoxContainer(); navBox.Alignment = BoxContainer.AlignmentMode.Center; navBox.AddThemeConstantOverride("separation", 12); nav.AddChild(navBox);
        navBox.AddChild(NavButton("煎饼实验台", () => LabRequested?.Invoke()));
        navBox.AddChild(NavButton("Day 数据", () => DebugRequested?.Invoke()));
        navBox.AddChild(NavButton("城市地图", () => MapRequested?.Invoke()));

        var dayPanel = Panel("#392820"); root.AddChild(dayPanel);
        var dayBox = new VBoxContainer(); dayBox.AddThemeConstantOverride("separation", 15); dayPanel.AddChild(dayBox); dayBox.AddChild(Label("营业日", 28, "#FFE0AF"));
        var dayScroll = new ScrollContainer { CustomMinimumSize = new Vector2(0, 225), HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        dayBox.AddChild(dayScroll);
        var days = new GridContainer { Columns = 5, SizeFlagsHorizontal = SizeFlags.ExpandFill };
        days.AddThemeConstantOverride("h_separation", 12); days.AddThemeConstantOverride("v_separation", 10); dayScroll.AddChild(days);
        for (int day = 1; day <= 15; day++)
        {
            int selected = day;
            var button = new Button { Text = $"Day {day}\n{DaySubtitle(day)}", CustomMinimumSize = new Vector2(190, 62), SizeFlagsHorizontal = SizeFlags.ExpandFill };
            button.AddThemeFontSizeOverride("font_size", 17); button.Pressed += () => DayRequested?.Invoke(selected); days.AddChild(button); _dayButtons.Add(button);
        }

        var lower = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill }; lower.AddThemeConstantOverride("separation", 20); root.AddChild(lower);
        var upgradePanel = Panel("#2C2521"); upgradePanel.SizeFlagsHorizontal = SizeFlags.ExpandFill; lower.AddChild(upgradePanel);
        _upgrades = new VBoxContainer(); _upgrades.AddThemeConstantOverride("separation", 12); upgradePanel.AddChild(_upgrades);
        var resetPanel = Panel("#2C201D"); resetPanel.CustomMinimumSize = new Vector2(420, 0); lower.AddChild(resetPanel);
        var resetBox = new VBoxContainer(); resetBox.AddThemeConstantOverride("separation", 12); resetPanel.AddChild(resetBox);
        resetBox.AddChild(Label("进度管理", 24, "#E8C9A5"));
        _message = Label("", 17, "#78D892"); _message.AutowrapMode = TextServer.AutowrapMode.WordSmart; resetBox.AddChild(_message);
        var reset = NavButton("重置全部进度", () => _resetDialog.PopupCentered()); resetBox.AddChild(reset);
        _errorPanel = Panel("#501D1D"); _errorPanel.Visible = false; resetBox.AddChild(_errorPanel);
        var errorBox = new VBoxContainer(); _errorPanel.AddChild(errorBox); _errorText = Label("", 16, "#FFB2AA"); _errorText.AutowrapMode = TextServer.AutowrapMode.WordSmart; errorBox.AddChild(_errorText);
        errorBox.AddChild(NavButton("确认创建新存档", ConfirmCorruptReset));
        _resetDialog = new ConfirmationDialog { Title = "重置进度", DialogText = "将清除金币、升级与每日最佳记录。此操作不可撤销。", OkButtonText = "确认重置" };
        _resetDialog.Confirmed += ResetProgress; AddChild(_resetDialog);
    }

    private void Render()
    {
        if (_save is null) return;
        _coins.Text = $"金币  ¥{_save.Data.Coins}";
        _equipment.Text = $"煎饼炉 Lv{_save.Data.PurchasedStoveLevel}  ·  配料台 Lv{_save.Data.PurchasedIngredientStationLevel}  ·  油条锅 Lv{_save.Data.PurchasedFryerLevel}\n已解锁至 Day {_save.Data.HighestUnlockedDay}  ·  天津最高 {_save.Data.TianjinBestStars} 星";
        for (int index = 0; index < _dayButtons.Count; index++)
        {
            int day = index + 1; Button button = _dayButtons[index]; button.Disabled = _save.HasLoadError || day > _save.Data.HighestUnlockedDay;
            if (_save.Data.DayBestRecords.TryGetValue(day, out DayBestRecord? best)) button.Text = $"Day {day}\n最佳 ¥{best.TotalRevenue} · 满意 {best.Satisfaction:0}%";
        }
        _errorPanel.Visible = _save.HasLoadError;
        _errorText.Text = _save.HasLoadError ? $"存档读取失败，已保留备份：\n{_save.CorruptBackupPath}\n{_save.LoadErrorMessage}" : string.Empty;
        RenderUpgrades();
    }

    private void RenderUpgrades()
    {
        foreach (Node child in _upgrades.GetChildren()) child.QueueFree();
        _upgrades.AddChild(Label("可购买升级", 24, "#FFE0AF"));
        AddUpgrade("equipment:ingredient_station_lv2", "配料台 Lv2", 60, _save.Data.PurchasedIngredientStationLevel >= 2);
        AddUpgrade("equipment:pancake_stove_lv2", "煎饼炉 Lv2 · 不会焦", 120, _save.Data.PurchasedStoveLevel >= 2);
        AddUpgrade("equipment:fryer_lv2", "油条锅 Lv2 · 8根更快", 160, _save.Data.PurchasedFryerLevel >= 2);
        AddUpgrade("equipment:ingredient_station_lv3", "配料台 Lv3", 180, _save.Data.PurchasedIngredientStationLevel >= 3);
        AddUpgrade("equipment:pancake_stove_lv3", "煎饼炉 Lv3 · 恒温加速", 300, _save.Data.PurchasedStoveLevel >= 3);
        AddUpgrade("equipment:fryer_lv3", "油条锅 Lv3 · 自动抬篮", 320, _save.Data.PurchasedFryerLevel >= 3);
        if (!_save.Data.UnlockedUpgradeIds.Any(id => id.EndsWith("lv2", StringComparison.Ordinal))) _upgrades.AddChild(Label("完成 Day 3 后开放第一项升级。", 17, "#9F8D7E"));
    }

    private void AddUpgrade(string id, string name, int price, bool owned)
    {
        if (!_save.Data.UnlockedUpgradeIds.Contains(id, StringComparer.Ordinal)) return;
        var row = new HBoxContainer(); var label = Label($"{name}  ¥{price}", 19, "#EBD5B8"); label.SizeFlagsHorizontal = SizeFlags.ExpandFill; row.AddChild(label);
        var button = NavButton(owned ? "已购买" : "购买", () => Purchase(id)); button.Disabled = owned || _save.Data.Coins < price || _save.HasLoadError; row.AddChild(button); _upgrades.AddChild(row);
    }

    private void Purchase(string id) { bool ok = _save.TryPurchase(id, _catalog, out string error); _message.Text = ok ? "升级购买成功，下次营业自动装备。" : error; _message.Modulate = ok ? new Color("#78D892") : new Color("#FF756A"); Render(); }
    private void ResetProgress() { _save.ResetProgress(out string error); _message.Text = string.IsNullOrEmpty(error) ? "进度已重置。" : error; Render(); }
    private void ConfirmCorruptReset() { _save.ConfirmCreateNewAfterCorruption(out string error); _message.Text = string.IsNullOrEmpty(error) ? "已创建新存档。" : error; Render(); }
    private static string DaySubtitle(int day) => day switch
    {
        1 => "基础煎饼", 2 => "薄脆", 3 => "香葱", 4 => "首次高峰",
        5 => "油条教学", 6 => "双线程", 7 => "油条煎饼", 8 => "火腿",
        9 => "豆浆", 10 => "完整套餐", 11 => "特殊顾客", 12 => "大订单",
        13 => "早高峰", 14 => "终章预热", _ => "天津决战",
    };
    private static Label Label(string text, int size, string color) { var l = new Label { Text = text }; l.AddThemeFontSizeOverride("font_size", size); l.AddThemeColorOverride("font_color", new Color(color)); return l; }
    private static Button NavButton(string text, Action action) { var b = new Button { Text = text, CustomMinimumSize = new Vector2(170, 52) }; b.Pressed += action; return b; }
    private static PanelContainer Panel(string color) { var p = new PanelContainer(); p.AddThemeStyleboxOverride("panel", new StyleBoxFlat { BgColor = new Color(color), CornerRadiusTopLeft = 16, CornerRadiusTopRight = 16, CornerRadiusBottomLeft = 16, CornerRadiusBottomRight = 16, ContentMarginLeft = 22, ContentMarginRight = 22, ContentMarginTop = 18, ContentMarginBottom = 18 }); return p; }
}
