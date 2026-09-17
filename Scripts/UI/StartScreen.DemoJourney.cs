using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
namespace ProjectCake.UI;

public partial class StartScreen
{
    private string _selectedBreakfast = "pancake";
    public void PresentBreakfastCollection()
    {
        if (_save is null) return;
        Begin(JourneyPage.Collection); Chrome(ReturnFromBreakfastCollection, "早餐旅行手账"); BookFrame();
        var available = DemoBreakfastCollection.Cards.Where(c => c.CityId == StableIds.Cities.Tianjin
            || _save.Data.UnlockedCityIds.Contains(c.CityId)).ToArray();
        var selected = available.FirstOrDefault(c => c.Id == _selectedBreakfast) ?? available[0];
        _selectedBreakfast = selected.Id;
        Text(_body, "CollectionTitle", "旅途收藏", new(335, 270, 520, 62), 40);
        for (int i = 0; i < available.Length; i++)
        {
            var card = available[i]; bool owned = _save.BreakfastRecordDay(card.Id).HasValue;
            var button = Button(_body, "Breakfast_" + card.Id, "", new(325, 350 + i * 88, 550, 76),
                () => { _selectedBreakfast = card.Id; PresentBreakfastCollection(); }, bare: true);
            var paper = new Panel { Size = button.Size, MouseFilter = MouseFilterEnum.Ignore };
            paper.AddThemeStyleboxOverride("panel", StartScreenTheme.Box(card.Id == selected.Id ? new Color("#FFE29C") : StartScreenTheme.Cream, 1));
            button.AddChild(paper);
            button.AddChild(new BookFoodIcon { Position = new(12, 7), Size = new(65, 62), Product = new(card.Id, card.Name, 1, card.Visual), MouseFilter = MouseFilterEnum.Ignore });
            var name = Text(button, "Name", card.Name, new(98, 9, 280, 52), 28);
            FitTextWidth(name, 28, 19);
            Text(button, "State", owned ? "已入册" : "待记录", new(394, 14, 140, 44), 23, true);
        }
        if (!_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan))
            Text(_body, "NextCityHint", "下一站武汉，还有新的早餐等你记录。", new(335, 800, 540, 60), 23);
        int? firstDay = _save.BreakfastRecordDay(selected.Id);
        Text(_body, "BreakfastName", selected.Name, new(1020, 262, 490, 64), 43, true);
        _body.AddChild(new BookFoodIcon { Position = new(1120, 346), Size = new(270, 190),
            Product = new(selected.Id, selected.Name, 1, selected.Visual), MouseFilter = MouseFilterEnum.Ignore });
        Text(_body, "BreakfastDescription", selected.Description, new(1025, 568, 490, 74), 25, true);
        Text(_body, "BreakfastSteps", selected.Steps, new(1025, 660, 490, 112), 24, true);
        Text(_body, "BreakfastOrigin", firstDay.HasValue ? $"首次记录 · {JourneyModel.City(selected.CityId).Name} · 第 {firstDay.Value} 天"
            : "正确送出一份火候合适的早餐，收摊保存后入册。", new(1025, 793, 490, 64), 22, true);
        Button(_body, "CollectionHome", "返回首页", new(1050, 882, 450, 65), ReturnFromBreakfastCollection, true);
        Focus("Breakfast_" + selected.Id);
    }
    private void ReturnFromBreakfastCollection()
    {
        RenderHome(); Focus("BreakfastRecords");
    }
    private void PresentDemoWuhanOpening()
    {
        Begin(JourneyPage.Opening); Chrome(() => PresentCity(StableIds.Cities.Wuhan), "下一站 · 武汉"); BookFrame(StableIds.Cities.Wuhan);
        CityPicture(_body, JourneyModel.City(StableIds.Cities.Wuhan), new(335, 340, 550, 360));
        Text(_body, "WuhanOpeningTitle", "江城过早", new(1030, 300, 470, 80), 46, true);
        Text(_body, "WuhanOpeningText", "热干面拌开芝麻酱的香气，三鲜豆皮在锅里慢慢定型。\n\n先从一碗热干面开始，再添一份豆皮。\n天津的早餐铺随时等你回访。", new(1030, 420, 470, 300), 28);
        Button(_body, "WuhanOpeningContinue", "开始武汉之旅", new(1050, 817, 460, 74), () => PresentCity(StableIds.Cities.Wuhan), true);
        Focus("WuhanOpeningContinue");
    }
    private void RenderDemoEnding()
    {
        Begin(JourneyPage.Completion); Chrome(RenderMap, "两城早餐旅行"); BookFrame(StableIds.Cities.Wuhan);
        Text(_body, "EndingTitle", "两城的清晨，写进手账", new(340, 258, 1180, 68), 46, true);
        int y = 366;
        foreach (var cityId in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            var city = JourneyModel.City(cityId); var p = _save!.Data.GetCity(cityId);
            HomeArt(_body, JourneyModel.Stamp(city), new(350, y, 110, 110));
            Text(_body, "EndingCity" + y, city.Name, new(485, y, 360, 52), 34);
            Text(_body, "EndingRecord" + y, $"完成 {_save.DemoContent!.CityStages(cityId).Count(s => _save.DemoProgress.CompletedStages.Contains(s.Id))} 局 · 最佳收入合计 {p.DayBestRecords.Values.Sum(r => r.TotalRevenue)} 金币",
                new(485, y + 55, 390, 90), 23);
            y += 190;
        }
        Text(_body, "EndingCollection", $"早餐记录 {_save!.DemoProgress.BreakfastRecords.Count} / 5", new(350, 778, 510, 55), 30);
        var xian = JourneyModel.City(StableIds.Cities.Xian);
        CityPicture(_body, xian, new(1015, 367, 510, 282));
        Text(_body, "XianPreview", "下一站预告 · 西安", new(1020, 680, 500, 55), 34, true);
        Text(_body, "XianBreakfast", "肉夹馍与肉丸胡辣汤，留待下一段旅程。", new(1020, 751, 500, 80), 24, true);
        Button(_body, "ReplayTianjin", "回访天津", new(345, 882, 245, 65), () => PresentCity(StableIds.Cities.Tianjin));
        Button(_body, "ReplayWuhan", "回访武汉", new(615, 882, 245, 65), () => PresentCity(StableIds.Cities.Wuhan));
        Button(_body, "EndingJournal", "翻开旅行手账", new(1040, 882, 470, 65), PresentBreakfastCollection, true);
        Focus("EndingJournal");
    }
}
