using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private Label? _archiveMessage;
    private int? _selectedArchiveSlotId;
    private int? _archiveMoreSlotId;

    private bool SwitchSaveSlot(int id)
    {
        if (_save is null || _busy) return false;
        if (_save.ActiveSlotId == id) return true;
        _busy = true;
        if (!_save.TryLoadSlot(id, out string error))
        {
            _busy = false;
            if (_archiveMessage is not null) _archiveMessage.Text = error;
            return false;
        }
        _selectedEquipment = null; _equipmentCity = null; _completedCity = null;
        _mapReturn = null; _cityReturn = null;
        _busy = false;
        SetStatus();
        return true;
    }

    private Button ArchiveButton(string name, string caption, Rect2 bounds, Action action)
    {
        var button = SettingsButton(name, caption, bounds, action);
        int size = 24;
        var font = button.GetThemeFont("font");
        string translated = button.Tr(caption);
        while (size > 16 && font.GetStringSize(translated, fontSize: size).X > bounds.Size.X - 18) size--;
        button.AddThemeFontSizeOverride("font_size", size);
        return button;
    }

    private void OpenJourneyArchives(bool newJourney = false)
    {
        if (_save is null || _busy) return;
        if (!newJourney)
        {
            OpenJourneyArchiveSpread();
            return;
        }
        OpenModal("journey-archives");
        var slots = _save.GetSlots();
        var title = Text(_modal, "ArchivesTitle", newJourney ? "选择一本空白旅行手账" : "我的旅程档案",
            new(340, 214, 1180, 66), 44, true);
        title.AddThemeColorOverride("font_color", JournalSettingsTheme.Ink);
        Text(_modal, "ArchivesHint", newJourney
            ? slots.All(s => s.Exists) ? "五本手账已经写满。可到旅程档案删除不再需要的旅程。" : "选择空白手账，出发时才会创建旅程。"
            : "选择旅程继续旅行，也可以在这里改名或删除。", new(354, 282, 1150, 43), 23);
        for (int i = 0; i < slots.Count; i++) AddArchiveSlot(slots[i], i, newJourney);
        _archiveMessage = Text(_modal, "ArchivesMessage", "", new(355, 835, 950, 40), 22);
        _archiveMessage.AddThemeColorOverride("font_color", new Color("#983F32"));
        var close = SettingsButton("CloseArchives", newJourney && slots.All(s => s.Exists) ? "前往旅程档案" : "返回首页",
            new(1308, 833, 240, 58), newJourney && slots.All(s => s.Exists) ? () => OpenJourneyArchives() : CloseModal);
        JournalSettingsTheme.Apply(close, selected: true);
        _modal.GetNodeOrNull<Button>(newJourney ? "CreateSlot" + (slots.FirstOrDefault(s => !s.Exists)?.Id ?? 0) :
            "ArchiveSlot" + (_save.ActiveSlotId ?? slots.FirstOrDefault(s => s.Exists && !s.Corrupt)?.Id ?? 1))?.GrabFocus();
    }

    private void OpenJourneyArchiveSpread()
    {
        if (_save is null) return;
        var slots = _save.GetSlots();
        var featured = slots.FirstOrDefault(s => s.Id == _save.ActiveSlotId)
            ?? slots.FirstOrDefault(s => s.Exists && !s.Corrupt)
            ?? slots[0];
        if (_selectedArchiveSlotId == featured.Id || !slots.Any(s => s.Id == _selectedArchiveSlotId))
            _selectedArchiveSlotId = null;
        OpenModal("journey-archives");
        _modal.GetNode<Button>("BookClose").Name = "CloseArchives";
        var upperRoute = HomeArt(_modal, "手绘旅行虚线路径2", new(1176, 211, 235, 62));
        upperRoute.Name = "ArchiveUpperRoute";
        upperRoute.Modulate = new Color(1, 1, 1, .55f);
        HomeArt(_modal, "路线起点_终点小旗", new(1390, 220, 36, 36)).Name = "ArchiveRouteFlag";
        Text(_modal, "OtherArchivesTitle", "其他旅程", new(992, 251, 385, 45), 29);
        var lowerRoute = HomeArt(_modal, "手绘旅行虚线路径3", new(1015, 771, 420, 69));
        lowerRoute.Name = "ArchiveLowerRoute";
        lowerRoute.Modulate = new Color(1, 1, 1, .38f);
        AddFeaturedArchive(featured);
        int index = 0;
        foreach (var slot in slots)
        {
            if (slot.Id == featured.Id) continue;
            AddSmallArchive(slot, index++);
        }
        _archiveMessage = Text(_modal, "ArchivesMessage", "", new(1000, 813, 510, 42), 21);
        _archiveMessage.AddThemeColorOverride("font_color", new Color("#983F32"));
        (_modal.GetNodeOrNull<Button>("ArchiveSelect" + (_selectedArchiveSlotId ?? featured.Id))
            ?? _modal.GetNodeOrNull<Button>("ArchiveSlot" + featured.Id)
            ?? _modal.GetNodeOrNull<Button>("CreateSlot" + featured.Id))?.GrabFocus();
    }

    private static Color ArchiveAccent(string cityId) => cityId switch
    {
        "city:wuhan" => new Color("#8CB6A4"),
        "city:xian" => new Color("#B79178"),
        "city:guangzhou" => new Color("#A4B88E"),
        "city:yangzhou" => new Color("#B899AB"),
        _ => new Color("#DBAA65")
    };

    private static string? ArchiveBreakfastMap(string cityId) => cityId switch
    {
        "city:tianjin" => "早餐地图-天津",
        "city:wuhan" => "早餐地图-武汉",
        _ => null
    };

    private Panel ArchivePaper(string name, Rect2 bounds, bool selected = false)
    {
        var paper = new Panel { Name = name, Position = bounds.Position, Size = bounds.Size,
            MouseFilter = MouseFilterEnum.Ignore };
        var style = JournalSettingsTheme.Box(new Color(selected ? "#FFF0CD" : "#FFF9ED"), 19, selected ? 3 : 2);
        style.BorderColor = new Color(selected ? "#8A6943" : "#BD9271");
        paper.AddThemeStyleboxOverride("panel", style);
        _modal.AddChild(paper);
        return paper;
    }

    private void AddFeaturedArchive(SaveSlotSummary slot)
    {
        const float x = 330, y = 283;
        ArchivePaper("ArchiveCard" + slot.Id, new(x, y, 550, 505));
        var cover = HomeArt(_modal, slot.Exists ? "已有旅程手账封面" : "空白存档手账",
            new(x + 25, y + 103, 215, 235));
        cover.Name = "FeaturedArchiveCover";
        cover.PivotOffset = cover.Size / 2;
        cover.RotationDegrees = -4;
        HomeArt(_modal, "小星星", new(x + 194, y + 94, 36, 36)).RotationDegrees = 12;
        var flag = ArchivePaper("CurrentArchiveFlag", new(x - 19, y - 26, 207, 55), true);
        flag.RotationDegrees = -5;
        Text(_modal, "CurrentArchiveCaption", slot.Id == _save?.ActiveSlotId ? "旅途中" : "旅行手账",
            new(x + 18, y - 18, 170, 44), 28);
        string name = slot.Corrupt ? $"旅程 {slot.Id} · 无法读取" : slot.Exists ? slot.Name : $"旅程 {slot.Id}";
        var heading = Text(_modal, "ArchiveName" + slot.Id, name, new(x + 247, y + 51, 268, 54), 38);
        FitTextWidth(heading, 38, 23);
        heading.AutowrapMode = TextServer.AutowrapMode.Off;
        heading.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
        heading.TooltipText = name;
        if (slot.Exists && !slot.Corrupt)
        {
            var city = JourneyModel.City(slot.CityId);
            if (ArchiveBreakfastMap(slot.CityId) is { } mapArt)
                HomeArt(_modal, mapArt, new(x + 18, y + 274, 230, 111)).Name = "ArchiveBreakfastMap" + slot.Id;
            else
                HomeArt(_modal, JourneyModel.NodeArt(city), new(x + 66, y + 290, 120, 90))
                    .Name = "ArchiveCitySticker" + slot.Id;
            var accent = ArchiveAccent(slot.CityId);
            var dayStamp = ArchivePaper("ArchiveDayStamp" + slot.Id, new(x + 400, y + 104, 112, 82));
            var dayStyle = JournalSettingsTheme.Box(new Color("#FFF9ED"), 35, 3);
            dayStyle.BorderColor = accent;
            dayStamp.AddThemeStyleboxOverride("panel", dayStyle);
            Text(_modal, "ArchiveDay" + slot.Id, $"DAY {slot.Day}", new(x + 405, y + 119, 102, 53), 22, true);
            var cityLabel = Text(_modal, "ArchiveProgress" + slot.Id,
                $"{city.Name} · 第 {slot.Day} 天",
                new(x + 248, y + 196, 272, 37), 22);
            FitTextWidth(cityLabel, 22, 17);
            HomeArt(_modal, JourneyModel.Stamp(city), new(x + 251, y + 255, 91, 91)).RotationDegrees = -10;
            HomeArt(_modal, "当前金币", new(x + 344, y + 258, 44, 44));
            Text(_modal, "FeaturedCoins", $"{slot.Coins} 金币", new(x + 391, y + 262, 130, 39), 22);
            var journeyLine = HomeArt(_modal, "手绘旅行虚线路径2", new(x + 267, y + 310, 218, 45), stretch: true);
            journeyLine.Name = "ArchiveJourneyLine";
            journeyLine.Modulate = new Color(1, 1, 1, .66f);
            HomeArt(_modal, "定位符", new(x + 247, y + 304, 32, 39)).Name = "ArchiveJourneyStart";
            HomeArt(_modal, "小红旗", new(x + 484, y + 301, 31, 35)).Name = "ArchiveJourneyEnd";
            Text(_modal, "ArchiveRouteStart", "天津", new(x + 248, y + 342, 94, 37), 22);
            var destination = Text(_modal, "ArchiveRoute",
                city.Name == "天津" ? "下一站" : city.Name, new(x + 421, y + 342, 103, 37), 22, true);
            destination.AddThemeColorOverride("font_color", ArchiveAccent(slot.CityId).Darkened(.36f));
            var go = ArchiveButton("ArchiveSlot" + slot.Id, "继续旅程  ›",
                new(x + 80, y + 389, 390, 67), () =>
                {
                    if (slot.Id != _save?.ActiveSlotId && !SwitchSaveSlot(slot.Id)) return;
                    CloseModal(); PresentMap();
                });
            JournalSettingsTheme.Apply(go, selected: true, radius: 25);
            go.AddThemeFontSizeOverride("font_size", 30);
            ArchiveButton("RenameSlot" + slot.Id, "✎ 改名", new(x + 108, y + 462, 143, 38),
                () => ShowArchiveRename(slot, x + 120, y + 38));
        }
        else
        {
            Text(_modal, "ArchiveProgress" + slot.Id,
                slot.Corrupt ? "这本手账暂时无法读取" : "尚未出发，写下第一站",
                new(x + 247, y + 178, 270, 65), 22);
            if (!slot.Exists)
                ArchiveButton("CreateSlot" + slot.Id, "开启新旅程", new(x + 80, y + 389, 390, 67),
                    () => RequestNewGame(slot.Id));
        }
        if (slot.Exists)
        {
            ArchiveButton("ArchiveMore" + slot.Id, "⋯", new(x + 310, y + 462, 55, 38), () =>
            {
                _archiveMoreSlotId = _archiveMoreSlotId == slot.Id ? null : slot.Id;
                OpenJourneyArchiveSpread();
            });
            if (_archiveMoreSlotId == slot.Id)
                ArchiveButton("DeleteSlot" + slot.Id, "删除旅程", new(x + 371, y + 459, 151, 43),
                    () => RequestDeleteSaveSlot(slot));
        }
    }

    private void AddSmallArchive(SaveSlotSummary slot, int index)
    {
        float x = index % 2 == 0 ? 982 : 1268, y = index / 2 == 0 ? 299 : 515;
        bool selected = _selectedArchiveSlotId == slot.Id;
        ArchivePaper("ArchiveCard" + slot.Id, new(x, y, 263, 198), selected);
        var choose = ArchiveButton("ArchiveSelect" + slot.Id, "", new(x, y, 263, 198), () =>
        {
            _selectedArchiveSlotId = slot.Id;
            _archiveMoreSlotId = null;
            OpenJourneyArchiveSpread();
        });
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            choose.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        HomeArt(choose, slot.Exists ? "已有旅程手账封面" : "空白存档手账",
            new(10, 31, 85, 99));
        HomeArt(choose, "小星星", new(224, 6, 27, 27)).RotationDegrees = slot.Id % 2 == 0 ? 12 : -12;
        string name = slot.Corrupt ? $"旅程 {slot.Id} · 无法读取" : slot.Exists ? slot.Name : $"旅程 {slot.Id}";
        var label = Text(choose, "ArchiveName" + slot.Id, name, new(100, 34, 151, 40), 25);
        FitTextWidth(label, 25, 18);
        label.AutowrapMode = TextServer.AutowrapMode.Off;
        label.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
        choose.TooltipText = name;
        string cityName = slot.Corrupt ? "无法读取" : slot.Exists ? JourneyModel.City(slot.CityId).Name : "空白手账";
        Text(choose, "ArchiveProgress" + slot.Id,
            slot.Exists && !slot.Corrupt ? $"{cityName} · 第 {slot.Day} 天 · {slot.Coins} 金币" : cityName,
            new(100, 79, 155, 55), 17);
        if (slot.Exists && !slot.Corrupt)
        {
            if (ArchiveBreakfastMap(slot.CityId) is { } mapArt)
                HomeArt(choose, mapArt, new(18, 122, 112, 67)).Name = "ArchiveBreakfastMap" + slot.Id;
            var stamp = ArchivePaper("ArchiveSmallDay" + slot.Id, new(x + 169, y + 141, 82, 42), selected);
            var style = JournalSettingsTheme.Box(new Color("#FFF9ED"), 20, 2);
            style.BorderColor = ArchiveAccent(slot.CityId);
            stamp.AddThemeStyleboxOverride("panel", style);
            Text(_modal, "ArchiveDay" + slot.Id, $"DAY {slot.Day}", new(x + 173, y + 146, 74, 32), 17, true);
            if (ArchiveBreakfastMap(slot.CityId) is null)
                HomeArt(choose, JourneyModel.Stamp(JourneyModel.City(slot.CityId)),
                    new(24, 130, 44, 44)).RotationDegrees = -13;
        }
        else Text(choose, "ArchiveDay" + slot.Id, slot.Corrupt ? "待整理" : "待出发",
            new(157, 148, 90, 30), 17, true);
        if (!selected) return;
        if (slot.Exists && !slot.Corrupt)
        {
            ArchiveButton("ArchiveSlot" + slot.Id, "选择这段旅程", new(1008, 733, 260, 53), () =>
            {
                if (!SwitchSaveSlot(slot.Id)) return;
                CloseModal(); PresentMap();
            });
            ArchiveButton("RenameSlot" + slot.Id, "✎ 改名", new(1282, 733, 119, 53),
                () => ShowArchiveRename(slot, x - 7, y + 5));
        }
        else if (!slot.Exists)
            ArchiveButton("CreateSlot" + slot.Id, "开启新旅程", new(1008, 733, 260, 53),
                () => RequestNewGame(slot.Id));
        if (slot.Exists)
        {
            ArchiveButton("ArchiveMore" + slot.Id, "⋯", new(1415, 733, 59, 53), () =>
            {
                _archiveMoreSlotId = _archiveMoreSlotId == slot.Id ? null : slot.Id;
                OpenJourneyArchiveSpread();
            });
            if (_archiveMoreSlotId == slot.Id)
                ArchiveButton("DeleteSlot" + slot.Id, "删除旅程", new(1340, 790, 150, 43),
                    () => RequestDeleteSaveSlot(slot));
        }
    }

    private void AddArchiveSlot(SaveSlotSummary slot, int index, bool newJourney)
    {
        int column = index % 2, row = index / 2;
        float x = column == 0 ? 335 : 1000, y = 349 + row * 153;
        var card = new Panel { Name = "ArchiveCard" + slot.Id, Position = new(x, y), Size = new(575, 136), MouseFilter = MouseFilterEnum.Ignore };
        card.AddThemeStyleboxOverride("panel", JournalSettingsTheme.Box(slot.Id == _save?.ActiveSlotId
            ? new Color("#F3DA9B") : new Color("#FFF8E8"), 13, 2));
        _modal.AddChild(card);
        HomeArt(_modal, slot.Exists ? "已有旅程手账封面" : "闭合旅行手账封面｜新旅程入口",
            new(x + 15, y + 16, 67, 98));
        string heading = slot.Corrupt ? $"旅程 {slot.Id} · 无法读取" : slot.Exists ? slot.Name : $"旅程 {slot.Id} · 空白手账";
        var label = Text(_modal, "ArchiveName" + slot.Id, heading, new(x + 91, y + 13, 295, 42), 26);
        FitTextWidth(label, 26, 19);
        string details = slot.Corrupt ? "可删除，其他旅程仍可使用" : slot.Exists
            ? $"{JourneyModel.City(slot.CityId).Name} · 第 {slot.Day} 天 · {slot.Coins} 金币" : "尚未出发";
        var progress = Text(_modal, "ArchiveProgress" + slot.Id, details, new(x + 91, y + 56, 375, 33), 19);
        FitTextWidth(progress, 19, 16);
        if (newJourney)
        {
            if (!slot.Exists) ArchiveButton("CreateSlot" + slot.Id, "开始旅程", new(x + 399, y + 83, 156, 42),
                () => RequestNewGame(slot.Id));
            return;
        }
        if (!slot.Exists)
        {
            ArchiveButton("CreateSlot" + slot.Id, "新的旅程", new(x + 399, y + 83, 156, 42),
                () => RequestNewGame(slot.Id));
            return;
        }
        if (!slot.Corrupt)
        {
            string action = slot.Id == _save?.ActiveSlotId ? "继续旅程" : "设为当前";
            ArchiveButton("ArchiveSlot" + slot.Id, action, new(x + 399, y + 83, 156, 42), () =>
            {
                if (slot.Id != _save?.ActiveSlotId && !SwitchSaveSlot(slot.Id)) return;
                CloseModal(); PresentMap();
            });
            ArchiveButton("RenameSlot" + slot.Id, "改名", new(x + 91, y + 96, 95, 32), () => ShowArchiveRename(slot, x, y));
        }
        ArchiveButton("DeleteSlot" + slot.Id, "删除", new(x + 198, y + 96, 95, 32), () => RequestDeleteSaveSlot(slot));
    }

    private void ShowArchiveRename(SaveSlotSummary slot, float x, float y)
    {
        if (_modal.GetNodeOrNull<LineEdit>("ArchiveRename") is not null) return;
        var input = new LineEdit { Name = "ArchiveRename", Text = slot.Name, MaxLength = 40,
            Position = new(x + 91, y + 11), Size = new(292, 44) };
        input.AddThemeStyleboxOverride("normal", JournalSettingsTheme.Box(new Color("#FFF8E8"), 8, 2));
        input.AddThemeFontSizeOverride("font_size", 23);
        input.AddThemeColorOverride("font_color", JournalSettingsTheme.Ink);
        _modal.AddChild(input); _modalControls.Add(input);
        var save = SettingsButton("SaveArchiveName", "保存", new(x + 390, y + 11, 78, 44), () =>
        {
            if (_save is null) return;
            if (!_save.TryRenameSlot(slot.Id, input.Text, out string error))
            { if (_archiveMessage is not null) _archiveMessage.Text = error; return; }
            OpenJourneyArchives();
        });
        SettingsButton("CancelArchiveName", "取消", new(x + 476, y + 11, 78, 44), () => OpenJourneyArchives());
        input.TextSubmitted += _ => save.EmitSignal(BaseButton.SignalName.Pressed);
        input.GrabFocus(); input.SelectAll();
    }

    private void OpenMapJourneySwitch()
    {
        if (_save is null || _busy) return;
        OpenModal("map-switch");
        var journeys = _save.GetSlots().Where(s => s.Exists && !s.Corrupt).ToArray();
        const float x = 720, y = 169, width = 480, rowStart = 224, rowStep = 76;
        float footerY = rowStart + journeys.Length * rowStep + 7;
        float height = footerY + 70 - y;
        var frame = new Panel { Name = "JourneySwitchDrawer", Position = new(x, y),
            Size = new(width, height), MouseFilter = MouseFilterEnum.Ignore };
        var wood = JournalSettingsTheme.Box(new Color("#C58243"), 29, 5);
        wood.BorderColor = new Color("#79401F");
        wood.ShadowColor = new Color(0.27f, 0.13f, 0.05f, 0.35f);
        wood.ShadowSize = 9;
        wood.ShadowOffset = new Vector2(0, 6);
        frame.AddThemeStyleboxOverride("panel", wood);
        _modal.AddChild(frame);
        var paper = new Panel { Name = "JourneySwitchPaper", Position = new(x + 9, y + 9),
            Size = new(width - 18, height - 18), MouseFilter = MouseFilterEnum.Ignore };
        var paperStyle = JournalSettingsTheme.Box(new Color("#FFF5DF"), 23, 3);
        paperStyle.BorderColor = new Color("#E9B76C");
        paper.AddThemeStyleboxOverride("panel", paperStyle);
        _modal.AddChild(paper);
        var heading = Text(_modal, "SwitchTitle", "选择旅程", new(x + 28, y + 13, 285, 38), 26);
        heading.AddThemeColorOverride("font_color", StartScreenTheme.Ink);
        _modal.AddChild(new ColorRect { Position = new(x + 220, y + 34), Size = new(width - 268, 2),
            Color = new Color("#D6A777"), MouseFilter = MouseFilterEnum.Ignore });
        int first = -1;
        int row = 0;
        foreach (var slot in journeys)
        {
            bool active = slot.Id == _save.ActiveSlotId;
            var city = JourneyModel.City(slot.CityId);
            string summary = $"{city.Name}·第{slot.Day}天·金币{slot.Coins}";
            var button = SettingsButton("MapSwitchSlot" + slot.Id, summary,
                new(x + 26, rowStart + row++ * rowStep, width - 52, 65), () =>
                {
                    if (slot.Id != _save.ActiveSlotId && !SwitchSaveSlot(slot.Id)) return;
                    CloseModal(); PresentMap();
                });
            var card = JournalSettingsTheme.Box(active ? new Color("#FFE7A9") : new Color("#FFFDF5"), 22, 3);
            card.BorderColor = active ? new Color("#C3752E") : new Color("#DDB78B");
            card.ShadowColor = new Color(0.46f, 0.26f, 0.10f, 0.20f);
            card.ShadowSize = 3;
            card.ShadowOffset = new Vector2(0, 3);
            button.AddThemeStyleboxOverride("normal", card);
            button.AddThemeStyleboxOverride("hover", JournalSettingsTheme.Box(new Color("#FFE9B9"), 22, 3));
            foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color" })
                button.AddThemeColorOverride(state, Colors.Transparent);
            if (ArchiveBreakfastMap(slot.CityId) is { } mapArt)
            {
                var skyline = HomeArt(button, mapArt, new(width - 224, 4, 156, 57));
                skyline.Name = "MapSwitchBreakfastMap" + slot.Id;
                skyline.Modulate = new Color(1, 1, 1, .32f);
            }
            HomeArt(button, JourneyModel.NodeArt(city), new(9, 4, 55, 57));
            var title = Text(button, "MapSwitchName" + slot.Id, summary, new(74, 16, width - 205, 33), 22);
            title.AddThemeColorOverride("font_color", StartScreenTheme.Ink);
            title.AutowrapMode = TextServer.AutowrapMode.Off;
            FitTextWidth(title, 22, 14);
            title.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
            if (active)
            {
                var badge = new Panel { Position = new(width - 123, 16), Size = new(58, 33),
                    MouseFilter = MouseFilterEnum.Ignore };
                var badgeStyle = JournalSettingsTheme.Box(new Color("#F6B959"), 16, 2);
                badgeStyle.BorderColor = new Color("#9E542B");
                badge.AddThemeStyleboxOverride("panel", badgeStyle);
                button.AddChild(badge);
                var current = Text(button, "MapSwitchCurrent" + slot.Id, "当前", new(width - 120, 18, 52, 29), 18, true);
                current.AddThemeColorOverride("font_color", StartScreenTheme.Ink);
            }
            if (first < 0) first = slot.Id;
        }
        _archiveMessage = Text(_modal, "MapSwitchMessage", "", new(x + 32, footerY + 58, width - 64, 30), 18);
        var archives = SettingsButton("MapSwitchArchives", "管理旅程档案  ›", new(x + 26, footerY, width - 52, 54), () =>
        { CloseModal(); RenderHome(); OpenJourneyArchives(); });
        var footerStyle = JournalSettingsTheme.Box(new Color("#F4D49A"), 18, 3);
        footerStyle.BorderColor = new Color("#B5753A");
        archives.AddThemeStyleboxOverride("normal", footerStyle);
        archives.AddThemeFontSizeOverride("font_size", 25);
        (_modal.GetNodeOrNull<Button>("MapSwitchSlot" + first) ?? archives).GrabFocus();
    }
}
