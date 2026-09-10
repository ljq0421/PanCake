using Godot;

namespace ProjectCake.UI;

/// <summary>Stage-specific anchors measured on the 1672 × 941 v2 sheets.</summary>
internal sealed class WuhanWorkbenchLayout
{
    public static readonly Vector2 DesignSize = new(1920, 1080);
    public static readonly Vector2 SourceSize = new(1672, 941);
    public static Vector2 Point(float x, float y) => new Vector2(x, y) * DesignSize / SourceSize;
    public static Rect2 Rect(float x, float y, float width, float height) => new(Point(x, y), Point(width, height));
    public static readonly Rect2 EggUi = new(520, 18, 250, 60);
    public static readonly Rect2 CoinUi = new(794, 18, 206, 60);
    public static readonly WuhanWorkbenchLayout Noodles = new(false);
    public static readonly WuhanWorkbenchLayout Doupi = new(true);
    public static WuhanWorkbenchLayout ForStage(bool unlocked) => unlocked ? Doupi : Noodles;
    public Rect2 Cooker { get; }
    public Rect2 Bowl { get; }
    public Rect2 BowlFood { get; }
    public Rect2 Pan { get; } = Rect(1052, 459, 560, 274);
    public Rect2 Raw { get; }
    public Rect2 RawFood { get; }
    public Rect2 Stock { get; } = Rect(1414, 744, 231, 133);
    public Rect2 StockFood { get; } = Rect(1440, 765, 178, 76);
    public Rect2 Batter { get; } = Rect(1047, 739, 179, 142);
    public Rect2 Filling { get; } = Rect(1235, 734, 174, 158);
    public Vector2[] PanCorners { get; } = new[] { Point(1124, 491), Point(1521, 491), Point(1550, 642), Point(1107, 642) };
    public Vector2[] PanOutline { get; } = new[] { Point(1090, 514), Point(1099, 478), Point(1114, 465), Point(1145, 460), Point(1494, 460), Point(1534, 469), Point(1548, 514) };
    public Vector2[] BowlOutline { get; }
    public Vector2[] CookerOutline { get; }
    public Vector2[] CookerFront { get; }
    private readonly Rect2[] _ingredients;
    private readonly Vector2 _basketHome;
    public Rect2 Ingredient(int index) => _ingredients[index];
    public Vector2 BasketHome(int index, int count) => _basketHome + Point(count == 2 ? (index == 0 ? -65 : 65) : 0, 0);

    private WuhanWorkbenchLayout(bool doupi)
    {
        Cooker = doupi ? Rect(72, 427, 423, 274) : Rect(76, 428, 437, 282);
        Bowl = doupi ? Rect(649, 465, 256, 199) : Rect(693, 465, 278, 211);
        BowlFood = doupi ? Rect(669, 490, 216, 108) : Rect(714, 491, 235, 116);
        Raw = doupi ? Rect(46, 702, 351, 171) : Rect(48, 707, 365, 184);
        RawFood = doupi ? Rect(77, 717, 277, 109) : Rect(81, 729, 291, 110);
        _ingredients = doupi
            ? new[] { Rect(436, 715, 142, 133), Rect(730, 713, 145, 136), Rect(584, 714, 142, 135), Rect(879, 714, 146, 137) }
            : new[] { Rect(485, 718, 157, 139), Rect(831, 717, 165, 142), Rect(655, 718, 168, 141), Rect(1006, 717, 175, 143) };
        _basketHome = Point(doupi ? 279 : 291, doupi ? 499 : 505);
        Vector2[] bowlShape = { new(0, .38f), new(.025f, .26f), new(.10f, .145f), new(.23f, .05f),
            new(.40f, .005f), new(.59f, .005f), new(.77f, .06f), new(.91f, .17f), new(.98f, .30f),
            new(1, .42f), new(.95f, .62f), new(.85f, .80f), new(.74f, .93f), new(.59f, .995f),
            new(.42f, 1), new(.26f, .93f), new(.14f, .79f), new(.06f, .60f) };
        BowlOutline = bowlShape.Select(p => Bowl.Position + p * Bowl.Size).ToArray();
        Vector2[] potShape = { new(0, .51f), new(.018f, .36f), new(.083f, .31f), new(.105f, .22f),
            new(.16f, .14f), new(.26f, .065f), new(.39f, .015f), new(.51f, 0), new(.65f, .025f),
            new(.79f, .09f), new(.89f, .19f), new(.93f, .31f), new(.985f, .34f), new(1, .52f) };
        CookerOutline = potShape.Select(p => Cooker.Position + p * Cooker.Size).ToArray();
        float cx = doupi ? 282 : 294, cy = doupi ? 540 : 548, rx = doupi ? 169 : 174, ry = doupi ? 74 : 76;
        CookerFront = Enumerable.Range(0, 25).Select(i => {
            float angle = i * Mathf.Pi / 24;
            return Point(cx + rx * Mathf.Cos(angle), cy + ry * Mathf.Sin(angle));
        }).Concat(new[] { Point(cx - rx, doupi ? 697 : 706), Point(cx + rx, doupi ? 697 : 706) }).ToArray();
    }
}
