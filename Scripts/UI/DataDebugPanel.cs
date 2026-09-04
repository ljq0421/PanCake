using System.Globalization;
using System.Text;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class DataDebugPanel : Control
{
    public event Action? PancakeLabRequested;
    public event Action? HubRequested;

    private readonly Dictionary<int, Button> _dayButtons = new();
    private readonly StyleBoxFlat _statusStyle = new();
    private RichTextLabel _details = null!;
    private RichTextLabel _status = null!;
    private DataCatalog? _catalog;
    private DayController? _dayController;

    public override void _Ready()
    {
        BuildInterface();
    }

    public void Initialize(DataCatalog catalog, DayController dayController)
    {
        _catalog = catalog;
        _dayController = dayController;
        _dayController.DayPrepared += RenderDay;

        RenderCatalogStatus();
        SetButtonsEnabled(catalog.IsValid);

        if (catalog.IsValid && !dayController.TryPrepareDay(1, catalog, out string error))
        {
            ShowSelectionError(error);
        }
    }

    public override void _ExitTree()
    {
        if (_dayController is not null)
        {
            _dayController.DayPrepared -= RenderDay;
        }
    }

    private void BuildInterface()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);

        var background = new ColorRect
        {
            Color = new Color("#171310"),
            MouseFilter = MouseFilterEnum.Ignore,
        };
        background.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        AddChild(background);

        var margin = new MarginContainer();
        margin.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        margin.OffsetLeft = 96;
        margin.OffsetTop = 64;
        margin.OffsetRight = -96;
        margin.OffsetBottom = -64;
        AddChild(margin);

        var content = new VBoxContainer();
        content.AddThemeConstantOverride("separation", 24);
        margin.AddChild(content);

        var title = new Label
        {
            Text = "早餐铺子 · 天津数据调试台",
        };
        title.AddThemeFontSizeOverride("font_size", 44);
        title.AddThemeColorOverride("font_color", new Color("#FFD596"));
        content.AddChild(title);

        var subtitle = new Label
        {
            Text = "完整天津章节 / Day 1～15 配置与资源验证",
        };
        subtitle.AddThemeFontSizeOverride("font_size", 22);
        subtitle.AddThemeColorOverride("font_color", new Color("#BDAF9F"));
        content.AddChild(subtitle);

        var buttonRow = new HBoxContainer();
        buttonRow.AddThemeConstantOverride("separation", 16);
        content.AddChild(buttonRow);

        var labButton = new Button
        {
            Text = "返回煎饼实验台",
            CustomMinimumSize = new Vector2(220, 58),
        };
        labButton.AddThemeFontSizeOverride("font_size", 21);
        labButton.Pressed += () => PancakeLabRequested?.Invoke();
        buttonRow.AddChild(labButton);

        var hubButton = new Button { Text = "营业大厅", CustomMinimumSize = new Vector2(180, 58) };
        hubButton.Pressed += () => HubRequested?.Invoke();
        buttonRow.AddChild(hubButton);

        var dayScroll = new ScrollContainer { CustomMinimumSize = new Vector2(0, 122), HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        content.AddChild(dayScroll);
        var dayGrid = new GridContainer { Columns = 8, SizeFlagsHorizontal = SizeFlags.ExpandFill };
        dayGrid.AddThemeConstantOverride("h_separation", 10);
        dayGrid.AddThemeConstantOverride("v_separation", 8);
        dayScroll.AddChild(dayGrid);

        for (int day = 1; day <= 15; day++)
        {
            int selectedDay = day;
            var button = new Button
            {
                Text = $"Day {day}",
                CustomMinimumSize = new Vector2(130, 48),
                ToggleMode = true,
            };
            button.AddThemeFontSizeOverride("font_size", 19);
            button.Pressed += () => SelectDay(selectedDay);
            dayGrid.AddChild(button);
            _dayButtons.Add(day, button);
        }

        var columns = new HBoxContainer
        {
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };
        columns.AddThemeConstantOverride("separation", 24);
        content.AddChild(columns);

        var detailsPanel = CreatePanel(new Color("#241E19"));
        detailsPanel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        detailsPanel.SizeFlagsStretchRatio = 2.2f;
        columns.AddChild(detailsPanel);

        _details = new RichTextLabel
        {
            BbcodeEnabled = true,
            FitContent = false,
            ScrollActive = true,
            CustomMinimumSize = new Vector2(960, 640),
        };
        _details.AddThemeFontSizeOverride("normal_font_size", 22);
        detailsPanel.AddChild(_details);

        var statusPanel = CreatePanel(new Color("#1C2920"));
        statusPanel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        statusPanel.SizeFlagsStretchRatio = 1.0f;
        columns.AddChild(statusPanel);
        _statusStyle.CornerRadiusTopLeft = 14;
        _statusStyle.CornerRadiusTopRight = 14;
        _statusStyle.CornerRadiusBottomLeft = 14;
        _statusStyle.CornerRadiusBottomRight = 14;
        _statusStyle.ContentMarginLeft = 28;
        _statusStyle.ContentMarginTop = 24;
        _statusStyle.ContentMarginRight = 28;
        _statusStyle.ContentMarginBottom = 24;
        statusPanel.AddThemeStyleboxOverride("panel", _statusStyle);

        _status = new RichTextLabel
        {
            BbcodeEnabled = true,
            FitContent = false,
            ScrollActive = true,
            CustomMinimumSize = new Vector2(480, 640),
        };
        _status.AddThemeFontSizeOverride("normal_font_size", 20);
        statusPanel.AddChild(_status);
    }

    private static PanelContainer CreatePanel(Color color)
    {
        var panel = new PanelContainer();
        var style = new StyleBoxFlat
        {
            BgColor = color,
            CornerRadiusTopLeft = 14,
            CornerRadiusTopRight = 14,
            CornerRadiusBottomLeft = 14,
            CornerRadiusBottomRight = 14,
            ContentMarginLeft = 28,
            ContentMarginTop = 24,
            ContentMarginRight = 28,
            ContentMarginBottom = 24,
        };
        panel.AddThemeStyleboxOverride("panel", style);
        return panel;
    }

    private void SelectDay(int day)
    {
        if (_catalog is null || _dayController is null)
        {
            ShowSelectionError("调试界面尚未连接数据系统。");
            return;
        }

        if (!_dayController.TryPrepareDay(day, _catalog, out string error))
        {
            ShowSelectionError(error);
        }
    }

    private void RenderDay(DayConfig config)
    {
        foreach ((int day, Button button) in _dayButtons)
        {
            button.ButtonPressed = day == config.Day;
        }

        var text = new StringBuilder();
        text.AppendLine($"[font_size=34][color=#FFD596]Day {config.Day}[/color][/font_size]");
        text.AppendLine($"[color=#BDAF9F]当前状态[/color]  Preparing");
        text.AppendLine();
        text.AppendLine($"[color=#D6C2A8]营业时长[/color]  {config.DurationSeconds:0} 秒");
        text.AppendLine($"[color=#D6C2A8]顾客数量[/color]  {config.CustomerCount}");
        text.AppendLine($"[color=#D6C2A8]预期收入[/color]  ¥{config.ExpectedRevenue}");
        text.AppendLine($"[color=#D6C2A8]耐心倍率[/color]  {config.PatienceMultiplier:0.00}");
        text.AppendLine($"[color=#D6C2A8]等待上限[/color]  {config.MaxWaitingCustomers} 人");
        text.AppendLine($"[color=#D6C2A8]随机种子[/color]  {config.RandomSeed}");
        text.AppendLine();
        AppendWeights(text, "顾客权重", config.CustomerWeights);
        AppendWeights(text, "订单权重", config.OrderTypeWeights);
        AppendWeights(text, "配方权重", config.RecipeWeights);
        text.AppendLine("[color=#D6C2A8]到店分段[/color]");
        foreach (ArrivalSegmentConfig segment in config.ArrivalSegments)
        {
            text.AppendLine($"  {segment.Start:P0}～{segment.End:P0}  →  {segment.CustomerRatio:P0} 顾客");
        }

        text.AppendLine();
        text.AppendLine($"[color=#D6C2A8]开店解锁[/color]  {FormatList(config.StartUnlocks)}");
        text.AppendLine($"[color=#D6C2A8]结算解锁[/color]  {FormatList(config.CompletionUnlocks)}");
        text.AppendLine($"[color=#D6C2A8]可用配方[/color]  {FormatList(config.AvailableRecipeIds)}");
        text.AppendLine($"[color=#D6C2A8]可用商品[/color]  {string.Join(", ", config.AvailableProductKinds.Select(kind => kind.ToString()))}");
        text.AppendLine($"[color=#D6C2A8]大订单上限[/color]  {config.Constraints.MaxBigOrderCustomers}");
        text.AppendLine($"[color=#D6C2A8]单客最多煎饼[/color]  {config.Constraints.MaxPancakesPerCustomer}");
        if (config.StarGoals.Count > 0)
        {
            text.AppendLine("[color=#D6C2A8]星级目标[/color]");
            foreach (StarGoalConfig goal in config.StarGoals)
                text.AppendLine($"  {goal.Stars}星：完成 {goal.MinimumCompletedCustomers} / 满意 {goal.MinimumSatisfaction:0}% / Perfect {goal.MinimumPerfectOrders}");
        }

        _details.Text = text.ToString();
    }

    private void RenderCatalogStatus()
    {
        if (_catalog is null)
        {
            return;
        }

        var text = new StringBuilder();
        text.AppendLine("[font_size=28][color=#E8DCCB]启动校验[/color][/font_size]");
        text.AppendLine();
        text.AppendLine($"配方 Resource：{_catalog.RecipesById.Count} / 8");
        text.AppendLine($"独立商品 Resource：{_catalog.ProductsById.Count} / 2");
        text.AppendLine($"煎饼炉等级：{_catalog.StovesByLevel.Count} / 3");
        text.AppendLine($"配料台等级：{_catalog.IngredientStationsByLevel.Count} / 3");
        text.AppendLine($"油条锅等级：{_catalog.FryersByLevel.Count} / 3");
        text.AppendLine($"顾客类型：{_catalog.CustomersById.Count} / 4");
        text.AppendLine($"每日 JSON：{_catalog.DaysByNumber.Count} / 15");
        text.AppendLine();

        if (_catalog.IsValid)
        {
            _statusStyle.BgColor = new Color("#193323");
            text.AppendLine("[font_size=26][color=#78D892]✓ 全部数据校验通过[/color][/font_size]");
            text.AppendLine();
            text.AppendLine("15 天配置、商品、顾客与三级设备均已通过启动校验。");
        }
        else
        {
            _statusStyle.BgColor = new Color("#3B1717");
            text.AppendLine($"[font_size=26][color=#FF7777]✗ {_catalog.ValidationIssues.Count} 项配置错误[/color][/font_size]");
            text.AppendLine();
            foreach (ValidationIssue issue in _catalog.ValidationIssues)
            {
                text.AppendLine($"[color=#FFB0A8]• {issue}[/color]");
            }

            _details.Text = "[font_size=32][color=#FF7777]初始化已停止[/color][/font_size]\n\n请先修复右侧列出的配置错误。";
        }

        _status.Text = text.ToString();
    }

    private void SetButtonsEnabled(bool enabled)
    {
        foreach (Button button in _dayButtons.Values)
        {
            button.Disabled = !enabled;
        }
    }

    private void ShowSelectionError(string error)
    {
        _details.Text = $"[font_size=30][color=#FF7777]无法切换日期[/color][/font_size]\n\n{error}";
    }

    private static void AppendWeights(StringBuilder text, string title, IReadOnlyDictionary<string, double> weights)
    {
        text.AppendLine($"[color=#D6C2A8]{title}[/color]");
        foreach ((string id, double weight) in weights.OrderBy(pair => pair.Key, StringComparer.Ordinal))
        {
            text.AppendLine($"  {id}  {weight.ToString("P0", CultureInfo.InvariantCulture)}");
        }

        text.AppendLine();
    }

    private static string FormatList(IReadOnlyCollection<string> values) =>
        values.Count == 0 ? "—" : string.Join(", ", values);
}
