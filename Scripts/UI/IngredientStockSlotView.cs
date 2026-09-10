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
    private Button _refill = null!;
    private ProgressBar _stock = null!;
    private StyleBoxFlat _stockFill = null!;
    private string _displayName = string.Empty;
    private bool _usesCaption;
    private bool _previewsRefill;
    private IngredientStockStatus? _lastStatus;
    private Tween? _feedbackTween;
    private Label _refillHint = null!;

    public override void _Ready()
    {
        base._Ready();
        SceneNodeBinder.Bind(this);
        if (HasMeta("_stock_display_name"))
        {
            _displayName = GetMeta("_stock_display_name").AsString();
            _usesCaption = GetMeta("_stock_uses_caption").AsBool();
            _previewsRefill = GetMeta("_stock_previews_refill").AsBool();
            HoldToRefill = GetMeta("_stock_hold_to_refill").AsBool();
            ShowStockNumbers = GetMeta("_stock_show_numbers").AsBool();
        }
        _stockFill = (StyleBoxFlat)_stock.GetThemeStylebox("fill");
        _refill.Pressed += () => RefillRequested?.Invoke();
    }

    public override void SaveSceneConfiguration()
    {
        base.SaveSceneConfiguration();
        SetMeta("_stock_display_name", _displayName);
        SetMeta("_stock_uses_caption", _usesCaption);
        SetMeta("_stock_previews_refill", _previewsRefill);
        SetMeta("_stock_hold_to_refill", HoldToRefill);
        SetMeta("_stock_show_numbers", ShowStockNumbers);
    }

    public event Action? RefillRequested;

    public Label StockLabel => CountLabel;
    public Button RefillButton => _refill;
    public ProgressBar StockBar => _stock;
    public bool HoldToRefill { get; set; }
    public bool ShowStockNumbers { get; set; } = true;
    private double _holdProgress;
    private bool? _refillTeaching;
    private bool _refillAvailable;

    public void ConfigureRefillTeaching(bool needed)
    {
        _refillTeaching = needed;
        RefreshRefillHint();
    }

    private void RefreshRefillHint()
    {
        bool low = _lastStatus is IngredientStockStatus.Low or IngredientStockStatus.Empty;
        _refillHint.Visible = HoldToRefill && (_holdProgress > 0 || low || _refillTeaching == true && _refillAvailable);
        _refillHint.Text = _holdProgress > 0 ? "松开取消" : _refillTeaching == false
            ? _lastStatus == IngredientStockStatus.Empty ? "已用完" : "余量不足" : "长按补货";
    }

    public void RenderHoldProgress(double progress)
    {
        _holdProgress = progress;
        RefreshRefillHint();
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
            _refillAvailable = false;
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
        _refillAvailable = canInteract && quantity < capacity && status != IngredientStockStatus.Refilling;
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
        RefreshRefillHint();
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
            if (_refill.GetThemeStylebox(state) is not StyleBoxFlat style) continue;
            style.BgColor = color;
            int border = state == "focus" ? 5 : 3;
            style.BorderWidthLeft = style.BorderWidthTop = style.BorderWidthRight = style.BorderWidthBottom = border;
        }
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
