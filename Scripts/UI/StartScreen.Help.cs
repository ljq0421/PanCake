using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class StartScreen
{
    // Preserve the authored layout while fitting it into the shared settings book.
    private static readonly Rect2 HelpLayoutBounds = new(30, 30, 1860, 1020);

    private void OpenHelp()
    {
        OpenModal("help");
        float scale = Mathf.Min(BookBounds.Size.X / HelpLayoutBounds.Size.X, BookBounds.Size.Y / HelpLayoutBounds.Size.Y);
        var content = new Control { Name = "HelpContent", Size = new(1920, 1080),
            Position = BookBounds.GetCenter() - HelpLayoutBounds.GetCenter() * scale,
            Scale = Vector2.One * scale, MouseFilter = MouseFilterEnum.Ignore };
        _modal.AddChild(content);

        HelpPanel(content, "TitleUnderline", new(286, 174, 580, 16), "#FFD16A", "#FFD16A", 8, 0);
        HelpText(content, "HelpTitle", "一本早餐旅行手册", new(274, 94, 610, 83), 57);
        HelpPanel(content, "WelcomeTape", new(462, 202, 414, 48), "#FFD2AA", "#FFD2AA", 10, 0);
        HelpText(content, "HelpWelcome", "第一次来？从这里开始", new(470, 204, 398, 42), 29, true);

        HelpJourneyCard(content, "New", "新的旅程", "从天津出发，建立新的旅行进度。", 270, "#FFF0DC", "#F3C49B",
            "新的旅程");
        HelpPanel(content, "SaveWarning", new(385, 408, 475, 45), "#FFD0C0", "#EFAE9D", 16, 2);
        var warning = HelpText(content, "HelpSaveWarning", "五段旅程独立保存，可在首页管理存档", new(398, 410, 449, 40), 27, true);
        warning.AddThemeColorOverride("font_color", new Color("#9A3326"));
        HelpJourneyCard(content, "Continue", "继续旅程", "回到上次早餐铺\n继续营业与升级", 490, "#ECF2D9", "#C6D8A0", "继续旅程");
        HelpJourneyCard(content, "Map", "世界地图", "查看已点亮城市和下一站。", 710, "#DEF1F7", "#AFDCEB", "世界地图入口图标");

        HomeArt(content, "设置图标", new(1000, 103, 80, 80));
        HelpPanel(content, "ControlsUnderline", new(1100, 177, 310, 16), "#FFD16A", "#FFD16A", 8, 0);
        HelpText(content, "HelpControlsTitle", "操作小抄", new(1100, 99, 325, 78), 59);
        var motto = HelpText(content, "HelpMotto", "慢慢来，做好每份早餐", new(1440, 116, 328, 60), 27, true);
        motto.AddThemeColorOverride("font_color", new Color("#966642"));

        HelpOperation(content, "Click", "点击", "选择 / 加料", new(1000, 250, 375, 164), "#FFEBD0", "#F2CBA0", 0);
        HelpOperation(content, "Drag", "拖动", "移动食材 / 交付", new(1395, 250, 375, 164), "#E9F1D1", "#C6DBA0", 1);
        HelpOperation(content, "Hold", "长按", "按工作台提示操作", new(1000, 432, 375, 164), "#DEF0F8", "#B2DDEC", 2);
        HelpOperation(content, "Discard", "丢弃", "已投入制作的食物", new(1395, 432, 375, 164), "#FFDFD8", "#F4BCB3", 3);
        DrawHelpCityTips(content);
        DrawHelpKeys(content);

        {
            var credits = Button(content, "MusicCredits", "配乐与署名", new(164, 919, 270, 40), OpenDemoMusicCredits, bare: true);
            credits.AddThemeFontSizeOverride("font_size", 22);
        }
        var close = Button(content, "Close", "记住了", new(800, 945, 320, 82), CloseModal, bare: true);
        var closeArt = HomeArt(close, "首页地图按钮底板", new(0, 0, 320, 82), stretch: true);
        closeArt.Name = "HelpCloseArt";
        closeArt.ShowBehindParent = true;
        close.AddThemeFontSizeOverride("font_size", 41);
        var teaching = Button(content, "ReplayInterfaceTeaching", "经营教学", new(1370, 948, 290, 68), () =>
            InterfaceTeaching.Offer(_modal, "replay", InterfaceLessons.Replay(HelpCityId()), replay: true));
        teaching.AddThemeFontSizeOverride("font_size", 29);
        if (Page == JourneyPage.City && _city is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan)
        {
            var replay = Button(content, "ReplayTutorial", "重看首份教学", new(440, 948, 330, 68), () =>
            {
                CloseModal();
                DemoTutorialRequested?.Invoke();
            });
            replay.AddThemeFontSizeOverride("font_size", 29);
        }
        close.GrabFocus();
    }

    private Panel HelpPanel(Control parent, string name, Rect2 rect, string fill, string border, int radius = 30, int line = 2)
    {
        var panel = new Panel { Name = name, Position = rect.Position, Size = rect.Size, MouseFilter = MouseFilterEnum.Ignore };
        panel.AddThemeStyleboxOverride("panel", new StyleBoxFlat
        {
            BgColor = new Color(fill), BorderColor = new Color(border),
            BorderWidthLeft = line, BorderWidthRight = line, BorderWidthTop = line, BorderWidthBottom = line,
            CornerRadiusTopLeft = radius, CornerRadiusTopRight = radius, CornerRadiusBottomLeft = radius, CornerRadiusBottomRight = radius
        });
        parent.AddChild(panel);
        return panel;
    }

    private Label HelpText(Control parent, string name, string text, Rect2 rect, int size, bool centered = false)
    {
        var label = Text(parent, name, text, rect, size, centered);
        label.SetMeta("help_text_size", rect.Size);
        // Measure the translated copy in both dimensions without shrinking other UI labels.
        void Fit()
        {
            string translated = label.Tr(label.Text).ToString();
            Font font = label.GetThemeFont("font");
            int fitted = size;
            while (fitted > 21)
            {
                Vector2 measured = font.GetMultilineStringSize(translated, label.HorizontalAlignment, rect.Size.X, fitted);
                label.AddThemeFontSizeOverride("font_size", fitted);
                label.Size = rect.Size;
                if (measured.X <= rect.Size.X && measured.Y <= rect.Size.Y && label.GetMinimumSize().Y <= rect.Size.Y) break;
                fitted--;
            }
            label.AddThemeFontSizeOverride("font_size", fitted);
            label.Size = rect.Size;
        }
        Fit();
        return label;
    }

    private void HelpJourneyCard(Control parent, string key, string title, string description, float y, string fill, string border, string art)
    {
        var card = HelpPanel(parent, "HelpJourney" + key, new(110, y, 780, 200), fill, border, 36);
        HomeArt(card, art, new(18, 10, 238, 180)).Name = "Help" + key + "Art";
        HelpText(card, "Help" + key + "Title", title, new(278, 22, 470, 64), 46);
        HelpText(card, "Help" + key + "Description", description, new(278, 86, 470, key == "New" ? 48 : 90), 31);
    }

    private void HelpOperation(Control parent, string key, string title, string description, Rect2 rect, string fill, string border, int quadrant)
    {
        var card = HelpPanel(parent, "HelpOperation" + key, rect, fill, border);
        string cacheKey = "HelpGesture" + quadrant;
        if (!_textures.TryGetValue(cacheKey, out var texture))
        {
            var source = Texture("帮助手势");
            // Four panels in the supplied 1448×1086 sheet, separated at x=724 / y=590.
            int x = quadrant % 2 * 724, y = quadrant < 2 ? 0 : 590;
            using var image = source.GetImage();
            using var region = image.GetRegion(new Rect2I(x, y, 724, quadrant < 2 ? 590 : 496));
            region.Convert(Image.Format.Rgba8);
            byte[] pixels = region.GetData();
            int width = region.GetWidth(), left = width, top = region.GetHeight(), right = -1, bottom = -1;
            for (int row = 0; row < region.GetHeight(); row++) for (int column = 0; column < width; column++)
                if (pixels[(row * width + column) * 4 + 3] >= 128)
                {
                    left = Math.Min(left, column); right = Math.Max(right, column);
                    top = Math.Min(top, row); bottom = Math.Max(bottom, row);
                }
            // Ignore faint export noise when framing; retain a small antialiased edge margin.
            left = Math.Max(0, left - 2); top = Math.Max(0, top - 2);
            right = Math.Min(width - 1, right + 2); bottom = Math.Min(region.GetHeight() - 1, bottom + 2);
            texture = new AtlasTexture { Atlas = source, Region = new Rect2(x + left, y + top, right - left + 1, bottom - top + 1), FilterClip = true };
            _textures[cacheKey] = texture;
        }
        card.AddChild(new TextureRect { Name = "Help" + key + "Art", Position = new(16, 13), Size = new(140, 138), Texture = texture,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, MouseFilter = MouseFilterEnum.Ignore });
        HelpText(card, "Help" + key + "Title", title, new(170, 25, 190, 59), 46);
        HelpText(card, "Help" + key + "Description", description, new(170, 85, 187, 68), 26);
    }

    private void DrawHelpCityTips(Control parent)
    {
        string cityId = HelpCityId();
        JourneyCity city = JourneyModel.Cities.FirstOrDefault(c => c.Id == cityId) ?? JourneyModel.Cities[0];
        var panel = HelpPanel(parent, "HelpCityTips", new(1000, 623, 770, 214), "#FFF4DD", "#D3A777", 25, 4);
        panel.SetMeta("city_id", city.Id);
        // Use the existing postcard's authored location slot, in its native 600×365 layout.
        var postcard = new Control { Name = "HelpPostcard", Position = new(12, 14), Size = new(600, 365),
            Scale = Vector2.One * .54f, MouseFilter = MouseFilterEnum.Ignore };
        panel.AddChild(postcard);
        HomeArt(postcard, city.Art is null ? "继续旅程明信片底板" : city.Art[JourneyModel.ArtRoot.Length..^4], new(0, 0, 600, 365));
        if (city.Art is null) HomeArt(postcard, "世界地图小早餐铺标记", new(65, 57, 245, 235));
        bool tianjin = city.Id == StableIds.Cities.Tianjin;
        var location = new Control { Name = "HelpPostcardLocation", Position = tianjin ? new(411, 279) : city.Art is null ? new(399, 268) : new(399, 286),
            Size = new(148, 44), MouseFilter = MouseFilterEnum.Ignore };
        postcard.AddChild(location);
        if (city.Art is not null && !tianjin)
            HomeArt(location, "存档信息小纸签", new(-10, -5, 164, 56), stretch: true);
        HomeArt(location, "定位符", new(5, 7, 25, 31)).Name = "HelpLocationIcon";
        var cityName = Text(location, "HelpCityName", city.Name, new(35, 0, 106, 44), 32, true);
        cityName.AutowrapMode = TextServer.AutowrapMode.Off;
        FitTextWidth(cityName, 32, 16);
        cityName.Size = new(106, 44);
        cityName.SetMeta("help_text_size", cityName.Size);
        var tape = HelpPanel(panel, "HelpCityTape", new(12, -9, 352, 54), "#A96334", "#A96334", 10, 0);
        tape.RotationDegrees = -3;
        HomeArt(tape, "小星星", new(9, 6, 41, 41));
        var title = HelpText(tape, "HelpCityTipsTitle", "当前城市小贴士", new(56, 4, 284, 45), 32, true);
        title.AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        string[] tips = city.Id switch
        {
            StableIds.Cities.Tianjin or StableIds.Cities.Wuhan => new[] { "右键长按 0.45 秒", "拖入垃圾桶即可丢弃", "自动收款，点击挂件查看明细" },
            StableIds.Cities.Xian => new[] { "按工作台提示制作早餐", "看清订单，拖动成品交付", "点击金币收钱" },
            StableIds.Cities.Guangzhou => new[] { "按工作台提示制作早餐", "看清订单，拖动成品交付", "完成订单后自动入账" },
            StableIds.Cities.Yangzhou => new[] { "先备餐，将成品放入托盘", "备齐订单，再整盘上桌", "完成订单后自动入账" },
            _ => throw new InvalidOperationException("Unknown help city")
        };
        string[] colors = { "#64ABC3", "#8AB550", "#EE9855" };
        for (int i = 0; i < tips.Length; i++)
        {
            var number = HelpPanel(panel, "HelpTipNumber" + i, new(346, 51 + i * 51, 32, 32), colors[i], colors[i], 16, 0);
            HelpText(number, "Number", (i + 1).ToString(), new(0, 0, 32, 32), 24, true).AddThemeColorOverride("font_color", Colors.White);
            HelpText(panel, "HelpTip" + i, tips[i], new(390, 44 + i * 51, 360, 48), 26);
        }
    }

    private string HelpCityId() => Page is JourneyPage.City or JourneyPage.Ledger or JourneyPage.Upgrades or JourneyPage.Collection or JourneyPage.Map or JourneyPage.Continue
        ? _city : Page == JourneyPage.Completion && _completedCity is not null ? _completedCity
        : _save?.CanContinue == true ? _save.ContinueCityId : StableIds.Cities.Tianjin;

    private void DrawHelpKeys(Control parent)
    {
        var strip = HelpPanel(parent, "HelpKeyboard", new(1000, 851, 770, 77), "#F5DDB6", "#F5DDB6", 34, 0);
        string[] keys = { "Tab / 方向键", "Enter / 空格", "Esc" };
        string[] captions = { "切换", "确认", "返回" };
        for (int i = 0; i < 3; i++)
        {
            var cap = HelpPanel(strip, "HelpKey" + i, new(18 + i * 255, 14, 157, 48), "#FFF8EC", "#8E725C", 10, 3);
            HelpText(cap, "Key", keys[i], new(4, 4, 149, 40), 23, true);
            HelpText(strip, "HelpKeyCaption" + i, captions[i], new(182 + i * 255, 13, 66, 49), 26, true);
        }
    }
}
