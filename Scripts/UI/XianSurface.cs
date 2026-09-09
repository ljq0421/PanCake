using Godot;

namespace ProjectCake.UI;

/// <summary>Replaceable vector placeholder with the same hit target for gestures and native drag/drop.</summary>
public partial class XianSurface : Control
{
    public string Kind { get; set; } = "";
    public string Title { get; set; } = "";
    public string Detail { get; set; } = "";
    public int Amount { get; set; }
    public int Stage { get; set; }
    public double Meter { get; set; }
    public bool Selected { get; set; }
    public bool Unavailable { get; set; }
    public Color FoodColor { get; set; } = new("#E9B963");
    public Func<bool>? CanInteract { get; set; }
    public Func<string>? DragToken { get; set; }
    public Func<string, bool>? AcceptToken { get; set; }
    public Action<string>? Dropped { get; set; }
    public Action? Pressed { get; set; }
    public Action<double>? HorizontalStroke { get; set; }
    public Action? GestureEnded { get; set; }
    private bool _held;
    private Vector2 _previous;
    private Label _title = null!, _detail = null!;
    private static readonly Color Ink = new("#513D32"), Accent = new("#873F38");

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        MouseExited += CancelGesture;
    }
    public void Refresh()
    {
        if (_title is null) return;
        _title.Text = Title; _title.Position = new Vector2(10, 12); _title.Size = new Vector2(Size.X - 20, 36);
        _detail.Text = Detail;
        _detail.Position = new Vector2(12, Kind == "customer" ? 62 : Math.Max(80, Size.Y - 100));
        _detail.Size = new Vector2(Size.X - 24, Kind == "customer" ? Size.Y - 100 : 92);
        if (Kind == "juice") { _detail.Position = new Vector2(80, 49); _detail.Size = new Vector2(Size.X - 92, Size.Y - 59); }
        Modulate = Unavailable ? new Color(.8f, .8f, .8f) : Colors.White;
        QueueRedraw();
    }
    public override void _Draw()
    {
        var panel = new StyleBoxFlat
        {
            BgColor = Kind == "board" ? new Color("#D6B27E") : new Color("#FFF4DC"), BorderColor = Selected ? Accent : new Color("#A99277"),
            BorderWidthLeft = Selected ? 5 : 3, BorderWidthRight = Selected ? 5 : 3, BorderWidthTop = Selected ? 5 : 3, BorderWidthBottom = Selected ? 5 : 3,
            CornerRadiusTopLeft = 22, CornerRadiusTopRight = 22, CornerRadiusBottomLeft = 22, CornerRadiusBottomRight = 22,
        };
        DrawStyleBox(panel, new Rect2(Vector2.Zero, Size));
        if (Kind == "customer")
        {
            if (Amount == 0) return;
            DrawRect(new Rect2(18, Size.Y - 28, Size.X - 36, 10), new Color("#D9CEB9"));
            DrawRect(new Rect2(18, Size.Y - 28, (Size.X - 36) * (float)Math.Clamp(1 - Meter, 0, 1), 10), Meter > .6 ? Accent : new Color("#728658"));
            return;
        }
        Vector2 center = new(Size.X / 2, 58 + Math.Max(25, (Size.Y - 172) / 2));
        if (Kind == "bun")
        {
            if (Stage > 0)
            {
                DrawCircle(center, 66, Ink); DrawCircle(center, 61, FoodColor);
                if (Stage >= 2)
                {
                    DrawLine(center + new Vector2(-55, 5), center + new Vector2(55, 5), Ink, 10);
                    for (int i = 0; i < Amount * 5; i++) DrawCircle(center + new Vector2(-42 + i % 5 * 21, i / 5 * 12), 12, new Color("#8E5135"));
                }
                if (Stage == 3) DrawRect(new Rect2(center + new Vector2(-64, 20), new Vector2(128, 46)), new Color("#FFFCF0"));
            }
        }
        else if (Kind == "oven")
        {
            DrawRect(new Rect2(center + new Vector2(-Size.X * .41f, -50), new Vector2(Size.X * .82f, 106)), new Color("#68635C"));
            for (int i = 0; i < Amount; i++) DrawCircle(center + new Vector2(-70 + i % 3 * 70, -22 + i / 3 * 46), 23, FoodColor);
        }
        else if (Kind == "board" || Kind == "meat")
        {
            if (Kind == "meat") center = new Vector2(Size.X / 2, 74);
            for (int i = 0; i < Math.Min(6, Amount); i++)
                DrawCircle(center + new Vector2(-42 + i % 3 * 40, -5 + i / 3 * 24), Kind == "meat" ? 14 : 18, new Color("#93553A"));
            if (Kind == "board")
            {
                float offset = (float)Math.Sin(Meter * Math.PI * 12) * 22;
                DrawRect(new Rect2(center + new Vector2(5 + offset, -45), new Vector2(70, 26)), new Color("#DDD6C7"));
                DrawLine(center + new Vector2(75 + offset, -32), center + new Vector2(102 + offset, -32), Ink, 12);
                DrawRect(new Rect2(28, Size.Y - 113, (Size.X - 56) * (float)Meter, 8), Accent);
            }
        }
        else if (Kind == "soup" || Kind == "juice")
        {
            if (Kind == "juice") center = new Vector2(40, 87);
            float radius = Kind == "juice" ? 23 : 48;
            DrawCircle(center, radius + 5, Ink); DrawCircle(center, radius, new Color("#9D5940"));
            if (Kind == "soup") for (int i = 0; i < 4; i++) DrawCircle(center + new Vector2(-20 + i % 2 * 36, -16 + i / 2 * 27), 9, new Color("#CBB181"));
        }
    }
    public override void _GuiInput(InputEvent input)
    {
        if (CanInteract?.Invoke() != true) { CancelGesture(); return; }
        if (input is InputEventMouseButton b && b.ButtonIndex == MouseButton.Left)
        {
            if (b.Pressed) { _held = true; _previous = b.Position; Pressed?.Invoke(); }
            else CancelGesture();
        }
        if (input is InputEventMouseMotion m && _held)
        {
            if (!new Rect2(Vector2.Zero, Size).HasPoint(m.Position)) { CancelGesture(); return; }
            HorizontalStroke?.Invoke(m.Position.X - _previous.X); _previous = m.Position;
        }
    }
    public override void _Input(InputEvent input)
    {
        if (input is InputEventMouseButton b && b.ButtonIndex == MouseButton.Left && !b.Pressed) CancelGesture();
    }
    public void CancelGesture() { _held = false; GestureEnded?.Invoke(); }
    public override Variant _GetDragData(Vector2 atPosition)
    {
        if (CanInteract?.Invoke() != true) return default;
        string token = DragToken?.Invoke() ?? "";
        if (token.Length == 0) return default;
        var preview = TianjinUi.Label(token == "meat" ? "腊汁肉 · 1份" : token == "soup" ? "胡辣汤" : token == "juice" ? "腊汁" : "肉夹馍", 26, Ink);
        SetDragPreview(preview); CancelGesture(); return token;
    }
    public override bool _CanDropData(Vector2 atPosition, Variant data) => data.VariantType == Variant.Type.String && CanInteract?.Invoke() == true && AcceptToken?.Invoke(data.AsString()) == true;
    public override void _DropData(Vector2 atPosition, Variant data) { if (_CanDropData(atPosition, data)) Dropped?.Invoke(data.AsString()); }
}
