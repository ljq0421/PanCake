using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

/// <summary>One illustrated day, time and income sign shared by all city workbenches.</summary>
public partial class BusinessHud : Control
{
    private readonly string _city;
    public const string ArtworkPath = "res://resource/art/Global/PanelUI/HUD.png";
    // Current HUD.png (1916 x 821): exclude near-transparent export specks as well as padding.
    private static readonly Rect2 ArtworkRegion = new(97, 177, 1723, 396);
    private const float ArtworkScale = 440f / 1723;
    private readonly Label _day = TianjinUi.Label("1", 25, alignment: HorizontalAlignment.Center);
    private readonly Label _time = TianjinUi.Label("00:00", 25, alignment: HorizontalAlignment.Center);
    private readonly Label _income = TianjinUi.Label("0", 25, alignment: HorizontalAlignment.Center);
    private Control _sign = null!;
    public Control IncomeCoin { get; } = new() { Name = "IncomeCoin" };
    public Button PauseButton { get; } = new() { Name = "HudPause" };
    public Control IncomeTarget => _income;
    private Tween? _incomeTween;
    private readonly Label _challenge = TianjinUi.Label("", 21, alignment: HorizontalAlignment.Center);

    public void EmphasizeIncome()
    {
        ResetIncomeEmphasis();
        if (_city != "天津" || ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool()) return;
        _income.PivotOffset = _income.Size * .5f;
        _incomeTween = CreateTween();
        _incomeTween.TweenProperty(_income, "scale", Vector2.One * 1.04f, .12);
        _incomeTween.TweenProperty(_income, "scale", Vector2.One, .23);
    }

    public void ResetIncomeEmphasis()
    {
        _incomeTween?.Kill(); _incomeTween = null; _income.Scale = Vector2.One;
    }

    public override void _ExitTree() => ResetIncomeEmphasis();

    public BusinessHud(string city) { _city = city; Name = "BusinessHud"; }

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        ZIndex = 70;
        TextureFilter = TextureFilterEnum.LinearWithMipmaps;
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        // Exclude transparent margins at runtime, retaining the supplied image unchanged.
        _sign = new TextureRect { Name = "HudArtwork",
            Texture = new AtlasTexture { Atlas = GD.Load<Texture2D>(ArtworkPath), Region = ArtworkRegion },
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered };
        Place(this, _sign, new(Vector2.Zero, ArtworkRegion.Size * ArtworkScale));
        if (_city == "武汉")
        {
            var material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/business_hud_city.gdshader") };
            material.SetShaderParameter("accent", WuhanUi.Accent);
            material.SetShaderParameter("outline", WuhanUi.Ink);
            _sign.Material = material;
            _day.AddThemeColorOverride("font_color", WuhanUi.Text);
            _income.AddThemeColorOverride("font_color", WuhanUi.Text);
        }
        _day.Name = "DaySign"; _time.Name = "TimeSign"; _income.Name = "IncomeSign";
        _day.ClipText = _time.ClipText = _income.ClipText = true;
        PlaceOnArtwork(_day, new(530, 355, 173, 110));
        PlaceOnArtwork(_time, new(956, 355, 212, 110));
        PlaceOnArtwork(_income, new(1410, 355, 255, 110));
        PlaceOnArtwork(IncomeCoin, new(1254, 340, 145, 145));
        if (_city is "天津" or "武汉" or "西安") StyleIconButton(PauseButton, LoadArt("暂停铜扣"));
        else PauseButton.Hide(); // Guangzhou and Yangzhou keep their existing pause/resume controls.
        PauseButton.Position = new(1840, 28); PauseButton.Size = new(56, 56);
        AddChild(PauseButton);
        _challenge.Name = "DailyChallengeProgress";
        _challenge.MouseFilter = MouseFilterEnum.Ignore;
        _challenge.AddThemeColorOverride("font_color", new Color("#513A28"));
        _challenge.AddThemeColorOverride("font_outline_color", new Color("#FFF3D9"));
        _challenge.AddThemeConstantOverride("outline_size", 5);
        AddChild(_challenge); _challenge.Hide();
        Resized += LayoutSigns;
        LayoutSigns();
    }

    private void LayoutSigns()
    {
        _sign.Position = new((Size.X - _sign.Size.X) / 2, 6);
        PauseButton.Position = new(Size.X - 80, 28);
        _challenge.Position = new((Size.X - 540) / 2, 109); _challenge.Size = new(540, 32);
    }

    public void Render(DayController controller, bool allowPause)
    {
        if (controller.CurrentConfig is not { } config) return;
        double seconds = controller.State switch {
            DayState.Opening => controller.OpeningRemainingSeconds,
            DayState.Closing => controller.ClosingRemainingSeconds,
            DayState.Results => 0,
            _ => controller.DayRemainingSeconds };
        RenderValues(config.Day, seconds, controller.Ledger?.Build().TotalRevenue ?? 0, controller.State == DayState.Closing);
        PauseButton.Disabled = !allowPause;
        _challenge.Visible = !controller.TutorialActive && controller.CurrentPlan?.Challenge is not null;
        if (_challenge.Visible && controller.CurrentPlan?.Challenge is { } challenge && controller.Ledger is { } ledger)
        {
            bool claimed = GetNodeOrNull<SaveService>("/root/SaveService")?.Data.GetCity(config.CityId).ClaimedChallenges.ContainsKey(config.Day) == true;
            _challenge.Text = challenge.Live(ledger.Build(), claimed);
        }
        if (_city is "天津" or "武汉" or "西安") OfferInterfaceTeaching(controller, allowPause);
    }

    public void RenderValues(int day, double seconds, int income, bool closing)
    {
        _day.Text = day.ToString();
        int remaining = Math.Max(0, (int)Math.Ceiling(seconds));
        _time.Text = $"{remaining / 60:00}:{remaining % 60:00}";
        _time.AddThemeColorOverride("font_color", closing ? new Color("#9B422F") : _city == "武汉" ? WuhanUi.Text : TianjinUi.BrownText);
        _income.Text = income.ToString();
        FitNumber(_day); FitNumber(_time); FitNumber(_income);
    }

    private static void FitNumber(Label label)
    {
        int fontSize = 25;
        Font font = label.GetThemeFont("font");
        while (fontSize > 12 && font.GetStringSize(label.Text, fontSize: fontSize).X > label.Size.X - 4) fontSize--;
        label.AddThemeFontSizeOverride("font_size", fontSize);
    }

    private void OfferInterfaceTeaching(DayController controller, bool allowPause)
    {
        if (!allowPause || !IsVisibleInTree() || controller.State != DayState.Running || controller.TutorialActive) return;
        var owner = GetParent<Control>();
        bool Eligible() => owner.IsVisibleInTree() && !controller.IsPaused && !controller.TutorialActive
            && controller.State == DayState.Running
            && !owner.Descendants<TutorialFocusLayer>().Any(layer => layer.Visible)
            && !owner.Descendants<Control>().Any(control => control.Name == "DemoLesson" && control.IsVisibleInTree());
        void Pause(bool value) => controller.SetPauseReason("interface-teaching", value);
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        if (!settings.HasSeenInterfaceLesson(InterfaceLessons.BusinessKey))
            InterfaceTeaching.Offer(owner, InterfaceLessons.BusinessKey, InterfaceLessons.Business, Eligible, Pause);
        else if (_city is "天津" or "武汉")
            InterfaceTeaching.Offer(owner, InterfaceLessons.PendantKey, InterfaceLessons.Pendant, Eligible, Pause);
    }

    public Texture2D LoadArt(string name)
        => GD.Load<Texture2D>($"res://resource/art/Global/HUDUI/{name}-{_city}.png");

    public static void StyleIconButton(Button button, Texture2D texture)
    {
        ButtonHoverFeedback.Attach(button);
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

    private void PlaceOnArtwork(Control child, Rect2 source)
        => Place(_sign, child, new((source.Position - ArtworkRegion.Position) * ArtworkScale, source.Size * ArtworkScale));
    private static void Place(Control parent, Control child, Rect2 rect)
    {
        child.MouseFilter = MouseFilterEnum.Ignore; child.Position = rect.Position; child.Size = rect.Size;
        parent.AddChild(child);
    }
}
