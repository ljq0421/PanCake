using Godot;
using ProjectCake.Fryer;

namespace ProjectCake.UI;

/// <summary>Shared cooking colors for the basket, rack and the next FIFO serving.</summary>
public static class YoutiaoPresentation
{
    public static Color Tint(YoutiaoQuality quality) => quality switch
    {
        // Values above one lighten the cooked texture while preserving its alpha and detail.
        YoutiaoQuality.Light => new Color(1.12f, 1.27f, 1.48f),
        YoutiaoQuality.Deep => new Color(.78f, .56f, .34f),
        _ => Colors.White,
    };

    public static string Name(YoutiaoQuality quality) => quality switch
    {
        YoutiaoQuality.Light => "偏浅",
        YoutiaoQuality.Golden => "金黄",
        YoutiaoQuality.Deep => "偏深",
        _ => "焦糊",
    };

    public static IReadOnlyList<Color> RackTints(IReadOnlyList<YoutiaoQuality> items, int stockTier)
    {
        if (items.Count == 0) return Array.Empty<Color>();
        // Every quality present gets a visible group. Preserve the existing 1–3 pile density.
        var groups = items.Distinct().ToList();
        YoutiaoQuality mostCommon = items.GroupBy(item => item).OrderByDescending(group => group.Count()).First().Key;
        while (groups.Count < stockTier) groups.Add(mostCommon);
        // The first FIFO quality is drawn last, at the front of the stack.
        return groups.AsEnumerable().Reverse().Select(Tint).ToArray();
    }
}
