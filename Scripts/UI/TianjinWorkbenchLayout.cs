using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>1920×1080 counter geometry. Appliances move together with their input regions.</summary>
internal static class TianjinWorkbenchLayout
{
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
            new Rect2(18, 120, 190, 24), TrayVerticalScale: bowl ? 1f : 1.12f,
            StockFootprintRect: bowl ? null : new Rect2(30, 42, 188, 48),
            StackLayout: id switch
            {
                StableIds.Ingredients.Crispy => new(new Vector2(69.6f, 74.4f), 28, 64, 82),
                StableIds.Ingredients.Ham => new(new Vector2(55.2f, 74.4f), 30, 64, 82),
                // Spread the larger clusters across the full floor, with a wider
                // row stagger so the two rows do not pile onto the same centers.
                StableIds.Ingredients.Scallion => new(new Vector2(55.2f, 40.8f), 32, 81, 86,
                    new Rect2(32, 40, 184, 46), RowOffset: 8),
                _ => null,
            });
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
}
