using Godot;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.Pancake;

namespace ProjectCake.UI;

/*
THESIS: one portion owns one row and its ingredient icons; delivery changes that row's paper.
OWN-WORLD: warm outlined paper in Tianjin, ivory and teal in Wuhan, existing food art.
STORY: match the main food and extras, prepare it, then see only its region turn green.
FIRST VIEWPORT: equal-width food rows above one shared side-product row and a patience bar.
FORM: the user's approved icon-only order bubble; no names, ordinals, totals or status copy.
FINISH: verify both cities at 1080p and 720p, partial deliveries, and unchanged drop targets.
*/
public partial class OrderBubbleView : PanelContainer
{
    private const float MainHeight = 54;
    private const float SideHeight = 44;
    private VBoxContainer _content = null!;
    private VBoxContainer _rows = null!;
    private readonly List<(int Line, int Portion, PanelContainer Region, Label? Quantity)> _regions = new();
    private readonly Dictionary<Texture2D, Texture2D> _trimmed = new();
    private TianjinArtCatalog _shared = null!;
    private WuhanArtCatalog? _wuhan;
    private Color _paper;
    private Color _ink;
    private Color _rule;
    private readonly Color _complete = new("#DCECC8");
    private OrderData? _order;
    public ProgressBar Patience { get; private set; } = null!;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        Configure(new TianjinArtCatalog());
        Resized += QueueRedraw;
    }

    public void Configure(TianjinArtCatalog art, WuhanArtCatalog? wuhan = null)
    {
        _shared = art;
        _wuhan = wuhan;
        _paper = wuhan is null ? TianjinUi.Paper : WuhanUi.Paper;
        _ink = wuhan is null ? TianjinUi.BrownDark : WuhanUi.Ink;
        _rule = wuhan is null ? new Color("#CDB38E") : new Color("#BAC9B8");
        QueueRedraw();
    }

    public override void _Draw()
    {
        // Draw outside the paper without letting the tail affect container sizing or input.
        float x = Size.X * .5f;
        Vector2[] tail = { new(x - 15, Size.Y - 4), new(x, Size.Y + 12), new(x + 15, Size.Y - 4) };
        DrawColoredPolygon(tail, _paper);
        DrawPolyline(tail, _ink, 4, true);
    }

    public void Render(OrderData order, OrderProgress progress, IReadOnlyDictionary<string, RecipeData> recipes)
    {
        if (!ReferenceEquals(_order, order))
        {
            _order = order;
            _regions.Clear();
            foreach (Node child in _rows.GetChildren()) { _rows.RemoveChild(child); child.QueueFree(); }
            for (int lineIndex = 0; lineIndex < order.Lines.Count; lineIndex++)
            {
                OrderLineData line = order.Lines[lineIndex];
                if (!IsMain(line.ProductKind)) continue;
                for (int portion = 0; portion < line.Quantity; portion++)
                {
                    AddRule();
                    PanelContainer region = Region("OrderMainRow", MainHeight, lineIndex, portion);
                    var icons = new HBoxContainer { Name = "OrderIcons", MouseFilter = MouseFilterEnum.Ignore };
                    icons.AddThemeConstantOverride("separation", 12);
                    region.AddChild(icons);
                    icons.AddChild(ProductIcon(line.ProductKind, new Vector2(62, 46)));
                    if (line.ProductKind == ProductKind.Pancake && line.Sauce != SaucePreference.Normal)
                    {
                        TextureRect sauce = Icon(_shared.SaucePreferenceIcon(line.Sauce), new Vector2(28, 38), "OrderSauceIcon");
                        sauce.SetMeta("sauce", (int)line.Sauce);
                        icons.AddChild(sauce);
                    }
                    if (recipes.TryGetValue(line.DefinitionId, out RecipeData? recipe))
                        foreach (string ingredient in recipe.ExtraIngredients)
                        {
                            Texture2D texture = _wuhan is null ? _shared.Ingredient(ingredient) : _wuhan.Ingredient(ingredient);
                            TextureRect topping = Icon(texture, new Vector2(44, 40), $"OrderIngredientIcon_{ingredient}");
                            topping.SetMeta("ingredient_id", ingredient);
                            icons.AddChild(topping);
                        }
                    _rows.AddChild(region);
                    _regions.Add((lineIndex, portion, region, null));
                }
            }
            int[] sides = Enumerable.Range(0, order.Lines.Count).Where(i => !IsMain(order.Lines[i].ProductKind)).ToArray();
            if (sides.Length > 0)
            {
                AddRule();
                var sideRow = new HBoxContainer { Name = "OrderSideRow", MouseFilter = MouseFilterEnum.Ignore };
                sideRow.AddThemeConstantOverride("separation", 0);
                _rows.AddChild(sideRow);
                foreach (int index in sides)
                {
                    if (sideRow.GetChildCount() > 0)
                        sideRow.AddChild(new ColorRect { Color = _rule, CustomMinimumSize = new Vector2(1, 0), MouseFilter = MouseFilterEnum.Ignore });
                    PanelContainer region = Region("OrderSideProduct", SideHeight, index, -1);
                    region.SizeFlagsHorizontal = SizeFlags.ExpandFill;
                    // Each side owns an equal share, independent of the texture or fraction width.
                    var icons = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center, MouseFilter = MouseFilterEnum.Ignore };
                    icons.AddThemeConstantOverride("separation", 8);
                    region.AddChild(icons);
                    icons.AddChild(ProductIcon(order.Lines[index].ProductKind, new Vector2(46, 36)));
                    Label quantity = TianjinUi.Label("", 22, _ink);
                    quantity.Name = "OrderQuantity";
                    quantity.MouseFilter = MouseFilterEnum.Ignore;
                    quantity.CustomMinimumSize = new Vector2(40, 0);
                    icons.AddChild(quantity);
                    sideRow.AddChild(region);
                    _regions.Add((index, -1, region, quantity));
                }
            }
        }
        foreach (var entry in _regions)
        {
            int delivered = progress.GetDeliveredQuantity(entry.Line);
            bool done = entry.Portion >= 0 ? delivered > entry.Portion : delivered >= order.Lines[entry.Line].Quantity;
            ((StyleBoxFlat)entry.Region.GetThemeStylebox("panel")).BgColor = done ? _complete : _paper;
            entry.Region.SetMeta("complete", done);
            if (entry.Quantity is not null) entry.Quantity.Text = $"{delivered}/{order.Lines[entry.Line].Quantity}";
        }
    }

    private static bool IsMain(ProductKind kind) => kind is ProductKind.Pancake or ProductKind.HotDryNoodles;

    private PanelContainer Region(string name, float height, int line, int portion)
    {
        var region = new PanelContainer { Name = $"{name}_{line}_{portion}", CustomMinimumSize = new Vector2(0, height), MouseFilter = MouseFilterEnum.Ignore };
        StyleBoxFlat style = Flat(_paper);
        style.ContentMarginLeft = style.ContentMarginRight = 6;
        style.ContentMarginTop = style.ContentMarginBottom = 4;
        region.AddThemeStyleboxOverride("panel", style);
        region.SetMeta("line_index", line);
        region.SetMeta("portion", portion);
        return region;
    }

    private void AddRule()
    {
        if (_rows.GetChildCount() > 0)
            _rows.AddChild(new ColorRect { Name = "OrderRule", Color = _rule, CustomMinimumSize = new Vector2(0, 1), MouseFilter = MouseFilterEnum.Ignore });
    }

    private Control ProductIcon(ProductKind kind, Vector2 size)
    {
        if (kind != ProductKind.HotDryNoodles || _wuhan is null)
            return Icon(_wuhan is null ? _shared.Product(kind) : _wuhan.Product(kind), size, "OrderProductIcon");
        // The noodle texture is a food layer; place it in the same bowl as the workbench.
        var bowl = new Control { Name = "OrderProductIcon", CustomMinimumSize = size, MouseFilter = MouseFilterEnum.Ignore };
        TextureRect baseLayer = Icon(_wuhan.Texture("empty_bowl"), size, "Bowl");
        bowl.AddChild(baseLayer);
        TianjinUi.FullRect(baseLayer);
        TextureRect noodles = Icon(_wuhan.Texture("mixed"), new Vector2(size.X * .78f, size.Y * .55f), "Noodles");
        noodles.Position = new Vector2(size.X * .11f, size.Y * .04f);
        bowl.AddChild(noodles);
        return bowl;
    }

    private TextureRect Icon(Texture2D texture, Vector2 size, string name)
    {
        if (!_trimmed.TryGetValue(texture, out Texture2D? trimmed))
        {
            using Image image = texture.GetImage();
            // Ignore the nearly transparent matte residue in generated food layers,
            // as the Wuhan workbench does; otherwise tiny icons inherit huge padding.
            image.Convert(Image.Format.Rgba8);
            byte[] pixels = image.GetData();
            int width = image.GetWidth(), height = image.GetHeight();
            int left = width, top = height, right = -1, bottom = -1;
            for (int y = 0; y < height; y++)
            for (int x = 0; x < width; x++)
                if (pixels[(y * width + x) * 4 + 3] >= 32)
                {
                    left = Math.Min(left, x); right = Math.Max(right, x);
                    top = Math.Min(top, y); bottom = Math.Max(bottom, y);
                }
            Rect2I bounds = right >= left ? new Rect2I(left, top, right - left + 1, bottom - top + 1) : default;
            trimmed = bounds.HasArea() ? new AtlasTexture { Atlas = texture, Region = bounds } : texture;
            _trimmed[texture] = trimmed;
        }
        TextureRect icon = TianjinUi.Texture(trimmed, size);
        icon.Name = name;
        icon.MouseFilter = MouseFilterEnum.Ignore;
        icon.SizeFlagsVertical = SizeFlags.ShrinkCenter;
        return icon;
    }

    private static StyleBoxFlat Flat(Color color) => new()
    {
        BgColor = color, ContentMarginLeft = 0, ContentMarginRight = 0,
        ContentMarginTop = 0, ContentMarginBottom = 0,
    };
}
