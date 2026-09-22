using Godot;

namespace ProjectCake.UI;

/// <summary>Shared paging artwork; the existing button retains input and navigation.</summary>
public partial class PageArrowArt : TextureRect
{
    private static readonly Dictionary<(bool Right, string Palette), Texture2D> Textures = new();
    private Button _button = null!;

    public static void Apply(Button button, bool right, string city = "", string? caption = null)
    {
        button.Text = "";
        button.TooltipText = caption ?? (right ? "下一页" : "上一页");
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled", "focus" })
            button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        if (button.GetNodeOrNull<PageArrowArt>("PageArrow") is not { } art)
        {
            art = new PageArrowArt { Name = "PageArrow", _button = button,
                MouseFilter = MouseFilterEnum.Ignore, ExpandMode = ExpandModeEnum.IgnoreSize,
                StretchMode = StretchModeEnum.KeepAspectCentered };
            button.AddChild(art);
            art.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        }
        city = city.StartsWith("city:", StringComparison.Ordinal) ? city[5..] : city;
        string palette = city is "tianjin" or "wuhan" ? city : "home";
        var key = (right, palette);
        if (!Textures.TryGetValue(key, out var texture))
        {
            Color fill = palette == "home" ? StartScreenTheme.Cream : CitySettlementTheme.Paper;
            Color border = palette switch
            {
                "wuhan" => new("#527C69"),
                "tianjin" => new("#AB692F"),
                _ => StartScreenTheme.Teal,
            };
            Color ink = palette == "home" ? StartScreenTheme.Ink : new("#4A3024");
            // Native vector artwork matches the reference at every UI scale.
            string points = right ? "28,25 37,31 28,37" : "34,25 25,31 34,37";
            using var pixels = new Image();
            pixels.LoadSvgFromString($"""
                <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
                  <rect x="2" y="2" width="60" height="60" rx="28" fill="#{fill.ToHtml(false)}" stroke="#{border.ToHtml(false)}" stroke-width="2.2"/>
                  <polyline points="{points}" fill="none" stroke="#{ink.ToHtml(false)}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                """, 4);
            texture = ImageTexture.CreateFromImage(pixels);
            Textures[key] = texture;
        }
        art.Texture = texture;
        // Palette is baked into the shared vector texture; no artwork recoloring is needed.
        art.Material = null;
        ButtonHoverFeedback.Attach(button);
        ArtworkButtonFocus.Attach(button);
        art.Refresh();
    }

    public override void _Process(double delta) => Refresh();

    private void Refresh() => SelfModulate = _button.Disabled ? new Color(1, 1, 1, .35f)
        : _button.IsPressed() ? new Color(.85f, .85f, .85f) : Colors.White;
}
