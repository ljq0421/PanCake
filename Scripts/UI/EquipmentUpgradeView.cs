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
    private bool _submitted;
    public string SelectedId { get; private set; } = "";
    public IEnumerable<Button> Buttons => _cards.Concat(_detail.GetChildren().OfType<Button>());

    public void Configure(CityEquipmentView[] items, string? selected, Action<string> selection, Action<CityEquipmentView> purchase)
    {
        Size = new(1260, 620); MouseFilter = MouseFilterEnum.Ignore;
        _items = items; _purchase = purchase; _selection = selection;
        LabelAt(this, "EquipmentListTitle", "设备一览", new(0, 0, 280, 62), 43);
        LabelAt(this, "EquipmentListHint", "好的设备，是美味的开始！", new(275, 12, 300, 45), 22, Muted);
        for (int i = 0; i < items.Length; i++)
        {
            var item = items[i];
            var card = MakeButton(this, "Select_" + item.Id, "", new(0, 84 + i * 180, 565, 167));
            _cards.Add(card);
            foreach (string stateName in new[] { "normal", "hover", "pressed", "disabled" })
                card.AddThemeStyleboxOverride(stateName, new StyleBoxEmpty());
            var background = PaintedBackground(card, "设备卡片底板-普通-v1.png");
            _cardArt.Add(background);
            card.MouseEntered += () => background.SelfModulate = new Color(1.03f, 1.03f, 1.03f);
            card.MouseExited += () => background.SelfModulate = Colors.White;
            card.ButtonDown += () => background.SelfModulate = new Color(.95f, .95f, .95f);
            card.ButtonUp += () => background.SelfModulate = Colors.White;
            var focusBorder = Box(Colors.Transparent, Gold, 2);
            card.AddThemeStyleboxOverride("focus", focusBorder);
            if (item.Art is not null) Picture(card, item.Art, new(18, 15, 263, 135));
            else LabelAt(card, "EquipmentWordmark", item.Name, new(24, 25, 240, 130), 34, Muted, true);
            var equipmentName = LabelAt(card, "EquipmentName", item.Name, new(306, 17, 240, 48), 32);
            if (ProjectCake.Core.ExperienceProfile.IsDemo)
            {
                int size = 32;
                while (size > 24 && equipmentName.GetThemeFont("font").GetStringSize(equipmentName.Tr(item.Name), fontSize: size).X > 240) size--;
                equipmentName.AddThemeFontSizeOverride("font_size", size);
            }
            LabelAt(card, "EquipmentLevel", item.Level > 0 ? $"Lv{item.Level}" : "未开放", new(308, 65, 225, 36), 26);
            string state = item.CanBuy ? "可升级" : item.Level >= 3 ? "已满级" : item.Level == 0 ? "未开放"
                : item.Notice.Contains("金币不足") ? "金币不足" : item.Notice.StartsWith("完成第") ? "待解锁" : item.Notice;
            var chip = new Panel { Position = new(303, 103), Size = new(240, 52), MouseFilter = MouseFilterEnum.Ignore };
            chip.AddThemeStyleboxOverride("panel", Box(new(item.CanBuy ? "#FFDA75" : "#EDDFCD"), new("#DCBE96"), 1)); card.AddChild(chip);
            LabelAt(chip, "EquipmentState", state, new(10, 3, 220, 46), state.Length > 11 ? 16 : 22, item.CanBuy ? Ink : Muted, true);
            card.Pressed += () => { if (!_submitted && card.IsVisibleInTree()) Select(item.Id, true); };
        }
        _detail = new Control { Name = "EquipmentDetail", Position = new(700, 0), Size = new(560, 620), MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_detail);
        if (items.Length == 0) { LabelAt(this, "EmptyEquipment", "暂无设备", new(0, 120, 560, 100), 30); return; }
        Select(items.Any(i => i.Id == selected) ? selected! : items[0].Id, false);
    }

    private void Select(string id, bool focus)
    {
        SelectedId = id; _selection(id);
        foreach (var child in _detail.GetChildren()) { _detail.RemoveChild(child); child.QueueFree(); }
        for (int i = 0; i < _cards.Count; i++)
        {
            bool active = _items[i].Id == id;
            _cardArt[i].Texture = GD.Load<Texture2D>(ArtRoot + (active ? "设备卡片底板-选中-v1.png" : "设备卡片底板-普通-v1.png"));
            if (active && focus) _cards[i].GrabFocus();
        }
        var e = _items.Single(i => i.Id == id);
        LabelAt(_detail, "SelectedEquipmentName", e.Name, new(0, 0, 560, 60), 42);
        LabelAt(_detail, "LevelTransition", e.TargetLevel is int next ? $"Lv{e.Level}  →  Lv{next}" : e.Level == 0 ? "设备尚未开放" : $"Lv{e.Level} · {(e.Level >= 3 || e.Notice == "已升至最高等级" ? "已满级" : "固定设备")}", new(0, 62, 560, 44), 27, Muted);
        if (e.Art is not null) Picture(_detail, e.Art, new(0, 140, 270, 280));
        else LabelAt(_detail, "EquipmentWordmark", e.Name, new(0, 170, 266, 260), 40, Muted, true);
        var scroll = new ScrollContainer { Name = "UpgradeScroll", Position = new(282, 90), Size = new(278, 360), HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        _detail.AddChild(scroll);
        var rows = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; rows.AddThemeConstantOverride("separation", 14); scroll.AddChild(rows);
        EffectPanel(rows, e.Level == 0 ? "开放后 Lv1" : $"当前等级  Lv{e.Level}", e, false);
        if (e.TargetLevel is int target) EffectPanel(rows, $"升级后  Lv{target}", e, true);
        LabelAt(_detail, "UpgradePrice", e.TargetLevel is not null ? $"{e.Price} 金币" : e.Level >= 3 ? "当前可用的最好设备" : e.Notice, new(0, 460, 560, 48), 26, Ink, true);
        var buy = MakeButton(_detail, "UpgradeEquipment", "升级设备", new(45, 510, 470, 68));
        buy.Disabled = !e.CanBuy; buy.AddThemeFontSizeOverride("font_size", 34);
        buy.AddThemeStyleboxOverride("normal", Box(new("#FFD36B"), new("#9A602B"), 3));
        buy.Pressed += () => { if (_submitted || buy.Disabled || !buy.IsVisibleInTree()) return; _submitted = true; buy.Disabled = true; _purchase(e); };
        LabelAt(_detail, "UpgradeNotice", e.CanBuy ? "升级后，下次营业生效" : e.Notice, new(0, 584, 560, 29), 20, Muted, true);
    }

    private static void EffectPanel(VBoxContainer rows, string title, CityEquipmentView equipment, bool next)
    {
        var panel = new PanelContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill, CustomMinimumSize = new(0, 180) };
        panel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty()); rows.AddChild(panel);
        PaintedBackground(panel, next ? "升级后效果面板底板-v1.png" : "当前效果面板底板-v1.png", 80);
        var margins = new MarginContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; panel.AddChild(margins);
        margins.AddThemeConstantOverride("margin_left", 16); margins.AddThemeConstantOverride("margin_right", 16);
        margins.AddThemeConstantOverride("margin_bottom", 16);
        var content = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; content.AddThemeConstantOverride("separation", 8); margins.AddChild(content);
        var heading = FlowLabel(content, title, 25, next ? Green : Ink);
        heading.CustomMinimumSize = new(0, 40); heading.VerticalAlignment = VerticalAlignment.Center;
        foreach (var effect in equipment.Effects)
        {
            var label = FlowLabel(content, effect.Name + "：" + (next ? effect.Next : effect.Current), 21, next && effect.Changed ? Green : Ink);
            label.Name = (next ? "Next_" : "Current_") + content.GetChildCount();
        }
    }

    private static NinePatchRect PaintedBackground(Control parent, string filename, int top = 32)
    {
        // A wrapper keeps Container layout from resetting the 2x sprite's half scale.
        var wrapper = new Control { Name = "PaintedBackground", MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(wrapper); wrapper.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var art = new NinePatchRect { Name = "Backing", Texture = GD.Load<Texture2D>(ArtRoot + filename),
            Scale = Vector2.One * .5f, MouseFilter = MouseFilterEnum.Ignore,
            PatchMarginLeft = 32, PatchMarginTop = top, PatchMarginRight = 32, PatchMarginBottom = 32 };
        wrapper.AddChild(art);
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
        return button;
    }
}
