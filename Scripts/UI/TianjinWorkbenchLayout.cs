using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>1920×1080 counter geometry. Appliances move together with their input regions.</summary>
internal static class TianjinWorkbenchLayout
{
    // All embedded-art anchors are measured on the user's 1672 x 941 originals.
    public static readonly Vector2 SourceScale = new(1920f / 1672, 1080f / 941);
    public static readonly Rect2 CashPendant = FromSource(1220, 140, 125, 122);
    public static readonly Vector2 CashSlot = new Vector2(1280, 162) * SourceScale;
    public static Rect2 FromSource(float x, float y, float width, float height) =>
        new(new Vector2(x, y) * SourceScale, new Vector2(width, height) * SourceScale);
    public static readonly Rect2 EmbeddedStove = FromSource(520, 510, 430, 310);
    public static readonly Rect2 EmbeddedSurface = FromSource(550, 530, 365, 197);
    public static readonly Rect2 EmbeddedFryer = FromSource(112, 447, 338, 258);
    public static readonly Rect2 EmbeddedOpening = FromSource(150, 477, 253, 96);
    public static readonly Rect2 EmbeddedYoutiaoTray = FromSource(104, 710, 343, 116);
    public static readonly Rect2 EmbeddedSoyTray = FromSource(1468, 583, 173, 219);
    public static Rect2 EmbeddedIngredient(string id) => id switch
    {
        StableIds.Ingredients.Batter => FromSource(953, 542, 145, 139),
        StableIds.Ingredients.Sauce => FromSource(951, 673, 149, 136),
        StableIds.Ingredients.Egg => FromSource(1107, 582, 167, 101),
        StableIds.Ingredients.Crispy => FromSource(1287, 582, 174, 101),
        StableIds.Ingredients.Scallion => FromSource(1105, 701, 178, 107),
        StableIds.Ingredients.Ham => FromSource(1291, 701, 184, 107),
        _ => throw new ArgumentOutOfRangeException(nameof(id)),
    };

    public static WorkstationSlotSpec EmbeddedIngredientSlot(string id)
    {
        Vector2 size = EmbeddedIngredient(id).Size;
        Rect2 floor = new(22, 30, size.X - 44, size.Y - 53);
        Rect2 caption = new(0, size.Y - 5, size.X, 24);
        bool bowl = id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce;
        return new(size, new Rect2(Vector2.Zero, size), new Rect2(12, 5, size.X - 24, size.Y - 12),
            caption, new Rect2(), new Rect2(), new Rect2(Vector2.Zero, size),
            new Rect2(18, size.Y + 18, size.X - 36, 4), 1,
            IngredientContainmentRect: floor, CaptionRect: caption,
            StockFootprintRect: bowl ? null : floor,
            StackLayout: bowl ? null : new StockStackLayout(
                id == StableIds.Ingredients.Egg ? new Vector2(32, 42) : new Vector2(43, 34),
                (floor.Size.X - 35) / 4, floor.Position.Y + 20, floor.End.Y - 3,
                new Rect2(16, 8, size.X - 32, size.Y - 25), RowOffset: 3));
    }
    public const float BackEdge = 580;
    public const float FrontEdge = 995;
    public const float CenterX = 960;
    public static readonly float[] CustomerCenters = { 256, 580, 904, 1228, 1720 };
    public static readonly Rect2 PortraitWindow = new(0, 156, 332, 255);
    public const float OrderCardBottom = 152;
    public static readonly Rect2 RearTrayVisual = new(0, 4, 250, 82);
    public static float DepthAt(float contactY) => (contactY - BackEdge) / (FrontEdge - BackEdge);
    public static readonly Vector2 ApplianceOffset = new(0, 50);
    public static readonly Vector2 StoveOffset = new(50, 50);
    public static readonly Rect2 StoveFooter = new(160, 400, 410, 56);
    public static readonly Rect2 StoveFooterWithAction = new(160, 400, 260, 56);
    public static readonly Rect2 StoveActions = new(430, 400, 140, 56);
    public static readonly Rect2 Ingredients = new(1120, 692, 714, 296);
    public static readonly Rect2 Utilities = new(950, 590, 950, 110);
    public static readonly Rect2 Coins = new(40, 0, 250, 110);
    public static readonly Rect2 Finished = new(286, 0, 250, 110);
    public static readonly Rect2 TrayInput = new(12, 0, 226, 86);
    public static readonly Rect2 SoyStockInput = new(12, -22, 226, 108);
    public static readonly Rect2 FinishedTray = new(0, 0, 250, 86);
    // Conservative rectangle inside the perspective tray floor, clear of every rim.
    public static readonly Rect2 ServingTrayFloor = new(48, 18, 154, 42);
    public static readonly Rect2 SoyMilk = new(532, 0, 250, 110);
    public static readonly Rect2 SoyTray = FinishedTray;
    // Tall tabletop objects may rise above the counter's back edge, like the fryer.
    public static readonly Rect2 Trash = new(804, -56, 146, 120);
    public static readonly Vector2 FinishedVisual = new(158, 116);
    public static readonly Vector2 SoyVisual = new(102, 110);
    public static readonly Vector2 FinishedYoutiaoDragVisual = new(164, 110);
    public static readonly Rect2 FinishedInput = new(12, -36, 226, 122);
    public static readonly Vector2 FinishedArtPosition = new(10, 0);
    public static readonly Rect2 SoyCupInput = new(26, -22, 196, 106);
    public static readonly Vector2 SoyArtPosition = new(12, -4);
    public static readonly Rect2 FinishedCaption = new(41, 80, 168, 26);
    public static readonly Rect2 FinishedPickupHint = FinishedCaption;
    public static readonly Rect2 SoyCaption = FinishedCaption;
    public static readonly Rect2 SoyActions = new(246, 14, 84, 86);
    public static readonly Rect2 RawYoutiao = new(326, 66, 240, 174);
    public static readonly Rect2 FinishedYoutiao = new(326, 220, 240, 184);
    public static readonly string[] IngredientOrder =
    {
        StableIds.Ingredients.Batter, StableIds.Ingredients.Egg, StableIds.Ingredients.Crispy,
        StableIds.Ingredients.Sauce, StableIds.Ingredients.Scallion, StableIds.Ingredients.Ham,
    };

    public static WorkstationSlotSpec IngredientSlot(string id)
    {
        bool bowl = id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce;
        Rect2 toolAnchor = id == StableIds.Ingredients.Sauce
            ? new Rect2(60, 2, 112, 86) : new Rect2(58, 2, 112, 86);
        // The trimmed tray's floor starts below its back wall and ends above
        // its front lip. The former y25..97 anchor included both raised edges.
        return new WorkstationSlotSpec(
            new Vector2(248, 144),
            bowl ? new Rect2(0, 0, 228, 124) : new Rect2(0, 0, 248, 124),
            bowl ? toolAnchor : new Rect2(22, -20, 204, 120),
            new Rect2(24, 120, 74, 24),
            new Rect2(98, 120, 104, 24),
            // Standalone stock previews retain the legacy button geometry.
            // The serving workbench hides it and uses a StockGesture over tray and caption.
            new Rect2(224, 94, 66, 56),
            bowl ? new Rect2(0, 0, 228, 128) : new Rect2(20, -12, 208, 132),
            new Rect2(24, 144, 176, 4), bowl ? .85f : 1f,
            bowl ? new Rect2(64, 4, 104, 84) : new Rect2(36, 40, 176, 48),
            // Keep upper-row stock captions in the gap above the taller A tray below.
            new Rect2(18, id is StableIds.Ingredients.Egg or StableIds.Ingredients.Crispy ? 104 : 120, 190, 24), TrayVerticalScale: 1f,
            StockFootprintRect: bowl ? null : new Rect2(30, 42, 188, 48),
            StackLayout: id switch
            {
                StableIds.Ingredients.Egg => new(new Vector2(37, 49), 32, 72, 84, new Rect2(32, 24, 188, 62)),
                StableIds.Ingredients.Crispy => new(new Vector2(57, 58), 28, 68, 82, new Rect2(32, 24, 188, 62)),
                StableIds.Ingredients.Ham => new(new Vector2(49, 54), 30, 68, 82, new Rect2(32, 24, 188, 62)),
                // Spread the larger clusters across the full floor, with a wider
                // row stagger so the two rows do not pile onto the same centers.
                StableIds.Ingredients.Scallion => new(new Vector2(55.2f, 40.8f), 32, 81, 86,
                    new Rect2(32, 40, 184, 46), RowOffset: 8),
                _ => null,
            },
            TableContactAnchor: bowl ? null : new Vector2(124, 103),
            VisualContactRatio: bowl ? null : new Vector2(.5f, 1));
    }

    public static Rect2 IngredientPlacement(int index) => new(
        index % 3 * 258 - (index % 3 == 0 ? 0 : 50), index < 3 ? 16 : 148, 248, 144);

    public static WorkstationSlotSpec RawYoutiaoSlot() => new(
        RawYoutiao.Size, new Rect2(0, 30, 240, 128), new Rect2(34, 55, 172, 64),
        new Rect2(34, 144, 172, 30), new Rect2(), new Rect2(),
        new Rect2(0, 30, 240, 144), new Rect2(), .9f, CaptionRect: new Rect2(28, 144, 184, 30));

    public static WorkstationSlotSpec FinishedYoutiaoSlot() => new(
        FinishedYoutiao.Size, new Rect2(12, 15, 216, 127.8f), new Rect2(44.4f, 34.8f, 147.6f, 70.2f),
        new Rect2(26, 148, 126, 30), new Rect2(152, 148, 50, 30), new Rect2(),
        new Rect2(0, 8, 240, 172), new Rect2(), 1f, CaptionRect: new Rect2(18, 148, 192, 30));

    public static WorkstationSlotSpec FinishedYoutiaoTableSlot() => FinishedYoutiaoSlot() with
    {
        IngredientAnchorRect = new Rect2(44, 60, 148, 52),
        TableContactAnchor = new Vector2(120, 120),
        VisualContactRatio = new Vector2(.5f, 1),
    };
}
