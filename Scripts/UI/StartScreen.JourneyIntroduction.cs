using Godot;
using ProjectCake.Data;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private static readonly string[] TianjinBreakfastStories =
    {
        "饼香裹着酥脆，热乎乎地递到手里。街坊的清晨，从摊前的一声招呼开始。",
        "金黄酥香的油条，是早餐桌上熟悉的搭档。一口脆香，伴着街坊闲聊，让早晨有了滋味。",
        "一杯温热豆浆，配着煎饼和油条慢慢喝。忙碌之前，先留一点时间给这份热乎。"
    };

    private void RenderTianjinIntroduction(bool opening = false)
    {
        Begin(opening ? JourneyPage.NewJourneyMap : JourneyPage.NewJourney, animate: !opening);
        if (!opening) NavigationUtilities(includeHome: true);
        BookFrame();
        var city = JourneyModel.City(StableIds.Cities.Tianjin);
        var station = Text(_body, "StationTitle", "第一站 · 天津", new(350, 277, 530, 75), 48, true);
        FitTextWidth(station, 48, 30);
        HomeArt(_body, "天津旅行明信片", new(335, 400, 550, 350)).Name = "JourneyPostcard";
        var heading = Text(_body, "BreakfastHeading", "从街坊的一份早餐开始", new(1010, 280, 530, 62), 34, true);
        FitTextWidth(heading, 34, 24);
        GetNode<DataCatalog>("/root/DataCatalog").TryGetDay(city.Id, 1, out var firstDay);
        for (int i = 0; i < city.Foods.Length; i++)
        {
            var food = city.Foods[i];
            float x = 1010 + i * 180;
            var icon = new BookFoodIcon { Name = "BreakfastFood" + i, Position = new(x + 28, 383), Size = new(112, 120),
                CropTransparentMargins = true, Product = new(food.Visual, food.Name, 1, food.Visual) };
            bool available = firstDay?.AvailableProductKinds.Contains(Enum.Parse<ProductKind>(food.Visual)) == true;
            icon.Modulate = available ? Colors.White : new Color(.85f, .82f, .77f, .8f);
            _body.AddChild(icon);
            var label = Text(_body, "BreakfastName" + i, food.Name, new(x, 503, 168, 42), 28, true);
            FitTextWidth(label, 28, 20);
            var availability = Text(_body, "BreakfastAvailability" + i, available ? "首日经营" : "后续早餐预览", new(x, 545, 168, 27), 18, true);
            FitTextWidth(availability, 18, 14);
            var story = Text(_body, "BreakfastStory" + i, TianjinBreakfastStories[i], new(x, 573, 168, 176), 21);
            story.VerticalAlignment = VerticalAlignment.Top;
        }
        Text(_body, "DepartureHint", "第一天，从一份热乎早餐开始。", new(1010, 754, 540, 45), 26, true);
        var depart = Button(_body, "Depart", "从天津出发", new(1065, 809, 420, 70), DepartFirstStation, bare: true);
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
            _body.GetNode<Label>("BreakfastStory" + i).AddThemeFontSizeOverride("font_size", _settings.Language == "en" ? 18 : 21);
            FitTextWidth(_body.GetNode<Label>("BreakfastName" + i), 28, 18);
            FitTextWidth(_body.GetNode<Label>("BreakfastAvailability" + i), 18, 14);
        }
        FitTextWidth(_body.GetNode<Label>("BreakfastHeading"), 34, 24);
        FitTextWidth(_body.GetNode<Label>("StationTitle"), 48, 30);
        FitTextWidth(_body.GetNode<Label>("DepartureHint"), 26, 20);
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
