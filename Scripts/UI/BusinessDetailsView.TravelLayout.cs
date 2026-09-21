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
        // Keep the end-of-day spread intentionally sparse: service reflection lives on
        // the left page, while results and the two next-step actions live on the right.
        _metrics = new Control { MouseFilter = MouseFilterEnum.Ignore };
        _summary.AddChild(_metrics);
        BuildTravelReception();
        BuildTravelSatisfaction();
        BuildTravelNote();

        TravelPanel(_summary, new(890, 0, 560, 166));
        TravelHeading(_summary, "今日收入", new(905, -18, 245, 51));
        CaptureTravelMotion(TravelMotionGroup.Income, _summary, () =>
        {
            Art(_summary, "总收入图标", new(920, 56, 92, 84));
            _income = TravelValue(_summary, $"¥{r.TotalRevenue}", new(1030, 50, 380, 94), 78);
        });

        TravelPanel(_summary, new(890, 194, 560, 166));
        TravelHeading(_summary, "挑战结果", new(905, 176, 245, 51));
        CaptureTravelMotion(TravelMotionGroup.Challenge, _summary, () =>
        {
            string result = _model.Challenge is null ? "今日暂无挑战" : _model.ChallengeCaption;
            var challenge = Text(_summary, result, new(925, 245, 490, 78), 24, wrap: true);
            challenge.Name = "ChallengeSettlement";
        });

        AddTravelUpgradeButton();
    }

    private static void Explain(Control control, string text)
    {
        control.MouseFilter = MouseFilterEnum.Pass;
        control.TooltipText = text;
    }

    private void BuildTravelReception()
    {
        TravelPanel(_metrics, new(230, 25, 560, 145));
        var heading = TravelHeading(_metrics, "今日接待", new(245, 7, 233, 51));
        Explain(heading, "显示本次营业已结束的客单数：完成 + 流失。营业中尚在等待的顾客暂不计入。" );
        CaptureTravelMotion(TravelMotionGroup.Reception, _metrics, () =>
        {
            TravelValue(_metrics, $"{_model.Resolved} {_model.Unit}", new(255, 77, 480, 62), 56, HorizontalAlignment.Center);
        });
    }

    private void BuildTravelSatisfaction()
    {
        TravelPanel(_metrics, new(230, 214, 560, 130));
        var heading = TravelHeading(_metrics, "顾客满意度", new(245, 196, 266, 47));
        heading.Name = "BookSatisfaction";
        Explain(heading, "只计算已完成订单的顾客，包含出餐错误的订单；流失顾客不计入平均值。没有完成订单时显示 —。");
        CaptureTravelMotion(TravelMotionGroup.Evaluation, _metrics, () =>
        {
            Art(_metrics, "满意度图标", new(258, 260, 58, 58));
            Text(_metrics, Percent(_model.Satisfaction), new(340, 251, 330, 72), 56);
        });
    }

    private void BuildTravelNote()
    {
        CaptureTravelMotion(TravelMotionGroup.Note, _summary, () =>
        {
            _note = new Control { Name = "DailyNote", Position = new(230, 373), Size = new(560, 142), MouseFilter = MouseFilterEnum.Ignore };
            _summary.AddChild(_note);
            var paper = Art(_note, "今日手记便签底板", new(0, 0, 560, 142));
            paper.StretchMode = TextureRect.StretchModeEnum.Scale;
            Text(_note, "营业手记", new(64, 18, 430, 34), 26);
            Text(_note, _model.DailyNote, new(34, 57, 488, 68), 21, wrap: true);
        });
    }

    private void AddTravelUpgradeButton()
    {
        _upgradeEntry = ButtonAt(_summary, "店铺升级", new(900, 470, 235, 64), OpenUpgrades);
        _upgradeEntry.Name = "OpenBookUpgrades";
        _upgradeEntry.Disabled = !CanUpgrade;
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
