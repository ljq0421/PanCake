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
    public event Action? DemoTutorialRequested;
    private CityPageModel? _cityModel;
    private Action? _cityReturn;
    public string SelectedCityId => _city;
    public int SelectedDay { get; private set; } = 1;
    public void ConfigureCities(DataCatalog catalog, YangzhouCatalog? yangzhou)
        => _cityModel = new(catalog, _save!, yangzhou);
    public void PresentCity(string cityId, Action? returnToSource = null)
    {
        if (_save?.IsDemo == true && cityId != StableIds.Cities.Tianjin) return;
        _city = cityId; _cityReturn = returnToSource ?? RenderHome;
        SelectedDay = Math.Clamp(_save!.IsDemo ? _save.ContinueDay : JourneyModel.Progress(_save!, cityId).HighestUnlockedDay, 1, _save.ChapterLength(cityId));
        Show(); RenderCity();
    }
    public void PresentLedger() { SelectedDay = Math.Clamp(JourneyModel.Progress(_save!, _city).HighestUnlockedDay, 1, _save!.ChapterLength(_city)); RenderLedgerPage(); }
    public void PresentUpgrades() => RenderUpgradePage();
    public void RefreshCityPage()
    {
        string focus = GetViewport().GuiGetFocusOwner()?.Name.ToString() ?? "";
        if (Page == JourneyPage.Ledger) RenderLedgerPage();
        else if (Page == JourneyPage.Upgrades) RenderUpgradePage();
        else if (Page == JourneyPage.City) RenderCity();
        if (focus.Length > 0) Focus(focus);
    }
    private void BookFrame(string? cityId = null, bool withNote = false)
    {
        var book = HomeArt(_body, withNote ? "旅行手账双页母版-带便签" : "旅行手账双页母版", BookBounds);
        book.Name = "SharedBook";
        if (cityId is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan or StableIds.Cities.Xian)
        {
            var theme = CitySettlementTheme.For(cityId["city:".Length..]);
            // Materials belong to each book; the cached atlas and mask remain immutable.
            var material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/journey_book_city.gdshader") };
            material.SetShaderParameter("region_mask", GD.Load<Texture2D>(JourneyModel.ArtRoot + (withNote ? "旅行手账双页分区遮罩-带便签.png" : "旅行手账双页分区遮罩.png")));
            material.SetShaderParameter("cover_color", theme.Primary);
            material.SetShaderParameter("ornament_color", theme.Secondary);
            book.Material = material;
        }
    }
    private void CityFrame(JourneyPage page, string title)
    {
        Begin(page); Chrome(page == JourneyPage.City ? () => (_cityReturn ?? RenderHome)() : RenderCity, title);
        if (page == JourneyPage.Ledger)
        {
            HomeArt(_body, "旅行手账双页母版-经营手账", BookBounds).Name = "SharedBook";
            var heading = _body.GetNode<Label>("PageTitle");
            var sign = HomeArt(_body, "城市名称牌底板", new(615, 12, 690, 146));
            _body.MoveChild(sign, heading.GetIndex());
            heading.Position = new(655, 42); heading.Size = new(610, 72);
            heading.AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        }
        else BookFrame(_city, page == JourneyPage.City);
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
    }
    private bool CanOpenDay(int day)
    {
        bool cityAvailable = _save is not null && (_save.Data.UnlockedCityIds.Contains(_city)
            || DeveloperToolsVisible && _city == StableIds.Cities.Wuhan);
        return _save is { CanContinue: true } && cityAvailable
            && day >= 1 && day <= JourneyModel.Progress(_save, _city).HighestUnlockedDay;
    }
    private void RequestBusiness(int day)
    {
        if (!CanOpenDay(day)) { ShowError("该城市或营业日尚未开放，无法开张。"); return; }
        _busy = true; BusinessRequested?.Invoke(_city, day);
    }
    private void RenderCity()
    {
        var city = JourneyModel.City(_city); var p = JourneyModel.Progress(_save!, _city);
        int day = Math.Clamp(_save!.IsDemo ? SelectedDay : p.HighestUnlockedDay, 1, _save!.ChapterLength(_city));
        CityFrame(JourneyPage.City, city.Name + "早餐铺");
        Text(_body, "CityTitle", city.Name, new(325, 235, 500, 90), 58);
        Text(_body, "PostcardLabel", "城市明信片", new(325, 322, 500, 48), 27);
        CityPicture(_body, city, new(315, 365, 560, 300));
        if (_save!.IsDemo)
            Button(_body, "ReplayTutorial", "重看首份教学", new(350, 885, 470, 65), () => DemoTutorialRequested?.Invoke());
        Foods(_body, city, new(350, 665), 177, .75f);
        // The master already contains the paper. Follow its printed rules, including their slope.
        var note = new Control { Name = "BusinessNote", Position = new(1030, 340), Size = new(430, 400),
            RotationDegrees = -3.4f, MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(note);
        Text(note, "Ready", "准备开张", new(5, -19, 300, 30), 21, true);
        Text(note, "DayTitle", $"第 {day} 天", new(5, 7, 300, 65), 42, true);
        var themeLabel = Text(note, "DayTheme", _cityModel?.DayTitle(_city, day) ?? "", new(0, 96, 430, 54), 28, true);
        FitTextWidth(themeLabel, 28, 22);
        SummaryRow(note, "Coins", "当前金币", _save!.Data.Coins + " 金币", 171);
        SummaryRow(note, "Progress", "营业日开放", $"{p.HighestUnlockedDay} / {_save!.ChapterLength(_city)} 天", 247);
        SummaryRow(note, "ChapterState", _save.IsDemo ? "试玩进度" : "章节状态", (_save.IsDemo ? _save.DemoProgress.CompletedStages.Count == _save.ChapterLength(_city) : p.Completed) ? "已完成" : "尚未完成", 323);
        var goals = new Control { Name = "JourneyGoals", Position = new(1015, 755), Size = new(425, 90), MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(goals);
        var heading = Text(goals, "GoalHeading", "下一目标", new(0, 0, 80, 28), 19);
        heading.AddThemeColorOverride("font_color", StartScreenTheme.Muted);
        var goal = Text(goals, "Goal", JourneyModel.Goal(_save, city), new(90, 0, 335, 48), 19);
        goal.VerticalAlignment = VerticalAlignment.Top;
        goal.AddThemeConstantOverride("line_spacing", -4);
        if (p.Completed) HomeArt(_body, JourneyModel.Stamp(city), new(795, 248, 110, 110));
        if (_city == StableIds.Cities.Yangzhou)
        {
            var collection = Text(goals, "Collection", p.UnlockedCollectibleIds.Contains("collectible:yangzhou_crab_soup_bun") ? "已收藏：蟹黄汤包图鉴 · 三星城市徽章" : "三星收藏：蟹黄汤包图鉴\n最终日18组 / 满意度90% / Perfect干丝10份", new(0, 51, 425, 34), 16);
            collection.AddThemeConstantOverride("line_spacing", -6);
            collection.AddThemeColorOverride("font_color", StartScreenTheme.Muted);
        }
        Button(_body, "OpenBusiness", $"{(p.Completed ? "再次营业" : "开张")} · 第 {day} 天", new(1035, 873, 510, 76), () => RequestBusiness(day), true).Disabled = !CanOpenDay(day);
        Focus("OpenBusiness");
    }
    private void SummaryRow(Control parent, string name, string caption, string value, float y)
    {
        var row = new HBoxContainer { Position = new(0, y), Size = new(430, 54), MouseFilter = MouseFilterEnum.Ignore };
        row.AddThemeConstantOverride("separation", 12); parent.AddChild(row);
        var label = Text(row, name + "Label", caption, new(0, 0, 150, 54), 24);
        label.CustomMinimumSize = new(150, 54);
        label.AddThemeColorOverride("font_color", StartScreenTheme.Muted);
        var field = Text(row, name, value, new(0, 0, 268, 54), 25);
        field.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        field.HorizontalAlignment = HorizontalAlignment.Right;
        FitTextWidth(field, 25, 20);
    }
    private void RenderLedgerPage()
    {
        var city = JourneyModel.City(_city); var p = JourneyModel.Progress(_save!, _city);
        CityFrame(JourneyPage.Ledger, city.Name + " · 经营手账");
        var calendarTitle = Text(_body, "CalendarTitle", "营业日历", new(604, 248, 270, 65), 43, true);
        FitTextWidth(calendarTitle, 43, 20);
        calendarTitle.RotationDegrees = -4;
        var progress = Text(_body, "CalendarProgress", _save!.IsDemo ? $"已开放 {p.HighestUnlockedDay} / {_save.ChapterLength(_city)} 局" : $"已开放 {p.HighestUnlockedDay} / {_save.ChapterLength(_city)} 天 · 章节 {p.BestStars} 星", new(596, 348, 286, 32), 19, true);
        FitTextWidth(progress, 19, 14);
        for (int d = 1; d <= _save!.ChapterLength(_city); d++)
        {
            int date = d; bool unlocked = d <= p.HighestUnlockedDay;
            bool recorded = p.DayBestRecords.TryGetValue(d, out var record) && unlocked && !_save!.HasLoadError;
            var at = new Vector2(320 + ((d - 1) % 3) * 190, 406 + ((d - 1) / 3) * 84);
            var b = Button(_body, "Date" + d, "", new(at, new(179, 82)), () => { SelectedDay = date; RenderLedgerPage(); Focus("Date" + date); }, bare: true);
            var panel = new Panel { Size = b.Size, MouseFilter = MouseFilterEnum.Ignore };
            var style = StartScreenTheme.Box(d == SelectedDay ? new Color("#FFE29C") : unlocked ? new Color("#FFF7E6") : new Color("#E9D8B8"), d == SelectedDay ? 3 : 1);
            style.BorderColor = d == SelectedDay ? new Color("#E5A334") : new Color("#AD8056");
            panel.AddThemeStyleboxOverride("panel", style); b.AddChild(panel);
            Text(b, "Day", $"第 {d} 天", new(13, 4, 135, 32), 23);
            if (recorded) HomeArt(b, "../HUDUI/小费飞行金币", new(12, 45, 23, 23));
            var metrics = Text(b, "Record", !unlocked ? "未解锁" : recorded ? record!.TotalRevenue.ToString() : "等待开店", new(recorded ? 39 : 13, 42, recorded ? 94 : 120, 30), 21);
            FitTextWidth(metrics, 21, 12);
            if (unlocked)
            {
                var mood = HomeArt(b, LedgerMoodArt(recorded ? record!.Satisfaction : null), new(140, 40, 28, 28));
                mood.Name = "SatisfactionFace";
            }
            else b.AddChild(new LedgerLockIcon { Name = "DateLock", Position = new(138, 25), Scale = Vector2.One * .23f, MouseFilter = MouseFilterEnum.Ignore });
            b.TooltipText = $"第 {d} 天 · {_cityModel?.DayTitle(_city, d)}\n" + (recorded ? $"历史最佳收入 {record!.TotalRevenue} 金币 · 满意度 {record.Satisfaction:0.##}%" : metrics.Text);
            if (d == SelectedDay) HomeArt(b, "小红旗", new(151, -12, 30, 36)).Name = "SelectedFlag";
        }
        Text(_body, "CalendarHint", "选择日期，查看营业记录。", new(330, 829, 550, 32), 22, true);
        Text(_body, "SelectedDay", $"第 {SelectedDay} 天", new(1050, 245, 325, 65), 49, true);
        if (SelectedDay == _save!.ChapterLength(_city)) HomeArt(_body, "皇冠", new(1368, 245, 55, 50)).Name = "FinalDayCrown";
        var theme = Text(_body, "SelectedTheme", _cityModel?.DayTitle(_city, SelectedDay) ?? "", new(1050, 340, 360, 42), 30, true);
        FitTextWidth(theme, 30, 20);
        if (SelectedDay > p.HighestUnlockedDay || _save!.HasLoadError)
            HomeArt(_body, "未解锁城市节点", new(1175, 401, 145, 145));
        else
        {
            var paths = _cityModel?.LedgerArt(_city, SelectedDay) ?? Array.Empty<string>();
            if (paths.Length == 0) Foods(_body, city, new(1020, 385), 170, .75f);
            else for (int i = 0; i < paths.Length; i++)
                Art(_body, paths[i], new(1010 + i * 490f / paths.Length + 10, 390, 490f / paths.Length - 20, 170));
        }
        bool hasRecord = p.DayBestRecords.TryGetValue(SelectedDay, out var best) && SelectedDay <= p.HighestUnlockedDay && !_save!.HasLoadError;
        Text(_body, "RecordTitle", _save.HasLoadError ? "存档无法读取" : hasRecord ? "历史最佳收入" : SelectedDay > p.HighestUnlockedDay ? "营业日尚未解锁" : "等待开店", new(1100, 589, 270, 36), 25);
        var revenue = Text(_body, "BestRevenue", _save.HasLoadError ? "请通过重置进度恢复" : hasRecord ? $"{best!.TotalRevenue} 金币" : SelectedDay > p.HighestUnlockedDay ? $"完成第 {SelectedDay - 1} 天后开放" : "这一天还没有营业记录", new(1100, 630, 250, 48), hasRecord ? 38 : 23);
        FitTextWidth(revenue, hasRecord ? 38 : 23, 19);
        var satisfaction = Text(_body, "BestMetrics", hasRecord ? $"满意度 {best!.Satisfaction:0}%" : "满意度 —", new(1100, 710, 235, 38), 28);
        FitTextWidth(satisfaction, 28, 19);
        if (hasRecord && best!.PerfectOrders > 0)
            Art(_body, "res://resource/art/Global/BookUI/Perfect 印章.png", new(1370, 603, 70, 70)).Name = "PerfectStamp";
        var perfect = Text(_body, "BestPerfect", hasRecord ? $"Perfect {best!.PerfectOrders} 单" : "", new(1335, 687, 108, 60), 18, true);
        FitTextWidth(perfect, 18, 12);
        Text(_body, "ReplayNote", _save.HasLoadError ? "重置会清除全部旅程，操作前会再次确认。" : "重玩仅补发超过历史最佳的收入差额。", new(1010, 803, 505, 38), 21, true);
        Button(_body, "StartSelectedDay", $"{(hasRecord ? "再次营业" : "开张")} · 第 {SelectedDay} 天", new(1030, 873, 510, 76), () => RequestBusiness(SelectedDay), true).Disabled = !CanOpenDay(SelectedDay);
        Button(_body, "ResetLedgerProgress", "重置进度", new(340, 952, 170, 48), RequestLedgerReset);
        Focus("Date" + SelectedDay);
    }
    internal static string LedgerMoodArt(double? satisfaction) => satisfaction is null ? "灰脸"
        : satisfaction >= 60 ? "绿笑脸" : satisfaction >= 30 ? "棕平脸" : "红难过";
    private static void FitTextWidth(Label label, int size, int minimum)
    {
        var font = label.GetThemeFont("font");
        while (size > minimum && label.Tr(label.Text).ToString().Split('\n').Any(line => font.GetStringSize(line, HorizontalAlignment.Left, -1, size).X > label.Size.X)) size--;
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
