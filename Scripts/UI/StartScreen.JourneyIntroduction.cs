using Godot;
using ProjectCake.Data;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private static readonly string[] TianjinBreakfastStories =
    {
        "饼香裹着酥脆，热乎乎地递到手里。街坊的清晨，从摊前的一声招呼开始。",
        "一口金黄酥脆，添一份街坊早餐的滋味。",
        "一杯温热豆香，配出清晨的热乎。"
    };

    private void RenderTianjinIntroduction(bool opening = false)
    {
        Begin(opening ? JourneyPage.NewJourneyMap : JourneyPage.NewJourney, animate: !opening);
        if (!opening) NavigationUtilities(includeHome: true);
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
        AddBreakfastPaper();
        var heading = Text(_body, "BreakfastHeading", "从街坊的一份早餐开始", new(1010, 280, 530, 62), 34, true);
        FitTextWidth(heading, 34, 24);
        GetNode<DataCatalog>("/root/DataCatalog").TryGetDay(city.Id, 1, out var firstDay);
        for (int i = 0; i < city.Foods.Length; i++)
        {
            var food = city.Foods[i];
            bool featured = i == 0;
            float x = i == 1 ? 1010 : 1280;
            var icon = new BookFoodIcon { Name = "BreakfastFood" + i,
                Position = featured ? new(1025, 389) : new(x + 7, 629),
                Size = featured ? new(172, 167) : new(82, 85),
                CropTransparentMargins = true, Product = new(food.Visual, food.Name, 1, food.Visual) };
            bool available = firstDay?.AvailableProductKinds.Contains(Enum.Parse<ProductKind>(food.Visual)) == true;
            icon.Modulate = available ? Colors.White : new Color(1, .97f, .91f);
            _body.AddChild(icon);
            Text(_body, "BreakfastName" + i, food.Name,
                featured ? new(1220, 400, 278, 47) : new(x + 102, 621, 156, 39), featured ? 34 : 27);
            if (featured)
            {
                var availability = Text(_body, "BreakfastAvailability0", available ? "首日经营" : "后续早餐预览", new(1220, 367, 150, 30), 19, true);
                availability.AddThemeColorOverride("font_color", new Color("#95552F"));
                FitTextWidth(availability, 19, 15);
            }
            var story = Text(_body, "BreakfastStory" + i, TianjinBreakfastStories[i],
                featured ? new(1220, 456, 278, 109) : new(x + 102, 666, 150, 73), featured ? 22 : 20);
            story.VerticalAlignment = VerticalAlignment.Top;
        }
        Text(_body, "BreakfastPreviewHeading", "后续早餐预览", new(1140, 584, 270, 30), 20, true)
            .AddThemeColorOverride("font_color", new Color("#896345"));
        Text(_body, "DepartureHint", "第一天，从一份热乎早餐开始。", new(1010, 751, 530, 36), 23, true);
        var depart = Button(_body, "Depart", "从天津出发", new(1065, 794, 420, 65), DepartFirstStation, bare: true);
        var plate = HomeArt(depart, "首页地图按钮底板", new(Vector2.Zero, depart.Size), stretch: true);
        plate.ShowBehindParent = true;
        depart.AddThemeFontSizeOverride("font_size", 32);
        FitJourneyIntroduction();
        if (!opening) { JourneyStage = FirstJourneyStage.Ready; Focus("Depart"); }
    }

    private void FitJourneyIntroduction()
    {
        if (_body.GetNodeOrNull<Label>("BreakfastStory0") is null) return;
        for (int i = 0; i < 3; i++)
        {
            _body.GetNode<Label>("BreakfastStory" + i).AddThemeFontSizeOverride("font_size", _settings.Language == "en" ? 18 : i == 0 ? 22 : 20);
            FitTextWidth(_body.GetNode<Label>("BreakfastName" + i), i == 0 ? 34 : 27, 18);
        }
        FitTextWidth(_body.GetNode<Label>("BreakfastAvailability0"), 19, 15);
        FitTextWidth(_body.GetNode<Label>("BreakfastPreviewHeading"), 20, 16);
        FitTextWidth(_body.GetNode<Label>("JourneyPostcard/PostcardCity"), 25, 18);
        FitTextWidth(_body.GetNode<Label>("BreakfastHeading"), 34, 24);
        FitTextWidth(_body.GetNode<Label>("StationTitle"), 48, 30);
        FitTextWidth(_body.GetNode<Label>("DepartureHint"), 23, 18);
    }

    private void AddBreakfastPaper()
    {
        var paper = new Control { Name = "BreakfastPaper", Position = new(1000, 348), Size = new(530, 222), MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(paper);
        paper.Draw += () =>
        {
            Vector2[] edge = { new(4, 8), new(163, 4), new(301, 7), new(517, 2), new(522, 80), new(518, 150),
                new(525, 211), new(357, 219), new(186, 216), new(7, 222), new(10, 135), new(2, 59) };
            paper.DrawColoredPolygon(edge, new Color("#F8E6B8"));
            paper.DrawPolyline(edge.Append(edge[0]).ToArray(), new Color("#DBBD89"), 1.2f, true);
            paper.DrawColoredPolygon(new Vector2[] { new(19, -3), new(82, -10), new(85, 12), new(22, 19) }, new Color(.86f, .66f, .38f, .42f));
            paper.DrawPolyline(new Vector2[] { new(219, 45), new(289, 46), new(365, 43) }, new Color("#C69260"), 1.5f, true);
            paper.DrawPolyline(new Vector2[] { new(135, -14), new(252, -11), new(369, -14) }, new Color("#E8B76B"), 3, true);
            for (int x = 15; x < 110; x += 19)
            {
                paper.DrawLine(new(x, 251), new(x + 9, 251), new Color("#CBB08A"), 1.5f, true);
                paper.DrawLine(new(x + 404, 251), new(x + 413, 251), new Color("#CBB08A"), 1.5f, true);
            }
        };
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
