using Godot;

namespace ProjectCake.UI;

public enum IngredientVisualMode
{
    Single,
    StageScale,
    CountLayout,
    RepresentativeCluster,
    WideSingle,
    WideStock,
    HybridStock,
    LooseStock,
}

public enum WorkstationSlotAttentionState
{
    Normal,
    Actionable,
    Required,
    LowStock,
    Empty,
    Refilling,
}

public readonly record struct StockStackLayout(
    Vector2 MaxSize, float ColumnSpacing, float BackFootY, float FrontFootY,
    Rect2? SilhouetteBounds = null, float RowOffset = 4);

public readonly record struct WorkstationSlotSpec(
    Vector2 MinimumSize,
    Rect2 TrayRect,
    Rect2 IngredientAnchorRect,
    Rect2 LabelRect,
    Rect2 CountRect,
    Rect2 RefillRect,
    Rect2 ClickRect,
    Rect2 StockRect,
    float MaxVisualRatio,
    Rect2? IngredientContainmentRect = null,
    Rect2? CaptionRect = null,
    float TrayVerticalScale = 1f,
    Rect2? StockFootprintRect = null,
    StockStackLayout? StackLayout = null);

/// <summary>
/// Keeps a workstation item visually anchored inside its container while input
/// and stock controls remain independent from the art layout.
/// </summary>
public partial class WorkstationSlotView : Control
{
    private readonly Control _visualLayer;
    private readonly TextureRect _tray;
    private readonly Control _ingredientAnchor;
    private readonly TextureRect _ingredient;
    private readonly List<TextureRect> _ingredientVisuals = new();
    private readonly Label _label;
    private readonly Label _count;
    private readonly Control _clickArea;
    private readonly Control _refillStatus;
    private readonly Control _stockStatus;
    private readonly Panel _attentionFrame;
    private readonly Panel _captionPlate;
    private WorkstationSlotSpec _spec;
    private IngredientVisualMode _visualMode;
    private float _stockFraction = 1f;
    private bool _ingredientAvailable = true;
    private int _quantity;
    private int _capacity;
    private Rect2 _rotatedOpaqueBounds;
    private Bitmap? _ingredientHitMask;
    private Color[] _wideStockTints = Array.Empty<Color>();
    private LiquidStockView? _liquid;
    private WorkstationSlotAttentionState _attentionState;
    private bool _emptyCaptionStyled;
    private Rect2 _stackBounds;
    private (Vector2 Center, Vector2 Size, float Angle)[] _stackLayout = Array.Empty<(Vector2, Vector2, float)>();

    public WorkstationSlotView()
    {
        MouseFilter = MouseFilterEnum.Ignore;

        _visualLayer = new Control { Name = "VisualLayer", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_visualLayer);
        _tray = TextureNode("Tray");
        _visualLayer.AddChild(_tray);

        _ingredientAnchor = new Control
        {
            Name = "IngredientAnchor",
            ClipContents = true,
            MouseFilter = MouseFilterEnum.Ignore,
        };
        _visualLayer.AddChild(_ingredientAnchor);
        _ingredient = TextureNode("Ingredient");
        _ingredientAnchor.AddChild(_ingredient);
        _ingredientVisuals.Add(_ingredient);

        _captionPlate = new Panel { Name = "CaptionPlate", MouseFilter = MouseFilterEnum.Ignore, Visible = false };
        _visualLayer.AddChild(_captionPlate);
        _label = SlotLabel("Label", 18);
        _visualLayer.AddChild(_label);
        _count = SlotLabel("Count", 18);
        _visualLayer.AddChild(_count);

        _attentionFrame = new Panel { Name = "AttentionFrame", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_attentionFrame);
        ApplyAttentionStyle();

        _clickArea = new Control { Name = "ClickArea", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_clickArea);
        _refillStatus = new Control { Name = "RefillStatus", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_refillStatus);
        _stockStatus = new Control { Name = "StockStatus", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_stockStatus);

        Resized += LayoutChildren;
    }

    public Label CountLabel => _count;
    public Control HoverTarget => _ingredientAnchor;
    public Rect2 TrayVisualRect
    {
        get
        {
            Rect2 fitted = FitInside(_tray.Texture?.GetSize() ?? Vector2.Zero, _spec.TrayRect);
            Vector2 size = fitted.Size * new Vector2(1, _spec.TrayVerticalScale);
            return new Rect2(fitted.GetCenter() - size * .5f, size);
        }
    }
    public Rect2 IngredientVisualRect
    {
        get
        {
            Rect2? combined = null;
            foreach (TextureRect visual in _ingredientVisuals.Where(visual => visual.Visible))
            {
                Rect2 rect = _visualMode is IngredientVisualMode.WideSingle or IngredientVisualMode.WideStock
                    ? new Rect2(_spec.IngredientAnchorRect.Position + visual.Position + visual.PivotOffset
                        + _rotatedOpaqueBounds.Position * (visual.Size.X / visual.Texture.GetWidth()),
                        _rotatedOpaqueBounds.Size * (visual.Size.X / visual.Texture.GetWidth()))
                    : IngredientBounds(visual);
                combined = combined is null ? rect : combined.Value.Merge(rect);
            }
            return combined ?? new Rect2(_spec.IngredientAnchorRect.GetCenter(), Vector2.Zero);
        }
    }
    public Rect2 ClickBounds => _spec.ClickRect;
    public int VisibleIngredientVisualCount => _ingredientVisuals.Count(visual => visual.Visible);
    public float IngredientVisualOpacity => _ingredientVisuals.Count == 0 ? 0 : _ingredientVisuals[0].Modulate.A;
    public WorkstationSlotAttentionState AttentionState => _attentionState;
    public int VisibleStockUnits => _visualMode == IngredientVisualMode.HybridStock && !_spec.CaptionRect.HasValue
        ? Math.Min(_quantity, 6) : VisibleIngredientVisualCount;
    public int StockTier => _stockFraction <= 0 ? 0 : _stockFraction <= 0.25f ? 1 : _stockFraction <= 0.6f ? 2 : 3;
    public IReadOnlyList<TextureRect> IngredientVisuals => _ingredientVisuals;
    public int LiquidTier => _liquid?.Tier ?? 0;

    // Transform all four corners, so rotations cannot pass a bounds check by
    // reporting only the unrotated TextureRect's position and size.
    public Rect2 IngredientBounds(TextureRect visual)
    {
        Transform2D transform = visual.GetTransform();
        Vector2 first = transform * Vector2.Zero;
        Rect2 bounds = new(first, Vector2.Zero);
        bounds = bounds.Expand(transform * new Vector2(visual.Size.X, 0));
        bounds = bounds.Expand(transform * visual.Size);
        bounds = bounds.Expand(transform * new Vector2(0, visual.Size.Y));
        return new Rect2(_spec.IngredientAnchorRect.Position + bounds.Position, bounds.Size);
    }

    public void HideNameplate()
    {
        _captionPlate.Hide();
        _label.Hide();
        _count.Hide();
    }

    public void ShowEmptyCaption(bool visible)
    {
        _captionPlate.Hide();
        _count.Hide();
        _label.Visible = visible;
        if (_spec.CaptionRect is Rect2 caption) Place(_label, caption);
        if (!_emptyCaptionStyled)
        {
            TianjinUi.ApplyCounterHint(_label);
            _emptyCaptionStyled = true;
        }
    }

    public void Configure(
        Texture2D trayTexture,
        Texture2D ingredientTexture,
        string label,
        WorkstationSlotSpec spec,
        IngredientVisualMode visualMode = IngredientVisualMode.Single)
    {
        _spec = spec;
        _visualMode = visualMode;
        _stackLayout = Array.Empty<(Vector2, Vector2, float)>();
        CustomMinimumSize = spec.MinimumSize;
        _tray.Texture = trayTexture;
        EnsureIngredientVisuals(visualMode switch
        {
            IngredientVisualMode.CountLayout => 4,
            IngredientVisualMode.RepresentativeCluster => 3,
            IngredientVisualMode.HybridStock => spec.CaptionRect.HasValue ? Math.Max(1, _capacity) : 12,
            IngredientVisualMode.LooseStock => spec.CaptionRect.HasValue ? Math.Max(1, _capacity) : 3,
            IngredientVisualMode.WideStock => 3,
            _ => 1,
        }, ingredientTexture);
        if (visualMode is IngredientVisualMode.WideSingle or IngredientVisualMode.WideStock)
        {
            _rotatedOpaqueBounds = RotatedOpaqueBounds(ingredientTexture, Mathf.DegToRad(32));
            _ingredientHitMask?.Dispose();
            _ingredientHitMask = new Bitmap();
            using Image image = ingredientTexture.GetImage();
            _ingredientHitMask.CreateFromImageAlpha(image, 0.05f);
        }
        _label.Text = label;
        _captionPlate.Visible = spec.CaptionRect.HasValue;
        if (spec.CaptionRect.HasValue)
        {
            _label.AddThemeFontSizeOverride("font_size", 20);
            _label.AddThemeConstantOverride("outline_size", 0);
            _count.AddThemeConstantOverride("outline_size", 0);
            _count.AddThemeColorOverride("font_color", TianjinUi.Brown);
        }
        ApplyAttentionStyle();
        LayoutChildren();
    }

    public void SetStockFraction(double fraction)
    {
        _stockFraction = Mathf.Clamp((float)fraction, 0f, 1f);
        LayoutIngredientVisuals();
    }

    public void SetStock(int quantity, int capacity)
    {
        quantity = Math.Clamp(quantity, 0, Math.Max(0, capacity));
        if (_quantity == quantity && _capacity == capacity) return;
        _quantity = quantity;
        _capacity = capacity;
        if (_visualMode is IngredientVisualMode.HybridStock or IngredientVisualMode.LooseStock && _spec.CaptionRect.HasValue)
            EnsureIngredientVisuals(Math.Max(1, capacity), _ingredient.Texture);
        _stockFraction = capacity > 0 ? (float)quantity / capacity : 0;
        LayoutIngredientVisuals();
        _liquid?.SetTier(StockTier);
    }

    public void ConfigureLiquid(Texture2D emptyBowl, Texture2D fullBowl, bool sauce)
    {
        _tray.Texture = emptyBowl;
        _liquid = new LiquidStockView(fullBowl, sauce) { Name = "LiquidSurface" };
        _visualLayer.AddChild(_liquid);
        _visualLayer.MoveChild(_liquid, 1);
        LayoutChildren();
    }

    public void SetIngredientAvailable(bool available)
    {
        if (_ingredientAvailable == available) return;
        _ingredientAvailable = available;
        LayoutIngredientVisuals();
    }

    public void SetAttention(WorkstationSlotAttentionState state)
    {
        if (_attentionState == state) return;
        _attentionState = state;
        ApplyAttentionStyle();
    }

    public void SetInteraction(Control interaction)
    {
        ClearChildren(_clickArea);
        _clickArea.AddChild(interaction);
        interaction.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        if (interaction is ProjectCake.Interaction.DragItem drag)
            drag.HitTest = point => _visualMode is not (IngredientVisualMode.WideSingle or IngredientVisualMode.WideStock)
                || ContainsVisibleIngredient(interaction.GetGlobalTransform() * point);
        if (interaction is ProjectCake.Interaction.PressRepeatGesture repeat)
            repeat.Contains = point => ContainsVisibleIngredient(interaction.GetGlobalTransform() * point);
    }

    public void SetWideStockTints(IReadOnlyList<Color> tints)
    {
        if (_wideStockTints.SequenceEqual(tints)) return;
        _wideStockTints = tints.Take(3).ToArray();
        LayoutIngredientVisuals();
    }

    private bool ContainsVisibleIngredient(Vector2 globalPoint)
    {
        if (_ingredientHitMask is null || !_ingredientAvailable || !_ingredient.IsVisibleInTree()) return false;
        Vector2 anchorPoint = _ingredientAnchor.GetGlobalTransform().AffineInverse() * globalPoint;
        if (_ingredientAnchor.ClipContents && !new Rect2(Vector2.Zero, _ingredientAnchor.Size).HasPoint(anchorPoint)) return false;

        // Undo the displayed sprite's rotation, pivot and all parent transforms.
        foreach (TextureRect visual in _ingredientVisuals.Where(item => item.IsVisibleInTree()))
        {
            Vector2 localPoint = visual.GetGlobalTransform().AffineInverse() * globalPoint;
            Rect2 drawn = FitInside(visual.Texture.GetSize(), new Rect2(Vector2.Zero, visual.Size));
            if (!drawn.HasPoint(localPoint)) continue;
            Vector2 pixel = (localPoint - drawn.Position) / drawn.Size * (Vector2)_ingredientHitMask.GetSize();
            if (_ingredientHitMask.GetBitv(new Vector2I((int)pixel.X, (int)pixel.Y))) return true;
        }
        return false;
    }

    public void SetRefillControl(Control control)
    {
        ClearChildren(_refillStatus);
        _refillStatus.AddChild(control);
        control.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
    }

    public void SetStockControl(Control control)
    {
        ClearChildren(_stockStatus);
        _stockStatus.AddChild(control);
        control.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
    }

    public bool IngredientIsInsideTray(float safetyMargin = 0)
    {
        if (_spec.StockFootprintRect is Rect2 floor)
        {
            Rect2 silhouetteArea = _spec.StackLayout?.SilhouetteBounds ?? _spec.IngredientAnchorRect;
            foreach (TextureRect visual in _ingredientVisuals.Where(item => item.Visible))
            {
                Rect2 rect = IngredientBounds(visual);
                Vector2 foot = _spec.IngredientAnchorRect.Position
                    + visual.GetTransform() * new Vector2(visual.Size.X * .5f, visual.Size.Y);
                if (!floor.Grow(-safetyMargin).HasPoint(foot) || !silhouetteArea.Encloses(rect)) return false;
            }
            return true;
        }
        // The visible outer tray includes its rim. Some vessels supply a tighter
        // interior rectangle so an item on the front lip cannot pass this check.
        Rect2 safeTray = (_spec.IngredientContainmentRect ?? TrayVisualRect).Grow(-safetyMargin);
        Rect2 item = IngredientVisualRect;
        if (item.Size == Vector2.Zero) return true;
        return item.Position.X >= safeTray.Position.X
            && item.Position.Y >= safeTray.Position.Y
            && item.End.X <= safeTray.End.X
            && item.End.Y <= safeTray.End.Y;
    }

    private void LayoutChildren()
    {
        _visualLayer.Position = Vector2.Zero;
        _visualLayer.Size = Size;
        _tray.StretchMode = TextureRect.StretchModeEnum.Scale;
        Place(_tray, TrayVisualRect);
        if (_liquid is not null) Place(_liquid, TrayVisualRect);
        Place(_ingredientAnchor, _spec.IngredientAnchorRect);
        LayoutIngredientVisuals();
        Place(_label, _spec.LabelRect);
        Place(_count, _spec.CountRect);
        if (_spec.CaptionRect is Rect2 caption) Place(_captionPlate, caption);
        Rect2 attentionRect = new(
            _spec.TrayRect.Position,
            new Vector2(
                Math.Max(_spec.TrayRect.Size.X, _spec.ClickRect.End.X - _spec.TrayRect.Position.X),
                Math.Max(_spec.TrayRect.Size.Y, _spec.ClickRect.End.Y - _spec.TrayRect.Position.Y)));
        Place(_attentionFrame, attentionRect);
        Place(_clickArea, _spec.ClickRect);
        Place(_refillStatus, _spec.RefillRect);
        Place(_stockStatus, _spec.StockRect);
    }

    private void ApplyAttentionStyle()
    {
        // Countertop slots communicate state on their attached nameplate, so a
        // rectangular selection card never encloses the bowl and its controls.
        if (_spec.CaptionRect.HasValue)
        {
            _attentionFrame.Visible = false;
            Color plateColor = _attentionState == WorkstationSlotAttentionState.Required
                ? TianjinUi.Yellow.Lightened(0.42f) : TianjinUi.Cream;
            StyleBoxFlat plate = TianjinUi.Box(plateColor, 10, 2, false);
            plate.BorderColor = _attentionState switch
            {
                WorkstationSlotAttentionState.Empty => TianjinUi.Red,
                WorkstationSlotAttentionState.LowStock => TianjinUi.Orange,
                WorkstationSlotAttentionState.Refilling => TianjinUi.Green,
                _ => TianjinUi.Brown,
            };
            _captionPlate.AddThemeStyleboxOverride("panel", plate);
            return;
        }
        _attentionFrame.Visible = true;
        Color border = _attentionState switch
        {
            WorkstationSlotAttentionState.Actionable => new Color(0.61f, 0.35f, 0.18f, 0.72f),
            WorkstationSlotAttentionState.Required => TianjinUi.Yellow,
            WorkstationSlotAttentionState.LowStock => TianjinUi.Orange,
            WorkstationSlotAttentionState.Empty => TianjinUi.Red,
            WorkstationSlotAttentionState.Refilling => TianjinUi.Green,
            _ => Colors.Transparent,
        };
        int borderWidth = _attentionState switch
        {
            WorkstationSlotAttentionState.Required => 4,
            WorkstationSlotAttentionState.Normal => 0,
            _ => 3,
        };
        Color fill = _attentionState == WorkstationSlotAttentionState.Required
            ? new Color(1f, 0.91f, 0.52f, 0.10f)
            : Colors.Transparent;
        StyleBoxFlat style = TianjinUi.Box(fill, 14, borderWidth, false);
        style.BorderColor = border;
        _attentionFrame.AddThemeStyleboxOverride("panel", style);
    }


    private void EnsureIngredientVisuals(int count, Texture2D texture)
    {
        while (_ingredientVisuals.Count < count)
        {
            TextureRect copy = TextureNode($"Ingredient{_ingredientVisuals.Count + 1}");
            _ingredientAnchor.AddChild(copy);
            _ingredientVisuals.Add(copy);
        }

        for (int index = 0; index < _ingredientVisuals.Count; index++)
        {
            _ingredientVisuals[index].Texture = texture;
            _ingredientVisuals[index].Visible = index < count;
        }
    }

    private void LayoutIngredientVisuals()
    {
        if (_ingredientVisuals.Count == 0)
        {
            return;
        }

        Rect2 localBounds = CenteredScale(new Rect2(Vector2.Zero, _spec.IngredientAnchorRect.Size), _spec.MaxVisualRatio);
        if (_visualMode is IngredientVisualMode.WideSingle or IngredientVisualMode.WideStock)
        {
            bool stock = _visualMode == IngredientVisualMode.WideStock;
            int visible = stock ? Math.Max(StockTier, _wideStockTints.Length) : 1;
            float stackHeight = stock ? 24f : 0f;
            Vector2 sourceSize = _ingredient.Texture.GetSize();
            float wideScale = Math.Min(localBounds.Size.X / _rotatedOpaqueBounds.Size.X,
                (localBounds.Size.Y - stackHeight) / _rotatedOpaqueBounds.Size.Y);
            for (int index = 0; index < _ingredientVisuals.Count; index++)
            {
                TextureRect visual = _ingredientVisuals[index];
                visual.Visible = _ingredientAvailable && index < visible;
                visual.Size = sourceSize * wideScale;
                visual.PivotOffset = visual.Size * 0.5f;
                visual.RotationDegrees = 32;
                visual.Position = localBounds.GetCenter() + new Vector2(0, stock ? 12 - index * 12 : 0)
                    - visual.PivotOffset - _rotatedOpaqueBounds.GetCenter() * wideScale;
                Color qualityTint = _wideStockTints.Length == 0 ? Colors.White
                    : stock ? _wideStockTints[Math.Min(index, _wideStockTints.Length - 1)] : _wideStockTints[^1];
                visual.Modulate = IngredientTint() * qualityTint;
            }
            return;
        }

        if (_visualMode == IngredientVisualMode.HybridStock)
        {
            if (_spec.CaptionRect.HasValue)
            {
                LayoutSeparatedStock(localBounds);
                return;
            }
            int backCount = _quantity > 6 ? (_stockFraction > 0.6f ? 6 : 3) : 0;
            for (int index = 0; index < _ingredientVisuals.Count; index++)
            {
                TextureRect visual = _ingredientVisuals[index];
                bool back = index >= 6;
                int cell = index % 6;
                visual.Visible = back ? cell < backCount : cell < Math.Min(_quantity, 6);
                visual.ZIndex = back ? 0 : 1;
                Vector2 cellSize = localBounds.Size * new Vector2(0.34f, 0.55f);
                Vector2 position = localBounds.Position + localBounds.Size * new Vector2(
                    0.025f + (cell % 3) * 0.29f + (cell / 3) * 0.025f,
                    0.10f + (cell / 3) * 0.23f);
                if (back) position += localBounds.Size * new Vector2(0.025f, -0.07f);
                Place(visual, FitInside(visual.Texture.GetSize(), new Rect2(position, cellSize)));
                visual.Modulate = back ? new Color(0.94f, 0.88f, 0.78f) : Colors.White;
            }
            return;
        }

        if (_visualMode == IngredientVisualMode.LooseStock)
        {
            if (_spec.CaptionRect.HasValue)
            {
                LayoutSeparatedStock(localBounds);
                return;
            }
            for (int index = 0; index < _ingredientVisuals.Count; index++)
            {
                TextureRect visual = _ingredientVisuals[index];
                visual.Visible = index < StockTier;
                Rect2 cell = _spec.CaptionRect.HasValue
                    ? new Rect2(localBounds.Position + new Vector2(index * localBounds.Size.X / 3f + 3, 3),
                        new Vector2(localBounds.Size.X / 3f - 6, localBounds.Size.Y - 6))
                    : new Rect2(localBounds.Position + localBounds.Size * new Vector2(0.05f + index * 0.25f, 0.12f),
                        localBounds.Size * new Vector2(0.4f, 0.76f));
                Place(visual, FitInside(visual.Texture.GetSize(), cell));
                visual.Modulate = Colors.White;
            }
            return;
        }

        if (_visualMode == IngredientVisualMode.RepresentativeCluster)
        {
            for (int index = 0; index < _ingredientVisuals.Count; index++)
            {
                TextureRect visual = _ingredientVisuals[index];
                visual.Visible = index < 3;
                if (!visual.Visible) continue;

                Vector2 cellSize = localBounds.Size * new Vector2(0.54f, 0.75f);
                Vector2 cellPosition = localBounds.Position + new Vector2(
                    index * localBounds.Size.X * 0.23f,
                    index % 2 == 0 ? localBounds.Size.Y * 0.08f : 0);
                Place(visual, FitInside(visual.Texture?.GetSize() ?? Vector2.Zero, new Rect2(cellPosition, cellSize)));
                visual.Modulate = IngredientTint();
            }
            return;
        }

        if (_visualMode == IngredientVisualMode.CountLayout)
        {
            int visible = VisibleUnitCount(_stockFraction);
            for (int index = 0; index < _ingredientVisuals.Count; index++)
            {
                TextureRect visual = _ingredientVisuals[index];
                visual.Visible = index < visible;
                if (!visual.Visible)
                {
                    continue;
                }

                int column = index % 2;
                int row = index / 2;
                Vector2 cellSize = localBounds.Size * new Vector2(0.58f, 0.64f);
                Vector2 cellPosition = localBounds.Position + new Vector2(
                    column * localBounds.Size.X * 0.38f,
                    row * localBounds.Size.Y * 0.32f);
                Place(visual, FitInside(visual.Texture?.GetSize() ?? Vector2.Zero, new Rect2(cellPosition, cellSize)));
                visual.Modulate = IngredientTint();
            }
            return;
        }

        float scale = _visualMode == IngredientVisualMode.StageScale ? StageScale(_stockFraction) : 1f;
        _ingredient.Visible = _visualMode == IngredientVisualMode.Single || _stockFraction > 0;
        Place(_ingredient, FitInside(_ingredient.Texture?.GetSize() ?? Vector2.Zero, CenteredScale(localBounds, scale)));
        _ingredient.Modulate = IngredientTint();
        for (int index = 1; index < _ingredientVisuals.Count; index++)
        {
            _ingredientVisuals[index].Visible = false;
        }
    }

    private void LayoutSeparatedStock(Rect2 bounds)
    {
        // Generate the full capacity once. Stock changes only reveal/hide these
        // positions; neither a refill nor a refresh reshuffles the remaining food.
        int slots = Math.Max(1, _capacity);
        bool layoutChanged = _stackLayout.Length != slots || _stackBounds != bounds;
        if (layoutChanged)
        {
            _stackBounds = bounds;
            _stackLayout = BuildStackedStock(bounds, slots);
        }
        for (int index = 0; index < _ingredientVisuals.Count; index++)
        {
            TextureRect visual = _ingredientVisuals[index];
            visual.Visible = index < _quantity;
            if (!layoutChanged || index >= slots) continue;
            var placement = _stackLayout[index];
            visual.Size = placement.Size;
            visual.PivotOffset = placement.Size * .5f;
            visual.Position = placement.Center - visual.PivotOffset;
            visual.Rotation = placement.Angle;
            visual.ZIndex = 0;
            visual.Modulate = Colors.White;
        }
    }

    private (Vector2 Center, Vector2 Size, float Angle)[] BuildStackedStock(Rect2 bounds, int count)
    {
        int columns = (count + 1) / 2;
        Vector2 source = _ingredient.Texture.GetSize();
        // Same large food size at every equipment level; only the number of
        // positions changes. Back row is painted first, front row overlaps it.
        StockStackLayout layout = _spec.StackLayout ?? new(new Vector2(46, 62), 34, 51, 82);
        Vector2 size = source * Math.Min(layout.MaxSize.X / source.X, layout.MaxSize.Y / source.Y);
        var result = new (Vector2 Center, Vector2 Size, float Angle)[count];
        for (int index = 0; index < count; index++)
        {
            int row = index / columns, column = index % columns;
            float angle = Mathf.DegToRad(new[] { -5f, 2f, -2f, 4f, -3f }[column % 5]);
            float x = 124 + (column - (columns - 1) * .5f) * layout.ColumnSpacing
                + (row == 0 ? layout.RowOffset : -layout.RowOffset);
            float footY = row == 0 ? layout.BackFootY : layout.FrontFootY;
            Vector2 foot = new(x, footY);
            Vector2 center = foot - new Vector2(0, size.Y * .5f).Rotated(angle);
            if (layout.SilhouetteBounds is Rect2 safeArea)
            {
                // Loose scallion leaves must all sit on the floor, unlike an
                // upright egg. Include rotation, then move the whole cluster in.
                float cos = Math.Abs(Mathf.Cos(angle)), sin = Math.Abs(Mathf.Sin(angle));
                Vector2 half = new((size.X * cos + size.Y * sin) * .5f,
                    (size.X * sin + size.Y * cos) * .5f);
                // Leave a subpixel inset so Control transform rounding cannot
                // put a rotated corner across the floor edge.
                safeArea = safeArea.Grow(-.5f);
                center = center.Clamp(safeArea.Position + half, safeArea.End - half);
            }
            result[index] = (center - _spec.IngredientAnchorRect.Position, size, angle);
        }
        return result;
    }
    private static int VisibleUnitCount(float fraction) => fraction switch
    {
        <= 0f => 0,
        <= 0.25f => 1,
        <= 0.50f => 2,
        <= 0.75f => 3,
        _ => 4,
    };

    // Use the rotated opaque silhouette, not the square transparent canvas, to
    // fit a diagonal food sprite. Rotation and uniform scaling preserve its shape.
    private static Rect2 RotatedOpaqueBounds(Texture2D texture, float angle)
    {
        using Image image = texture.GetImage();
        Vector2 center = (Vector2)image.GetSize() * 0.5f;
        Vector2 min = new(float.MaxValue, float.MaxValue), max = new(float.MinValue, float.MinValue);
        for (int y = 0; y < image.GetHeight(); y += 2)
        for (int x = 0; x < image.GetWidth(); x += 2)
        {
            if (image.GetPixel(x, y).A < 0.05f) continue;
            Vector2 point = (new Vector2(x, y) - center).Rotated(angle);
            min = min.Min(point);
            max = max.Max(point);
        }
        return max.X < min.X ? new Rect2(-center, image.GetSize()) : new Rect2(min, max - min).Grow(3);
    }

    private static float StageScale(float fraction) => fraction switch
    {
        <= 0f => 0f,
        <= 0.25f => 0.50f,
        <= 0.50f => 0.68f,
        <= 0.75f => 0.84f,
        _ => 1f,
    };

    private Color IngredientTint()
    {
        float stockAlpha = _visualMode == IngredientVisualMode.StageScale
            ? 0.48f + _stockFraction * 0.52f
            : 1f;
        return new Color(1f, 1f, 1f, _ingredientAvailable ? stockAlpha : 0.45f);
    }

    private static TextureRect TextureNode(string name) => new()
    {
        Name = name,
        ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
        StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
        MouseFilter = MouseFilterEnum.Ignore,
    };

    private static Label SlotLabel(string name, int fontSize)
    {
        Label label = TianjinUi.Label(string.Empty, fontSize, TianjinUi.BrownText, HorizontalAlignment.Center);
        label.Name = name;
        label.VerticalAlignment = VerticalAlignment.Center;
        label.MouseFilter = MouseFilterEnum.Ignore;
        label.AddThemeConstantOverride("outline_size", 3);
        label.AddThemeColorOverride("font_outline_color", new Color(1f, 0.94f, 0.79f, 0.92f));
        return label;
    }

    private static Rect2 CenteredScale(Rect2 rect, float ratio)
    {
        Vector2 size = rect.Size * Mathf.Clamp(ratio, 0, 1);
        return new Rect2(rect.Position + (rect.Size - size) * 0.5f, size);
    }

    private static Rect2 FitInside(Vector2 sourceSize, Rect2 bounds)
    {
        if (sourceSize.X <= 0 || sourceSize.Y <= 0 || bounds.Size.X <= 0 || bounds.Size.Y <= 0)
            return new Rect2(bounds.GetCenter(), Vector2.Zero);
        float scale = Mathf.Min(bounds.Size.X / sourceSize.X, bounds.Size.Y / sourceSize.Y);
        Vector2 size = sourceSize * scale;
        return new Rect2(bounds.Position + (bounds.Size - size) * 0.5f, size);
    }

    private static void Place(Control control, Rect2 rect)
    {
        control.Position = rect.Position;
        control.Size = rect.Size;
    }

    private static void ClearChildren(Node parent)
    {
        foreach (Node child in parent.GetChildren())
        {
            parent.RemoveChild(child);
            child.QueueFree();
        }
    }
}
