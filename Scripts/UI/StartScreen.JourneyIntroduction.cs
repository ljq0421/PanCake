using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class StartScreen
{
    // City content and navigation stay separate from this reusable book-page composition.
    private void JourneyIntroduction(JourneyCity city, string station, Action depart)
    {
        HomeArt(_body, "Dayx背景", new(385, 225, 455, 124)).Name = "JourneyTitlePlate";
        var title = Text(_body, "JourneyTitle", "新的旅程", new(444, 249, 310, 66), 45, true);
        FitTextWidth(title, 45, 28);
        var postcard = new Control { Name = "JourneyPostcard", Position = new(285, 390), Size = new(650, 435),
            PivotOffset = new(325, 217.5f), RotationDegrees = -4, MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(postcard);
        CityPicture(postcard, city, new(Vector2.Zero, postcard.Size));
        // Caption follows the postcard's printed lower-right frame, including its tilt.
        HomeArt(postcard, "定位符", new(453, 322, 15, 21)).Name = "JourneyLocation";
        var cityTitle = Text(postcard, "CityTitle", $"{station} · {city.Name}", new(475, 316, 112, 34), 19, true);
        cityTitle.AutowrapMode = TextServer.AutowrapMode.Off;
        FitTextWidth(cityTitle, 19, 14);

        HomeArt(_body, "早餐推荐", new(1060, 268, 420, 96)).Name = "BreakfastTitlePlate";
        var foodTitle = Text(_body, "FoodTitle", city.Name + "早餐推荐", new(1160, 287, 299, 60), 33, true);
        FitTextWidth(foodTitle, 33, 22);
        JourneyBreakfastCards(city);

        var button = Button(_body, "Depart", $"从{city.Name}出发", new(1080, 768, 410, 100), depart, bare: true);
        var background = HomeArt(button, "首页地图按钮底板", new(Vector2.Zero, button.Size), stretch: true);
        background.Name = "DeparturePlate";
        background.ShowBehindParent = true;
        button.AddThemeFontSizeOverride("font_size", 34);
    }

    private void JourneyBreakfastCards(JourneyCity city)
    {
        int count = city.Foods.Length;
        const float width = 164, gap = 15;
        float left = 1265 - (count * width + (count - 1) * gap) / 2;
        for (int i = 0; i < count; i++)
        {
            var food = city.Foods[i];
            var card = new Control { Name = "BreakfastCard" + i, Position = new(left + i * (width + gap), 402),
                Size = new(width, 236), MouseFilter = MouseFilterEnum.Ignore };
            _body.AddChild(card);
            card.AddChild(new TextureRect { Name = "Background", ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                Texture = JourneyBreakfastCardTexture(i % 3), Size = card.Size,
                StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, MouseFilter = MouseFilterEnum.Ignore });
            // These food exports include transparent padding; enlarge around the same visual centre.
            if (food.Art is not null) Art(card, food.Art, new(-16, -6, 196, 232));
            else card.AddChild(new BookFoodIcon { Position = new(-16, -6), Size = new(196, 232),
                Product = new(food.Visual, food.Name, 1, food.Visual), MouseFilter = MouseFilterEnum.Ignore });
            var name = Text(card, "Food" + i, food.Name, new(9, 194, 146, 36), 25, true);
            FitTextWidth(name, 25, 18);
        }
    }

    private Texture2D JourneyBreakfastCardTexture(int index)
    {
        string key = "JourneyBreakfastCard" + index;
        if (_textures.TryGetValue(key, out var texture)) return texture;
        var source = Texture("早餐背景");
        using var image = source.GetImage();
        image.Convert(Image.Format.Rgba8);
        byte[] pixels = image.GetData();
        int width = image.GetWidth(), height = image.GetHeight();
        int start = index * width / 3, end = (index + 1) * width / 3;
        int left = end, right = -1, top = height, bottom = -1;
        // Trim each of the three cards independently; retain the original supplied PNG.
        for (int y = 0; y < height; y++) for (int x = start; x < end; x++)
            if (pixels[(y * width + x) * 4 + 3] >= 128)
            { left = Math.Min(left, x); right = Math.Max(right, x); top = Math.Min(top, y); bottom = Math.Max(bottom, y); }
        texture = new AtlasTexture { Atlas = source, FilterClip = true,
            Region = right >= left && bottom >= top ? new(left, top, right - left + 1, bottom - top + 1) : new(start, 0, end - start, height) };
        _textures[key] = texture;
        return texture;
    }
}
