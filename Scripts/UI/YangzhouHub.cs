using Godot;
using ProjectCake.Core;
using ProjectCake.Yangzhou;

namespace ProjectCake.UI;

public partial class YangzhouHub : Control
{
    public event Action<int>? DayRequested;
    public event Action? MapRequested, PracticeRequested;
    private SaveService _save = null!;
    private YangzhouCatalog _catalog = null!;
    private readonly Button[] _days = new Button[12], _upgrades = new Button[2];
    private readonly Label[] _equipment = new Label[2];
    private Label _coins = null!, _message = null!, _collection = null!;
    private Button _open = null!;
    public override void _Ready()
    {
        var canvas = GuangzhouUi.Canvas(this);
        canvas.AddChild(new ColorRect { Size = new(1920, 1080), Color = new("#E1EDE5"), MouseFilter = MouseFilterEnum.Ignore });
        GuangzhouUi.Text(canvas, "扬州 · 一席早茶", new(70, 48, 1000, 75), 48);
        GuangzhouUi.Text(canvas, "切一碟干丝，候一笼点心，添一杯绿杨春。", new(74, 125, 1100, 50), 25);
        _coins = GuangzhouUi.Text(canvas, "", new(1250, 62, 310, 55), 28);
        GuangzhouUi.Button(canvas, "早餐地图", new(1580, 62, 260, 60), () => MapRequested?.Invoke());
        _message = GuangzhouUi.Text(canvas, "", new(74, 190, 1750, 60), 22);
        GuangzhouUi.Panel(canvas, new(70, 274, 1020, 718));
        GuangzhouUi.Text(canvas, "十二个清晨", new(100, 295, 900, 50), 32);
        for (int i = 0; i < 12; i++)
        {
            int day = i + 1;
            _days[i] = GuangzhouUi.Button(canvas, "", new(100 + i % 3 * 320, 366 + i / 3 * 120, 302, 104), () => DayRequested?.Invoke(day));
            _days[i].Name = $"Day{day}";
        }
        _open = GuangzhouUi.Button(canvas, "打开铺门", new(100, 876, 942, 72), () => DayRequested?.Invoke(_save.Data.Yangzhou.HighestUnlockedDay), true);
        GuangzhouUi.Panel(canvas, new(1120, 274, 720, 718));
        GuangzhouUi.Text(canvas, "置办店里设备", new(1150, 295, 650, 50), 32);
        for (int i = 0; i < 2; i++)
        {
            int index = i;
            _equipment[i] = GuangzhouUi.Text(canvas, "", new(1150, 365 + i * 195, 640, 112), 24);
            _upgrades[i] = GuangzhouUi.Button(canvas, "", new(1150, 485 + i * 195, 640, 58), () => Purchase(index));
        }
        _collection = GuangzhouUi.Text(canvas, "", new(1150, 773, 640, 108), 23);
        if (OS.GetCmdlineUserArgs().Contains("--dev-ui"))
            GuangzhouUi.Button(canvas, "Day 8 练习 · Lv2设备 · 不保存", new(1150, 899, 640, 58), () => PracticeRequested?.Invoke());
        GuangzhouUi.Text(canvas, "开店前有5秒备货。升级先减轻重复操作，再增加备货与并行能力。", new(74, 1008, 1750, 44), 23);
    }
    public void Initialize(YangzhouCatalog catalog, SaveService save)
    {
        _catalog = catalog; _save = save; _save.Changed += Render; Render();
    }
    public override void _ExitTree() { if (_save is not null) _save.Changed -= Render; }
    public void ShowError(string error) => _message.Text = error;
    public void Render()
    {
        if (_save is null) return;
        var city = _save.Data.Yangzhou;
        _coins.Text = $"共享金币  ¥{_save.Data.Coins}";
        _message.Text = _save.HasLoadError ? _save.LoadErrorMessage : city.Completed ? $"扬州已点亮 {new string('★', city.BestStars)} · 继续练习，挑战三星早茶大会。" : "逐日开放商品；重玩只补发超过当天最佳收入的差额。";
        foreach (var day in _catalog.Days)
        {
            var button = _days[day.Day - 1]; button.Disabled = _save.HasLoadError || day.Day > city.HighestUnlockedDay;
            button.Text = $"Day {day.Day} · {day.Title}\n" + (city.DayBestRecords.TryGetValue(day.Day, out var best) ? $"最佳 ¥{best.TotalRevenue} · {best.Satisfaction:0}%" : day.Day <= city.HighestUnlockedDay ? $"{day.Customers}组 · {day.Duration:0}秒" : "尚未开放");
        }
        _open.Text = $"打开铺门 · Day {city.HighestUnlockedDay}"; _open.Disabled = _save.HasLoadError;
        for (int i = 0; i < 2; i++)
        {
            string id = i == 0 ? YangzhouCatalog.BoardId : YangzhouCatalog.SteamerId;
            int level = city.EquipmentLevels.GetValueOrDefault(id), price = 0, afterDay = 0;
            if (level < 3)
            {
                if (i == 0) { var next = _catalog.Boards.Single(d => d.Level == Math.Max(1, level) + 1); price = next.Price; afterDay = next.UnlockAfterDay; }
                else { var next = _catalog.Steamers.Single(d => d.Level == Math.Max(1, level) + 1); price = next.Price; afterDay = next.UnlockAfterDay; }
            }
            _equipment[i].Text = i == 0 ? $"干丝台  Lv{level}\n" + (level == 1 ? "每块4份 · 库存4 · 85%辅助完成" : level == 2 ? "每块5份 · 库存6 · 70%辅助完成" : "每块6份 · 库存8 · 60%辅助完成")
                : level == 0 ? "竹蒸笼\nDay 3 免费开放，批量蒸制点心。" : $"竹蒸笼  Lv{level}\n" + (level == 1 ? "单层6格 · 留意出笼火候" : level == 2 ? "单层8格 · 自动保温，手动出笼" : "双层8×2 · 快蒸保温，独立计时");
            _upgrades[i].Text = level >= 3 ? "已升满" : level == 0 ? "Day 3 免费开放" : !city.DayBestRecords.ContainsKey(afterDay) ? $"Day {afterDay} 结束开放 · ¥{price}" : $"升至 Lv{level + 1} · ¥{price}";
            _upgrades[i].Disabled = _save.HasLoadError || level is 0 or >= 3 || !city.DayBestRecords.ContainsKey(afterDay) || _save.Data.Coins < price;
        }
        _collection.Text = city.UnlockedCollectibleIds.Contains("collectible:yangzhou_crab_soup_bun") ? "已收藏 · 扬州早餐图鉴：蟹黄汤包\n已获得 · 扬州三星城市徽章" : "三星收藏 · 蟹黄汤包图鉴\n最终日18组 / 满意度90% / Perfect干丝10份";
    }
    private void Purchase(int index)
    {
        bool ok = _save.PurchaseYangzhou(index == 0 ? YangzhouCatalog.BoardId : YangzhouCatalog.SteamerId, _catalog, out string error);
        Render(); _message.Text = ok ? "设备已升级，下次开店生效。" : error;
    }
}
