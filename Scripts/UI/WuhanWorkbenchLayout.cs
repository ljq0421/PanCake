using Godot;

namespace ProjectCake.UI;

/// <summary>Anchors authored against the 1672 × 941 integrated workbench, in design coordinates.</summary>
internal static class WuhanWorkbenchLayout
{
    public static readonly Vector2 DesignSize = new(1920, 1080);
    public static readonly Vector2 SourceSize = new(1672, 941);
    public static Vector2 Point(float x, float y) => new Vector2(x, y) * DesignSize / SourceSize;
    public static Rect2 Rect(float x, float y, float width, float height) => new(Point(x, y), Point(width, height));
    public static readonly Rect2 Cooker = Rect(76, 425, 432, 283);
    public static readonly Rect2 Bowl = Rect(619, 494, 246, 193);
    public static readonly Rect2 BowlFood = Rect(639, 516, 207, 112);
    public static readonly Rect2 Pan = Rect(1010, 465, 576, 245);
    public static readonly Rect2 Raw = Rect(49, 706, 322, 177);
    public static readonly Rect2 RawFood = Rect(78, 729, 263, 104);
    public static readonly Rect2 Stock = Rect(1397, 716, 216, 164);
    public static readonly Rect2 StockFood = Rect(1420, 750, 169, 91);
    public static readonly Rect2 Sauce = Rect(613, 722, 113, 126);
    public static readonly Rect2 Batter = Rect(995, 716, 180, 166);
    public static readonly Rect2 Filling = Rect(1193, 716, 190, 165);
    public static readonly Rect2 EggUi = new(520, 18, 250, 60);
    public static readonly Rect2 CoinUi = new(794, 18, 206, 60);
    public static Rect2 Ingredient(int index) => index switch
    {
        0 => Rect(382, 722, 112, 126),
        1 => Rect(729, 722, 113, 126),
        2 => Rect(498, 722, 112, 126),
        _ => Rect(846, 722, 123, 126),
    };
    public static Vector2[] PanCorners => new[] { Point(1100, 487), Point(1490, 487), Point(1516, 618), Point(1066, 618) };
    public static Vector2[] BowlOutline => new[] { Point(621, 559), Point(637, 530), Point(677, 504), Point(727, 496),
        Point(779, 502), Point(826, 526), Point(857, 557), Point(853, 598), Point(831, 642), Point(790, 674),
        Point(741, 685), Point(688, 673), Point(647, 643), Point(628, 605) };
}
