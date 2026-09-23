using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
namespace ProjectCake.UI;

public partial class StartScreen
{
    private void ReturnFromBreakfastCollection()
    {
        if (_collectionOverWorkbench)
        {
            var returnToSource = _collectionOverWorkbenchReturn;
            _collectionOverWorkbench = false;
            _collectionOverWorkbenchReturn = null;
            ZIndex = _collectionOverlayZIndex;
            Hide();
            returnToSource?.Invoke();
            return;
        }
        RenderHome(); Focus("BreakfastRecords");
    }
    public void PresentWuhanOpening(bool animate = true)
    {
        _city = StableIds.Cities.Wuhan; _homeBookPalette = true;
        Show();
        Begin(JourneyPage.Opening, animate); Chrome(() => PresentCity(StableIds.Cities.Wuhan), showBack: false); BookFrame(StableIds.Cities.Wuhan);
        var city = JourneyModel.City(StableIds.Cities.Wuhan);
        Text(_body, "WuhanOpeningTitle", "江城过早", new(350, 277, 530, 75), 44, true);
        var postcard = HomeArt(_body, "武汉旅行明信片", new(335, 370, 550, 350));
        postcard.Name = "WuhanJourneyPostcard";
        HomeArt(_body, "定位符", new(535, 708, 23, 31)).Name = "WuhanPostcardMarker";
        Text(_body, "WuhanPostcardCity", "武汉", new(570, 700, 150, 44), 26);
        var skyline = HomeArt(_body, "早餐地图-武汉", new(580, 758, 295, 80));
        skyline.Name = "WuhanSkyline";
        // Match the Tianjin page's quiet ink print while retaining Wuhan's green palette.
        skyline.Material = new ShaderMaterial { Shader = new Shader { Code = """
            shader_type canvas_item;
            varying vec4 tint;
            void vertex() { tint = COLOR; }
            void fragment() {
                vec4 source = texture(TEXTURE, UV);
                float lightness = dot(source.rgb, vec3(0.299, 0.587, 0.114));
                float ink = mix(0.08, 0.55, clamp((1.0 - lightness) * 2.5, 0.0, 1.0));
                COLOR = vec4(vec3(0.31, 0.46, 0.39), pow(source.a, 3.0) * ink) * tint;
            }
            """ } };
        Text(_body, "WuhanBreakfastHeading", "先从一碗热干面开始", new(1010, 280, 530, 62), 32, true);
        for (int i = 0; i < city.Foods.Length; i++)
        {
            var food = city.Foods[i];
            _body.AddChild(new BookFoodIcon { Name = "WuhanBreakfastFood" + i,
                Position = i == 0 ? new(1025, 389) : new(1030, 632),
                Size = i == 0 ? new(172, 167) : new(118, 112),
                CropTransparentMargins = true, Product = new(food.Visual, food.Name, 1, food.Visual) });
            Text(_body, "WuhanBreakfastName" + i, food.Name,
                i == 0 ? new(1220, 409, 278, 44) : new(1180, 628, 330, 44), i == 0 ? 32 : 28);
            var story = Text(_body, "WuhanBreakfastStory" + i,
                i == 0 ? "热干面拌开芝麻酱的香气。" : "三鲜豆皮在锅里慢慢定型。",
                i == 0 ? new(1220, 463, 278, 99) : new(1180, 680, 330, 65), 22);
            story.VerticalAlignment = VerticalAlignment.Top;
        }
        Text(_body, "WuhanBreakfastAvailability", "首日经营", new(1220, 367, 150, 30), 19)
            .AddThemeColorOverride("font_color", new Color("#896345"));
        Text(_body, "WuhanBreakfastPreviewHeading", "后续早餐预览", new(1140, 584, 270, 30), 20, true)
            .AddThemeColorOverride("font_color", new Color("#896345"));
        Text(_body, "WuhanReturnHint", "天津的早餐铺随时等你回访。", new(1010, 751, 530, 36), 23, true);
        var depart = Button(_body, "WuhanOpeningContinue", "开始武汉之旅", new(1050, 798, 460, 65), () =>
        {
            // The introduction is the departure action: both editions open Wuhan Day 1 directly.
            // StartCityBusiness records the visit only after it has validated and initialized the shift.
            RequestBusiness(1);
        }, bare: true);
        var plate = HomeArt(depart, "首页地图按钮底板", new(Vector2.Zero, depart.Size), stretch: true);
        plate.Name = "WuhanOpeningButtonPlate";
        plate.ShowBehindParent = true;
        depart.AddThemeFontSizeOverride("font_size", 32);
        DecorateDemoIntroduction(true);
        FitWuhanIntroduction();
        Focus("WuhanOpeningContinue");
    }
    private void FitWuhanIntroduction()
    {
        if (_body.GetNodeOrNull<Label>("WuhanOpeningTitle") is null) return;
        foreach (var (name, size) in new[] { ("WuhanOpeningTitle", 44), ("WuhanBreakfastHeading", 32),
            ("WuhanBreakfastName0", 32), ("WuhanBreakfastName1", 28) })
            FitTextWidth(_body.GetNode<Label>(name), size, 18);
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
