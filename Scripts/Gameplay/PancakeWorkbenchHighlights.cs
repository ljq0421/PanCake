using Godot;
using ProjectCake.Data;
using ProjectCake.Interaction;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private void ConfigureTianjinHighlights(Vector2[] fryerOutline)
    {
        var outlines = new TianjinEquipmentHighlightView { Name = "TianjinEquipmentHighlights", ZIndex = 76 };
        AddChild(outlines);

        InteractionHighlightState Hover(Control target)
        {
            if (!_initialized || !CanInteract || _drag.IsDragging || !target.IsVisibleInTree())
                return InteractionHighlightState.None;
            Vector2 point = target.GetGlobalTransform().AffineInverse() * target.GetGlobalMousePosition();
            return new Rect2(Vector2.Zero, target.Size).HasPoint(point)
                ? InteractionHighlightState.Hover : InteractionHighlightState.None;
        }

        InteractionHighlightState Target(DropZone zone, Control surface)
        {
            if (!_initialized || !CanInteract || !surface.IsVisibleInTree()) return InteractionHighlightState.None;
            return zone.VisualState != DropZoneVisualState.Idle
                ? InteractionHighlightPresentation.FromDropZone(zone.VisualState) : Hover(surface);
        }

        outlines.AddEllipse("stove", TianjinWorkbenchLayout.EmbeddedSurface, () => Target(_stoveDropZone, _canvas));
        outlines.AddPath("fryer", SourcePath(fryerOutline), () => Hover(_rawYoutiaoInput));

        // These appliances are painted into the workbench. Trace that source art;
        // outlining a background crop would draw the old rectangular hit target.
        outlines.AddPath("youtiao_rack", SourcePath(new Vector2[] {
            new(138, 711), new(413, 711), new(433, 716), new(445, 727), new(455, 790),
            new(455, 806), new(449, 817), new(432, 829), new(116, 829), new(101, 823),
            new(93, 812), new(93, 795), new(110, 736), new(119, 719),
        }), () => Hover(_finishedYoutiaoSlot));

        foreach ((string id, IngredientStockSlotView slot) in _ingredientSlots)
        {
            InteractionHighlightState State()
            {
                if (!_initialized || !CanInteract || !slot.IsVisibleInTree() || !_enabledIngredients.Contains(id))
                    return InteractionHighlightState.None;
                if (id == StableIds.Ingredients.Sauce && Machine.Runtime.State == PancakeState.Saucing)
                    return InteractionHighlightState.Selected;
                return Hover(slot);
            }
            outlines.AddPath(id, IngredientOutline(id), State);
        }

        outlines.AddPath("soy_tray", SourcePath(new Vector2[] {
            new(1485, 580), new(1588, 580), new(1606, 586), new(1614, 600),
            new(1656, 769), new(1659, 786), new(1652, 800), new(1635, 805),
            new(1508, 805), new(1495, 800), new(1488, 788), new(1462, 606),
            new(1464, 590), new(1472, 583),
        }), () => Hover(_soyPanel));

        outlines.AddPath("trash", SourcePath(new Vector2[] {
            new(1018, 841), new(1149, 841), new(1154, 846), new(1163, 846),
            new(1167, 854), new(1167, 870), new(1161, 878), new(1155, 920),
            new(1148, 934), new(1136, 939), new(1031, 939), new(1018, 934),
            new(1011, 921), new(1006, 879), new(1001, 872), new(1002, 851),
            new(1007, 845), new(1017, 845),
        }), () => Target(_trashZone, _trashZone));

        // Finished food keeps its existing brown ink material. Its independent
        // alpha contour follows the live texture, stock visibility and motion.
        foreach (TextureRect food in _finishedYoutiaoSlot.IngredientVisuals)
            ArtContourHighlight.Attach(food, () => Hover(_storedYoutiao));
        foreach (TextureRect food in _finished.FindChildren("*", "TextureRect", true, false).OfType<TextureRect>().ToArray())
            ArtContourHighlight.Attach(food, () => Hover(_finished));
        if (_soyStockArt is not null)
            foreach (TextureRect cup in _soyStockArt.Cups)
                ArtContourHighlight.Attach(cup, () => Hover(_soyPanel));
    }

    private static Vector2[] SourcePath(Vector2[] points) =>
        points.Select(point => point * TianjinWorkbenchLayout.SourceScale).ToArray();

    private static Vector2[] IngredientOutline(string id)
    {
        if (id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce)
        {
            bool batter = id == StableIds.Ingredients.Batter;
            // Include the actual spoon handle in each bowl's outer silhouette.
            Vector2[] bowl = {
                new(1012, 563), new(1038, 566), new(1077, 545), new(1086, 543),
                new(1093, 548), new(1093, 556), new(1075, 577), new(1087, 589),
                new(1090, 604), new(1083, 644), new(1072, 661), new(1053, 674),
                new(1029, 680), new(1004, 677), new(983, 668), new(969, 652),
                new(959, 615), new(956, 596), new(963, 582), new(982, 570),
            };
            if (!batter)
                bowl = bowl.Select(point => new Vector2(point.X, point.Y + 127)).ToArray();
            return SourcePath(bowl);
        }

        Rect2 tray = TianjinWorkbenchLayout.EmbeddedIngredient(id);
        // The four trays share the background's rounded perspective lip. The
        // front edge is wider than the rear edge, unlike their rectangular input.
        Vector2[] normalized = {
            new(.15f, .02f), new(.84f, .02f), new(.91f, .05f), new(.96f, .12f),
            new(.99f, .73f), new(1f, .84f), new(.96f, .95f), new(.87f, .99f),
            new(.10f, .99f), new(.03f, .94f), new(0f, .83f), new(.02f, .22f),
            new(.05f, .10f), new(.09f, .04f),
        };
        return normalized.Select(point => tray.Position + point * tray.Size).ToArray();
    }
}

/// <summary>Non-interactive contours for appliances already painted into Tianjin's background.</summary>
internal partial class TianjinEquipmentHighlightView : Control
{
    private sealed record Contour(string Id, Vector2[]? Path, Rect2? Ellipse, Func<InteractionHighlightState> Resolve)
    {
        public InteractionHighlightState State { get; set; }
    }

    private readonly List<Contour> _contours = new();

    public TianjinEquipmentHighlightView()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        Size = new Vector2(1920, 1080);
    }

    public void AddPath(string id, Vector2[] points, Func<InteractionHighlightState> state) =>
        _contours.Add(new Contour(id, points, null, state));

    public void AddEllipse(string id, Rect2 bounds, Func<InteractionHighlightState> state) =>
        _contours.Add(new Contour(id, null, bounds, state));

    public override void _Process(double delta)
    {
        bool changed = false;
        foreach (Contour contour in _contours)
        {
            InteractionHighlightState next = IsVisibleInTree() ? contour.Resolve() : InteractionHighlightState.None;
            if (next == contour.State) continue;
            contour.State = next;
            changed = true;
        }
        if (changed) QueueRedraw();
    }

    public override void _Draw()
    {
        foreach (Contour contour in _contours)
        {
            if (contour.State == InteractionHighlightState.None) continue;
            if (contour.Ellipse is Rect2 ellipse)
                InteractionHighlightPresentation.DrawEllipse(this, ellipse, contour.State);
            else if (contour.Path is Vector2[] path)
                InteractionHighlightPresentation.DrawPath(this, path, contour.State);
        }
    }
}
