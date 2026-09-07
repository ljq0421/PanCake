using Godot;

namespace ProjectCake.UI;

public enum IngredientVisualMode
{
    Single,
    StageScale,
    CountLayout,
    RepresentativeCluster,
    WideSingle,
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

public readonly record struct WorkstationSlotSpec(
    Vector2 MinimumSize,
    Rect2 TrayRect,
    Rect2 IngredientAnchorRect,
    Rect2 LabelRect,
    Rect2 CountRect,
    Rect2 RefillRect,
    Rect2 ClickRect,
    Rect2 StockRect,
    float MaxVisualRatio);

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
    private WorkstationSlotSpec _spec;
    private IngredientVisualMode _visualMode;
    private float _stockFraction = 1f;
    private bool _ingredientAvailable = true;
    private WorkstationSlotAttentionState _attentionState;

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
    public Rect2 TrayVisualRect => FitInside(_tray.Texture?.GetSize() ?? Vector2.Zero, _spec.TrayRect);
    public Rect2 IngredientVisualRect
    {
        get
        {
            Rect2? combined = null;
            foreach (TextureRect visual in _ingredientVisuals.Where(visual => visual.Visible))
            {
                Rect2 rect = new(_spec.IngredientAnchorRect.Position + visual.Position, visual.Size);
                combined = combined is null ? rect : combined.Value.Merge(rect);
            }
            return combined ?? new Rect2(_spec.IngredientAnchorRect.GetCenter(), Vector2.Zero);
        }
    }
    public Rect2 ClickBounds => _spec.ClickRect;
    public int VisibleIngredientVisualCount => _ingredientVisuals.Count(visual => visual.Visible);
    public float IngredientVisualOpacity => _ingredientVisuals.Count == 0 ? 0 : _ingredientVisuals[0].Modulate.A;
    public WorkstationSlotAttentionState AttentionState => _attentionState;

    public void Configure(
        Texture2D trayTexture,
        Texture2D ingredientTexture,
        string label,
        WorkstationSlotSpec spec,
        IngredientVisualMode visualMode = IngredientVisualMode.Single)
    {
        _spec = spec;
        _visualMode = visualMode;
        CustomMinimumSize = spec.MinimumSize;
        _tray.Texture = trayTexture;
        EnsureIngredientVisuals(visualMode switch
        {
            IngredientVisualMode.CountLayout => 4,
            IngredientVisualMode.RepresentativeCluster => 3,
            _ => 1,
        }, ingredientTexture);
        _label.Text = label;
        LayoutChildren();
    }

    public void SetStockFraction(double fraction)
    {
        _stockFraction = Mathf.Clamp((float)fraction, 0f, 1f);
        LayoutIngredientVisuals();
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
        Rect2 safeTray = TrayVisualRect.Grow(-safetyMargin);
        Rect2 item = IngredientVisualRect;
        return item.Position.X >= safeTray.Position.X
            && item.Position.Y >= safeTray.Position.Y
            && item.End.X <= safeTray.End.X
            && item.End.Y <= safeTray.End.Y;
    }

    private void LayoutChildren()
    {
        _visualLayer.Position = Vector2.Zero;
        _visualLayer.Size = Size;
        Place(_tray, _spec.TrayRect);
        Place(_ingredientAnchor, _spec.IngredientAnchorRect);
        LayoutIngredientVisuals();
        Place(_label, _spec.LabelRect);
        Place(_count, _spec.CountRect);
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
        if (_visualMode == IngredientVisualMode.WideSingle)
        {
            _ingredient.Visible = _ingredientAvailable;
            _ingredient.StretchMode = TextureRect.StretchModeEnum.Scale;
            Place(_ingredient, localBounds);
            _ingredient.Modulate = IngredientTint();
            for (int index = 1; index < _ingredientVisuals.Count; index++)
            {
                _ingredientVisuals[index].Visible = false;
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

    private static int VisibleUnitCount(float fraction) => fraction switch
    {
        <= 0f => 0,
        <= 0.25f => 1,
        <= 0.50f => 2,
        <= 0.75f => 3,
        _ => 4,
    };

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
