using Godot;

namespace ProjectCake.UI;

/// <summary>Shared paging artwork; the existing button retains input and navigation.</summary>
public partial class PageArrowArt : TextureRect
{
    private static readonly Dictionary<bool, Texture2D> Textures = new();
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
        if (!Textures.TryGetValue(right, out var texture))
        {
            var source = GD.Load<Texture2D>("res://resource/art/Global/StartPage/" + (right ? "右箭头" : "左箭头") + ".png");
            using var pixels = source.GetImage();
            var used = pixels.GetUsedRect();
            texture = new AtlasTexture { Atlas = source, Region = new Rect2(used.Position, used.Size) };
            Textures[right] = texture;
        }
        art.Texture = texture;
        city = city.StartsWith("city:", StringComparison.Ordinal) ? city[5..] : city;
        art.Material = city is "tianjin" or "wuhan" ? CityPageArtSkin.MaterialFor(city) : null;
        ButtonHoverFeedback.Attach(button);
        ArtworkButtonFocus.Attach(button);
        art.Refresh();
    }

    public override void _Process(double delta) => Refresh();

    private void Refresh() => SelfModulate = _button.Disabled ? new Color(1, 1, 1, .35f)
        : _button.IsPressed() ? new Color(.85f, .85f, .85f) : Colors.White;
}
