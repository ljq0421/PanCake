using Godot;

namespace ProjectCake.UI;

public static class TianjinUi
{
    public static readonly Color Cream = new("#FFF1D2");
    public static readonly Color CreamMuted = new("#F4DDB5");
    public static readonly Color Paper = new("#FFF8E8");
    public static readonly Color Yellow = new("#F5B83D");
    public static readonly Color Orange = new("#E9873D");
    public static readonly Color Brown = new("#9A592D");
    public static readonly Color BrownDark = new("#4A291C");
    public static readonly Color BrownText = new("#3B241A");
    public static readonly Color Green = new("#76A951");
    public static readonly Color Red = new("#D95D47");
    public static readonly Color Shadow = new(0.21f, 0.10f, 0.045f, 0.34f);
    public static Theme CreateTheme()
    {
        var theme = new Theme();
        theme.SetFontSize("font_size", "Label", 18);
        theme.SetColor("font_color", "Label", BrownText);
        theme.SetFontSize("font_size", "Button", 18);
        theme.SetColor("font_color", "Button", BrownText);
        theme.SetColor("font_hover_color", "Button", BrownText);
        theme.SetColor("font_pressed_color", "Button", BrownText);
        theme.SetStylebox("normal", "Button", Box(Cream, 14));
        theme.SetStylebox("hover", "Button", Box(Cream.Lightened(0.09f), 14));
        theme.SetStylebox("pressed", "Button", Box(Cream.Darkened(0.08f), 14, 4, false));
        theme.SetStylebox("focus", "Button", Box(Cream, 14, 6));
        theme.SetStylebox("panel", "PanelContainer", Box(Paper));
        return theme;
    }

    public static StyleBoxFlat Box(Color background, int radius = 16, int border = 4, bool shadow = true)
    {
        return new StyleBoxFlat
        {
            BgColor = background,
            BorderColor = BrownDark,
            BorderWidthLeft = border,
            BorderWidthTop = border,
            BorderWidthRight = border,
            BorderWidthBottom = border,
            CornerRadiusTopLeft = radius,
            CornerRadiusTopRight = radius,
            CornerRadiusBottomLeft = radius,
            CornerRadiusBottomRight = radius,
            ContentMarginLeft = 16,
            ContentMarginTop = 12,
            ContentMarginRight = 16,
            ContentMarginBottom = 12,
            ShadowColor = shadow ? Shadow : Colors.Transparent,
            ShadowSize = shadow ? 8 : 0,
            ShadowOffset = shadow ? new Vector2(0, 6) : Vector2.Zero,
        };
    }

    public static PanelContainer Panel(Color background, int radius = 16, int border = 4, bool shadow = true)
    {
        var panel = new PanelContainer();
        panel.AddThemeStyleboxOverride("panel", Box(background, radius, border, shadow));
        return panel;
    }

    public static Label Label(string text, int size = 20, Color? color = null, HorizontalAlignment alignment = HorizontalAlignment.Left)
    {
        var label = new Label
        {
            Text = text,
            HorizontalAlignment = alignment,
            VerticalAlignment = VerticalAlignment.Center,
        };
        label.AddThemeFontSizeOverride("font_size", size);
        label.AddThemeColorOverride("font_color", color ?? BrownText);
        return label;
    }

    public static Button Button(string text, bool primary = false, Vector2? minimumSize = null)
    {
        var button = new Button
        {
            Text = text,
            CustomMinimumSize = minimumSize ?? new Vector2(152, 52),
            FocusMode = Control.FocusModeEnum.All,
        };
        Color normal = primary ? Yellow : Cream;
        button.AddThemeStyleboxOverride("normal", Box(normal, 14, 4, true));
        button.AddThemeStyleboxOverride("hover", Box(normal.Lightened(0.09f), 14, 4, true));
        button.AddThemeStyleboxOverride("pressed", Box(normal.Darkened(0.08f), 14, 4, false));
        button.AddThemeStyleboxOverride("focus", Box(normal, 14, 6, true));
        button.AddThemeStyleboxOverride("disabled", Box(new Color("#D9C7AA"), 14, 3, false));
        button.AddThemeColorOverride("font_color", BrownText);
        button.AddThemeColorOverride("font_hover_color", BrownText);
        button.AddThemeColorOverride("font_pressed_color", BrownText);
        button.AddThemeColorOverride("font_focus_color", BrownText);
        button.AddThemeColorOverride("font_disabled_color", new Color("#826F5D"));
        button.AddThemeFontSizeOverride("font_size", primary ? 22 : 18);
        return button;
    }

    public static TextureRect Texture(Texture2D texture, Vector2 minimumSize, TextureRect.StretchModeEnum stretch = TextureRect.StretchModeEnum.KeepAspectCentered)
    {
        return new TextureRect
        {
            Texture = texture,
            CustomMinimumSize = minimumSize,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = stretch,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
    }

    public static void FullRect(Control control, float left = 0, float top = 0, float right = 0, float bottom = 0)
    {
        control.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        control.OffsetLeft = left;
        control.OffsetTop = top;
        control.OffsetRight = right;
        control.OffsetBottom = bottom;
    }
}
