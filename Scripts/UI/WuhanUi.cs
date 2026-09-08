using Godot;

namespace ProjectCake.UI;

/// <summary>Wuhan's ivory and teal skin; shared city artwork and feedback retain their colors.</summary>
public static class WuhanUi
{
    public static readonly Color Paper = new("#F7F3E8");
    public static readonly Color Surface = new("#E9E9DC");
    public static readonly Color Accent = new("#387F70");
    public static readonly Color Ink = new("#24594F");
    public static readonly Color Text = new("#293E36");
    public static readonly Color Muted = new("#45594F");
    public static readonly Color Disabled = new("#D5DCD2");

    public static StyleBoxFlat Box(Color background, int radius = 16, int border = 4, bool shadow = true)
    {
        var box = TianjinUi.Box(background, radius, border, shadow);
        box.BorderColor = Ink;
        box.ShadowColor = shadow ? new Color(.10f, .19f, .15f, .26f) : Colors.Transparent;
        return box;
    }

    private static StyleBoxFlat ButtonBox(string state, bool primary)
    {
        Color normal = primary ? Ink : Paper;
        if (state == "focus") return Box(Colors.Transparent, 14, 6, false);
        return Box(state switch
        {
            "hover" => normal.Lightened(.07f),
            "pressed" => normal.Darkened(.06f),
            "disabled" => Disabled,
            _ => normal,
        }, 14, state == "disabled" ? 3 : 4, state is not ("pressed" or "disabled"));
    }

    public static Theme CreateTheme()
    {
        var theme = new Theme();
        foreach (string type in new[] { "Label", "Button", "TooltipLabel" })
        {
            theme.SetFontSize("font_size", type, 18);
            theme.SetColor("font_color", type, Text);
        }
        theme.SetColor("default_color", "RichTextLabel", Text);
        theme.SetFontSize("normal_font_size", "RichTextLabel", 22);
        foreach (string state in new[] { "normal", "hover", "pressed", "focus", "disabled" })
            theme.SetStylebox(state, "Button", ButtonBox(state, false));
        foreach (string state in new[] { "hover", "pressed", "focus", "disabled" })
            theme.SetColor($"font_{state}_color", "Button", state == "disabled" ? Muted : Text);
        theme.SetStylebox("panel", "PanelContainer", Box(Paper));
        theme.SetStylebox("panel", "AcceptDialog", Box(Paper, 22));
        theme.SetStylebox("panel", "TooltipPanel", Box(Paper, 10, 2));
        theme.SetColor("font_shadow_color", "TooltipLabel", Colors.Transparent);
        theme.SetConstant("outline_size", "TooltipLabel", 0);
        theme.SetColor("title_color", "Window", Text);
        theme.SetStylebox("embedded_border", "Window", Box(Surface, 18));
        theme.SetStylebox("embedded_unfocused_border", "Window", Box(Surface, 18));
        var track = Box(Surface, 6, 1, false);
        track.ContentMarginLeft = track.ContentMarginRight = track.ContentMarginTop = track.ContentMarginBottom = 0;
        theme.SetStylebox("background", "ProgressBar", track);
        var fill = Box(TianjinUi.Green, 6, 0, false);
        fill.ContentMarginLeft = fill.ContentMarginRight = fill.ContentMarginTop = fill.ContentMarginBottom = 0;
        theme.SetStylebox("fill", "ProgressBar", fill);
        return theme;
    }

    public static PanelContainer Panel(Color background, int radius = 16, int border = 4, bool shadow = true)
    {
        var panel = new PanelContainer();
        panel.AddThemeStyleboxOverride("panel", Box(background, radius, border, shadow));
        return panel;
    }

    public static Label Label(string text, int size = 20, Color? color = null,
        HorizontalAlignment alignment = HorizontalAlignment.Left) => TianjinUi.Label(text, size, color ?? Text, alignment);

    public static Button Button(string text, bool primary = false, Vector2? minimumSize = null)
    {
        var button = new Button { Text = text, CustomMinimumSize = minimumSize ?? new Vector2(152, 52) };
        foreach (string state in new[] { "normal", "hover", "pressed", "focus", "disabled" })
            button.AddThemeStyleboxOverride(state, ButtonBox(state, primary));
        Color foreground = primary ? Paper : Text;
        button.AddThemeColorOverride("font_color", foreground);
        foreach (string state in new[] { "hover", "pressed", "focus", "disabled" })
            button.AddThemeColorOverride($"font_{state}_color", state == "disabled" ? Muted : foreground);
        button.AddThemeFontSizeOverride("font_size", primary ? 22 : 18);
        return button;
    }
}
