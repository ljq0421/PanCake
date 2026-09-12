using Godot;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
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
        foreach (var label in _details.GetChildren().OfType<Label>()) label.AddThemeColorOverride("font_color", Ink);
        _plainPaper.Visible = !UsesBookArt; _illustratedPaper.Visible = UsesBookArt;
        _scroll.Size = new(1524, UsesBookArt ? 480 : 568);
        _save.Position = new(80, 792);
        _save.Size = new(UsesBookArt ? 1140 : 1120, 65);
        CloseButton.Position = new(1320, 798); CloseButton.CustomMinimumSize = new(240, 72); CloseButton.Size = new(240, 72);
        _retry.Position = new(1100, 809);
        _city.Position = new(80, 32); _title.Position = new(80, 78); _title.Size = new(1000, 62); _title.HorizontalAlignment = HorizontalAlignment.Left; _title.AddThemeFontSizeOverride("font_size", 46);
        _infoButton.Position = new(80, 842); _escapeHint.Position = new(1340, 870); _explanation.Position = new(230, 850);
        _explanation.RemoveThemeStyleboxOverride("normal");
    }

    private void PaintBookPaper(bool details)
    {
        Clear(_illustratedPaper);
        Art(_illustratedPaper, "营业结算账本底板-v1", new(0, 0, 1680, 900));
        _city.Position = new(100, 39);
        _title.Position = new(100, 80);
        _title.Size = new(620, 60); _title.HorizontalAlignment = HorizontalAlignment.Left;
        _title.AddThemeFontSizeOverride("font_size", 46);
        _save.Position = new(100, details ? 736 : 790); _save.Size = new(970, 55);
        CloseButton.Position = details ? new(1320, 741) : new(1410, 653);
        CloseButton.CustomMinimumSize = details ? new(240, 64) : new(180, 104); CloseButton.Size = CloseButton.CustomMinimumSize;
        _retry.Position = new(1100, details ? 746 : 727);
        _infoButton.Position = new(1120, details ? 749 : 791); _escapeHint.Position = new(details ? 1340 : 1370, details ? 800 : 767);
        if (_model.CanRetry) _infoButton.Position = new(100, details ? 778 : 823);
        _explanation.Position = new(100, details ? 715 : 768);
        _explanation.AddThemeStyleboxOverride("normal", TianjinUi.Box(CitySettlementTheme.Paper, 5, 1, false));
    }

    private void BookDivider(Control parent, Rect2 bounds)
    {
        var line = Art(parent, "账本轻分隔线", bounds);
        line.Modulate = new Color(1, 1, 1, .28f);
    }

    private void BuildArtSummary()
    {
        var r = _model.Result;
        BookDivider(_summary, new(95, 463, 650, 12));
        BookDivider(_summary, new(920, 463, 650, 12));
        Art(_summary, "总收入图标", new(90, 30, 110, 110));
        Text(_summary, "今日收入", new(220, 4, 460, 45), 30);
        _income = Text(_summary, $"¥{r.TotalRevenue}", new(215, 54, 510, 110), 84);
        Text(_summary, "菜品销售", new(105, 190, 380, 42), 26, Muted);
        Text(_summary, $"¥{r.SaleRevenue}", new(485, 190, 240, 42), 28, Ink, HorizontalAlignment.Right);
        Art(_summary, "小费图标", new(99, 247, 43, 43));
        Text(_summary, "顾客小费", new(157, 246, 330, 42), 26, Muted);
        Text(_summary, $"+¥{r.Tips}", new(485, 246, 240, 42), 28, Ink, HorizontalAlignment.Right);
        Art(_summary, "今日热销徽章", new(100, 290, 300, 70));
        Text(_summary, "今日最受欢迎", new(171, 309, 210, 35), 22, Ink);
        if (_model.BestSeller is { } best)
        {
            Place(_summary, new BookFoodIcon { Product = best }, new(105, 374, 78, 78));
            Text(_summary, best.Name, new(220, 365, 500, 60), 28, wrap: true);
            Text(_summary, $"今日卖出 ×{best.Quantity}", new(220, 424, 500, 32), 22, Muted);
        }
        else Text(_summary, "还没有完成的客单", new(188, 400, 520, 60), 25, Muted);

        _metrics = new Control { MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_metrics);
        Text(_metrics, "今日接待" + (_model.Closing ? "" : " · 已结束"), new(925, -61, 620, 42), 32, Ink);
        Text(_metrics, $"{_model.Resolved} {_model.Unit}", new(925, 55, 550, 68), 48);
        Art(_metrics, "完成顾客图标", new(918, 140, 55, 55));
        Text(_metrics, $"完成 {r.CompletedCustomers}", new(985, 150, 250, 45), 30, CitySettlementTheme.Completed.Darkened(.38f));
        Art(_metrics, "流失顾客图标", new(1240, 140, 55, 55));
        Text(_metrics, $"流失 {r.LostCustomers}", new(1305, 150, 250, 45), 30, CitySettlementTheme.Lost.Darkened(.25f));
        Text(_metrics, "完成率  " + Percent(_model.CompletionRate), new(925, 213, 600, 42), 26, Muted);
        Art(_metrics, "满意度图标", new(918, 291, 54, 54));
        Text(_metrics, "完成顾客满意度", new(985, 294, 350, 40), 25, Muted);
        Text(_metrics, Percent(_model.Satisfaction), new(985, 342, 290, 70), 48);
        _stamp = new Control { Position = new(1350, 278), Size = new(170, 178), PivotOffset = new(85, 89), MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_stamp);
        if (r.PerfectOrders > 0)
        {
            Art(_stamp, "Perfect 印章", new(23, 0, 124, 124));
            Text(_stamp, $"Perfect ×{r.PerfectOrders}", new(-10, 130, 190, 38), 25, new("#8B5926"), HorizontalAlignment.Center);
        }
        else Text(_stamp, "今天还没有\n完美出餐", new(-5, 40, 185, 90), 24, Muted, HorizontalAlignment.Center);

        _note = new Control { Position = new(95, 478), Size = new(650, 145), MouseFilter = MouseFilterEnum.Ignore }; _summary.AddChild(_note);
        Art(_note, "今日手记便签底板", new(0, 0, 650, 145));
        Text(_note, "今日手记", new(48, 22, 555, 30), 22, Ink);
        Text(_note, _model.DailyNote, new(48, 57, 555, 74), 24, wrap: true);
        var rating = _model.Stickers.Where(s => s.Contains("评级")).ToArray();
        if (rating.Length > 0) Text(_summary, string.Join(" · ", rating), new(925, 424, 620, 35), 22, Ink);
        var unlocked = _model.Stickers.Where(s => !s.Contains("评级") && !s.Contains("升级")).ToArray();
        var upgrades = _model.Stickers.Where(s => s.Contains("升级")).ToArray();
        float y = 468;
        foreach (var group in new[] { (Items: unlocked, Art: "新解锁提示贴片"), (Items: upgrades, Art: "可升级提示贴片") })
        {
            if (group.Items.Length == 0) continue;
            Art(_summary, group.Art, new(918, y, 440, 94));
            string caption = group.Items.Length == 1 ? group.Items[0] : "新解锁 · 回店查看";
            Text(_summary, caption, new(group.Art == "新解锁提示贴片" ? 1050 : 984, y + 24, group.Art == "新解锁提示贴片" ? 230 : 280, 56), 18, Ink, wrap: true);
            y += 89;
        }
    }
}
