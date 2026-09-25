using Godot;
using ProjectCake.Data;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private static readonly string[] TianjinBreakfastStories =
    {
        "绿豆面摊成薄饼，鸡蛋、酱料和馃篦儿层层叠起，是天津街头最熟悉的晨间味道。",
        "面坯下锅，炸得金黄酥脆；配豆浆或夹进煎饼，都是老早的滋味。",
        "黄豆磨浆煮熟，豆香醇厚；配油条或煎饼，是温热的家常味。"
    };

    private void RenderTianjinIntroduction(bool opening = false)
    {
        Begin(opening ? JourneyPage.NewJourneyMap : JourneyPage.NewJourney, animate: !opening);
        if (!opening) NavigationUtilities(includeHome: true);
        AddNewJourneyBackdropShade();
        BookFrame();
        var city = JourneyModel.City(StableIds.Cities.Tianjin);
        var station = Text(_body, "StationTitle", "第一站 · 天津", new(350, 277, 530, 75), 48, true);
        FitTextWidth(station, 48, 30);
        var postcard = HomeArt(_body, "天津旅行明信片", new(335, 400, 550, 350));
        postcard.Name = "JourneyPostcard";
        HomeArt(postcard, "定位符", new(383, 268, 19, 25));
        Text(postcard, "PostcardCity", "天津", new(406, 258, 88, 44), 25, true);
        var skyline = HomeArt(_body, "早餐地图-天津", new(580, 727, 295, 112));
        skyline.Name = "TianjinSkyline";
        // Reuse the original art; suppress its glow into a quiet ink print on the paper.
        skyline.Material = new ShaderMaterial { Shader = new Shader { Code = """
            shader_type canvas_item;
            varying vec4 tint;
            void vertex() { tint = COLOR; }
            void fragment() {
                vec4 source = texture(TEXTURE, UV);
                float lightness = dot(source.rgb, vec3(0.299, 0.587, 0.114));
                float ink = mix(0.08, 0.55, clamp((1.0 - lightness) * 2.5, 0.0, 1.0));
                COLOR = vec4(vec3(0.64, 0.40, 0.20), pow(source.a, 3.0) * ink) * tint;
            }
            """ } };
        var heading = Text(_body, "BreakfastHeading", "从街坊的一份早餐开始", new(1010, 280, 530, 62), 34, true);
        FitTextWidth(heading, 34, 24);
        GetNode<DataCatalog>("/root/DataCatalog").TryGetDay(city.Id, 1, out var firstDay);
        for (int i = 0; i < city.Foods.Length; i++)
        {
            var food = city.Foods[i];
            bool featured = i == 0;
            float x = i == 1 ? 1010 : 1285;
            // Keep a 15px gap after the 118px illustration in each secondary entry.
            float textX = x + 7 + 118 + 15;
            var icon = new BookFoodIcon { Name = "BreakfastFood" + i,
                Position = featured ? new(1025, 389) : new(x + 7, 629),
                Size = featured ? new(172, 167) : new(118, 112),
                CropTransparentMargins = true, Product = new(food.Visual, food.Name, 1, food.Visual) };
            bool available = firstDay?.AvailableProductKinds.Contains(Enum.Parse<ProductKind>(food.Visual)) == true;
            icon.Modulate = available ? Colors.White : new Color(1, .97f, .91f);
            _body.AddChild(icon);
            Text(_body, "BreakfastName" + i, food.Name,
                featured ? new(1220, 400, 278, 47) : new(textX, 621, 156, 39), featured ? 34 : 27);
            var story = Text(_body, "BreakfastStory" + i, TianjinBreakfastStories[i],
                featured ? new(1220, 456, 278, 109) : new(textX, 666, 150, 96), featured ? 22 : 18);
            story.VerticalAlignment = VerticalAlignment.Top;
        }
        var depart = Button(_body, "Depart", "出发！", new(1065, 794, 420, 65), DepartFirstStation, bare: true);
        var plate = HomeArt(depart, "首页地图按钮底板", new(Vector2.Zero, depart.Size), stretch: true);
        plate.ShowBehindParent = true;
        depart.AddThemeFontSizeOverride("font_size", 32);
        DecorateJourneyIntroduction(false);
        // Keep the shifted soy-milk brushwork beneath the neighboring youtiao copy.
        _body.MoveChild(_body.GetNode("BreakfastFood2Backing"), _body.GetNode("BreakfastFood0").GetIndex());
        FitJourneyIntroduction();
        if (!opening) { JourneyStage = FirstJourneyStage.Ready; Focus("Depart"); }
    }

    /// <summary>Keeps the first-station book in focus without muting its paper artwork or navigation.</summary>
    private void AddNewJourneyBackdropShade()
    {
        var shade = new ColorRect
        {
            Name = "NewJourneyBackdropShade",
            Position = Vector2.Zero,
            Size = new Vector2(1920, 1080),
            Color = new(.16f, .09f, .04f, .46f),
            MouseFilter = Control.MouseFilterEnum.Ignore
        };
        _body.AddChild(shade);
        _body.MoveChild(shade, 0);
    }

    private void FitJourneyIntroduction()
    {
        if (_body.GetNodeOrNull<Label>("BreakfastStory0") is null) return;
        for (int i = 0; i < 3; i++)
        {
            _body.GetNode<Label>("BreakfastStory" + i).AddThemeFontSizeOverride("font_size", _settings.Language == "en" ? 18 : i == 0 ? 22 : 18);
            FitTextWidth(_body.GetNode<Label>("BreakfastName" + i), i == 0 ? 34 : 27, 18);
        }
        FitTextWidth(_body.GetNode<Label>("JourneyPostcard/PostcardCity"), 25, 18);
        FitTextWidth(_body.GetNode<Label>("BreakfastHeading"), 34, 24);
        FitTextWidth(_body.GetNode<Label>("StationTitle"), 48, 30);
    }

    private void DepartFirstStation()
    {
        if (_journeyInputPending || JourneyStage != FirstJourneyStage.Ready) return;
        if (_save?.CanContinue != true) { ShowError("存档无法继续，请检查存档状态。"); return; }
        SelectedDay = 1;
        _busy = true;
        JourneyStage = FirstJourneyStage.Departing;
        OpeningSound(OpeningCue.Click);
        FirstStationDepartureRequested?.Invoke();
        if (!_busy) JourneyStage = FirstJourneyStage.Ready;
    }
}
