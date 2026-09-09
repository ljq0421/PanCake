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

    public override void _Ready() => Build();
    public void Initialize(DataCatalog catalog, SaveService save)
    {
        _catalog = catalog; _save = save; _save.Changed += Render; Render();
    }
    public override void _ExitTree() { if (_save is not null) _save.Changed -= Render; }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); Theme = WuhanUi.CreateTheme(); _art = new WuhanArtCatalog();
        var bg = TianjinUi.Texture(_art.Background, Vector2.Zero, TextureRect.StretchModeEnum.Scale); TianjinUi.FullRect(bg); bg.Modulate = new Color(1,1,1,.68f); AddChild(bg);
        var shade = new ColorRect { Color = new Color(WuhanUi.Paper, .85f), MouseFilter = MouseFilterEnum.Ignore }; TianjinUi.FullRect(shade); AddChild(shade);
        var margin = new MarginContainer(); TianjinUi.FullRect(margin, 70, 42, -70, -42); AddChild(margin);
        var root = new VBoxContainer(); root.AddThemeConstantOverride("separation", 18); margin.AddChild(root);
        var header = new HBoxContainer(); root.AddChild(header);
        var title = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; header.AddChild(title);
        title.AddChild(WuhanUi.Label("武汉 · 过早之城", 42, WuhanUi.Ink)); title.AddChild(WuhanUi.Label("热干面即时制作 · 三鲜豆皮批量备货 · 蛋酒快速配餐", 20, WuhanUi.Muted));
        header.AddChild(TianjinUi.Texture(_art.Shared.Coin, new Vector2(42,42))); _coins = WuhanUi.Label("¥0", 26, WuhanUi.Ink); header.AddChild(_coins);
        var map = WuhanUi.Button("早餐地图", false, new Vector2(170,56)); map.Pressed += () => MapRequested?.Invoke(); header.AddChild(map);
        _message = WuhanUi.Label("", 19, WuhanUi.Text, HorizontalAlignment.Center); root.AddChild(_message);
        var body = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill }; body.AddThemeConstantOverride("separation", 22); root.AddChild(body);
        var dayPanel = WuhanUi.Panel(WuhanUi.Paper, 18); dayPanel.SizeFlagsHorizontal = SizeFlags.ExpandFill; body.AddChild(dayPanel);
        var dayColumn = new VBoxContainer(); dayColumn.AddThemeConstantOverride("separation", 10); dayPanel.AddChild(dayColumn);
        dayColumn.AddChild(WuhanUi.Label("今天的营业牌", 28, WuhanUi.Ink));
        _dayTitle = WuhanUi.Label("Day 1", 60, WuhanUi.Ink); dayColumn.AddChild(_dayTitle);
        _daySubtitle = WuhanUi.Label("", 28, WuhanUi.Accent); dayColumn.AddChild(_daySubtitle);
        dayColumn.AddChild(new HSeparator());
        _dayRecord = WuhanUi.Label("", 22, WuhanUi.Text);
        _dayRecord.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _dayRecord.SizeFlagsVertical = SizeFlags.ExpandFill; dayColumn.AddChild(_dayRecord);
        _primary = WuhanUi.Button("打开铺门", true, new Vector2(0,70));
        _primary.Name = "StartWuhanDay";
        _primary.Pressed += () => { if (!_save.HasLoadError) DayRequested?.Invoke(Math.Clamp(_save.Data.Wuhan.HighestUnlockedDay,1,12)); };
        dayColumn.AddChild(_primary);
        var ledgerButton = WuhanUi.Button("经营手账", false, new Vector2(0,60));
        ledgerButton.Name = "OpenWuhanLedger"; ledgerButton.Pressed += ShowLedger; dayColumn.AddChild(ledgerButton);
        var equipmentPanel = WuhanUi.Panel(WuhanUi.Surface, 18); equipmentPanel.CustomMinimumSize = new Vector2(680,0); body.AddChild(equipmentPanel);
        var equipmentColumn = new VBoxContainer(); equipmentColumn.AddThemeConstantOverride("separation", 12); equipmentPanel.AddChild(equipmentColumn); equipmentColumn.AddChild(WuhanUi.Label("武汉设备", 28, WuhanUi.Ink));
        _equipment = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill }; _equipment.AddThemeConstantOverride("separation",8); equipmentColumn.AddChild(_equipment);
        _ledger = new WuhanLedger { Name = "WuhanLedger", Visible = false, ZIndex = 100 };
        AddChild(_ledger);
        _ledger.DayRequested += day => DayRequested?.Invoke(day);
    }

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
        foreach (Node child in _equipment.GetChildren()) child.QueueFree();
        int cooker = city.EquipmentLevels.GetValueOrDefault("noodle_cooker",1), griddle = city.EquipmentLevels.GetValueOrDefault("doupi_griddle"), station = city.EquipmentLevels.GetValueOrDefault("ingredient_station",1);
        _equipment.AddChild(Card("煮面锅", _art.Cooker(cooker), cooker, Next(city, "equipment:noodle_cooker_lv2", "equipment:noodle_cooker_lv3")));
        _equipment.AddChild(Card("豆皮锅", _art.Griddle(Math.Max(1,griddle)), griddle, Next(city, "equipment:doupi_griddle_lv2", "equipment:doupi_griddle_lv3")));
        _equipment.AddChild(Card("备料台", _art.Texture("base_seasoning"), station, Next(city, "equipment:wuhan_ingredient_station_lv2", "equipment:wuhan_ingredient_station_lv3")));
    }

    private Control Card(string title, Texture2D texture, int level, string? offer)
    {
        var box = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; box.AddChild(WuhanUi.Label(level == 0 ? $"{title} · 未解锁" : $"{title} · Lv{level}",18,WuhanUi.Ink,HorizontalAlignment.Center));
        box.AddChild(TianjinUi.Texture(texture,new Vector2(180,210)));
        if (offer is not null)
        {
            int price = Price(offer); var buy = WuhanUi.Button($"升级 ¥{price}", true, new Vector2(0,54)); buy.Disabled = _save.Data.Coins < price; buy.Pressed += () => Purchase(offer); box.AddChild(buy);
        }
        else box.AddChild(WuhanUi.Label(level == 0 ? "完成对应营业日解锁" : "当前最好设备",15,WuhanUi.Muted,HorizontalAlignment.Center));
        return box;
    }
    private string? Next(CityProgressData city, params string[] ids) => ids.FirstOrDefault(id => city.UnlockedContentIds.Contains(id,StringComparer.Ordinal) && !Owned(city,id));
    private static bool Owned(CityProgressData city,string id) => id.Contains("ingredient_station") ? city.EquipmentLevels.GetValueOrDefault("ingredient_station",1) >= (id.EndsWith("lv3")?3:2) : id.Contains("noodle_cooker") ? city.EquipmentLevels.GetValueOrDefault("noodle_cooker",1) >= (id.EndsWith("lv3")?3:2) : city.EquipmentLevels.GetValueOrDefault("doupi_griddle") >= (id.EndsWith("lv3")?3:2);
    private static int Price(string id) => id switch { "equipment:wuhan_ingredient_station_lv2"=>120,"equipment:noodle_cooker_lv2"=>220,"equipment:doupi_griddle_lv2"=>280,"equipment:wuhan_ingredient_station_lv3"=>300,"equipment:noodle_cooker_lv3"=>520,"equipment:doupi_griddle_lv3"=>560,_=>0 };
    private void Purchase(string id) { bool ok=_save.TryPurchase(StableIds.Cities.Wuhan,id,_catalog,out string error); _message.Text=ok?"新设备已经装好，下次营业生效。":error; _message.Modulate=ok?TianjinUi.Green:TianjinUi.Red; Render(); }
    public static string DaySubtitle(int day) => day switch {1=>"初到武汉",2=>"葱花",3=>"辣油高峰",4=>"豆皮开锅",5=>"双线程",6=>"蛋酒",7=>"牛肉与上班族",8=>"完整早餐",9=>"带走大单",10=>"高级豆皮锅",11=>"过早高峰",_=>"最终挑战"};
}
