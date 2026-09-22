using Godot;

namespace ProjectCake.UI;

public partial class StartScreen
{
    // Home-only atlas cache preserves other pages' existing image framing and source PNGs.
    private readonly Dictionary<string, Texture2D> _homeTextures = new();
    private static bool _homeEntranceShown;

    private void HomeEntrance()
    {
        if (_homeEntranceShown) return;
        _homeEntranceShown = true;
        _body.AddChild(new HomeEntranceMotion
        {
            Screen = this, Logo = _body.GetNode<Control>("HomeLogo"),
            Actions = new[] { "Continue", "NewGame", "BreakfastRecords", "WorldMap" }
                .Select(name => (Control)_body.GetNode<Button>(name)).ToArray()
        });
    }

    private static ShaderMaterial HomeMapSoftFocus() => new()
    {
        Shader = new Shader { Code = """
            shader_type canvas_item;
            varying vec4 vertex_modulate;
            void vertex() { vertex_modulate = COLOR; }
            void fragment() {
                vec4 tint = vertex_modulate;
                vec4 sum = vec4(0.0);
                float total = 0.0;
                for (int y = -2; y <= 2; y++) {
                    for (int x = -2; x <= 2; x++) {
                        float weight = exp(-float(x*x + y*y) / 4.0);
                        vec4 sample_color = texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * 3.0);
                        sum += vec4(sample_color.rgb * sample_color.a, sample_color.a) * weight;
                        total += weight;
                    }
                }
                vec3 color = sum.rgb / max(sum.a, 0.0001);
                color = mix(color, vec3(1.0, 0.88, 0.68), 0.18);
                COLOR = vec4(color, sum.a / total) * tint;
            }
            """ }
    };

    private string HomeLogoArt => _settings.Language == "en" ? "World, Breakfast Is Served" : "全世界等我开饭";

    private Texture2D HomeTexture(string name)
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
        return texture;
    }

    private TextureRect HomeArt(Control parent, string name, Rect2 rect, bool stretch = false)
    {
        var art = new TextureRect
        {
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            Texture = HomeTexture(name), Position = rect.Position, Size = rect.Size,
            StretchMode = stretch ? TextureRect.StretchModeEnum.Scale : TextureRect.StretchModeEnum.KeepAspectCentered,
            MouseFilter = MouseFilterEnum.Ignore
        };
        parent.AddChild(art);
        return art;
    }

    private Button HomeAction(string name, string caption, string icon, Rect2 rect, Action action, bool small = false)
    {
        var button = Button(_body, name, "", rect, action, bare: true, highlightFocus: name != "Continue");
        var texture = Texture(small ? "首页地图按钮底板" : "首页主按钮底板");
        float artScale = rect.Size.Y / texture.GetHeight();
        // Scale both painted end caps uniformly; only the plain centre changes width.
        button.AddChild(new NinePatchRect
        {
            Name = "ButtonBacking", Texture = texture,
            Size = rect.Size / artScale, Scale = Vector2.One * artScale,
            PatchMarginLeft = texture.GetHeight() / 2, PatchMarginRight = texture.GetHeight() / 2,
            MouseFilter = MouseFilterEnum.Ignore
        });
        var picture = HomeArt(button, icon, small ? new(35, -12, 100, 100) : new(18, -34, 180, 178));
        picture.Name = "ActionIcon";
        button.AddChild(new HomeActionMotion { Screen = this, Icon = picture, Train = name == "Continue" });
        var label = Text(button, "Caption", caption,
            small ? new(7, 83, 156, 45) : new(200, 30, 275, 88), small ? 30 : 48, true);
        FitTextWidth(label, small ? 30 : 48, small ? 25 : 32);
        label.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
        label.AddThemeConstantOverride("outline_size", 4);
        return button;
    }

    private void HomeUtility(string name, string caption, string icon, float x, Action action, Control? parent = null)
    {
        var button = Button(parent ?? _body, name, "", new(x, 32, 108, 128), action, bare: true);
        HomeArt(button, "圆形功能按钮底板", new(6, 0, 96, 96));
        HomeArt(button, icon, new(29, 23, 50, 50));
        var label = Text(button, "Caption", caption, new(0, 96, 108, 32), 26, true);
        FitTextWidth(label, 26, 20);
        label.AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        label.AddThemeColorOverride("font_outline_color", StartScreenTheme.Ink);
        label.AddThemeConstantOverride("outline_size", 6);
    }
}
