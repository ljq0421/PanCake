using Godot;
using ProjectCake.Fryer;

namespace ProjectCake.UI;

/// <summary>
/// Draws the fryer from independent body and basket assets. Basket movement and
/// cooking particles stay procedural so one basket image covers every state.
/// </summary>
public partial class FryerVisualView : Control
{
    private TianjinArtCatalog? _art;
    private FryerStateMachine? _machine;
    private float _basketOffset;
    private float _effectPhase;
    private bool _lastLowered;
    private Tween? _basketTween;

    public void Bind(TianjinArtCatalog art, FryerStateMachine machine)
    {
        _art = art;
        _machine = machine;
        _lastLowered = IsLowered(machine.Runtime.State);
        _basketOffset = _lastLowered ? LoweredOffset : 0;
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
            float target = lowered ? LoweredOffset : 0;
            _basketTween?.Kill();
            if (animate && IsInsideTree())
            {
                _basketTween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
                _basketTween.TweenMethod(Callable.From<float>(value =>
                {
                    _basketOffset = value;
                    QueueRedraw();
                }), _basketOffset, target, 0.24);
            }
            else
            {
                _basketOffset = target;
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
        Vector2 shift = new(0, _basketOffset);
        DrawTextureRect(_art.FryerBasket(_machine.Level.Level), new Rect2(canvas.Position + shift, canvas.Size), false);
        DrawBatch(runtime, canvas, shift);
        DrawCookingEffects(runtime, canvas);
    }

    private void DrawBatch(FryerBatchRuntime runtime, Rect2 canvas, Vector2 shift)
    {
        if (_art is null || runtime.Quantity <= 0) return;
        Texture2D texture = runtime.Quality == YoutiaoQuality.Burnt || runtime.State == FryerState.Burnt
            ? _art.BurntYoutiao
            : runtime.State is FryerState.Empty or FryerState.Loaded ? _art.RawYoutiao : _art.Ingredient(Data.StableIds.Ingredients.Youtiao);
        Color tint = runtime.Quality switch
        {
            YoutiaoQuality.Light when runtime.State == FryerState.Frying => new Color(1f, 0.91f, 0.72f),
            YoutiaoQuality.Deep => new Color(0.78f, 0.56f, 0.34f),
            _ => Colors.White,
        };
        Vector2[] slots =
        {
            new(0.35f, 0.42f), new(0.47f, 0.41f), new(0.59f, 0.42f), new(0.41f, 0.50f),
            new(0.53f, 0.49f), new(0.65f, 0.50f), new(0.45f, 0.57f), new(0.58f, 0.57f),
        };
        Vector2 itemSize = canvas.Size * new Vector2(0.17f, 0.105f);
        for (int i = 0; i < Math.Min(runtime.Quantity, slots.Length); i++)
        {
            Vector2 center = canvas.Position + canvas.Size * slots[i] + shift;
            Rect2 target = new(center - itemSize * 0.5f, itemSize);
            DrawTextureRect(texture, target, false, tint);
        }
    }

    private void DrawCookingEffects(FryerBatchRuntime runtime, Rect2 canvas)
    {
        if (runtime.State != FryerState.Frying || runtime.Quantity <= 0) return;
        Color bubble = new(1f, 0.91f, 0.55f, 0.78f);
        for (int i = 0; i < 7; i++)
        {
            float phase = (_effectPhase * (0.9f + i * 0.07f) + i * 0.19f) % 1f;
            float x = 0.32f + ((i * 37) % 43) / 100f;
            float y = 0.61f - phase * 0.19f;
            float radius = canvas.Size.X * (0.008f + (i % 3) * 0.003f);
            DrawCircle(canvas.Position + canvas.Size * new Vector2(x, y), radius, new Color(bubble, 0.78f * (1f - phase)));
        }
    }

    private float LoweredOffset => Mathf.Clamp(Size.Y * 0.075f, 9, 16);
    private static bool IsLowered(FryerState state) => state is FryerState.Frying or FryerState.Burnt;
    private static Rect2 FittedSquare(Vector2 size, float margin)
    {
        float side = Mathf.Min(size.X, size.Y) - margin * 2;
        return new Rect2((size - Vector2.One * side) * 0.5f, Vector2.One * side);
    }
}
