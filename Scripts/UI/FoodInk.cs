using Godot;

namespace ProjectCake.UI;

/// <summary>Shared, non-destructive brown ink for the Tianjin food artwork.</summary>
public static class FoodInk
{
    private static Shader? _shader;
    private static ShaderMaterial? _stock;
    private static ShaderMaterial? _order;
    private static ShaderMaterial? _scallion;

    public static ShaderMaterial Material(bool order = false)
    {
        ref ShaderMaterial? cached = ref (order ? ref _order : ref _stock);
        if (cached is not null) return cached;
        cached = new ShaderMaterial { Shader = _shader ??= GD.Load<Shader>("res://resource/shaders/food_ink.gdshader") };
        cached.SetShaderParameter("outline_pixels", order ? 0.85f : 1.25f);
        cached.SetShaderParameter("detail_pixels", order ? 0.35f : 0.55f);
        return cached;
    }

    public static bool AppliesTo(Texture2D? texture)
    {
        while (texture is AtlasTexture atlas) texture = atlas.Atlas;
        string path = texture?.ResourcePath ?? "";
        if (!path.StartsWith("res://resource/art/TianJin/", StringComparison.Ordinal)) return false;
        return System.IO.Path.GetFileNameWithoutExtension(path) is
            "鸡蛋" or "薄脆" or "香葱碎" or "火腿片" or "成品豆浆杯" or
            "熟油条" or "生油条面坯" or "炸焦油条" or "装袋后的通用煎饼果子" or
            "折叠后通用煎饼成品_1" or "sauce_light" or "sauce_extra";
    }

    public static void Apply(TextureRect visual, bool order = false)
    {
        if (!AppliesTo(visual.Texture)) return;
        Texture2D source = visual.Texture;
        while (source is AtlasTexture atlas) source = atlas.Atlas;
        if (!order && source.ResourcePath.EndsWith("/香葱碎.png", StringComparison.Ordinal))
        {
            if (_scallion is null)
            {
                _scallion = (ShaderMaterial)Material().Duplicate();
                _scallion.SetShaderParameter("outline_pixels", 0.65f);
                _scallion.SetShaderParameter("detail_strength", 0.25f);
            }
            visual.Material = _scallion;
        }
        else visual.Material = Material(order);
    }
}
