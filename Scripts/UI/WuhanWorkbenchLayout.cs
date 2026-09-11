using Godot;

namespace ProjectCake.UI;

/// <summary>Stage-specific anchors measured on the replacement 1672 × 941 pendant sheets.</summary>
internal sealed class WuhanWorkbenchLayout
{
    public static readonly Vector2 DesignSize = new(1920, 1080);
    public static readonly Vector2 SourceSize = new(1672, 941);
    public static Vector2 Point(float x, float y) => new Vector2(x, y) * DesignSize / SourceSize;
    public static Rect2 Rect(float x, float y, float width, float height) => new(Point(x, y), Point(width, height));
    public static readonly Rect2 EmbeddedTrash = Rect(1008, 870, 150, 71);
    public static readonly Rect2 EggUi = new(520, 18, 250, 60);
    public static readonly Rect2 CashPendant = Rect(1508, 184, 134, 211);
    public static readonly Vector2 CashSlot = Point(1574, 240);
    public static readonly WuhanWorkbenchLayout Noodles = new(false);
    public static readonly WuhanWorkbenchLayout Doupi = new(true);
    public static WuhanWorkbenchLayout ForStage(bool unlocked) => unlocked ? Doupi : Noodles;
    public Rect2 Cooker { get; }
    public Rect2 Bowl { get; }
    public Rect2 BowlFood { get; }
    public Rect2 Pan { get; } = Rect(1020, 476, 428, 227);
    public Rect2 Raw { get; }
    public Rect2 RawFood { get; }
    public Rect2 Stock { get; } = Rect(1280, 732, 364, 149);
    public Rect2 StockFood { get; } = Rect(1303, 754, 309, 80);
    public Rect2 Batter { get; } = Rect(1465, 603, 184, 116);
    public Rect2 DoupiEgg { get; } = Rect(1450, 494, 180, 108);
    public Rect2 DoupiEggFood { get; } = Rect(1484, 512, 109, 58);
    public Rect2 Filling { get; } = Rect(1069, 703, 205, 187);
    public Vector2[] PanCorners { get; } = new[] { Point(1094, 505), Point(1374, 505), Point(1402, 618), Point(1076, 618) };
    public Vector2[] PanOutline { get; } = new[] { Point(1058, 513), Point(1067, 489), Point(1087, 478), Point(1377, 478), Point(1397, 486), Point(1408, 513) };
    public Vector2[] BowlOutline { get; }
    public Vector2[] CookerOutline { get; }
    public Vector2[] CookerFront { get; }
    private readonly Rect2[] _ingredients;
    private readonly Vector2 _basketHome;
    public Rect2 Ingredient(int index) => _ingredients[index];
    public Vector2 BasketHome(int index, int count) => _basketHome + Point(count == 2 ? (index == 0 ? -65 : 65) : 0, 0);

    private WuhanWorkbenchLayout(bool doupi)
    {
        Cooker = Rect(60, 435, 424, 269);
        Bowl = Rect(631, 463, 256, 204);
        BowlFood = Rect(652, 488, 214, 109);
        Raw = Rect(43, 702, 366, 178);
        RawFood = Rect(76, 723, 302, 111);
        _ingredients = new[] { Rect(424, 719, 143, 134), Rect(719, 719, 144, 137), Rect(572, 719, 143, 136), Rect(868, 719, 149, 136) };
        _basketHome = Point(268, 501);
        Vector2[] bowlShape = { new(0, .38f), new(.025f, .26f), new(.10f, .145f), new(.23f, .05f),
            new(.40f, .005f), new(.59f, .005f), new(.77f, .06f), new(.91f, .17f), new(.98f, .30f),
            new(1, .42f), new(.95f, .62f), new(.85f, .80f), new(.74f, .93f), new(.59f, .995f),
            new(.42f, 1), new(.26f, .93f), new(.14f, .79f), new(.06f, .60f) };
        BowlOutline = bowlShape.Select(p => Bowl.Position + p * Bowl.Size).ToArray();
        Vector2[] potShape = { new(0, .51f), new(.018f, .36f), new(.083f, .31f), new(.105f, .22f),
            new(.16f, .14f), new(.26f, .065f), new(.39f, .015f), new(.51f, 0), new(.65f, .025f),
            new(.79f, .09f), new(.89f, .19f), new(.93f, .31f), new(.985f, .34f), new(1, .52f) };
        CookerOutline = potShape.Select(p => Cooker.Position + p * Cooker.Size).ToArray();
        float cx = 270, cy = 550, rx = 169, ry = 70;
        CookerFront = Enumerable.Range(0, 25).Select(i => {
            float angle = i * Mathf.Pi / 24;
            return Point(cx + rx * Mathf.Cos(angle), cy + ry * Mathf.Sin(angle));
        }).Concat(new[] { Point(cx - rx, 697), Point(cx + rx, 697) }).ToArray();
    }
}
