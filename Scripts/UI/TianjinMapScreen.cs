using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class TianjinMapScreen : Control
{
    public event Action? HubRequested;

    private SaveService _save = null!;
    private PanelContainer _tianjinCard = null!;
    private Label _tianjinState = null!;
    private PanelContainer _wuhanCard = null!;
    private Label _wuhanState = null!;
    private bool _lightUpPlayed;

    public override void _Ready() => Build();

    public void Initialize(SaveService save)
    {
        if (_save is not null) _save.Changed -= Render;
        _save = save;
        _save.Changed += Render;
        Render();
    }

    public override void _ExitTree()
    {
        if (_save is not null) _save.Changed -= Render;
    }

    public override void _Process(double delta)
    {
        if (_lightUpPlayed || _save is null || !_save.Data.TianjinCompleted || !IsVisibleInTree()) return;
        _lightUpPlayed = true;
        _tianjinCard.PivotOffset = _tianjinCard.Size * .5f;
        _tianjinCard.Scale = new Vector2(.92f, .92f);
        _tianjinCard.Modulate = new Color(1.35f, 1.15f, .75f, .25f);
        Tween tween = CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(_tianjinCard, "scale", Vector2.One, .65);
        tween.TweenProperty(_tianjinCard, "modulate", Colors.White, .8);
    }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var background = new ColorRect { Color = new Color("#17120F"), MouseFilter = MouseFilterEnum.Ignore };
        background.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        AddChild(background);

        var dawn = new ColorRect { Color = new Color("#7A4935"), MouseFilter = MouseFilterEnum.Ignore };
        dawn.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        dawn.OffsetTop = 500;
        AddChild(dawn);

        var margin = new MarginContainer();
        margin.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        margin.OffsetLeft = 150; margin.OffsetTop = 80; margin.OffsetRight = -150; margin.OffsetBottom = -80;
        AddChild(margin);

        var root = new VBoxContainer(); root.AddThemeConstantOverride("separation", 28); margin.AddChild(root);
        var header = new HBoxContainer(); root.AddChild(header);
        var titles = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; header.AddChild(titles);
        titles.AddChild(Text("早餐地图", 46, "#FFD596"));
        titles.AddChild(Text("从天津的清晨，走向下一座城市", 22, "#CBB5A0"));
        var back = new Button { Text = "返回营业大厅", CustomMinimumSize = new Vector2(190, 54) };
        back.Pressed += () => HubRequested?.Invoke(); header.AddChild(back);

        var route = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center, SizeFlagsVertical = SizeFlags.ExpandFill };
        route.AddThemeConstantOverride("separation", 45); root.AddChild(route);
        _tianjinCard = CityCard("天津", "煎饼果子 · 油条 · 豆浆", out _tianjinState); route.AddChild(_tianjinCard);
        var arrow = Text("→", 56, "#B47B53"); arrow.VerticalAlignment = VerticalAlignment.Center; route.AddChild(arrow);
        _wuhanCard = CityCard("武汉", "下一章", out _wuhanState); route.AddChild(_wuhanCard);
        root.AddChild(Text("天津达到一星后点亮，并开放武汉占位入口。武汉玩法将在后续章节制作。", 19, "#BDAA96"));
    }

    private void Render()
    {
        if (_save is null) return;
        int stars = _save.Data.TianjinBestStars;
        bool complete = _save.Data.TianjinCompleted;
        _tianjinState.Text = complete ? $"已点亮  {new string('★', stars)}{new string('☆', 3 - stars)}\n最高星级：{stars}" : "尚未点亮\n完成 Day 15 并至少获得一星";
        SetCardColor(_tianjinCard, complete ? "#684224" : "#332720", complete ? "#F4B85E" : "#806C5C");

        bool wuhan = _save.Data.UnlockedCityIds.Contains("city:wuhan", StringComparer.Ordinal);
        _wuhanState.Text = wuhan ? "已开放\n敬请期待" : "未开放\n先点亮天津";
        SetCardColor(_wuhanCard, wuhan ? "#3E4C42" : "#27231F", wuhan ? "#8EC7A2" : "#5E554E");
    }

    private static PanelContainer CityCard(string city, string subtitle, out Label state)
    {
        var card = new PanelContainer { CustomMinimumSize = new Vector2(520, 410) };
        var box = new VBoxContainer { Alignment = BoxContainer.AlignmentMode.Center };
        box.AddThemeConstantOverride("separation", 20); card.AddChild(box);
        var emblem = Text(city[..1], 92, "#FFE0A9"); emblem.HorizontalAlignment = HorizontalAlignment.Center; box.AddChild(emblem);
        var name = Text(city, 38, "#FFF0D7"); name.HorizontalAlignment = HorizontalAlignment.Center; box.AddChild(name);
        var sub = Text(subtitle, 20, "#CDB8A3"); sub.HorizontalAlignment = HorizontalAlignment.Center; box.AddChild(sub);
        state = Text(string.Empty, 22, "#FFE0A9"); state.HorizontalAlignment = HorizontalAlignment.Center; box.AddChild(state);
        return card;
    }

    private static void SetCardColor(PanelContainer card, string background, string border)
    {
        card.AddThemeStyleboxOverride("panel", new StyleBoxFlat
        {
            BgColor = new Color(background), BorderColor = new Color(border),
            BorderWidthLeft = 3, BorderWidthTop = 3, BorderWidthRight = 3, BorderWidthBottom = 3,
            CornerRadiusTopLeft = 26, CornerRadiusTopRight = 26, CornerRadiusBottomLeft = 26, CornerRadiusBottomRight = 26,
            ContentMarginLeft = 34, ContentMarginRight = 34, ContentMarginTop = 34, ContentMarginBottom = 34,
        });
    }

    private static Label Text(string text, int size, string color)
    {
        var label = new Label { Text = text };
        label.AddThemeFontSizeOverride("font_size", size);
        label.AddThemeColorOverride("font_color", new Color(color));
        return label;
    }
}
