using Godot;

namespace ProjectCake.UI;

/// <summary>Shared illustrated framing for short, interruption-level game panels.</summary>
public static class IllustratedPanelChrome
{
    private const string MainFramePath = "res://resource/art/Global/PanelUI/panel-main-v1.tres";
    private const string TapePath = "res://resource/art/Global/PanelUI/corner-tape-v4.png";
    private const string TapeShaderPath = "res://resource/shaders/panel_tape_lighten.gdshader";

    public static void ApplyMainFrame(Control panel)
        => panel.AddThemeStyleboxOverride("panel", GD.Load<StyleBoxTexture>(MainFramePath));

    public static NinePatchRect AddTitleTape(Control parent, string name, Rect2 bounds, int zIndex = 1)
    {
        var texture = GD.Load<Texture2D>(TapePath);
        float scale = bounds.Size.Y / texture.GetHeight();
        var tape = new NinePatchRect
        {
            Name = name,
            Position = bounds.Position,
            Size = bounds.Size / scale,
            Scale = Vector2.One * scale,
            Texture = texture,
            PatchMarginLeft = 50,
            PatchMarginRight = 50,
            ZIndex = zIndex,
            MouseFilter = Control.MouseFilterEnum.Ignore,
            Material = new ShaderMaterial { Shader = GD.Load<Shader>(TapeShaderPath) },
        };
        parent.AddChild(tape);
        return tape;
    }
}
