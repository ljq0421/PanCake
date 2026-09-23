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
    private bool _homeBookPalette = true;
    private string BookPaletteCity => !HostedByBook && _homeBookPalette ? "" : _city;
    public string SelectedCityId => _city;
    public int SelectedDay { get; private set; } = 1;
    public void ConfigureCities(DataCatalog catalog, YangzhouCatalog? yangzhou)
        => _cityModel = new(catalog, _save!, yangzhou);
    public void PresentCity(string cityId, Action? returnToSource = null, bool fromHome = false)
    {
        if (_save?.IsDemo == true && (_save.ChapterLength(cityId) == 0 || !_save.Data.UnlockedCityIds.Contains(cityId))) return;
        if (_backdropCity is not null && _backdropCity != cityId) ReleaseCityBackdrop();
        if (fromHome && Page == JourneyPage.Home) OpenHomeOverlay();
        _city = cityId; _cityReturn = returnToSource ?? RenderHome; _homeBookPalette = fromHome;
        SelectedDay = Math.Max(1, JourneyModel.Progress(_save!, cityId).HighestUnlockedDay);
        Show(); RenderCity();
    }
    public void PresentLedger() { SelectedDay = Math.Max(1, JourneyModel.Progress(_save!, _city).HighestUnlockedDay); RenderLedgerPage(); }
    public void PresentUpgrades()
    {
        // Entering the page starts at the first upgrade the player can buy now.
        // Refreshes after selecting or purchasing still retain their current selection.
        _selectedEquipment = null;
        _equipmentCity = _city;
        RenderUpgradePage();
    }
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
        if ((HostedByBook || !_homeBookPalette) && cityId is (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan or StableIds.Cities.Xian))
        {
            var theme = CitySettlementTheme.For(cityId["city:".Length..]);
            // Materials belong to each book; the cached atlas and mask remain immutable.
            var material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/journey_book_city.gdshader") };
            material.SetShaderParameter("region_mask", GD.Load<Texture2D>(JourneyModel.ArtRoot + (withNote ? "旅行手账双页分区遮罩-带便签.png" : "旅行手账双页分区遮罩.png")));
            material.SetShaderParameter("cover_color", theme.Primary);
            material.SetShaderParameter("ornament_color", theme.Secondary);
            material.SetShaderParameter("note_color", CitySettlementTheme.Paper.Lerp(theme.Secondary, .48f));
            material.SetShaderParameter("note_enabled", withNote && CityPageArtSkin.UsesWuhanPalette(cityId) ? 1f : 0f);
            book.Material = material;
        }
    }
    private void CityFrame(JourneyPage page, string title)
    {
        if (HostedByBook)
        {
            Begin(page); BookFrame(_city); return;
        }
        Begin(page);
        if (page == JourneyPage.City) NavigationUtilities(includeHome: true);
        else if (page == JourneyPage.Ledger) NavigationUtilities(includeHome: true);
        else Chrome(RenderCity, title, showBack: page != JourneyPage.Upgrades);
        if (page == JourneyPage.Ledger)
        {
            var ledger = HomeArt(_body, "旅行手账双页母版-经营手账", BookBounds);
            ledger.Name = "SharedBook";
            CityPageArtSkin.Apply(ledger, BookPaletteCity);
        }
        else BookFrame(_city, page == JourneyPage.City);
        if (!HostedByBook && _homeBookPalette)
            ApplyHomeBookBackground(_body.GetNode<TextureRect>("SharedBook"));
        (string Name, string Caption, Action Action)[] tabs = {
            ("ContinueTab", "继续营业", RenderCity),
            ("LedgerTab", "经营手账", PresentLedger), ("UpgradeTab", "店铺升级", PresentUpgrades) };
        for (int i = 0; i < tabs.Length; i++)
        {
            var bookmark = tabs[i];
            bool selected = page == JourneyPage.City && i == 0 || page == JourneyPage.Ledger && i == 1 || page == JourneyPage.Upgrades && i == 2;
            var button = Button(_body, bookmark.Name, "", new(selected ? 1617 : 1607, 290 + i * 170, 140, 155), bookmark.Action, bare: true);
            var tabArt = HomeArt(button, i == 0 ? "书页标签-继续旅程" : "书页标签-" + bookmark.Caption + "-v2", new(0, 0, 140, 155), stretch: true);
            // The supplied journey tab has its own green artwork and icon; leave it unmodified.
            if (i != 0) CityPageArtSkin.Apply(tabArt, BookPaletteCity);
            button.Disabled = selected;
            var caption = Text(button, "Caption", bookmark.Caption.Insert(2, "\n"), new(25, 85, 94, 57), 25, true);
            FitContinueLines(caption, 25, 16, 2);
            // The straight edge tucks under the book cover, like a paper index tab.
            _body.MoveChild(button, _body.GetNode("SharedBook").GetIndex());
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
        bool reconciled = _cityModel is null || _cityModel.Reconcile(out _);
        var city = JourneyModel.City(_city); var p = JourneyModel.Progress(_save!, _city);
        int day = Math.Max(1, p.HighestUnlockedDay);
        var overview = _cityModel?.Overview(_city, day);
        day = overview?.Day ?? day;
        CityFrame(JourneyPage.City, city.Name + "早餐铺");
        DrawContinuePostcard(city);
        var dayRibbon = HomeArt(_body, "Dayx背景", new(320, 695, 595, 145));
        dayRibbon.Name = "DayRibbon";
        CityPageArtSkin.Apply(dayRibbon, BookPaletteCity);
        var dayCaption = Text(_body, "DayTitle", $"第{day}天 {overview?.Title ?? ""}", new(383, 722, 443, 74), 32, true);
        FitTextWidth(dayCaption, 32, 22);
        if (_save!.IsDemo && _save.Data.Wuhan.Completed)
        {
            var keepsake = Button(_body, "ReviewDemoEnding", "重看旅行纪念", new(1100, 276, 350, 40), RenderDemoEnding, bare: true);
            keepsake.AddThemeFontSizeOverride("font_size", 24);
            keepsake.Size = new(350, 40);
        }
        // The master already contains the paper. Follow its printed rules, including their slope.
        var note = new Control { Name = "BusinessNote", Position = new(1018, 350), Size = new(460, 380),
            RotationDegrees = -3.4f, MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(note);
        bool embeddedChallenge = _city is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan;
        var challenge = embeddedChallenge ? _cityModel?.Challenge(_city, day) : null;
        ContinueSummaryRow(note, "Coins", "当前金币", (overview?.Coins ?? _save.Data.Coins).ToString(), 0);
        var unlockRow = ContinueSummaryRow(note, "LatestUnlock", "最新解锁", "", 76);
        DrawLatestUnlocks(unlockRow, overview?.LatestUnlocks ?? Array.Empty<CityUnlockView>());
        ContinueSummaryRow(note, "Goal", "下一目标", overview?.Goal ?? JourneyModel.Goal(_save, city), 152, true);
        string challengeValue = challenge is null ? "第2天起开放"
            : p.ClaimedChallenges.ContainsKey(day) ? $"{challenge.Requirement} · 奖励已领取"
            : $"{challenge.Requirement} · 奖励 {challenge.Reward}金币";
        ContinueSummaryRow(note, "Progress", embeddedChallenge ? "每日挑战" : "城市进度",
            embeddedChallenge ? challengeValue : $"已营业 {overview?.CompletedDays ?? 0} 天 · 可持续营业", 228,
            icon: embeddedChallenge ? "下一目标" : null);
        ContinueSummaryRow(note, "BestRecord", "历史最佳", overview?.BestRevenue is { } best ? $"{best} 金币(第{overview.BestDay}天)" : "暂无记录", 304);
        if (p.Completed) HomeArt(_body, JourneyModel.Stamp(city), new(788, 230, 92, 92)).Name = "CompletionStamp";
        if (!embeddedChallenge)
        {
            var goals = new Control { Name = "JourneyGoals", Position = new(1015, 755), Size = new(425, 90), MouseFilter = MouseFilterEnum.Ignore };
            _body.AddChild(goals);
            if (_city == StableIds.Cities.Yangzhou)
            {
                var collection = Text(goals, "Collection", p.UnlockedCollectibleIds.Contains("collectible:yangzhou_crab_soup_bun") ? "已收藏：蟹黄汤包图鉴 · 三星城市徽章" : "三星收藏：蟹黄汤包图鉴\n最终日18组 / 满意度90% / Perfect干丝10份", new(0, 0, 425, 58), 18);
                collection.AddThemeConstantOverride("line_spacing", -6);
                collection.AddThemeColorOverride("font_color", StartScreenTheme.Muted);
            }
        }
        // Tianjin and Wuhan put the business action directly below their five-row information card.
        var open = Button(_body, "OpenBusiness", "继续营业", new(1110, embeddedChallenge ? 752 : 862, 360, 78), () => RequestBusiness(day), bare: true);
        var plate = HomeArt(open, "首页地图按钮底板", new(0, 0, 360, 78), stretch: true);
        CityPageArtSkin.Apply(plate, BookPaletteCity);
        plate.ShowBehindParent = true;
        open.AddThemeFontSizeOverride("font_size", 34);
        open.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
        open.AddThemeConstantOverride("outline_size", 5);
        open.Disabled = !CanOpenDay(day) || !reconciled;
        if (!reconciled) ShowError("解锁进度保存失败，请重试进入城市。原有进度已保留。");
        if (open.Disabled) plate.Modulate = new Color(1, 1, 1, .55f);
        Focus("OpenBusiness");
    }
    private void RenderLedgerPage()
    {
        var city = JourneyModel.City(_city); var p = JourneyModel.Progress(_save!, _city);
        CityFrame(JourneyPage.Ledger, city.Name + " · 经营手账");
        var calendarTitle = Text(_body, "CalendarTitle", "营业日历", new(604, 248, 270, 65), 43, true);
        FitTextWidth(calendarTitle, 43, 20);
        calendarTitle.RotationDegrees = -4;
        var progress = Text(_body, "CalendarProgress", $"已开放至第 {p.HighestUnlockedDay} 天 · {p.BestStars} 星", new(596, 348, 286, 32), 19, true);
        FitTextWidth(progress, 19, 14);
        int pageStart = (SelectedDay - 1) / 15 * 15 + 1;
        int lastDay = Math.Max(_save!.ChapterLength(_city), p.HighestUnlockedDay);
        if (lastDay > 15)
        {
            var previous = Button(_body, "PreviousDays", "", new(320, 844, 150, 48), () => { SelectedDay = Math.Max(1, pageStart - 15); RenderLedgerPage(); }, bare: true);
            PageArrowArt.Apply(previous, false, BookPaletteCity);
            previous.Disabled = pageStart == 1;
            var next = Button(_body, "NextDays", "", new(690, 844, 150, 48), () => { SelectedDay = Math.Min(lastDay, pageStart + 15); RenderLedgerPage(); }, bare: true);
            PageArrowArt.Apply(next, true, BookPaletteCity);
            next.Disabled = pageStart + 14 >= lastDay;
        }
        for (int d = pageStart; d <= Math.Min(lastDay, pageStart + 14); d++)
        {
            int date = d; bool unlocked = d <= p.HighestUnlockedDay;
            bool recorded = p.DayBestRecords.TryGetValue(d, out var record) && unlocked && !_save!.HasLoadError;
            var at = new Vector2(320 + ((d - pageStart) % 3) * 190, 406 + ((d - pageStart) / 3) * 84);
            var b = Button(_body, "Date" + d, "", new(at, new(179, 82)), () => { SelectedDay = date; RenderLedgerPage(); Focus("Date" + date); }, bare: true);
            var panel = new Panel { Size = b.Size, MouseFilter = MouseFilterEnum.Ignore };
            bool wuhan = CityPageArtSkin.UsesWuhanPalette(BookPaletteCity);
            var palette = CitySettlementTheme.For(wuhan ? "wuhan" : "tianjin");
            var style = StartScreenTheme.Box(wuhan
                ? (d == SelectedDay ? CitySettlementTheme.Paper.Lerp(palette.Primary, .32f) : unlocked ? CitySettlementTheme.Paper.Lerp(palette.Secondary, .24f) : CitySettlementTheme.Paper.Lerp(palette.Secondary, .52f))
                : (d == SelectedDay ? new Color("#FFE29C") : unlocked ? new Color("#FFF7E6") : new Color("#E9D8B8")), d == SelectedDay ? 3 : 1);
            style.BorderColor = wuhan ? (d == SelectedDay ? palette.Primary.Darkened(.18f) : palette.Secondary.Darkened(.35f)) : d == SelectedDay ? new Color("#E5A334") : new Color("#AD8056");
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
            if (d == SelectedDay) HomeArt(b, "小红旗", new(151, -12, 30, 36)).Name = "SelectedFlag";
        }
        Text(_body, "SelectedDay", $"第 {SelectedDay} 天", new(1050, 245, 325, 65), 49, true);
        if (SelectedDay == _save!.ChapterLength(_city)) HomeArt(_body, "皇冠", new(1368, 245, 55, 50)).Name = "FinalDayCrown";
        var theme = Text(_body, "SelectedTheme", _cityModel?.DayTitle(_city, SelectedDay) ?? "", new(1050, 340, 360, 42), 30, true);
        FitTextWidth(theme, 30, 20);
        if (SelectedDay > p.HighestUnlockedDay || _save!.HasLoadError)
            HomeArt(_body, "未解锁城市节点", new(1175, 401, 145, 145));
        else
        {
            var foodBoard = new TextureRect
            {
                Name = "LedgerFoodBoard",
                Position = new(1005, 372),
                Size = new(500, 210),
                Texture = GD.Load<Texture2D>("res://resource/art/Global/UpgradeUI/设备涂鸦背景-v1.png"),
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.Scale,
                MouseFilter = MouseFilterEnum.Ignore,
            };
            _body.AddChild(foodBoard);
            var paths = _cityModel?.LedgerArt(_city, SelectedDay) ?? Array.Empty<string>();
            if (paths.Length == 0) Foods(_body, city, new(1020, 385), 170, .75f);
            else for (int i = 0; i < paths.Length; i++)
                Art(_body, paths[i], new(1010 + i * 490f / paths.Length + 10, 390, 490f / paths.Length - 20, 170));
        }
        bool hasRecord = p.DayBestRecords.TryGetValue(SelectedDay, out var best) && SelectedDay <= p.HighestUnlockedDay && !_save!.HasLoadError;
        Text(_body, "RecordTitle", _save.HasLoadError ? "存档无法读取" : hasRecord ? "历史最佳收入" : SelectedDay > p.HighestUnlockedDay ? "营业日尚未解锁" : "等待开店", new(1100, 589, 270, 36), 25);
        var revenue = Text(_body, "BestRevenue", _save.HasLoadError ? "请打开设置管理存档" : hasRecord ? $"{best!.TotalRevenue} 金币" : SelectedDay > p.HighestUnlockedDay ? $"完成第 {SelectedDay - 1} 天后开放" : "这一天还没有营业记录", new(1100, 630, 250, 48), hasRecord ? 38 : 23);
        FitTextWidth(revenue, hasRecord ? 38 : 23, 19);
        var satisfaction = Text(_body, "BestMetrics", hasRecord ? $"满意度 {best!.Satisfaction:0}%" : "满意度 —", new(1100, 710, 235, 38), 28);
        FitTextWidth(satisfaction, 28, 19);
        if (hasRecord && best!.PerfectOrders > 0)
            Art(_body, "res://resource/art/Global/StartPage/Perfect印章.png", new(1370, 603, 70, 70)).Name = "PerfectStamp";
        var perfect = Text(_body, "BestPerfect", hasRecord ? $"Perfect {best!.PerfectOrders} 单" : "", new(1335, 687, 108, 60), 18, true);
        FitTextWidth(perfect, 18, 12);
        if (_save.HasLoadError)
            Text(_body, "ReplayNote", "可打开设置，在存档管理中选择其他旅程。", new(1010, 803, 505, 38), 21, true);
        string startCaption = hasRecord ? "再次营业" : "开张";
        var start = Button(_body, "StartSelectedDay", "", new(1110, 795, 340, 48), () => RequestBusiness(SelectedDay), bare: true);
        var plateTexture = Texture("首页地图按钮底板");
        float plateScale = start.Size.Y / plateTexture.GetHeight();
        var plate = new NinePatchRect
        {
            Name = "StartSelectedDayButtonPlate", Texture = plateTexture, Size = start.Size / plateScale,
            Scale = Vector2.One * plateScale, PatchMarginLeft = plateTexture.GetHeight() / 2,
            PatchMarginRight = plateTexture.GetHeight() / 2, MouseFilter = MouseFilterEnum.Ignore
        };
        start.AddChild(plate);
        CityPageArtSkin.Apply(plate, BookPaletteCity);
        var startLabel = Text(start, "Caption", startCaption, new(0, 0, start.Size.X, start.Size.Y), 29, true);
        startLabel.AddThemeColorOverride("font_color", StartScreenTheme.Ink);
        startLabel.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
        startLabel.AddThemeConstantOverride("outline_size", 3);
        start.Disabled = !CanOpenDay(SelectedDay);
        if (start.Disabled) { plate.Modulate = new(1, 1, 1, .55f); startLabel.Modulate = new(1, 1, 1, .55f); }
        Focus("Date" + SelectedDay);
        InterfaceTeaching.Offer(_body, InterfaceLessons.CalendarKey, InterfaceLessons.Calendar,
            () => !ModalOpen && Page == JourneyPage.Ledger);
    }
    internal static string LedgerMoodArt(double? satisfaction) => satisfaction is null ? "灰脸"
        : satisfaction >= 60 ? "绿笑脸" : satisfaction >= 30 ? "棕平脸" : "红难过";
    private static void FitTextWidth(Label label, int size, int minimum)
    {
        var font = label.GetThemeFont("font");
        while (size > minimum && label.Tr(label.Text).ToString().Split('\n').Any(line => font.GetStringSize(line, HorizontalAlignment.Left, -1, size).X > label.Size.X)) size--;
        label.AddThemeFontSizeOverride("font_size", size);
    }
    private string? _selectedEquipment;
    private string? _equipmentCity;
    private void RenderUpgradePage()
    {
        CityFrame(JourneyPage.Upgrades, "");
        var wallet = EquipmentUpgradeView.AddWallet(_body, _bookUpgradeSource?.Coins ?? _save!.Data.Coins, new(1220, 220, 360, 64));
        wallet.PivotOffset = wallet.Size;
        wallet.Scale = Vector2.One * .49f;
        if (_equipmentCity != _city) { _selectedEquipment = null; _equipmentCity = _city; }
        var view = new EquipmentUpgradeView { Name = "UpgradeView", Position = new(320, 230) };
        _body.AddChild(view);
        view.Configure(_bookUpgradeSource?.Equipment ?? _cityModel?.Equipment(_city) ?? Array.Empty<CityEquipmentView>(), _selectedEquipment, BookPaletteCity,
            id => { _selectedEquipment = id; _bookUpgradeSelection?.Invoke(id); }, e =>
            {
                if (HostedByBook) { _bookUpgradePurchase?.Invoke(e); return; }
                // The home book is itself a modal; purchases inside it remain interactive.
                if (_busy || (ModalOpen && !_modal.IsAncestorOf(view))) return;
                var current = _cityModel?.Equipment(_city).FirstOrDefault(i => i.Id == e.Id);
                if (current is null || !current.CanBuy || current.Level != e.Level || current.Price != e.Price)
                { RefreshCityPage(); ShowError("设备状态已变化，请查看最新升级信息。"); return; }
                _purchasedEquipment = e;
                _busy = true; UpgradeRequested?.Invoke(_city, e.PurchaseId);
            }, HostedByBook && _bookUpgradeSource?.SupportsContinue == true ? $"开始第 {_bookUpgradeSource.NextDay} 天" : null,
            HostedByBook && _bookUpgradeSource?.SupportsContinue == true ? _bookUpgradeContinue : null);
        Focus("Select_" + view.SelectedId);
    }
}
