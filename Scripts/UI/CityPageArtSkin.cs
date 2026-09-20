using Godot;

namespace ProjectCake.UI;

/// <summary>Applies the established city palette to shared journey-page decorations without altering source PNGs.</summary>
public static class CityPageArtSkin
{
    private static readonly Dictionary<(string City, bool Paper), ShaderMaterial> Materials = new();
    private static Shader? _shader;

    public static bool UsesWuhanPalette(string cityId) => Normalize(cityId) == "wuhan";

    public static void Apply(CanvasItem artwork, string cityId, bool recolorPaper = false)
    {
        if (!UsesWuhanPalette(cityId)) return;
        artwork.Material = MaterialFor(cityId, recolorPaper);
    }

    public static ShaderMaterial MaterialFor(string cityId, bool recolorPaper = false)
    {
        string city = Normalize(cityId);
        var key = (city, recolorPaper);
        if (Materials.TryGetValue(key, out var material)) return material;

        var theme = CitySettlementTheme.For(city);
        material = new ShaderMaterial { Shader = _shader ??= GD.Load<Shader>("res://resource/shaders/city_page_art.gdshader") };
        material.SetShaderParameter("primary", theme.Primary);
        material.SetShaderParameter("secondary", theme.Secondary);
        material.SetShaderParameter("recolor_paper", recolorPaper ? 1f : 0f);
        Materials.Add(key, material);
        return material;
    }

    public static void ApplyPrimaryButton(Button button, string cityId)
    {
        if (!UsesWuhanPalette(cityId)) return;
        var theme = CitySettlementTheme.For(Normalize(cityId));
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
        {
            Color fill = state switch
            {
                "hover" => theme.Primary.Lightened(.08f),
                "pressed" => theme.Primary.Darkened(.08f),
                "disabled" => CitySettlementTheme.Paper.Lerp(theme.Secondary, .45f),
                _ => theme.Primary,
            };
            var box = StartScreenTheme.Box(fill, state == "disabled" ? 2 : 3, state is "normal" or "hover");
            box.BorderColor = theme.Primary.Darkened(.38f);
            button.AddThemeStyleboxOverride(state, box);
        }
        button.AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        button.AddThemeColorOverride("font_hover_color", StartScreenTheme.Cream);
        button.AddThemeColorOverride("font_pressed_color", StartScreenTheme.Cream);
        button.AddThemeColorOverride("font_disabled_color", CitySettlementTheme.Muted);
    }

    private static string Normalize(string cityId) => cityId.StartsWith("city:", StringComparison.Ordinal) ? cityId[5..] : cityId;
}
