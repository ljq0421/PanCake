using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class WuhanHub : Control
{
    public event Action<int>? DayRequested;
    public event Action? MapRequested;
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private WuhanArtCatalog _art = null!;
    private Label _coins = null!;
    private Label _message = null!;
    private Label _dayTitle = null!;
    private Label _daySubtitle = null!;
    private Label _dayRecord = null!;
    private WuhanLedger _ledger = null!;
    private HBoxContainer _equipment = null!;
    private Button _primary = null!;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _art = new WuhanArtCatalog();
        ((Button)FindChild("StartWuhanDay", true, false)).Pressed += () =>
        {
            if (!_save.HasLoadError) DayRequested?.Invoke(Math.Clamp(_save.Data.Wuhan.HighestUnlockedDay, 1, 12));
        };
        ((Button)FindChild("OpenWuhanLedger", true, false)).Pressed += ShowLedger;
        this.FindButton("早餐地图").Pressed += () => MapRequested?.Invoke();
        _ledger.DayRequested += day => DayRequested?.Invoke(day);
        GetNode<Button>("%CookerUpgrade").Pressed += () => Purchase(CurrentOffer("cooker") ?? string.Empty);
        GetNode<Button>("%GriddleUpgrade").Pressed += () => Purchase(CurrentOffer("griddle") ?? string.Empty);
        GetNode<Button>("%WuhanStationUpgrade").Pressed += () => Purchase(CurrentOffer("station") ?? string.Empty);
    }
    public void Initialize(DataCatalog catalog, SaveService save)
    {
        _catalog = catalog; _save = save; _save.Changed += Render; Render();
    }
    public override void _ExitTree() { if (_save is not null) _save.Changed -= Render; }
    public void ShowLedger() => _ledger.Open(_save);

    private void Render()
    {
        if (_save is null) return; CityProgressData city = _save.Data.Wuhan; _coins.Text = $"¥{_save.Data.Coins}";
        int day = Math.Clamp(city.HighestUnlockedDay, 1, 12);
        _primary.Text = city.Completed ? "再次挑战 · Day 12" : $"打开铺门 · Day {day}";
        _primary.Disabled = _save.HasLoadError;
        _dayTitle.Text = $"Day {day}";
        _daySubtitle.Text = DaySubtitle(day);
        _dayRecord.Text = _save.HasLoadError ? "存档无法读取，暂时无法营业。\n请返回天津经营手账重置进度。"
            : city.DayBestRecords.TryGetValue(day, out DayBestRecord? best)
                ? $"历史最佳营业额  ¥{best.TotalRevenue}\n满意度  {best.Satisfaction:0}%  ·  Perfect {best.PerfectOrders} 单\n\n设备和食材已经备好，随时可以开门。"
                : "这是新的营业日，先看订单再安排工作台。\n\n翻开经营手账，可以查看往日记录或重玩。";
        _message.Text = city.Completed ? $"武汉已点亮  {new string('★',city.BestStars)}{new string('☆',3-city.BestStars)} · 下一站：西安已开放" : $"已到 Day {day} / 12 · 合理安排面锅、豆皮库存和顾客优先级。";
        _ledger.Refresh(_save);
        RenderEquipment(city);
    }

    private void RenderEquipment(CityProgressData city)
    {
        int cooker = city.EquipmentLevels.GetValueOrDefault("noodle_cooker",1), griddle = city.EquipmentLevels.GetValueOrDefault("doupi_griddle"), station = city.EquipmentLevels.GetValueOrDefault("ingredient_station",1);
        UpdateCard("Cooker", "煮面锅", _art.Cooker(cooker), cooker, Next(city, "equipment:noodle_cooker_lv2", "equipment:noodle_cooker_lv3"));
        UpdateCard("Griddle", "豆皮锅", _art.Griddle(Math.Max(1,griddle)), griddle, Next(city, "equipment:doupi_griddle_lv2", "equipment:doupi_griddle_lv3"));
        UpdateCard("WuhanStation", "备料台", _art.Texture("base_seasoning"), station, Next(city, "equipment:wuhan_ingredient_station_lv2", "equipment:wuhan_ingredient_station_lv3"));
    }

    private void UpdateCard(string prefix, string title, Texture2D texture, int level, string? offer)
    {
        GetNode<Label>($"%{prefix}Title").Text = level == 0 ? $"{title} · 未解锁" : $"{title} · Lv{level}";
        GetNode<TextureRect>($"%{prefix}Image").Texture = texture;
        Label note = GetNode<Label>($"%{prefix}Note");
        Button upgrade = GetNode<Button>($"%{prefix}Upgrade");
        note.Visible = offer is null;
        note.Text = level == 0 ? "完成对应营业日解锁" : "当前最好设备";
        upgrade.Visible = offer is not null;
        if (offer is not null)
        {
            int price = Price(offer);
            upgrade.Text = $"升级 ¥{price}";
            upgrade.Disabled = _save.Data.Coins < price;
        }
    }
    private string? CurrentOffer(string station) => station switch
    {
        "cooker" => Next(_save.Data.Wuhan, "equipment:noodle_cooker_lv2", "equipment:noodle_cooker_lv3"),
        "griddle" => Next(_save.Data.Wuhan, "equipment:doupi_griddle_lv2", "equipment:doupi_griddle_lv3"),
        _ => Next(_save.Data.Wuhan, "equipment:wuhan_ingredient_station_lv2", "equipment:wuhan_ingredient_station_lv3"),
    };
    private string? Next(CityProgressData city, params string[] ids) => ids.FirstOrDefault(id => city.UnlockedContentIds.Contains(id,StringComparer.Ordinal) && !Owned(city,id));
    private static bool Owned(CityProgressData city,string id) => id.Contains("ingredient_station") ? city.EquipmentLevels.GetValueOrDefault("ingredient_station",1) >= (id.EndsWith("lv3")?3:2) : id.Contains("noodle_cooker") ? city.EquipmentLevels.GetValueOrDefault("noodle_cooker",1) >= (id.EndsWith("lv3")?3:2) : city.EquipmentLevels.GetValueOrDefault("doupi_griddle") >= (id.EndsWith("lv3")?3:2);
    private static int Price(string id) => id switch { "equipment:wuhan_ingredient_station_lv2"=>120,"equipment:noodle_cooker_lv2"=>220,"equipment:doupi_griddle_lv2"=>280,"equipment:wuhan_ingredient_station_lv3"=>300,"equipment:noodle_cooker_lv3"=>520,"equipment:doupi_griddle_lv3"=>560,_=>0 };
    private void Purchase(string id) { bool ok=_save.TryPurchase(StableIds.Cities.Wuhan,id,_catalog,out string error); _message.Text=ok?"新设备已经装好，下次营业生效。":error; _message.Modulate=ok?TianjinUi.Green:TianjinUi.Red; Render(); }
    public static string DaySubtitle(int day) => day switch {1=>"初到武汉",2=>"葱花",3=>"辣油高峰",4=>"豆皮开锅",5=>"双线程",6=>"蛋酒",7=>"牛肉与上班族",8=>"完整早餐",9=>"带走大单",10=>"高级豆皮锅",11=>"过早高峰",_=>"最终挑战"};
}
