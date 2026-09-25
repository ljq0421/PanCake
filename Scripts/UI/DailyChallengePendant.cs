using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;

namespace ProjectCake.UI;

/// <summary>Read-only presentation of the current run's challenge; rewards remain settlement-owned.</summary>
public partial class DailyChallengePendant : Control
{
    public static readonly Vector2 DisplaySize = new(480, 487f / 3);
    private readonly Label _name = TianjinUi.Label("", 26);
    private readonly Label _requirement = TianjinUi.Label("", 21);
    private readonly Label _reward = TianjinUi.Label("", 27, alignment: HorizontalAlignment.Center);
    private readonly Label _stamp = TianjinUi.Label("", 21, new Color("#41612B"), HorizontalAlignment.Center);
    private readonly List<TextureRect> _stars = new();
    private Texture2D _starTexture = null!;
    private Tween? _feedback;
    private DayController? _controller;
    private string? _runId;
    private int _lastProgress;
    private bool _focused = true;
    private bool _allowMotion;
    private readonly string _city;
    private readonly CashPendantFeedback _completionCoins = new();
    private AudioStreamPlayer _completionSound = null!;
    private Texture2D _coinTexture = null!;
    public Func<Vector2>? CoinTargetGlobal { get; set; }
    internal IReadOnlyCollection<Control> CompletionCoins => _completionCoins.Coins;
    internal event Action? CompletionPresented;

    public DailyChallengePendant(string city) { _city = city; Name = "DailyChallengePendant"; MouseFilter = MouseFilterEnum.Ignore; }

    public override void _Ready()
    {
        Size = DisplaySize;
        var artwork = Art(GD.Load<Texture2D>("res://resource/art/Global/HUDUI/daily-challenge-pendant-v1.png"));
        artwork.Name = "ChallengeArtwork";
        var title = TianjinUi.Label("每日挑战", 26, alignment: HorizontalAlignment.Center);
        if (_city == "武汉")
        {
            var material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/daily_challenge_city.gdshader") };
            material.SetShaderParameter("accent", WuhanUi.Accent);
            material.SetShaderParameter("outline", WuhanUi.Ink);
            material.SetShaderParameter("paper", WuhanUi.Paper);
            artwork.Material = material;
            foreach (var label in new[] { title, _name, _requirement, _reward, _stamp })
                label.AddThemeColorOverride("font_color", WuhanUi.Text);
        }
        Place(this, artwork, new(Vector2.Zero, DisplaySize));
        Place(this, title, new(158, 18, 163, 36));
        title.ClipText = true;
        Fit(title, 26);
        _name.Name = "ChallengeName";
        _requirement.Name = "ChallengeRequirement";
        _reward.Name = "ChallengeReward";
        _stamp.Name = "ChallengeCompletionStamp";
        Place(this, _name, new(75, 64, 125, 38));
        Place(this, _requirement, new(205, 64, 140, 38));
        var rewardPlate = new Panel();
        var rewardStyle = TianjinUi.Box(new Color("#FFD57A"), 19, 2, false);
        rewardStyle.BorderColor = new Color("#B97528");
        rewardPlate.AddThemeStyleboxOverride("panel", rewardStyle);
        Place(this, rewardPlate, new(350, 68, 105, 38));
        Place(rewardPlate, Art(CroppedArt("res://resource/art/Global/HUDUI/小费飞行金币.png")), new(5, 5, 28, 28));
        Place(rewardPlate, _reward, new(33, 1, 68, 36));
        var stampStyle = TianjinUi.Box(new Color("#F0EDCF"), 5, 2, false);
        stampStyle.BorderColor = new Color("#608345");
        if (_city == "武汉") { stampStyle.BgColor = WuhanUi.Surface; stampStyle.BorderColor = WuhanUi.Accent; }
        stampStyle.ContentMarginLeft = stampStyle.ContentMarginRight = 6;
        stampStyle.ContentMarginTop = stampStyle.ContentMarginBottom = 0;
        _stamp.AddThemeStyleboxOverride("normal", stampStyle);
        Place(this, _stamp, new(75, 99, 277, 27));
        _stamp.PivotOffset = _stamp.Size / 2;
        _stamp.Hide();
        _starTexture = CroppedArt("res://resource/art/Global/StartPage/小星星.png");
        _coinTexture = CroppedArt("res://resource/art/Global/HUDUI/小费飞行金币.png");
        _completionSound = new AudioStreamPlayer { Name = "ChallengeCompletedSound",
            Stream = MakeCompletionSound(), Bus = JourneySettings.EffectsBus,
            VolumeDb = -6, MaxPolyphony = 1 };
        AddChild(_completionSound);
        BuildCelebration();
        Hide();
    }

    public void Render(DayController controller, bool allowMotion, bool claimed)
    {
        _controller = controller;
        _allowMotion = allowMotion;
        if (controller.TutorialActive || controller.CurrentPlan?.Challenge is not { } challenge || controller.Ledger is not { } ledger)
        {
            Hide(); StopAllFeedback(); _runId = null; return;
        }
        Show();
        string runId = controller.CurrentPlan.RunId;
        bool newRun = _runId != runId;
        if (newRun) { StopAllFeedback(); _runId = runId; BuildStars(challenge.Target); }
        DayResult result = ledger.Build();
        int progress = Math.Clamp(challenge.Progress(result), 0, challenge.Target);
        bool achieved = challenge.Achieved(result);
        _name.Text = Tr(challenge.Name);
        _reward.Text = $"+{challenge.Reward}";
        _requirement.Text = Tr(challenge.Requirement);
        bool nearly = !claimed && !achieved && (challenge.Kind == DailyChallengeKind.Streak
            ? ledger.CurrentCorrectStreak : progress) == challenge.Target - 1;
        _stamp.Text = Tr("奖励已领取");
        _stamp.Visible = claimed;
        if (nearly) _requirement.Text = challenge.Kind == DailyChallengeKind.Perfect ? Tr("再完美完成 1 单！") : Tr("再完成 1 单！");
        bool english = TranslationServer.GetLocale().StartsWith("en");
        _name.ClipText = _requirement.ClipText = true;
        _name.Position = english ? new(75, 58) : new(75, 64);
        _name.Size = english ? new(270, 26) : new(125, 38);
        _requirement.Position = english ? new(75, 84) : new(205, 64);
        _requirement.Size = english ? new(270, 26) : new(140, 38);
        _requirement.Visible = !english || !claimed;
        UpdateNearly(nearly);
        for (int i = 0; i < _stars.Count; i++)
            _stars[i].Modulate = i < progress ? Colors.White : new Color(.65f, .48f, .33f, .35f);
        Fit(_name, english ? 20 : 26); Fit(_requirement, english ? 18 : 21); Fit(_stamp, 21);
        if (!CanPresent()) StopAllFeedback();
        else if (!CanAnimate()) StopFeedback();
        else if (!newRun && progress > _lastProgress) AnimateProgress(progress);
        if (!newRun && achieved && _lastProgress < challenge.Target && !claimed && CanPresent())
            CelebrateCompletion(challenge);
        _lastProgress = progress;
    }

    private void BuildStars(int target)
    {
        foreach (var star in _stars) { RemoveChild(star); star.QueueFree(); }
        _stars.Clear();
        float step = Math.Min(26, 414f / Math.Max(1, target));
        float size = Math.Min(18, step - 2);
        float left = (DisplaySize.X - step * target) / 2;
        for (int i = 0; i < target; i++)
        {
            var star = Art(_starTexture); star.Name = $"ChallengeStar{i + 1}";
            Place(this, star, new(left + step * i + (step - size) / 2, 128, size, size));
            star.PivotOffset = star.Size / 2; _stars.Add(star);
        }
    }

    private bool CanPresent() => _focused && _allowMotion && IsVisibleInTree() && _controller?.IsPaused == false;
    private bool CanAnimate() => CanPresent() && !ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();

    private void CelebrateCompletion(DailyChallenge challenge)
    {
        // Cosmetic only: no ledger credit, save mutation or business-income pulse.
        _completionSound.Play();
        ShowCelebration(challenge);
        if (CanAnimate() && CoinTargetGlobal is not null)
        {
            var inverse = GetGlobalTransform().AffineInverse();
            Vector2 origin = inverse * _reward.GetGlobalRect().GetCenter();
            Vector2 target = inverse * CoinTargetGlobal();
            for (int i = 0; i < 3; i++)
                _completionCoins.Spawn(this, _coinTexture, origin + new Vector2(i * 12 - 12, 0), target, i * .09);
        }
        CompletionPresented?.Invoke();
    }

    private void AnimateProgress(int progress)
    {
        StopFeedback();
        _feedback = CreateTween().SetParallel();
        if (progress > 0 && progress <= _stars.Count)
        {
            var star = _stars[progress - 1];
            _feedback.TweenProperty(star, "scale", Vector2.One * 1.2f, .14);
            _feedback.TweenProperty(star, "scale", Vector2.One, .3).SetDelay(.14);
        }
    }

    private void StopFeedback()
    {
        _feedback?.Kill(); _feedback = null;
        _completionCoins.Clear();
        _stamp.Scale = Vector2.One; _stamp.Rotation = 0;
        foreach (var star in _stars) star.Scale = Vector2.One;
    }
    private void StopAllFeedback() { StopFeedback(); StopCelebration(); _completionSound?.Stop(); }
    public override void _Process(double delta)
    {
        if (!CanPresent()) StopAllFeedback();
        else if (!CanAnimate()) StopFeedback();
        TickCelebration(delta);
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) { _focused = false; StopAllFeedback(); }
        else if (what == NotificationApplicationFocusIn) _focused = true;
    }
    public override void _ExitTree() => StopAllFeedback();
    private static void Fit(Label label, int size)
    {
        while (size > 16 && label.GetThemeFont("font").GetStringSize(label.Text, fontSize: size).X > label.Size.X - 12) size--;
        label.AddThemeFontSizeOverride("font_size", size);
    }
    private static Texture2D CroppedArt(string path)
    {
        var texture = GD.Load<Texture2D>(path);
        using var image = texture.GetImage();
        return new AtlasTexture { Atlas = texture, Region = image.GetUsedRect() };
    }
    private static TextureRect Art(Texture2D texture) => new() { Texture = texture,
        ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered };
    private static void Place(Control parent, Control child, Rect2 rect)
    {
        child.MouseFilter = MouseFilterEnum.Ignore; child.Position = rect.Position; child.Size = rect.Size; parent.AddChild(child);
    }
}
