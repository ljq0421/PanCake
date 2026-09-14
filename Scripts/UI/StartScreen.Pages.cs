using Godot;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private void RenderSplash()
    {
        Begin(JourneyPage.Splash); Ambient(); Art(_body, "LOGO", new(475, 200, 970, 470));
        Text(_body, "Tagline", "从一份早餐开始，点亮世界。", new(510, 715, 900, 70), 36, true);
        Button(_body, "Skip", "点击任意位置或按 Enter 开启旅程", new(560, 835, 800, 65), RenderHome, bare: true);
        Schedule(3, RenderHome); Focus("Skip");
    }
    private void RenderHome()
    {
        // Home composition: breakfast-shop wall, overlapping left logo and three tabletop actions.
        // Art is user supplied; layout and live progress remain independent of the textures.
        Begin(JourneyPage.Home); Ambient();
        HomeArt(_body, "世界地图墙挂底板", new(445, 100, 1080, 640), stretch: true);
        var wall = new Control { Name = "HomeMap", Position = new(490, 205), Size = new(990, 470), MouseFilter = MouseFilterEnum.Ignore }; _body.AddChild(wall);
        HomeArt(wall, "卡通世界地图母版", new(0, 0, 990, 470), stretch: true);
        // Schematic callouts around Asia; keep all five names legible when every city is unlocked.
        Vector2[] points = { new(715, 70), new(605, 205), new(475, 80), new(735, 335), new(870, 210) };
        bool canContinue = _save?.CanContinue == true;
        for (int i = 0; i < JourneyModel.Cities.Length; i++)
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
        var card = HomeAction("Continue", "继续旅程", "小火车", new(400, 835, 500, 150), RenderContinue);
        var current = JourneyModel.City(_save?.ContinueCityId ?? JourneyModel.Cities[0].Id);
        card.Disabled = !canContinue; card.Modulate = new Color(1, 1, 1, canContinue ? 1 : .68f);
        card.TooltipText = canContinue ? current.Name + " · 第 " + JourneyModel.Progress(_save!, current.Id).HighestUnlockedDay + " 天" : _save?.HasLoadError == true ? "存档无法读取" : "暂无存档";
        HomeAction("NewGame", "新的旅程", "闭合旅行手账封面｜新旅程入口", new(940, 835, 500, 150), RenderOpening);
        HomeAction("WorldMap", "世界地图", "世界地图入口图标", new(1480, 850, 310, 110), () => PresentMap(), small: true);
        Utilities(); Focus(canContinue ? "Continue" : "NewGame");
        // The wall remains an additional map entrance, after the main actions in keyboard order.
        var mapLink = Button(_body, "WallMap", "", new(490, 205, 990, 470), () => PresentMap(), bare: true);
        mapLink.TooltipText = "查看世界地图";
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
        Begin(JourneyPage.NewJourney); Chrome(RenderHome, "新的旅程");
        Art(_body, "旅行手账双页母版", new(180, 150, 1560, 800));
        JournalTab("JournalMap", "世界地图", () => PresentMap(RenderNewJourney));
        var city = JourneyModel.Cities[0];
        Text(_body, "CityTitle", "第一站 · 天津", new(350, 280, 480, 85), 49, true);
        CityPicture(_body, city, new(310, 400, 550, 360));
        Text(_body, "FoodTitle", "从街坊的一份早餐开始", new(1020, 280, 530, 68), 34);
        Foods(_body, city, new(1020, 395), 165);
        Text(_body, "NewHint", "翻开手账，选一天，准备开张。", new(1030, 640, 470, 70), 27);
        Button(_body, "Depart", "从天津出发", new(1080, 750, 410, 78), RequestNewGame, true); Focus("Depart");
    }
    private void RequestNewGame()
    {
        if (_save is null) return;
        if (!_save.RequiresNewGameConfirmation) { DispatchNewGame(); return; }
        OpenModal("confirm");
        Text(_modal, "ConfirmationTitle", "重新翻开一本旅行手账？", new(560, 345, 800, 70), 40, true);
        Text(_modal, "ConfirmationText", (_save.HasLoadError ? "现有存档无法读取。\n" : "") + "新的旅程将清空所有城市的营业进度、\n金币和设备升级。是否重新开始？", new(570, 440, 780, 150), 30, true);
        Button(_modal, "Cancel", "保留原旅程", new(615, 650, 300, 75), CloseModal);
        Button(_modal, "Confirm", "确认重新开始", new(995, 650, 300, 75), DispatchNewGame, true);
        _modalControls[0].GrabFocus();
    }
    private void DispatchNewGame() { CloseModal(); _busy = true; NewGameRequested?.Invoke(); }
    private void RenderContinue()
    {
        if (_save?.CanContinue != true) return;
        Begin(JourneyPage.Continue); Chrome(RenderHome, "旅行手账");
        Art(_body, "旅行手账双页母版", new(180, 150, 1560, 800));
        JournalTab("JournalMap", "世界地图", () => PresentMap(RenderContinue));
        var city = JourneyModel.City(_save.ContinueCityId);
        Text(_body, "CityTitle", city.Name + "早餐铺", new(350, 282, 480, 80), 49, true);
        CityPicture(_body, city, new(310, 398, 550, 310));
        Text(_body, "Progress", JourneyModel.State(_save, city), new(340, 745, 500, 65), 28, true);
        Text(_body, "ResumeTitle", "旅程进行到这里", new(1030, 285, 490, 70), 38);
        Text(_body, "Coins", "旅途积蓄    " + _save.Data.Coins + " 金币", new(1030, 390, 500, 65), 31);
        Text(_body, "Goal", JourneyModel.Goal(_save, city), new(1030, 485, 500, 110), 28);
        Button(_body, "Resume", "前往早餐铺", new(1080, 665, 410, 78), () => { _busy = true; ContinueRequested?.Invoke(); }, true);
        Button(_body, "BrowseMap", "看看世界地图", new(1100, 777, 370, 62), () => PresentMap(RenderContinue), bare: true); Focus("Resume");
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
    private void Foods(Control parent, JourneyCity city, Vector2 position, float step)
    {
        for (int i = 0; i < city.Foods.Length; i++)
        {
            var food = city.Foods[i]; var at = position + new Vector2(step * i, 0);
            if (food.Art is not null) Art(parent, food.Art, new(at, new Vector2(135, 155)));
            else parent.AddChild(new BookFoodIcon { Position = at, Size = new(135, 155), Product = new(food.Visual, food.Name, 1, food.Visual) });
            Text(parent, "Food" + i, food.Name, new(at + new Vector2(-12, 165), new Vector2(159, 58)), 26, true);
        }
    }
    private static readonly Vector2[] MapPoints = { new(1390, 300), new(1280, 478), new(1070, 355), new(1130, 670), new(1510, 572) };
    private void RenderMap()
    { Begin(JourneyPage.Map); Chrome(() => (_mapReturn ?? RenderHome)(), "世界早餐地图"); DrawMap(); Utilities(); Focus("Node" + Math.Max(0, Array.FindIndex(JourneyModel.Cities, c => c.Id == _city))); }
    private void DrawMap(bool reveal = false)
    {
        Art(_body, "世界地图墙挂底板", new(175, 125, 1570, 825));
        Art(_body, "卡通世界地图母版", new(240, 195, 1440, 690));
        Art(_body, "美洲区域装饰", new(305, 425, 170, 130)).Modulate = new Color(1, 1, 1, .4f);
        Art(_body, "欧洲区域装饰", new(785, 225, 125, 95)).Modulate = new Color(1, 1, 1, .4f);
        Art(_body, "世界地图未知早餐剪影", new(560, 650, 150, 100)).Modulate = new Color(1, 1, 1, .28f);
        Text(_body, "MapRegion", "中国旅程 · 城市路线示意", new(1015, 242, 600, 48), 26, true);
        Text(_body, "Explore", "还有更多早餐，等着与你相遇。", new(380, 775, 620, 60), 27, true);
        if (!reveal && _save is not null && JourneyModel.Cities.All(c => JourneyModel.Progress(_save, c.Id).Completed))
            Art(_body, "中国阶段完成纪念章", new(480, 365, 360, 360));
        Art(_body, "路线起点_终点小旗", new(1510, 270, 52, 62));
        for (int i = 1; i < MapPoints.Length; i++)
        {
            var from = MapPoints[i - 1] + new Vector2(75, 45); var to = MapPoints[i] + new Vector2(75, 45);
            var route = Art(_body, "手绘旅行虚线路径1", new(from, new Vector2(from.DistanceTo(to), 28))); route.Rotation = (to - from).Angle();
            route.Modulate = new Color(1, 1, 1, _save?.Data.UnlockedCityIds.Contains(JourneyModel.Cities[i].Id) == true ? .85f : .18f);
            if (reveal) { var t = CreateTween(); _tweens.Add(t); route.Scale = new(0, 1); t.TweenProperty(route, "scale:x", 1f, 1.2).SetDelay(.3); }
        }
        for (int i = 0; i < JourneyModel.Cities.Length; i++)
        {
            var city = JourneyModel.Cities[i]; bool unlocked = _save?.Data.UnlockedCityIds.Contains(city.Id) == true || i == 0;
            bool completed = _save is not null && JourneyModel.Progress(_save, city.Id).Completed; bool current = _save?.ContinueCityId == city.Id;
            var node = Button(_body, "Node" + i, "", new(MapPoints[i], new Vector2(150, 168)), () => OpenCard(city.Id), bare: true);
            var marker = Art(node, completed ? JourneyModel.Stamp(city) : unlocked ? JourneyModel.NodeArt(city) : "未解锁城市节点", new(21, 0, 108, 86));
            if (!reveal) NodeFeedback(node, city, unlocked);
            var cityName = Text(node, "Name", city.Name, new(0, 85, 150, 43), 28, true);
            var state = Text(node, "State", completed ? "已完成" : current && unlocked ? "当前旅程" : unlocked ? "可前往" : "尚未抵达", new(-15, 128, 180, 34), 21, true);
            foreach (var label in new[] { cityName, state })
            {
                label.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
                label.AddThemeConstantOverride("outline_size", 8);
            }
            node.Disabled = !unlocked && !DeveloperToolsVisible;
            node.TooltipText = !unlocked ? i == 0 ? "第一站" : $"完成{JourneyModel.Cities[i - 1].Name}章节后开放" : string.Empty;
            if (!unlocked) marker.Modulate = new Color(1, 1, 1, .5f);
            if (current && unlocked)
            {
                marker.PivotOffset = marker.Size / 2; var t = CreateTween().SetLoops(); _tweens.Add(t);
                t.TweenProperty(marker, "scale", new Vector2(1.045f, 1.045f), 1.2).SetTrans(Tween.TransitionType.Sine);
                t.TweenProperty(marker, "scale", Vector2.One, 1.2).SetTrans(Tween.TransitionType.Sine);
            }
        }
        if (DeveloperToolsVisible) Text(_body, "Developer", "开发预览：未解锁城市可查看，不写入解锁进度。", new(160, 936, 1120, 48), 24).AddThemeColorOverride("font_color", StartScreenTheme.Cream);
    }
    public void OpenCard(string cityId)
    {
        if (_save is null || (!DeveloperToolsVisible && !_save.Data.UnlockedCityIds.Contains(cityId))) return;
        _city = cityId; RenderCity();
    }
    private void RenderCity()
    {
        Begin(JourneyPage.City); var city = JourneyModel.City(_city); Chrome(RenderMap, city.Name + " · 城市明信片");
        Art(_body, "城市章节页明信片母版", new(175, 150, 1570, 810));
        CityPicture(_body, city, new(310, 340, 655, 400));
        Text(_body, "CityTitle", city.Name + "早餐铺", new(1020, 300, 520, 70), 44); Foods(_body, city, new(1020, 405), 170);
        Text(_body, "CityState", JourneyModel.State(_save!, city), new(1020, 635, 500, 55), 28);
        var p = JourneyModel.Progress(_save!, city.Id);
        for (int d = 1; d <= city.Days; d++)
        {
            bool recorded = p.DayBestRecords.ContainsKey(d);
            var mark = Text(_body, "Day" + d, recorded ? d + "·" : d.ToString(), new(1020 + (d - 1) * 33, 696, 30, 35), 20, true);
            mark.AddThemeColorOverride("font_color", recorded ? StartScreenTheme.Brick : StartScreenTheme.Muted);
        }
        Text(_body, "DayLegend", "标点日期已有营业记录", new(1240, 742, 320, 35), 20);
        Button(_body, "EnterCity", _save!.CanContinue ? "前往早餐铺" : "开始新的旅程", new(722, 805, 470, 79), () =>
        {
            if (!_save.CanContinue) { RenderOpening(); return; }
            _busy = true; CityRequested?.Invoke(city.Id, DeveloperToolsVisible);
        }, bare: true); Focus("EnterCity");
    }
    private void RenderCompletion()
    {
        Begin(JourneyPage.Completion); var city = JourneyModel.City(_completedCity!);
        Art(_body, "旅行手账双页母版", new(180, 150, 1560, 800)); CityPicture(_body, city, new(330, 390, 540, 320));
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
        var next = JourneyModel.Next(_completedCity); _completedCity = null;
        if (next is not null && _save!.Data.UnlockedCityIds.Contains(next.Id)) { _city = next.Id; RenderCity(); } else RenderMap();
    }
}
