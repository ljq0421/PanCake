using Godot;

namespace ProjectCake.UI;

public partial class StartScreen
{
    // Home-only atlas cache preserves other pages' existing image framing and source PNGs.
    private readonly Dictionary<string, Texture2D> _homeTextures = new();

    private TextureRect HomeArt(Control parent, string name, Rect2 rect, bool stretch = false)
    {
        if (!_homeTextures.TryGetValue(name, out var texture))
        {
            var source = GD.Load<Texture2D>(JourneyModel.ArtRoot + name + ".png");
            using var image = source.GetImage();
            image.Convert(Image.Format.Rgba8);
            byte[] pixels = image.GetData();
            int width = image.GetWidth(), height = image.GetHeight();
            int left = width, top = height, right = -1, bottom = -1;
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
                if (pixels[(y * width + x) * 4 + 3] >= 128)
                {
                    left = Math.Min(left, x); right = Math.Max(right, x);
                    top = Math.Min(top, y); bottom = Math.Max(bottom, y);
                }
            texture = right >= left && bottom >= top
                ? new AtlasTexture { Atlas = source, Region = new Rect2(left, top, right - left + 1, bottom - top + 1) }
                : source;
            _homeTextures[name] = texture;
        }
        var art = new TextureRect
        {
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            Texture = texture, Position = rect.Position, Size = rect.Size,
            StretchMode = stretch ? TextureRect.StretchModeEnum.Scale : TextureRect.StretchModeEnum.KeepAspectCentered,
            MouseFilter = MouseFilterEnum.Ignore
        };
        parent.AddChild(art);
        return art;
    }

    private Button HomeAction(string name, string caption, string icon, Rect2 rect, Action action, bool small = false)
    {
        var button = Button(_body, name, "", rect, action, bare: true);
        HomeArt(button, small ? "首页地图按钮底板" : "首页主按钮底板", new(Vector2.Zero, rect.Size), stretch: true);
        HomeArt(button, icon, small ? new(14, -12, 110, 112) : new(18, -34, 180, 178));
        var label = Text(button, "Caption", caption,
            small ? new(122, 18, 175, 66) : new(200, 30, 275, 88), small ? 34 : 48, true);
        label.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
        label.AddThemeConstantOverride("outline_size", 4);
        return button;
    }

    private void HomeUtility(string name, string caption, string icon, float x, Action action)
    {
        var button = Button(_body, name, "", new(x, 32, 108, 128), action, bare: true);
        HomeArt(button, "圆形功能按钮底板", new(6, 0, 96, 96));
        HomeArt(button, icon, new(29, 23, 50, 50));
        var label = Text(button, "Caption", caption, new(0, 96, 108, 32), 26, true);
        label.AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        label.AddThemeColorOverride("font_outline_color", StartScreenTheme.Ink);
        label.AddThemeConstantOverride("outline_size", 6);
    }
}
