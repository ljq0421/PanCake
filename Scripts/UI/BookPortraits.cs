using Godot;
namespace ProjectCake.UI;

internal static class BookPortraits
{
    private static readonly Dictionary<string, Texture2D> Cache = new();
    internal static Texture2D Head(TianjinArtCatalog art, string appearance, CustomerExpression expression)
    {
        string key = appearance + expression;
        if (Cache.TryGetValue(key, out var existing)) return existing;
        var source = art.CustomerHead(appearance, expression);
        using var image = source.GetImage();
        Rect2I bounds = image.GetUsedRect();
        return Cache[key] = bounds.Size.X > 0 ? new AtlasTexture { Atlas = source, Region = new Rect2(bounds.Position, bounds.Size) } : source;
    }
}
