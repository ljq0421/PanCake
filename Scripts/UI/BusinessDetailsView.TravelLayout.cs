using Godot;
using ProjectCake.Customers;

namespace ProjectCake.UI;

// Tianjin/Wuhan reference layout: illustrated travel book, paired rows and warm paper panels.
// All amounts and outcomes remain supplied by the current business snapshot.
public partial class BusinessDetailsView
{
    private const int TravelActionFontSize = 24;

    private void ApplyTravelLayout()
    {
        _city.Position = new(410, 55); _city.Size = new(380, 34);
        _title.Position = new(410, 94); _title.Size = new(380, 54);
        _title.AddThemeFontSizeOverride("font_size", 42);
        _status.Position = new(ArtPageRight, 59);
        _save.Position = new(290, 777); _save.Size = new(500, 52);
        SetButtonBounds(_retry, new(945, 776, 180, 58));
        SetButtonBounds(CloseButton, new(1145, 776, 280, 70));
        CloseButton.AddThemeFontSizeOverride("font_size", 30);
        var closeTexture = GD.Load<Texture2D>("res://resource/art/TianJin/DialogUI/button-secondary-v1.png");
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            CloseButton.AddThemeStyleboxOverride(state, new StyleBoxTexture
            {
                Texture = closeTexture,
                ModulateColor = state switch { "hover" => new Color(1.06f, 1.04f, 1), "pressed" => new Color(.92f, .88f, .80f),
                    "disabled" => new Color(1, 1, 1, .45f), _ => Colors.White },
                ContentMarginLeft = 22, ContentMarginRight = 22, ContentMarginTop = 6, ContentMarginBottom = 10
            });
        var closeFocus = TianjinUi.Box(Colors.Transparent, 35, 2, false);
        closeFocus.BorderColor = CityTheme.Primary;
        closeFocus.ExpandMarginLeft = closeFocus.ExpandMarginRight = closeFocus.ExpandMarginTop = closeFocus.ExpandMarginBottom = 3;
        CloseButton.AddThemeStyleboxOverride("focus", closeFocus);
        SetButtonBounds(_previousPage, new(80, 431, 72, 72));
        SetButtonBounds(_nextPage, new(1540, 502, 72, 72));
        for (int i = 0; i < _filters.Count; i++)
        {
            SetButtonBounds(_filters[i], new(ArtPageRight + i * 142, -24, 134, 52));
            _filters[i].AddThemeFontSizeOverride("font_size", 23);
            if (_filters[i].GetNodeOrNull<Control>("SelectionMarker") is null)
            {
                var marker = new Control { Name = "SelectionMarker", Position = new(58, 50), Size = new(18, 9), MouseFilter = MouseFilterEnum.Ignore };
                _filters[i].AddChild(marker);
                marker.Draw += () =>
                {
                    var points = new Vector2[] { new(0, 0), new(9, 8), new(18, 0) };
                    marker.DrawColoredPolygon(points, CitySettlementTheme.Paper.Lerp(CityTheme.Secondary, .38f));
                    marker.DrawPolyline(points, CityTheme.Primary, 2, true);
                };
            }
        }
        _filters[(int)BookFilter.Completed].TooltipText = "完成包含出餐正确与出餐错误的订单；错误为完成订单的子集。";
        _filters[(int)BookFilter.Incorrect].TooltipText = "出餐错误的订单，同时计入完成。";
        _scroll.Position = new(ArtPageLeft, 55); _scroll.Size = new(1220, 560);
        _rows.AddThemeConstantOverride("separation", 12);
    }

    private void TravelPanel(Control parent, Rect2 bounds, bool inset = false)
    {
        var panel = new Panel { MouseFilter = MouseFilterEnum.Ignore };
        var box = TianjinUi.Box(inset ? new Color("#F5E5C4") with { A = .57f } : new Color("#FFF8E5") with { A = .18f }, 18, inset ? 0 : 2, false);
        box.BorderColor = CityTheme.Secondary with { A = .46f };
        panel.AddThemeStyleboxOverride("panel", box);
        Place(parent, panel, bounds);
    }

    private void BuildTravelSummary()
    {
        var r = _model.Result;
        TravelPanel(_summary, new(890, 24, 560, 303));
        TravelHeading(_summary, "收入详情", new(910, 3, 233, 51));
        CaptureTravelMotion(TravelMotionGroup.Income, _summary, () =>
            _incomeCoins = Art(_summary, "总收入图标", new(918, 92, 125, 112)));
        TravelValue(_summary, _model.Closing ? "今日收入" : "收入", new(1065, 67, 166, 38), 30);
        TravelAside(_summary, "好味道，\n让每一天都值得", new(1238, 57, 185, 48));
        CaptureTravelMotion(TravelMotionGroup.Income, _summary, () =>
            _income = TravelValue(_summary, $"¥{r.TotalRevenue}", new(1065, 108, 355, 96), 82));
        TravelPanel(_summary, new(907, 211, 526, 104), true);
        CaptureTravelMotion(TravelMotionGroup.Sales, _summary, () =>
        {
            Art(_summary, "小费图标-v1", new(933, 218, 51, 36));
            Text(_summary, "菜品销售", new(1005, 215, 220, 40), 26, Muted);
            TravelValue(_summary, $"¥{r.SaleRevenue}", new(1230, 215, 180, 40), 28, HorizontalAlignment.Right);
        });
        Line(_summary, new(933, 262, 477, 1), CityTheme.Secondary with { A = .65f });
        CaptureTravelMotion(TravelMotionGroup.Tips, _summary, () =>
        {
            Art(_summary, "单笔收入", new(933, 270, 51, 36));
            Text(_summary, "顾客小费", new(1005, 267, 220, 40), 26, Muted);
            TravelValue(_summary, $"+¥{r.Tips}", new(1230, 267, 180, 40), 28, HorizontalAlignment.Right);
        });
        BookDivider(_summary, new(890, 332, 560, 10));

        _note = new Control { Name = "DailyNote", Position = new(923, 378), Size = new(527, 127), MouseFilter = MouseFilterEnum.Ignore };
        _summary.AddChild(_note);
        // The existing note silhouette is wider than its content area; stretch the paper, never its lettering.
        var paper = Art(_note, "今日手记便签底板", new(0, 0, 527, 127));
        paper.StretchMode = TextureRect.StretchModeEnum.Scale;
        Text(_note, _model.NewWuhanUnlock || _model.Upgrades is null ? "营业手记" : "下一步期待", new(66, 19, 400, 34), 26);
        Text(_note, _model.NewWuhanUnlock ? "在天津忙碌了七天，早餐旅程有了新的方向。" : _model.Upgrades?.NextGoal ?? _model.DailyNote, new(38, 57, 452, 65), 20, wrap: true);
        if (_model.NewWuhanUnlock)
        {
            var tag = new Panel { Name = "WuhanUnlockTag", Position = new(110, 112), Size = new(385, 46), MouseFilter = MouseFilterEnum.Ignore };
            tag.AddThemeStyleboxOverride("panel", TianjinUi.Box(new Color("#C8DDD0"), 9, 1, false));
            _note.AddChild(tag);
            tag.AddChild(new BookFoodIcon { Position = new(8, 2), Size = new(46, 44), Product = new("", "热干面", 1, "HotDryNoodles") });
            Text(tag, "新城市已解锁 · 武汉", new(58, 4, 317, 40), 23, new Color("#24594F"));
        }
        if (_model.Challenge is not null)
            Text(_summary, _model.ChallengeCaption, new(890, 345, 560, 30), 21, wrap: false).Name = "ChallengeSettlement";

        // The left page starts below the book title; its content previously occupied the right page.
        _metrics = new Control { Position = new(ArtPageLeft - ArtPageRight, 54), MouseFilter = MouseFilterEnum.Ignore };
        _summary.AddChild(_metrics);
        BuildTravelReception();
        BookDivider(_metrics, new(890, 240, 560, 10));
        TravelPanel(_metrics, new(890, 270, 560, 120));
        var satisfaction = TravelHeading(_metrics, "顾客满意度", new(905, 253, 266, 47));
        satisfaction.Name = "BookSatisfaction";
        Explain(satisfaction, "只计算已完成订单的顾客，包含出餐错误的订单；流失顾客不计入平均值。没有完成订单时显示 —。" );
        CaptureTravelMotion(TravelMotionGroup.Evaluation, _metrics, () =>
        {
            Art(_metrics, "满意度图标", new(915, 309, 66, 66));
            Text(_metrics, Percent(_model.Satisfaction), new(1003, 306, 209, 72), 56);
        });
        Line(_metrics, new(1218, 300, 2, 72), CityTheme.Secondary with { A = .6f });
        _stamp = new Control { Position = _metrics.Position + new Vector2(1236, 269), Size = new(195, 117), PivotOffset = new(97, 58), MouseFilter = MouseFilterEnum.Ignore };
        _summary.AddChild(_stamp);
        if (r.PerfectOrders > 0)
        {
            Art(_stamp, "Perfect 印章", new(53, 0, 89, 89));
            TravelValue(_stamp, $"Perfect ×{r.PerfectOrders}", new(0, 90, 195, 27), 23, HorizontalAlignment.Center);
        }
        else Text(_stamp, "暂无完美出餐", new(0, 35, 195, 68), 22, Muted, HorizontalAlignment.Center);

        BuildTravelHighlights();

        CaptureTravelMotion(TravelMotionGroup.Review, _summary, () =>
        {
            var rating = _model.Stickers.Where(s => s.Contains("评级")).ToArray();
            if (rating.Length > 0) Text(_summary, string.Join(" · ", rating), new(245, 572, 530, 26), 19);
        });
        var upgrades = _model.Stickers.Where(s => s.Contains("升级")).ToArray();
        AddSummarySticker(upgrades, "可升级提示贴片", "UpgradeSticker", new(890, 540, 320, 80), false);
    }

    private static void Explain(Control control, string text)
    {
        control.MouseFilter = MouseFilterEnum.Pass;
        control.TooltipText = text;
    }

    private void BuildTravelReception()
    {
        var r = _model.Result;
        TravelPanel(_metrics, new(890, -30, 560, 259));
        var heading = TravelHeading(_metrics, "今日接待", new(905, -48, 233, 51));
        Explain(heading, "显示本次营业已结束的客单数：完成 + 流失。营业中尚在等待的顾客暂不计入。" );
        CaptureTravelMotion(TravelMotionGroup.Reception, _metrics, () =>
        {
            TravelValue(_metrics, $"{_model.Resolved} {_model.Unit}", new(914, 9, 285, 78), 61);
            if (_model.Resolved > 0) TravelAside(_metrics, "感谢每一位顾客", new(1208, 31, 215, 44));
        });
        TravelPanel(_metrics, new(909, 95, 522, 82), true);
        CaptureTravelMotion(TravelMotionGroup.Reception, _metrics, () =>
        {
            var stats = new[]
            {
                ("完成", r.CompletedCustomers, "完成顾客图标", new Color("#456E49")),
                ("错误", _model.Filter(BookFilter.Incorrect).Count(), "状态章-错误完成", new Color("#A05C2F")),
                ("流失", r.LostCustomers, "流失顾客图标", new Color("#765648"))
            };
            for (int i = 0; i < stats.Length; i++)
            {
                var (caption, count, icon, color) = stats[i];
                float x = 922 + i * 174;
                Art(_metrics, icon, new(x, 109, 58, 58));
                var label = TravelValue(_metrics, caption, new(x + 68, 100, 94, 32), 23, color: color);
                TravelValue(_metrics, count.ToString(), new(x + 68, 137, 84, 33), 27, HorizontalAlignment.Center);
                Explain(label, i == 0 ? "完成包含出餐正确与出餐错误的订单；错误为完成订单的子集。" : i == 1 ? "出餐错误的订单，同时计入完成。" : "等待超时离开的顾客。" );
                if (i < 2) Line(_metrics, new(x + 164, 109, 1, 55), CityTheme.Secondary with { A = .8f });
            }
            var rate = TravelValue(_metrics, "完成率  " + Percent(_model.CompletionRate), new(914, 188, 215, 30), 25);
            Explain(rate, "完成率 = 完成 ÷（完成 + 流失）。完成包含出餐错误的订单。" );
        });
        var progress = _completionProgress = new ProgressBar
        {
            Name = "BookCompletionProgress", MinValue = 0, MaxValue = 100,
            Value = _model.CompletionRate ?? 0, ShowPercentage = false, MouseFilter = MouseFilterEnum.Ignore
        };
        var track = TianjinUi.Box(new Color("#FFF8E8"), 13, 2, false);
        track.BorderColor = Ink;
        track.ContentMarginLeft = track.ContentMarginRight = track.ContentMarginTop = track.ContentMarginBottom = 4;
        var fill = TianjinUi.Box(new Color("#78A858"), 9, 0, false);
        fill.ContentMarginLeft = fill.ContentMarginRight = fill.ContentMarginTop = fill.ContentMarginBottom = 0;
        var frame = new Panel { MouseFilter = MouseFilterEnum.Ignore };
        frame.AddThemeStyleboxOverride("panel", track);
        Place(_metrics, frame, new(1142, 191, 283, 26));
        progress.AddThemeStyleboxOverride("background", new StyleBoxEmpty());
        progress.AddThemeStyleboxOverride("fill", fill);
        Place(frame, progress, new(4, 4, 275, 18));
    }

    private Label TravelValue(Control parent, string value, Rect2 bounds, int size,
        HorizontalAlignment align = HorizontalAlignment.Left, Color? color = null)
    {
        var font = GetThemeFont("font", "Label");
        string translated = TranslationServer.Translate(value);
        while (size > 16 && font.GetStringSize(translated, fontSize: size).X > bounds.Size.X) size--;
        return Text(parent, value, bounds, size, color, align);
    }

    private Label TravelHeading(Control parent, string caption, Rect2 bounds, bool crown = false)
    {
        var paper = Art(parent, "今日手记便签底板", bounds);
        paper.StretchMode = TextureRect.StretchModeEnum.Scale;
        if (crown) Picture(parent, GD.Load<Texture2D>("res://resource/art/Global/StartPage/皇冠.png"),
            new(bounds.Position + new Vector2(8, 3), new(40, 40)));
        return TravelValue(parent, caption,
            new(bounds.Position + new Vector2(crown ? 55 : 32, 8), new(bounds.Size.X - (crown ? 70 : 52), bounds.Size.Y - 14)), 27);
    }

    private void TravelAside(Control parent, string caption, Rect2 bounds)
    {
        var label = Text(parent, caption, bounds, 19, CityTheme.Primary.Lerp(CitySettlementTheme.Paper, .28f),
            HorizontalAlignment.Center, wrap: true);
        for (int size = 19; size > 15 && label.GetLineCount() > 2;)
            label.AddThemeFontSizeOverride("font_size", --size);
        Line(parent, new(bounds.Position + new Vector2(20, bounds.Size.Y + 3), new(bounds.Size.X - 40, 2)), CityTheme.Secondary with { A = .65f });
    }

    private void BuildTravelHighlights()
    {
        var section = new Control { Name = "BookHighlights", MouseFilter = MouseFilterEnum.Ignore };
        Place(_metrics, section, new(890, 405, 560, 111));
        TravelPanel(section, new(0, 10, 560, 101));
        TravelHeading(section, _model.Closing ? "今日亮点" : "本次亮点", new(15, -10, 245, 48), crown: true);
        CaptureTravelMotion(TravelMotionGroup.Review, section, () =>
        {
            var highlights = _model.Highlights;
            if (highlights.Count == 0)
            {
                Text(section, "慢慢来，把下一份早餐做好。", new(24, 44, 512, 52), 23, Muted, wrap: true);
                return;
            }
            float width = (532 - (highlights.Count - 1) * 10) / highlights.Count;
            for (int i = 0; i < highlights.Count; i++)
            {
                var item = highlights[i];
                var (icon, color) = item.Kind switch
                {
                    BookHighlightKind.Perfect => ("Perfect 图标", new Color("#A04B32")),
                    BookHighlightKind.NoLoss => ("完成顾客图标", new Color("#487344")),
                    BookHighlightKind.Tips => ("单笔收入", new Color("#996522")),
                    _ => ("状态章-正确完成", new Color("#4B716D"))
                };
                var chip = new Panel { Name = "Highlight" + item.Kind, MouseFilter = MouseFilterEnum.Ignore };
                var box = TianjinUi.Box(CitySettlementTheme.Paper.Lerp(color, .12f), 16, 2, false);
                box.BorderColor = CitySettlementTheme.Paper.Lerp(color, .48f);
                chip.AddThemeStyleboxOverride("panel", box);
                Place(section, chip, new(14 + i * (width + 10), 45, width, 52));
                Art(chip, icon, new(8, 10, 32, 32));
                var label = Text(chip, _model.Closing && item.Kind == BookHighlightKind.Tips ? "收获小费" : item.Caption,
                    new(46, 2, width - 52, 48), 20, color, wrap: true);
                // Long amounts and localized captions may use two lines; never ellipsize a result.
                for (int size = 20; size > 16 && label.GetLineCount() > 2;)
                    label.AddThemeFontSizeOverride("font_size", --size);
            }
        });
    }

    private void BuildTravelOrderRow(BookOrder order)
    {
        float nameHeight = WrappedHeight(order.Customer, 378, 28);
        var row = new Control { Name = $"OrderRow{order.Number}", CustomMinimumSize = new(ArtRowWidth, 130), MouseFilter = MouseFilterEnum.Ignore };
        _rows.AddChild(row);
        Text(row, $"#{order.Number:00}", new(0, 13, 57, 35), 22, Muted);
        _art ??= new TianjinArtCatalog();
        var expression = order.Lost ? CustomerExpression.Angry : order.Outcome == BookOutcome.Incorrect ? CustomerExpression.Impatient : CustomerExpression.Happy;
        Art(row, "顾客头像圆框", new(65, 2, 100, 100));
        var portrait = Picture(row, BookPortraits.Head(_art, order.Appearance, expression), new(79, 16, 72, 72));
        if (order.Lost) portrait.Modulate = new(.75f, .70f, .65f, .8f);
        Text(row, order.Customer, new(180, 5, 378, nameHeight), 28, wrap: true);
        float productBottom = BuildProducts(row, order.Products, 180, Math.Max(56, nameHeight + 13), 378, 23, 44);
        var color = order.Outcome switch { BookOutcome.Perfect => new Color("#91601D"), BookOutcome.Incorrect => new("#A05C2F"), BookOutcome.Lost or BookOutcome.Unreceived => new("#92534B"), _ => new("#456E49") };
        Art(row, order.Outcome switch { BookOutcome.Perfect => "Perfect 图标", BookOutcome.Incorrect => "状态章-错误完成", BookOutcome.Lost or BookOutcome.Unreceived => "状态章-顾客流失", _ => "状态章-正确完成" }, new(ArtRowRight, 3, 68, 68));
        string status = order.Outcome switch { BookOutcome.Perfect => "完美出餐", BookOutcome.Incorrect => "出餐错误", BookOutcome.Lost => "等待离开", BookOutcome.Unreceived => "收摊未接待", _ => "顺利完成" };
        Text(row, status, new(ArtRowRight + 82, 5, 458, 39), 29, color);
        float rightBottom = BuildOrderMetrics(row, order, ArtRowRight + 82, 56, 450, 25, color);
        var metrics = row.GetNode<Control>("OrderMetrics");
        var metricsPaper = new Control { MouseFilter = MouseFilterEnum.Ignore };
        Place(row, metricsPaper, new(metrics.Position - new Vector2(12, 7), metrics.Size + new Vector2(24, 14)));
        row.MoveChild(metricsPaper, 0);
        TravelPanel(metricsPaper, new(Vector2.Zero, metricsPaper.Size), true);
        row.CustomMinimumSize = new(ArtRowWidth, Math.Max(130, Math.Max(productBottom, rightBottom + 7) + 23));
        BookDivider(row, new(0, row.CustomMinimumSize.Y - 10, ArtPageWidth, 10));
        BookDivider(row, new(ArtRowRight, row.CustomMinimumSize.Y - 10, 540, 10));
    }
}
