using Godot;

namespace ProjectCake.UI;

public static class GuangzhouUi
{
    public static readonly Color Background = new("#E9EEE5"), Paper = new("#FFFDF4"), Green = new("#285B4B"), Ink = new("#273F35"),
        Muted = new("#64796C"), Line = new("#B9C7B6"), Red = new("#A34D36"), Gold = new("#C18A3C");
    public static Control Canvas(Control parent)
    {
        parent.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        parent.Theme = TianjinUi.CreateTheme();
        var canvas = new Control { Name = "Canvas", Size = new(1920, 1080), MouseFilter = Control.MouseFilterEnum.Ignore };
        parent.AddChild(canvas);
        void Fit()
        {
            float scale = Math.Min(parent.Size.X / 1920, parent.Size.Y / 1080);
            canvas.Scale = Vector2.One * scale;
            canvas.Position = (parent.Size - canvas.Size * scale) * .5f;
        }
        parent.Resized += Fit; Fit(); return canvas;
    }
    public static StyleBoxFlat Style(Color color, int border = 1) => new()
    {
        BgColor = color, BorderColor = Line, BorderWidthLeft = border, BorderWidthTop = border, BorderWidthRight = border, BorderWidthBottom = border,
        CornerRadiusTopLeft = 16, CornerRadiusTopRight = 16, CornerRadiusBottomLeft = 16, CornerRadiusBottomRight = 16,
        ContentMarginLeft = 16, ContentMarginRight = 16, ContentMarginTop = 10, ContentMarginBottom = 10,
    };
    public static Panel Panel(Control parent, Rect2 rect, Color? color = null)
    {
        var panel = new Panel { Position = rect.Position, Size = rect.Size, MouseFilter = Control.MouseFilterEnum.Ignore };
        panel.AddThemeStyleboxOverride("panel", Style(color ?? Paper)); parent.AddChild(panel); return panel;
    }
    public static Label Text(Control parent, string text, Rect2 rect, int size = 22, Color? color = null)
    {
        var label = new Label { Text = text, Position = rect.Position, Size = rect.Size, MouseFilter = Control.MouseFilterEnum.Ignore,
            VerticalAlignment = VerticalAlignment.Center, AutowrapMode = TextServer.AutowrapMode.WordSmart };
        label.AddThemeFontSizeOverride("font_size", size); label.AddThemeColorOverride("font_color", color ?? Ink); parent.AddChild(label); return label;
    }
    public static T Button<T>(Control parent, T button, Rect2 rect, Action action, bool primary = false) where T : Button
    {
        button.Position = rect.Position; button.Size = rect.Size; button.MouseDefaultCursorShape = Control.CursorShape.PointingHand;
        button.AddThemeStyleboxOverride("normal", Style(primary ? Green : Paper));
        button.AddThemeStyleboxOverride("hover", Style(primary ? new Color("#39705B") : new Color("#EDF4E6"), 2));
        button.AddThemeStyleboxOverride("pressed", Style(new Color("#B8CDB6"), 2));
        button.AddThemeStyleboxOverride("disabled", Style(new Color("#E3E8DE")));
        button.AddThemeFontSizeOverride("font_size", 21);
        button.AddThemeColorOverride("font_color", primary ? Paper : Ink);
        button.AddThemeColorOverride("font_hover_color", primary ? Paper : Ink);
        button.AddThemeColorOverride("font_disabled_color", Muted);
        button.Pressed += action; parent.AddChild(button); return button;
    }
    public static Button Button(Control parent, string text, Rect2 rect, Action action, bool primary = false)
        => Button(parent, new Button { Text = text }, rect, action, primary);
}

public partial class GuangzhouDragSource : Button
{
    public string Payload { get; set; } = "";
    public Func<bool>? CanDrag { get; set; }
    public override Variant _GetDragData(Vector2 atPosition)
    {
        if (Disabled || CanDrag?.Invoke() == false) return default;
        var preview = new Label { Text = Text.Split('\n')[0] }; preview.AddThemeFontSizeOverride("font_size", 26);
        preview.AddThemeColorOverride("font_color", GuangzhouUi.Green); SetDragPreview(preview); return Payload;
    }
}

public partial class GuangzhouCustomerCard : Button
{
    public Func<string, bool>? Accepts { get; set; }
    public Action<string>? Delivered { get; set; }
    public override bool _CanDropData(Vector2 atPosition, Variant data) => data.VariantType == Variant.Type.String && Accepts?.Invoke(data.AsString()) == true;
    public override void _DropData(Vector2 atPosition, Variant data) => Delivered?.Invoke(data.AsString());
}
