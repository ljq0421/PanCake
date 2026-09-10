using Godot;

namespace ProjectCake.UI;

/// <summary>Game-wide identity: shared cartoon shapes, independent of any city skin.</summary>
public static class StartScreenTheme
{
    public static readonly Color Cream = new("#FFF6E5"), Teal = new("#286354"), Ink = new("#3E382B"),
        Apricot = new("#F2C67D"), Brick = new("#983F32"), Muted = new("#665C49");

    public static StyleBoxFlat Box(Color color, int border = 3, bool shadow = false) => new()
    {
        BgColor = color, BorderColor = Ink,
        BorderWidthLeft = border, BorderWidthRight = border, BorderWidthTop = border, BorderWidthBottom = border,
        CornerRadiusTopLeft = 20, CornerRadiusTopRight = 20, CornerRadiusBottomLeft = 20, CornerRadiusBottomRight = 20,
        ShadowColor = new Color(0.19f, 0.17f, 0.12f, 0.16f), ShadowSize = shadow ? 5 : 0, ShadowOffset = new(0, 5),
        ContentMarginLeft = 24, ContentMarginRight = 24, ContentMarginTop = 12, ContentMarginBottom = 12,
    };

    public static Theme Create()
    {
        var theme = new Theme { DefaultFontSize = 26 };
        theme.SetColor("font_color", "Label", Ink);
        return theme;
    }

    public static void Apply(Button button, bool primary = false, bool destructive = false)
    {
        Color fill = destructive ? Brick : primary ? Teal : Cream;
        Color text = primary || destructive ? Cream : Ink;
        button.AddThemeStyleboxOverride("normal", Box(fill, 3, true));
        button.AddThemeStyleboxOverride("hover", Box(fill.Lightened(0.07f), 3, true));
        button.AddThemeStyleboxOverride("pressed", Box(fill.Darkened(0.06f)));
        button.AddThemeStyleboxOverride("disabled", Box(new Color("#E1DDCF"), 2));
        var focus = Box(Colors.Transparent, 4);
        focus.BorderColor = Teal;
        focus.ExpandMarginLeft = focus.ExpandMarginRight = focus.ExpandMarginTop = focus.ExpandMarginBottom = 6;
        button.AddThemeStyleboxOverride("focus", focus);
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color" })
            button.AddThemeColorOverride(state, text);
        button.AddThemeColorOverride("font_disabled_color", Muted);
        button.AddThemeFontSizeOverride("font_size", 30);
    }
}
