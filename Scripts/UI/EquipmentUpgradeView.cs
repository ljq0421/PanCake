using Godot;

namespace ProjectCake.UI;

/// <summary>Shared book interior: selection never buys; only the fixed detail action submits.</summary>
public partial class EquipmentUpgradeView : Control
{
    private static readonly Color Ink = new("#442818"), Muted = new("#805B3D"), Gold = new("#EDA52B"), Green = new("#276631");
    private CityEquipmentView[] _items = Array.Empty<CityEquipmentView>();
    private readonly List<Button> _cards = new();
    private readonly List<NinePatchRect> _cardArt = new();
    private const string ArtRoot = "res://resource/art/Global/UpgradeUI/";
    private Control _detail = null!;
    private Action<CityEquipmentView> _purchase = null!;
    private Action<string> _selection = null!;
    private string? _continueCaption;
    private Action? _continueBusiness;
    private string _cityId = "";
    private bool _submitted;
    public string SelectedId { get; private set; } = "";
    public IEnumerable<Button> Buttons => _cards.Concat(_detail.GetChildren().OfType<Button>());

    public void Configure(CityEquipmentView[] items, string? selected, string cityId, Action<string> selection, Action<CityEquipmentView> purchase,
        string? continueCaption = null, Action? continueBusiness = null)
    {
        Size = new(1260, 620); MouseFilter = MouseFilterEnum.Ignore;
        _items = items; _purchase = purchase; _selection = selection; _cityId = cityId;
        _continueCaption = continueCaption; _continueBusiness = continueBusiness;
        LabelAt(this, "EquipmentListTitle", "设备一览", new(0, 0, 280, 62), 43);
        LabelAt(this, "EquipmentListHint", "好的设备，是美味的开始！", new(275, 12, 300, 45), 22, Muted);
        for (int i = 0; i < items.Length; i++)
        {
            var item = items[i];
            var card = MakeButton(this, "Select_" + item.Id, "", new(0, 84 + i * 180, 565, 167));
            _cards.Add(card);
            foreach (string stateName in new[] { "normal", "hover", "pressed", "disabled" })
                card.AddThemeStyleboxOverride(stateName, new StyleBoxEmpty());
            var background = PaintedBackground(card, "设备卡片底板-普通-v2.png", 110, 110, _cityId, true);
            _cardArt.Add(background);
            card.MouseEntered += () => background.SelfModulate = new Color(1.03f, 1.03f, 1.03f);
            card.MouseExited += () => background.SelfModulate = Colors.White;
            card.ButtonDown += () => background.SelfModulate = new Color(.95f, .95f, .95f);
            card.ButtonUp += () => background.SelfModulate = Colors.White;
            var focusBorder = Box(Colors.Transparent, Gold, 2);
            card.AddThemeStyleboxOverride("focus", focusBorder);
            if (item.Art == "res://resource/art/TianJin/升级小料.png")
                Sprite(card, "EquipmentPicture", item.Art, new(18, 20, 263, 127));
            else if (item.Art is not null) Picture(card, item.Art, new(18, 15, 263, 135));
            else LabelAt(card, "EquipmentWordmark", item.Name, new(24, 25, 240, 130), 34, Muted, true);
            var equipmentName = LabelAt(card, "EquipmentName", item.Name, new(306, 17, 240, 48), 32);
            {
                int size = 32;
                while (size > 24 && equipmentName.GetThemeFont("font").GetStringSize(equipmentName.Tr(item.Name), fontSize: size).X > 240) size--;
                equipmentName.AddThemeFontSizeOverride("font_size", size);
            }
            LabelAt(card, "EquipmentLevel", item.Presentation?.Fixed == true ? "生面无限供应" : item.Level > 0 ? $"Lv{item.Level}" : "未开放", new(308, 65, 225, 36), 26);
            string state = item.CanBuy ? "可升级" : item.Level >= 3 ? "已满级" : item.Level == 0 ? "未开放"
                : item.Notice.Contains("金币不足") ? "金币不足" : item.Notice.StartsWith("完成第") ? "待解锁" : item.Notice;
            state = item.Presentation?.State(item) ?? state;
            var chip = new Panel { Position = new(303, 103), Size = new(214, 52), MouseFilter = MouseFilterEnum.Ignore };
            chip.AddThemeStyleboxOverride("panel", item.CanBuy ? new StyleBoxEmpty() : Box(new("#EDDFCD"), new("#C8A681"), 2)); card.AddChild(chip);
            if (item.CanBuy)
            {
                var chipArt = Sprite(chip, "UpgradeChipArt", "res://resource/art/Global/BookUI/可升级提示贴片.png", new(0, 0, 214, 52), true);
                CityPageArtSkin.Apply(chipArt, _cityId);
            }
            LabelAt(chip, "EquipmentState", state, new(10, 3, item.CanBuy ? 148 : 194, 46), state.Length > 11 ? 16 : 22, item.CanBuy ? Ink : Muted, true);
            card.Pressed += () => { if (!_submitted && card.IsVisibleInTree()) Select(item.Id, true); };
        }
        _detail = new Control { Name = "EquipmentDetail", Position = new(700, 0), Size = new(560, 620), MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_detail);
        if (items.Length == 0) { LabelAt(this, "EmptyEquipment", "暂无设备", new(0, 120, 560, 100), 30); return; }
        Select(items.Any(i => i.Id == selected) ? selected! : items[0].Id, false);
    }

    private void Select(string id, bool focus)
    {
        _successTween?.Kill();
        _previewTween?.Kill();
        SelectedId = id; _selection(id);
        foreach (var child in _detail.GetChildren()) { _detail.RemoveChild(child); child.QueueFree(); }
        for (int i = 0; i < _cards.Count; i++)
        {
            bool active = _items[i].Id == id;
            _cardArt[i].Texture = GD.Load<Texture2D>(ArtRoot + (active ? "设备卡片底板-选中-v2.png" : "设备卡片底板-普通-v2.png"));
            if (active && focus) _cards[i].GrabFocus();
        }
        var e = _items.Single(i => i.Id == id);
        if (e.Presentation is not null) { BuildComparison(e); return; }
        LabelAt(_detail, "SelectedEquipmentName", e.Name, new(0, 0, 560, 60), 42);
        bool hasBenefit = _cityId is "city:tianjin" or "city:wuhan" && e.TargetLevel.HasValue && e.Level > 0;
        if (hasBenefit)
        {
            var benefit = LabelAt(_detail, "UpgradeBenefit", BookUpgradeSource.Benefit(new(_cityId, e.PurchaseId, e.Id, e.Name, e.Level, e.TargetLevel!.Value, e.Price)), new(0, 108, 255, 80), 18, Muted);
            benefit.ZIndex = 1; benefit.ClipText = true;
        }
        LabelAt(_detail, "LevelTransition", e.TargetLevel is int next ? $"Lv{e.Level}  →  Lv{next}" : e.Level == 0 ? "设备尚未开放" : $"Lv{e.Level} · {(e.Level >= 3 || e.Notice == "已升至最高等级" ? "已满级" : "固定设备")}", new(0, 62, 560, 44), 27, Muted);
        var doodle = Sprite(_detail, "EquipmentDoodle", ArtRoot + "设备涂鸦背景-v1.png", new(0, 138, 274, 292));
        CityPageArtSkin.Apply(doodle, _cityId, true);
        if (e.Art is not null) Picture(_detail, e.Art, new(0, hasBenefit ? 198 : 140, 270, hasBenefit ? 222 : 280));
        else LabelAt(_detail, "EquipmentWordmark", e.Name, new(0, 170, 266, 260), 40, Muted, true);
        // The comparison viewport shares the equipment image's vertical centre (y = 280).
        // Short comparisons centre as a group; longer ones retain scrolling above the price.
        var scroll = new ScrollContainer { Name = "UpgradeScroll", Position = new(282, 115), Size = new(278, 330), HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        _detail.AddChild(scroll);
        var alignment = new MarginContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill };
        scroll.AddChild(alignment);
        var rows = new VBoxContainer { Name = "UpgradeComparison", SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ShrinkCenter };
        rows.AddThemeConstantOverride("separation", 12); alignment.AddChild(rows);
        EffectPanel(rows, e.Level == 0 ? "开放后 Lv1" : $"当前等级  Lv{e.Level}", e, false, _cityId);
        if (e.TargetLevel is int target)
        {
            var arrow = Sprite(rows, "UpgradeComparisonArrow", "res://resource/art/Global/StartPage/箭头.png", new(0, 0, 36, 36));
            arrow.CustomMinimumSize = new(36, 36);
            arrow.SizeFlagsHorizontal = SizeFlags.ShrinkCenter;
            EffectPanel(rows, $"升级后  Lv{target}", e, true, _cityId);
        }
        MoneyPlate(_detail, "UpgradePriceFrame", "UpgradePrice", e.TargetLevel is not null ? $"{e.Price} 金币" : e.Level >= 3 ? "当前可用的最好设备" : e.Notice,
            new(30, 449, 500, 62), e.TargetLevel is not null, _cityId);
        bool showContinue = _continueCaption is not null && _continueBusiness is not null;
        var buy = MakeButton(_detail, "UpgradeEquipment", "升级设备", new(45, 519, showContinue ? 235 : 470, 72));
        buy.Disabled = !e.CanBuy; buy.AddThemeFontSizeOverride("font_size", 34);
        SkinPurchaseButton(buy, _cityId);
        buy.Pressed += () => { if (_submitted || buy.Disabled || !buy.IsVisibleInTree()) return; _submitted = true; buy.Disabled = true; _purchase(e); };
        if (showContinue)
        {
            var continueButton = MakeButton(_detail, "ContinueAfterUpgrade", _continueCaption!, new(280, 519, 235, 72));
            continueButton.AddThemeFontSizeOverride("font_size", 25);
            SkinSecondaryButton(continueButton);
            continueButton.Pressed += () => { if (continueButton.IsVisibleInTree()) _continueBusiness!(); };
        }
        if (!e.CanBuy)
            LabelAt(_detail, "UpgradeNotice", e.Notice, new(0, 591, 560, 29), 20, Muted, true);
    }

    private static void EffectPanel(VBoxContainer rows, string title, CityEquipmentView equipment, bool next, string cityId)
    {
        var panel = new PanelContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ShrinkBegin };
        panel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty()); rows.AddChild(panel);
        PaintedBackground(panel, next ? "升级后效果面板底板-v1.png" : "当前效果面板底板-v1.png", top: 80, cityId: cityId, recolorPaper: true);
        var margins = new MarginContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; panel.AddChild(margins);
        margins.AddThemeConstantOverride("margin_left", 12); margins.AddThemeConstantOverride("margin_right", 12);
        margins.AddThemeConstantOverride("margin_bottom", 8);
        var content = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; content.AddThemeConstantOverride("separation", 4); margins.AddChild(content);
        var heading = FlowLabel(content, title, 25, next ? Green : Ink);
        heading.CustomMinimumSize = new(0, 40); heading.VerticalAlignment = VerticalAlignment.Center;
        foreach (var effect in equipment.Effects)
        {
            var label = FlowLabel(content, effect.Name + "：" + (next ? effect.Next : effect.Current), 21, next && effect.Changed ? Green : Ink);
            label.Name = (next ? "Next_" : "Current_") + content.GetChildCount();
        }
    }

    private static NinePatchRect PaintedBackground(Control parent, string filename, int top = 32, int edge = 32, string cityId = "", bool recolorPaper = false)
    {
        // A wrapper keeps Container layout from resetting the 2x sprite's half scale.
        var wrapper = new Control { Name = "PaintedBackground", MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(wrapper); wrapper.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var art = new NinePatchRect { Name = "Backing", Texture = GD.Load<Texture2D>(ArtRoot + filename),
            TextureFilter = TextureFilterEnum.Linear,
            Scale = Vector2.One * .5f, MouseFilter = MouseFilterEnum.Ignore,
            PatchMarginLeft = edge, PatchMarginTop = top, PatchMarginRight = edge, PatchMarginBottom = edge };
        wrapper.AddChild(art);
        CityPageArtSkin.Apply(art, cityId, recolorPaper);
        void Fit() => art.Size = wrapper.Size * 2;
        wrapper.Resized += Fit; Fit();
        return art;
    }

    private static Label FlowLabel(Control parent, string text, int size, Color color)
    {
        var label = new Label { Text = text, AutowrapMode = TextServer.AutowrapMode.WordSmart, SizeFlagsHorizontal = SizeFlags.ExpandFill, MouseFilter = MouseFilterEnum.Ignore };
        label.AddThemeFontSizeOverride("font_size", size); label.AddThemeColorOverride("font_color", color); parent.AddChild(label); return label;
    }
    private static Label LabelAt(Control parent, string name, string text, Rect2 rect, int size, Color? color = null, bool centered = false)
    {
        var label = new Label { Name = name, Text = text, Position = rect.Position, Size = rect.Size,
            AutowrapMode = TextServer.AutowrapMode.WordSmart, MouseFilter = MouseFilterEnum.Ignore,
            VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = centered ? HorizontalAlignment.Center : HorizontalAlignment.Left };
        label.AddThemeFontSizeOverride("font_size", size); label.AddThemeColorOverride("font_color", color ?? Ink); parent.AddChild(label); return label;
    }
    private static void Picture(Control parent, string path, Rect2 rect)
    {
        var art = new TextureRect { Position = rect.Position, Size = rect.Size, Texture = GD.Load<Texture2D>(path), ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, MouseFilter = MouseFilterEnum.Ignore }; parent.AddChild(art);
    }
    private static StyleBoxFlat Box(Color fill, Color border, int width)
    {
        var box = StartScreenTheme.Box(fill, width); box.BorderColor = border;
        box.ContentMarginLeft = box.ContentMarginRight = 16; box.ContentMarginTop = box.ContentMarginBottom = 12; return box;
    }
    private static Button MakeButton(Control parent, string name, string text, Rect2 rect)
    {
        var button = new Button { Name = name, Text = text, Position = rect.Position, Size = rect.Size, MouseDefaultCursorShape = CursorShape.PointingHand }; parent.AddChild(button);
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" }) button.AddThemeStyleboxOverride(state, Box(new(state == "disabled" ? "#E6D7C4" : state == "pressed" ? "#FFE09B" : "#FFF4D7"), Gold, 2));
        var focus = Box(Colors.Transparent, Ink, 3); button.AddThemeStyleboxOverride("focus", focus);
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color" }) button.AddThemeColorOverride(state, Ink);
        ButtonHoverFeedback.Attach(button);
        return button;
    }
}
