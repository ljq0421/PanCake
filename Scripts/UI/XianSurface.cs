using Godot;

namespace ProjectCake.UI;

/// <summary>Replaceable vector placeholder with the same hit target for gestures and native drag/drop.</summary>
public partial class XianSurface : Control
{
    [Export] public string Kind { get; set; } = "";
    [Export] public bool ArtworkMode { get; set; }
    public string Title { get; set; } = "";
    public string Detail { get; set; } = "";
    public int Amount { get; set; }
    public int Stage { get; set; }
    public bool HasJuice { get; set; }
    public int Heat { get; set; }
    private readonly XianArtCatalog _art = new();
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
    public bool HasGesture => _held;
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
        if (Kind == "customer") return;
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
        _title.Visible = _detail.Visible = Kind != "customer";
        _title.Text = Title;
        _detail.Text = Detail;
        Modulate = Colors.White;
        QueueRedraw();
    }

    private void Food(string name, Rect2 rect, Color? tint = null)
    {
        Texture2D texture = _art.Texture(name);
        Vector2 size = texture.GetSize();
        float scale = Math.Min(rect.Size.X / size.X, rect.Size.Y / size.Y);
        Vector2 fitted = size * scale;
        DrawTextureRect(texture, new Rect2(rect.Position + (rect.Size - fitted) / 2, fitted), false, tint ?? Colors.White);
    }

    private void DrawArtwork()
    {
        if (Kind == "bun" && Stage > 0)
        {
            Color tint = Heat > 0 ? new Color("#bb8c62") : Colors.White;
            Food(Stage == 1 ? "完整熟白吉馍" : "切开白吉馍状态层", new Rect2(38, 0, 240, 140), tint);
            // Each trimmed layer is calibrated to the opening, rather than stretching its source canvas.
            if (Stage >= 2 && Amount > 0) Food("标准肉量覆盖层-v2", new Rect2(68, 76, 180, 42));
            if (Stage >= 2 && Amount > 1) Food("多肉追加覆盖层", new Rect2(67, 62, 182, 37));
            if (HasJuice) Food("腊汁覆盖层", new Rect2(80, 85, 156, 23));
            if (Stage == 3)
            {
                // Show only the front lower section of the bag; the bun and toppings remain visible.
                var paper = _art.Texture("肉夹馍包装纸");
                Vector2 size = paper.GetSize();
                DrawTextureRectRegion(paper, new Rect2(36, 112, 244, 24),
                    new Rect2(0, size.Y * .55f, size.X, size.Y * .45f));
            }
        }
        else if (Kind == "oven")
        {
            for (int i = 0; i < Amount; i++)
            {
                Rect2 rect = new(75 + i % 3 * 150, 47 + i / 3 * 58, 100, 61);
                Food(Stage <= 1 ? "生白吉馍坯" : "熟白吉馍", rect, Heat == 2 ? new Color("#49362e") : Colors.White);
                if (Heat > 0) Food("白吉馍偏焦覆盖层", rect, Heat == 2 ? new Color("#49362e") : Colors.White);
            }
        }
        else if (Kind == "board" && Amount > 0)
        {
            Food(Meter < .34 ? "剁肉状态01 整块肉" : Meter < .7 ? "剁肉状态02 粗剁状态" : "剁肉状态03 完成剁肉", new Rect2(160, 24, 165, 108));
            float offset = (float)Math.Sin(Meter * Math.PI * 12) * 24;
            Food("剁肉菜刀", new Rect2(260 + offset, 3, 135, 90));
            DrawRect(new Rect2(145, 139, 240, 7), new Color("#49362e55"));
            DrawRect(new Rect2(145, 139, 240 * (float)Meter, 7), Accent);
        }
        else if (Kind == "meat")
        {
            Food("预剁肉备货盘", new Rect2(5, 0, 118, 65));
            if (Amount > 0) Food("剁肉状态03 完成剁肉", new Rect2(27, 6, 75, 40));
        }
        else if (Kind == "soup_bowl")
            Food(Amount > 0 ? "成品肉丸胡辣汤" : "胡辣汤空碗", new Rect2(66, 15, 190, 145));
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
