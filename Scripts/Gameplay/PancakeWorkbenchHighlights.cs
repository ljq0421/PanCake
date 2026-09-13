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
        outlines.Background = () => _art.WorkbenchBackground(SoyMilkTray is not null ? new[] { ProductKind.SoyMilk }
            : FryerMachine is not null ? new[] { ProductKind.Youtiao } : Array.Empty<ProductKind>());
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

        _fryerVisual.ResolveBasketHighlight = () => Hover(_fryerVisual);

        // These appliances are painted into the workbench. Trace that source art;
        // outlining a background crop would draw the old rectangular hit target.
        outlines.AddPath("youtiao_rack", Array.Empty<Vector2>(), () => Hover(_finishedYoutiaoSlot));

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

        // Cups stand in front of the painted tray: its edge must not cross them.
        var soyOutline = new TianjinEquipmentHighlightView { Name = "SoyTrayHighlight", ZIndex = _soyPanel.ZIndex - 1,
            Background = outlines.Background, TextureFilter = TextureFilterEnum.Linear };
        AddChild(soyOutline);
        soyOutline.AddPath("soy_tray", Array.Empty<Vector2>(), () => Hover(_soyPanel));
        outlines.AddPath("trash", Array.Empty<Vector2>(), () => Target(_trashZone, _trashZone));

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

        // Each lip is traced independently on the current sheet, including its front wall.
        return SourcePath(id switch {
            StableIds.Ingredients.Egg => new Vector2[] { new(1106,654), new(1112,601), new(1116,588),
                new(1126,582), new(1141,579), new(1248,579), new(1263,584), new(1271,595),
                new(1278,654), new(1276,669), new(1269,679), new(1257,684), new(1126,684), new(1113,679), new(1107,669) },
            StableIds.Ingredients.Crispy => new Vector2[] { new(1285,600), new(1288,589), new(1298,582),
                new(1315,578), new(1370,578), new(1425,578), new(1439,582), new(1448,591),
                new(1452,610), new(1459,650), new(1460,665), new(1455,677), new(1445,683),
                new(1430,685), new(1370,685), new(1310,685), new(1297,681), new(1290,672), new(1287,650) },
            StableIds.Ingredients.Scallion => new Vector2[] { new(1102,774), new(1109,722), new(1115,707),
                new(1128,699), new(1249,698), new(1266,703), new(1275,714), new(1284,775),
                new(1281,793), new(1273,804), new(1259,809), new(1121,809), new(1107,803), new(1102,792) },
            StableIds.Ingredients.Ham => new Vector2[] { new(1291,725), new(1293,711), new(1302,701),
                new(1320,696), new(1380,696), new(1437,696), new(1452,700), new(1461,710),
                new(1467,730), new(1472,758), new(1476,780), new(1474,793), new(1467,802),
                new(1454,808), new(1380,808), new(1318,808), new(1305,804), new(1297,796), new(1294,780) },
            _ => throw new ArgumentOutOfRangeException(nameof(id)),
        });
    }
}

/// <summary>Non-interactive contours for appliances already painted into Tianjin's background.</summary>
internal partial class TianjinEquipmentHighlightView : Control
{
    public Func<Texture2D> Background { get; set; } = null!;
    private sealed record Contour(string Id, Vector2[]? Path, Rect2? Ellipse, Func<InteractionHighlightState> Resolve)
    {
        public InteractionHighlightState State { get; set; }
    }

    private readonly List<Contour> _contours = new();
    private Transform2D _drawnTransform;

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
        Transform2D transform = InteractionHighlightPresentation.PixelTransform(this);
        bool changed = transform != _drawnTransform;
        _drawnTransform = transform;
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
            if (contour.Id is "soy_tray" or "trash")
            {
                TianjinPaintedObjectContour.Draw(this, Background(),
                    contour.Id == "soy_tray" ? TianjinPaintedObject.SoyTray : TianjinPaintedObject.Trash, contour.State);
                continue;
            }
            if (contour.Id == "youtiao_rack")
            {
                TianjinYoutiaoTrayContour.Draw(this, Background(), contour.State);
                continue;
            }
            if (contour.Ellipse is Rect2 ellipse)
                InteractionHighlightPresentation.DrawEllipse(this, ellipse, contour.State);
            else if (contour.Path is Vector2[] path)
                BackgroundArtContour.Draw(this, Background(), path, new Rect2(0, 0, 1920, 1080), contour.State,
                    preferDarkInk: contour.Id is "soy_tray"
                        or StableIds.Ingredients.Crispy or StableIds.Ingredients.Ham);
        }
    }
}
