using Godot;

namespace ProjectCake.UI;

/// <summary>Original PNGs remain intact. Atlas regions remove transparent export margins.</summary>
public static class BookArtCatalog
{
    private static readonly Dictionary<string, Texture2D> Cache = new(StringComparer.Ordinal);
    private static readonly Dictionary<string, ShaderMaterial> Materials = new(StringComparer.Ordinal);
    private static Shader? _shader;
    public static string BoardPath(string city) => city switch
    {
        "tianjin" => "res://resource/art/TianJin/Ledger/ledger_book.png",
        "wuhan" => "res://resource/art/Global/BookUI/营业结算账本底板-武汉-v3.png",
        "xian" => "res://resource/art/Global/BookUI/营业结算账本底板-西安-v3.png",
        _ => "res://resource/art/Global/BookUI/营业结算账本底板-v1.png",
    };
    public static string BoardName(string city) => Path.GetFileNameWithoutExtension(BoardPath(city));
    public static Texture2D GetBoard(string city) => GetPath(BoardPath(city));
    public static ShaderMaterial? DecorationMaterial(string name, CitySettlementTheme theme)
    {
        int area = name switch { "营业结算账本底板-v1" => 2, "顾客头像圆框" => 3, "账本轻分隔线" => 4, "今日手记便签底板" => 5, "今日热销徽章" or "可升级提示贴片" or "新解锁提示贴片" => 1, _ => 0 };
        if (area == 0) return null;
        string key = theme.Id + "/" + name;
        if (Materials.TryGetValue(key, out var material)) return material;
        var atlas = (AtlasTexture)Get(name);
        Vector2 size = atlas.Atlas.GetSize(); var r = atlas.Region;
        material = new ShaderMaterial { Shader = _shader ??= GD.Load<Shader>("res://resource/shaders/book_accent.gdshader") };
        material.SetShaderParameter("region", new Vector4(r.Position.X / size.X, r.Position.Y / size.Y, r.Size.X / size.X, r.Size.Y / size.Y));
        material.SetShaderParameter("accent", area == 4 ? theme.Divider : theme.Ornament);
        material.SetShaderParameter("area", area);
        Materials.Add(key, material); return material;
    }
    public static Texture2D Get(string name) => GetPath($"res://resource/art/Global/BookUI/{name}.png");

    private static Texture2D GetPath(string path)
    {
        if (Cache.TryGetValue(path, out var cached)) return cached;
        var source = GD.Load<Texture2D>(path);
        using var pixels = source.GetImage();
        // The exports contain almost invisible stray pixels beyond the artwork.
        // Ignore alpha below 1/8 when measuring, while retaining the original texture.
        int left = pixels.GetWidth(), top = pixels.GetHeight(), right = 0, bottom = 0;
        for (int y = 0; y < pixels.GetHeight(); y++)
            for (int x = 0; x < pixels.GetWidth(); x++)
                if (pixels.GetPixel(x, y).A > .125f) { left = Math.Min(left, x); top = Math.Min(top, y); right = Math.Max(right, x); bottom = Math.Max(bottom, y); }
        var texture = new AtlasTexture { Atlas = source, Region = new Rect2(left, top, right - left + 1, bottom - top + 1), FilterClip = true };
        Cache.Add(path, texture); return texture;
    }
}
