using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>1920×1080 counter geometry. Appliance and stroke geometry remain unchanged.</summary>
internal static class TianjinWorkbenchLayout
{
    public static readonly Rect2 Ingredients = new(1032, 656, 868, 328);
    public static readonly Rect2 Utilities = new(1048, 570, 852, 86);
    public static readonly Rect2 Finished = new(28, 0, 250, 86);
    public static readonly Rect2 SoyMilk = new(344, 0, 246, 86);
    // Tall tabletop objects may rise above the counter's back edge, like the fryer.
    public static readonly Rect2 Trash = new(698, -46, 154, 120);
    public static readonly Vector2 FinishedVisual = new(158, 116);
    public static readonly Vector2 SoyVisual = new(102, 110);
    public static readonly Vector2 RawYoutiaoDragVisual = new(172, 112);
    public static readonly Vector2 FinishedYoutiaoDragVisual = new(164, 110);
    public static readonly Rect2 FinishedInput = new(0, -36, 250, 122);
    public static readonly Vector2 FinishedArtPosition = new(10, 0);
    public static readonly Rect2 SoyCupInput = new(8, -22, 132, 106);
    public static readonly Vector2 SoyArtPosition = new(12, -4);
    public static readonly Rect2 FinishedCaption = new(0, 60, 250, 26);
    public static readonly Rect2 FinishedPickupHint = new(148, 44, 96, 28);
    public static readonly Rect2 SoyActions = new(154, 0, 84, 86);
    public static readonly Rect2 RawYoutiao = new(326, 54, 240, 174);
    public static readonly Rect2 FinishedYoutiao = new(326, 248, 240, 184);
    public static readonly string[] IngredientOrder =
    {
        StableIds.Ingredients.Batter, StableIds.Ingredients.Crispy, StableIds.Ingredients.Egg,
        StableIds.Ingredients.Sauce, StableIds.Ingredients.Ham, StableIds.Ingredients.Scallion,
    };

    public static string ActionHint(string id) => id switch
    {
        StableIds.Ingredients.Egg or StableIds.Ingredients.Scallion => "点击",
        StableIds.Ingredients.Sauce => "炉面划动",
        _ => "拖入",
    };

    public static WorkstationSlotSpec IngredientSlot(string id)
    {
        bool bowl = id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce;
        // The food fills the vessel; refill sits below the food at the right rim.
        return new WorkstationSlotSpec(
            new Vector2(280, 164),
            bowl ? new Rect2(0, 0, 228, 136) : new Rect2(0, 0, 280, 128),
            bowl ? new Rect2(58, 18, 112, 88) : new Rect2(24, 16, 232, 96),
            new Rect2(8, 136, 64, 24),
            new Rect2(146, 136, 66, 24),
            new Rect2(214, 104, 66, 56),
            new Rect2(0, 0, 208, 164),
            new Rect2(8, 160, 198, 6), 1f);
    }

    public static Rect2 IngredientPlacement(int index) => new(
        index % 3 * 294, index / 3 * 164, 280, 164);

    public static Rect2 HintPlacement(string id) => new(
        76, 136, 68, 24);

    public static WorkstationSlotSpec RawYoutiaoSlot() => new(
        RawYoutiao.Size, new Rect2(0, 30, 240, 128), new Rect2(34, 55, 172, 64),
        new Rect2(20, 145, 200, 28), new Rect2(), new Rect2(),
        new Rect2(0, 30, 240, 144), new Rect2(), 1f);

    public static WorkstationSlotSpec FinishedYoutiaoSlot() => new(
        FinishedYoutiao.Size, new Rect2(0, 8, 240, 142), new Rect2(36, 30, 164, 78),
        new Rect2(20, 149, 140, 28), new Rect2(170, 149, 58, 28), new Rect2(),
        new Rect2(0, 8, 240, 172), new Rect2(), 1f);
}
