using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class DailyChallengePendant
{
    private Panel _banner = null!;
    private Label _bannerTitle = null!, _bannerReward = null!;
    private readonly List<TextureRect> _sparkles = new();
    private Tween? _celebration, _nearlyTween;
    private double _bannerRemaining;
    private bool _wasNearly;

    private void BuildCelebration()
    {
        _banner = new Panel { Name = "ChallengeCompletionBanner", ZIndex = 2, Visible = false };
        var paper = TianjinUi.Box(new Color("#FFF1CF"), 22, 3, true);
        paper.BorderColor = new Color("#B97528");
        _banner.AddThemeStyleboxOverride("panel", paper);
        // The temporary banner occupies the top HUD band, above customer orders.
        Place(this, _banner, new(0, 0, 640, 132));
        _banner.PivotOffset = _banner.Size / 2;
        Place(_banner, Art(_starTexture), new(24, 27, 70, 70));
        _bannerTitle = TianjinUi.Label("", 34, TianjinUi.BrownText, HorizontalAlignment.Center);
        _bannerReward = TianjinUi.Label("", 26, TianjinUi.BrownText, HorizontalAlignment.Center);
        Place(_banner, _bannerTitle, new(100, 20, 516, 48));
        Place(_banner, _bannerReward, new(100, 74, 516, 38));
        for (int i = 0; i < 6; i++)
        {
            var star = Art(_starTexture);
            Place(_banner, star, new(0, 0, 18, 18));
            star.PivotOffset = star.Size / 2;
            _sparkles.Add(star);
        }
    }

    private void UpdateNearly(bool nearly)
    {
        if (nearly && !_wasNearly && CanAnimate())
        {
            _nearlyTween?.Kill();
            _requirement.Modulate = new Color("#FFBD55");
            _nearlyTween = CreateTween();
            _nearlyTween.TweenProperty(_requirement, "modulate", Colors.White, .65);
        }
        if (!nearly) { _nearlyTween?.Kill(); _requirement.Modulate = Colors.White; }
        _wasNearly = nearly;
    }

    private void ShowCelebration(DailyChallenge challenge)
    {
        StopCelebration();
        _bannerTitle.Text = $"{Tr("挑战达成")} · {Tr(challenge.Name)}";
        _bannerReward.Text = string.Format(Tr("奖金 {0} 金币 · 结算领取").ToString(), challenge.Reward);
        Fit(_bannerTitle, 34); Fit(_bannerReward, 26);
        Vector2 rest = new((GetParent<Control>().Size.X - _banner.Size.X) / 2 - Position.X, 8 - Position.Y);
        _banner.Position = rest;
        _banner.Scale = Vector2.One;
        _banner.Modulate = Colors.White;
        _banner.Show();
        _bannerRemaining = 2.15;
        foreach (var star in _sparkles) star.Hide();
        if (!CanAnimate()) return;
        _banner.Scale = new(.9f, .9f);
        _celebration = CreateTween().SetParallel();
        _celebration.TweenProperty(_banner, "scale", Vector2.One, .28)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        for (int i = 0; i < _sparkles.Count; i++)
        {
            var star = _sparkles[i];
            star.Position = new(i < 3 ? 40 : 592, 56);
            star.Modulate = Colors.White; star.Scale = Vector2.One; star.Show();
            Vector2 end = star.Position + new Vector2(i < 3 ? -22 : 22, (i % 3 - 1) * 42);
            _celebration.TweenProperty(star, "position", end, .55).SetDelay(.12);
            _celebration.TweenProperty(star, "modulate:a", 0f, .35).SetDelay(.4);
        }
        _celebration.TweenProperty(_banner, "position", Size / 2 - _banner.Size / 2, .25).SetDelay(1.85)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.In);
        _celebration.TweenProperty(_banner, "scale", Vector2.One * .3f, .25).SetDelay(1.85);
        _celebration.TweenProperty(_banner, "modulate:a", 0f, .2).SetDelay(1.9);
    }

    private void TickCelebration(double delta)
    {
        if (_bannerRemaining <= 0) return;
        if (!CanAnimate() && _celebration is not null)
        {
            _celebration.Kill(); _celebration = null;
            _banner.Position = new((GetParent<Control>().Size.X - _banner.Size.X) / 2 - Position.X, 8 - Position.Y);
            _banner.Scale = Vector2.One; _banner.Modulate = Colors.White;
            foreach (var star in _sparkles) star.Hide();
        }
        _bannerRemaining -= delta;
        if (_bannerRemaining <= 0) StopCelebration();
    }

    private void StopCelebration()
    {
        _celebration?.Kill(); _celebration = null;
        _nearlyTween?.Kill(); _nearlyTween = null;
        _requirement.Modulate = Colors.White;
        _bannerRemaining = 0;
        _banner?.Hide();
    }

    private static AudioStreamWav MakeCompletionSound()
    {
        const int rate = 22050;
        double[] notes = { 523.25, 659.25, 783.99, 1046.5 };
        byte[] data = new byte[(int)(rate * .92) * 2];
        for (int i = 0; i < data.Length / 2; i++)
        {
            double value = 0;
            for (int n = 0; n < notes.Length; n++)
            {
                double t = i / (double)rate - n * .13;
                if (t < 0 || t > .5) continue;
                double envelope = Math.Min(1, t / .008) * Math.Exp(-t * 9) * Math.Min(1, (.5 - t) / .04);
                double phase = Math.Tau * notes[n] * t;
                value += (Math.Sin(phase) + .18 * Math.Sin(phase * 2)) * envelope * .3;
            }
            short sample = (short)(Math.Clamp(value, -1, 1) * short.MaxValue);
            data[i * 2] = (byte)(sample & 255); data[i * 2 + 1] = (byte)(sample >> 8);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate, Data = data };
    }
}
