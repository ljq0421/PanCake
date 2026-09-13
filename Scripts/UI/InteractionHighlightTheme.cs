using Godot;
using System.Runtime.CompilerServices;

namespace ProjectCake.UI;

/// <summary>Scene-local hover styling. Other interaction states retain their shared semantics.</summary>
public sealed record InteractionHighlightTheme(Color HoverColor)
{
    public static readonly InteractionHighlightTheme Tianjin = new(new Color("#FFF06A"));
    public static readonly InteractionHighlightTheme Wuhan = new(new Color("#20B8AA"));
    public static readonly Color BackingColor = new("#49382D");
    private static readonly ConditionalWeakTable<Node, InteractionHighlightTheme> Themes = new();
    private static readonly ConditionalWeakTable<CanvasItem, Dictionary<object, Fade>> Fades = new();
    private static readonly ConditionalWeakTable<CanvasItem, HoverFadeRedraw> Redraws = new();
    private sealed class Fade { public ulong Frame; public float Opacity; }

    public static void Set(Node root, InteractionHighlightTheme theme)
    {
        Themes.Remove(root);
        Themes.Add(root, theme);
    }

    public static InteractionHighlightTheme? Find(Node? node)
    {
        for (; node is not null; node = node.GetParent())
            if (Themes.TryGetValue(node, out var theme)) return theme;
        return null;
    }

    public static bool Applies(CanvasItem canvas, InteractionHighlightState state) =>
        state == InteractionHighlightState.Hover && Find(canvas) is not null;

    public static bool ReducedMotion => ProjectSettings.HasSetting("accessibility/reduce_motion")
        && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();

    // Drawn equipment may share one canvas. Each silhouette owns its own fade, and
    // missing a frame resets it, so moving between adjacent bowls never carries opacity.
    public static float HoverOpacity(CanvasItem canvas, object key, InteractionHighlightState state)
    {
        var fades = Fades.GetOrCreateValue(canvas);
        if (!Applies(canvas, state)) { fades.Remove(key); return 1; }
        ulong frame = Engine.GetProcessFrames();
        if (!fades.TryGetValue(key, out var fade))
        {
            if (fades.Count > 128)
                foreach (var old in fades.Where(p => p.Value.Frame + 1 < frame).Select(p => p.Key).ToArray()) fades.Remove(old);
            fades[key] = fade = new Fade();
        }
        if (fade.Frame + 1 < frame) fade.Opacity = 0;
        if (fade.Frame != frame)
            fade.Opacity = ReducedMotion ? 1 : Mathf.MoveToward(fade.Opacity, 1, (float)canvas.GetProcessDeltaTime() * 10);
        fade.Frame = frame;
        if (fade.Opacity < 1)
        {
            if (!Redraws.TryGetValue(canvas, out var redraw))
            {
                redraw = new HoverFadeRedraw { Canvas = canvas, Name = "HoverFadeRedraw" };
                canvas.AddChild(redraw);
                Redraws.Add(canvas, redraw);
            }
            redraw.Pending = true;
        }
        return fade.Opacity;
    }
}

// QueueRedraw inside _Draw alone is not a reliable request for the next frame.
internal partial class HoverFadeRedraw : Node
{
    internal CanvasItem Canvas = null!;
    internal bool Pending;
    public override void _Process(double delta)
    {
        if (!Pending) return;
        Pending = false;
        Canvas.QueueRedraw();
    }
}
