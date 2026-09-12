using Godot;

namespace ProjectCake.UI;

/// <summary>Replaceable geometry-only workstation target. Gestures and native drag share the visible bounds.</summary>
public partial class YangzhouSurface : Control
{
    public string Title { get; set; } = "";
    public string Detail { get; set; } = "";
    public string Kind { get; set; } = "";
    public int Amount { get; set; }
    public double Meter { get; set; }
    public bool Active { get; set; }
    public bool InteractionEnabled { get; set; } = true;
    public Func<bool>? CanInteract { get; set; }
    public Func<string>? DragToken { get; set; }
    public Func<string, bool>? AcceptToken { get; set; }
    public Action<string>? Dropped { get; set; }
    public Action? Pressed { get; set; }
    public Action<Vector2, Vector2, double>? Motion { get; set; }
    public Action? Released { get; set; }
    private bool _held;
    private bool _hovered;
    public bool HasGesture => _held;
    private Vector2 _last;
    private ulong _lastTime;
    private Label _title = null!, _detail = null!;
    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        MouseEntered += () => { _hovered = true; QueueRedraw(); };
        MouseExited += () => { _hovered = false; Cancel(); QueueRedraw(); };
    }
    public InteractionHighlightState HighlightState
    {
        get
        {
            if (!InteractionEnabled || CanInteract?.Invoke() != true) return InteractionHighlightState.None;
            if (GetViewport().GuiIsDragging())
            {
                var data = GetViewport().GuiGetDragData();
                bool accepted = data.VariantType == Variant.Type.String && AcceptToken?.Invoke(data.AsString()) == true;
                return accepted ? (_hovered ? InteractionHighlightState.Valid : InteractionHighlightState.Eligible) : InteractionHighlightState.None;
            }
            if (_held || Active) return InteractionHighlightState.Selected;
            return _hovered ? InteractionHighlightState.Hover : InteractionHighlightState.None;
        }
    }
    public void Refresh()
    {
        if (_title is not null)
        {
            _title.Text = Title; _detail.Text = Detail; _detail.Position = new(14, Size.Y - 78); _detail.Size = new(Size.X - 28, 70);
        }
        QueueRedraw();
    }
    public override void _Draw()
    {
        var style = GuangzhouUi.Style(Kind == "board" ? new Color("#E5CCA4") : new Color("#FFF8E8"), 0);
        DrawStyleBox(style, new Rect2(Vector2.Zero, Size));
        var ink = new Color("#57402D"); var center = new Vector2(Size.X / 2, 62 + Math.Max(18, (Size.Y - 156) / 2));
        if (Kind == "board")
        {
            DrawRect(new(center + new Vector2(-80, -28), new Vector2(135, 65)), new Color("#FFEDC1"));
            for (int i = 0; i < (int)(Meter * 19); i++) DrawLine(center + new Vector2(-76 + i * 7, -28), center + new Vector2(-76 + i * 7, 37), ink, 2);
            DrawLine(center + new Vector2(72 - (float)Meter * 140, -38), center + new Vector2(72 - (float)Meter * 140, 48), ink, 6);
        }
        else if (Kind == "scald")
        {
            DrawRect(new(center + new Vector2(-120, 0), new Vector2(240, 45)), new Color("#C0DBD3"));
            Vector2 ladle = center + new Vector2(0, Active ? 22 : -10);
            DrawArc(ladle, 34, 0, Mathf.Pi, 24, ink, 4); DrawLine(ladle + new Vector2(34, 0), ladle + new Vector2(80, -60), ink, 6);
            for (int i = 0; i < Amount; i++) DrawCircle(center + new Vector2(-70 + i * 70, -50), 9, new Color("#347C70"));
        }
        else if (Kind == "steam")
        {
            for (int i = 0; i < Amount; i++) DrawCircle(new Vector2(35 + i * 48, 67), 8, new Color("#C6A369"));
        }
        else if (Kind == "stock")
        {
            if (Size.Y >= 140) for (int i = 0; i < Math.Min(8, Amount); i++) DrawCircle(new Vector2(26 + i * Math.Min(42, (Size.X - 52) / 8), 64), 7, new Color("#7FAD91"));
        }
        if (Meter > 0 && Kind != "scald") DrawRect(new(14, Size.Y - 86, (Size.X - 28) * (float)Math.Clamp(Meter, 0, 1), 5), new Color("#347C70"));
        // These authored geometry devices use the rounded surface itself as their visible body.
        ButtonContourHighlight.DrawContour(this, style, new Rect2(Vector2.Zero, Size), HighlightState);
    }
    public override void _GuiInput(InputEvent input)
    {
        if (CanInteract?.Invoke() != true) { Cancel(); return; }
        if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left } button)
        {
            if (button.Pressed) { _held = true; _last = button.Position; _lastTime = Time.GetTicksUsec(); Pressed?.Invoke(); }
            else Cancel();
        }
        if (input is InputEventMouseMotion motion && _held)
        {
            ulong now = Time.GetTicksUsec(); double delta = Math.Min(.1, (now - _lastTime) / 1_000_000d);
            Motion?.Invoke(motion.Position, motion.Position - _last, delta); _last = motion.Position; _lastTime = now;
        }
    }
    public override void _Input(InputEvent input)
    {
        if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false }) Cancel();
    }
    public void Cancel() { _held = false; Released?.Invoke(); }
    public override Variant _GetDragData(Vector2 atPosition)
    {
        if (CanInteract?.Invoke() != true) return default;
        string token = DragToken?.Invoke() ?? ""; if (token.Length == 0) return default;
        var label = TianjinUi.Label(Title, 24, new Color("#285B4B")); SetDragPreview(label); Cancel(); return token;
    }
    public override bool _CanDropData(Vector2 atPosition, Variant data) => data.VariantType == Variant.Type.String && CanInteract?.Invoke() == true && AcceptToken?.Invoke(data.AsString()) == true;
    public override void _DropData(Vector2 atPosition, Variant data) { if (_CanDropData(atPosition, data)) Dropped?.Invoke(data.AsString()); }
}
