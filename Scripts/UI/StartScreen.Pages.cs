using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private void RenderSplash()
    {
        Begin(JourneyPage.Splash); Ambient(); Art(_body, "LOGO", new(475, 200, 970, 470));
        Text(_body, "Tagline", "从一份早餐开始，点亮世界。", new(510, 715, 900, 70), 36, true);
        Button(_body, "Skip", "点击任意位置或按 Enter 开启旅程", new(560, 835, 800, 65), RenderHome, bare: true);
        Focus("Skip");
    }
    private void RenderHome()
    {
        // Home composition: breakfast-shop wall, overlapping left logo and four tabletop actions.
        // Art is user supplied; layout and live progress remain independent of the textures.
        Begin(JourneyPage.Home); Ambient();
        HomeArt(_body, "世界地图墙挂底板", new(445, 100, 1080, 640), stretch: true);
        var wall = new Control { Name = "HomeMap", Position = new(490, 205), Size = new(990, 470), MouseFilter = MouseFilterEnum.Ignore }; _body.AddChild(wall);
        HomeArt(wall, "卡通世界地图母版", new(0, 0, 990, 470), stretch: true);
        // Schematic callouts around Asia; keep all five names legible when every city is unlocked.
        Vector2[] points = { new(715, 70), new(605, 205), new(475, 80), new(735, 335), new(870, 210) };
        bool canContinue = _save?.CanContinue == true;
        for (int i = 0; i < (ExperienceProfile.IsDemo ? 3 : JourneyModel.Cities.Length); i++)
        {
            var city = JourneyModel.Cities[i];
            bool unlocked = canContinue ? _save!.Data.UnlockedCityIds.Contains(city.Id) : i == 0;
            if (!unlocked) continue;
            Vector2 at = points[i];
            var marker = new Control { Name = "HomeCity" + i, Position = at, Size = new(108, 126), MouseFilter = MouseFilterEnum.Ignore };
            wall.AddChild(marker);
            HomeArt(marker, JourneyModel.NodeArt(city), new(8, 0, 92, 92));
            HomeArt(marker, "城市名称牌底板", new(0, 86, 108, 38), stretch: true);
            Text(marker, "City" + i, city.Name, new(6, 87, 96, 34), 24, true).AddThemeColorOverride("font_color", StartScreenTheme.Cream);
            if (canContinue && JourneyModel.Progress(_save!, city.Id).Completed)
                HomeArt(marker, "已完成城市节点", new(80, -8, 30, 30));
            if (canContinue && _save!.ContinueCityId == city.Id)
            {
                var t = CreateTween().SetLoops(); _tweens.Add(t);
                t.TweenProperty(marker, "modulate:a", .78f, 1.3); t.TweenProperty(marker, "modulate:a", 1f, 1.3);
            }
        }
        HomeArt(_body, "LOGO", new(60, 60, 560, 258));
        if (ExperienceProfile.IsDemo)
            Text(_body, "DemoScope", "本次试玩包含天津 15 天、武汉 12 天，以及五份早餐收藏。", new(390, 747, 1140, 58), 27, true);
        if (_save?.DemoMigrationRetryAvailable == true)
            Button(_body, "RetryDemoMigration", "重试读取存档", new(810, 790, 300, 42), () =>
            {
                _save.Load(); RenderHome();
                if (_save.HasLoadError) ShowError("旧试玩存档升级失败，请检查写入权限后重试。原存档已保留。");
                else if (_save.DemoMigrationNotice.Length > 0) ShowError(_save.DemoMigrationNotice);
            }, bare: true);
        var card = HomeAction("Continue", "继续旅程", "小火车", new(400, 835, 500, 150), RenderContinue);
        card.Disabled = !canContinue; card.Modulate = new Color(1, 1, 1, canContinue ? 1 : .68f);
        HomeAction("NewGame", "新的旅程", "闭合旅行手账封面｜新旅程入口", new(940, 835, 500, 150), RenderOpening);
        HomeAction("BreakfastRecords", "旅途收藏", "已有旅程手账封面", new(1475, 855, 170, 145), PresentBreakfastCollection, small: true);
        HomeAction("WorldMap", "世界地图", "世界地图入口图标", new(1655, 855, 170, 145), () => PresentMap(), small: true);
        Utilities(); Focus(canContinue ? "Continue" : "NewGame");
        // The wall remains an additional map entrance, after the main actions in keyboard order.
        Button(_body, "WallMap", "", new(490, 205, 990, 470), () => PresentMap(), bare: true, hoverVisual: wall);
        _status.MoveToFront();
    }
    private void RenderOpening()
    {
        Begin(JourneyPage.Opening);
        var map = Art(_body, "卡通世界地图母版", new(160, 180, 1600, 720));
        Art(map, "第一站天津节点专属素材", new(1155, 240, 140, 130));
        map.PivotOffset = new(1230, 300);
        var t = CreateTween(); _tweens.Add(t);
        t.TweenProperty(map, "scale", new Vector2(1.65f, 1.65f), 1.8).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        Text(_body, "Destination", "第一站 · 天津", new(520, 190, 850, 100), 62, true);
        Button(_body, "Skip", "跳过演出", new(1530, 920, 230, 65), RenderNewJourney);
        Schedule(2.2, RenderNewJourney); Focus("Skip");
    }
    private void RenderNewJourney()
    {
        Begin(JourneyPage.NewJourney); Chrome(RenderHome);
        BookFrame();
        var city = JourneyModel.Cities[0];
        JourneyIntroduction(city, "第一站", RequestNewGame);
        Focus("Depart");
    }
    private void RequestNewGame()
    {
        if (_save is null) return;
        if (!_save.RequiresNewGameConfirmation) { DispatchNewGame(); return; }
        OpenModal("confirm");
        ConfirmationTitle(_modal, "ConfirmationTitle", "重新翻开一本旅行手账？");
        ConfirmationMessage(_modal, "ConfirmationText", (_save.HasLoadError ? "现有存档无法读取。\n" : "") + "新的旅程将清空所有城市的营业进度、\n金币和设备升级。是否重新开始？");
        ConfirmationAction(_modal, "Cancel", "保留原旅程", CloseModal);
        ConfirmationAction(_modal, "Confirm", "确认重新开始", DispatchNewGame, true);
        _modalControls[0].GrabFocus();
    }
    private void DispatchNewGame() { CloseModal(); _busy = true; NewGameRequested?.Invoke(); }
    private void RenderContinue()
    {
        if (_save?.CanContinue != true) return;
        ContinueRequested?.Invoke();
    }
    private void CityPicture(Control parent, JourneyCity city, Rect2 rect)
    {
        if (city.Art is not null) Art(parent, city.Art, rect);
        else
        {
            Art(parent, "世界地图小早餐铺标记", new(rect.Position + new Vector2(rect.Size.X * .24f, 0), new Vector2(rect.Size.X * .52f, rect.Size.Y * .65f)));
            Text(parent, "CityShop", city.Name + "早餐铺", new(rect.Position + new Vector2(0, rect.Size.Y * .72f), new Vector2(rect.Size.X, 65)), 38, true);
        }
    }
    private void Foods(Control parent, JourneyCity city, Vector2 position, float step, float scale = 1)
    {
        int count = city.Foods.Length;
        for (int i = 0; i < count; i++)
        {
            var food = city.Foods[i]; var at = position + new Vector2(step * i, 0);
            if (food.Art is not null) Art(parent, food.Art, new(at + new Vector2((135 - 135 * scale) / 2, 0), new Vector2(135, 155) * scale));
            else parent.AddChild(new BookFoodIcon { Position = at + new Vector2((135 - 135 * scale) / 2, 0), Size = new Vector2(135, 155) * scale, Product = new(food.Visual, food.Name, 1, food.Visual) });
            Text(parent, "Food" + i, food.Name, new(at + new Vector2(-12, 155 * scale + 8), new Vector2(159, 58)), 26, true);
        }
    }
    // Shared by the interactive map and chapter-unlock presentation.
    private static readonly Vector2[] MapPoints = { new(1450, 270), new(1310, 425), new(1090, 320), new(1130, 565), new(1500, 550) };
    private static readonly Rect2 MapArtworkBounds = new(235, 225, 1450, 535);
    private Rect2 _mapArtworkRect;
    private Vector2 MapArtworkPoint(Vector2 referencePoint) => _mapArtworkRect.Position
        + (referencePoint - MapArtworkBounds.Position) / MapArtworkBounds.Size * _mapArtworkRect.Size;
    private Vector2 MapNodePosition(int index) => MapArtworkPoint(MapPoints[index] + new Vector2(65, 40)) - new Vector2(65, 40);
    private void RenderMap()
    {
        Begin(JourneyPage.Map); Chrome(() => (_mapReturn ?? RenderHome)()); DrawMap();
        DrawMapSummary(); Focus("Node" + Math.Max(0, Array.FindIndex(JourneyModel.Cities, c => c.Id == _city)));
        _status.Position = new(340, 75); _status.Size = new(1240, 40);
        _status.AddThemeColorOverride("font_color", StartScreenTheme.Ink);
        _status.MoveToFront();
    }
    private void DrawMap(bool reveal = false)
    {
        HomeArt(_body, "世界地图墙挂底板", new(160, 125, 1600, 685)).Name = "MapFrame";
        var map = HomeArt(_body, "卡通世界地图母版", MapArtworkBounds);
        map.Name = "WorldMapArt";
        Vector2 nativeSize = map.Texture.GetSize();
        float mapScale = Math.Min(MapArtworkBounds.Size.X / nativeSize.X, MapArtworkBounds.Size.Y / nativeSize.Y);
        map.Size = nativeSize * mapScale;
        map.Position = MapArtworkBounds.GetCenter() - map.Size / 2;
        _mapArtworkRect = new(map.Position, map.Size);
        Art(_body, "美洲区域装饰", new(MapArtworkPoint(new(380, 417.5f)) - new Vector2(65, 47.5f), new Vector2(130, 95))).Modulate = new Color(1,1,1,.3f);
        Art(_body, "欧洲区域装饰", new(MapArtworkPoint(new(905, 282.5f)) - new Vector2(55, 37.5f), new Vector2(110, 75))).Modulate = new Color(1,1,1,.3f);
        Text(_body, "MapRegion", "中国旅程 · 城市路线示意", new(995, 219, 540, 40), 24, true);
        if (_save is not null && JourneyModel.Cities.All(c => JourneyModel.Progress(_save, c.Id).Completed))
            Art(_body, "中国阶段完成纪念章", new(MapArtworkPoint(new(790, 555)) - new Vector2(90, 90), new Vector2(180, 180)));
        int visibleCities = _save?.IsDemo == true ? 3 : JourneyModel.Cities.Length;
        for (int i = 1; i < visibleCities; i++)
        {
            var from = MapNodePosition(i-1) + new Vector2(65, 40); var to = MapNodePosition(i) + new Vector2(65, 40);
            var route = Art(_body, "手绘旅行虚线路径1", new(from, new Vector2(from.DistanceTo(to), 20)));
            route.Name = "MapRoute" + i;
            route.StretchMode = TextureRect.StretchModeEnum.Scale;
            route.Rotation = (to-from).Angle(); route.Modulate = new Color(1,1,1,.55f);
            if (reveal) { var t = CreateTween(); _tweens.Add(t); route.Scale = new(0,1); t.TweenProperty(route,"scale:x",1f,1.2); }
        }
        for (int i = 0; i < visibleCities; i++)
        {
            var city = JourneyModel.Cities[i]; bool unlocked = JourneyModel.MapCityUnlocked(_save, city);
            bool completed = _save is not null && JourneyModel.Progress(_save, city.Id).Completed;
            bool preview = _save?.IsDemo == true && _save.ChapterLength(city.Id) == 0;
            var node = Button(_body, "Node"+i, "", new(MapNodePosition(i), new Vector2(130,155)), () =>
            {
                _city = city.Id;
                if (!preview && (unlocked || (_save?.CanContinue == true && DeveloperToolsVisible)))
                {
                    if (_save?.CanContinue == true) OpenCard(city.Id);
                    else RenderOpening();
                }
                else RenderMap();
            }, bare:true);
            Art(node, completed ? JourneyModel.Stamp(city) : unlocked ? JourneyModel.NodeArt(city) : "未解锁城市节点", new(20,0,90,78));
            var cityLabel = Text(node,"Name",city.Name,new(0,77,130,38),26,true);
            cityLabel.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream); cityLabel.AddThemeConstantOverride("outline_size", 4);
            var stateLabel = Text(node,"State",preview ? "下一站预告" : completed ? "已完成" : !unlocked ? "尚未抵达" : city.Id == (_save?.ContinueCityId ?? JourneyModel.Cities[0].Id) ? "当前城市" : "可前往",new(-15,115,160,32),20,true);
            FitTextWidth(stateLabel, 20, 18);
            stateLabel.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream); stateLabel.AddThemeConstantOverride("outline_size", 4);
            if (city.Id == _city) { var ring = Art(node,"城市节点悬停高亮环",new(-4,-15,140,105)); ring.ShowBehindParent = true; }
        }
    }
    private void DrawMapSummary()
    {
        var view = JourneyModel.MapSummary(_save!, JourneyModel.City(_city), DeveloperToolsVisible);
        var panel = new Panel { Name = "MapJourneyStrip", Position = new(375, 825), Size = new(1170, 245), MouseFilter = MouseFilterEnum.Ignore };
        panel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty()); _body.AddChild(panel);
        HomeArt(panel, "世界早餐地图解锁", new(Vector2.Zero, panel.Size)).Name = "MapJourneyStripArt";
        MapLandmark(panel, view.City, new(197, 115, 190, 112));
        if (view.NextCity is { } destination) MapLandmark(panel, destination, new(556, 115, 190, 112));

        HomeArt(panel, JourneyModel.NodeArt(view.City), new(59, 53, 74, 91)).Name = "SelectedCityIcon";
        MapStripText(panel, "MapSelection", view.IsCurrent ? "当前城市" : "所选城市", new(149, 64, 216, 34), 26);
        MapStripText(panel, "SummaryCity", view.City.Name, new(149, 100, 216, 62), 44);
        var arrow = HomeArt(panel, "箭头", new(375, 94, 44, 44));
        arrow.Name = "MapNextArrow";
        arrow.PivotOffset = arrow.Size / 2;
        arrow.RotationDegrees = -90;
        if (view.NextCity is { } next)
            HomeArt(panel, JourneyModel.NodeArt(next), new(435, 53, 74, 91)).Name = "NextCityIcon";
        else HomeArt(panel, "小红旗", new(435, 69, 64, 64));
        MapStripText(panel, "MapNextLabel", view.IsPreview || view.NextIsPreview ? "下一站预告" : view.NextCity is null ? "最终站" : "下一站", new(525, 64, 230, 34), 26);
        MapStripText(panel, "MapNextCity", view.NextCity?.Name ?? (view.IsPreview ? "敬请期待" : view.City.Name), new(525, 100, 230, 62), 44);

        HomeArt(panel, "小红旗", new(805, 58, 43, 47));
        MapStripText(panel, "MapLitLabel", "已点亮城市", new(862, 64, 267, 34), 26);
        MapStripText(panel, "MapLitCount", $"{view.LitCities}/{view.TotalCities}", new(862, 100, 267, 62), 44);

        Art(panel, "res://resource/art/Global/BookUI/奖励章中心符号｜星星.png", new(805, 168, 25, 25)).Name = "MapGoalStar";
        var goal = Text(panel, "SummaryGoal", view.Goal, new(843, 164, 286, 64), 19);
        FitContinueLines(goal, 19, 18, 3);
    }
    private void MapLandmark(Control parent, JourneyCity city, Rect2 bounds)
    {
        if (city.Id is not (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan)) return;
        var art = HomeArt(parent, "早餐地图-" + city.Name, bounds);
        art.Name = "MapLandmark" + city.Name;
        art.Modulate = new Color(1, 1, 1, .6f);
    }
    private Label MapStripText(Control parent, string name, string value, Rect2 bounds, int size)
    {
        var label = Text(parent, name, value, bounds, size);
        label.AutowrapMode = TextServer.AutowrapMode.Off;
        FitTextWidth(label, size, 20);
        return label;
    }
    public void OpenCard(string cityId)
    {
        if (_save?.IsDemo == true && _save.ChapterLength(cityId) == 0) return;
        if (_save is null || (!DeveloperToolsVisible && !_save.Data.UnlockedCityIds.Contains(cityId))) return;
        PresentCity(cityId, RenderMap);
    }
    private void RenderCompletion()
    {
        if (ExperienceProfile.HasTwoCityEnding(_save?.IsDemo == true) && _completedCity == StableIds.Cities.Wuhan) { RenderDemoEnding(); return; }
        Begin(JourneyPage.Completion); var city = JourneyModel.City(_completedCity!);
        BookFrame(); CityPicture(_body, city, new(330, 390, 540, 320));
        Text(_body, "CompleteTitle", city.Name + "章节完成", new(380, 260, 1120, 90), 54, true);
        var stamp = Art(_body, JourneyModel.Stamp(city), new(1060, 385, 410, 340));
        stamp.PivotOffset = stamp.Size / 2; stamp.Scale = new(1.45f, 1.45f); stamp.Modulate = new(1, 1, 1, 0);
        var t = CreateTween().SetParallel(); _tweens.Add(t);
        t.TweenProperty(stamp, "scale", Vector2.One, .4).SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out); t.TweenProperty(stamp, "modulate:a", 1f, .25);
        var impact = Art(_body, "盖章完成轻冲击效果", new(990, 350, 550, 410)); t.TweenProperty(impact, "modulate:a", 0f, .6).SetDelay(.3);
        Text(_body, "CompleteCaption", "这一城的清晨，已经写进旅程。", new(435, 775, 1000, 70), 32, true);
        Button(_body, "Skip", "查看下一站", new(1420, 922, 310, 65), FinishCompletion); Schedule(2, RevealRoute); Focus("Skip");
    }
    private void RevealRoute()
    {
        Begin(JourneyPage.Completion); DrawMap(true); UnlockDecoration();
        Text(_body, "NextTitle", JourneyModel.Next(_completedCity!) is { } next ? "下一站 · " + next.Name : "五城早餐旅程，已点亮", new(320, 54, 1300, 90), 49, true).AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        foreach (var b in _buttons) b.Disabled = true;
        Button(_body, "Skip", "继续旅程", new(1440, 920, 300, 65), FinishCompletion); Schedule(2, FinishCompletion); Focus("Skip");
    }
    private void FinishCompletion()
    {
        if (_completedCity is null) return;
        if (_save?.IsDemo == true && _completedCity == StableIds.Cities.Tianjin)
        { _completedCity = null; PresentDemoWuhanOpening(); return; }
        var next = JourneyModel.Next(_completedCity); _completedCity = null;
        if (next is not null && _save!.Data.UnlockedCityIds.Contains(next.Id)) { PresentCity(next.Id, RenderMap); } else RenderMap();
    }
}
