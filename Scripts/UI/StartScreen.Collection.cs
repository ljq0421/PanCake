using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
namespace ProjectCake.UI;

public partial class StartScreen
{
    private string _selectedBreakfast = "pancake", _collectionCity = "";
    private Control _collectionContent = null!, _collectionDetail = null!;
    private const float CollectionContentScale = 1400f / 1860f;

    private CollectionDecoration CollectionPaper(Control parent, Rect2 rect, string kind = "paper", bool selected = false)
    {
        var paper = new CollectionDecoration { Position = rect.Position, Size = rect.Size, Kind = kind, Selected = selected };
        parent.AddChild(paper); return paper;
    }
    private void CollectionFood(Control parent, BreakfastCard card, Rect2 rect)
    {
        if (card.Id == "doupi") rect = new(rect.Position + rect.Size * .095f, rect.Size * .81f);
        if (card.Id == "soy_milk") rect = new(rect.Position - rect.Size * .1f, rect.Size * 1.2f);
        parent.AddChild(new BookFoodIcon { Position = rect.Position, Size = rect.Size, CropTransparentMargins = true, Product = new(card.Id, card.Name, 1, card.Visual) });
    }

    private bool CollectionBreakfastUnlocked(BreakfastCard card)
    {
        if (!_save!.Data.UnlockedCityIds.Contains(card.CityId)) return false;
        int day = _save.Data.Cities.TryGetValue(card.CityId, out var progress) ? progress.HighestUnlockedDay : 1;
        var kind = card.Id switch
        {
            "pancake" => ProductKind.Pancake, "youtiao" => ProductKind.Youtiao,
            "soy_milk" => ProductKind.SoyMilk, "noodles" => ProductKind.HotDryNoodles,
            "doupi" => ProductKind.Doupi, _ => (ProductKind?)null,
        };
        return kind.HasValue && GetNode<DataCatalog>("/root/DataCatalog").TryGetDay(card.CityId, day, out var config)
            && config.AvailableProductKinds.Contains(kind.Value);
    }

    public void PresentBreakfastCollection()
    {
        if (_save is null) return;
        if (Page == JourneyPage.Home && !_collectionOverWorkbench) { _showCustomerCollection = false; OpenHomeOverlay(); }
        Begin(JourneyPage.Collection);
        var book = HomeArt(_body, "旅行手账双页母版", BookBounds); book.Name = "CollectionBook";
        _collectionContent = new Control
        {
            Name = "CollectionContent",
            Size = new(1920, 1080),
            Position = BookBounds.Position - new Vector2(30, 4) * CollectionContentScale,
            Scale = Vector2.One * CollectionContentScale,
            MouseFilter = MouseFilterEnum.Stop,
        };
        _body.AddChild(_collectionContent);
        Text(_collectionContent, "CollectionTitle", "旅途收藏", new(143, 104, 390, 86), 62);
        CollectionSectionTabs();
        if (_showCustomerCollection) { RenderCustomerCollection(); return; }
        bool wuhan = _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan);
        if (_collectionCity == StableIds.Cities.Wuhan && !wuhan) _collectionCity = "";
        var available = DemoBreakfastCollection.Cards.Where(c => c.CityId == StableIds.Cities.Tianjin || wuhan).ToArray();
        var shown = available.Where(c => _collectionCity.Length == 0 || c.CityId == _collectionCity).ToArray();
        var unlocked = shown.Where(CollectionBreakfastUnlocked).ToArray();
        var selected = unlocked.FirstOrDefault(c => c.Id == _selectedBreakfast) ?? unlocked.FirstOrDefault();
        _selectedBreakfast = selected?.Id ?? "";
        var tabs = new[] { ("", "全部"), (StableIds.Cities.Tianjin, "天津"), (StableIds.Cities.Wuhan, "武汉"),
            (StableIds.Cities.Xian, ""), (StableIds.Cities.Guangzhou, ""), (StableIds.Cities.Yangzhou, "") };
        for (int i = 0; i < tabs.Length; i++)
        {
            var (id, caption) = tabs[i]; bool locked = i >= 3 || i == 2 && !wuhan;
            var tab = Button(_collectionContent, "CollectionCity" + i, "", new(130 + i * 126, 272, 116, 52),
                () => { _collectionCity = id; PresentBreakfastCollection(); Focus("CollectionCity" + Array.FindIndex(tabs, t => t.Item1 == id)); }, bare: true);
            var paper = CollectionPaper(tab, new(0, 0, 116, 52), selected: id == _collectionCity);
            paper.Fill = id == _collectionCity ? new("#FFE0A0") : new("#EBDEC7");
            if (caption.Length > 0) Text(tab, "City", caption, new(6, 5, locked ? 70 : 104, 42), 24, true);
            tab.Disabled = locked;
            if (locked) { var mark = CollectionPaper(tab, new(caption.Length == 0 ? 48 : 76, 16, 30, 30), "lock"); mark.Scale = new(.65f, .65f); }
        }

        int index = 0;
        foreach (var card in shown)
        {
            var rect = new Rect2(130 + index % 4 * 190, 347 + index / 4 * 236, 174, 218); index++;
            if (!unlocked.Contains(card))
            {
                var lockedFood = CollectionPaper(_collectionContent, rect, "postage");
                lockedFood.Name = "LockedBreakfast_" + card.Id; lockedFood.Fill = new("#EDE5D8");
                CollectionPaper(lockedFood, new(52, 76, 70, 65), "lock").Ink = new("#998875");
                continue;
            }
            bool owned = _save.BreakfastRecordDay(card.Id).HasValue;
            var button = Button(_collectionContent, "Breakfast_" + card.Id, "", rect,
                () => { _selectedBreakfast = card.Id; PresentBreakfastCollection(); }, bare: true);
            CollectionPaper(button, new(Vector2.Zero, rect.Size), "postage", card.Id == selected?.Id);
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
                var paper = CollectionPaper(_collectionContent, rect, "postage"); paper.Fill = new("#EDE5D8");
                bool namedCity = city.Id == StableIds.Cities.Wuhan;
                CollectionPaper(paper, new(52, namedCity ? 43 : 76, 70, 65), "lock").Ink = new("#998875");
                if (namedCity)
                {
                    Text(paper, "LockedCity", city.Name, new(12, 138, 150, 37), 27, true);
                    Text(paper, "LockedCaption", "待解锁", new(12, 179, 150, 27), 21, true);
                }
            }
        }
        Text(_collectionContent, "NextCityHint", wuhan ? "美食无国界\n下一站，会遇见怎样的美味呢？" : "下一站武汉，还有新的早餐等你记录。",
            new(267, 839, 600, 76), 25);
        Art(_collectionContent, "闭合旅行手账封面｜新旅程入口", new(133, 824, 115, 100));
        if (selected is not null) RenderCollectionDetail(selected);
        Focus(selected is not null ? "Breakfast_" + selected.Id : "Back");
    }

    private void RenderCollectionDetail(BreakfastCard card)
    {
        // Inset the detail panels from the painted page and its curved lower edge.
        _collectionDetail = new Control
        {
            Name = "CollectionDetail", Position = new(1032, 110), Size = new(747, 837),
            Scale = Vector2.One * .94f, MouseFilter = MouseFilterEnum.Ignore,
        };
        _collectionContent.AddChild(_collectionDetail);
        var city = JourneyModel.City(card.CityId);
        int? day = _save!.BreakfastRecordDay(card.Id);
        var stats = _save.BreakfastStatsFor(card.Id);
        CollectionPaper(_collectionDetail, new(6, 0, 470, 86));
        Text(_collectionDetail, "BreakfastName", card.Name, new(28, 7, 428, 67), 49);
        Text(_collectionDetail, "BreakfastCity", city.Name, new(499, 18, 130, 50), 32, true);
        Art(_collectionDetail, JourneyModel.Stamp(city), new(633, 2, 118, 118));
        var photo = CollectionPaper(_collectionDetail, new(11, 135, 322, 312), "photo"); photo.RotationDegrees = -3;
        CollectionFood(photo, card, new(23, 23, 276, 225));
        Text(photo, "PhotoCaption", city.Name + " · 早餐记忆", new(15, 258, 290, 35), 25, true);
        var note = CollectionPaper(_collectionDetail, new(363, 134, 376, 311)); note.RotationDegrees = 1;
        Text(note, "NoteTitle", "旅途手记", new(23, 18, 325, 48), 31);
        Text(note, "BreakfastDescription", card.Description, new(23, 87, 325, 100), 26);
        Text(note, "NoteFooter", day.HasValue ? "这份清晨的味道，\n已经留在旅行手账里。" : "把清晨的第一份美味，\n留给下一段旅程。", new(23, 198, 325, 82), 23);

        CollectionPaper(_collectionDetail, new(0, 471, 747, 165));
        Text(_collectionDetail, "StepsHeading", "制作流程", new(24, 474, 690, 38), 28);
        string[] steps = card.Steps.Split(" → ");
        float stepWidth = 711f / steps.Length;
        for (int i = 0; i < steps.Length; i++)
        {
            float x = 18 + stepWidth * i;
            var art = CollectionStepArt(card.Id, i);
            if (art is null) CollectionFood(_collectionDetail, card, new(x + 27, 515, stepWidth - 60, 60));
            else Art(_collectionDetail, "res://resource/art/" + art + ".png", new(x + 23, 515, stepWidth - 52, 60));
            Text(_collectionDetail, "Step" + i, steps[i], new(x + 5, 579, stepWidth - 18, 45), 21, true);
            if (i + 1 < steps.Length) Text(_collectionDetail, "StepArrow" + i, "→", new(x + stepWidth - 18, 544, 28, 40), 25, true);
        }
        CollectionPaper(_collectionDetail, new(0, 663, 347, 174));
        Text(_collectionDetail, "RecordTitle", "我的记录", new(21, 672, 303, 39), 29);
        Text(_collectionDetail, "BreakfastOrigin", day.HasValue ? $"首次记录 · {city.Name} · 第 {day.Value} 天"
            : "正确送出合格早餐，收摊保存后入册。", new(21, 718, 303, 42), 21);
        Text(_collectionDetail, "BreakfastDelivered", $"{Tr("制作次数")}：{stats.Delivered}", new(21, 765, 303, 27), 23);
        if (card.Id != "soy_milk") Text(_collectionDetail, "BreakfastPerfect", $"{Tr("Perfect 次数")}：{stats.Perfect}", new(21, 800, 303, 27), 23);
        CollectionPaper(_collectionDetail, new(367, 663, 380, 174));
        Text(_collectionDetail, "StampsTitle", "收集印章", new(387, 672, 340, 39), 29);
        CollectionStamp("FirstStamp", "初遇", day.HasValue ? $"第 {day.Value} 天" : "首次入册", new(381, 714), day.HasValue, new("#D6533C"));
        CollectionStamp("SkilledStamp", "熟练", "累计20份", new(499, 714), stats.Skilled, new("#B57716"));
        if (card.Id != "soy_milk") CollectionStamp("PerfectStamp", "Perfect", "完美10份", new(617, 714), stats.PerfectStamp, new("#8C6743"));
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
        var stamp = CollectionPaper(_collectionDetail, new(position, new(112, 112)), "stamp");
        stamp.Name = name; stamp.Ink = earned ? color : new("#A99B87"); stamp.RotationDegrees = earned ? -7 : 0;
        Text(stamp, "Title", title, new(10, 27, 92, 40), title == "Perfect" ? 22 : 29, true).AddThemeColorOverride("font_color", stamp.Ink);
        Text(stamp, "Threshold", subtitle, new(7, 69, 98, 24), 17, true).AddThemeColorOverride("font_color", stamp.Ink);
    }
}
