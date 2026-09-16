using Godot;

namespace ProjectCake.UI;

/// <summary>Artwork-backed chrome for Tianjin's guided first-breakfast lesson.</summary>
public static class TianjinTeachingUi
{
    private const string PanelFramePath = "res://resource/art/TianJin/TutorialUI/teaching-panel-v1.tres";
    private const string ActionPath = "res://resource/art/TianJin/TutorialUI/teaching-action-v1.png";

    public static void ApplyPanel(Panel panel)
        => panel.AddThemeStyleboxOverride("panel", GD.Load<StyleBoxTexture>(PanelFramePath));

    public static Panel ActionFrame(Button action, Vector2 position, Vector2 size)
    {
        var frame = new Panel { Position = position, Size = size, MouseFilter = Control.MouseFilterEnum.Ignore };
        var art = new TextureRect
        {
            Texture = GD.Load<Texture2D>(ActionPath),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.Scale,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        FullRect(art);
        frame.AddChild(art);

        action.Position = Vector2.Zero;
        action.Size = size;
        action.Flat = true;
        action.AddThemeStyleboxOverride("normal", new StyleBoxEmpty());
        action.AddThemeStyleboxOverride("hover", new StyleBoxEmpty());
        action.AddThemeStyleboxOverride("pressed", new StyleBoxEmpty());
        action.AddThemeStyleboxOverride("disabled", new StyleBoxEmpty());
        action.AddThemeStyleboxOverride("focus", FocusBox());
        action.AddThemeFontSizeOverride("font_size", 21);
        action.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        action.AddThemeColorOverride("font_hover_color", TianjinUi.BrownText);
        action.AddThemeColorOverride("font_pressed_color", TianjinUi.BrownText);
        action.AddThemeColorOverride("font_focus_color", TianjinUi.BrownText);
        action.AddThemeColorOverride("font_disabled_color", new Color("#826F5D"));
        frame.AddChild(action);
        return frame;
    }

    private static StyleBoxFlat FocusBox()
    {
        var style = new StyleBoxFlat
        {
            BgColor = Colors.Transparent,
            BorderColor = TianjinUi.BrownDark,
            BorderWidthLeft = 3,
            BorderWidthTop = 3,
            BorderWidthRight = 3,
            BorderWidthBottom = 3,
            CornerRadiusTopLeft = 14,
            CornerRadiusTopRight = 14,
            CornerRadiusBottomLeft = 14,
            CornerRadiusBottomRight = 14,
            ExpandMarginLeft = 3,
            ExpandMarginTop = 3,
            ExpandMarginRight = 3,
            ExpandMarginBottom = 3,
        };
        return style;
    }

    private static void FullRect(Control control)
    {
        control.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        control.OffsetLeft = control.OffsetTop = control.OffsetRight = control.OffsetBottom = 0;
    }
}
