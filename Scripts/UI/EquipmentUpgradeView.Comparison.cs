using Godot;

namespace ProjectCake.UI;

public partial class EquipmentUpgradeView
{
    private Tween? _previewTween;
    private readonly List<(Control Node, Vector2 Origin, bool Lift, bool Flip)> _parts = new();
    private readonly List<(ColorRect Fill, double Seconds)> _meters = new();
    private static bool Reduced => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();

    private void BuildComparison(CityEquipmentView e)
    {
        var p = e.Presentation!; _parts.Clear(); _meters.Clear();
        LabelAt(_detail, "SelectedEquipmentName", e.Name, new(0, 0, 560, 48), 38);
        LabelAt(_detail, "LevelTransition", p.Fixed ? "常驻能力 · 已生效" : e.TargetLevel is int next ? $"Lv{e.Level}  →  Lv{next}" : e.Level == 0 ? "设备尚未开放" : $"Lv{e.Level} · 已满级", new(0, 47, 355, 35), 24, Muted);
        var paper = new Panel { Name = "BenefitPaper", Position = new(0, 83), Size = new(560, 44), MouseFilter = MouseFilterEnum.Ignore };
        paper.AddThemeStyleboxOverride("panel", Box(new("#FFE8A2"), new("#EDCE80"), 0)); _detail.AddChild(paper);
        LabelAt(paper, "UpgradeBenefit", p.Headline, new(12, 0, 536, 44), 28, Ink, true);
        bool comparison = e.TargetLevel.HasValue;
        AddComparisonSide(e, false, new(0, 136, comparison ? 255 : 560, 120));
        if (comparison)
        {
            var arrow = Sprite(_detail, "UpgradeComparisonArrow", "res://resource/art/Global/StartPage/箭头.png", new(261, 185, 36, 40));
            arrow.PivotOffset = arrow.Size / 2; arrow.Rotation = -Mathf.Pi / 2;
            AddComparisonSide(e, true, new(305, 136, 255, 120));
        }
        string changes = p.Fixed ? "生面随取随用，不消耗有限食材库存" : e.Level == 0 ? e.Notice
            : comparison ? string.Join(" · ", e.Effects.Where(v => v.Changed).Select(v => v.Name)) : "当前设备的全部能力已生效";
        LabelAt(_detail, "ChangedEffects", comparison ? "本次提升：" + changes : changes, new(0, 260, 560, 30), 18, Muted);
        BuildParameterTable(e);
        MoneyPlate(_detail, "UpgradePriceFrame", "UpgradePrice", comparison ? $"{e.Price} 金币" : p.Fixed ? "已生效 · 生面无限供应" : e.Level == 0 ? "随营业进度免费开放" : "当前可用的最好设备", new(0, 466, 560, 54), comparison, _cityId);
        LabelAt(_detail, "UpgradeNotice", p.Condition(e), new(0, 522, 560, 33), 20, Muted, true);
        bool continuation = _continueCaption is not null && _continueBusiness is not null;
        var buy = MakeButton(_detail, "UpgradeEquipment", comparison ? p.Action(e) : p.Fixed ? "已生效" : e.Level == 0 ? "尚未开放" : "已满级", new(0, 559, continuation ? 277 : 560, 60));
        buy.Disabled = !e.CanBuy; buy.AddThemeFontSizeOverride("font_size", comparison && !p.DayUnlocked ? 24 : 29); SkinPurchaseButton(buy, _cityId);
        buy.Pressed += () => { if (_submitted || buy.Disabled || !buy.IsVisibleInTree()) return; _submitted = true; buy.Disabled = true; _purchase(e); };
        if (continuation)
        {
            var button = MakeButton(_detail, "ContinueAfterUpgrade", _continueCaption!, new(291, 559, 269, 60));
            button.AddThemeFontSizeOverride("font_size", 24); SkinSecondaryButton(button);
            button.Pressed += () => { if (button.IsVisibleInTree()) _continueBusiness!(); };
        }
        if (comparison)
        {
            var changed = _detail.GetNode<Label>("ChangedEffects");
            changed.Size = new(560, 30); changed.AddThemeFontSizeOverride("font_size", 19);
            changed.Text = (e.Id, e.TargetLevel) switch
            {
                ("noodle_cooker", 3) => "新增双篮与自动提篮 · 煮面更快",
                ("noodle_cooker", _) => "新增熟度保护 · 仍需手动提篮",
                ("doupi_griddle", 3) => "新增自动翻面 · 两段煎制更快",
                ("doupi_griddle", _) => "新增恒温保护 · 不再煎焦",
                ("pancake_stove", 3) => "两面成熟更快 · 仍需手动翻面",
                ("pancake_stove", _) => "新增恒温保护 · 不再煎焦",
                ("fryer", 3) => "新增自动提篮 · 不再炸焦",
                ("fryer", _) => "每锅容量增加 · 更快炸至金黄",
                _ => "鸡蛋、薄脆、葱花与火腿容量增加",
            };
            ReplayPreview();
        }
    }

    private void AddComparisonSide(CityEquipmentView e, bool next, Rect2 rect)
    {
        var p = e.Presentation!;
        var side = new Button { Name = next ? "NextEquipment" : "CurrentEquipment", Position = rect.Position, Size = rect.Size,
            MouseDefaultCursorShape = CursorShape.PointingHand };
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            side.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        side.Pressed += ReplayPreview;
        _detail.AddChild(side);
        ButtonHoverFeedback.Attach(side);
        PaintedBackground(side, next ? "升级后效果面板底板-v1.png" : "当前效果面板底板-v1.png", 32, 32, next ? "" : _cityId, true);
        LabelAt(side, "Heading", p.Fixed ? "随取随用" : (next ? "升级后" : e.Level == 0 ? "开放后" : "当前") + $"  Lv{(next ? e.TargetLevel : Math.Max(1, e.Level))}", new(10, 2, rect.Size.X - 20, 29), 23, next ? Green : Ink, true);
        float scale = e.Id == "ingredient_station" && !p.Fixed ? .43f : .62f;
        float left = (rect.Size.X - 233 * scale) / 2;
        var illustration = new Control { Name = "WorkingPreview", Position = new(left, 31), Scale = Vector2.One * scale, Size = new(233, 125), MouseFilter = MouseFilterEnum.Ignore }; side.AddChild(illustration);
        ComposeEquipment(illustration, e, next);
        var duration = e.Effects.FirstOrDefault(v => v.Name is "最佳煮面时间" or "第一阶段煎制时间" or "第一面成熟时间" or "炸至金黄");
        if (duration is not null && double.TryParse((next ? duration.Next : duration.Current).Replace(" 秒", ""), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out double seconds))
        {
            var meter = new ColorRect { Name = "WorkPreviewProgress", Position = new(22, 112), Size = new(rect.Size.X - 44, 3), Color = new("#E9DDC6"), MouseFilter = MouseFilterEnum.Ignore };
            var fill = new ColorRect { Name = "Fill", Size = meter.Size, Color = next ? Green : Muted, MouseFilter = MouseFilterEnum.Ignore };
            side.AddChild(meter); meter.AddChild(fill); _meters.Add((fill, seconds));
        }
        if (e.Id == "ingredient_station" && !p.Fixed)
        {
            var stock = e.Effects.First(v => v.Name == "鸡蛋容量");
            string value = next ? stock.Next : stock.Current;
            LabelAt(side, "StockAmount", $"有限食材各备 {value}", new(12, 86, rect.Size.X - 24, 29), 20, next ? Green : Ink, true);
        }
    }

    private void ComposeEquipment(Control parent, CityEquipmentView e, bool next)
    {
        var p = e.Presentation!;
        string path = next ? p.NextArt : p.CurrentArt;
        if (path.Length > 0) Sprite(parent, "Body", path, new(9, 8, 215, 117));
        string Value(string key) { var effect = e.Effects.FirstOrDefault(v => v.Name == key); return (next ? effect?.Next : effect?.Current) ?? ""; }
        void Part(string name, string art, Rect2 rect, bool lift = false, bool flip = false, bool stretch = false)
        {
            var part = Sprite(parent, name, art, rect, stretch); part.PivotOffset = part.Size / 2;
            _parts.Add((part, part.Position, lift, flip));
        }
        if (e.Id == "noodle_cooker")
        {
            int count = Value("面篮数量").StartsWith("2") ? 2 : 1;
            for (int i = 0; i < count; i++)
            {
                var texture = TrimmedArt("res://resource/art/Wuhan/通用热干面漏勺_v2.png");
                var size = new Vector2(69, 69 * texture.GetHeight() / texture.GetWidth());
                // Place the basket mouths over the water, with both baskets inside the rim.
                var basket = new Control { Name = "Basket" + i, Position = new(count == 1 ? 91 : 64 + i * 52, 15), Size = size, MouseFilter = MouseFilterEnum.Ignore }; parent.AddChild(basket);
                Sprite(basket, "BasketArt", "res://resource/art/Wuhan/通用热干面漏勺_v2.png", new(Vector2.Zero, size));
                Sprite(basket, "Noodles", "res://resource/art/Wuhan/漏勺中的熟面状态.png", new(size * new Vector2(.10f, .48f), size * new Vector2(.50f, .37f)));
                _parts.Add((basket, basket.Position, Value("自动提篮") == "开启", false));
            }
            // Repaint the front of the fitted pot above the submerged basket bottoms.
            var body = parent.GetNode<TextureRect>("Body");
            Vector2 artSize = body.Texture.GetSize();
            Vector2 fitted = artSize * Math.Min(body.Size.X / artSize.X, body.Size.Y / artSize.Y);
            Vector2 origin = body.Position + (body.Size - fitted) / 2;
            const float front = .60f;
            var foreground = new TextureRect { Name = "CookerFront", Position = origin + new Vector2(0, fitted.Y * front),
                Size = new(fitted.X, fitted.Y * (1 - front)),
                Texture = new AtlasTexture { Atlas = body.Texture, Region = new(0, artSize.Y * front, artSize.X, artSize.Y * (1 - front)) },
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.Scale,
                TextureFilter = TextureFilterEnum.Linear, MouseFilter = MouseFilterEnum.Ignore };
            parent.AddChild(foreground);
        }
        else if (e.Id == "doupi_griddle")
        {
            // Keep the cut portions inside the cooking surface, including during replay.
            var surface = new Control { Name = "DoupiSurface", Position = new(50, 26), Size = new(132, 50),
                ClipContents = true, MouseFilter = MouseFilterEnum.Ignore };
            parent.AddChild(surface);
            var portions = new Control { Name = "Doupi", Size = surface.Size, PivotOffset = surface.Size / 2,
                MouseFilter = MouseFilterEnum.Ignore };
            surface.AddChild(portions);
            int count = int.Parse(Value("每锅产量").Split(' ')[0], System.Globalization.CultureInfo.InvariantCulture);
            int columns = (int)Math.Ceiling(count / 2f);
            float cellWidth = (surface.Size.X - 8) / columns;
            for (int i = 0; i < count; i++)
                Sprite(portions, "DoupiPiece" + i, $"res://resource/art/Wuhan/DoupiPieces_v1/piece-{i % 4 + 1:00}.png",
                    new(4 + i % columns * cellWidth, 2 + i / columns * 24, cellWidth - 1, 23));
            _parts.Add((portions, portions.Position, false, Value("翻面与切块").StartsWith("自动")));
            if (Value("翻面与切块").StartsWith("自动")) Sprite(parent, "FlipTool", "res://resource/art/Wuhan/Lv3豆皮锅自动翻面铲.png", new(156, 32, 66, 68));
        }
        else if (e.Id == "fryer")
        {
            // Fit the basket to the opening of the trimmed shop illustration.
            // Keep its contents in the same local space throughout the lift.
            var basket = new Control { Name = "FryingBasket", Position = new(54, 22), Size = new(125, 43), MouseFilter = MouseFilterEnum.Ignore };
            parent.AddChild(basket);
            Sprite(basket, "BasketArt", "res://resource/art/TianJin/Workbench/阶段工作台-升降滤篮-v4.png", new(Vector2.Zero, basket.Size), stretch: true);
            int count = Value("每锅容量").StartsWith("8") ? 8 : 6;
            for (int i = 0; i < count; i++) Sprite(basket, "Youtiao" + i, "res://resource/art/TianJin/熟油条.png", new(20 + i % 4 * 20, 10 + i / 4 * 12, 20, 22));
            _parts.Add((basket, basket.Position, Value("自动提篮") == "开启", false));
        }
        else if (e.Id == "pancake_stove")
            // Project the top-down pancake onto the stove's elliptical cooking surface.
            Part("Pancake", "res://resource/art/TianJin/展开煎饼基础层-v2.png", new(53, 18.5f, 126, 71), stretch: true);
    }

    private void ReplayPreview()
    {
        _previewTween?.Kill();
        foreach (var part in _parts) { part.Node.Position = part.Origin + (part.Lift ? new Vector2(0, -16) : Vector2.Zero); part.Node.Scale = Vector2.One; }
        foreach (var meter in _meters) meter.Fill.Scale = Vector2.One;
        if (Reduced || _parts.Count == 0) return;
        _previewTween = CreateTween();
        _previewTween.TweenMethod(Callable.From<float>(t =>
        {
            double clock = t * 1.5 * (_meters.Count == 0 ? 1 : _meters.Max(v => v.Seconds));
            foreach (var meter in _meters) meter.Fill.Scale = new((float)Math.Clamp(clock / Math.Max(.01, meter.Seconds), 0, 1), 1);
            foreach (var part in _parts)
            {
                float enter = Mathf.Clamp(t / .3f, 0, 1);
                float lift = part.Lift ? Mathf.Clamp((t - .58f) / .25f, 0, 1) : 0;
                part.Node.Position = part.Origin + new Vector2(0, -22 * (1 - enter) - 16 * lift);
                part.Node.Scale = new(1, part.Flip && t > .4f && t < .8f ? Math.Max(.12f, Mathf.Abs(Mathf.Cos((t - .4f) / .4f * Mathf.Pi))) : 1);
            }
        }), 0f, 1f, 2.6);
    }

    private void BuildParameterTable(CityEquipmentView e)
    {
        bool comparison = e.TargetLevel.HasValue;
        AddParameterRow(_detail, "ParameterHeading", "参数名称", e.Level == 0 ? "开放后" : "当前", comparison ? "升级后" : "", false, true)
            .Position = new(0, 294);
        var scroll = new ScrollContainer
        {
            Name = "UpgradeParameterScroll", Position = new(0, 328), Size = new(560, 132),
            HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled,
            VerticalScrollMode = ScrollContainer.ScrollMode.Auto, FocusMode = FocusModeEnum.All,
            MouseFilter = MouseFilterEnum.Stop,
        };
        _detail.AddChild(scroll);
        var rows = new VBoxContainer { Name = "ParameterRows", CustomMinimumSize = new(540, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        rows.AddThemeConstantOverride("separation", 0); scroll.AddChild(rows);
        for (int i = 0; i < e.Effects.Count; i++)
        {
            var effect = e.Effects[i];
            AddParameterRow(rows, "ParameterRow" + i, effect.Name, effect.Current, comparison ? effect.Next : "",
                comparison && effect.Changed, false);
        }
        scroll.GuiInput += input =>
        {
            if (input is not InputEventKey { Pressed: true } key) return;
            if (key.Keycode is not (Key.Up or Key.Down or Key.Pageup or Key.Pagedown or Key.Home or Key.End)) return;
            scroll.ScrollVertical = key.Keycode switch
            {
                Key.Home => 0, Key.End => (int)scroll.GetVScrollBar().MaxValue,
                Key.Up => scroll.ScrollVertical - 44, Key.Down => scroll.ScrollVertical + 44,
                Key.Pageup => scroll.ScrollVertical - 132, _ => scroll.ScrollVertical + 132,
            };
            scroll.AcceptEvent();
        };
    }

    private static PanelContainer AddParameterRow(Control parent, string name, string caption, string current, string next, bool changed, bool heading)
    {
        var row = new PanelContainer { Name = name, CustomMinimumSize = new(540, heading ? 32 : 44), MouseFilter = MouseFilterEnum.Pass };
        var style = Box(new(heading ? "#F1E3C6" : changed ? "#E8EFD9" : "#FFF5E3"), new("#DFCEAC"), 0);
        style.ContentMarginLeft = 8; style.ContentMarginRight = 0;
        style.ContentMarginTop = style.ContentMarginBottom = 0;
        style.CornerRadiusTopLeft = style.CornerRadiusTopRight = style.CornerRadiusBottomLeft = style.CornerRadiusBottomRight = 0;
        row.AddThemeStyleboxOverride("panel", style);
        parent.AddChild(row);
        var columns = new HBoxContainer { MouseFilter = MouseFilterEnum.Pass };
        columns.AddThemeConstantOverride("separation", 0); row.AddChild(columns);
        void Cell(string nodeName, string text, float width, bool centered, Color color)
        {
            var label = FlowLabel(columns, text, heading ? 20 : 21, color);
            label.Name = nodeName; label.CustomMinimumSize = new(width, heading ? 32 : 44);
            label.SizeFlagsHorizontal = SizeFlags.Fill;
            label.VerticalAlignment = VerticalAlignment.Center;
            label.HorizontalAlignment = centered ? HorizontalAlignment.Center : HorizontalAlignment.Left;
        }
        Cell("ParameterName", caption, 202, false, Ink);
        Cell("CurrentValue", current, 154, true, Muted);
        Cell("NextValue", next, 176, true, changed ? Green : Ink);
        return row;
    }

    private Tween? _successTween;

    internal void PlayPurchaseSuccess(string equipmentId, CityEquipmentView? previous = null)
    {
        var item = _items.FirstOrDefault(v => v.Id == equipmentId);
        if (item is null || SelectedId != equipmentId) return;
        _successTween?.Kill();
        var level = _detail.GetNode<Label>("LevelTransition");
        string originalText = level.Text;
        Vector2 originalSize = level.Size;
        int originalFontSize = level.GetThemeFontSize("font_size");
        bool installed = previous?.Level == 0;
        level.Text = installed ? $"已安装 Lv{item.Level} · 下次营业生效" : $"已升至 Lv{item.Level} · 下次营业生效";
        level.Size = new(418, originalSize.Y);
        level.AddThemeFontSizeOverride("font_size", 23);
        level.AddThemeColorOverride("font_color", Green);

        var stamp = new Panel
        {
            Name = "UpgradeSuccessPaper", Position = new(428, level.Position.Y + 1), Size = new(132, 33),
            MouseFilter = MouseFilterEnum.Ignore,
        };
        stamp.AddThemeStyleboxOverride("panel", Box(new("#E8EFD9"), new("#8FA16C"), 1));
        _detail.AddChild(stamp);
        var check = new Line2D { Width = 2.2f, DefaultColor = Green, Antialiased = true };
        check.Points = new[] { new Vector2(12, 17), new Vector2(17, 22), new Vector2(26, 11) };
        stamp.AddChild(check);
        LabelAt(stamp, "UpgradeSuccessStamp", installed ? "已购买" : "已升级", new(33, 0, 92, 33), 22, Green, true);

        // Compare with the purchased offer, never with the next available upgrade.
        var highlighted = new List<Label>();
        var benefit = _detail.GetNodeOrNull<Label>("BenefitPaper/UpgradeBenefit");
        string? originalBenefit = benefit?.Text;
        if (benefit is not null && previous?.Id == equipmentId && previous.Presentation is not null)
            benefit.Text = previous.Presentation.Headline;
        var changes = _detail.GetNodeOrNull<Label>("ChangedEffects");
        string? originalChanges = changes?.Text;
        if (changes is not null) changes.Text = "本次提升已标注在下方「当前」参数中";
        if (previous?.Id == equipmentId)
        {
            for (int i = 0; i < item.Effects.Count; i++)
            {
                var effect = item.Effects[i];
                var old = previous.Effects.FirstOrDefault(e => e.Name == effect.Name);
                if (old is null || old.Current == effect.Current) continue;
                var row = _detail.GetNodeOrNull<Control>($"UpgradeParameterScroll/ParameterRows/ParameterRow{i}");
                var value = row?.Descendants<Label>().FirstOrDefault(l => l.Name == "CurrentValue");
                if (value is null) continue;
                value.AddThemeColorOverride("font_color", Green);
                highlighted.Add(value);
            }
        }
        var current = _detail.GetNodeOrNull<Control>("CurrentEquipment");
        var tween = _successTween = CreateTween();
        if (!Reduced)
        {
            stamp.Position -= new Vector2(0, 5);
            tween.TweenProperty(stamp, "position:y", level.Position.Y + 1, .2).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
            if (current is not null)
            {
                current.Modulate = new Color(1.07f, 1.07f, 1.02f);
                tween.Parallel().TweenProperty(current, "modulate", Colors.White, .6);
            }
        }
        tween.TweenInterval(1.5);
        if (!Reduced) tween.TweenProperty(stamp, "modulate:a", 0f, .25);
        tween.TweenCallback(Callable.From(() =>
        {
            stamp.QueueFree();
            level.Text = originalText; level.Size = originalSize;
            level.AddThemeFontSizeOverride("font_size", originalFontSize);
            level.AddThemeColorOverride("font_color", Muted);
            if (benefit is not null && originalBenefit is not null) benefit.Text = originalBenefit;
            if (changes is not null && originalChanges is not null) changes.Text = originalChanges;
            foreach (var value in highlighted) value.AddThemeColorOverride("font_color", Muted);
        }));
    }
}
