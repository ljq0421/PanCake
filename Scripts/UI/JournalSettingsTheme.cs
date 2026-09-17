using Godot;

namespace ProjectCake.UI;

/// <summary>Local paper controls; does not change other journal pages' theme.</summary>
internal static class JournalSettingsTheme
{
    internal static readonly Color Ink = new("#58351F"), Border = new("#AA805D"),
        Cream = new("#FFF6E5"), Gold = new("#FFD17A"), Muted = new("#84664F");
    private static Texture2D? _knob, _activeKnob;

    internal static StyleBoxFlat Box(Color fill, int radius = 14, int border = 2) => new()
    {
        BgColor = fill, BorderColor = Border,
        BorderWidthLeft = border, BorderWidthRight = border, BorderWidthTop = border, BorderWidthBottom = border,
        CornerRadiusTopLeft = radius, CornerRadiusTopRight = radius, CornerRadiusBottomLeft = radius, CornerRadiusBottomRight = radius,
        ContentMarginLeft = 12, ContentMarginRight = 12, ContentMarginTop = 4, ContentMarginBottom = 4,
    };

    internal static void Apply(Button button, bool selected = false, int radius = 14)
    {
        Color fill = selected ? Gold : Cream;
        button.AddThemeStyleboxOverride("normal", Box(fill, radius));
        button.AddThemeStyleboxOverride("hover", Box(fill.Lightened(.10f), radius));
        button.AddThemeStyleboxOverride("pressed", Box(Gold.Darkened(.03f), radius));
        button.AddThemeStyleboxOverride("disabled", Box(new Color("#EAE0CE"), radius));
        var focus = Box(Colors.Transparent, radius, 3); focus.BorderColor = Ink;
        focus.ExpandMarginLeft = focus.ExpandMarginRight = focus.ExpandMarginTop = focus.ExpandMarginBottom = 3;
        button.AddThemeStyleboxOverride("focus", focus);
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color" })
            button.AddThemeColorOverride(state, Ink);
        button.AddThemeColorOverride("font_disabled_color", Muted);
        button.AddThemeFontSizeOverride("font_size", 24);
    }

    internal static void Apply(OptionButton button)
    {
        Apply((Button)button);
        button.AddThemeConstantOverride("arrow_margin", 14);
        button.AddThemeIconOverride("arrow", Svg("<path d='M4 7 L12 15 L20 7 Z' fill='#795032'/>", 24));
        var popup = button.GetPopup();
        popup.AddThemeStyleboxOverride("panel", Box(Cream));
        popup.AddThemeStyleboxOverride("hover", Box(Gold, 8, 0));
        popup.AddThemeFontSizeOverride("font_size", 24);
        popup.AddThemeColorOverride("font_color", Ink);
        popup.AddThemeColorOverride("font_hover_color", Ink);
        popup.AddThemeIconOverride("radio_checked", Svg("<circle cx='8' cy='8' r='6' fill='#FFD17A' stroke='#795032' stroke-width='2'/><circle cx='8' cy='8' r='2' fill='#58351F'/>", 16));
        popup.AddThemeIconOverride("radio_unchecked", Svg("<circle cx='8' cy='8' r='6' fill='#FFF6E5' stroke='#AA805D' stroke-width='2'/>", 16));
        popup.AddThemeConstantOverride("v_separation", 16);
    }

    internal static void Apply(HSlider slider)
    {
        var track = Box(new Color("#B7987F"), 7, 2);
        track.ContentMarginTop = track.ContentMarginBottom = 6;
        track.ContentMarginLeft = track.ContentMarginRight = 0;
        slider.AddThemeStyleboxOverride("slider", track);
        var fill = (StyleBoxFlat)track.Duplicate(); fill.BgColor = Gold; fill.BorderColor = new Color("#795032");
        slider.AddThemeStyleboxOverride("grabber_area", fill);
        var active = (StyleBoxFlat)fill.Duplicate(); active.BgColor = new Color("#FFE1A0");
        slider.AddThemeStyleboxOverride("grabber_area_highlight", active);
        _knob ??= Knob(false); _activeKnob ??= Knob(true);
        slider.AddThemeIconOverride("grabber", _knob);
        slider.AddThemeIconOverride("grabber_highlight", _activeKnob);
        slider.AddThemeIconOverride("grabber_disabled", _knob);
        slider.FocusEntered += slider.QueueRedraw;
    }

    private static Texture2D Knob(bool active) => Svg(
        $"<circle cx='22' cy='24' r='18' fill='#674124' opacity='.18'/><circle cx='22' cy='21' r='18' fill='{(active ? "#FFE1A0" : "#FFE6AF")}' stroke='#704324' stroke-width='{(active ? 4 : 3)}'/><circle cx='22' cy='20' r='13' fill='#FFF9E9'/>", 44);

    private static Texture2D Svg(string body, int size)
    {
        using var image = new Image();
        image.LoadSvgFromString($"<svg xmlns='http://www.w3.org/2000/svg' width='{size}' height='{size}' viewBox='0 0 {size} {size}'>{body}</svg>");
        return ImageTexture.CreateFromImage(image);
    }
}
