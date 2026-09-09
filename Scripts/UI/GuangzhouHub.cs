using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Guangzhou;

namespace ProjectCake.UI;

public partial class GuangzhouHub : Control
{
    public event Action<int>? DayRequested;
    public event Action? MapRequested;
    public event Action? PracticeRequested;
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private Control _canvas = null!;
    private readonly Button[] _days = new Button[12];
    private readonly Label[] _equipmentInfo = new Label[3];
    private readonly Button[] _upgrades = new Button[3];
    private Label _coins = null!, _message = null!;
    private Button _open = null!;
    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        for (int index = 0; index < _days.Length; index++)
        {
            int day = index + 1;
            _days[index].Pressed += () => DayRequested?.Invoke(day);
        }
        for (int index = 0; index < _upgrades.Length; index++)
        {
            int equipment = index;
            _upgrades[index].Pressed += () => Purchase(equipment);
        }
        _open.Pressed += () => DayRequested?.Invoke(_save.Data.Guangzhou.HighestUnlockedDay);
        this.FindButton("早餐地图").Pressed += () => MapRequested?.Invoke();
        Button? practice = this.FindOptionalButton("Day 9 练习 · Lv2设备 · 不保存");
        if (practice is not null)
        {
            practice.Visible = OS.GetCmdlineUserArgs().Contains("--dev-ui");
            practice.Pressed += () => PracticeRequested?.Invoke();
        }
    }
    public void Initialize(DataCatalog catalog, SaveService save)
    {
        if (_save is not null) _save.Changed -= Render;
        _catalog = catalog; _save = save; save.Changed += Render; Render();
    }
    public override void _ExitTree() { if (_save is not null) _save.Changed -= Render; }
    public void Render()
    {
        if (_save is null || _catalog is null) return;
        var city = _save.Data.Guangzhou;
        _coins.Text = $"共享金币  ¥{_save.Data.Coins}";
        _message.Text = _save.HasLoadError ? _save.LoadErrorMessage : city.Completed ? $"广州已点亮  {new string('★', city.BestStars)} · 可以继续挑战更高成绩。"
            : "逐日开放新商品与设备升级。重玩只补发超过当天历史最高收入的差额。";
        for (int i = 0; i < 12; i++)
        {
            int day = i + 1; _days[i].Disabled = _save.HasLoadError || !_catalog.IsValid || day > city.HighestUnlockedDay;
            string[] titles = { "斋肠初体验", "蒸前加鸡蛋", "猪肉肠", "第一次高峰", "烧卖开蒸", "双线备货", "虾仁与早班", "添一杯早茶", "虾饺登场", "一盅两件", "完整早餐高峰", "最终早茶挑战" };
            _days[i].Text = $"DAY {day:00} · {titles[i]}\n" + (city.DayBestRecords.TryGetValue(day, out var best) ? $"最佳 ¥{best.TotalRevenue} · 满意 {best.Satisfaction:0}%" : day <= city.HighestUnlockedDay ? "等待开店" : "尚未开放");
        }
        _open.Text = $"打开铺门 · Day {city.HighestUnlockedDay}"; _open.Disabled = _save.HasLoadError || !_catalog.IsValid;
        for (int i = 0; i < 3; i++)
        {
            string id = GuangzhouRules.Equipment[i]; int level = city.EquipmentLevels.GetValueOrDefault(id);
            var next = Next(i);
            _equipmentInfo[i].Text = $"{GuangzhouRules.Name(id)}   {(level == 0 ? "Day 5 免费开放" : $"Lv{level}")}\n" + Description(id, Math.Max(1, level));
            _upgrades[i].Text = next is null ? "已升满" : !city.UnlockedContentIds.Contains($"equipment:{id}_lv{next.Level}") ? $"Day {next.UnlockAfterDay} 结束开放 · ¥{next.UpgradePrice}" : $"升级到 Lv{next.Level} · ¥{next.UpgradePrice}";
            _upgrades[i].Disabled = next is null || level == 0 || _save.HasLoadError || !city.UnlockedContentIds.Contains($"equipment:{id}_lv{next.Level}") || _save.Data.Coins < next.UpgradePrice;
        }
    }
    private GuangzhouEquipmentData? Next(int index)
    {
        string id = GuangzhouRules.Equipment[index]; int level = Math.Max(1, _save.Data.Guangzhou.EquipmentLevels.GetValueOrDefault(id));
        return level >= 3 ? null : _catalog.GetGuangzhouEquipment(id, level + 1);
    }
    private void Purchase(int index)
    {
        var next = Next(index); if (next is null) return;
        bool ok = _save.TryPurchase(StableIds.Cities.Guangzhou, $"equipment:{next.EquipmentId}_lv{next.Level}", _catalog, out string error);
        Render(); _message.Text = ok ? "升级已购买，下次开店生效。" : error;
    }
    private static string Description(string id, int level) => id switch
    {
        GuangzhouRules.Stove => level == 1 ? "单屉 · 2.5秒蒸熟 · 需要留意过蒸" : level == 2 ? "双屉 · 不会过蒸 · 独立计时" : "双屉 · 1.8秒快蒸 · 熟后弹出提示",
        GuangzhouRules.Cabinet => level == 1 ? "2层 · 烧卖5秒 / 虾饺7秒 · 手动取出" : level == 2 ? "4层 · 烧卖4.3秒 / 虾饺6秒" : "4层 · 熟后自动保温 · 手动取出",
        _ => level == 1 ? "米浆8 / 蛋6 / 肉6 / 虾4 / 豉油10" : level == 2 ? "米浆12 / 蛋10 / 肉10 / 虾8 / 豉油16" : "米浆18 / 蛋16 / 肉16 / 虾12 / 豉油24",
    };
}
