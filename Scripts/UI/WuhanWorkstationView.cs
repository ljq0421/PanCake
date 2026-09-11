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
    public Func<bool>? BatterRequested, EggRequested, FillingRequested, FlipRequested, DiscardRequested;
    public Func<Vector2, Vector2, bool>? SpreadRequested;
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
            ProductKind.Doupi => _doupi is not null && _stock.Count > 0,
            ProductKind.EggRiceWine => false,
            _ => false,
        };

    public void ConfigureDelivery(DragService drag)
    {
        if (_drag == drag && _deliverySources.Count == 2) return;
        GetNode<Control>("WuhanDrag_EggRiceWine").Hide();
        _drag = drag;
        drag.DragStarted += OnDragStarted;
        drag.DragEnded += OnDragEnded;
        foreach (ProductKind kind in new[] { ProductKind.HotDryNoodles, ProductKind.Doupi })
        {
            DragItem source = GetNode<DragItem>($"WuhanDrag_{kind}");
            source.DragDisplaySize = kind switch {
                ProductKind.HotDryNoodles => _layout.Bowl.Size,
                ProductKind.Doupi => new Vector2(100, 75), _ => new Vector2(100, 50),
            };
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
            if (kind == ProductKind.HotDryNoodles) source.DragDisplaySize = BowlRect.Size;
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
            Rect2 food = new(BowlFood.Position - BowlRect.Position, BowlFood.Size);
            Texture2D sheet = _art.WorkbenchBackground(_doupi is not null);
            Vector2[] outline = _layout.BowlOutline;
            root.AddChild(new Polygon2D {
                Polygon = outline.Select(p => p - BowlRect.Position).ToArray(),
                UV = outline.Select(p => p / WuhanWorkbenchLayout.DesignSize * sheet.GetSize()).ToArray(),
                Texture = sheet,
            });
            foreach (var layer in BowlLayers(food, _bowl.State, (float)_bowl.MixProgress, _bowl.Quality, _bowl.Toppings))
                Layer(layer.Id, layer.Rect, alpha: layer.Alpha);
        }
        else if (kind == ProductKind.Doupi && _stock.Count > 0)
        {
            DoupiInventory.Piece piece = _stock.PieceAt(0);
            Rect2 source = RelativeRect(DoupiSurface, PieceRegion(piece.Tile));
            foreach (string id in new[] { "doupi_skin", "doupi_filling_overlay" })
            {
                Texture2D texture = _art.Texture(id);
                root.AddChild(new Polygon2D { Polygon = RectQuad(new Rect2(0, 0, 100, 60)),
                    UV = RectQuad(source).Select(p => p * texture.GetSize()).ToArray(), Texture = texture, Color = CookedTint(1) });
            }
            if (piece.Quality == DoupiQuality.Overbrowned)
            {
                Texture2D texture = _art.Texture("doupi_burnt");
                root.AddChild(new Polygon2D { Polygon = RectQuad(new Rect2(0, 0, 100, 60)),
                    UV = RectQuad(source).Select(p => p * texture.GetSize()).ToArray(), Texture = texture, Color = new Color(1, 1, 1, .3f) });
            }
        }
        return root;
    }

    public static readonly string[] IngredientIds = { StableIds.Ingredients.WuhanBaseSeasoning,
        StableIds.Ingredients.WuhanScallion, StableIds.Ingredients.WuhanChiliOil, StableIds.Ingredients.WuhanBraisedBeef };
    private WuhanArtCatalog _art = null!;
    private WuhanWorkbenchLayout _layout = WuhanWorkbenchLayout.Noodles;
    private NoodleCookerStateMachine _cooker = null!;
    private HotDryNoodlesStateMachine _bowl = null!;
    private DoupiStateMachine? _doupi;
    private DoupiInventory _stock = null!;
    public int PendingDoupiDemand { get; set; }
    private WuhanIngredientInventory _ingredients = null!;
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
        public DoupiCutLine Line;
        public float Lift;
        public string Ingredient = "";
        public NoodleQuality Quality;
        public DoupiState Before;
        public DoupiQuality DoupiQuality;
    }

    // The view shares the background's 1920x1080 coordinate system.
    private Rect2 BowlRect => _layout.Bowl;
    private Rect2 BowlFood => _layout.BowlFood;
    private Rect2 PanRect => _layout.Pan;
    private Rect2 StockRect => _layout.Stock;
    private static readonly Rect2 EggStockRect = WuhanWorkbenchLayout.EggUi;
    private Rect2 RawTrayRect => _layout.Raw;
    private Rect2 RawRect => _layout.RawFood;
    private Rect2 IngredientRect(int index) => _layout.Ingredient(index);
    private Rect2 BatterRect => _layout.Batter;
    private Rect2 FillingRect => _layout.Filling;
    private Rect2 DoupiEggRect => _layout.DoupiEgg;
    public Vector2 BatterCenter => BatterRect.GetCenter();
    public Vector2 FillingCenter => FillingRect.GetCenter();
    public Vector2 DoupiEggCenter => DoupiEggRect.GetCenter();
    public Vector2 PanPoint(float x, float y) => QuadPoint(PanCorners, x, y);
    public float PanAspect => ((PanCorners[1] - PanCorners[0]).Length() + (PanCorners[2] - PanCorners[3]).Length())
        / ((PanCorners[3] - PanCorners[0]).Length() + (PanCorners[2] - PanCorners[1]).Length());
    public Vector2 BowlStatusPosition => new(BowlRect.Position.X, BowlRect.End.Y + 10);
    public Vector2 DoupiStatusPosition => new(PanRect.Position.X, PanRect.End.Y + 10);
    public Vector2 EggStatusPosition => EggStockRect.Position;
    public Vector2 BasketStatusPosition(int index) => BasketHome(index) + new Vector2(-50, -100);
    private Rect2 IngredientFoodRect(int index) => RelativeRect(IngredientRect(index), new Rect2(.12f, .15f, .76f, .45f));
    public Vector2 BowlCenter => BowlFood.GetCenter();
    public Vector2 IngredientCenter(int index) => IngredientRect(index).GetCenter();
    public Vector2 StockCenter => StockRect.GetCenter();
    public Vector2 PanCenter => (PanCorners[0] + PanCorners[2]) / 2;
    public Vector2 CupCenter => EggStockRect.GetCenter();

    public override void _Ready()
    {
        MouseExited += () => { _hover = ""; _pointer = new Vector2(-1000, -1000); QueueRedraw(); };
    }

    public void Bind(WuhanArtCatalog art, NoodleCookerStateMachine cooker, HotDryNoodlesStateMachine bowl,
        DoupiStateMachine? doupi, DoupiInventory stock, bool eggUnlocked,
        WuhanIngredientInventory ingredients, int cookerLevel, int doupiLevel)
    {
        CancelAnimations();
        _art = art; _cooker = cooker; _bowl = bowl; _doupi = doupi; _stock = stock;
        _layout = WuhanWorkbenchLayout.ForStage(doupi is not null);
        PendingDoupiDemand = 0; _ingredients = ingredients;
        _bounds.Clear(); _phase=0; _pointer = new Vector2(-1000, -1000); TooltipText = "";
        MouseDefaultCursorShape = CursorShape.Arrow;
        RememberStates(); BindRefillControls(); RefreshRefillControls(); RefreshDeliverySources(); QueueRedraw();
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
        m.Index = index; m.Quality = quality; m.Origin = origin ?? (kind == "drop" ? _rawDropOrigin : null); RememberStates();
    }
    public void PlayIngredient(string ingredient)
    {
        Play("ingredient", .48, "bowl").Ingredient = ingredient;
    }
    public void PlayDoupi(DoupiState before)
    {
        string kind = before switch { DoupiState.Empty => "batter", DoupiState.Batter => "egg",
            DoupiState.ReadyToFlip => "flip", DoupiState.Flipped => "filling", DoupiState.Burnt => "discard", _ => "cut" };
        Motion m = Play(kind, kind == "flip" ? .48 : .36, "pan");
        m.Before = before;
        RememberStates();
    }
    public void PlayCut(DoupiCutLine line)
    {
        Motion m = Play("cut", .36, "pan"); m.Line = line;
        if (_gesture == "cut") m.Origin = _gesturePoint;
        RememberStates();
    }
    private void PlayFlipReturn(float lift) => Play("flip_return", .16, "pan").Lift = lift;
    public void PlayStock(int amount, int stockStart, int firstPiece = 0, DoupiQuality quality = DoupiQuality.Normal)
    {
        Motion m = Play("stock", .48, "pan", "stock");
        m.Amount = amount; m.StockStart = stockStart; m.Index = firstPiece; m.DoupiQuality = quality; RememberStates();
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
            else if (hit == "doupi_egg") EggRequested?.Invoke();
            else if (hit == "pan" && _doupi?.State == DoupiState.Burnt) DiscardRequested?.Invoke();
            else if (hit == "pan" && _doupi is not null) GestureRejected?.Invoke(HoverDescription("pan"));
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
        if (_cooker is null) return false;
        return (point.Y >= 560 && new Rect2(Vector2.Zero, Size).HasPoint(point))
            || (_doupi is not null && NearPan(point))
            || BowlRect.HasPoint(point)
            || Enumerable.Range(0, _cooker.Baskets.Count).Any(i => BasketRect(i).HasPoint(point));
    }
    public string HitTarget(Vector2 p)
    {
        if (_cooker is null) return "";
        if (InBowl(p)) return "bowl";
        for (int i = 0; i < 4; i++) if (IngredientRect(i).HasPoint(p)) return $"ingredient{i}";
        if (BowlRect.HasPoint(p)) return "bowl";
        for (int i = 0; i < _cooker.Baskets.Count; i++)
            if (BasketRect(i).HasPoint(p)) return $"basket{i}";
        if (RawTrayRect.HasPoint(p)) return "raw";
        if (_doupi is not null && StockRect.HasPoint(p)) return "stock";
        if (_doupi is not null)
        {
            if (DoupiEggRect.HasPoint(p)) return "doupi_egg";
            if (BatterRect.HasPoint(p)) return "batter";
            if (FillingRect.HasPoint(p)) return "filling";
            if (NearPan(p)) return "pan";
        }
        return "";
    }

    public override void _Draw()
    {
        if (_cooker is null) return;
        DrawCounterForeground();
        DrawCooker(); DrawMixStation(); DrawDoupi(); DrawTransfers(); DrawSupplyLabels(); DrawProductionCues(); DrawGesture();
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

    private Rect2 CookerCanvas => _layout.Cooker;
    private Vector2 BasketHome(int index) => _layout.BasketHome(index, _cooker.Baskets.Count);
    private Vector2 BasketSize => FitSprite(_art.Texture("basket"), new Rect2(0, 0, 156, 177)).Size;

    // Restore the counter above customers, including the pot silhouette above the rear edge.
    private void DrawCounterForeground()
    {
        Texture2D sheet = _art.WorkbenchBackground(_doupi is not null);
        Rect2 table = new(0, 560, 1920, 520);
        DrawTextureRectRegion(sheet, table, new Rect2(table.Position / WuhanWorkbenchLayout.DesignSize * sheet.GetSize(),
            table.Size / WuhanWorkbenchLayout.DesignSize * sheet.GetSize()));
        void Restore(Vector2[] outline) => DrawPolygon(outline, new[] { Colors.White },
            outline.Select(p => p / WuhanWorkbenchLayout.DesignSize).ToArray(), sheet);
        Restore(_layout.CookerOutline);
        Restore(_layout.BowlOutline);
        if (_doupi is not null) Restore(_layout.PanOutline);
    }

    public Rect2 BasketRect(int index)
    {
        Motion? m = Find($"basket{index}");
        float raised = IsRaised(_cooker.Baskets[index].State) ? 1 : 0;
        if (m?.Kind == "raise") raised = ReducedMotion ? 1 : Ease(m.Progress);
        Vector2 center = BasketHome(index) + new Vector2(0, -80.4f * raised);
        if (m?.Kind == "shake" && !ReducedMotion) center.Y += Mathf.Sin(m.Progress * Mathf.Tau * 2) * 10;
        return At(center, BasketSize);
    }
    private static Rect2 BasketFoodRect(Rect2 basket) => RelativeRect(basket, new Rect2(.10f, .48f, .50f, .37f));
    private void BasketFront(Rect2 basket)
    {
        Texture2D texture = _art.Texture("basket");
        Rect2 strip = new(0, .76f, 1, .24f);
        DrawTextureRectRegion(texture, RelativeRect(basket, strip), RelativeRect(Source(texture), strip));
    }
    private void DrawLoadedBasket(Rect2 basket, string food = "cooked_basket")
    {
        Sprite("basket", basket);
        Sprite(food, BasketFoodRect(basket));
        BasketFront(basket);
    }
    private void DrawCooker()
    {
        // Pot and water are already in the sheet; baskets remain functional overlays.
        for (int i = 0; i < _cooker.Baskets.Count; i++)
        {
            Motion? m = Find($"basket{i}"); NoodleBasketRuntime basket = _cooker.Baskets[i];
            if (HasProductionGesture && _gestureBasket == i && _gesture == "basket" || _cooker.PendingPourBasket == i) continue;
            if (m?.Kind == "pour" && !ReducedMotion) continue;
            Rect2 r = BasketRect(i); Hint(r, $"basket{i}"); Sprite("basket", r);
            if (basket.State != NoodleBasketState.Empty)
            {
                Rect2 noodles = BasketFoodRect(r);
                if (m?.Kind == "drop" && !ReducedMotion)
                {
                    float p = Ease(m.Progress); noodles = At((m.Origin ?? RawRect.GetCenter()).Lerp(noodles.GetCenter(), p), noodles.Size);
                }
                Sprite(basket.Quality == NoodleQuality.Overcooked ? "overcooked" : basket.State == NoodleBasketState.Cooking ? "raw_noodles" : "cooked_basket", noodles);
                BasketFront(r);
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
        Hint(RawTrayRect, "raw");
        if (!_ingredients.CanUse(StableIds.Ingredients.WuhanNoodles))
            Ellipse(RawRect.GetCenter(), RawRect.Size * .48f, new Color(.15f, .12f, .08f, .32f));
    }

    private void DrawCookerFront()
    {
        // Sample only the front half of the pot, preserving the water above its curved rim.
        Vector2[] edge = _layout.CookerFront;
        DrawPolygon(edge, new[] { Colors.White }, edge.Select(p => p / WuhanWorkbenchLayout.DesignSize).ToArray(),
            _art.WorkbenchBackground(_doupi is not null));
    }

    private void DrawMixStation()
    {
        Hint(BowlRect, "bowl");
        Motion? m = Find("bowl");
        bool delivering = _draggedProduct == ProductKind.HotDryNoodles;
        if (!delivering)
        {
            if (_bowl.State != NoodleBowlState.Empty && !(m?.Kind == "pour" && m.Progress < .66f && !ReducedMotion))
                DrawBowlContents(BowlFood, _bowl.State, (float)_bowl.MixProgress, _bowl.Quality, _bowl.Toppings,
                    m?.Kind == "ingredient" && m.Progress < .62f ? m.Ingredient : "");
        }
        for (int i = 0; i < 4; i++) Hint(IngredientRect(i), $"ingredient{i}");
        if (_mixLast is Vector2 pointer && InBowl(pointer))
        {
            Vector2 center = BowlFood.GetCenter();
            float angle = ReducedMotion ? -.3f : (pointer-center).Angle() * .12f - .4f;
            Sprite("chopsticks", At(pointer + new Vector2(30,-40.5f), new Vector2(148.5f,148.5f)), 1, angle);
        }
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
        int index = Array.IndexOf(IngredientIds, m.Ingredient);
        float p = Ease(m.Progress);
        Vector2 start = IngredientFoodRect(index).GetCenter(), end = BowlFood.GetCenter();
        Vector2 center = start.Lerp(end, p) - new Vector2(0, Mathf.Sin(p * Mathf.Pi) * 75);
        if (index is 0 or 2)
        {
            // Move a spoonful, not a second copy of the baked-in container.
            Color sauce = index == 0 ? new Color("#BE803B") : new Color("#CB4627");
            Ellipse(center, new Vector2(13, 7), sauce);
            DrawLine(center + new Vector2(8, -2), center + new Vector2(29, -24), WuhanUi.Ink, 4, true);
        }
        else Sprite(ToppingArt(m.Ingredient), At(center, new Vector2(48, 33)), 1 - p * .5f);
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
                    Rect2 contents = BasketFoodRect(At(center, home.Size));
                    Vector2 start=center+(contents.GetCenter()-center).Rotated(angle);
                    Sprite(m.Quality==NoodleQuality.Overcooked?"overcooked":"cooked_basket",At(start.Lerp(BowlFood.GetCenter(),fall),contents.Size.Lerp(BowlFood.Size,fall)),1,angle*(1-fall));
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
