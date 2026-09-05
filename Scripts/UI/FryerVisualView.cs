using Godot;
using ProjectCake.Fryer;

namespace ProjectCake.UI;

/// <summary>
/// Draws the fryer from independent body and basket assets. Basket movement and
/// cooking particles stay procedural so one basket image covers every state.
/// </summary>
public partial class FryerVisualView : Control
{
    private readonly record struct FryerSlotSpec(
        Vector2 Position,
        float RotationDegrees,
        float Scale,
        int DrawOrder);

    // Positions are normalized against the shared square fryer canvas.  They are
    // deliberately authored per basket size instead of being inferred from the
    // mouse release point: dropping means "load the next slot", not "place here".
    private static readonly FryerSlotSpec[] SixSlotLayout =
    {
        new(new Vector2(0.38f, 0.41f), -2.0f, 0.96f, 0),
        new(new Vector2(0.50f, 0.41f),  1.5f, 1.00f, 1),
        new(new Vector2(0.62f, 0.41f), -1.0f, 0.97f, 2),
        new(new Vector2(0.40f, 0.53f),  2.5f, 1.00f, 3),
        new(new Vector2(0.52f, 0.53f), -1.5f, 0.98f, 4),
        new(new Vector2(0.64f, 0.53f),  3.0f, 0.96f, 5),
    };

    private static readonly FryerSlotSpec[] EightSlotLayout =
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
            if (animate && IsInsideTree())
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

        Rect2 canvas = FittedSquare(Size, 2);
        DrawTextureRect(_art.FryerBody(_machine.Level.Level), canvas, false);

        FryerBatchRuntime runtime = _machine.Runtime;
        Rect2 basketPlacement = InterpolateRect(
            BasketPlacementForLevel(_machine.Level.Level),
            LoweredBasketPlacementForLevel(_machine.Level.Level),
            _loweredProgress);
        Rect2 basketRect = ResolveBasketRect(canvas, basketPlacement);
        DrawTextureRect(_art.FryerBasket(_machine.Level.Level), basketRect, false);
        DrawBatch(runtime, canvas, basketPlacement);
        DrawCookingEffects(runtime, canvas, basketPlacement);
    }

    private void DrawBatch(FryerBatchRuntime runtime, Rect2 canvas, Rect2 basketPlacement)
    {
        if (_art is null || _machine is null || runtime.Quantity <= 0) return;
        Texture2D texture = runtime.Quality == YoutiaoQuality.Burnt || runtime.State == FryerState.Burnt
            ? _art.BurntYoutiao
            : runtime.State is FryerState.Empty or FryerState.Loaded ? _art.RawYoutiao : _art.Ingredient(Data.StableIds.Ingredients.Youtiao);
        Color tint = runtime.Quality switch
        {
            YoutiaoQuality.Light when runtime.State == FryerState.Frying => new Color(1f, 0.91f, 0.72f),
            YoutiaoQuality.Deep => new Color(0.78f, 0.56f, 0.34f),
            _ => Colors.White,
        };
        IReadOnlyList<FryerSlotSpec> layout = LayoutForLevel(_machine.Level.Level);
        Vector2 slotBounds = canvas.Size * 0.18f * Mathf.Min(basketPlacement.Size.X, basketPlacement.Size.Y);
        int visibleCount = Math.Min(runtime.Quantity, layout.Count);
        for (int index = 0; index < visibleCount; index++)
        {
            FryerSlotSpec slot = layout[index];
            Vector2 normalizedPosition = basketPlacement.Position + slot.Position * basketPlacement.Size;
            Vector2 center = canvas.Position + canvas.Size * normalizedPosition;
            Vector2 itemSize = FitInside(texture.GetSize(), slotBounds * slot.Scale);
            DrawSetTransform(center, Mathf.DegToRad(slot.RotationDegrees), Vector2.One);
            DrawTextureRect(texture, new Rect2(itemSize * -0.5f, itemSize), false, tint);
        }
        DrawSetTransform(Vector2.Zero, 0, Vector2.One);
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
            DrawCircle(canvas.Position + canvas.Size * normalizedPosition, radius, new Color(bubble, 0.78f * (1f - phase)));
        }
    }

    internal static int SlotCountForLevel(int level) => LayoutForLevel(level).Count;

    internal static bool LayoutMeetsConstraints(int level)
    {
        IReadOnlyList<FryerSlotSpec> layout = LayoutForLevel(level);
        Rect2 basketPlacement = BasketPlacementForLevel(level);
        return layout.Count == (level <= 1 ? 6 : 8)
            && layout.All(slot => slot.Position.X is >= 0.25f and <= 0.75f
                && slot.Position.Y is >= 0.35f and <= 0.60f
                && Math.Abs(slot.RotationDegrees) <= 8
                && slot.Scale is >= 0.85f and <= 1.10f)
            && layout.Select((slot, index) => slot.DrawOrder == index).All(matches => matches)
            && basketPlacement.Position.X >= 0
            && basketPlacement.Position.Y >= -0.05f
            && basketPlacement.End.X <= 1
            && basketPlacement.End.Y <= 1;
    }

    private static IReadOnlyList<FryerSlotSpec> LayoutForLevel(int level) => level <= 1 ? SixSlotLayout : EightSlotLayout;

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
    private static Rect2 FittedSquare(Vector2 size, float margin)
    {
        float side = Mathf.Min(size.X, size.Y) - margin * 2;
        return new Rect2((size - Vector2.One * side) * 0.5f, Vector2.One * side);
    }
}
