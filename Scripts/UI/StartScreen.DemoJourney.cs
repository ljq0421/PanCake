using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
namespace ProjectCake.UI;

public partial class StartScreen
{
    private void ReturnFromBreakfastCollection()
    {
        RenderHome(); Focus("BreakfastRecords");
    }
    private void PresentDemoWuhanOpening()
    {
        Begin(JourneyPage.Opening); Chrome(() => PresentCity(StableIds.Cities.Wuhan), showBack: false); BookFrame(StableIds.Cities.Wuhan);
        CityPicture(_body, JourneyModel.City(StableIds.Cities.Wuhan), new(335, 340, 550, 360));
        Text(_body, "WuhanOpeningTitle", "江城过早", new(1030, 300, 470, 80), 46, true);
        Text(_body, "WuhanOpeningText", "热干面拌开芝麻酱的香气，三鲜豆皮在锅里慢慢定型。\n\n先从一碗热干面开始，再添一份豆皮。\n天津的早餐铺随时等你回访。", new(1030, 420, 470, 300), 28);
        var depart = Button(_body, "WuhanOpeningContinue", "开始武汉之旅", new(1050, 817, 460, 74), () => PresentCity(StableIds.Cities.Wuhan), bare: true);
        var plate = Texture("res://resource/art/Wuhan/武汉解锁按钮底板-v1.png");
        float plateScale = depart.Size.Y / plate.GetHeight();
        depart.AddChild(new NinePatchRect
        {
            Name = "WuhanOpeningButtonPlate", Texture = plate, Size = depart.Size / plateScale, Scale = Vector2.One * plateScale,
            PatchMarginLeft = plate.GetHeight() / 2, PatchMarginRight = plate.GetHeight() / 2,
            MouseFilter = MouseFilterEnum.Ignore, ShowBehindParent = true
        });
        depart.AddThemeFontSizeOverride("font_size", 32);
        depart.AddThemeColorOverride("font_color", WuhanUi.Ink);
        depart.AddThemeColorOverride("font_hover_color", WuhanUi.Ink);
        depart.AddThemeColorOverride("font_pressed_color", WuhanUi.Ink);
        depart.AddThemeColorOverride("font_focus_color", WuhanUi.Ink);
        depart.AddThemeColorOverride("font_outline_color", WuhanUi.Paper);
        depart.AddThemeConstantOverride("outline_size", 4);
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
            Text(_body, "EndingRecord" + y, $"完成 {p.DayBestRecords.Count} 天 · 最佳收入合计 {p.DayBestRecords.Values.Sum(r => r.TotalRevenue)} 金币",
                new(485, y + 55, 390, 90), 23);
            y += 190;
        }
        Text(_body, "EndingCollection", $"早餐记录 {_save!.Data.BreakfastRecords.Count} / 5", new(350, 778, 510, 55), 30);
        var xian = JourneyModel.City(StableIds.Cities.Xian);
        CityPicture(_body, xian, new(1015, 367, 510, 282));
        Text(_body, "XianPreview", "下一站预告 · 西安", new(1020, 680, 500, 55), 34, true);
        Text(_body, "XianBreakfast", "肉夹馍与肉丸胡辣汤，留待下一段旅程。", new(1020, 751, 500, 80), 24, true);
        Button(_body, "ReplayTianjin", "回访天津", new(345, 882, 245, 65), () => PresentCity(StableIds.Cities.Tianjin));
        Button(_body, "ReplayWuhan", "回访武汉", new(615, 882, 245, 65), () => PresentCity(StableIds.Cities.Wuhan));
        Button(_body, "EndingJournal", "翻开旅行手账", new(1040, 882, 470, 65), PresentBreakfastCollection, true);
        Focus("EndingJournal");
        AddCompletionContinueButton(new(1040, 963, 470, 65));
    }
}
