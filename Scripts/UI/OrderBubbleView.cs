using Godot;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.Pancake;

namespace ProjectCake.UI;

/*
THESIS: toppings stay with their portion; plain products can share a row with independent delivery regions.
OWN-WORLD: warm outlined paper in Tianjin, ivory and teal in Wuhan, existing food art.
STORY: match the main food and extras, prepare it, then see only its region turn green.
FIRST VIEWPORT: compact equal-width product rows, toppings in a grid, one patience bar.
FORM: the user's approved icon-only order bubble; no names, ordinals, totals or status copy.
FINISH: verify both cities at 1080p and 720p, partial deliveries, and unchanged drop targets.
*/
public partial class OrderBubbleView : PanelContainer
{
    public const float CompactWidth = 184;
    private const float CompactRowHeight = 58;
    private static readonly Vector2 CompactProductSize = new(74, 54);
    private static readonly Vector2 CompactToppingSize = new(36, 26);
    private const float MainHeight = 54;
    private const float SideHeight = 44;
    private static int WuhanToppingOrder(string ingredient) => ingredient switch
    {
        StableIds.Ingredients.WuhanChiliOil => 0,
        StableIds.Ingredients.WuhanScallion => 1,
        StableIds.Ingredients.WuhanBraisedBeef => 2,
        _ => 3,
    };
    private VBoxContainer _content = null!;
    private VBoxContainer _rows = null!;
    private readonly List<(int Line, int Portion, PanelContainer Region, Label? Quantity)> _regions = new();
    private readonly Dictionary<Texture2D, Texture2D> _trimmed = new();
    private static readonly Dictionary<(Texture2D Source, Vector2 Size), Texture2D> CompactIcons = new();
    private TianjinArtCatalog _shared = null!;
    private WuhanArtCatalog? _wuhan;
    private XianArtCatalog? _xian;
    private bool _xianSelected;
    private Color _paper;
    private Color _ink;
    private Color _rule;
    private Color _frameInk;
    private StyleBoxTexture _frame = null!;
    private StyleBoxFlat? _selectionOutline;
    private const float FrameScale = .4f;
    private const float OrnamentOverhang = 24;
    private readonly Color _complete = new("#DCECC8");
    private OrderData? _order;
    private float _arrivalPaperScale = 1;

    public void SetArrivalMotion(double age, bool reduced)
    {
        float reveal = Math.Clamp((float)((age - .24) / .11), 0, 1);
        Modulate = new Color(1, 1, 1, reveal);
        float scale = reduced ? 1 : Mathf.Lerp(.96f, 1, 1 - MathF.Pow(1 - reveal, 3));
        if (Mathf.IsEqualApprox(_arrivalPaperScale, scale)) return;
        _arrivalPaperScale = scale;
        QueueRedraw();
    }
    private bool _compactLayout;
    private OrderProgress? _progress;
    private IReadOnlyDictionary<string, RecipeData>? _recipes;

    public OrderBubbleView? CreatePaperCopy(Control host)
    {
        if (_order is null || _progress is null || _recipes is null) return null;
        var copy = GD.Load<PackedScene>("res://Scenes/UI/OrderBubbleView.tscn").Instantiate<OrderBubbleView>();
        copy.Name = "CompletedOrderPaper";
        host.AddChild(copy);
        copy.Configure(_shared); copy.ConfigureTianjinPaper();
        copy.Render(_order, _progress, _recipes);
        copy.Position = host.GetGlobalTransform().AffineInverse() * GlobalPosition;
        copy.Size = Size; copy.Patience.Hide();
        return copy;
    }
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
        ApplyFrame(wuhan is null ? "tianjin" : "wuhan", _ink);
        QueueRedraw();
    }

    // Explicit opt-in: Xi'an keeps its existing horizontal layout.
    public void ConfigureCompactLayout()
    {
        _compactLayout = true;
        ApplyContentMargins();
        CustomMinimumSize = new Vector2(CompactWidth, 0);
        Size = new Vector2(CompactWidth, Size.Y);
    }

    public void ConfigureTianjinPaper()
    {
        ConfigureCompactLayout();
        _paper = new Color("#FAF2DF"); _ink = TianjinUi.BrownDark;
        _rule = new Color("#CDB38E", .7f);
        ApplyFrame("tianjin", TianjinUi.BrownDark);
        QueueRedraw();
    }

    public override void _Draw()
    {
        // Slice beyond the complete ornaments and corner curves, then draw at UI scale.
        // Only straight edges and paper stretch; ornaments sit above the content box.
        Vector2 arrivalOffset = new Vector2(Size.X * .5f, Size.Y + 12) * (1 - _arrivalPaperScale);
        DrawSetTransform(arrivalOffset + new Vector2(0, -OrnamentOverhang) * _arrivalPaperScale,
            0, Vector2.One * FrameScale * _arrivalPaperScale);
        Vector2 frameSize = new(Size.X / FrameScale, (Size.Y + OrnamentOverhang) / FrameScale);
        DrawStyleBox(_frame, new Rect2(Vector2.Zero, frameSize));
        // The Wuhan source has a cut-out at the old tail. Use an intact straight strip
        // for the entire lower middle, keeping all three cities continuous at any width.
        float left = _frame.TextureMarginLeft, right = _frame.TextureMarginRight;
        float bottom = _frame.TextureMarginBottom;
        DrawTextureRectRegion(_frame.Texture,
            new Rect2(left, frameSize.Y - bottom, frameSize.X - left - right, bottom),
            new Rect2(left, _frame.Texture.GetHeight() - bottom, 64, bottom));
        DrawSetTransform(arrivalOffset, 0, Vector2.One * _arrivalPaperScale);
        float x = Size.X * .5f;
        Vector2[] tail = { new(x - 15, Size.Y - 9), new(x, Size.Y + 12), new(x + 15, Size.Y - 9) };
        DrawColoredPolygon(tail, _paper);
        DrawPolyline(tail, _frameInk, 3, true);
        if (_xianSelected)
        {
            Color selected = new("#DB922E");
            if (_selectionOutline is null)
            {
                _selectionOutline = new StyleBoxFlat { BgColor = Colors.Transparent, BorderColor = selected };
                _selectionOutline.SetBorderWidthAll(2);
                _selectionOutline.SetCornerRadiusAll(12);
            }
            DrawStyleBox(_selectionOutline, new Rect2(6, 0, Size.X - 12, Size.Y - 6));
        }
    }

    public void ConfigureXian(XianArtCatalog art)
    {
        _xian = art;
        _paper = new Color("#FFF1D9"); _ink = new Color("#513D32"); _rule = new Color("#D7B98B");
        ApplyFrame("xian", new Color("#873F38"));
        Patience.AddThemeStyleboxOverride("fill", Patience.GetThemeStylebox("fill").Duplicate() as StyleBox);
    }

    public void RenderXianState(double remaining, bool selected)
    {
        PatienceBarPresentation.Render(Patience, remaining);
        _xianSelected = selected;
        QueueRedraw();
    }

    private void ApplyFrame(string city, Color frameInk)
    {
        _frameInk = frameInk;
        _frame = GD.Load<StyleBoxTexture>($"res://resource/art/OrderBubbleUI/frame-{city}.tres");
        using Image paperImage = _frame.Texture.GetImage();
        _paper = paperImage.GetPixel(130, paperImage.GetHeight() - 40);
        ApplyContentMargins();
        _content.AddThemeConstantOverride("separation", 3);
        Patience.CustomMinimumSize = new Vector2(0, 6);
        var track = Flat(new Color("#E2D6BF")); track.SetCornerRadiusAll(3);
        var fill = Flat(PatienceBarPresentation.Green); fill.SetCornerRadiusAll(3);
        Patience.AddThemeStyleboxOverride("background", track);
        Patience.AddThemeStyleboxOverride("fill", fill);
        QueueRedraw();
    }

    private void ApplyContentMargins() => AddThemeStyleboxOverride("panel", new StyleBoxEmpty {
        // Reclaim inner whitespace for larger food, keeping the three-row card's height.
        ContentMarginLeft = _compactLayout ? 12 : 18,
        ContentMarginRight = _compactLayout ? 12 : 18,
        ContentMarginTop = _compactLayout ? 6 : 18,
        ContentMarginBottom = 12,
    });

    public void Render(OrderData order, OrderProgress progress, IReadOnlyDictionary<string, RecipeData> recipes)
    {
        _progress = progress; _recipes = recipes;
        if (!ReferenceEquals(_order, order))
        {
            _order = order;
            _regions.Clear();
            foreach (Node child in _rows.GetChildren()) { _rows.RemoveChild(child); child.QueueFree(); }
            int[] sides = Enumerable.Range(0, order.Lines.Count).Where(i => !IsMain(order.Lines[i].ProductKind)).ToArray();
            (int Line, int Portion)? pairedMain = null;
            if (_compactLayout && sides.Length == 1)
            {
                // Two side types belong together. Only a lone side joins a plain main.
                for (int i = 0; i < order.Lines.Count; i++)
                    if (IsPlainMain(order.Lines[i], recipes)) pairedMain = (i, order.Lines[i].Quantity - 1);
            }
            for (int lineIndex = 0; lineIndex < order.Lines.Count; lineIndex++)
            {
                OrderLineData line = order.Lines[lineIndex];
                if (!IsMain(line.ProductKind)) continue;
                for (int portion = 0; portion < line.Quantity; portion++)
                {
                    if (pairedMain == (lineIndex, portion)) continue;
                    AddRule();
                    PanelContainer region = Region("OrderMainRow", _compactLayout ? CompactRowHeight : MainHeight, lineIndex, portion);
                    var icons = new HBoxContainer { Name = "OrderIcons", MouseFilter = MouseFilterEnum.Ignore,
                        Alignment = _compactLayout ? BoxContainer.AlignmentMode.Center : BoxContainer.AlignmentMode.Begin };
                    icons.AddThemeConstantOverride("separation", _compactLayout ? 6 : 12);
                    region.AddChild(icons);
                    icons.AddChild(ProductIcon(line.ProductKind, _compactLayout ? CompactProductSize : new Vector2(62, 46)));
                    var toppings = new List<Control>();
                    if (line.ProductKind == ProductKind.Pancake && line.Sauce != SaucePreference.Normal)
                    {
                        TextureRect sauce = Icon(_shared.SaucePreferenceIcon(line.Sauce),
                            _compactLayout ? CompactToppingSize : new Vector2(28, 38), "OrderSauceIcon");
                        sauce.SetMeta("sauce", (int)line.Sauce);
                        toppings.Add(sauce);
                    }
                    if (_xian is not null && recipes.TryGetValue(line.DefinitionId, out var xianRecipe) && xianRecipe is XianRecipeData xr)
                    {
                        if (xr.MeatPortions > 1) toppings.Add(Icon(_xian.Texture("多肉订单小图标"), new Vector2(44, 40), "OrderExtraMeat"));
                        if (xr.HasJuice) toppings.Add(Icon(_xian.Texture("加汁订单小图标"), new Vector2(32, 40), "OrderJuice"));
                    }
                    else if (recipes.TryGetValue(line.DefinitionId, out RecipeData? recipe))
                        foreach (string ingredient in line.ProductKind == ProductKind.HotDryNoodles
                            ? recipe.ExtraIngredients.OrderBy(WuhanToppingOrder)
                            : recipe.ExtraIngredients.AsEnumerable())
                        {
                            Texture2D texture = _wuhan is null ? _shared.Ingredient(ingredient) : _wuhan.Ingredient(ingredient);
                            TextureRect topping = Icon(texture,
                                _compactLayout ? CompactToppingSize : new Vector2(44, 40), $"OrderIngredientIcon_{ingredient}");
                            topping.SetMeta("ingredient_id", ingredient);
                            toppings.Add(topping);
                        }
                    if (_compactLayout && toppings.Count > 0)
                    {
                        var grid = new GridContainer { Name = "OrderToppings", Columns = toppings.Count > 2 ? 2 : 1,
                            MouseFilter = MouseFilterEnum.Ignore, SizeFlagsVertical = SizeFlags.ShrinkCenter };
                        grid.AddThemeConstantOverride("h_separation", 4);
                        grid.AddThemeConstantOverride("v_separation", 2);
                        icons.AddChild(grid);
                        foreach (Control topping in toppings) grid.AddChild(topping);
                    }
                    else foreach (Control topping in toppings) icons.AddChild(topping);
                    _rows.AddChild(region);
                    _regions.Add((lineIndex, portion, region, null));
                }
            }
            if (_compactLayout)
            {
                if (pairedMain is { } main)
                    AddSimpleRow(order, new[] { main, (sides[0], -1) });
                else if (sides.Length > 1)
                    foreach (int[] pair in sides.Chunk(2))
                        AddSimpleRow(order, pair.Select(index => (index, -1)).ToArray());
                else foreach (int index in sides)
                {
                    AddRule();
                    PanelContainer region = Region("OrderSideProduct", CompactRowHeight, index, -1);
                    var icons = new HBoxContainer { Name = "OrderIcons", Alignment = BoxContainer.AlignmentMode.Center,
                        MouseFilter = MouseFilterEnum.Ignore };
                    icons.AddThemeConstantOverride("separation", 6);
                    region.AddChild(icons);
                    // Keep the product on the row's centerline even when a quantity is shown.
                    var product = new Control { Name = "CenteredSideProduct", CustomMinimumSize = CompactProductSize,
                        MouseFilter = MouseFilterEnum.Ignore, SizeFlagsVertical = SizeFlags.ShrinkCenter };
                    Control icon = ProductIcon(order.Lines[index].ProductKind, CompactProductSize);
                    product.AddChild(icon); icon.Size = CompactProductSize;
                    icons.AddChild(product);
                    Label? quantity = null;
                    if (order.Lines[index].Quantity > 1)
                    {
                        quantity = TianjinUi.Label("", 18, _ink);
                        quantity.Name = "OrderQuantity";
                        quantity.MouseFilter = MouseFilterEnum.Ignore;
                        quantity.Position = new Vector2(CompactProductSize.X + 2, 0);
                        quantity.Size = new Vector2(36, CompactProductSize.Y);
                        product.AddChild(quantity);
                    }
                    _rows.AddChild(region);
                    _regions.Add((index, -1, region, quantity));
                }
            }
            else if (sides.Length > 0)
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
            // The illustrated paper remains visible below incomplete rows. This leaves the
            // stretchable outer frame unobscured while completed portions still read green.
            ((StyleBoxFlat)entry.Region.GetThemeStylebox("panel")).BgColor = done ? _complete : Colors.Transparent;
            entry.Region.SetMeta("complete", done);
            if (entry.Quantity is not null) entry.Quantity.Text = $"{delivered}/{order.Lines[entry.Line].Quantity}";
        }
    }

    internal Control? LastDeliveredIcon(int line)
    {
        if (_order is null || _progress is null) return null;
        foreach (var entry in _regions)
        {
            if (entry.Line != line) continue;
            int delivered = _progress.GetDeliveredQuantity(entry.Line);
            if (delivered <= 0 || entry.Portion >= 0 && entry.Portion != delivered - 1) continue;
            return entry.Region.FindChild("OrderProductIcon", true, false) as Control;
        }
        return null;
    }

    private static bool IsMain(ProductKind kind) => kind is ProductKind.Pancake or ProductKind.HotDryNoodles or ProductKind.Roujiamo;

    private static bool IsPlainMain(OrderLineData line, IReadOnlyDictionary<string, RecipeData> recipes) =>
        IsMain(line.ProductKind) && recipes.TryGetValue(line.DefinitionId, out RecipeData? recipe)
        && recipe.ExtraIngredients.Count == 0
        && (line.ProductKind != ProductKind.Pancake || line.Sauce == SaucePreference.Normal);

    private void AddSimpleRow(OrderData order, (int Line, int Portion)[] entries)
    {
        AddRule();
        var row = new HBoxContainer { Name = "OrderSimpleRow", MouseFilter = MouseFilterEnum.Ignore };
        row.AddThemeConstantOverride("separation", 4);
        _rows.AddChild(row);
        float[] widths = entries.Select(entry => SimpleProductWidth(order.Lines[entry.Line].ProductKind)).ToArray();
        bool[] hasQuantity = entries.Select(entry => entry.Portion < 0 && order.Lines[entry.Line].Quantity > 1).ToArray();
        // Use visible artwork proportions, not padded source canvases. Reserve quantity
        // space before fitting food, so the shared row never crops or overlaps either.
        float fixedWidth = entries.Length * 4 + (entries.Length - 1) * 4 + hasQuantity.Count(value => value) * 34;
        float fit = Math.Min(1, (CompactWidth - 24 - fixedWidth) / widths.Sum());
        for (int i = 0; i < entries.Length; i++)
        {
            var entry = entries[i];
            PanelContainer region = Region(entry.Portion >= 0 ? "OrderMainRow" : "OrderSideProduct",
                CompactRowHeight, entry.Line, entry.Portion);
            region.SetMeta("shared_row", true);
            region.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            var icons = new HBoxContainer { Name = "OrderIcons", Alignment = BoxContainer.AlignmentMode.Center,
                MouseFilter = MouseFilterEnum.Ignore };
            icons.AddThemeConstantOverride("separation", 2);
            region.AddChild(icons);
            // Container minimum sizes round upward; whole pixels prevent a one-pixel overflow.
            var size = new Vector2(MathF.Floor(widths[i] * fit), CompactProductSize.Y);
            icons.AddChild(ProductIcon(order.Lines[entry.Line].ProductKind, size));
            Label? quantity = null;
            if (hasQuantity[i])
            {
                quantity = TianjinUi.Label("", 18, _ink);
                quantity.Name = "OrderQuantity";
                quantity.MouseFilter = MouseFilterEnum.Ignore;
                quantity.CustomMinimumSize = new Vector2(32, 0);
                icons.AddChild(quantity);
            }
            row.AddChild(region);
            _regions.Add((entry.Line, entry.Portion, region, quantity));
        }
    }

    private float SimpleProductWidth(ProductKind kind)
    {
        Texture2D source = kind == ProductKind.HotDryNoodles && _wuhan is not null
            ? _wuhan.Texture("empty_bowl") : _wuhan is null ? _shared.Product(kind) : _wuhan.Product(kind);
        Texture2D prepared = PrepareCompactIcon(source, CompactProductSize);
        return Math.Min(CompactProductSize.X, CompactProductSize.Y * prepared.GetWidth() / prepared.GetHeight());
    }

    private PanelContainer Region(string name, float height, int line, int portion)
    {
        var region = new PanelContainer { Name = $"{name}_{line}_{portion}", CustomMinimumSize = new Vector2(0, height), MouseFilter = MouseFilterEnum.Ignore };
        StyleBoxFlat style = Flat(Colors.Transparent);
        style.ContentMarginLeft = style.ContentMarginRight = _compactLayout ? 2 : 6;
        style.ContentMarginTop = style.ContentMarginBottom = _compactLayout ? 2 : 4;
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
        if (_xian is not null && kind is ProductKind.Roujiamo or ProductKind.Hulatang)
            return Icon(_xian.Texture(kind == ProductKind.Roujiamo ? "通用卡通腊汁肉夹馍成品" : "成品肉丸胡辣汤"), size, "OrderProductIcon");
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
        if (_compactLayout)
        {
            Texture2D prepared = PrepareCompactIcon(texture, size);
            var compactIcon = new TextureRect { Texture = prepared, Name = name, CustomMinimumSize = size,
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
                TextureFilter = TextureFilterEnum.LinearWithMipmaps,
                MouseFilter = MouseFilterEnum.Ignore, SizeFlagsVertical = SizeFlags.ShrinkCenter };
            // Prepared textures are transient; choose the existing ink from source identity.
            if (FoodInk.AppliesTo(texture)) compactIcon.Material = FoodInk.Material(order: true);
            return compactIcon;
        }
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
        FoodInk.Apply(icon, order: true);
        icon.Name = name;
        icon.MouseFilter = MouseFilterEnum.Ignore;
        icon.SizeFlagsVertical = SizeFlags.ShrinkCenter;
        return icon;
    }

    private static Texture2D PrepareCompactIcon(Texture2D texture, Vector2 size)
    {
        var key = (texture, size);
        if (CompactIcons.TryGetValue(key, out Texture2D? prepared)) return prepared;
        using Image source = texture.GetImage();
        source.Convert(Image.Format.Rgba8);
        Rect2I bounds = CompactIconBounds(source);
        if (bounds.HasArea())
        {
            // A tight atlas cuts off the ink at the quad's boundary. Keep two display
            // pixels of transparent guard, recalculated for the final shared-row size.
            float fit = Math.Min((size.X - 4) / bounds.Size.X, (size.Y - 4) / bounds.Size.Y);
            int padding = (int)Math.Ceiling(2 / fit);
            using Image padded = Image.CreateEmpty(bounds.Size.X + padding * 2, bounds.Size.Y + padding * 2,
                false, Image.Format.Rgba8);
            padded.Fill(Colors.Transparent);
            padded.BlitRect(source, bounds, new Vector2I(padding, padding));
            padded.FixAlphaEdges();
            padded.GenerateMipmaps();
            prepared = ImageTexture.CreateFromImage(padded);
        }
        else prepared = texture;
        return CompactIcons[key] = prepared;
    }

    private static Rect2I CompactIconBounds(Image image)
    {
        byte[] pixels = image.GetData();
        int width = image.GetWidth(), height = image.GetHeight();
        int left = width, top = height, right = -1, bottom = -1;
        // Generated layers can have almost invisible alpha over the entire canvas.
        // Ignore only that matte residue, not the softer edge pixels cut by the old 32 threshold.
        for (int y = 0; y < height; y++)
        for (int x = 0; x < width; x++)
            if (pixels[(y * width + x) * 4 + 3] >= 8)
            {
                left = Math.Min(left, x); right = Math.Max(right, x);
                top = Math.Min(top, y); bottom = Math.Max(bottom, y);
            }
        return right >= left ? new Rect2I(left, top, right - left + 1, bottom - top + 1) : default;
    }

    private static StyleBoxFlat Flat(Color color) => new()
    {
        BgColor = color, ContentMarginLeft = 0, ContentMarginRight = 0,
        ContentMarginTop = 0, ContentMarginBottom = 0,
    };
}
