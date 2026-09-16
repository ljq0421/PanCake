using Godot;

namespace ProjectCake.UI;

/// <summary>Wuhan palette over the shared teaching artwork; text stays independently themed.</summary>
public static class WuhanTeachingUi
{
    private static ShaderMaterial CreateMaterial() => new()
    {
        Shader = GD.Load<Shader>("res://resource/shaders/wuhan_teaching_palette.gdshader"),
    };

    public static void ApplyPanel(Panel panel)
    {
        TianjinTeachingUi.ApplyPanel(panel);
        panel.Material = CreateMaterial();
    }

    public static Panel ActionFrame(Button action, Vector2 position, Vector2 size)
    {
        var frame = TianjinTeachingUi.ActionFrame(action, position, size);
        // The wrapper must not draw the inherited rectangular Panel behind the cutout.
        frame.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        var art = frame.GetChildren().OfType<TextureRect>().Single();
        art.Material = CreateMaterial();
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color" })
            action.AddThemeColorOverride(state, WuhanUi.Text);
        action.AddThemeColorOverride("font_disabled_color", WuhanUi.Muted);
        var focus = (StyleBoxFlat)action.GetThemeStylebox("focus").Duplicate();
        focus.BorderColor = WuhanUi.Ink;
        action.AddThemeStyleboxOverride("focus", focus);
        action.MouseEntered += () => art.Modulate = new Color(1.06f, 1.06f, 1.06f);
        action.MouseExited += () => art.Modulate = Colors.White;
        action.ButtonDown += () => art.Modulate = new Color(.92f, .92f, .92f);
        action.ButtonUp += () => art.Modulate = Colors.White;
        return frame;
    }
}
