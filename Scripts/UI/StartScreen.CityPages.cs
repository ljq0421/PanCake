using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Yangzhou;

namespace ProjectCake.UI;

public partial class StartScreen
{
    public static readonly Rect2 BookBounds = new(240, 150, 1400, 800);
    public event Action<string, int>? BusinessRequested;
    public event Action<string, string>? UpgradeRequested;
    public event Action<string>? DeveloperRequested;
    private CityPageModel? _cityModel;
    private Action? _cityReturn;
    public string SelectedCityId => _city;
    public int SelectedDay { get; private set; } = 1;
    public void ConfigureCities(DataCatalog catalog, YangzhouCatalog yangzhou)
        => _cityModel = new(catalog, _save!, yangzhou);
    public void PresentCity(string cityId, Action? returnToSource = null)
    {
        _city = cityId; _cityReturn = returnToSource ?? RenderHome;
        SelectedDay = Math.Clamp(JourneyModel.Progress(_save!, cityId).HighestUnlockedDay, 1, JourneyModel.City(cityId).Days);
        Show(); RenderCity();
    }
    public void PresentLedger() { SelectedDay = Math.Clamp(JourneyModel.Progress(_save!, _city).HighestUnlockedDay, 1, JourneyModel.City(_city).Days); RenderLedgerPage(); }
    public void PresentUpgrades() => RenderUpgradePage();
    public void RefreshCityPage()
    {
        string focus = GetViewport().GuiGetFocusOwner()?.Name.ToString() ?? "";
        if (Page == JourneyPage.Ledger) RenderLedgerPage();
        else if (Page == JourneyPage.Upgrades) RenderUpgradePage();
        else if (Page == JourneyPage.City) RenderCity();
        if (focus.Length > 0) Focus(focus);
    }
    private void BookFrame()
    {
        var book = HomeArt(_body, "旅行手账双页母版", BookBounds);
        book.Name = "SharedBook";
    }
    private void CityFrame(JourneyPage page, string title)
    {
        Begin(page); Chrome(page == JourneyPage.City ? () => (_cityReturn ?? RenderHome)() : RenderCity, title);
        BookFrame();
        (string Name, string Caption, Action Action)[] tabs = {
            ("LedgerTab", "经营手账", PresentLedger), ("UpgradeTab", "店铺升级", PresentUpgrades),
            ("MapTab", "世界地图", () => { var origin = Page; string city = _city; int day = SelectedDay;
                PresentMap(() => { _city = city; SelectedDay = day; if (origin == JourneyPage.Ledger) RenderLedgerPage(); else if (origin == JourneyPage.Upgrades) RenderUpgradePage(); else RenderCity(); }); }) };
        for (int i = 0; i < tabs.Length; i++)
        {
            var tab = tabs[i]; var b = Button(_body, tab.Name, "", new(1610, 290 + i * 132, 245, 100), tab.Action, bare: true);
            var art = HomeArt(b, "旅行手账书签母版", new(0, 0, 245, 100), stretch: true);
            if (page == JourneyPage.Ledger && i == 0 || page == JourneyPage.Upgrades && i == 1) art.Modulate = new Color("#FFDC83");
            Text(b, "Caption", tab.Caption, new(40, 18, 194, 64), 28, true);
        }
        if (DeveloperToolsVisible)
            Button(_body, "DeveloperMenu", "开发工具", new(70, 960, 170, 55), OpenCityDeveloperMenu);
    }
    private void OpenCityDeveloperMenu()
    {
        OpenModal("developer");
        Text(_modal, "Title", "开发工具", new(570, 310, 700, 70), 38, true);
        if (_city == StableIds.Cities.Tianjin) {
            Button(_modal, "Lab", "煎饼实验台", new(620, 440, 310, 70), () => { CloseModal(); DeveloperRequested?.Invoke("lab"); });
            Button(_modal, "Data", "Day 数据", new(980, 440, 310, 70), () => { CloseModal(); DeveloperRequested?.Invoke("data"); });
        }
        if (_city is StableIds.Cities.Guangzhou or StableIds.Cities.Yangzhou)
            Button(_modal, "Practice", "练习 · Lv2 · 不保存", new(660, 450, 600, 75), () => { CloseModal(); DeveloperRequested?.Invoke(_city); });
        Button(_modal, "Close", "返回", new(800, 660, 320, 70), CloseModal); _modalControls[0].GrabFocus();
    }
    private bool CanOpenDay(int day) => _save is { CanContinue: true } && _save.Data.UnlockedCityIds.Contains(_city)
        && day >= 1 && day <= JourneyModel.Progress(_save, _city).HighestUnlockedDay;
    private void RequestBusiness(int day)
    {
        if (!CanOpenDay(day)) { ShowError("该城市或营业日尚未开放，无法开张。"); return; }
        _busy = true; BusinessRequested?.Invoke(_city, day);
    }
    private void RenderCity()
    {
        var city = JourneyModel.City(_city); var p = JourneyModel.Progress(_save!, _city);
        int day = Math.Clamp(p.HighestUnlockedDay, 1, city.Days);
        CityFrame(JourneyPage.City, city.Name + "早餐铺");
        Text(_body, "CityTitle", city.Name, new(325, 235, 500, 90), 58);
        Text(_body, "PostcardLabel", "城市明信片", new(325, 322, 500, 48), 27);
        CityPicture(_body, city, new(315, 365, 560, 300));
        Foods(_body, city, new(350, 665), 177, .75f);
        Text(_body, "Ready", "准备开张", new(1020, 245, 370, 70), 44);
        Text(_body, "Coins", _save!.Data.Coins + " 金币", new(1380, 251, 195, 55), 27, true);
        Text(_body, "DayTitle", $"第 {day} 天", new(1040, 365, 480, 90), 63, true);
        Text(_body, "DayTheme", _cityModel?.DayTitle(_city, day) ?? "", new(1020, 460, 535, 65), 35, true);
        Text(_body, "Progress", $"营业日开放               {p.HighestUnlockedDay} / {city.Days} 天\n章节状态                 {(p.Completed ? "已完成" : "尚未完成")}", new(1020, 548, 530, 110), 27);
        Text(_body, "Goal", JourneyModel.Goal(_save, city), new(1020, 683, 520, 130), 29);
        if (p.Completed) HomeArt(_body, JourneyModel.Stamp(city), new(795, 248, 110, 110));
        if (_city == StableIds.Cities.Yangzhou)
            Text(_body, "Collection", p.UnlockedCollectibleIds.Contains("collectible:yangzhou_crab_soup_bun") ? "已收藏：蟹黄汤包图鉴 · 三星城市徽章" : "三星收藏：蟹黄汤包图鉴\n最终日18组 / 满意度90% / Perfect干丝10份", new(1015, 774, 555, 75), 20);
        Button(_body, "OpenBusiness", $"{(p.Completed ? "再次营业" : "开张")} · 第 {day} 天", new(1030, 873, 510, 76), () => RequestBusiness(day), true).Disabled = !CanOpenDay(day);
        Focus("OpenBusiness");
    }
    private void RenderLedgerPage()
    {
        var city = JourneyModel.City(_city); var p = JourneyModel.Progress(_save!, _city);
        CityFrame(JourneyPage.Ledger, city.Name + " · 经营手账");
        Text(_body, "CalendarTitle", "营业日历", new(320, 232, 535, 70), 46);
        Text(_body, "CalendarProgress", $"已开放 {p.HighestUnlockedDay} / {city.Days} 天 · 章节 {p.BestStars} 星", new(320, 303, 570, 50), 25);
        for (int d = 1; d <= city.Days; d++)
        {
            int date = d; bool unlocked = d <= p.HighestUnlockedDay;
            bool recorded = p.DayBestRecords.TryGetValue(d, out var record) && !_save!.HasLoadError;
            var at = new Vector2(320 + ((d - 1) % 3) * 190, 380 + ((d - 1) / 3) * 91);
            var b = Button(_body, "Date" + d, "", new(at, new(179, 82)), () => { SelectedDay = date; RenderLedgerPage(); Focus("Date" + date); }, bare: true);
            var panel = new Panel { Size = b.Size, MouseFilter = MouseFilterEnum.Ignore };
            panel.AddThemeStyleboxOverride("panel", StartScreenTheme.Box(d == SelectedDay ? new Color("#FFD579") : unlocked ? new Color("#FFF7E6") : new Color("#E9D8B8"), 1)); b.AddChild(panel);
            Text(b, "Day", $"第 {d} 天", new(13, 3, 153, 33), 24);
            var metrics = Text(b, "Record", !unlocked ? "未解锁" : recorded ? $"{record!.TotalRevenue} 金币\n满意度 {record.Satisfaction:0}%" : "等待开店", new(13, 33, 153, 46), 16);
            metrics.AddThemeConstantOverride("line_spacing", -6);
            FitTextWidth(metrics, 16, 12);
        }
        Text(_body, "CalendarHint", "选择日期，查看营业记录。", new(330, 831, 550, 38), 24, true);
        Text(_body, "SelectedDay", $"第 {SelectedDay} 天", new(1020, 240, 540, 85), 60, true);
        Text(_body, "SelectedTheme", _cityModel?.DayTitle(_city, SelectedDay) ?? "", new(1020, 328, 540, 55), 34, true);
        if (SelectedDay > p.HighestUnlockedDay || _save!.HasLoadError)
            HomeArt(_body, "未解锁城市节点", new(1190, 425, 190, 190));
        else
        {
            var paths = _cityModel?.LedgerArt(_city, SelectedDay) ?? Array.Empty<string>();
            if (paths.Length == 0) Foods(_body, city, new(1050, 405), 170);
            else for (int i = 0; i < paths.Length; i++)
                Art(_body, paths[i], new(1020 + i * 540f / paths.Length + 10, 405, 540f / paths.Length - 20, 210));
        }
        bool hasRecord = p.DayBestRecords.TryGetValue(SelectedDay, out var best) && !_save!.HasLoadError;
        Text(_body, "RecordTitle", hasRecord ? "历史最佳收入" : SelectedDay > p.HighestUnlockedDay ? "营业日尚未解锁" : "等待开店", new(1030, 650, 510, 45), 28);
        var revenue = Text(_body, "BestRevenue", hasRecord ? $"{best!.TotalRevenue} 金币" : SelectedDay > p.HighestUnlockedDay ? $"完成第 {SelectedDay - 1} 天后开放" : "这一天还没有营业记录", new(1030, 700, 510, 60), hasRecord ? 43 : 27);
        FitTextWidth(revenue, hasRecord ? 43 : 27, 24);
        Text(_body, "BestMetrics", hasRecord ? $"满意度 {best!.Satisfaction:0}%       Perfect {best.PerfectOrders} 单" : "", new(1030, 765, 535, 45), 27);
        Text(_body, "ReplayNote", "重玩仅补发超过历史最佳的收入差额。", new(1020, 820, 535, 42), 22);
        Button(_body, "StartSelectedDay", $"{(hasRecord ? "再次营业" : "开张")} · 第 {SelectedDay} 天", new(1030, 873, 510, 76), () => RequestBusiness(SelectedDay), true).Disabled = !CanOpenDay(SelectedDay);
        Button(_body, "ResetLedgerProgress", "重置进度", new(340, 952, 170, 48), RequestLedgerReset);
        Focus("Date" + SelectedDay);
    }
    private static void FitTextWidth(Label label, int size, int minimum)
    {
        var font = label.GetThemeFont("font");
        while (size > minimum && label.Text.Split('\n').Any(line => font.GetStringSize(line, HorizontalAlignment.Left, -1, size).X > label.Size.X)) size--;
        label.AddThemeFontSizeOverride("font_size", size);
    }
    private void RequestLedgerReset()
    {
        OpenModal("reset-ledger");
        Text(_modal, "Title", "重新开始全部旅程？", new(540, 320, 840, 80), 38, true);
        Text(_modal, "Warning", "所有城市的营业记录、金币和升级将被清空。\n此操作无法撤销。", new(550, 445, 820, 130), 30, true);
        Button(_modal, "Cancel", "保留进度", new(610, 650, 300, 72), CloseModal);
        Button(_modal, "Confirm", "确认重置", new(1000, 650, 300, 72), () => { CloseModal(); _busy = true; NewGameRequested?.Invoke(); }, true);
        _modalControls[0].GrabFocus();
    }
    private string? _selectedEquipment;
    private string? _equipmentCity;
    private void RenderUpgradePage()
    {
        var city = JourneyModel.City(_city); CityFrame(JourneyPage.Upgrades, city.Name + " · 店铺升级");
        Text(_body, "Coins", _save!.Data.Coins + " 金币", new(1300, 170, 270, 48), 30, true);
        if (_equipmentCity != _city) { _selectedEquipment = null; _equipmentCity = _city; }
        var view = new EquipmentUpgradeView { Name = "UpgradeView", Position = new(320, 230) };
        _body.AddChild(view);
        view.Configure(_cityModel?.Equipment(_city) ?? Array.Empty<CityEquipmentView>(), _selectedEquipment,
            id => _selectedEquipment = id, e =>
            {
                if (_busy || ModalOpen) return;
                var current = _cityModel?.Equipment(_city).FirstOrDefault(i => i.Id == e.Id);
                if (current is null || !current.CanBuy || current.Level != e.Level || current.Price != e.Price)
                { RefreshCityPage(); ShowError("设备状态已变化，请查看最新升级信息。"); return; }
                _busy = true; UpgradeRequested?.Invoke(_city, e.PurchaseId);
            });
        Focus("Select_" + view.SelectedId);
    }
}
