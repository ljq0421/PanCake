using Godot;

namespace ProjectCake.UI;

/// <summary>Art-only skin. All order data and patience progress remain runtime UI.</summary>
internal static class OrderBubbleSkin
{
    public static void Apply(PanelContainer bubble, TianjinArtCatalog art)
    {
        bubble.Name = "OrderBubble";
        StyleBoxTexture style = NineSlice(art.OrderBody, 28, 16);
        style.ContentMarginLeft = 12;
        style.ContentMarginRight = 12;
        style.ContentMarginTop = 10;
        style.ContentMarginBottom = 14;
        bubble.AddThemeStyleboxOverride("panel", style);
        // An overlay parent prevents PanelContainer from sizing the tail as content.
        var overlay = new Control { Name = "OrderBubbleDecoration", MouseFilter = Control.MouseFilterEnum.Ignore };
        overlay.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        bubble.AddChild(overlay);
        var tail = TianjinUi.Texture(art.OrderTail, new Vector2(36, 18));
        tail.Name = "OrderBubbleTail";
        tail.MouseFilter = Control.MouseFilterEnum.Ignore;
        overlay.AddChild(tail);
        void LayoutTail()
        {
            tail.Position = new Vector2((overlay.Size.X - 36) / 2, overlay.Size.Y + 6);
            tail.Size = new Vector2(36, 18);
        }
        overlay.Resized += LayoutTail;
        LayoutTail();
    }

    public static Control PatienceTrack(Texture2D frame, ProgressBar fill)
    {
        var track = new NinePatchRect
        {
            Name = "OrderPatienceFrame", Texture = frame,
            PatchMarginLeft = 16, PatchMarginRight = 16,
            PatchMarginTop = 4, PatchMarginBottom = 4,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        track.SetAnchorsPreset(Control.LayoutPreset.BottomWide);
        track.OffsetTop = -12;
        track.OffsetBottom = 0;
        track.AddChild(fill);
        fill.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        fill.OffsetLeft = 4;
        fill.OffsetRight = -4;
        fill.OffsetTop = 3;
        fill.OffsetBottom = -3;
        fill.CustomMinimumSize = new Vector2(0, 6);
        fill.AddThemeStyleboxOverride("background", new StyleBoxEmpty());
        return track;
    }

    private static StyleBoxTexture NineSlice(Texture2D texture, float sourceMargin, float drawMargin)
    {
        var style = new StyleBoxTexture { Texture = texture };
        foreach (Side side in new[] { Side.Left, Side.Top, Side.Right, Side.Bottom })
        {
            style.SetTextureMargin(side, sourceMargin);
            // Godot texture margins also set the drawn corner dimensions.
            style.SetContentMargin(side, drawMargin);
        }
        return style;
    }
}
