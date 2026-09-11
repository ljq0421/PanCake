using Godot;
using System.Runtime.CompilerServices;

namespace ProjectCake.UI;

/// <summary>Shared remaining-patience presentation for every city.</summary>
public static class PatienceBarPresentation
{
    public static readonly Color Green = new("#76A951");
    public static readonly Color Yellow = new("#E2BA42");
    public static readonly Color Red = new("#C94F42");
    private static readonly ConditionalWeakTable<ProgressBar, StyleBoxFlat> Fills = new();

    public static void Render(ProgressBar bar, double remaining)
    {
        remaining = Math.Clamp(remaining, 0, 1);
        // Scene resources can be shared by several customers: mutate only a private copy.
        StyleBoxFlat fill = Fills.GetValue(bar, control =>
        {
            var copy = (StyleBoxFlat)control.GetThemeStylebox("fill").Duplicate();
            control.AddThemeStyleboxOverride("fill", copy);
            return copy;
        });
        bar.Value = remaining * 100;
        bar.Modulate = Colors.White;
        fill.BgColor = remaining < .2 ? Red : remaining < .4 ? Yellow : Green;
    }
}
