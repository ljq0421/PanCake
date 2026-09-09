using Godot;
using ProjectCake.Inventory;

namespace ProjectCake.UI;

/// <summary>
/// Reusable ingredient slot that owns precise stock text, visual tiers,
/// low-stock affordance, and refill progress. Gameplay code only supplies
/// inventory state and the take/refill actions.
/// </summary>
public partial class IngredientStockSlotView : WorkstationSlotView
{
    private readonly Button _refill;
    private readonly ProgressBar _stock;
    private readonly StyleBoxFlat _stockFill;
    private string _displayName = string.Empty;
    private bool _usesCaption;
    private bool _previewsRefill;
    private IngredientStockStatus? _lastStatus;
    private Tween? _feedbackTween;
    private readonly Label _refillHint;

    public IngredientStockSlotView()
    {
        _refill = new Button
        {
            Text = "+",
            FocusMode = FocusModeEnum.All,
            CustomMinimumSize = new Vector2(48, 48),
            Visible = false,
        };
        _refill.AddThemeFontSizeOverride("font_size", 27);
        _refill.Pressed += () => RefillRequested?.Invoke();
        SetRefillControl(_refill);

        _stock = new ProgressBar
        {
            MinValue = 0,
            MaxValue = 100,
            Value = 100,
            ShowPercentage = false,
            CustomMinimumSize = new Vector2(0, 6),
            MouseFilter = MouseFilterEnum.Ignore,
            Visible = false,
        };
        _stock.AddThemeStyleboxOverride("background", StockBarStyle(new Color(0.25f, 0.14f, 0.09f, 0.24f)));
        _stockFill = StockBarStyle(TianjinUi.Green);
        _stock.AddThemeStyleboxOverride("fill", _stockFill);
        SetStockControl(_stock);
        _refillHint = TianjinUi.Label("长按补货", 16, TianjinUi.BrownDark, HorizontalAlignment.Center);
        _refillHint.Name = "HoldRefillHint";
        _refillHint.Position = new Vector2(54, 94);
        _refillHint.Size = new Vector2(140, 26);
        _refillHint.MouseFilter = MouseFilterEnum.Ignore;
        _refillHint.Visible = false;
        _refillHint.AddThemeColorOverride("font_outline_color", TianjinUi.Cream);
        _refillHint.AddThemeConstantOverride("outline_size", 5);
        AddChild(_refillHint);
    }

    public event Action? RefillRequested;

    public Label StockLabel => CountLabel;
    public Button RefillButton => _refill;
    public ProgressBar StockBar => _stock;
    public bool HoldToRefill { get; set; }
    public bool ShowStockNumbers { get; set; } = true;
    private double _holdProgress;

    public void RenderHoldProgress(double progress)
    {
        _holdProgress = progress;
        if (HoldToRefill && progress > 0) { _refillHint.Visible = true; _refillHint.Text = "松开取消"; }
        else { _refillHint.Text = "长按补货"; _refillHint.Visible = HoldToRefill && _lastStatus is IngredientStockStatus.Low or IngredientStockStatus.Empty; }
        if (_lastStatus == IngredientStockStatus.Refilling) return;
        _stock.Visible = progress > 0;
        _stock.Value = progress * 100;
    }

    public void ConfigureStock(
        Texture2D trayTexture,
        Texture2D ingredientTexture,
        string displayName,
        WorkstationSlotSpec spec,
        IngredientVisualMode visualMode)
    {
        _displayName = displayName;
        _usesCaption = spec.CaptionRect.HasValue;
        _previewsRefill = visualMode is IngredientVisualMode.HybridStock or IngredientVisualMode.LooseStock
            or IngredientVisualMode.Single;
        Configure(trayTexture, ingredientTexture, displayName, spec, visualMode);
        if (spec.CaptionRect is Rect2 caption)
        {
            _refillHint.Position = caption.Position;
            _refillHint.Size = caption.Size;
            TianjinUi.ApplyCounterHint(_refillHint);
        }
        CountLabel.Text = "0/0";
        _refill.Name = $"IngredientRefill_{StableNodeKey(Name)}";
        _stock.Name = $"IngredientStock_{StableNodeKey(Name)}";
        _refill.TooltipText = $"补满{displayName}";
    }

    public void RenderStock(
        int quantity,
        int capacity,
        IngredientStockStatus status,
        double refillProgress,
        bool canInteract,
        bool unlimited = false)
    {
        if (unlimited)
        {
            _holdProgress = 0;
            SetStock(1, 1);
            SetIngredientAvailable(true);
            CountLabel.Visible = ShowStockNumbers;
            CountLabel.Text = ShowStockNumbers ? "不限" : string.Empty;
            CountLabel.Modulate = Colors.White;
            _stock.Visible = _refill.Visible = _refillHint.Visible = false;
            _refill.Disabled = true;
            _lastStatus = IngredientStockStatus.Normal;
            return;
        }
        refillProgress = Math.Clamp(refillProgress, 0, 1);
        double fraction = capacity > 0 ? (double)quantity / capacity : 0;
        double shownFraction = status == IngredientStockStatus.Refilling ? refillProgress : fraction;
        CountLabel.Visible = ShowStockNumbers;
        CountLabel.Text = !ShowStockNumbers ? string.Empty : status == IngredientStockStatus.Refilling
            ? $"{refillProgress:P0}"
            : $"{quantity}/{capacity}";
        if (_usesCaption)
        {
            CountLabel.Modulate = Colors.White;
            CountLabel.AddThemeColorOverride("font_color", status == IngredientStockStatus.Normal
                ? TianjinUi.Brown : TianjinUi.BrownDark);
        }
        else CountLabel.Modulate = StatusColor(status);
        // Preview newly replenished portions from the gameplay clock. Inventory
        // stays unchanged and unavailable until the refill actually completes.
        // Recomputing from progress also freezes on pause and resets on cancel.
        int shownQuantity = quantity;
        if (_previewsRefill && status == IngredientStockStatus.Refilling)
        {
            int remaining = Math.Max(0, capacity - quantity);
            shownQuantity += (int)Math.Floor(remaining * refillProgress);
        }
        SetStock(shownQuantity, capacity);
        SetIngredientAvailable(shownQuantity > 0);

        _stock.Value = shownFraction * 100;
        _stock.Visible = status == IngredientStockStatus.Refilling || _holdProgress > 0;
        if (status != IngredientStockStatus.Refilling && _holdProgress > 0) _stock.Value = _holdProgress * 100;
        _stockFill.BgColor = TianjinUi.Green;

        bool needsRefill = status is IngredientStockStatus.Low or IngredientStockStatus.Empty;
        _refillHint.Visible = HoldToRefill && (needsRefill || _holdProgress > 0);
        _refill.Visible = !HoldToRefill && (needsRefill || status == IngredientStockStatus.Refilling);
        _refill.Disabled = !canInteract || status == IngredientStockStatus.Refilling || quantity >= capacity;
        _refill.Text = status == IngredientStockStatus.Refilling ? "…" : "+";
        _refill.TooltipText = status == IngredientStockStatus.Refilling ? $"{_displayName}补货中" : $"补满{_displayName}";

        if (_lastStatus != status)
        {
            bool refillCompleted = _lastStatus == IngredientStockStatus.Refilling
                && status == IngredientStockStatus.Normal;
            ApplyRefillStyle(status);
            _lastStatus = status;
            if (refillCompleted)
            {
                PlayRefillCompleteFeedback();
            }
            else if (status is IngredientStockStatus.Low or IngredientStockStatus.Empty)
            {
                PlayStockAttention(status);
            }
        }
    }

    private void PlayStockAttention(IngredientStockStatus status)
    {
        _feedbackTween?.Kill();
        PivotOffset = Size * 0.5f;
        Scale = Vector2.One;
        Modulate = Colors.White;
        Color tint = status == IngredientStockStatus.Empty
            ? new Color(1f, 0.76f, 0.70f, 1f)
            : new Color(1f, 0.88f, 0.67f, 1f);
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _feedbackTween = tween;
        if (!ReducedMotion)
        {
            tween.TweenProperty(this, "scale", new Vector2(1.025f, 1.025f), 0.10);
        }
        tween.Parallel().TweenProperty(this, "modulate", tint, 0.10);
        tween.TweenProperty(this, "scale", Vector2.One, 0.15);
        tween.Parallel().TweenProperty(this, "modulate", Colors.White, 0.15);
        tween.Finished += () => _feedbackTween = null;
    }

    private void PlayRefillCompleteFeedback()
    {
        _feedbackTween?.Kill();
        PivotOffset = Size * 0.5f;
        Scale = Vector2.One;
        Modulate = Colors.White;
        Tween tween = CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _feedbackTween = tween;
        if (!ReducedMotion)
        {
            tween.TweenProperty(this, "scale", new Vector2(1.035f, 1.035f), 0.11);
        }
        tween.Parallel().TweenProperty(this, "modulate", new Color(0.88f, 1f, 0.80f, 1f), 0.11);
        tween.TweenProperty(this, "scale", Vector2.One, 0.15);
        tween.Parallel().TweenProperty(this, "modulate", Colors.White, 0.15);
        tween.Finished += () => _feedbackTween = null;
    }

    private void ApplyRefillStyle(IngredientStockStatus status)
    {
        Color background = status == IngredientStockStatus.Empty ? new Color("#F3B09E")
            : status == IngredientStockStatus.Refilling ? new Color("#C8DEA8")
            : TianjinUi.Cream;
        foreach ((string state, Color color) in new[]
        {
            ("normal", background),
            ("hover", background.Lightened(0.08f)),
            ("pressed", background.Darkened(0.08f)),
            ("focus", background),
            ("disabled", background.Darkened(0.08f)),
        })
        {
            _refill.AddThemeStyleboxOverride(state, TianjinUi.Box(color, 12, state == "focus" ? 5 : 3, false));
        }
        _refill.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        _refill.AddThemeColorOverride("font_hover_color", TianjinUi.BrownText);
        _refill.AddThemeColorOverride("font_pressed_color", TianjinUi.BrownText);
        _refill.AddThemeColorOverride("font_focus_color", TianjinUi.BrownText);
        _refill.AddThemeColorOverride("font_disabled_color", new Color("#826F5D"));
    }

    private static Color StatusColor(IngredientStockStatus status) => status switch
    {
        IngredientStockStatus.Low => TianjinUi.Orange,
        IngredientStockStatus.Empty => TianjinUi.Red,
        IngredientStockStatus.Refilling => TianjinUi.Green,
        _ => TianjinUi.BrownText,
    };

    private static StyleBoxFlat StockBarStyle(Color color) => new()
    {
        BgColor = color,
        CornerRadiusTopLeft = 3,
        CornerRadiusTopRight = 3,
        CornerRadiusBottomLeft = 3,
        CornerRadiusBottomRight = 3,
    };

    private static bool ReducedMotion => ProjectSettings.HasSetting("accessibility/reduce_motion")
        && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();

    private static string StableNodeKey(StringName slotName)
    {
        const string prefix = "IngredientSlot_";
        string value = slotName.ToString();
        return value.StartsWith(prefix, StringComparison.Ordinal) ? value[prefix.Length..] : value;
    }
}
