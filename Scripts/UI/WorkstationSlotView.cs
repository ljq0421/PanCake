using Godot;

namespace ProjectCake.UI;

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
    private readonly Label _label;
    private readonly Label _count;
    private readonly Control _clickArea;
    private readonly Control _refillStatus;
    private readonly Control _stockStatus;
    private WorkstationSlotSpec _spec;

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

        _label = SlotLabel("Label", 16);
        _visualLayer.AddChild(_label);
        _count = SlotLabel("Count", 15);
        _visualLayer.AddChild(_count);

        _clickArea = new Control { Name = "ClickArea", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_clickArea);
        _refillStatus = new Control { Name = "RefillStatus", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_refillStatus);
        _stockStatus = new Control { Name = "StockStatus", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_stockStatus);

        Resized += LayoutChildren;
    }

    public Label CountLabel => _count;
    public TextureRect HoverTarget => _ingredient;
    public Rect2 TrayVisualRect => FitInside(_tray.Texture?.GetSize() ?? Vector2.Zero, _spec.TrayRect);
    public Rect2 IngredientVisualRect
    {
        get
        {
            Rect2 bounds = CenteredScale(_spec.IngredientAnchorRect, _spec.MaxVisualRatio);
            return FitInside(_ingredient.Texture?.GetSize() ?? Vector2.Zero, bounds);
        }
    }
    public Rect2 ClickBounds => _spec.ClickRect;

    public void Configure(Texture2D trayTexture, Texture2D ingredientTexture, string label, WorkstationSlotSpec spec)
    {
        _spec = spec;
        CustomMinimumSize = spec.MinimumSize;
        _tray.Texture = trayTexture;
        _ingredient.Texture = ingredientTexture;
        _label.Text = label;
        LayoutChildren();
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
        Rect2 ingredientBounds = CenteredScale(new Rect2(Vector2.Zero, _spec.IngredientAnchorRect.Size), _spec.MaxVisualRatio);
        Place(_ingredient, ingredientBounds);
        Place(_label, _spec.LabelRect);
        Place(_count, _spec.CountRect);
        Place(_clickArea, _spec.ClickRect);
        Place(_refillStatus, _spec.RefillRect);
        Place(_stockStatus, _spec.StockRect);
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
