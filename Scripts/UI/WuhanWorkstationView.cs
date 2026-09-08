using Godot;
using ProjectCake.Data;
using ProjectCake.Wuhan;
using ProjectCake.Interaction;

namespace ProjectCake.UI;

/// <summary>
/// Artwork, hit targets and transient presentation for the four Wuhan stations.
/// All tweens are manually stepped by the day screen, so pause, tests and cooking
/// share one clock. Completion never changes inventory or production state.
/// </summary>
public partial class WuhanWorkstationView : Control
{
    public event Action<int>? BasketPressed;
    public event Action<string>? IngredientPressed;
    public event Action? DoupiPressed, EggPressed;
    public event Action<float>? MixMoved;
    public Func<bool>? CanInteract { get; set; }
    private DragService? _drag;
    private ProductKind? _draggedProduct;
    private readonly Dictionary<ProductKind, DragItem> _deliverySources = new();
    private bool _deliveryConfigured;
    public ProductKind? DraggedProduct => _draggedProduct;
    public static string DeliveryPayload(ProductKind kind) => $"wuhan:{kind}";
    public static ProductKind? DeliveryProduct(string payload) => payload switch
    {
        "wuhan:HotDryNoodles" => ProductKind.HotDryNoodles,
        "wuhan:Doupi" => ProductKind.Doupi,
        "wuhan:EggRiceWine" => ProductKind.EggRiceWine,
        _ => null,
    };
    private static string DeliveryChannel(ProductKind kind) => kind switch
    {
        ProductKind.HotDryNoodles => "bowl", ProductKind.Doupi => "stock", _ => "egg",
    };

    public bool CanDeliver(ProductKind kind) => _cooker is not null && CanInteract?.Invoke() == true
        && !_motions.Any(m => m.Locks.Contains(DeliveryChannel(kind))) && kind switch
        {
            ProductKind.HotDryNoodles => _bowl.State == NoodleBowlState.Ready,
            ProductKind.Doupi => _stock.Count > 0,
            ProductKind.EggRiceWine => _egg?.HasFinishedCup == true,
            _ => false,
        };

    public void ConfigureDelivery(DragService drag)
    {
        _drag = drag;
        drag.DragStarted += OnDragStarted;
        drag.DragEnded += OnDragEnded;
        foreach (ProductKind kind in new[] { ProductKind.HotDryNoodles, ProductKind.Doupi, ProductKind.EggRiceWine })
        {
            var source = new DragItem { Name = $"WuhanDrag_{kind}", MouseFilter = MouseFilterEnum.Stop, Visible = false };
            source.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
            AddChild(source);
            _deliverySources[kind] = source;
        }
    }

    private void OnDragStarted(string payload)
    {
        _draggedProduct = DeliveryProduct(payload);
        EndMix(); QueueRedraw();
    }
    private void OnDragEnded(DragResult result)
    {
        _draggedProduct = null;
        RefreshDeliverySources(); QueueRedraw();
    }
    public void CancelInput() { _drag?.CancelDrag(); EndMix(); }

    public void RefreshDeliverySources()
    {
        if (_cooker is null || _drag is null) return;
        foreach (var (kind, source) in _deliverySources)
        {
            Rect2 rect = kind == ProductKind.HotDryNoodles ? BowlRect : kind == ProductKind.Doupi ? StockRect : CupRect.Grow(4);
            source.Position = rect.Position; source.Size = rect.Size;
            source.Visible = CanDeliver(kind);
            if (_deliveryConfigured) continue;
            source.Configure(_drag, DeliveryPayload(kind), kind == ProductKind.HotDryNoodles ? "热干面" : kind == ProductKind.Doupi ? "三鲜豆皮" : "蛋酒",
                WuhanUi.Paper, new DragVisualSpec(_art.Product(kind), kind == ProductKind.HotDryNoodles ? BowlRect.Size : kind == ProductKind.Doupi ? new Vector2(100, 75) : CupSize,
                    () => CreateDeliveryPreview(kind)), () => CanDeliver(kind) && !_drag.IsDragging);
        }
        _deliveryConfigured = true;
    }

    private Control CreateDeliveryPreview(ProductKind kind)
    {
        var root = new Control { MouseFilter = MouseFilterEnum.Ignore };
        void Layer(string id, Rect2 rect, bool fit = false, float alpha = 1)
        {
            Texture2D texture = _art.Texture(id);
            if (fit) rect = FitSprite(texture, rect);
            var image = new TextureRect
            {
                Texture = new AtlasTexture { Atlas = texture, Region = Source(texture) },
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, Position = rect.Position, Size = rect.Size,
                StretchMode = TextureRect.StretchModeEnum.Scale, MouseFilter = MouseFilterEnum.Ignore,
                Modulate = new Color(1, 1, 1, alpha),
            };
            root.AddChild(image);
        }
        if (kind == ProductKind.HotDryNoodles)
        {
            Rect2 bowl = new(Vector2.Zero, BowlRect.Size), food = new(BowlFood.Position - BowlRect.Position, BowlFood.Size);
            Layer("empty_bowl", bowl); Layer("bowl_noodles", food); Layer("mixed", food);
            if (_bowl.Quality == NoodleQuality.Overcooked) Layer("overcooked", food, alpha: .35f);
            foreach (string topping in _bowl.Toppings)
                Layer(topping == StableIds.Ingredients.WuhanScallion ? "scallion" : topping == StableIds.Ingredients.WuhanChiliOil ? "chili_overlay" : "beef_overlay",
                    topping == StableIds.Ingredients.WuhanBraisedBeef ? RelativeRect(food, new Rect2(.25f, .17f, .64f, .67f)) : food);
        }
        else Layer(kind == ProductKind.Doupi ? "doupi_single" : "egg_finished", new Rect2(Vector2.Zero, kind == ProductKind.Doupi ? new Vector2(100, 75) : CupSize), true);
        return root;
    }

    public static readonly string[] IngredientIds = { StableIds.Ingredients.WuhanBaseSeasoning,
        StableIds.Ingredients.WuhanScallion, StableIds.Ingredients.WuhanChiliOil, StableIds.Ingredients.WuhanBraisedBeef };
    private WuhanArtCatalog _art = null!;
    private NoodleCookerStateMachine _cooker = null!;
    private HotDryNoodlesStateMachine _bowl = null!;
    private DoupiStateMachine? _doupi;
    private DoupiInventory _stock = null!;
    private EggRiceWineRuntime? _egg;
    private WuhanIngredientInventory _ingredients = null!;
    private int _cookerLevel, _doupiLevel;
    private readonly Dictionary<Texture2D, Rect2> _bounds = new();
    private readonly List<Motion> _motions = new();
    private readonly NoodleBasketState[] _previousBaskets = new NoodleBasketState[2];
    private DoupiState _previousDoupi;
    private float _phase;
    private Vector2? _mixLast;
    private string _hover = "";
    public bool IsMixing => _mixLast.HasValue;
    public int ActiveMotionCount => _motions.Count;
    public static bool ReducedMotion => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();

    private sealed class Motion
    {
        public required string Kind;
        public required string[] Locks;
        public required Tween Tween;
        public float Progress;
        public int Index;
        public string Ingredient = "";
        public NoodleQuality Quality;
        public DoupiState Before;
    }

    // Local coordinates in the 1920 x 1080 design, with the v3 counter at y=600.
    // Independent objects keep their source aspect; surfaces use explicit anchors.
    private Rect2 BowlRect => FitSprite(_art.Texture("empty_bowl"), new Rect2(603, 120, 224, 174));
    private Rect2 BowlFood => RelativeRect(BowlRect, new Rect2(.075f, .07f, .85f, .55f));
    private Rect2 PanRect => FitSprite(_art.Griddle(Math.Max(1, _doupiLevel)), new Rect2(1004, -46, 400, 318), new Vector2(.5f, 1));
    private Rect2 StockRect => FitSprite(_art.Texture("doupi_stock"), new Rect2(1086, 246, 238, 80));
    private Rect2 EggMachine => FitSprite(_art.Texture("egg_station"), new Rect2(1610, 0, 266, 320), new Vector2(.5f, 1));
    private Vector2 EggSpout => EggMachine.Position + EggMachine.Size * new Vector2(.39f, .525f);
    private Rect2 CupRect => At(new Vector2(EggSpout.X, EggMachine.Position.Y + EggMachine.Size.Y * .76f), CupSize);
    private Vector2 CupSize => FitSprite(_art.Texture("egg_base"), new Rect2(0, 0, 56, 60)).Size;
    private Rect2 BaseCupRect(int index) => new(new Vector2(1460 + (index % 2) * 66, 139 + (index / 2) * 68), CupSize);
    private static readonly Rect2 RawRect = new(58, 268, 94, 53);
    private static readonly Rect2 SauceBottleRect = new(588, 231, 35, 60);
    private static readonly Rect2 BatterRect = new(997, 262, 74, 64);
    private static readonly Rect2 FillingRect = new(1340, 262, 74, 64);
    private static Rect2 IngredientRect(int index) => index switch
    {
        0 => new Rect2(485, 114, 104, 84), 1 => new Rect2(482, 230, 96, 68),
        2 => new Rect2(841, 110, 100, 88), _ => new Rect2(852, 231, 96, 70)
    };
    public Vector2 BowlCenter => BowlFood.GetCenter();
    public Vector2 IngredientCenter(int index) => IngredientRect(index).GetCenter();
    public Vector2 StockCenter => StockRect.GetCenter();
    public Vector2 PanCenter => (PanCorners[0] + PanCorners[2]) / 2;
    public Vector2 CupCenter => CupRect.GetCenter();

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Stop;
        MouseExited += () => { EndMix(); _hover = ""; QueueRedraw(); };
    }

    public void Bind(WuhanArtCatalog art, NoodleCookerStateMachine cooker, HotDryNoodlesStateMachine bowl,
        DoupiStateMachine? doupi, DoupiInventory stock, EggRiceWineRuntime? egg,
        WuhanIngredientInventory ingredients, int cookerLevel, int doupiLevel)
    {
        CancelAnimations();
        _art = art; _cooker = cooker; _bowl = bowl; _doupi = doupi; _stock = stock;
        _egg = egg; _ingredients = ingredients; _cookerLevel = cookerLevel; _doupiLevel = doupiLevel;
        _bounds.Clear(); _phase=0; _deliveryConfigured=false; RememberStates(); RefreshDeliverySources(); QueueRedraw();
    }

    public bool Busy(string channel) => (_draggedProduct is ProductKind kind && DeliveryChannel(kind) == channel)
        || _motions.Any(m => m.Locks.Contains(channel));
    public float MotionProgress(string channel) => _motions.FirstOrDefault(m => m.Locks.Contains(channel))?.Progress ?? 1;
    public void EndMix() { _mixLast = null; QueueRedraw(); }
    public void CancelAnimations()
    {
        CancelInput();
        foreach (Motion m in _motions) m.Tween.Kill();
        _motions.Clear(); EndMix(); _hover = ""; QueueRedraw();
    }
    public override void _ExitTree()
    {
        CancelAnimations();
        if (_drag is not null) { _drag.DragStarted -= OnDragStarted; _drag.DragEnded -= OnDragEnded; }
    }

    private Motion Play(string kind, double seconds, params string[] channels)
    {
        var tween = CreateTween(); tween.Pause();
        var motion = new Motion { Kind = kind, Locks = channels, Tween = tween };
        tween.TweenMethod(Callable.From<float>(p => motion.Progress = p), 0f, 1f, ReducedMotion ? .12 : seconds);
        _motions.Add(motion); QueueRedraw(); return motion;
    }
    public void PlayBasket(int index, NoodleBasketState before, NoodleQuality quality)
    {
        string kind = before switch
        {
            NoodleBasketState.Empty => "drop", NoodleBasketState.Raised or NoodleBasketState.Draining => "shake",
            NoodleBasketState.Drained => "pour", _ => "raise"
        };
        Motion m = kind == "pour" ? Play(kind, .66, $"basket{index}", "bowl") : Play(kind, .24, $"basket{index}");
        m.Index = index; m.Quality = quality; RememberStates();
    }
    public void PlayIngredient(string ingredient)
    {
        Play("ingredient", .48, "bowl").Ingredient = ingredient;
    }
    public void PlayRefill(string ingredient) => Play("refill", 1, "refill:" + ingredient).Ingredient = ingredient;
    public void PlayDoupi(DoupiState before)
    {
        string kind = before switch { DoupiState.Empty => "batter", DoupiState.Batter => "egg",
            DoupiState.ReadyToFlip => "flip", DoupiState.Flipped => "filling",
            DoupiState.Cut => "stock", DoupiState.Burnt => "discard", _ => "cut" };
        Motion m = kind == "stock" ? Play(kind, .48, "pan", "stock") : Play(kind, kind == "flip" ? .48 : .36, "pan");
        m.Before = before; m.Index = _doupi?.CompletedCuts ?? 0; RememberStates();
    }
    public void PlayEgg(bool refill) => Play(refill ? "egg_refill" : "brew", .6, "egg");
    public void Tick(double delta)
    {
        if (_cooker is null || delta <= 0) return;
        foreach (Motion m in _motions.ToArray())
        {
            m.Tween.CustomStep(delta);
            if (m.Progress >= .9999f) { m.Tween.Kill(); _motions.Remove(m); }
        }
        // Automatic equipment transitions use the same visual action as a manual click.
        NoodleBasketState[] previousBaskets = (NoodleBasketState[])_previousBaskets.Clone();
        DoupiState previousDoupi = _previousDoupi;
        for (int i = 0; i < _cooker.Baskets.Count; i++)
            if (_cooker.Baskets[i].State == NoodleBasketState.Draining && !IsRaised(previousBaskets[i]) && !Busy($"basket{i}"))
                PlayBasket(i, NoodleBasketState.Ready, _cooker.Baskets[i].Quality);
        if (_doupi?.State == DoupiState.Flipped && previousDoupi == DoupiState.SkinCooking && !Busy("pan"))
            PlayDoupi(DoupiState.ReadyToFlip);
        RememberStates(); _phase += (float)delta; QueueRedraw();
    }
    private void RememberStates()
    {
        if (_cooker is null) return;
        for (int i = 0; i < _cooker.Baskets.Count; i++) _previousBaskets[i] = _cooker.Baskets[i].State;
        _previousDoupi = _doupi?.State ?? DoupiState.Empty;
    }
    private static bool IsRaised(NoodleBasketState state) => state is NoodleBasketState.Raised or NoodleBasketState.Draining or NoodleBasketState.Drained;
    private Motion? Find(string channel) => _motions.FirstOrDefault(m => m.Locks.Contains(channel));
    private static float Ease(float t) => 1 - Mathf.Pow(1 - Mathf.Clamp(t, 0, 1), 3);
    private static float Segment(float t, float from, float to) => Ease((t - from) / (to - from));

    public override void _GuiInput(InputEvent input)
    {
        if (_cooker is null || CanInteract?.Invoke() != true || _drag?.IsDragging == true) { EndMix(); return; }
        if (input is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (!mb.Pressed) { EndMix(); return; }
            string hit = HitTarget(mb.Position);
            if (hit.StartsWith("basket")) BasketPressed?.Invoke(int.Parse(hit[^1..]));
            else if (hit.StartsWith("ingredient")) IngredientPressed?.Invoke(IngredientIds[int.Parse(hit[^1..])]);
            else if (hit == "pan") DoupiPressed?.Invoke();
            else if (hit == "stock") { }
            else if (hit == "egg") EggPressed?.Invoke();
            else if (hit == "raw")
            {
                int index = Enumerable.Range(0, _cooker.Baskets.Count).FirstOrDefault(i => _cooker.Baskets[i].State == NoodleBasketState.Empty && !Busy($"basket{i}"), -1);
                if (index >= 0) BasketPressed?.Invoke(index);
            }
            else if (hit == "bowl" && !Busy("bowl"))
            {
                if (InBowl(mb.Position) && _bowl.State is NoodleBowlState.Seasoned or NoodleBowlState.Mixing) _mixLast = mb.Position;
            }
            AcceptEvent(); QueueRedraw();
        }
        else if (input is InputEventMouseMotion mm)
        {
            _hover = HitTarget(mm.Position);
            if ((mm.ButtonMask & MouseButtonMask.Left) == 0 || !InBowl(mm.Position) || Busy("bowl")) EndMix();
            else if (_mixLast is Vector2 previous)
            {
                MixMoved?.Invoke(previous.DistanceTo(mm.Position)); _mixLast = mm.Position;
                if (_bowl.State == NoodleBowlState.Ready) EndMix();
            }
            MouseDefaultCursorShape = _hover.Length > 0 ? CursorShape.PointingHand : CursorShape.Arrow;
            QueueRedraw();
        }
    }

    public bool InBowl(Vector2 p) => ((p - BowlFood.GetCenter()) / (BowlFood.Size * .5f)).LengthSquared() <= 1;
    public string HitTarget(Vector2 p)
    {
        if (_cooker is null) return "";
        if (InBowl(p)) return "bowl";
        if (SauceBottleRect.Grow(4).HasPoint(p)) return "ingredient0";
        for (int i = 0; i < 4; i++) if (IngredientRect(i).Grow(4).HasPoint(p)) return $"ingredient{i}";
        if (BowlRect.HasPoint(p)) return "bowl";
        for (int i = 0; i < _cooker.Baskets.Count; i++)
            if (BasketRect(i).HasPoint(p)) return $"basket{i}";
        if (RawRect.HasPoint(p)) return "raw";
        if (StockRect.HasPoint(p)) return "stock";
        if (Geometry2D.IsPointInPolygon(p, PanCorners) || BatterRect.HasPoint(p) || FillingRect.HasPoint(p)) return "pan";
        if (EggMachine.HasPoint(p) || CupRect.HasPoint(p)) return "egg";
        if (_egg is not null)
            for (int i = 0; i < _egg.BaseCups; i++) if (BaseCupRect(i).HasPoint(p)) return "egg";
        return "";
    }

    public override void _Draw()
    {
        if (_cooker is null) return;
        DrawCooker(); DrawMixStation(); DrawDoupi(); DrawEgg(); DrawRefills(); DrawTransfers();
    }

    private Rect2 Source(Texture2D texture)
    {
        if (!_bounds.TryGetValue(texture, out Rect2 bounds))
        {
            using Image img = texture.GetImage();
            // Generated PNGs contain almost-transparent matte residue outside the art.
            // GetUsedRect counts that residue and silently shifts every authored anchor.
            img.Convert(Image.Format.Rgba8);
            byte[] pixels=img.GetData();int width=img.GetWidth(),height=img.GetHeight();
            int left=width,top=height,right=-1,bottom=-1;
            for(int y=0;y<height;y++)for(int x=0;x<width;x++)
                if(pixels[(y*width+x)*4+3]>=32){left=Math.Min(left,x);right=Math.Max(right,x);top=Math.Min(top,y);bottom=Math.Max(bottom,y);}
            // Steam is already painted above the finished cup. Align the ceramic
            // body to the base cup and draw animated steam separately.
            if(texture==_art.Texture("egg_finished"))top=Math.Max(top,(int)(height*.222f));
            bounds=right>=left?new Rect2(left,top,right-left+1,bottom-top+1):new Rect2(Vector2.Zero,texture.GetSize());
            _bounds[texture] = bounds;
        }
        return bounds;
    }
    private void Sprite(string id, Rect2 rect, float alpha = 1, float angle = 0) => Sprite(_art.Texture(id), rect, alpha, angle);
    private void Sprite(Texture2D texture, Rect2 rect, float alpha = 1, float angle = 0)
        => DrawSprite(texture, FitSprite(texture, rect), alpha, angle);
    private Rect2 FitSprite(Texture2D texture, Rect2 box, Vector2? alignment = null)
    {
        Vector2 source = Source(texture).Size;
        float scale = Math.Min(box.Size.X / source.X, box.Size.Y / source.Y);
        Vector2 size = source * scale;
        return new Rect2(box.Position + (box.Size - size) * (alignment ?? new Vector2(.5f, .5f)), size);
    }
    private static Rect2 RelativeRect(Rect2 parent, Rect2 normalized)
        => new(parent.Position + parent.Size * normalized.Position, parent.Size * normalized.Size);
    // Flat food overlays are deliberately projected onto the authored bowl opening.
    private void FoodLayer(string id, Rect2 rect, float alpha = 1)
        => DrawSprite(_art.Texture(id), rect, alpha, 0);
    private void DrawSprite(Texture2D texture, Rect2 rect, float alpha, float angle)
    {
        if (alpha <= 0) return;
        DrawSetTransform(rect.GetCenter(), angle);
        DrawTextureRectRegion(texture, new Rect2(-rect.Size / 2, rect.Size), Source(texture), new Color(1, 1, 1, alpha));
        DrawSetTransform(Vector2.Zero);
    }
    private void Ellipse(Vector2 center, Vector2 radius, Color color)
    {
        Vector2[] points = Enumerable.Range(0, 48).Select(i => center + Vector2.FromAngle(i * Mathf.Tau / 48) * radius).ToArray();
        DrawColoredPolygon(points, color);
    }
    private void Hint(Rect2 rect, string target)
    {
        if (_hover == target && CanInteract?.Invoke() == true)
            Ellipse(rect.GetCenter(), rect.Size * .55f, new Color(WuhanUi.Accent, .18f));
    }
    private static Rect2 At(Vector2 center, Vector2 size) => new(center - size / 2, size);

    // All v2 cookers use square source canvases. Keep the pot bases on the counter
    // and align the separate baskets with each model's authored water surface.
    private Rect2 CookerCanvas => _cookerLevel switch
    {
        2 => new Rect2(66, -22, 363, 363),
        3 => new Rect2(61, -2, 367, 367),
        _ => new Rect2(66, -2, 363, 363)
    };
    private Vector2 BasketHome(int index) => CookerCanvas.Position + CookerCanvas.Size *
        (_cookerLevel == 3 ? new Vector2(index == 0 ? .37f : .714f, .477f) : new Vector2(.546f, .437f));
    private Vector2 BasketSize => FitSprite(_art.Texture("basket"), new Rect2(0, 0, _cookerLevel == 3 ? 116 : 136, _cookerLevel == 3 ? 120 : 140)).Size;
    public Rect2 BasketRect(int index)
    {
        Motion? m = Find($"basket{index}");
        float raised = IsRaised(_cooker.Baskets[index].State) ? 1 : 0;
        if (m?.Kind == "raise") raised = ReducedMotion ? 1 : Ease(m.Progress);
        Vector2 center = BasketHome(index) + new Vector2(0, -67 * raised);
        if (m?.Kind == "shake" && !ReducedMotion) center.Y += Mathf.Sin(m.Progress * Mathf.Tau * 2) * 10;
        return At(center, BasketSize);
    }
    private void DrawCooker()
    {
        Rect2 c = CookerCanvas;
        DrawTextureRect(_art.Cooker(_cookerLevel), c, false);
        // The v2 artwork already contains water without baked-in baskets.
        for (int i = 0; i < _cooker.Baskets.Count; i++)
        {
            Motion? m = Find($"basket{i}"); NoodleBasketRuntime basket = _cooker.Baskets[i];
            if (m?.Kind == "pour" && !ReducedMotion) continue;
            Rect2 r = BasketRect(i); Hint(r, $"basket{i}"); Sprite("basket", r);
            if (basket.State != NoodleBasketState.Empty)
            {
                Rect2 noodles = new(r.Position + r.Size * new Vector2(.08f, .50f), r.Size * new Vector2(.60f, .24f));
                if (m?.Kind == "drop" && !ReducedMotion)
                {
                    float p = Ease(m.Progress); noodles = At(RawRect.GetCenter().Lerp(noodles.GetCenter(), p), RawRect.Size.Lerp(noodles.Size, p));
                }
                Sprite(basket.Quality == NoodleQuality.Overcooked ? "overcooked" : basket.State == NoodleBasketState.Cooking ? "raw_noodles" : "cooked_basket", noodles);
                if (basket.State is NoodleBasketState.Cooking or NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Locked)
                {
                    Steam(noodles.GetCenter() + new Vector2(0,-10), .55f);
                    for (int j=0;j<4;j++) DrawArc(noodles.GetCenter()+new Vector2(j*15-22,13), 3 + Mathf.PosMod((ReducedMotion ? 0 : _phase*5)+j,4), 0, Mathf.Tau, 16, new Color(1,1,1,.55f), 1.5f, true);
                }
                if (basket.State is NoodleBasketState.Raised or NoodleBasketState.Draining || m?.Kind == "shake")
                    Drips(r.Position + r.Size * new Vector2(.38f,.94f), m?.Kind == "shake" ? 8 : 4);
            }
        }
        DrawCookerFront();
        DrawRawTray();
    }

    private void DrawRawTray()
    {
        Hint(RawRect, "raw"); Sprite(_art.Shared.IngredientTray, RawRect.Grow(8));
        Sprite("raw_noodles", RawRect, _ingredients.Count(StableIds.Ingredients.WuhanNoodles) > 0 ? 1 : .25f);
        DrawString(ThemeDB.FallbackFont, new Vector2(RawRect.End.X + 14, RawRect.End.Y + 5), $"面条 {_ingredients.Count(StableIds.Ingredients.WuhanNoodles)}", fontSize: 18, modulate: WuhanUi.Text);
    }

    private void DrawCookerFront()
    {
        // Each v2 pot has its own front-rim height, shared by idle and return motion.
        Rect2 c = CookerCanvas;
        Texture2D pot = _art.Cooker(_cookerLevel);
        float front = _cookerLevel switch { 2 => .645f, 3 => .595f, _ => .568f };
        DrawTextureRectRegion(pot, new Rect2(c.Position + new Vector2(0,c.Size.Y*front),c.Size*new Vector2(1,1-front)),
            new Rect2(new Vector2(0,pot.GetHeight()*front),pot.GetSize()*new Vector2(1,1-front)));
    }

    private void DrawMixStation()
    {
        Sprite("mix_station", new Rect2(505, 128, 420, 200));
        Hint(BowlRect, "bowl");
        Motion? m = Find("bowl");
        bool delivering = _draggedProduct == ProductKind.HotDryNoodles;
        if (!delivering)
        {
            Sprite("empty_bowl", BowlRect);
            if (_bowl.State != NoodleBowlState.Empty && !(m?.Kind == "pour" && m.Progress < .66f && !ReducedMotion))
                DrawBowlContents(BowlFood, _bowl.State, (float)_bowl.MixProgress, _bowl.Quality, _bowl.Toppings,
                    m?.Kind == "ingredient" && m.Progress < .62f ? m.Ingredient : "");
        }
        for (int i=0;i<4;i++)
        {
            Rect2 r = IngredientRect(i); Hint(r, $"ingredient{i}");
            if (i is 1 or 3) Sprite(_art.Shared.IngredientTray, r.Grow(3));
            bool movingContainer=m?.Kind=="ingredient"&&m.Ingredient==IngredientIds[i]&&i is 0 or 2&&!ReducedMotion;
            if(!movingContainer)Sprite(_art.Ingredient(IngredientIds[i]), r, _ingredients.Count(IngredientIds[i]) > 0 ? 1 : .3f);
        }
        if(!(m?.Kind=="ingredient"&&m.Ingredient==IngredientIds[0]&&!ReducedMotion))Sprite("base_sauce", SauceBottleRect);
        if (_mixLast is Vector2 pointer)
        {
            Vector2 center = BowlFood.GetCenter();
            float angle = ReducedMotion ? -.3f : (pointer-center).Angle() * .12f - .4f;
            Sprite("chopsticks", At(pointer + new Vector2(20,-27), new Vector2(99,99)), 1, angle);
        }
        else Sprite("chopsticks", new Rect2(749,235,91,88), .9f, -.15f);
        if (m?.Kind == "ingredient") DrawIngredientMotion(m);
    }
    private void DrawBowlContents(Rect2 food, NoodleBowlState state, float progress, NoodleQuality quality,
        IEnumerable<string> toppings, string hidden = "", float opacity = 1)
    {
        FoodLayer("bowl_noodles", food,opacity);
        bool seasoned = state is NoodleBowlState.Seasoned or NoodleBowlState.Mixing or NoodleBowlState.Ready;
        if (seasoned && hidden != StableIds.Ingredients.WuhanBaseSeasoning)
        {
            float half = Mathf.Clamp(progress / 50, 0, 1), mixed = Mathf.Clamp((progress - 40) / 60, 0, 1);
            FoodLayer("unmixed", food, (1-half)*opacity);
            FoodLayer("half_mixed", food, half * (1-mixed)*opacity);
            FoodLayer("mixed", food, mixed*opacity);
        }
        if (quality == NoodleQuality.Overcooked) FoodLayer("overcooked", food, (seasoned ? .35f : .8f)*opacity);
        foreach (string topping in toppings)
            if (topping != hidden)
            {
                bool beef=topping==StableIds.Ingredients.WuhanBraisedBeef;
                Rect2 placement=beef?new Rect2(food.Position+food.Size*new Vector2(.25f,.17f),food.Size*new Vector2(.64f,.67f)):food;
                FoodLayer(topping == StableIds.Ingredients.WuhanScallion ? "scallion" : topping == StableIds.Ingredients.WuhanChiliOil ? "chili_overlay" : "beef_overlay", placement,opacity);
            }
    }
    private void DrawIngredientMotion(Motion m)
    {
        if (ReducedMotion) return;
        int index = Array.IndexOf(IngredientIds,m.Ingredient);
        Rect2 source = IngredientRect(index);
        float p=m.Progress, enter=Segment(p,0,.38f), leave=Segment(p,.72f,1);
        Vector2 target=BowlFood.GetCenter()+new Vector2(index<2?-42:48,-70);
        Vector2 center=source.GetCenter().Lerp(target,enter).Lerp(source.GetCenter(),leave);
        if (index is 0 or 2)
        {
            Sprite(_art.Ingredient(m.Ingredient), At(center,source.Size*.85f), 1, -.65f*enter*(1-leave));
            if(p>.35f&&p<.74f) DrawLine(center+new Vector2(12,22),BowlFood.GetCenter(),index==0?new Color("#BE803B"):new Color("#CB4627"),6,true);
            if(index==0&&p>.5f) Sprite("base_sauce",At(center+new Vector2(55,0),new Vector2(40,64)),1,-.65f);
        }
        else Sprite(index==1?"scallion":"beef_overlay",At(source.GetCenter().Lerp(BowlFood.GetCenter(),Ease(p)),source.Size.Lerp(BowlFood.Size,p)),1-p);
    }

    private Vector2[] PanCorners => (_doupiLevel switch
    {
        3 => new[] {new Vector2(.1895f,.3590f),new Vector2(.8073f,.3590f),new Vector2(.8543f,.6708f),new Vector2(.1433f,.6708f)},
        2 => new[] {new Vector2(.1900f,.1529f),new Vector2(.8067f,.1529f),new Vector2(.8561f,.5918f),new Vector2(.1447f,.5918f)},
        _ => new[] {new Vector2(.1867f,.1522f),new Vector2(.8091f,.1522f),new Vector2(.8589f,.5928f),new Vector2(.1411f,.5928f)}
    })
        .Select(p => PanRect.Position + p * PanRect.Size).ToArray();
    private void PanLayer(string id,float alpha=1,float grow=1,float flip=1)
    {
        Vector2[] corners=PanCorners; Vector2 center=(corners[0]+corners[2])/2;
        corners=corners.Select(p=>center+(p-center)*new Vector2(grow,grow*flip)).ToArray();
        Texture2D tex=_art.Texture(id);Rect2 source=Source(tex);Vector2 size=tex.GetSize();
        Vector2[] uv={source.Position/size,new Vector2(source.End.X,source.Position.Y)/size,source.End/size,new Vector2(source.Position.X,source.End.Y)/size};
        // Finished food is drawn in an oblique perspective in its source PNG.
        // Sample its top-face quadrilateral, not the surrounding transparent box.
        if(id=="doupi_finished")uv=new[]{new Vector2(.37f,.20f),new Vector2(.97f,.37f),new Vector2(.725f,.79f),new Vector2(.033f,.553f)};
        if(id=="doupi_cut")uv=new[]{new Vector2(.325f,.21f),new Vector2(.96f,.452f),new Vector2(.706f,.802f),new Vector2(.035f,.597f)};
        DrawPolygon(corners,new[]{new Color(1,1,1,alpha)},uv,tex);
    }
    private void DrawDoupi()
    {
        Sprite(_art.Griddle(Math.Max(1,_doupiLevel)),PanRect,_doupi is null?.4f:1);
        Sprite("doupi_batter",BatterRect,_doupi is null?.35f:1);
        Sprite("doupi_filling",FillingRect,_doupi is null?.35f:1);
        Hint(StockRect,"stock");Sprite("doupi_stock",StockRect);
        int displayed=_stock.Count - (_draggedProduct == ProductKind.Doupi ? 1 : 0);
        Motion? m=Find("pan");
        if(m?.Kind=="stock")displayed=Math.Max(0,displayed-8);
        for(int i=0;i<displayed;i++)Sprite("doupi_single",StockItemRect(i));
        if(_doupi is null)return;
        Hint(At(PanCenter, PanRect.Size * new Vector2(.7f, .4f)),"pan");
        DoupiState state=_doupi.State;
        if(m?.Kind=="discard"){PanLayer("doupi_egg",1-m.Progress);PanLayer("doupi_burnt",1-m.Progress);}
        if(state!=DoupiState.Empty)
        {
            float grow=m?.Kind=="batter"&&!ReducedMotion?.25f+.75f*Ease(m.Progress):1;
            float flip=m?.Kind=="flip"&&!ReducedMotion?Mathf.Max(.06f,Mathf.Abs(Mathf.Cos(m.Progress*Mathf.Pi))):1;
            bool finished=state is DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cut;
            if(!finished)
            {
                PanLayer("doupi_skin",1,grow,flip);
                if(state!=DoupiState.Batter)PanLayer("doupi_egg",m?.Kind=="egg"?Ease(m.Progress):1,1,flip);
                if(state==DoupiState.SecondCooking)PanLayer("doupi_filling_overlay",m?.Kind=="filling"?Ease(m.Progress):1,m?.Kind=="filling"?.4f+.6f*Ease(m.Progress):1);
            }
            else PanLayer(state==DoupiState.Cut&&m?.Kind!="cut"?"doupi_cut":"doupi_finished");
            if(state==DoupiState.Overbrowned)PanLayer("doupi_burnt",.3f);
            if(state==DoupiState.Burnt)PanLayer("doupi_burnt");
            int cuts=_doupi.CompletedCuts;
            for(int i=0;i<cuts;i++)DrawCut(i,m?.Kind=="cut"&&i==cuts-1?m.Progress:1);
            if(state is DoupiState.SkinCooking or DoupiState.SecondCooking or DoupiState.ReadyToFlip or DoupiState.ReadyToCut)Steam(PanCenter+new Vector2(0,-30),.7f);
        }
        if(m is not null)DrawPanMotion(m);
    }
    private Rect2 StockItemRect(int index) => RelativeRect(StockRect,
        new Rect2(.11f + (index % 4) * .195f, .16f + (index / 4) * .13f, .19f, .30f));
    private void DrawCut(int index,float progress)
    {
        Vector2[] c=PanCorners;
        Vector2 a=index<3?c[0].Lerp(c[1],(index+1)/4f):c[0].Lerp(c[3],.5f);
        Vector2 b=index<3?c[3].Lerp(c[2],(index+1)/4f):c[1].Lerp(c[2],.5f);
        DrawLine(a,a.Lerp(b,Ease(progress)),new Color("#744625"),3,true);
    }
    private void DrawPanMotion(Motion m)
    {
        if(ReducedMotion)return;
        float p=m.Progress;
        if(m.Kind is "flip" or "cut")
        {
            Vector2 center=PanCenter;
            if(m.Kind=="cut")
            {
                Vector2[] c=PanCorners;int index=Math.Max(0,m.Index-1);
                center=index<3?c[0].Lerp(c[1],(index+1)/4f).Lerp(c[3].Lerp(c[2],(index+1)/4f),Ease(p)):c[0].Lerp(c[3],.5f).Lerp(c[1].Lerp(c[2],.5f),Ease(p));
            }
            else center+=new Vector2(35,-Mathf.Sin(p*Mathf.Pi)*60);
            Sprite(m.Kind=="cut"?"cut_tool":_doupiLevel==3?"auto_flip_tool":"flip_tool",At(center+new Vector2(30,-23),new Vector2(138,91)),1,Mathf.Sin(p*Mathf.Pi)*-.4f);
        }
        else if(m.Kind is "batter" or "egg" or "filling")
        {
            Vector2 from=(m.Kind=="filling"?FillingRect:BatterRect).GetCenter();
            Vector2 center=from.Lerp(PanCenter+new Vector2(0,-78),Mathf.Sin(p*Mathf.Pi));
            Texture2D tex=m.Kind=="egg"?_art.Shared.Ingredient(StableIds.Ingredients.Egg):_art.Texture(m.Kind=="batter"?"doupi_batter":"doupi_filling");
            Sprite(tex,At(center,new Vector2(73,68)),1,-Mathf.Sin(p*Mathf.Pi)*.65f);
            if(p>.2f&&p<.8f)DrawLine(center+new Vector2(0,28),PanCenter,m.Kind=="egg"?new Color("#FFC942"):new Color("#EACD8C"),7,true);
        }
        else if(m.Kind=="stock")
            for(int i=0;i<8;i++){Rect2 target=StockItemRect(Math.Max(0,_stock.Count-8)+i);Sprite("doupi_single",At((PanCenter+new Vector2((i%4)*35-55,(i/4)*27)).Lerp(target.GetCenter(),Ease(p)),new Vector2(50,36).Lerp(target.Size,p)));}
    }

    private void DrawEgg()
    {
        Hint(EggMachine,"egg");Sprite("egg_station",EggMachine,_egg is null?.4f:1);
        if(_egg is null)return;
        for(int i=0;i<_egg.BaseCups;i++)Sprite("egg_base",BaseCupRect(i));
        Motion? m=Find("egg");
        if((_egg.HasFinishedCup||_egg.IsPreparing) && _draggedProduct != ProductKind.EggRiceWine)
        {
            Rect2 r=CupRect;
            if(m?.Kind=="brew"&&!ReducedMotion)r=At(BaseCupRect(_egg.BaseCups).GetCenter().Lerp(CupRect.GetCenter(),Segment(m.Progress,0,.28f)),CupSize);
            float progress=_egg.HasFinishedCup?1:Mathf.Clamp(1-(float)(_egg.RemainingSeconds/EggRiceWineRuntime.ActionSeconds),0,1);
            Sprite("egg_base",r,1-progress);
            Sprite("egg_finished",r,progress);
            if(_egg.IsPreparing&&progress>.25f)
            {
                DrawLine(EggSpout,r.Position+r.Size*new Vector2(.5f,.24f),new Color(.9f,.96f,1,.8f),5,true);
            }
            Steam(r.Position+new Vector2(r.Size.X/2,5),.45f);
        }
        if(m?.Kind=="egg_refill")
            for(int i=0;i<6;i++)
            {
                Rect2 r=BaseCupRect(i);r.Position-=new Vector2(0,ReducedMotion?0:30*(1-Ease(m.Progress)));
                Sprite("egg_base",r,m.Progress);
            }
    }
    private void DrawRefills()
    {
        foreach(Motion m in _motions.Where(m=>m.Kind=="refill"))
        {
            int index=Array.IndexOf(IngredientIds,m.Ingredient);
            Rect2 target=index<0?RawRect:IngredientRect(index);
            if(!ReducedMotion)target.Position+=new Vector2(0,-35*(1-Ease(m.Progress)));
            Sprite(_art.Ingredient(m.Ingredient),target,.4f+.6f*m.Progress);
        }
    }
    private void DrawTransfers()
    {
        foreach(Motion m in _motions)
        {
            if(m.Kind=="pour"&&!ReducedMotion)
            {
                Rect2 home=At(BasketHome(m.Index)+new Vector2(0,-67),BasketSize);
                Vector2 destination=BowlFood.GetCenter()+new Vector2(-32,-105);
                float enter=Segment(m.Progress,0,.36f),leave=Segment(m.Progress,.7f,1);
                Vector2 center=home.GetCenter().Lerp(destination,enter).Lerp(BasketHome(m.Index),leave);
                float angle=Segment(m.Progress,.30f,.5f)*(1-leave)*1.15f;
                Sprite("basket",At(center,home.Size),1,angle);
                if(leave>0)
                {
                    // The returning empty basket descends behind the front rim.
                    DrawCookerFront();
                    DrawRawTray();
                }
                if(m.Progress<.68f)
                {
                    float fall=Segment(m.Progress,.42f,.67f);
                    Vector2 start=center+new Vector2(-19,15);
                    Sprite(m.Quality==NoodleQuality.Overcooked?"overcooked":"cooked_basket",At(start.Lerp(BowlFood.GetCenter(),fall),new Vector2(88,45).Lerp(BowlFood.Size,fall)),1,angle*(1-fall));
                }
            }

        }
    }
    private void Steam(Vector2 origin,float scale)
    {
        if(ReducedMotion)return;
        for(int i=0;i<3;i++)
        {
            float t=Mathf.PosMod(_phase*.6f+i*.33f,1);
            Vector2 p=origin+new Vector2((i-1)*23+Mathf.Sin(t*5+i)*9,-t*65)*scale;
            DrawArc(p,8*scale,Mathf.Pi*.2f,Mathf.Pi*1.1f,12,new Color(1,1,1,(1-t)*.55f),2,true);
        }
    }
    private void Drips(Vector2 origin,int count)
    {
        if(ReducedMotion)return;
        for(int i=0;i<count;i++)
        {
            float t=Mathf.PosMod(_phase*2+i*.23f,1);
            Vector2 p=origin+new Vector2((i-(count-1)*.5f)*8,t*42);
            DrawLine(p,p+new Vector2(0,5),new Color(.65f,.9f,1,1-t),2.5f,true);
        }
    }
}
