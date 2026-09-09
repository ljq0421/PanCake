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
    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        this.FindButton("早餐地图").Pressed += () => MapRequested?.Invoke();
        for (int index = 0; index < _days.Count; index++)
        {
            int day = index + 1;
            _days[index].Pressed += () => DayRequested?.Invoke(day);
        }
        string[] ids = { XianRules.Oven, XianRules.Board, XianRules.Soup };
        Button[] buys = this.Descendants<Button>().Where(button => button.CustomMinimumSize == new Vector2(570, 55)).ToArray();
        for (int index = 0; index < ids.Length; index++)
        {
            string id = ids[index];
            Button buy = buys[index];
            Label label = buy.GetParent().GetChildren().OfType<Label>().Single();
            buy.Pressed += () => Purchase(id);
            _equipment[id] = (label, buy);
        }
    }
    public void Initialize(DataCatalog catalog, SaveService save)
    {
        if (_save is not null) _save.Changed -= Render;
        _catalog = catalog; _save = save; _save.Changed += Render; Render();
    }
    public override void _ExitTree() { if (_save is not null) _save.Changed -= Render; }
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
