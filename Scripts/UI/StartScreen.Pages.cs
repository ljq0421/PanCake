using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private void RenderHome()
    {
        if (_homeOverlayOpen) CloseModal();
        _homeBookPalette = true;
        // Home composition: breakfast-shop wall, overlapping left logo and four tabletop actions.
        // Art is user supplied; layout and live progress remain independent of the textures.
        Begin(JourneyPage.Home); Ambient();
        // Render only the wall decoration into a soft-focus layer: the original shop,
        // foreground logo and buttons stay sharp and independently composited.
        var mapViewport = new SubViewport
        {
            Name = "HomeMapViewport", Size = new(1080, 640), TransparentBg = true,
            Disable3D = true, GuiDisableInput = true,
            RenderTargetUpdateMode = SubViewport.UpdateMode.Always
        };
        _body.AddChild(mapViewport);
        var mapLayer = new Control { MouseFilter = MouseFilterEnum.Ignore };
        mapViewport.AddChild(mapLayer);
        HomeArt(mapLayer, "世界地图墙挂底板", new(0, 0, 1080, 640), stretch: true);
        var wall = new Control { Name = "HomeMap", Position = new(45, 105), Size = new(990, 470), MouseFilter = MouseFilterEnum.Ignore }; mapLayer.AddChild(wall);
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
        var mapArt = new TextureRect
        {
            Name = "HomeMapDecoration", Texture = mapViewport.GetTexture(),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            Position = new(730, 190), Size = new(864, 512),
            StretchMode = TextureRect.StretchModeEnum.Scale,
            TextureFilter = CanvasItem.TextureFilterEnum.Linear,
            MouseFilter = MouseFilterEnum.Ignore, Material = HomeMapSoftFocus()
        };
        _body.AddChild(mapArt);
        // Ambient() creates the swinging sign before this composited map. Keep the
        // sign in front of the map while leaving the logo and action controls above it.
        var hangingSign = _body.GetNodeOrNull<TextureRect>("HomeHangingSign");
        if (hangingSign is not null) _body.MoveChild(hangingSign, mapArt.GetIndex() + 1);
        var logo = HomeArt(_body, HomeLogoArt, new(80, 150, 1120, 516));
        logo.Name = "HomeLogo";
        logo.AddChild(new HomeLogoMotion { Screen = this, Logo = logo });
        if (_save?.DemoMigrationRetryAvailable == true)
            Button(_body, "RetryDemoMigration", "重试读取存档", new(810, 790, 300, 42), () =>
            {
                _save.Load(); RenderHome();
                if (_save.HasLoadError) ShowError("旧试玩存档升级失败，请检查写入权限后重试。原存档已保留。");
            }, bare: true);
        var card = HomeAction("Continue", "继续旅程", "小火车", new(400, 835, 500, 150), RenderContinue);
        card.Disabled = !canContinue; card.Modulate = new Color(1, 1, 1, canContinue ? 1 : .68f);
        HomeAction("NewGame", "新的旅程", "首页新旅程图标-粗描边-v2", new(940, 835, 500, 150), () => RequestNewGame());
        HomeAction("BreakfastRecords", "旅途收藏", "首页旅途收藏图标-粗描边-v2", new(1475, 855, 170, 145), PresentBreakfastCollection, small: true);
        HomeAction("WorldMap", "世界地图", "首页世界地图图标-粗描边-v2", new(1655, 855, 170, 145), () => PresentMap(), small: true);
        Utilities(); Focus(canContinue ? "Continue" : "NewGame");
        HomeEntrance();
        _status.MoveToFront();
    }
    private void RequestNewGame(int? requestedSlot = null, bool showCity = false)
    {
        if (_save is null || _busy) return;
        int? slot = requestedSlot ?? _save.GetSlots().FirstOrDefault(s => !s.Exists)?.Id;
        if (slot is null)
        {
            ShowError("五个槽位已满，无法新建旅程。请前往设置页面选择或删除存档。");
            return;
        }
        CloseModal(); _busy = true;
        if (showCity) NewGameCityRequested?.Invoke(slot.Value);
        else NewGameRequested?.Invoke(slot.Value);
    }
    private void OpenMapCity(string cityId)
    {
        if (_save is null || _busy) return;
        if (!_save.CanContinue)
        {
            if (cityId == StableIds.Cities.Tianjin) RequestNewGame(showCity: true);
            return;
        }
        if (_save.ChapterLength(cityId) <= 0) return;
        PresentCity(cityId, returnToSource: RenderMap, fromHome: true);
    }
    private void RenderContinue()
    {
        if (_save?.CanContinue != true) return;
        _busy = true; ContinueRequested?.Invoke();
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
    public void OpenCard(string cityId)
    {
        if (_save?.IsDemo == true && _save.ChapterLength(cityId) == 0) return;
        if (_save is null || (!DeveloperToolsVisible && !_save.Data.UnlockedCityIds.Contains(cityId))) return;
        PresentCity(cityId, RenderMap, fromHome: _homeBookPalette);
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
        Button(_body, "Skip", "继续旅程", new(1440, 920, 300, 65), FinishCompletion);
        AddCompletionContinueButton(new(1020, 920, 380, 65));
        if (_completionContinueBusiness is null) Schedule(2, FinishCompletion);
        Focus(_completionContinueBusiness is null ? "Skip" : "ContinueCompletedCity");
    }
    private void FinishCompletion()
    {
        if (_completedCity is null) return;
        _completionContinueBusiness = null;
        if (_save?.IsDemo == true && _completedCity == StableIds.Cities.Tianjin)
        { _completedCity = null; PresentWuhanOpening(); return; }
        var next = JourneyModel.Next(_completedCity); _completedCity = null;
        if (next is not null && _save!.Data.UnlockedCityIds.Contains(next.Id)) { PresentCity(next.Id, RenderMap); } else RenderMap();
    }
}
