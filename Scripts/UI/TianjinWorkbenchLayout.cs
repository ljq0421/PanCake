using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>1920×1080 counter geometry. Appliances move together with their input regions.</summary>
internal static class TianjinWorkbenchLayout
{
    public static readonly Vector2 ApplianceOffset = new(0, 50);
    public static readonly Rect2 StoveFooter = new(160, 400, 410, 56);
    public static readonly Rect2 StoveFooterWithAction = new(160, 400, 260, 56);
    public static readonly Rect2 StoveActions = new(430, 400, 140, 56);
    public static readonly Rect2 Ingredients = new(1032, 680, 868, 308);
    public static readonly Rect2 Utilities = new(1048, 568, 852, 110);
    public static readonly Rect2 Finished = new(28, 0, 250, 110);
    public static readonly Rect2 FinishedTray = new(0, 0, 250, 86);
    public static readonly Rect2 SoyMilk = new(328, 0, 330, 110);
    public static readonly Rect2 SoyTray = new(0, 0, 246, 86);
    // Tall tabletop objects may rise above the counter's back edge, like the fryer.
    public static readonly Rect2 Trash = new(706, -34, 146, 120);
    public static readonly Vector2 FinishedVisual = new(158, 116);
    public static readonly Vector2 SoyVisual = new(102, 110);
    public static readonly Vector2 RawYoutiaoDragVisual = new(172, 112);
    public static readonly Vector2 FinishedYoutiaoDragVisual = new(164, 110);
    public static readonly Rect2 FinishedInput = new(0, -36, 250, 122);
    public static readonly Vector2 FinishedArtPosition = new(10, 0);
    public static readonly Rect2 SoyCupInput = new(26, -22, 196, 106);
    public static readonly Vector2 SoyArtPosition = new(12, -4);
    public static readonly Rect2 FinishedCaption = new(30, 80, 190, 30);
    public static readonly Rect2 FinishedPickupHint = new(30, 80, 190, 30);
    public static readonly Rect2 SoyCaption = new(28, 80, 190, 30);
    public static readonly Rect2 SoyActions = new(246, 14, 84, 86);
    public static readonly Rect2 RawYoutiao = new(326, 54, 240, 174);
    public static readonly Rect2 FinishedYoutiao = new(326, 248, 240, 184);
    public static readonly string[] IngredientOrder =
    {
        StableIds.Ingredients.Batter, StableIds.Ingredients.Crispy, StableIds.Ingredients.Egg,
        StableIds.Ingredients.Sauce, StableIds.Ingredients.Ham, StableIds.Ingredients.Scallion,
    };

    public static WorkstationSlotSpec IngredientSlot(string id)
    {
        bool bowl = id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce;
        // Keep food above the flat floor, clear of the side and front rims.
        // These insets are measured against the trimmed ingredient tray art.
        return new WorkstationSlotSpec(
            new Vector2(280, 152),
            bowl ? new Rect2(0, 0, 228, 124) : new Rect2(0, 0, 248, 124),
            bowl ? new Rect2(58, 14, 112, 86) : new Rect2(34, 28, 180, 60),
            new Rect2(24, 120, 74, 30),
            new Rect2(98, 120, 104, 30),
            new Rect2(214, 94, 66, 56),
            new Rect2(0, 0, 208, 150),
            new Rect2(24, 150, 176, 6), 1f,
            bowl ? null : new Rect2(30, 24, 188, 68),
            new Rect2(18, 120, 190, 30));
    }

    public static Rect2 IngredientPlacement(int index) => new(
        index % 3 * 294, index / 3 * 156, 280, 152);

    public static WorkstationSlotSpec RawYoutiaoSlot() => new(
        RawYoutiao.Size, new Rect2(0, 30, 240, 128), new Rect2(34, 55, 172, 64),
        new Rect2(34, 144, 172, 30), new Rect2(), new Rect2(),
        new Rect2(0, 30, 240, 144), new Rect2(), 1f, CaptionRect: new Rect2(28, 144, 184, 30));

    public static WorkstationSlotSpec FinishedYoutiaoSlot() => new(
        FinishedYoutiao.Size, new Rect2(0, 8, 240, 142), new Rect2(36, 30, 164, 78),
        new Rect2(26, 148, 126, 30), new Rect2(152, 148, 50, 30), new Rect2(),
        new Rect2(0, 8, 240, 172), new Rect2(), 1f, CaptionRect: new Rect2(18, 148, 192, 30));
}
