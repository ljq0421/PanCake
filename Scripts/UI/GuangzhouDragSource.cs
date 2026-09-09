using Godot;

namespace ProjectCake.UI;

public partial class GuangzhouDragSource : Button
{
    public string Payload { get; set; } = "";
    public Func<bool>? CanDrag { get; set; }

    public override Variant _GetDragData(Vector2 atPosition)
    {
        if (Disabled || CanDrag?.Invoke() == false) return default;
        var preview = new Label { Text = Text.Split('\n')[0] };
        preview.AddThemeFontSizeOverride("font_size", 26);
        preview.AddThemeColorOverride("font_color", GuangzhouUi.Green);
        SetDragPreview(preview);
        return Payload;
    }
}
