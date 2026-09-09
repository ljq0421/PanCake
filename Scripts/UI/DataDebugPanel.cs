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
    private StyleBoxFlat _statusStyle = null!;
    private RichTextLabel _details = null!;
    private RichTextLabel _status = null!;
    private DataCatalog? _catalog;
    private DayController? _dayController;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _statusStyle = (StyleBoxFlat)_status.GetParent<PanelContainer>().GetThemeStylebox("panel");
        foreach (Button button in this.Descendants<Button>())
        {
            if (button.Text.StartsWith("Day ", StringComparison.Ordinal)
                && int.TryParse(button.Text.AsSpan(4), out int day))
            {
                _dayButtons[day] = button;
                int selectedDay = day;
                button.Pressed += () => SelectDay(selectedDay);
            }
        }
        this.FindButton("返回煎饼实验台").Pressed += () => PancakeLabRequested?.Invoke();
        this.FindButton("营业大厅").Pressed += () => HubRequested?.Invoke();
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
        text.AppendLine("天津库存：鸡蛋/薄脆/火腿/香葱 Lv1各6份、Lv2各8份、Lv3各10份；面糊/酱料不限；豆浆10杯。");
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
