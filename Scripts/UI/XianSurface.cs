using Godot;

namespace ProjectCake.UI;

/// <summary>Replaceable vector placeholder with the same hit target for gestures and native drag/drop.</summary>
public partial class XianSurface : Control
{
    public string Kind { get; set; } = "";
    public bool ArtworkMode { get; set; }
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
    private bool _artworkStyled;
    private readonly StyleBoxFlat _meatBadge = new() { BgColor = new Color("#fff1d9ee"), CornerRadiusTopLeft = 9,
        CornerRadiusTopRight = 9, CornerRadiusBottomLeft = 9, CornerRadiusBottomRight = 9 };
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
        if (ArtworkMode) { RefreshArtwork(); return; }
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
        if (ArtworkMode && Kind != "customer") { DrawArtwork(); return; }
        var panel = new StyleBoxFlat
        {
            BgColor = ArtworkMode && Kind == "customer" ? new Color(1, .956f, .863f, Amount == 0 ? .45f : .92f)
                : Kind == "board" ? new Color("#D6B27E") : new Color("#FFF4DC"), BorderColor = Selected ? Accent : new Color("#A99277"),
            BorderWidthLeft = Selected ? 5 : 3, BorderWidthRight = Selected ? 5 : 3, BorderWidthTop = Selected ? 5 : 3, BorderWidthBottom = Selected ? 5 : 3,
            CornerRadiusTopLeft = 22, CornerRadiusTopRight = 22, CornerRadiusBottomLeft = 22, CornerRadiusBottomRight = 22,
        };
        DrawStyleBox(panel, new Rect2(Vector2.Zero, Size));
        if (Kind == "customer")
        {
            if (Amount == 0) return;
            if (ArtworkMode)
            {
                Vector2 face = new(42, 120);
                DrawCircle(face, 26, new Color("#eac28b"));
                DrawCircle(face + new Vector2(-9, -6), 3, Ink); DrawCircle(face + new Vector2(9, -6), 3, Ink);
                float mood = Meter < .3 ? 7 : Meter < .6 ? 0 : -7;
                DrawPolyline(new[] { face + new Vector2(-11, 7), face + new Vector2(0, 7 + mood), face + new Vector2(11, 7) }, Ink, 3, true);
            }
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
    private void RefreshArtwork()
    {
        _title.Text = Title; _detail.Text = Detail;
        _title.MouseFilter = _detail.MouseFilter = MouseFilterEnum.Ignore;
        _title.Position = new(8, 4); _title.Size = new(Size.X - 16, 30);
        _detail.Position = new(8, Kind == "customer" ? 52 : Kind == "meat" ? 32 : Size.Y - 66);
        _detail.Size = new(Size.X - 16, Kind == "customer" ? Size.Y - 95 : 64);
        if (Kind == "customer" && Amount > 0) { _detail.Position = new(76, 52); _detail.Size = new(Size.X - 88, Size.Y - 95); }
        _detail.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _title.ClipText = true;
        if (!_artworkStyled)
        {
            _title.AddThemeFontSizeOverride("font_size", Kind == "customer" ? 23 : 22);
            _detail.AddThemeFontSizeOverride("font_size", 21);
            foreach (var label in new[] { _title, _detail })
            {
                label.AddThemeColorOverride("font_color", new Color("#422919"));
                label.AddThemeColorOverride("font_outline_color", new Color("#fff1d9"));
                label.AddThemeConstantOverride("outline_size", 5);
            }
            _artworkStyled = true;
        }
        // Keep the assembly plate clear: detailed recipe state appears above it.
        if (Kind == "bun") { _title.Position = new(0, -30); _detail.Position = new(-20, 105); _detail.Size = new(Size.X + 40, 65); }
        Modulate = Colors.White; QueueRedraw();
    }

    private void DrawArtwork()
    {
        Vector2 center = new(Size.X / 2, Size.Y * .40f);
        if (Kind == "meat")
        {
            DrawStyleBox(_meatBadge, new Rect2(Vector2.Zero, Size));
        }
        else if (Kind == "bun" && Stage > 0)
        {
            DrawCircle(center, 55, Ink); DrawCircle(center, 51, FoodColor);
            if (Stage >= 2)
            {
                DrawLine(center + new Vector2(-45, 0), center + new Vector2(45, 0), Ink, 8);
                for (int i = 0; i < Amount * 5; i++) DrawCircle(center + new Vector2(-32 + i % 5 * 16, i / 5 * 12), 10, new Color("#93553a"));
            }
            if (Stage == 3) DrawRect(new Rect2(center + new Vector2(-51, 15), new Vector2(102, 34)), new Color("#fff9e9"));
        }
        else if (Kind == "oven")
        {
            for (int i = 0; i < Amount; i++)
            {
                Vector2 p = new(100 + i % 3 * 150, 68 + i / 3 * 52);
                DrawCircle(p, 25, Ink); DrawCircle(p, 22, FoodColor);
            }
        }
        else if (Kind == "board" && Amount > 0)
        {
            for (int i = 0; i < 6; i++) DrawCircle(center + new Vector2(-45 + i % 3 * 35, i / 3 * 20), 16, new Color("#93553a"));
            float offset = (float)Math.Sin(Meter * Math.PI * 12) * 28;
            DrawRect(new Rect2(center + new Vector2(offset, -30), new Vector2(75, 24)), new Color("#e0dcd4"));
            DrawLine(center + new Vector2(offset + 75, -18), center + new Vector2(offset + 105, -18), Ink, 11);
            DrawRect(new Rect2(25, Size.Y - 78, (Size.X - 50) * (float)Meter, 7), Accent);
        }
        else if (Kind == "soup_bowl" && Amount > 0)
        {
            DrawCircle(center, 48, Ink); DrawCircle(center, 43, new Color("#fff9e9"));
            DrawCircle(center, 36, new Color("#9d5940"));
            for (int i = 0; i < 4; i++) DrawCircle(center + new Vector2(-16 + i % 2 * 29, -13 + i / 2 * 25), 8, new Color("#cbb181"));
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
