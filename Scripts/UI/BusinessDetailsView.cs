using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Data;
using ProjectCake.Pancake;

namespace ProjectCake.UI;

/// <summary>A session-only, input-isolating business receipt.</summary>
public partial class BusinessDetailsView : Control
{
    public event Action? CloseRequested;
    private Label _summary = null!;
    private VBoxContainer _rows = null!;
    private ScrollContainer _scroll = null!;
    internal Button CloseButton { get; private set; } = null!;

    public override void _Ready()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        ZIndex = 200;
        Theme = TianjinUi.CreateTheme();
        var shade = new ColorRect { Color = new Color(0.15f, .08f, .04f, .62f) };
        AddChild(shade); shade.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var panel = TianjinUi.Panel(TianjinUi.Paper, 22);
        panel.Position = new Vector2(340, 160); panel.Size = new Vector2(1240, 760);
        AddChild(panel);
        var content = new VBoxContainer(); content.AddThemeConstantOverride("separation", 22); panel.AddChild(content);
        var header = new HBoxContainer(); content.AddChild(header);
        var title = TianjinUi.Label("本次营业明细", 34); title.SizeFlagsHorizontal = SizeFlags.ExpandFill; header.AddChild(title);
        CloseButton = TianjinUi.Button("关闭 · Esc", minimumSize: new Vector2(160, 52));
        CloseButton.Name = "CloseBusinessDetails"; header.AddChild(CloseButton);
        CloseButton.Pressed += () => CloseRequested?.Invoke();
        _summary = TianjinUi.Label("", 24); _summary.Name = "BusinessSummary"; content.AddChild(_summary);
        content.AddChild(new HSeparator());
        var legend = TianjinUi.Label("顾客订单评价 · 按结束顺序    /    查看期间营业已暂停", 19, TianjinUi.Brown);
        content.AddChild(legend);
        _scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill, HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        content.AddChild(_scroll);
        _rows = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        _rows.AddThemeConstantOverride("separation", 14); _scroll.AddChild(_rows);
        Hide();
    }

    internal void Open(DayResult result, IReadOnlyList<BusinessOrderRecord> records, DataCatalog catalog)
    {
        _summary.Text = $"Day {result.Day}    总收入 ¥{result.TotalRevenue}    销售额 ¥{result.SaleRevenue}    小费 ¥{result.Tips}\n"
            + $"完成 {result.CompletedCustomers} 位    流失 {result.LostCustomers} 位    满意度 {result.Satisfaction:0}%    Perfect {result.PerfectOrders} 单";
        foreach (Node child in _rows.GetChildren()) { _rows.RemoveChild(child); child.QueueFree(); }
        if (records.Count == 0) _rows.AddChild(TianjinUi.Label("还没有结束的订单。完成订单后，可在这里查看收入与评价。", 23));
        for (int i = 0; i < records.Count; i++)
        {
            BusinessOrderRecord record = records[i];
            var card = TianjinUi.Panel(TianjinUi.Cream, 12, 1, false); _rows.AddChild(card);
            var lines = new VBoxContainer(); lines.AddThemeConstantOverride("separation", 8); card.AddChild(lines);
            string grade = record.Lost ? "流失 · 未完成" : record.Evaluation!.Grade switch
            {
                DeliveryGrade.Perfect => "Perfect · 完美", DeliveryGrade.Correct => "正确", _ => "错误",
            };
            lines.AddChild(TianjinUi.Label($"{i + 1:00}   {record.CustomerName}    ·    {grade}", 23));
            var order = TianjinUi.Label(string.Join("  /  ", record.Lines.Select(line => ProductName(line, catalog))), 21);
            order.AutowrapMode = TextServer.AutowrapMode.WordSmart; lines.AddChild(order);
            var evaluation = record.Evaluation;
            lines.AddChild(TianjinUi.Label(record.Lost ? "收入 ¥0    小费 ¥0    评分：未完成"
                : $"收入 ¥{evaluation!.TotalRevenue}（销售额 ¥{evaluation.SaleRevenue}）    小费 ¥{evaluation.Tip}    评分 {evaluation.SatisfactionScore}", 21));
            var reason = TianjinUi.Label(record.Lost ? "顾客未完成订单离开，不计入满意度。" : evaluation!.Message, 20, TianjinUi.BrownText);
            reason.AutowrapMode = TextServer.AutowrapMode.WordSmart; lines.AddChild(reason);
        }
        _scroll.ScrollVertical = 0;
        Show(); CloseButton.GrabFocus();
    }

    private static string ProductName(OrderLineData line, DataCatalog catalog)
    {
        string name = catalog.RecipesById.TryGetValue(line.DefinitionId, out var recipe) ? recipe.DisplayName
            : catalog.ProductsById.TryGetValue(line.DefinitionId, out var product) ? product.DisplayName
            : line.ProductKind switch { ProductKind.Pancake => "煎饼", ProductKind.Youtiao => "油条", ProductKind.SoyMilk => "豆浆", ProductKind.HotDryNoodles => "热干面", ProductKind.Doupi => "三鲜豆皮", ProductKind.EggRiceWine => "蛋酒", _ => line.DefinitionId };
        string sauce = line.ProductKind == ProductKind.Pancake && line.Sauce != SaucePreference.Normal
            ? line.Sauce == SaucePreference.Light ? "（少酱）" : "（多酱）" : "";
        return $"{name}{sauce} ×{line.Quantity}";
    }

    public override void _Input(InputEvent @event)
    {
        if (!IsVisibleInTree() || @event is not InputEventKey { Pressed: true, Echo: false } key) return;
        if (key.Keycode == Key.Escape) CloseRequested?.Invoke();
        else if (key.Keycode == Key.Tab) CloseButton.GrabFocus();
        else if (key.Keycode is not (Key.F or Key.G)) return;
        GetViewport().SetInputAsHandled();
    }
}
