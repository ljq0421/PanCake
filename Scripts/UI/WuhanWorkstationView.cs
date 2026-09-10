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
    public event Action? DoupiPressed;
    public event Action<float>? MixMoved;
    public Func<bool>? CanInteract { get; set; }
    private DragService? _drag;
    private ProductKind? _draggedProduct;
    private readonly Dictionary<ProductKind, DragItem> _deliverySources = new();
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
            ProductKind.EggRiceWine => _egg?.CanTake == true,
            _ => false,
        };

    public void ConfigureDelivery(DragService drag)
    {
        if (_drag == drag && _deliverySources.Count == 3) return;
        _drag = drag;
        drag.DragStarted += OnDragStarted;
        drag.DragEnded += OnDragEnded;
        foreach (ProductKind kind in new[] { ProductKind.HotDryNoodles, ProductKind.Doupi, ProductKind.EggRiceWine })
        {
            DragItem source = GetNode<DragItem>($"WuhanDrag_{kind}");
            source.BindRuntime(drag, () => CanDeliver(kind) && !drag.IsDragging,
                () => CreateDeliveryPreview(kind));
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
    public void CancelInput() { _drag?.CancelDrag(); CancelGesture(); EndMix(); _cooker?.CancelPendingPour(); }

    public void RefreshDeliverySources()
    {
        if (_cooker is null || _drag is null) return;
        foreach (var (kind, source) in _deliverySources)
        {
            Rect2 bounds = kind switch { ProductKind.HotDryNoodles => BowlRect,
                ProductKind.Doupi => StockRect, _ => EggStockRect };
            source.Position = bounds.Position;
            source.Size = bounds.Size;
            source.TooltipText = "按住成品拖给顾客";
            source.Visible = CanDeliver(kind) && !(kind == ProductKind.HotDryNoodles && _mixHeld);
        }
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
            Layer("empty_bowl", bowl);
            foreach (var layer in BowlLayers(food, _bowl.State, (float)_bowl.MixProgress, _bowl.Quality, _bowl.Toppings))
                Layer(layer.Id, layer.Rect, alpha: layer.Alpha);
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
    private bool _mixHeld;
    private string _hover = "";
    public bool IsMixing => _mixHeld;
    public int ActiveMotionCount => _motions.Count;
    public static bool ReducedMotion => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();

    private sealed class Motion
    {
        public required string Kind;
        public required string[] Locks;
        public required Tween Tween;
        public float Progress;
        public int Index;
        public int Amount;
        public int StockStart;
        public Vector2? Origin;
        public DoupiCutDirection Direction;
        public string Ingredient = "";
        public NoodleQuality Quality;
        public DoupiState Before;
    }

    // 1920x1080 design coordinates relative to the view at y=585.
    // Visual bounds, input sources and animation anchors share these definitions.
    private Rect2 BowlRect => FitSprite(_art.Texture("empty_bowl"), new Rect2(650, 20, 275, 228));
    private Rect2 BowlFood => RelativeRect(BowlRect, new Rect2(.075f, .07f, .85f, .55f));
    private Rect2 ChopsticksRect => new(BowlRect.End.X - 149, BowlRect.End.Y + 14, 96, 121.5f);
    private Rect2 PanRect => FitSprite(_art.Griddle(Math.Max(1, _doupiLevel)), new Rect2(1094, _doupiLevel == 3 ? -53 : -68, 441.6f, 344.4f), new Vector2(.5f, 1));
    private static readonly Rect2 StockRect = new(1364, 298, 245, 116.25f);
    private static readonly Rect2 EggStockRect = new(1628, 185, 274, 149);
    private Vector2 CupSize => FitSprite(_art.Texture("egg_finished"), new Rect2(0, 0, 72, 86)).Size;
    private Rect2 CupRect => EggCupRect(0);
    private Rect2 EggCupRect(int index) => At(EggStockRect.Position + new Vector2(57 + index * 80, 65), CupSize);
    private static readonly Rect2 RawTrayRect = new(148, 277, 217.5f, 127.5f);
    private Rect2 RawRect => TrayFoodRect(_art.Texture("raw_noodles"), RawTrayRect);
    private static Rect2 IngredientRect(int index) => index switch
    {
        0 => new Rect2(492, 20, 142.5f, 145),
        1 => new Rect2(630, 260, 150, 103.75f),
        2 => new Rect2(944, 20, 142.5f, 145),
        _ => new Rect2(888, 260, 150, 103.75f),
    };
    private static Rect2 IngredientReadout(int index) => new(IngredientRect(index).Position + new Vector2(0, IngredientRect(index).Size.Y + 4), new Vector2(120, 48));
    private static Rect2 SauceBottleRect => new(new Vector2(480, 225), IngredientRect(0).Size);
    private Rect2 BatterRect => FitSprite(_art.Texture("doupi_batter"), new Rect2(1060, 270, 140, 140), new Vector2(.5f, 1));
    private Rect2 FillingRect => FitSprite(_art.Texture("doupi_filling"), new Rect2(1210, 274, 140, 140), new Vector2(.5f, 1));
    public Vector2 BowlStatusPosition => new(565, 193);
    public Vector2 DoupiStatusPosition => new(1010, 240);
    public Vector2 EggStatusPosition => new(1568, 132);
    public Vector2 BasketStatusPosition(int index) => new(100, 236 + index * 25);

    // Contents use the actual fitted sprite and finish above the authored front rim.
    private Rect2 TrayFoodRect(Texture2D texture, Rect2 tray, string trayArt = "ingredient_tray")
        => FitSprite(texture, RelativeRect(FitSprite(_art.Texture(trayArt), tray), new Rect2(.16f, .23f, .68f, .42f)), new Vector2(.5f, 1));
    private Rect2 IngredientFoodRect(int index) => index is 1 or 3
        ? TrayFoodRect(_art.Ingredient(IngredientIds[index]), IngredientRect(index), index == 3 ? "beef_tray" : "ingredient_tray") : IngredientRect(index);
    public Vector2 BowlCenter => BowlFood.GetCenter();
    public Vector2 IngredientCenter(int index) => IngredientRect(index).GetCenter();
    public Vector2 StockCenter => StockRect.GetCenter();
    public Vector2 PanCenter => (PanCorners[0] + PanCorners[2]) / 2;
    public Vector2 CupCenter => CupRect.GetCenter();

    public override void _Ready()
    {
        MouseExited += () => { _hover = ""; _pointer = new Vector2(-1000, -1000); QueueRedraw(); };
    }

    public void Bind(WuhanArtCatalog art, NoodleCookerStateMachine cooker, HotDryNoodlesStateMachine bowl,
        DoupiStateMachine? doupi, DoupiInventory stock, EggRiceWineRuntime? egg,
        WuhanIngredientInventory ingredients, int cookerLevel, int doupiLevel)
    {
        CancelAnimations();
        _art = art; _cooker = cooker; _bowl = bowl; _doupi = doupi; _stock = stock;
        _egg = egg; _ingredients = ingredients; _cookerLevel = cookerLevel; _doupiLevel = doupiLevel;
        _bounds.Clear(); _phase=0; RememberStates(); BindRefillControls(); RefreshDeliverySources(); QueueRedraw();
    }

    public bool Busy(string channel) => (_draggedProduct is ProductKind kind && DeliveryChannel(kind) == channel)
        || _motions.Any(m => m.Locks.Contains(channel));
    public float MotionProgress(string channel) => _motions.FirstOrDefault(m => m.Locks.Contains(channel))?.Progress ?? 1;
    public void EndMix() { _mixHeld = false; _mixLast = null; QueueRedraw(); }
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
    public void PlayBasket(int index, NoodleBasketState before, NoodleQuality quality, Vector2? origin = null)
    {
        string kind = before switch
        {
            NoodleBasketState.Empty => "drop", NoodleBasketState.Raised or NoodleBasketState.Draining => "shake",
            NoodleBasketState.Drained => "pour", _ => "raise"
        };
        Motion m = kind == "pour" ? Play(kind, .66, $"basket{index}", "bowl") : Play(kind, .24, $"basket{index}");
        m.Index = index; m.Quality = quality; m.Origin = origin; RememberStates();
    }
    public void PlayIngredient(string ingredient)
    {
        Play("ingredient", .48, "bowl").Ingredient = ingredient;
    }
    public void PlayRefill(string ingredient) => Play("refill", 1, "refill:" + ingredient).Ingredient = ingredient;
    public void PlayDoupi(DoupiState before)
    {
        string kind = before switch { DoupiState.Empty => "batter", DoupiState.Batter => "egg",
            DoupiState.ReadyToFlip => "flip", DoupiState.Flipped => "filling", DoupiState.Burnt => "discard", _ => "cut" };
        Motion m = Play(kind, kind == "flip" ? .48 : .36, "pan");
        m.Before = before; RememberStates();
    }
    public void PlayCut(DoupiCutDirection direction)
    {
        Motion m = Play("cut", .36, "pan"); m.Direction = direction; RememberStates();
    }
    public void PlayStock(int amount, int stockStart)
    {
        Motion m = Play("stock", .48, "pan", "stock");
        m.Amount = amount; m.StockStart = stockStart; RememberStates();
    }
    private void HandleMixInput(InputEvent input)
    {
        if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false })
        {
            EndMix(); RefreshDeliverySources(); GetViewport().SetInputAsHandled();
        }
        else if (input is InputEventMouseMotion motion)
        {
            if ((motion.ButtonMask & MouseButtonMask.Left) == 0) { EndMix(); return; }
            Vector2 point = GetGlobalTransformWithCanvas().AffineInverse() * motion.Position;
            if (_bowl.State != NoodleBowlState.Ready && !Busy("bowl") && InBowl(point) && _mixLast is Vector2 previous && InBowl(previous))
                MixMoved?.Invoke(previous.DistanceTo(point));
            _mixLast = point; QueueRedraw(); GetViewport().SetInputAsHandled();
        }
    }
    public void PlayEggRefill() => Play("egg_refill", EggRiceWineRuntime.RefillSeconds, "egg");
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
    public Vector2 PourPosition => BowlFood.GetCenter() + new Vector2(-32, -105);
    public void RememberProductionState() => RememberStates();
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
            if (TryBeginGesture(hit, mb.Position)) { AcceptEvent(); return; }
            if (hit.StartsWith("ingredient")) IngredientPressed?.Invoke(IngredientIds[int.Parse(hit[^1..])]);
            else if (hit == "pan" && _doupi?.State is DoupiState.Empty or DoupiState.Batter or DoupiState.Flipped or DoupiState.Burnt) DoupiPressed?.Invoke();
            else if (hit == "bowl" && !Busy("bowl"))
            {
                if (InBowl(mb.Position) && _bowl.State is NoodleBowlState.Seasoned or NoodleBowlState.Mixing) { _mixLast = mb.Position; _mixHeld = true; }
            }
            AcceptEvent(); QueueRedraw();
        }
        else if (input is InputEventMouseMotion mm)
        {
            _pointer = mm.Position;
            _hover = HitTarget(mm.Position);
            TooltipText = HoverDescription(_hover);
            MouseDefaultCursorShape = _hover.Length > 0 ? CursorShape.PointingHand : CursorShape.Arrow;
            RefreshRefillControls();
            QueueRedraw();
        }
    }

    public bool InBowl(Vector2 p) => ((p - BowlFood.GetCenter()) / (BowlFood.Size * .5f)).LengthSquared() <= 1;
    // Raised baskets may extend above the workstation Control's nominal top edge.
    // Keep their visible geometry interactive, including the Lv2 automatic lift.
    public override bool _HasPoint(Vector2 point)
    {
        if (new Rect2(Vector2.Zero, Size).HasPoint(point)) return true;
        return _cooker is not null && Enumerable.Range(0, _cooker.Baskets.Count).Any(i => BasketRect(i).HasPoint(point));
    }
    public string HitTarget(Vector2 p)
    {
        if (_cooker is null) return "";
        if (InBowl(p)) return "bowl";
        if (SauceBottleRect.Grow(4).HasPoint(p)) return "ingredient0";
        for (int i = 0; i < 4; i++) if (IngredientRect(i).Grow(12).HasPoint(p)) return $"ingredient{i}";
        if (BowlRect.HasPoint(p)) return "bowl";
        for (int i = 0; i < _cooker.Baskets.Count; i++)
            if (BasketRect(i).HasPoint(p)) return $"basket{i}";
        if (RawTrayRect.HasPoint(p)) return "raw";
        if (StockRect.HasPoint(p)) return "stock";
        if (NearPan(p) || BatterRect.HasPoint(p) || FillingRect.HasPoint(p)) return "pan";
        if (EggStockRect.HasPoint(p)) return "egg";
        return "";
    }

    public override void _Draw()
    {
        if (_cooker is null) return;
        DrawCooker(); DrawMixStation(); DrawDoupi(); DrawEgg(); DrawRefills(); DrawTransfers(); DrawSupplyLabels(); DrawProductionCues(); DrawGesture();
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
            // body independently of the decorative steam above it.
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
    // Perspective is authored in the new tray art; never stretch separate bands.
    private void DrawTray(Texture2D texture, Rect2 tray)
    {
        DrawSprite(texture, FitSprite(texture, tray), 1, 0);
    }
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
        2 => new Rect2(30, -124, 460.8f, 460.8f),
        3 => new Rect2(25, -105, 470.4f, 470.4f),
        _ => new Rect2(30, -105, 460.8f, 460.8f)
    };
    private Vector2 BasketHome(int index) => CookerCanvas.Position + CookerCanvas.Size *
        (_cookerLevel == 3 ? new Vector2(index == 0 ? .37f : .714f, .477f) : new Vector2(.546f, .437f));
    private Vector2 BasketSize => FitSprite(_art.Texture("basket"), new Rect2(Vector2.Zero, new Vector2(_cookerLevel == 3 ? 144 : 168, _cookerLevel == 3 ? 149 : 174) * 1.2f)).Size;
    public Rect2 BasketRect(int index)
    {
        Motion? m = Find($"basket{index}");
        float raised = IsRaised(_cooker.Baskets[index].State) ? 1 : 0;
        if (m?.Kind == "raise") raised = ReducedMotion ? 1 : Ease(m.Progress);
        Vector2 center = BasketHome(index) + new Vector2(0, -80.4f * raised);
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
            if (HasProductionGesture && _gestureBasket == i && _gesture == "basket" || _cooker.PendingPourBasket == i) continue;
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

    public Vector2 RawCenter => RawRect.GetCenter();
    private void DrawRawTray()
    {
        Hint(RawTrayRect, "raw"); DrawTray(_art.Texture("ingredient_tray"), RawTrayRect);
        Sprite("raw_noodles", RawRect, _ingredients.Count(StableIds.Ingredients.WuhanNoodles) > 0 ? 1 : .25f);

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
            if (i is 1 or 3) DrawTray(_art.Texture(i == 3 ? "beef_tray" : "ingredient_tray"), r);
            bool movingContainer=m?.Kind=="ingredient"&&m.Ingredient==IngredientIds[i]&&i is 0 or 2&&!ReducedMotion;
            if(!movingContainer)Sprite(_art.Ingredient(IngredientIds[i]), IngredientFoodRect(i), _ingredients.Count(IngredientIds[i]) > 0 ? 1 : .3f);
        }
        if(!(m?.Kind=="ingredient"&&m.Ingredient==IngredientIds[0]&&!ReducedMotion))Sprite("base_sauce", SauceBottleRect);
        if (_mixLast is Vector2 pointer && InBowl(pointer))
        {
            Vector2 center = BowlFood.GetCenter();
            float angle = ReducedMotion ? -.3f : (pointer-center).Angle() * .12f - .4f;
            Sprite("chopsticks", At(pointer + new Vector2(30,-40.5f), new Vector2(148.5f,148.5f)), 1, angle);
        }
        else Sprite("chopsticks", ChopsticksRect, .9f, -.15f);
        if (m?.Kind == "ingredient") DrawIngredientMotion(m);
    }
    private static string ToppingArt(string ingredient) => ingredient == StableIds.Ingredients.WuhanScallion ? "scallion"
        : ingredient == StableIds.Ingredients.WuhanChiliOil ? "chili_overlay" : "beef_overlay";
    private static Rect2 ToppingPlacement(Rect2 food, string id) => RelativeRect(food, id switch
    {
        "scallion" => new Rect2(.10f, .12f, .70f, .65f),
        "chili_overlay" => new Rect2(.12f, .14f, .74f, .68f),
        _ => new Rect2(.48f, .28f, .40f, .43f),
    });
    private static IEnumerable<(string Id, Rect2 Rect, float Alpha)> BowlLayers(Rect2 food,
        NoodleBowlState state, float progress, NoodleQuality quality, IEnumerable<string> toppings, string hidden = "")
    {
        yield return ("bowl_noodles", food, 1);
        bool seasoned = state is NoodleBowlState.Seasoned or NoodleBowlState.Mixing or NoodleBowlState.Ready;
        if (seasoned && hidden != StableIds.Ingredients.WuhanBaseSeasoning)
        {
            float half = Mathf.Clamp(progress / 50, 0, 1), mixed = Mathf.Clamp((progress - 40) / 60, 0, 1);
            if (half < 1) yield return ("unmixed", food, 1 - half);
            if (half > 0 && mixed < 1) yield return ("half_mixed", food, half * (1 - mixed));
            if (mixed > 0) yield return ("mixed", food, mixed);
        }
        if (quality == NoodleQuality.Overcooked) yield return ("overcooked", food, seasoned ? .35f : .8f);
        foreach (string topping in toppings)
            if (topping != hidden)
            {
                string id = ToppingArt(topping);
                yield return (id, ToppingPlacement(food, id), 1);
            }
    }
    private void DrawBowlContents(Rect2 food, NoodleBowlState state, float progress, NoodleQuality quality,
        IEnumerable<string> toppings, string hidden = "", float opacity = 1)
    {
        foreach (var layer in BowlLayers(food, state, progress, quality, toppings, hidden))
            FoodLayer(layer.Id, layer.Rect, layer.Alpha * opacity);
    }
    private void DrawIngredientMotion(Motion m)
    {
        if (ReducedMotion) return;
        int index = Array.IndexOf(IngredientIds,m.Ingredient);
        Rect2 source = IngredientFoodRect(index);
        float p=m.Progress, enter=Segment(p,0,.38f), leave=Segment(p,.72f,1);
        Vector2 target=BowlFood.GetCenter()+new Vector2(index<2?-42:48,-70);
        Vector2 center=source.GetCenter().Lerp(target,enter).Lerp(source.GetCenter(),leave);
        if (index is 0 or 2)
        {
            float angle = -.65f*enter*(1-leave);
            Sprite(_art.Ingredient(m.Ingredient), At(center,source.Size), 1, angle);
            if(p>.35f&&p<.74f) DrawLine(center+new Vector2(12,22),BowlFood.GetCenter(),index==0?new Color("#BE803B"):new Color("#CB4627"),6,true);
            if(index==0)
            {
                Vector2 sauceHome = SauceBottleRect.GetCenter();
                Vector2 sauceTarget = target + new Vector2(-145, 0);
                Sprite("base_sauce", At(sauceHome.Lerp(sauceTarget, enter).Lerp(sauceHome, leave), SauceBottleRect.Size), 1, angle);
            }
        }
        else
        {
            string id = ToppingArt(m.Ingredient);
            Rect2 targetRect = ToppingPlacement(BowlFood, id);
            Sprite(id, At(source.GetCenter().Lerp(targetRect.GetCenter(), Ease(p)), source.Size.Lerp(targetRect.Size, Ease(p))), 1 - p);
        }
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
        Hint(StockRect,"stock");DrawTray(_art.Texture("doupi_stock"),StockRect);
        int displayed=_stock.Count;
        Motion? m=Find("pan");
        if(m?.Kind=="stock")displayed=Math.Max(0,displayed-m.Amount);
        for(int i=0;i<displayed;i++)Sprite("doupi_single",StockItemRect(i));
        if(_doupi is null)return;
        Hint(At(PanCenter, PanRect.Size * new Vector2(.7f, .4f)),"pan");
        DoupiState state=_doupi.State;
        if(m?.Kind=="discard"){PanLayer("doupi_egg",1-m.Progress);PanLayer("doupi_burnt",1-m.Progress);}
        if(state!=DoupiState.Empty)
        {
            float grow=m?.Kind=="batter"&&!ReducedMotion?.25f+.75f*Ease(m.Progress):1;
            float flip=m?.Kind=="flip"&&!ReducedMotion?Mathf.Max(.06f,Mathf.Abs(Mathf.Cos(m.Progress*Mathf.Pi))):1;
            bool finished=state is DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cut or DoupiState.Cutting;
            if(!finished)
            {
                PanLayer("doupi_skin",1,grow,flip);
                if(state!=DoupiState.Batter)PanLayer("doupi_egg",m?.Kind=="egg"?Ease(m.Progress):1,1,flip);
                if(state==DoupiState.SecondCooking)PanLayer("doupi_filling_overlay",m?.Kind=="filling"?Ease(m.Progress):1,m?.Kind=="filling"?.4f+.6f*Ease(m.Progress):1);
            }
            else if (state == DoupiState.Cut && m?.Kind != "cut")
            {
                // Draw only the pieces still in the pan after a partial transfer.
                Vector2[] c = PanCorners;
                for (int i = 0; i < _doupi.RemainingPieces; i++)
                {
                    float x = (i % 4 + .5f) / 4, y = (i / 4 + .5f) / 2;
                    Vector2 center = c[0].Lerp(c[1], x).Lerp(c[3].Lerp(c[2], x), y);
                    Sprite("doupi_single", At(center, new Vector2(60, 40)));
                }
            }
            else PanLayer("doupi_finished");
            if(_doupi.Quality==DoupiQuality.Overbrowned)PanLayer("doupi_burnt",.3f);
            if(state==DoupiState.Burnt)PanLayer("doupi_burnt");
            foreach (var direction in _doupi.CutDirections)
            {
                float progress = m?.Kind == "cut" && m.Direction == direction ? m.Progress : 1;
                if (direction == DoupiCutDirection.Horizontal) DrawCut(3, progress);
                else for (int i = 0; i < 3; i++) DrawCut(i, progress);
            }
            if(state is DoupiState.SkinCooking or DoupiState.SecondCooking or DoupiState.ReadyToFlip or DoupiState.ReadyToCut)Steam(PanCenter+new Vector2(0,-30),.7f);
        }
        if(m is not null && !(m.Kind == "cut" && _gesture == "cut"))DrawPanMotion(m);
    }
    private Rect2 StockItemRect(int index)
    {
        int slot = index % 8, layer = index / 8;
        Rect2 tray = FitSprite(_art.Texture("doupi_stock"), StockRect);
        float depth = slot / 4;
        float left = Mathf.Lerp(.18f, .14f, depth), right = 1 - left;
        Vector2 center = tray.Position + tray.Size * new Vector2(
            Mathf.Lerp(left, right, (slot % 4 + .5f) / 4), Mathf.Lerp(.36f, .55f, depth));
        // Inventory thumbnails share positions with transfers; delivery stays full size.
        Vector2 size = new(tray.Size.X * (right - left) / 4 - 2, tray.Size.Y * .27f);
        size = FitSprite(_art.Texture("doupi_single"), At(center, size)).Size;
        center += new Vector2(layer * 1.5f, -layer * 4);
        return At(center, size);
    }
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
                Vector2[] c=PanCorners;int index=m.Direction==DoupiCutDirection.Horizontal?3:1;
                center=index<3?c[0].Lerp(c[1],(index+1)/4f).Lerp(c[3].Lerp(c[2],(index+1)/4f),Ease(p)):c[0].Lerp(c[3],.5f).Lerp(c[1].Lerp(c[2],.5f),Ease(p));
            }
            else center+=new Vector2(35,-Mathf.Sin(p*Mathf.Pi)*60);
            Sprite(m.Kind=="cut"?"cut_tool":_doupiLevel==3?"auto_flip_tool":"flip_tool",At(center+new Vector2(30,-23),new Vector2(138,91)),1,Mathf.Sin(p*Mathf.Pi)*-.4f);
        }
        else if(m.Kind is "batter" or "egg" or "filling")
        {
            Rect2 container = m.Kind == "filling" ? FillingRect : BatterRect;
            Vector2 from=container.GetCenter();
            Vector2 center=from.Lerp(PanCenter+new Vector2(0,-78),Mathf.Sin(p*Mathf.Pi));
            Texture2D tex=m.Kind=="egg"?_art.Shared.Ingredient(StableIds.Ingredients.Egg):_art.Texture(m.Kind=="batter"?"doupi_batter":"doupi_filling");
            Sprite(tex,At(center,m.Kind == "egg" ? new Vector2(73,68) : container.Size),1,-Mathf.Sin(p*Mathf.Pi)*.65f);
            if(p>.2f&&p<.8f)DrawLine(center+new Vector2(0,28),PanCenter,m.Kind=="egg"?new Color("#FFC942"):new Color("#EACD8C"),7,true);
        }
        else if(m.Kind=="stock")
            for(int i=0;i<m.Amount;i++){Rect2 target=StockItemRect(m.StockStart+i);Sprite("doupi_single",At((PanCenter+new Vector2((i%4)*35-55,(i/4)*27)).Lerp(target.GetCenter(),Ease(p)),new Vector2(50,36).Lerp(target.Size,p)));}
    }

    private void DrawEgg()
    {
        Hint(EggStockRect, "egg");
        DrawTray(_art.Texture("egg_tray"), EggStockRect);
        int count = Math.Min(3, _egg?.Count ?? 0);
        if (_draggedProduct == ProductKind.EggRiceWine) count = Math.Min(3, Math.Max(0, (_egg?.Count ?? 0) - 1));
        Motion? motion = Find("egg");
        for (int i = 0; i < (motion?.Kind == "egg_refill" ? 3 : count); i++)
        {
            Rect2 cup = EggCupRect(i);
            float alpha = _egg?.IsRefilling == true ? .45f : 1;
            if (motion?.Kind == "egg_refill")
            {
                cup.Position -= new Vector2(0, ReducedMotion ? 0 : 18 * (1 - Ease(motion.Progress)));
                alpha = .45f + .55f * motion.Progress;
            }
            Sprite("egg_finished", cup, alpha);
        }
    }
    private void DrawRefills()
    {
        foreach(Motion m in _motions.Where(m=>m.Kind=="refill"))
        {
            int index=Array.IndexOf(IngredientIds,m.Ingredient);
            Rect2 target=index<0?RawRect:IngredientFoodRect(index);
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
                Rect2 home=At(m.Origin ?? (BasketHome(m.Index)+new Vector2(0,-67)),BasketSize);
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
