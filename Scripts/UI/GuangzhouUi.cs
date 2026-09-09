using Godot;

namespace ProjectCake.UI;

/// <summary>Guangzhou palette and self-drawn surface styling.</summary>
public static class GuangzhouUi
{
    public static readonly Color Background = new("#E9EEE5"), Paper = new("#FFFDF4"), Green = new("#285B4B"), Ink = new("#273F35"),
        Muted = new("#64796C"), Line = new("#B9C7B6"), Red = new("#A34D36"), Gold = new("#C18A3C");

    public static StyleBoxFlat Style(Color color, int border = 1) => new()
    {
        BgColor = color,
        BorderColor = Line,
        BorderWidthLeft = border,
        BorderWidthTop = border,
        BorderWidthRight = border,
        BorderWidthBottom = border,
        CornerRadiusTopLeft = 16,
        CornerRadiusTopRight = 16,
        CornerRadiusBottomLeft = 16,
        CornerRadiusBottomRight = 16,
        ContentMarginLeft = 16,
        ContentMarginRight = 16,
        ContentMarginTop = 10,
        ContentMarginBottom = 10,
    };
}
