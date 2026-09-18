using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
namespace ProjectCake.UI;

public partial class StartScreen
{
    private string _selectedBreakfast = "pancake", _collectionCity = "";

    private CollectionDecoration CollectionPaper(Control parent, Rect2 rect, string kind = "paper", bool selected = false)
    {
        var paper = new CollectionDecoration { Position = rect.Position, Size = rect.Size, Kind = kind, Selected = selected };
        parent.AddChild(paper); return paper;
    }
    private void CollectionFood(Control parent, BreakfastCard card, Rect2 rect)
        => parent.AddChild(new BookFoodIcon { Position = rect.Position, Size = rect.Size, CropTransparentMargins = true, Product = new(card.Id, card.Name, 1, card.Visual) });

    public void PresentBreakfastCollection()
    {
        if (_save is null) return;
        Begin(JourneyPage.Collection);
        var book = HomeArt(_body, "旅行手账双页母版", new(30, 4, 1860, 994)); book.Name = "CollectionBook";
        var back = Button(_body, "Back", "", new(80, 105, 44, 55), ReturnFromBreakfastCollection, bare: true);
        Art(back, "账本翻页箭头｜左", new(0, 6, 40, 42));
        Text(_body, "CollectionTitle", "旅途收藏", new(143, 104, 390, 86), 62);
        Text(_body, "CollectionMotto", "收集各地的美味，\n也收集一段段旅途的回忆。", new(151, 190, 510, 62), 23);
        CollectionPaper(_body, new(705, 116, 165, 126));
        Text(_body, "CollectedCaption", "已收集", new(713, 132, 149, 36), 25, true);
        Text(_body, "CollectedCount", $"{_save.CollectedBreakfastIds.Count()} / 5", new(713, 173, 149, 51), 37, true);

        bool wuhan = _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan);
        if (_collectionCity == StableIds.Cities.Wuhan && !wuhan) _collectionCity = "";
        var available = DemoBreakfastCollection.Cards.Where(c => c.CityId == StableIds.Cities.Tianjin || wuhan).ToArray();
        var shown = available.Where(c => _collectionCity.Length == 0 || c.CityId == _collectionCity).ToArray();
        var selected = shown.FirstOrDefault(c => c.Id == _selectedBreakfast) ?? shown[0];
        _selectedBreakfast = selected.Id;
        var tabs = new[] { ("", "全部"), (StableIds.Cities.Tianjin, "天津"), (StableIds.Cities.Wuhan, "武汉"),
            (StableIds.Cities.Xian, "西安"), (StableIds.Cities.Guangzhou, "广州"), (StableIds.Cities.Yangzhou, "扬州") };
        for (int i = 0; i < tabs.Length; i++)
        {
            var (id, caption) = tabs[i]; bool locked = i >= 3 || i == 2 && !wuhan;
            var tab = Button(_body, "CollectionCity" + i, "", new(130 + i * 126, 272, 116, 52),
                () => { _collectionCity = id; PresentBreakfastCollection(); Focus("CollectionCity" + Array.FindIndex(tabs, t => t.Item1 == id)); }, bare: true);
            var paper = CollectionPaper(tab, new(0, 0, 116, 52), selected: id == _collectionCity);
            paper.Fill = id == _collectionCity ? new("#FFE0A0") : new("#EBDEC7");
            Text(tab, "City", caption, new(6, 5, locked ? 70 : 104, 42), 24, true);
            tab.Disabled = locked;
            if (locked) { var mark = CollectionPaper(tab, new(76, 12, 30, 30), "lock"); mark.Scale = new(.65f, .65f); tab.TooltipText = "待解锁"; }
        }

        int index = 0;
        foreach (var card in shown)
        {
            var rect = new Rect2(130 + index % 4 * 190, 347 + index / 4 * 236, 174, 218); index++;
            bool owned = _save.BreakfastRecordDay(card.Id).HasValue;
            var button = Button(_body, "Breakfast_" + card.Id, "", rect,
                () => { _selectedBreakfast = card.Id; PresentBreakfastCollection(); }, bare: true);
            button.TooltipText = card.Name + " · " + (owned ? "已入册" : "待记录");
            CollectionPaper(button, new(Vector2.Zero, rect.Size), "postage", card.Id == selected.Id);
            CollectionFood(button, card, new(15, 17, 144, 121));
            Text(button, "Name", card.Name, new(9, 142, 156, 35), 26, true);
            Text(button, "City", JourneyModel.City(card.CityId).Name, new(9, 180, 85, 26), 21, true);
            if (owned) CollectionPaper(button, new(123, 172, 38, 38), "check").Ink = new("#329751");
            else Text(button, "State", "待记录", new(91, 180, 76, 26), 18, true);
        }
        if (_collectionCity.Length == 0)
        {
            foreach (var city in JourneyModel.Cities.Where(c => c.Id != StableIds.Cities.Tianjin && (c.Id != StableIds.Cities.Wuhan || !wuhan)))
            {
                var rect = new Rect2(130 + index % 4 * 190, 347 + index / 4 * 236, 174, 218); index++;
                var paper = CollectionPaper(_body, rect, "postage"); paper.Fill = new("#EDE5D8");
                CollectionPaper(paper, new(52, 43, 70, 65), "lock").Ink = new("#998875");
                Text(paper, "LockedCity", city.Name, new(12, 138, 150, 37), 27, true);
                Text(paper, "LockedCaption", "待解锁", new(12, 179, 150, 27), 21, true);
            }
        }
        Text(_body, "NextCityHint", wuhan ? "美食无国界\n下一站，会遇见怎样的美味呢？" : "下一站武汉，还有新的早餐等你记录。",
            new(267, 839, 600, 76), 25);
        Art(_body, "闭合旅行手账封面｜新旅程入口", new(133, 824, 115, 100));
        RenderCollectionDetail(selected);
        Button(_body, "CollectionHome", "返回首页", new(1130, 997, 430, 65), ReturnFromBreakfastCollection, true);
        Focus("Breakfast_" + selected.Id);
    }

    private void RenderCollectionDetail(BreakfastCard card)
    {
        var city = JourneyModel.City(card.CityId);
        int? day = _save!.BreakfastRecordDay(card.Id);
        var stats = _save.BreakfastStatsFor(card.Id);
        CollectionPaper(_body, new(1023, 110, 470, 86));
        Text(_body, "BreakfastName", card.Name, new(1045, 117, 428, 67), 49);
        Text(_body, "BreakfastCity", city.Name, new(1516, 128, 130, 50), 32, true);
        Art(_body, JourneyModel.Stamp(city), new(1650, 112, 118, 118));
        var photo = CollectionPaper(_body, new(1028, 245, 322, 312), "photo"); photo.RotationDegrees = -3;
        CollectionFood(photo, card, new(23, 23, 276, 225));
        Text(photo, "PhotoCaption", city.Name + " · 早餐记忆", new(15, 258, 290, 35), 25, true);
        var note = CollectionPaper(_body, new(1380, 244, 376, 311)); note.RotationDegrees = 1;
        Text(note, "NoteTitle", "旅途手记", new(23, 18, 325, 48), 31);
        Text(note, "BreakfastDescription", card.Description, new(23, 87, 325, 100), 26);
        Text(note, "NoteFooter", day.HasValue ? "这份清晨的味道，\n已经留在旅行手账里。" : "把清晨的第一份美味，\n留给下一段旅程。", new(23, 198, 325, 82), 23);

        CollectionPaper(_body, new(1017, 581, 747, 165));
        Text(_body, "StepsHeading", "制作流程", new(1041, 584, 690, 38), 28);
        string[] steps = card.Steps.Split(" → ");
        float stepWidth = 711f / steps.Length;
        for (int i = 0; i < steps.Length; i++)
        {
            float x = 1035 + stepWidth * i;
            var art = CollectionStepArt(card.Id, i);
            if (art is null) CollectionFood(_body, card, new(x + 27, 625, stepWidth - 60, 60));
            else Art(_body, "res://resource/art/" + art + ".png", new(x + 23, 625, stepWidth - 52, 60));
            Text(_body, "Step" + i, steps[i], new(x + 5, 689, stepWidth - 18, 45), 21, true);
            if (i + 1 < steps.Length) Text(_body, "StepArrow" + i, "→", new(x + stepWidth - 18, 654, 28, 40), 25, true);
        }
        CollectionPaper(_body, new(1017, 773, 347, 174));
        Text(_body, "RecordTitle", "我的记录", new(1038, 782, 303, 39), 29);
        Text(_body, "BreakfastOrigin", day.HasValue ? $"首次记录 · {city.Name} · 第 {day.Value} 天"
            : "正确送出合格早餐，收摊保存后入册。", new(1038, 828, 303, 42), 21);
        Text(_body, "BreakfastDelivered", $"{Tr("制作次数")}：{stats.Delivered}", new(1038, 875, 303, 27), 23);
        if (card.Id != "soy_milk") Text(_body, "BreakfastPerfect", $"{Tr("Perfect 次数")}：{stats.Perfect}", new(1038, 910, 303, 27), 23);
        CollectionPaper(_body, new(1384, 773, 380, 174));
        Text(_body, "StampsTitle", "收集印章", new(1404, 782, 340, 39), 29);
        CollectionStamp("FirstStamp", "初遇", day.HasValue ? $"第 {day.Value} 天" : "首次入册", new(1398, 824), day.HasValue, new("#D6533C"));
        CollectionStamp("SkilledStamp", "熟练", "累计20份", new(1516, 824), stats.Skilled, new("#B57716"));
        if (card.Id != "soy_milk") CollectionStamp("PerfectStamp", "Perfect", "完美10份", new(1634, 824), stats.PerfectStamp, new("#8C6743"));
    }

    private static string? CollectionStepArt(string id, int step) => id switch
    {
        "pancake" => step switch { 0 => "TianJin/展开煎饼基础层-v2", 1 => "TianJin/鸡蛋", 2 => "TianJin/煎饼铲子", 3 => "TianJin/酱刷", _ => null },
        "youtiao" => step switch { 0 => "TianJin/生油条面坯", 1 => "TianJin/油条沥油架", 2 => "TianJin/熟油条", 3 => "TianJin/油条沥油架", _ => null },
        "noodles" => step switch { 0 => "Wuhan/通用热干面漏勺_v2", 1 => "Wuhan/漏勺中的熟面状态", 2 => "Wuhan/热干面空碗_v2", _ => null },
        "doupi" => step switch { 0 => "Wuhan/豆皮豆米浆容器_v2", 1 => "Wuhan/豆皮手动翻面铲", 2 => "Wuhan/三鲜糯米馅容器_v2", 3 => "Wuhan/单块三鲜豆皮成品", _ => null },
        _ => null,
    };

    private void CollectionStamp(string name, string title, string subtitle, Vector2 position, bool earned, Color color)
    {
        var stamp = CollectionPaper(_body, new(position, new(112, 112)), "stamp");
        stamp.Name = name; stamp.Ink = earned ? color : new("#A99B87"); stamp.RotationDegrees = earned ? -7 : 0;
        Text(stamp, "Title", title, new(10, 27, 92, 40), title == "Perfect" ? 22 : 29, true).AddThemeColorOverride("font_color", stamp.Ink);
        Text(stamp, "Threshold", subtitle, new(7, 69, 98, 24), 17, true).AddThemeColorOverride("font_color", stamp.Ink);
    }
}
