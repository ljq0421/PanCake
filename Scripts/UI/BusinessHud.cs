using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

/// <summary>Three separated shop signs, shared by the three illustrated chapters.</summary>
public partial class BusinessHud : Control
{
    private readonly string _city;
    private readonly Label _day = TianjinUi.Label("1", 28);
    private readonly Label _orders = TianjinUi.Label("0/0", 25);
    private readonly Label _time = TianjinUi.Label("00:00", 32);
    private readonly Label _income = TianjinUi.Label("0", 27);
    private TextureRect _peak = null!;
    private Control _daySign = null!, _progressSign = null!, _incomeSign = null!;
    public Button PauseButton { get; } = new() { Name = "HudPause", TooltipText = "暂停营业（Esc）" };
    public Control IncomeTarget => _income;

    public BusinessHud(string city) { _city = city; Name = "BusinessHud"; }

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        ZIndex = 70;
        TextureFilter = TextureFilterEnum.LinearWithMipmaps;
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        _daySign = Sign("DaySign", "小型营业日签底板", new(24, 6, 250, 94));
        Icon(_daySign, "经营手账页图标", new(40, 35, 36, 36));
        Place(_daySign, _day, new(92, 34, 70, 38));
        _peak = Icon(_daySign, "高峰状态徽记", new(166, 39, 28, 28));
        _progressSign = Sign("ProgressSign", "中央经营挂牌底板", new(745, 6, 430, 94));
        Icon(_progressSign, "今日订单图标", new(40, 35, 34, 34));
        Place(_progressSign, _orders, new(86, 33, 108, 40));
        Icon(_progressSign, "厨房计时器", new(222, 33, 38, 38));
        Place(_progressSign, _time, new(271, 30, 128, 44));
        _incomeSign = Sign("IncomeSign", "收入挂牌底板", new(1586, 6, 240, 94));
        var coin = new TextureRect { Texture = GD.Load<Texture2D>("res://resource/art/TianJin/金币图标.png"),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered };
        Place(_incomeSign, coin, new(38, 35, 36, 36));
        Place(_incomeSign, _income, new(86, 34, 124, 38));
        StyleIconButton(PauseButton, LoadArt("暂停铜扣"));
        PauseButton.Position = new(1840, 28); PauseButton.Size = new(56, 56);
        AddChild(PauseButton);
        Resized += LayoutSigns;
        LayoutSigns();
    }

    private void LayoutSigns()
    {
        _progressSign.Position = new((Size.X - 430) / 2, 6);
        _incomeSign.Position = new(Size.X - 334, 6);
        PauseButton.Position = new(Size.X - 80, 28);
    }

    public void Render(DayController controller, string dayDescription, bool peak, bool allowPause)
    {
        if (controller.CurrentConfig is not { } config) return;
        _day.Text = config.Day.ToString();
        _daySign.TooltipText = dayDescription;
        _daySign.MouseFilter = MouseFilterEnum.Pass;
        _peak.Visible = peak;
        _orders.Text = $"{controller.Ledger?.CompletedCustomers ?? 0}/{config.CustomerCount}";
        _orders.TooltipText = "今日已完成订单 / 计划订单";
        _orders.MouseFilter = MouseFilterEnum.Pass;
        double seconds = controller.State switch {
            DayState.Opening => controller.OpeningRemainingSeconds,
            DayState.Closing => controller.ClosingRemainingSeconds,
            DayState.Results => 0,
            _ => controller.DayRemainingSeconds };
        int remaining = Math.Max(0, (int)Math.Ceiling(seconds));
        _time.Text = $"{remaining / 60:00}:{remaining % 60:00}";
        _time.TooltipText = controller.IsPaused ? "营业已暂停" : controller.State switch {
            DayState.Opening => "开门倒计时", DayState.Closing => "打烊收尾", DayState.Results => "今日已打烊", _ => "剩余营业时间" };
        _time.MouseFilter = MouseFilterEnum.Pass;
        _time.AddThemeColorOverride("font_color", controller.State == DayState.Closing ? new Color("#9B422F") : TianjinUi.BrownText);
        _income.Text = (controller.Ledger?.Build().TotalRevenue ?? 0).ToString();
        _income.TooltipText = "今日收入（含小费）"; _income.MouseFilter = MouseFilterEnum.Pass;
        PauseButton.Disabled = !allowPause;
    }

    public Texture2D LoadArt(string name)
        => GD.Load<Texture2D>($"res://resource/art/Global/HUDUI/{name}-{_city}.png");

    public static void StyleIconButton(Button button, Texture2D texture)
    {
        button.Text = ""; button.CustomMinimumSize = new(52, 52);
        button.MouseDefaultCursorShape = CursorShape.PointingHand;
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        var icon = new TextureRect { Name = "Artwork", Texture = texture, MouseFilter = MouseFilterEnum.Ignore,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered };
        button.AddChild(icon); icon.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        ArtworkButtonFocus.Attach(button, icon);
        button.MouseEntered += () => icon.Modulate = new Color(1.12f, 1.12f, 1.12f);
        button.MouseExited += () => icon.Modulate = Colors.White;
        button.ButtonDown += () => icon.Modulate = new Color(.88f, .88f, .88f);
        button.ButtonUp += () => icon.Modulate = Colors.White;
    }

    private Control Sign(string name, string art, Rect2 rect)
    {
        var sign = new BusinessHudSign { Name = name, Texture = LoadArt(art), MouseFilter = MouseFilterEnum.Ignore };
        Place(this, sign, rect); return sign;
    }
    private TextureRect Icon(Control parent, string art, Rect2 rect)
    {
        var icon = new TextureRect { Texture = LoadArt(art), ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered };
        Place(parent, icon, rect); return icon;
    }
    private static void Place(Control parent, Control child, Rect2 rect)
    {
        child.MouseFilter = MouseFilterEnum.Ignore; child.Position = rect.Position; child.Size = rect.Size;
        parent.AddChild(child);
    }
}

/// <summary>Stretch only the blank bands; keep the ties, side ornaments and center seal proportional.</summary>
public partial class BusinessHudSign : Control
{
    public Texture2D Texture { get; set; } = null!;
    public override void _Draw()
    {
        float w = Texture.GetWidth(), h = Texture.GetHeight(), scale = Size.Y / h;
        float[] cuts = { 0, .24f, .45f, .55f, .76f, 1 };
        float flexible = Math.Max(0, Size.X - w * .58f * scale) / 2;
        float x = 0;
        for (int i = 0; i < 5; i++)
        {
            float sourceWidth = (cuts[i + 1] - cuts[i]) * w;
            float width = i is 1 or 3 ? flexible : sourceWidth * scale;
            DrawTextureRectRegion(Texture, new Rect2(x, 0, width, Size.Y), new Rect2(cuts[i] * w, 0, sourceWidth, h));
            x += width;
        }
    }
}
