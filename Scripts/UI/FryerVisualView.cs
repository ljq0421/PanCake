using Godot;
using ProjectCake.Fryer;
using ProjectCake.Interaction;

namespace ProjectCake.UI;

/// <summary>
/// Draws the fryer from independent body and basket assets. Basket movement and
/// cooking particles stay procedural so one basket image covers every state.
/// </summary>
public partial class FryerVisualView : Control
{
    // Positions are normalized against the shared square fryer canvas.  They are
    // deliberately authored per basket size instead of being inferred from the
    // mouse release point: dropping means "load the next slot", not "place here".
    private static readonly SnapSlot[] SixSlotLayout =
    {
        new(new Vector2(0.38f, 0.41f), -2.0f, 0.96f, 0),
        new(new Vector2(0.50f, 0.41f),  1.5f, 1.00f, 1),
        new(new Vector2(0.62f, 0.41f), -1.0f, 0.97f, 2),
        new(new Vector2(0.40f, 0.53f),  2.5f, 1.00f, 3),
        new(new Vector2(0.52f, 0.53f), -1.5f, 0.98f, 4),
        new(new Vector2(0.64f, 0.53f),  3.0f, 0.96f, 5),
    };

    private static readonly SnapSlot[] EightSlotLayout =
    {
        new(new Vector2(0.32f, 0.41f), -3.0f, 0.95f, 0),
        new(new Vector2(0.44f, 0.41f),  1.0f, 0.98f, 1),
        new(new Vector2(0.56f, 0.41f), -1.5f, 1.00f, 2),
        new(new Vector2(0.68f, 0.41f),  2.5f, 0.96f, 3),
        new(new Vector2(0.34f, 0.53f),  2.0f, 0.98f, 4),
        new(new Vector2(0.46f, 0.53f), -2.0f, 1.00f, 5),
        new(new Vector2(0.58f, 0.53f),  1.5f, 0.97f, 6),
        new(new Vector2(0.70f, 0.53f), -3.0f, 0.95f, 7),
    };

    // The generated basket canvases do not share the same visible bounds even
    // though all source PNGs are 1254x1254.  Lv1/Lv2 therefore need their own
    // target rectangles; Lv3 already lines up with its taller automatic body.
    private static readonly Rect2 LevelOneBasketRect = new(0.06f, -0.02f, 0.88f, 0.88f);
    private static readonly Rect2 LevelTwoBasketRect = new(0.11f, 0.00f, 0.78f, 0.78f);
    private static readonly Rect2 LevelThreeBasketRect = new(0.00f, 0.00f, 1.00f, 1.00f);

    // Measured from the actual PNG artwork.  These are the visible inside edges
    // of each fryer body, not the transparent 1254x1254 source canvas.
    private static readonly Rect2 LevelOneInnerFrame = new(0.135f, 0.140f, 0.730f, 0.395f);
    private static readonly Rect2 LevelTwoInnerFrame = new(0.145f, 0.140f, 0.710f, 0.395f);
    private static readonly Rect2 LevelThreeInnerFrame = new(0.165f, 0.240f, 0.670f, 0.325f);

    // Opaque outer-frame bounds measured from the two independent basket PNGs.
    // Mapping these bounds onto the body inner frame prevents the basket's lower
    // rim from crossing the fryer's inner lower edge after it is lowered.
    private static readonly Rect2 SixBasketVisibleFrame = new(0.111f, 0.262f, 0.778f, 0.385f);
    private static readonly Rect2 EightBasketVisibleFrame = new(0.022f, 0.277f, 0.955f, 0.389f);

    private TianjinArtCatalog? _art;
    private FryerStateMachine? _machine;
    private float _loweredProgress;
    private float _effectPhase;
    private bool _lastLowered;
    private Tween? _basketTween;
    private Node2D _basketAnchor = null!;
    private Node2D _embeddedBasketArt = null!;
    private Node2D _rawFoodAnchor = null!;
    private ShaderMaterial? _rawFoodInk;
    public bool UseTableContact { get; set; }
    public Rect2? EmbeddedOpening { get; set; }
    public Vector2 TableContactAnchor => EmbeddedOpening.HasValue ? new Vector2(Size.X * .5f, Size.Y)
        : FittedSquare(Size, 2).Position + FittedSquare(Size, 2).Size * new Vector2(.5f, .86f);
    public Vector2 OpeningCenter => EmbeddedOpening?.GetCenter()
        ?? FittedSquare(Size, 2).Position + FittedSquare(Size, 2).Size * new Vector2(.5f, .4025f);

    public override void _Ready()
    {
        _basketAnchor = GetNodeOrNull<Node2D>("BasketAnchor")!;
        if (_basketAnchor is null)
        {
            _basketAnchor = new Node2D { Name = "BasketAnchor" };
            AddChild(_basketAnchor); // Programmatic previews may omit the packed scene.
        }
        _basketAnchor.Draw += DrawBasket;
        var basketInk = (ShaderMaterial)FoodInk.Material().Duplicate();
        basketInk.SetShaderParameter("key_green", true);
        basketInk.SetShaderParameter("outline_pixels", 0.4f);
        basketInk.SetShaderParameter("detail_pixels", 0.25f);
        _basketAnchor.Material = basketInk;
        // The metal keeps its painted warm grays. FoodInk's dark-detail pass
        // otherwise tints neutral gray shadows brown along with the food.
        var metalInk = (ShaderMaterial)basketInk.Duplicate();
        metalInk.SetShaderParameter("detail_strength", 0f);
        _embeddedBasketArt = new Node2D {
            Name = "EmbeddedBasketMetal", Material = metalInk, ShowBehindParent = true,
        };
        _basketAnchor.AddChild(_embeddedBasketArt);
        _embeddedBasketArt.Draw += () =>
        {
            if (_art is not null && _machine is not null && EmbeddedOpening is Rect2 opening)
                DrawEmbeddedBasketArt(EmbeddedBasketRect(opening), opening);
        };
        // Food needs the same brown ink as the surrounding hand-drawn artwork,
        // independently of the basket's light mesh treatment. As a child of the
        // basket, this non-interactive layer follows its movement automatically.
        _rawFoodAnchor = new Node2D { Name = "RawFoodInk", Material = RawFoodMaterial() };
        _basketAnchor.AddChild(_rawFoodAnchor);
        _rawFoodAnchor.Draw += DrawRawFood;
    }

    private ShaderMaterial RawFoodMaterial()
    {
        if (_rawFoodInk is not null) return _rawFoodInk;
        _rawFoodInk = (ShaderMaterial)FoodInk.Material().Duplicate();
        _rawFoodInk.SetShaderParameter("outline_pixels", 1.65f);
        return _rawFoodInk;
    }

    private Rect2 BodyCanvas()
    {
        Rect2 canvas = FittedSquare(Size, 2);
        if (!UseTableContact || _machine is null) return canvas;
        // Measured opaque feet, independent of transparent image padding.
        float contact = _machine.Level.Level switch { 1 => 1059f / 1254, 2 => 1049f / 1254, _ => 1107f / 1254 };
        float factor = (.86f - .4025f) / (contact - InnerFrameForLevel(_machine.Level.Level).GetCenter().Y);
        Vector2 size = canvas.Size * factor;
        return new Rect2(TableContactAnchor - size * new Vector2(.5f, contact), size);
    }

    public void Bind(TianjinArtCatalog art, FryerStateMachine machine)
    {
        _art = art;
        _machine = machine;
        _lastLowered = IsLowered(machine.Runtime.State);
        _loweredProgress = _lastLowered ? 1 : 0;
        QueueRedraw();
    }

    public void Tick(double deltaSeconds)
    {
        if (_machine?.Runtime.State == FryerState.Frying)
        {
            _effectPhase += (float)deltaSeconds;
            QueueRedraw();
        }
    }

    public void Refresh(bool animate = true)
    {
        if (_machine is null) return;
        bool lowered = IsLowered(_machine.Runtime.State);
        if (lowered != _lastLowered)
        {
            _lastLowered = lowered;
            float targetProgress = lowered ? 1 : 0;
            _basketTween?.Kill();
            if (animate && IsInsideTree() && !ReducedMotion)
            {
                _basketTween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
                _basketTween.TweenMethod(Callable.From<float>(value =>
                {
                    _loweredProgress = value;
                    QueueRedraw();
                }), _loweredProgress, targetProgress, 0.24);
            }
            else
            {
                _loweredProgress = targetProgress;
            }
        }
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_art is null || _machine is null || Size.X <= 0 || Size.Y <= 0) return;
        _embeddedBasketArt.QueueRedraw();

        if (EmbeddedOpening.HasValue)
        {
            _basketAnchor.Position = Vector2.Zero;
            _basketAnchor.QueueRedraw();
            _rawFoodAnchor.QueueRedraw();
            return;
        }

        Rect2 canvas = BodyCanvas();
        DrawTextureRect(_art.FryerBody(_machine.Level.Level), canvas, false);

        _basketAnchor.Position = canvas.Position;
        _basketAnchor.QueueRedraw();
        _rawFoodAnchor.QueueRedraw();
    }

    private void DrawBasket()
    {
        if (_art is null || _machine is null) return;
        if (EmbeddedOpening is Rect2 opening)
        {
            DrawEmbeddedBasket(opening);
            return;
        }
        Rect2 canvas = new(Vector2.Zero, BodyCanvas().Size);

        FryerBatchRuntime runtime = _machine.Runtime;
        Rect2 basketPlacement = CurrentBasketPlacement();
        Rect2 basketRect = ResolveBasketRect(canvas, basketPlacement);
        _basketAnchor.DrawTextureRect(_art.FryerBasket(_machine.Level.Level), basketRect, false);
        if (!UsesRawFood(runtime)) DrawBatch(_basketAnchor, runtime, canvas, basketPlacement);
        DrawCookingEffects(runtime, canvas, basketPlacement);
        DrawStateIndicator(runtime, canvas, basketPlacement);
    }

    private Rect2 CurrentBasketPlacement()
    {
        Rect2 lowered = LoweredBasketPlacementForLevel(_machine!.Level.Level);
        Rect2 raised = UseTableContact ? new Rect2(lowered.Position + new Vector2(0, -.07f), lowered.Size)
            : BasketPlacementForLevel(_machine.Level.Level);
        return InterpolateRect(
            raised, lowered,
            _loweredProgress);
    }

    private Rect2 EmbeddedBasketRect(Rect2 opening)
    {
        // This is the mouth plane, not the complete sprite including its front
        // wall. The back/front rim now follow the painted tub's full depth.
        return new Rect2(opening.Position + new Vector2(0, -22 * (1 - _loweredProgress)), opening.Size);
    }

    private void DrawEmbeddedBasketArt(Rect2 mouth, Rect2 opening)
    {
        // In the calibrated sprite the rim is at y=0.82; the remaining 18% is the wall below
        // it. Map the rim plane onto the tub, then let the fixed front lip hide
        // that wall as the basket descends. Fitting the entire PNG into the mouth
        // makes its floor too shallow and leaves the front wall floating on top.
        Texture2D texture = _art!.EmbeddedBasket;
        Vector2 canvasSize = new(mouth.Size.X, mouth.Size.Y / .82f);
        float visibleHeight = Mathf.Clamp(opening.End.Y - mouth.Position.Y, 0, canvasSize.Y);
        Rect2 destination = new(mouth.Position, new Vector2(canvasSize.X, visibleHeight));
        Rect2 source = new(Vector2.Zero, texture.GetSize() * new Vector2(1, visibleHeight / canvasSize.Y));
        _embeddedBasketArt.DrawTextureRectRegion(texture, destination, source);
    }

    private void DrawRawFood()
    {
        if (_art is null || _machine is null || !UsesRawFood(_machine.Runtime)) return;
        if (EmbeddedOpening is Rect2 opening)
        {
            Rect2 basket = EmbeddedBasketRect(opening);
            int columns = _machine.Level.Capacity <= 6 ? 3 : 4;
            for (int index = 0; index < _machine.Runtime.Quantity; index++)
                _rawFoodAnchor.DrawTextureRect(_art.RawYoutiao,
                    EmbeddedFoodRect(basket, columns, index, _art.RawYoutiao.GetSize()), false);
            return;
        }
        DrawBatch(_rawFoodAnchor, _machine.Runtime,
            new Rect2(Vector2.Zero, BodyCanvas().Size), CurrentBasketPlacement());
    }

    private static bool UsesRawFood(FryerBatchRuntime runtime) => runtime.State is FryerState.Empty or FryerState.Loaded;

    private void DrawEmbeddedBasket(Rect2 opening)
    {
        TianjinArtCatalog art = _art!;
        FryerBatchRuntime runtime = _machine!.Runtime;
        Rect2 basket = EmbeddedBasketRect(opening);
        int columns = _machine.Level.Capacity <= 6 ? 3 : 4;
        Texture2D food = runtime.State is FryerState.Empty or FryerState.Loaded ? art.RawYoutiao
            : runtime.State == FryerState.Burnt ? art.BurntYoutiao : art.Ingredient(Data.StableIds.Ingredients.Youtiao);
        Color tint = runtime.State is FryerState.Empty or FryerState.Loaded ? Colors.White : YoutiaoPresentation.Tint(runtime.Quality);
        for (int index = 0; !UsesRawFood(runtime) && index < runtime.Quantity; index++)
        {
            _basketAnchor.DrawTextureRect(food, EmbeddedFoodRect(basket, columns, index, food.GetSize()), false, tint);
        }
        if (runtime.State == FryerState.Frying)
            for (int i = 0; i < 7; i++)
            {
                float phase = (_effectPhase + i * .17f) % 1;
                Vector2 point = basket.Position + basket.Size * new Vector2(.18f + i * .1f, .8f - phase * .35f);
                _basketAnchor.DrawCircle(point, 2 + i % 2, new Color(1, .9f, .55f, .8f * (1 - phase)));
            }
        if (runtime.State is FryerState.Raised or FryerState.Draining)
            for (int i = 0; i < 3; i++)
                _basketAnchor.DrawCircle(new Vector2(basket.Position.X + basket.Size.X * (.3f + i * .2f), basket.End.Y + 6),
                    3, new Color(.98f, .67f, .22f, .8f));
    }

    internal static Rect2 EmbeddedFoodRect(Rect2 basket, int columns, int index, Vector2 textureSize)
    {
        Rect2 floor = new(basket.Position + basket.Size * new Vector2(.16f, .22f),
            basket.Size * new Vector2(.68f, .56f));
        // Preserve the same generous single-piece size at every capacity. Distribute
        // the remaining space between overlapping pieces, within the mesh interior.
        Vector2 size = FitInside(textureSize, new Vector2(floor.Size.X * .45f, floor.Size.Y));
        Vector2 travel = floor.Size - size;
        int count = columns * 2;
        Vector2 position = floor.Position + new Vector2(
            index * travel.X / (count - 1), travel.Y);
        return new Rect2(position, size);
    }

    public Control CreateBatchFoodPreview(Vector2 displaySize)
    {
        var preview = new Control { CustomMinimumSize = displaySize, MouseFilter = MouseFilterEnum.Ignore };
        if (_machine is null || _art is null || _machine.Runtime.Quantity <= 0) return preview;
        FryerBatchRuntime runtime = _machine.Runtime;
        Texture2D texture = runtime.State == FryerState.Loaded ? _art.RawYoutiao
            : runtime.State == FryerState.Burnt ? _art.BurntYoutiao : _art.Ingredient(Data.StableIds.Ingredients.Youtiao);
        Color tint = runtime.State == FryerState.Loaded ? Colors.White : YoutiaoPresentation.Tint(runtime.Quality);
        Rect2 basket = EmbeddedOpening ?? new Rect2(Vector2.Zero, new Vector2(300, 180));
        int columns = _machine.Level.Capacity <= 6 ? 3 : 4;
        Rect2[] pieces = Enumerable.Range(0, runtime.Quantity)
            .Select(index => EmbeddedFoodRect(basket, columns, index, texture.GetSize())).ToArray();
        Rect2 bounds = pieces.Aggregate((left, right) => left.Merge(right));
        float scale = Mathf.Min(displaySize.X / bounds.Size.X, displaySize.Y / bounds.Size.Y);
        foreach (Rect2 piece in pieces)
            preview.AddChild(new TextureRect
            {
                Texture = texture, Modulate = tint, MouseFilter = MouseFilterEnum.Ignore,
                Material = runtime.State == FryerState.Loaded ? RawFoodMaterial() : null,
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                Position = displaySize / 2 + (piece.Position - bounds.GetCenter()) * scale,
                Size = piece.Size * scale,
            });
        return preview;
    }

    private void DrawBatch(Node2D target, FryerBatchRuntime runtime, Rect2 canvas, Rect2 basketPlacement)
    {
        if (_art is null || _machine is null || runtime.Quantity <= 0) return;
        Texture2D texture = runtime.Quality == YoutiaoQuality.Burnt || runtime.State == FryerState.Burnt
            ? _art.BurntYoutiao
            : runtime.State is FryerState.Empty or FryerState.Loaded ? _art.RawYoutiao : _art.Ingredient(Data.StableIds.Ingredients.Youtiao);
        Color tint = runtime.State is FryerState.Empty or FryerState.Loaded
            ? Colors.White : YoutiaoPresentation.Tint(runtime.Quality);
        IReadOnlyList<SnapSlot> layout = LayoutForLevel(_machine.Level.Level);
        Vector2 slotBounds = canvas.Size * 0.18f * Mathf.Min(basketPlacement.Size.X, basketPlacement.Size.Y);
        int visibleCount = Math.Min(runtime.Quantity, layout.Count);
        for (int index = 0; index < visibleCount; index++)
        {
            SnapSlot slot = layout[index];
            Vector2 normalizedPosition = basketPlacement.Position + slot.NormalizedPosition * basketPlacement.Size;
            Vector2 center = canvas.Position + canvas.Size * normalizedPosition;
            Vector2 itemSize = FitInside(texture.GetSize(), slotBounds * slot.Scale);
            target.DrawSetTransform(center, Mathf.DegToRad(slot.RotationDegrees), Vector2.One);
            target.DrawTextureRect(texture, new Rect2(itemSize * -0.5f, itemSize), false, tint);
        }
        target.DrawSetTransform(Vector2.Zero, 0, Vector2.One);
    }

    private void DrawCookingEffects(FryerBatchRuntime runtime, Rect2 canvas, Rect2 basketPlacement)
    {
        if (runtime.State != FryerState.Frying || runtime.Quantity <= 0) return;
        Color bubble = new(1f, 0.91f, 0.55f, 0.78f);
        for (int i = 0; i < 7; i++)
        {
            float phase = (_effectPhase * (0.9f + i * 0.07f) + i * 0.19f) % 1f;
            float x = 0.32f + ((i * 37) % 43) / 100f;
            float y = 0.61f - phase * 0.19f;
            Vector2 normalizedPosition = basketPlacement.Position + new Vector2(x, y) * basketPlacement.Size;
            float radius = canvas.Size.X * basketPlacement.Size.X * (0.008f + (i % 3) * 0.003f);
            _basketAnchor.DrawCircle(canvas.Position + canvas.Size * normalizedPosition, radius, new Color(bubble, 0.78f * (1f - phase)));
        }
    }

    private void DrawStateIndicator(FryerBatchRuntime runtime, Rect2 canvas, Rect2 basketPlacement)
    {
        if (runtime.Quantity <= 0) return;
        Rect2 basket = ResolveBasketRect(canvas, basketPlacement);
        if (runtime.State == FryerState.Frying && runtime.Quality == YoutiaoQuality.Golden)
        {
            Color ready = new(1f, 0.75f, 0.18f, 0.92f);
            float y = basket.Position.Y + basket.Size.Y * 0.29f;
            for (int index = -1; index <= 1; index++)
            {
                Vector2 center = new(basket.GetCenter().X + index * basket.Size.X * 0.16f, y);
                _basketAnchor.DrawArc(center, 8, Mathf.Pi * 1.10f, Mathf.Pi * 1.90f, 12, ready, 4, true);
            }
        }
        else if (runtime.State is FryerState.Raised or FryerState.Draining)
        {
            Color drop = new(0.98f, 0.67f, 0.22f, 0.82f);
            float progress = runtime.State == FryerState.Draining && _machine is not null
                ? Mathf.Clamp((float)(runtime.DrainSeconds / _machine.Level.DrainSeconds), 0, 1)
                : 0;
            for (int index = -1; index <= 1; index++)
            {
                float offset = (index + 1) * 0.14f + progress * 0.08f;
                Vector2 center = new(basket.GetCenter().X + index * basket.Size.X * 0.13f, basket.End.Y - basket.Size.Y * offset);
                _basketAnchor.DrawCircle(center, 4, drop);
            }
        }
        else if (runtime.State == FryerState.Burnt)
        {
            Vector2 center = basket.GetCenter() + new Vector2(0, -basket.Size.Y * 0.08f);
            Vector2 diagonal = new(11, 11);
            _basketAnchor.DrawLine(center - diagonal, center + diagonal, TianjinUi.Red, 5, true);
            _basketAnchor.DrawLine(center + new Vector2(-diagonal.X, diagonal.Y), center + new Vector2(diagonal.X, -diagonal.Y), TianjinUi.Red, 5, true);
        }
    }

    internal static int SlotCountForLevel(int level) => LayoutForLevel(level).Count;

    internal static bool LayoutMeetsConstraints(int level)
    {
        IReadOnlyList<SnapSlot> layout = LayoutForLevel(level);
        Rect2 basketPlacement = BasketPlacementForLevel(level);
        return layout.Count == (level <= 1 ? 6 : 8)
            && layout.All(slot => slot.NormalizedPosition.X is >= 0.25f and <= 0.75f
                && slot.NormalizedPosition.Y is >= 0.35f and <= 0.60f
                && Math.Abs(slot.RotationDegrees) <= 8
                && slot.Scale is >= 0.85f and <= 1.10f)
            && layout.Select((slot, index) => slot.DrawOrder == index).All(matches => matches)
            && basketPlacement.Position.X >= 0
            && basketPlacement.Position.Y >= -0.05f
            && basketPlacement.End.X <= 1
            && basketPlacement.End.Y <= 1;
    }

    private static IReadOnlyList<SnapSlot> LayoutForLevel(int level) => level <= 1 ? SixSlotLayout : EightSlotLayout;

    private static Rect2 BasketPlacementForLevel(int level) => level switch
    {
        <= 1 => LevelOneBasketRect,
        2 => LevelTwoBasketRect,
        _ => LevelThreeBasketRect,
    };

    internal static bool LoweredBasketFitsInnerFrame(int level)
    {
        Rect2 target = InnerFrameForLevel(level);
        Rect2 visible = MapVisibleFrame(LoweredBasketPlacementForLevel(level), BasketVisibleFrameForLevel(level));
        const float tolerance = 0.002f;
        return Math.Abs(visible.Position.X - target.Position.X) <= tolerance
            && Math.Abs(visible.Position.Y - target.Position.Y) <= tolerance
            && Math.Abs(visible.End.X - target.End.X) <= tolerance
            && visible.End.Y <= target.End.Y + tolerance;
    }

    private static Rect2 LoweredBasketPlacementForLevel(int level)
    {
        return FitVisibleFrame(BasketVisibleFrameForLevel(level), InnerFrameForLevel(level));
    }

    private static Rect2 InnerFrameForLevel(int level) => level switch
    {
        <= 1 => LevelOneInnerFrame,
        2 => LevelTwoInnerFrame,
        _ => LevelThreeInnerFrame,
    };

    private static Rect2 BasketVisibleFrameForLevel(int level) => level <= 1 ? SixBasketVisibleFrame : EightBasketVisibleFrame;

    private static Rect2 FitVisibleFrame(Rect2 visibleFrame, Rect2 targetFrame)
    {
        Vector2 placementSize = targetFrame.Size / visibleFrame.Size;
        Vector2 placementPosition = targetFrame.Position - visibleFrame.Position * placementSize;
        return new Rect2(placementPosition, placementSize);
    }

    private static Rect2 MapVisibleFrame(Rect2 placement, Rect2 visibleFrame)
    {
        return new Rect2(
            placement.Position + visibleFrame.Position * placement.Size,
            visibleFrame.Size * placement.Size);
    }

    private static Rect2 InterpolateRect(Rect2 from, Rect2 to, float weight)
    {
        return new Rect2(from.Position.Lerp(to.Position, weight), from.Size.Lerp(to.Size, weight));
    }

    private static Rect2 ResolveBasketRect(Rect2 canvas, Rect2 placement)
    {
        return new Rect2(canvas.Position + canvas.Size * placement.Position, canvas.Size * placement.Size);
    }

    private static Vector2 FitInside(Vector2 sourceSize, Vector2 bounds)
    {
        if (sourceSize.X <= 0 || sourceSize.Y <= 0) return bounds;
        float factor = Mathf.Min(bounds.X / sourceSize.X, bounds.Y / sourceSize.Y);
        return sourceSize * factor;
    }

    private static bool IsLowered(FryerState state) => state is FryerState.Frying or FryerState.Burnt;
    private static bool ReducedMotion => ProjectSettings.HasSetting("accessibility/reduce_motion")
        && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();
    private static Rect2 FittedSquare(Vector2 size, float margin)
    {
        float side = Mathf.Min(size.X, size.Y) - margin * 2;
        return new Rect2((size - Vector2.One * side) * 0.5f, Vector2.One * side);
    }
}
