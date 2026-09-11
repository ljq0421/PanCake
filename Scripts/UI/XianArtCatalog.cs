using Godot;

namespace ProjectCake.UI;

/// <summary>Shared, alpha-trimmed Xi'an food textures. Source artwork stays untouched.</summary>
public sealed class XianArtCatalog
{
    private static readonly Dictionary<string, Texture2D> Cache = new();
    public Texture2D Texture(string name)
    {
        if (Cache.TryGetValue(name, out var cached)) return cached;
        var source = GD.Load<Texture2D>($"res://resource/art/XiAn/{name}.png");
        using var image = source.GetImage();
        image.Convert(Image.Format.Rgba8);
        byte[] data = image.GetData();
        int w = image.GetWidth(), h = image.GetHeight(), left = w, top = h, right = -1, bottom = -1;
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
            if (data[(y * w + x) * 4 + 3] >= 32)
            { left = Math.Min(left, x); top = Math.Min(top, y); right = Math.Max(right, x); bottom = Math.Max(bottom, y); }
        return Cache[name] = right >= left ? new AtlasTexture { Atlas = source,
            Region = new Rect2(left, top, right - left + 1, bottom - top + 1) } : source;
    }
}
