using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Xian;

namespace ProjectCake.UI;

public partial class XianHub : Control
{
    public event Action<int>? DayRequested;
    public event Action? MapRequested;
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private Label _coins = null!, _message = null!;
    private readonly List<Button> _days = new();
    private readonly Dictionary<string, (Label Label, Button Buy)> _equipment = new();
    public override void _Ready() => Build();
    public void Initialize(DataCatalog catalog, SaveService save)
    {
        if (_save is not null) _save.Changed -= Render;
        _catalog = catalog; _save = save; _save.Changed += Render; Render();
    }
    public override void _ExitTree() { if (_save is not null) _save.Changed -= Render; }
    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); Theme = TianjinUi.CreateTheme();
        var bg = new ColorRect { Color = new Color("#E6D9BF"), MouseFilter = MouseFilterEnum.Ignore }; TianjinUi.FullRect(bg); AddChild(bg);
        Label Text(string text, int size, Vector2 position, Vector2 dimensions)
        { var label = TianjinUi.Label(text, size, new Color("#513D32")); label.Position = position; label.Size = dimensions; AddChild(label); return label; }
        Text("西安 · 长安晨食", 46, new(70, 48), new(1100, 70));
        Text("提前备货，迎接下一波清晨客人。", 24, new(72, 124), new(1200, 46));
        _coins = Text("", 32, new(1390, 58), new(220, 60));
        var map = TianjinUi.Button("早餐地图", false, new(210, 64)); map.Position = new(1630, 52); map.Pressed += () => MapRequested?.Invoke(); AddChild(map);
        _message = Text("", 22, new(72, 196), new(1760, 70)); _message.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        for (int i = 0; i < 12; i++)
        {
            int day = i + 1;
            var button = TianjinUi.Button("", day == 1, new(340, 135)); button.Position = new(70 + i % 3 * 360, 300 + i / 3 * 158);
            button.Pressed += () => DayRequested?.Invoke(day); AddChild(button); _days.Add(button);
        }
        for (int i = 0; i < 3; i++)
        {
            string id = new[] { XianRules.Oven, XianRules.Board, XianRules.Soup }[i];
            var panel = TianjinUi.Panel(new Color("#FFF4DC"), 20); panel.Position = new(1190, 300 + i * 210); panel.Size = new(650, 190); AddChild(panel);
            var box = new VBoxContainer(); panel.AddChild(box);
            var label = TianjinUi.Label("", 23, TianjinUi.BrownText); label.AutowrapMode = TextServer.AutowrapMode.WordSmart; box.AddChild(label);
            var buy = TianjinUi.Button("", true, new(570, 55)); box.AddChild(buy);
            buy.Pressed += () => Purchase(id); _equipment[id] = (label, buy);
        }
        Text("手账保留最好收入；重玩获得超过旧纪录的收入差额。", 20, new(72, 972), new(1660, 40));
    }
    private void Purchase(string id)
    {
        int level = _save.Data.Xian.EquipmentLevels.GetValueOrDefault(id, id == XianRules.Board ? 1 : 0);
        bool ok = _save.TryPurchase(StableIds.Cities.Xian, $"equipment:{id}_lv{level + 1}", _catalog, out string error);
        Render(); _message.Text = ok ? "设备已经升级，下次开店生效。" : error;
    }
    public void Render()
    {
        if (_save is null || _coins is null) return;
        var city = _save.Data.Xian; _coins.Text = $"¥ {_save.Data.Coins}";
        _message.Text = _save.HasLoadError ? _save.LoadErrorMessage : city.Completed ? $"西安已点亮  {new string('★', city.BestStars)}{new string('☆', 3 - city.BestStars)} · 可以重玩挑战更高星级" : $"今日推荐：Day {city.HighestUnlockedDay} · {XianRules.Titles[city.HighestUnlockedDay - 1]}";
        for (int i = 0; i < _days.Count; i++)
        {
            int day = i + 1; _days[i].Disabled = day > city.HighestUnlockedDay || _save.HasLoadError;
            _days[i].Text = $"Day {day} · {XianRules.Titles[i]}\n" + (city.DayBestRecords.TryGetValue(day, out var best) ? $"最佳 ¥{best.TotalRevenue} · 满意 {best.Satisfaction:0}%" : day > city.HighestUnlockedDay ? "尚未解锁" : "打开铺门");
        }
        foreach (var (id, ui) in _equipment)
        {
            int level = city.EquipmentLevels.GetValueOrDefault(id, id == XianRules.Board ? 1 : 0);
            var current = _catalog.GetXianEquipment(id, Math.Max(1, level));
            string detail = id switch
            {
                XianRules.Oven => $"一炉{current.Capacity}个 · 熟馍{current.StockCapacity}个\n{(current.Automatic ? "自动翻面、出炉 · 4.8秒" : current.BurnProof ? "手动翻面 · 恒温不焦" : "手动翻面 · 注意火候")}",
                XianRules.Board => $"预剁{current.StockCapacity}份 · 肉锅/汁{current.IngredientCapacity}份\n一次剁肉2份 · 操作量 {current.WorkMultiplier:P0}",
                _ => $"锅内{current.Capacity}份 · 盛汤0.6秒\n补锅{current.RefillSeconds:0.0}秒",
            };
            ui.Label.Text = $"{XianRules.EquipmentName(id)} · {(level == 0 ? "未开放" : $"Lv{level}")}\n{detail}";
            if (level == 0) { ui.Buy.Text = $"Day {(id == XianRules.Oven ? 3 : 6)} 开店时免费获得"; ui.Buy.Disabled = true; }
            else if (level == 3) { ui.Buy.Text = "已达到最高等级"; ui.Buy.Disabled = true; }
            else
            {
                var next = _catalog.GetXianEquipment(id, level + 1); bool unlocked = city.UnlockedContentIds.Contains($"equipment:{id}_lv{level + 1}");
                ui.Buy.Text = unlocked ? $"升级 Lv{level + 1} · ¥{next.UpgradePrice}" : $"完成 Day {next.UnlockAfterDay} 后开放 · ¥{next.UpgradePrice}";
                ui.Buy.Disabled = !unlocked || _save.Data.Coins < next.UpgradePrice || _save.HasLoadError;
            }
        }
    }
}
