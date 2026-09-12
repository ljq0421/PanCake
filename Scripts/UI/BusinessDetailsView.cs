using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Customers;

namespace ProjectCake.UI;

/// <summary>Shared two-page ledger. It presents immutable snapshots and emits navigation requests only.</summary>
public partial class BusinessDetailsView : Control
{
    public event Action? CloseRequested;
    public event Action? RetryRequested;
    private Control _canvas = null!, _book = null!, _summary = null!, _details = null!, _metrics = null!, _note = null!, _stamp = null!;
    private Label _city = null!, _title = null!, _income = null!, _save = null!;
    private VBoxContainer _rows = null!;
    private ScrollContainer _scroll = null!;
    private Button _summaryTab = null!, _detailTab = null!, _retry = null!;
    private readonly List<Button> _filters = new();
    private BusinessBookModel _model = new();
    private BookFilter _filter;
    private Tween? _entrance;
    private PancakeAudio _audio = null!;
    private TianjinArtCatalog? _art;
    internal Button CloseButton { get; private set; } = null!;
    internal BusinessBookModel Model => _model;
    internal bool DetailVisible => _details.Visible;
    private Color Ink => UsesBookArt ? CitySettlementTheme.Ink : new("#4A3024");
    private Color Muted => UsesBookArt ? CitySettlementTheme.Muted : new("#775343");
    private Color Accent => _model.CityId switch { "wuhan" => new("#527C69"), "xian" => new("#995448"), "guangzhou" => new("#637D53"), "yangzhou" => new("#537C80"), _ => new("#AB692F") };

    public override void _Ready()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); ZIndex = 200;
        Theme = TianjinUi.CreateTheme(); MouseFilter = MouseFilterEnum.Stop;
        var shade = new ColorRect { Color = new Color(.12f, .08f, .04f, .4f), MouseFilter = MouseFilterEnum.Stop };
        AddChild(shade); shade.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        _canvas = new Control { Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Ignore }; AddChild(_canvas);
        void Fit() { float s = Math.Min(Size.X / 1920, Size.Y / 1080); _canvas.Scale = Vector2.One * s; _canvas.Position = (Size - new Vector2(1920, 1080) * s) / 2; }
        Resized += Fit; Fit();
        _book = new Control { Position = new(120, 90), Size = new(1680, 900), MouseFilter = MouseFilterEnum.Stop }; _canvas.AddChild(_book);
        _plainPaper = new Control { MouseFilter = MouseFilterEnum.Ignore }; _book.AddChild(_plainPaper);
        Panel(_plainPaper, new(0, 0, 1680, 900), new("#B88045"), 24, 3);
        Panel(_plainPaper, new(10, 7, 1660, 878), new("#FFF8E8"), 20, 1);
        Line(_plainPaper, new(840, 24, 2, 826), new Color(.47f, .32f, .20f, .18f));
        Line(_plainPaper, new(828, 24, 1, 826), new Color(.47f, .32f, .20f, .08f));
        _illustratedPaper = new Control { MouseFilter = MouseFilterEnum.Ignore }; _book.AddChild(_illustratedPaper);
        _city = Text(_book, "", new(80, 32, 600, 38), 26, Muted);
        _title = Text(_book, "", new(80, 78, 1000, 62), 46);
        _summaryTab = ButtonAt(_book, "今日小结", new(1220, -18, 170, 64), () => SelectPage(false));
        _detailTab = ButtonAt(_book, "顾客明细", new(1400, -18, 170, 64), () => SelectPage(true));
        _summary = new Control { Position = new(0, 155), Size = new(1680, 620), MouseFilter = MouseFilterEnum.Ignore }; _book.AddChild(_summary);
        _details = new Control { Position = new(0, 155), Size = new(1680, 620) }; _book.AddChild(_details);
        Text(_details, "今日客单", new(80, 0, 380, 44), 28);
        string[] names = { "全部", "完成", "错误", "流失" };
        for (int i = 0; i < names.Length; i++) { int index = i; _filters.Add(ButtonAt(_details, names[i], new(900 + i * 160, 0, 148, 48), () => SelectFilter((BookFilter)index))); }
        _scroll = new ScrollContainer { Position = new(78, 66), Size = new(1524, 568), HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled, Name = "OrderScroll" }; _details.AddChild(_scroll);
        _rows = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; _rows.AddThemeConstantOverride("separation", 12); _scroll.AddChild(_rows);
        _save = Text(_book, "", new(80, 792, 1120, 65), 20, Muted, wrap: true);
        CloseButton = ButtonAt(_book, "收好账本", new(1320, 798, 240, 72), RequestClose); CloseButton.Name = "CloseBusinessDetails";
        _retry = ButtonAt(_book, "重试保存", new(1100, 809, 190, 58), () => RetryRequested?.Invoke());
        _escapeHint = Text(_book, "Esc 返回", new(1340, 870, 220, 28), 18, Muted, HorizontalAlignment.Right);
        var info = ButtonAt(_book, "统计说明", new(80, 842, 130, 48), () => { });
        _infoButton = info;
        info.AddThemeStyleboxOverride("normal", new StyleBoxEmpty());
        info.AddThemeStyleboxOverride("hover", new StyleBoxEmpty());
        info.AddThemeStyleboxOverride("pressed", new StyleBoxEmpty());
        info.AddThemeStyleboxOverride("focus", TianjinUi.Box(new Color("#F4E6BC"), 5, 1, false));
        info.AddThemeFontSizeOverride("font_size", 18);
        info.TooltipText = "完成率 = 完成 ÷（完成 + 流失）；流失不计入完成顾客满意度。";
        var explanation = Text(_book, "完成率按已结束客单计算，错误完成也计入完成；流失不参与满意度。", new(230, 850, 990, 32), 18, Muted);
        _explanation = explanation;
        explanation.Hide(); info.Pressed += () => explanation.Visible = !explanation.Visible;
        _audio = new PancakeAudio(); AddChild(_audio);
        VisibilityChanged += () => { if (!Visible) { FinishAnimation(); _audio.Stop(); } };
        Hide();
    }
    internal void Open(DayResult result, IReadOnlyList<BusinessOrderRecord> records, DataCatalog catalog) =>
        Open(BusinessBookModel.From("tianjin", result, records, catalog));
    public void Open(BusinessBookModel model)
    {
        FinishAnimation(); _model = model; _filter = BookFilter.All;
        ApplyBookSkin();
        _city.Text = $"{model.CityName} · DAY {model.Result.Day:00}" + (model.Practice ? "  /  练习营业" : "");
        _title.Text = model.Closing ? "今日收摊" : "营业账本";
        _save.Text = model.SaveMessage.Length > 0 ? model.SaveMessage : "截至目前 · 收好账本后继续营业";
        _retry.Visible = model.CanRetry; CloseButton.Disabled = !model.CanClose;
        BuildSummary(); RefreshRows(); SelectPage(false); Show();
        (model.CanClose ? CloseButton : _retry).GrabFocus(); StartAnimation();
    }
    private void BuildSummary()
    {
        Clear(_summary);
        if (UsesBookArt) { BuildArtSummary(); return; }
        var r = _model.Result;
        Text(_summary, "今日收入", new(95, 5, 650, 42), 30);
        _income = Text(_summary, $"¥{r.TotalRevenue}", new(95, 51, 650, 125), 84);
        Text(_summary, "菜品销售", new(100, 210, 390, 40), 26, Muted);
        Text(_summary, $"¥{r.SaleRevenue}", new(500, 210, 230, 40), 28, Ink, HorizontalAlignment.Right);
        Text(_summary, "顾客小费", new(100, 264, 390, 40), 26, Muted);
        Text(_summary, $"+¥{r.Tips}", new(500, 264, 230, 40), 28, Ink, HorizontalAlignment.Right);
        Line(_summary, new(100, 321, 630, 1), new Color(.47f, .32f, .20f, .2f));
        _art ??= new TianjinArtCatalog();
        for (int i = 0; i < 3; i++) Picture(_summary, _art.Coin, new(565 + i * 43, 105 - i * 9, 60, 60));
        Text(_summary, "今日最受欢迎", new(100, 380, 650, 40), 28, Accent);
        if (_model.BestSeller is { } best)
        {
            var icon = new BookFoodIcon { Product = best }; Place(_summary, icon, new(95, 446, 108, 108));
            var name = Text(_summary, best.Name, new(225, 448, 510, 54), 30, wrap: true);
            Text(_summary, $"今日卖出 ×{best.Quantity}", new(225, 511, 510, 42), 24, Muted);
        }
        else Text(_summary, "还没有完成的客单", new(100, 448, 630, 64), 25, Muted);
        _metrics = new Control { MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_metrics);
        Text(_metrics, "今日接待" + (_model.Closing ? "" : " · 已结束"), new(925, 5, 650, 42), 28, Accent);
        Text(_metrics, $"{_model.Resolved} { _model.Unit}", new(925, 55, 240, 64), 48);
        Text(_metrics, $"完成  {r.CompletedCustomers}", new(925, 140, 280, 48), 32, new("#456E49"));
        Text(_metrics, $"流失  {r.LostCustomers}", new(1260, 140, 300, 48), 32, new("#92534B"));
        Text(_metrics, "完成率  " + Percent(_model.CompletionRate), new(925, 205, 630, 42), 26, Muted);
        Line(_metrics, new(925, 267, 630, 1), new Color(.47f, .32f, .20f, .2f));
        Text(_metrics, "完成顾客满意度", new(925, 298, 360, 40), 26, Muted);
        Text(_metrics, Percent(_model.Satisfaction), new(925, 343, 330, 75), 48);
        _stamp = new Control { Position = new(1320, 292), Size = new(235, 132), PivotOffset = new(117, 66), MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_stamp);
        if (r.PerfectOrders > 0)
        {
            Panel(_stamp, new(0, 0, 235, 125), new("#FBE8B8"), 32, 2);
            Text(_stamp, $"PERFECT ×{r.PerfectOrders}", new(5, 12, 225, 44), 26, new("#8B5926"), HorizontalAlignment.Center);
            Text(_stamp, "完美出餐", new(5, 63, 225, 38), 24, new("#8B5926"), HorizontalAlignment.Center);
        }
        else Text(_stamp, "今天还没有\n完美出餐", new(0, 12, 230, 94), 24, Muted, HorizontalAlignment.Center);
        _note = new Control { Position = new(920, 451), Size = new(655, 143), MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_note);
        Panel(_note, new(0, 0, 655, 143), new("#F4E6BC"), 3, 0);
        Text(_note, "今日手记", new(22, 10, 590, 34), 24, Accent);
        var note = Text(_note, _model.DailyNote, new(22, 51, 602, 80), 28, wrap: true);
        if (_model.Stickers.Length > 0)
        {
            var sticker = Text(_summary, string.Join("  ·  ", _model.Stickers), new(100, 582, 1440, 52), 20, Accent, wrap: true);
            sticker.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        }
    }
    internal void SelectPage(bool details)
    {
        FinishAnimation(); _summary.Visible = !details; _details.Visible = details;
        if (UsesBookArt) PaintBookPaper(details);
        StyleTab(_summaryTab, !details); StyleTab(_detailTab, details);
    }
    internal void SelectFilter(BookFilter filter) { FinishAnimation(); _filter = filter; RefreshRows(); }
    private void RefreshRows()
    {
        Clear(_rows);
        string[] names = { "全部", "完成", "错误", "流失" };
        for (int i = 0; i < 4; i++) { _filters[i].Text = $"{names[i]} {_model.Filter((BookFilter)i).Count()}"; StyleTab(_filters[i], (int)_filter == i); }
        foreach (var order in _model.Filter(_filter))
        {
            float nameHeight = WrappedHeight(order.Customer, 550, 26);
            float productY = Math.Max(48, nameHeight + 8);
            float reasonHeight = order.Reason.Length > 0 ? WrappedHeight(order.Reason, 600, 20) : 0;
            var row = new Control { CustomMinimumSize = new(1480, 132), MouseFilter = MouseFilterEnum.Ignore }; _rows.AddChild(row);
            Text(row, $"#{order.Number:00}", new(0, 0, 65, 38), 18, Muted);
            _art ??= new TianjinArtCatalog();
            var portrait = Picture(row, BookPortraits.Head(_art, order.Appearance, order.Lost ? CustomerExpression.Angry : order.Outcome == BookOutcome.Incorrect ? CustomerExpression.Impatient : CustomerExpression.Happy), new(62, 0, 70, 70));
            if (order.Lost) portrait.Modulate = new(.75f, .70f, .65f, .8f);
            if (UsesBookArt) { portrait.Position += new Vector2(12, 12); portrait.Size = new(46, 46); Art(row, "顾客头像圆框", new(62, 0, 70, 70)); }
            Text(row, order.Customer, new(152, 0, 550, nameHeight), 26, wrap: true);
            float bandHeight = 54;
            for (int i = 0; i < order.Products.Count; i++)
            {
                var p = order.Products[i]; float x = 146 + (i % 2) * 297, y = productY;
                string productText = $"{p.Name}{(p.Preference.Length > 0 ? "·" + p.Preference : "")} ×{p.Quantity}";
                float textHeight = Math.Max(48, WrappedHeight(productText, 238, 20)); bandHeight = Math.Max(bandHeight, textHeight + 8);
                Place(row, new BookFoodIcon { Product = p }, new(x, y, 45, 45));
                var label = Text(row, productText, new(x + 51, y, 238, textHeight), 20, wrap: true);
                label.AutowrapMode = TextServer.AutowrapMode.WordSmart;
                if (i % 2 == 1 || i == order.Products.Count - 1) { productY += bandHeight; bandHeight = 54; }
            }
            var color = order.Outcome switch { BookOutcome.Perfect => new Color("#91601D"), BookOutcome.Incorrect => new("#A05C2F"), BookOutcome.Lost or BookOutcome.Unreceived => new("#92534B"), _ => new("#456E49") };
            if (UsesBookArt) Art(row, order.Outcome switch { BookOutcome.Perfect => "Perfect 图标", BookOutcome.Incorrect => "状态章-错误完成", BookOutcome.Lost or BookOutcome.Unreceived => "状态章-顾客流失", _ => "状态章-正确完成" }, new(838, 0, 44, 44));
            else Place(row, new BookStatusMark { Outcome = order.Outcome, Ink = color }, new(846, 4, 32, 32));
            string status = order.Outcome switch { BookOutcome.Perfect => "完美出餐", BookOutcome.Incorrect => "出餐错误", BookOutcome.Lost => "等待离开", BookOutcome.Unreceived => "收摊未接待", _ => "顺利完成" };
            Text(row, status, new(892, 0, 560, 38), 26, color);
            Text(row, $"收入 ¥{order.Revenue}    小费 +¥{order.Tips}", new(846, 47, 425, 36), 24);
            Text(row, order.Score is { } score ? $"评分 {score:0}" : "评分 —", new(1270, 47, 180, 36), 24, Muted);
            if (order.Reason.Length > 0) { var reason = Text(row, order.Reason, new(846, 88, 600, reasonHeight), 20, color, wrap: true); }
            row.CustomMinimumSize = new(1480, Math.Max(132, Math.Max(productY + 12, 100 + reasonHeight)));
            if (UsesBookArt)
            {
                BookDivider(row, new(0, row.CustomMinimumSize.Y - 10, 710, 10));
                BookDivider(row, new(846, row.CustomMinimumSize.Y - 10, 600, 10));
            }
            else Line(row, new(0, row.CustomMinimumSize.Y - 1, 1480, 1), new Color(.47f, .32f, .20f, .16f));
        }
        if (!_model.Filter(_filter).Any()) _rows.AddChild(TianjinUi.Label(_model.Orders.Count == 0 ? "还没有结束的客单，第一笔收入值得期待。" : "这一类客单还没有记录。", 26, Muted));
        if (_model.ExtraNotes.Length > 0) { _rows.AddChild(TianjinUi.Label("补充记录", 24, Accent)); foreach (var extra in _model.ExtraNotes) _rows.AddChild(TianjinUi.Label(extra, 22, Muted)); }
        if (UsesBookArt) foreach (var sticker in _model.Stickers) _rows.AddChild(TianjinUi.Label(sticker, 22, Accent));
        _scroll.ScrollVertical = 0;
    }
    private void RequestClose() { FinishAnimation(); if (_model.CanClose) CloseRequested?.Invoke(); }
    private void StartAnimation()
    {
        if (ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool()) return;
        _audio.Play(PancakeSound.BookOpen);
        _book.Modulate = new(1, 1, 1, .3f);
        _entrance = CreateTween(); _entrance.TweenProperty(_book, "modulate", Colors.White, .2);
        if (!_model.Closing) return;
        _income.Text = "¥0"; _metrics.Modulate = new(1, 1, 1, 0); _stamp.Modulate = new(1, 1, 1, 0); _note.Modulate = new(1, 1, 1, 0);
        _entrance.TweenCallback(Callable.From(() => _audio.Play(PancakeSound.CoinCollect)));
        _entrance.TweenMethod(Callable.From<float>(n => _income.Text = $"¥{Mathf.RoundToInt(n)}"), 0f, (float)_model.Result.TotalRevenue, .6);
        _entrance.TweenProperty(_metrics, "modulate", Colors.White, .25);
        _entrance.TweenCallback(Callable.From(() => { if (_model.Result.PerfectOrders > 0) _audio.Play(PancakeSound.BookStamp); _stamp.Scale = Vector2.One * 1.13f; }));
        _entrance.TweenProperty(_stamp, "modulate", Colors.White, .08);
        _entrance.TweenProperty(_stamp, "scale", Vector2.One, .16).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
        _entrance.TweenProperty(_note, "modulate", Colors.White, .3);
        _entrance.TweenCallback(Callable.From(() => _audio.Play(PancakeSound.Ready)));
    }
    internal void FinishAnimation()
    {
        _entrance?.Kill(); _entrance = null;
        if (_book is null) return;
        _book.Modulate = Colors.White;
        if (_income is not null) _income.Text = $"¥{_model.Result.TotalRevenue}";
        foreach (var c in new[] { _metrics, _stamp, _note }) if (IsInstanceValid(c)) { c.Modulate = Colors.White; c.Scale = Vector2.One; }
    }
    public override void _Input(InputEvent input)
    {
        if (!IsVisibleInTree()) return;
        if (input is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left }) FinishAnimation();
        if (input is not InputEventKey { Pressed: true, Echo: false } key) return;
        if (key.Keycode == Key.Escape) RequestClose();
        else if (key.Keycode == Key.Tab)
        {
            var buttons = this.Descendants<Button>().Where(b => b.IsVisibleInTree() && !b.Disabled).ToArray();
            int i = Array.IndexOf(buttons, GetViewport().GuiGetFocusOwner());
            if (buttons.Length > 0) buttons[(i + (key.ShiftPressed ? buttons.Length - 1 : 1)) % buttons.Length].GrabFocus();
        }
        else if (key.Keycode is Key.Enter or Key.Space) return;
        GetViewport().SetInputAsHandled();
    }
    private void StyleTab(Button b, bool selected)
    {
        Color fill = UsesBookArt ? (selected ? CitySettlementTheme.Paper.Lerp(CityTheme.Secondary, .38f) : CitySettlementTheme.Paper) : selected ? new("#F3DA9B") : new("#F9EFD8");
        var box = TianjinUi.Box(fill, 9, selected ? 2 : 1, false);
        box.BorderColor = UsesBookArt ? (selected ? CityTheme.Primary : CitySettlementTheme.Section) : selected ? Accent : new("#BAA385");
        b.AddThemeStyleboxOverride("normal", box);
    }
    private float WrappedHeight(string text, float width, int size) => Math.Max(size + 10, GetThemeFont("font", "Label").GetMultilineStringSize(text, HorizontalAlignment.Left, width, size).Y);
    private static string Percent(double? value) => value is { } n ? $"{Math.Round(n, MidpointRounding.AwayFromZero):0}%" : "—";
    private static void Clear(Node n) { foreach (Node child in n.GetChildren()) { n.RemoveChild(child); child.QueueFree(); } }
    private static void Place(Control parent, Control node, Rect2 r) { parent.AddChild(node); node.Position = r.Position; node.Size = r.Size; }
    private Label Text(Control parent, string value, Rect2 r, int size, Color? color = null, HorizontalAlignment align = HorizontalAlignment.Left, bool wrap = false)
    {
        var label = TianjinUi.Label(wrap ? "" : value, size, color ?? Ink, align);
        label.MouseFilter = MouseFilterEnum.Ignore;
        if (wrap) { label.Size = r.Size; label.AutowrapMode = TextServer.AutowrapMode.WordSmart; label.Text = value; }
        Place(parent, label, r); return label;
    }
    private static void Panel(Control p, Rect2 r, Color color, int radius, int border) { var panel = new Panel { MouseFilter = MouseFilterEnum.Ignore }; var box = TianjinUi.Box(color, radius, border, false); box.BorderColor = new("#9D794E"); panel.AddThemeStyleboxOverride("panel", box); Place(p, panel, r); }
    private static void Line(Control p, Rect2 r, Color color) => Place(p, new ColorRect { Color = color, MouseFilter = MouseFilterEnum.Ignore }, r);
    private static TextureRect Picture(Control p, Texture2D texture, Rect2 r) { var image = TianjinUi.Texture(texture, Vector2.Zero); Place(p, image, r); return image; }
    private static Button ButtonAt(Control p, string text, Rect2 r, Action action) { var b = TianjinUi.Button(text, minimumSize: r.Size); b.AddThemeFontSizeOverride("font_size", 24); b.Pressed += action; Place(p, b, r); return b; }
}
