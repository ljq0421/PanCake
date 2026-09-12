using Godot;
using ProjectCake.Customers;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
    private const float ArtPageLeft = 230, ArtPageRight = 890, ArtPageWidth = 560;
    private const float ArtRowRight = ArtPageRight - ArtPageLeft, ArtRowWidth = 1200;
    private Control _plainPaper = null!, _illustratedPaper = null!;
    private Button _infoButton = null!;
    private Label _escapeHint = null!, _explanation = null!;
    private bool UsesBookArt => _model.CityId is "tianjin" or "wuhan" or "xian";
    private CitySettlementTheme CityTheme => CitySettlementTheme.For(_model.CityId);
    private TextureRect Art(Control parent, string name, Rect2 bounds)
    {
        var image = Picture(parent, BookArtCatalog.Get(name), bounds);
        image.Material = BookArtCatalog.DecorationMaterial(name, CityTheme);
        return image;
    }

    private static Rect2 FittedArtBounds(TextureRect image)
    {
        Vector2 original = image.Texture.GetSize();
        Vector2 fitted = original * Math.Min(image.Size.X / original.X, image.Size.Y / original.Y);
        return new Rect2(image.Position + (image.Size - fitted) / 2, fitted);
    }

    private void ApplyBookSkin()
    {
        Theme = TianjinUi.CreateTheme();
        if (UsesBookArt)
        {
            foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            {
                Color fill = state switch { "hover" => CitySettlementTheme.Paper.Lerp(CityTheme.Secondary, .28f), "pressed" => CitySettlementTheme.Section.Lerp(CityTheme.Primary, .20f), "disabled" => CitySettlementTheme.Section, _ => CitySettlementTheme.Paper };
                var box = TianjinUi.Box(fill, 14, 3, state != "disabled"); box.BorderColor = CitySettlementTheme.Border;
                Theme.SetStylebox(state, "Button", box);
            }
            var focus = TianjinUi.Box(Colors.Transparent, 14, 4, false); focus.BorderColor = CityTheme.Primary;
            Theme.SetStylebox("focus", "Button", focus);
            foreach (string color in new[] { "font_color", "font_hover_color", "font_pressed_color" }) Theme.SetColor(color, "Button", Ink);
            Theme.SetColor("font_disabled_color", "Button", Muted);
            _infoButton.AddThemeStyleboxOverride("focus", focus);
        }
        _city.AddThemeColorOverride("font_color", Muted); _title.AddThemeColorOverride("font_color", Ink);
        _save.AddThemeColorOverride("font_color", Muted); _escapeHint.AddThemeColorOverride("font_color", Muted); _explanation.AddThemeColorOverride("font_color", Muted);
        _detailHeading.AddThemeColorOverride("font_color", Ink);
        _plainPaper.Visible = !UsesBookArt; _illustratedPaper.Visible = UsesBookArt;
        _explanation.Hide();
        _summary.Position = _details.Position = new(0, 155);
        _summary.Size = _details.Size = new(1680, 620);
        _scroll.Position = new(78, 66); _scroll.Size = new(1524, 568);
        _detailHeading.Position = new(80, 0); _detailHeading.Size = new(380, 44);
        SetButtonBounds(_summaryTab, new(1220, -18, 170, 64)); SetButtonBounds(_detailTab, new(1400, -18, 170, 64));
        for (int i = 0; i < _filters.Count; i++) { SetButtonBounds(_filters[i], new(900 + i * 160, 0, 148, 48)); _filters[i].AddThemeFontSizeOverride("font_size", 24); }
        _save.Position = new(80, 792); _save.Size = new(1120, 65);
        _save.MaxLinesVisible = -1; _save.TextOverrunBehavior = TextServer.OverrunBehavior.NoTrimming;
        _save.AddThemeFontSizeOverride("font_size", 20); _save.MouseFilter = MouseFilterEnum.Ignore;
        SetButtonBounds(CloseButton, new(1320, 798, 240, 72)); SetButtonBounds(_retry, new(1100, 809, 190, 58));
        _city.Size = new(600, 38);
        _city.Position = new(80, 32); _title.Position = new(80, 78); _title.Size = new(1000, 62); _title.HorizontalAlignment = HorizontalAlignment.Left; _title.AddThemeFontSizeOverride("font_size", 46);
        SetButtonBounds(_infoButton, new(80, 842, 130, 48));
        _escapeHint.Position = new(1340, 870); _escapeHint.Size = new(220, 28);
        _explanation.Position = new(230, 850); _explanation.Size = new(990, 32);
        _explanation.AutowrapMode = TextServer.AutowrapMode.Off; _explanation.AddThemeFontSizeOverride("font_size", 18);
        _explanation.RemoveThemeStyleboxOverride("normal");
        if (UsesBookArt) ApplyArtLayout();
    }

    private static void SetButtonBounds(Button button, Rect2 bounds)
    {
        button.CustomMinimumSize = bounds.Size;
        button.Position = bounds.Position;
        button.Size = bounds.Size;
    }

    private void ApplyArtLayout()
    {
        _city.Position = new(ArtPageLeft, 78); _city.Size = new(ArtPageWidth, 32);
        _title.Position = new(ArtPageLeft, 114); _title.Size = new(ArtPageWidth, 60);
        SetButtonBounds(_summaryTab, new(ArtPageRight, 99, 268, 60));
        SetButtonBounds(_detailTab, new(1182, 99, 268, 60));
        _summary.Position = _details.Position = new(0, 185);
        _summary.Size = _details.Size = new(1680, 540);
        _detailHeading.Position = new(ArtPageLeft, 0); _detailHeading.Size = new(ArtPageWidth, 44);
        for (int i = 0; i < _filters.Count; i++)
        {
            _filters[i].AddThemeFontSizeOverride("font_size", 20);
            SetButtonBounds(_filters[i], new(ArtPageRight + i * 142, 0, 134, 46));
        }
        // Both halves of an order scroll together; the last 20 px are reserved
        // for the scrollbar, still inside the right-page safe area.
        _scroll.Position = new(ArtPageLeft, 58); _scroll.Size = new(1220, 477);
        _save.AddThemeFontSizeOverride("font_size", 18);
        _save.MaxLinesVisible = 2; _save.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
        _save.MouseFilter = MouseFilterEnum.Pass;
        _save.Position = new(ArtPageLeft, 732); _save.Size = new(ArtPageWidth, 52);
        SetButtonBounds(_retry, new(1020, 738, 180, 56));
        SetButtonBounds(CloseButton, new(1220, 738, 230, 56));
        SetButtonBounds(_infoButton, new(ArtPageRight, 790, 130, 34));
        _escapeHint.Position = new(1260, 798); _escapeHint.Size = new(190, 26);
        _explanation.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _explanation.AddThemeFontSizeOverride("font_size", 16);
        _explanation.Position = new(ArtPageLeft, 790); _explanation.Size = new(ArtPageWidth, 34);
    }

    private void PaintBookPaper()
    {
        Clear(_illustratedPaper);
        const float width = 900f * 1448f / 929f;
        var board = Picture(_illustratedPaper, BookArtCatalog.GetBoard(_model.CityId), new((1680 - width) / 2, 0, width, 900));
        board.Name = "BookBoard";
        board.Material = null;
    }

    private void BookDivider(Control parent, Rect2 bounds)
    {
        var line = Art(parent, "账本轻分隔线", bounds);
        line.Modulate = new Color(1, 1, 1, .28f);
    }

    private void BuildArtSummary()
    {
        var r = _model.Result;
        Art(_summary, "总收入图标", new(ArtPageLeft, 38, 100, 100));
        Text(_summary, "今日收入", new(350, 0, 440, 40), 30);
        _income = Text(_summary, $"¥{r.TotalRevenue}", new(345, 42, 445, 92), 76);
        Text(_summary, "菜品销售", new(ArtPageLeft, 146, 290, 38), 26, Muted);
        Text(_summary, $"¥{r.SaleRevenue}", new(530, 146, 260, 38), 28, Ink, HorizontalAlignment.Right);
        Art(_summary, "小费图标", new(ArtPageLeft, 195, 38, 38));
        Text(_summary, "顾客小费", new(280, 195, 240, 38), 26, Muted);
        Text(_summary, $"+¥{r.Tips}", new(530, 195, 260, 38), 28, Ink, HorizontalAlignment.Right);
        BookDivider(_summary, new(ArtPageLeft, 245, ArtPageWidth, 10));
        var bestSellerBadge = FittedArtBounds(Art(_summary, "今日热销徽章", new(ArtPageLeft, 263, 300, 60)));
        Text(_summary, "今日最受欢迎", new(bestSellerBadge.Position + new Vector2(bestSellerBadge.Size.X * .25f, 17), new(bestSellerBadge.Size.X * .68f, 32)), 22);
        if (_model.BestSeller is { } best)
        {
            Place(_summary, new BookFoodIcon { Product = best }, new(ArtPageLeft, 337, 68, 68));
            var name = Text(_summary, best.Name, new(320, 326, 470, 58), 26, wrap: true);
            name.MaxLinesVisible = 2; name.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis; name.TooltipText = best.Name;
            name.MouseFilter = MouseFilterEnum.Pass;
            Text(_summary, $"今日卖出 ×{best.Quantity}", new(320, 387, 470, 30), 22, Muted);
        }
        else Text(_summary, "还没有完成的客单", new(ArtPageLeft, 337, ArtPageWidth, 68), 25, Muted);

        _metrics = new Control { MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_metrics);
        Text(_metrics, "今日接待" + (_model.Closing ? "" : " · 已结束"), new(ArtPageRight, 0, ArtPageWidth, 40), 30);
        Text(_metrics, $"{_model.Resolved} {_model.Unit}", new(ArtPageRight, 48, ArtPageWidth, 66), 48);
        Art(_metrics, "完成顾客图标", new(ArtPageRight, 132, 46, 46));
        Text(_metrics, $"完成 {r.CompletedCustomers}", new(946, 132, 214, 46), 27, CitySettlementTheme.Completed.Darkened(.38f));
        Art(_metrics, "流失顾客图标", new(1182, 132, 46, 46));
        Text(_metrics, $"流失 {r.LostCustomers}", new(1238, 132, 212, 46), 27, CitySettlementTheme.Lost.Darkened(.25f));
        Text(_metrics, "完成率  " + Percent(_model.CompletionRate), new(ArtPageRight, 195, ArtPageWidth, 38), 26, Muted);
        BookDivider(_metrics, new(ArtPageRight, 245, ArtPageWidth, 10));
        Art(_metrics, "满意度图标", new(ArtPageRight, 278, 44, 44));
        Text(_metrics, "完成顾客满意度", new(946, 278, 330, 40), 25, Muted);
        Text(_metrics, Percent(_model.Satisfaction), new(946, 326, 260, 70), 48);
        _stamp = new Control { Position = new(1280, 263), Size = new(170, 144), PivotOffset = new(85, 72), MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_stamp);
        if (r.PerfectOrders > 0)
        {
            Art(_stamp, "Perfect 印章", new(35, 0, 100, 100));
            Text(_stamp, $"Perfect ×{r.PerfectOrders}", new(0, 106, 170, 34), 22, new("#8B5926"), HorizontalAlignment.Center);
        }
        else Text(_stamp, "今天还没有\n完美出餐", new(0, 34, 170, 86), 22, Muted, HorizontalAlignment.Center);

        _note = new Control { Name = "DailyNote", Position = new(ArtPageLeft, 418), Size = new(ArtPageWidth, 122), MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_note);
        var notePaper = FittedArtBounds(Art(_note, "今日手记便签底板", new(0, 0, ArtPageWidth, 122)));
        Text(_note, "今日手记", new(notePaper.Position + new Vector2(52, 18), new(notePaper.Size.X - 80, 30)), 21);
        Text(_note, _model.DailyNote, new(notePaper.Position + new Vector2(28, 52), new(notePaper.Size.X - 56, 62)), 20, wrap: true);
        var rating = _model.Stickers.Where(s => s.Contains("评级")).ToArray();
        if (rating.Length > 0) Text(_summary, string.Join(" · ", rating), new(ArtPageRight, 408, ArtPageWidth, 30), 21);
        var unlocked = _model.Stickers.Where(s => !s.Contains("评级") && !s.Contains("升级")).ToArray();
        var upgrades = _model.Stickers.Where(s => s.Contains("升级")).ToArray();
        AddSummarySticker(unlocked, "新解锁提示贴片", "UnlockSticker", new(ArtPageRight, 445, 268, 82), true);
        AddSummarySticker(upgrades, "可升级提示贴片", "UpgradeSticker", new(1182, 445, 268, 82), false);
    }

    private void AddSummarySticker(string[] items, string art, string name, Rect2 bounds, bool unlock)
    {
        if (items.Length == 0) return;
        var sticker = new Control { Name = name, MouseFilter = MouseFilterEnum.Pass, TooltipText = string.Join("\n", items) };
        Place(_summary, sticker, bounds);
        var paper = FittedArtBounds(Art(sticker, art, new(0, 0, bounds.Size.X, bounds.Size.Y)));
        float textWidth = unlock ? 158 : 181;
        string shortCaption = unlock ? "新解锁 · 回店查看" : "可升级 · 回店查看";
        string caption = items.Length == 1 ? items[0] : shortCaption;
        if (GetThemeFont("font", "Label").GetStringSize(caption, fontSize: 17).X > textWidth) caption = shortCaption;
        var label = Text(sticker, caption, new(unlock ? 72 : 18, paper.Position.Y + (paper.Size.Y - 28) / 2, textWidth, 28), 17);
        label.MaxLinesVisible = 1; label.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
    }

    private void RefreshArtRows()
    {
        foreach (var order in _model.Filter(_filter)) BuildArtOrderRow(order);
        if (!_model.Filter(_filter).Any()) AddArtRowNote(_model.Orders.Count == 0 ? "还没有结束的客单，第一笔收入值得期待。" : "这一类客单还没有记录。", 26, Muted);
        if (_model.ExtraNotes.Length > 0)
        {
            AddArtRowNote("补充记录", 24, Accent);
            foreach (var extra in _model.ExtraNotes) AddArtRowNote(extra, 22, Muted);
        }
        foreach (var sticker in _model.Stickers) AddArtRowNote(sticker, 22, Accent);
        _scroll.ScrollVertical = 0;
    }

    private void AddArtRowNote(string text, int fontSize, Color color)
    {
        float height = WrappedHeight(text, ArtPageWidth, fontSize) + 6;
        var row = new Control { CustomMinimumSize = new(ArtRowWidth, height), MouseFilter = MouseFilterEnum.Ignore }; _rows.AddChild(row);
        Text(row, text, new(0, 0, ArtPageWidth, height), fontSize, color, wrap: true);
    }

    private void BuildArtOrderRow(BookOrder order)
    {
        const float rightWidth = ArtRowWidth - ArtRowRight;
        float nameHeight = WrappedHeight(order.Customer, 425, 26);
        float productY = Math.Max(78, nameHeight + 12);
        var row = new Control { Name = $"OrderRow{order.Number}", CustomMinimumSize = new(ArtRowWidth, 148), MouseFilter = MouseFilterEnum.Ignore }; _rows.AddChild(row);
        Text(row, $"#{order.Number:00}", new(0, 0, 52, 38), 18, Muted);
        _art ??= new TianjinArtCatalog();
        var portrait = Picture(row, BookPortraits.Head(_art, order.Appearance, order.Lost ? CustomerExpression.Angry : order.Outcome == BookOutcome.Incorrect ? CustomerExpression.Impatient : CustomerExpression.Happy), new(67, 12, 46, 46));
        if (order.Lost) portrait.Modulate = new(.75f, .70f, .65f, .8f);
        Art(row, "顾客头像圆框", new(55, 0, 70, 70));
        Text(row, order.Customer, new(135, 0, 425, nameHeight), 26, wrap: true);
        foreach (var product in order.Products)
        {
            string caption = $"{product.Name}{(product.Preference.Length > 0 ? "·" + product.Preference : "")} ×{product.Quantity}";
            float height = Math.Max(48, WrappedHeight(caption, 503, 20));
            Place(row, new BookFoodIcon { Product = product }, new(0, productY, 45, 45));
            Text(row, caption, new(57, productY, 503, height), 20, wrap: true);
            productY += height + 10;
        }
        var color = order.Outcome switch { BookOutcome.Perfect => new Color("#91601D"), BookOutcome.Incorrect => new("#A05C2F"), BookOutcome.Lost or BookOutcome.Unreceived => new("#92534B"), _ => new("#456E49") };
        Art(row, order.Outcome switch { BookOutcome.Perfect => "Perfect 图标", BookOutcome.Incorrect => "状态章-错误完成", BookOutcome.Lost or BookOutcome.Unreceived => "状态章-顾客流失", _ => "状态章-正确完成" }, new(ArtRowRight, 0, 42, 42));
        string status = order.Outcome switch { BookOutcome.Perfect => "完美出餐", BookOutcome.Incorrect => "出餐错误", BookOutcome.Lost => "等待离开", BookOutcome.Unreceived => "收摊未接待", _ => "顺利完成" };
        Text(row, status, new(ArtRowRight + 54, 0, rightWidth - 54, 38), 26, color);
        Text(row, $"收入 ¥{order.Revenue}    小费 +¥{order.Tips}", new(ArtRowRight, 48, rightWidth, 34), 22);
        Text(row, order.Score is { } score ? $"评分 {score:0}" : "评分 —", new(ArtRowRight, 86, rightWidth, 34), 22, Muted);
        float rightBottom = 120;
        if (order.Reason.Length > 0)
        {
            float height = WrappedHeight(order.Reason, rightWidth, 20);
            Text(row, order.Reason, new(ArtRowRight, 130, rightWidth, height), 20, color, wrap: true);
            rightBottom = 130 + height;
        }
        row.CustomMinimumSize = new(ArtRowWidth, Math.Max(productY, rightBottom) + 22);
        BookDivider(row, new(0, row.CustomMinimumSize.Y - 10, ArtPageWidth, 10));
        BookDivider(row, new(ArtRowRight, row.CustomMinimumSize.Y - 10, rightWidth, 10));
    }
}
