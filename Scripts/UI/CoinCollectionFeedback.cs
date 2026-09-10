using Godot;
using ProjectCake.Gameplay;

namespace ProjectCake.UI;

/// <summary>Shared, presentation-only collection feedback, paused on the gameplay clock.</summary>
public partial class CoinCollectionFeedback : Node
{
    private readonly Dictionary<Control, Tween> _effects = new();
    private readonly HashSet<Control> _payments = new();
    private CoinTrayView? _tray;
    private Control _root = null!, _target = null!;
    private Texture2D _coin = null!;
    private PancakeAudio _audio = null!;
    private Tween? _pulse, _trayPulse;
    private Vector2 _targetScale, _trayScale;
    private Color _targetColor;
    public Func<bool>? CanAnimate { get; set; }
    public Action? Collecting { get; set; }
    internal IReadOnlyCollection<Control> Effects => _effects.Keys;
    private static bool ReducedMotion => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
    }

    public void Bind(CoinTrayView tray, Control root, Control target, Texture2D coin, Func<bool> canAnimate)
    {
        Clear();
        if (_tray is not null) { _tray.Collected -= OnCollected; _tray.CanCollect = null; }
        _tray = tray; _root = root; _target = target; _coin = coin; CanAnimate = canAnimate;
        _targetScale = target.Scale; _targetColor = target.Modulate;
        _trayScale = tray.Scale;
        tray.CanCollect = canAnimate;
        tray.Collected += OnCollected;
    }

    public override void _Process(double delta)
    {
        if (_root is null) return;
        if (!_root.IsVisibleInTree()) { Clear(); return; }
        bool active = CanAnimate?.Invoke() == true;
        _audio.SetPaused(!active);
        if (active) Advance(delta);
    }

    internal void Advance(double delta)
    {
        foreach (var pair in _effects.ToArray()) pair.Value.CustomStep(delta);
        _pulse?.CustomStep(delta);
        _trayPulse?.CustomStep(delta);
    }

    private Vector2 Local(Vector2 global) => _root.GetGlobalTransform().AffineInverse() * global;

    private void OnCollected(int amount)
    {
        if (_tray is null) return;
        Collecting?.Invoke();
        foreach (Control payment in _payments)
        {
            _effects[payment].Kill(); payment.QueueFree(); _effects.Remove(payment);
        }
        _payments.Clear();
        Vector2 origin = Local(_tray.LandingPoint), target = Local(_target.GetGlobalRect().GetCenter());
        _audio.Play(PancakeSound.CoinCollect);
        var text = TianjinUi.Label($"+¥{amount}", 34, new Color("#FFE27A"), HorizontalAlignment.Center);
        text.Name = "CollectedAmount";
        text.Position = origin - new Vector2(110, 70); text.Size = new Vector2(220, 50);
        if (_tray.IsButtonPresentation) text.Position = origin + new Vector2(-110, 38);
        text.AddThemeConstantOverride("outline_size", 5);
        text.AddThemeColorOverride("font_outline_color", TianjinUi.BrownDark);
        Tween labelTween = Effect(text);
        labelTween.SetParallel(true).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        if (!ReducedMotion) labelTween.TweenProperty(text, "position", text.Position - new Vector2(0, 32), .25);
        labelTween.TweenProperty(text, "modulate:a", 0f, .2).SetDelay(.4);
        if (!ReducedMotion)
        {
            _trayPulse?.Kill(); _tray.PivotOffset = _tray.IsButtonPresentation ? _tray.Size * .5f : new Vector2(125, 43);
            _trayPulse = CreateTween(); _trayPulse.Stop();
            _trayPulse.SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
            _trayPulse.TweenProperty(_tray, "scale", _trayScale * .96f, .1);
            _trayPulse.TweenProperty(_tray, "scale", _trayScale, .16);
            _trayPulse.Finished += () => _trayPulse = null;
            int count = Math.Clamp((int)Math.Ceiling(amount / 8.0), 3, 8);
            for (int i = 0; i < count; i++)
                Fly(origin + new Vector2((i % 4 - 1.5f) * 18, -(i / 4) * 10), target, i * .035);
        }
        _pulse?.Kill();
        _target.PivotOffset = _target.Size * .5f;
        _target.Modulate = new Color("#FFE27A");
        _pulse = CreateTween(); _pulse.Stop();
        _pulse.SetParallel(true).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        if (!ReducedMotion)
        {
            _pulse.TweenProperty(_target, "scale", _targetScale * 1.12f, .12);
            _pulse.Chain().TweenProperty(_target, "scale", _targetScale, .16);
        }
        _pulse.TweenProperty(_target, "modulate", _targetColor, .25);
        _pulse.Finished += () => _pulse = null;
    }

    public void PaymentFrom(Vector2 globalOrigin)
    {
        if (_tray is null || ReducedMotion) return;
        Vector2 origin = Local(globalOrigin), target = Local(_tray.LandingPoint);
        for (int i = 0; i < 3; i++) Fly(origin + new Vector2((i - 1) * 16, 0), target, i * .035, true, i);
    }

    private void Fly(Vector2 origin, Vector2 target, double delay, bool payment = false, int index = 0)
    {
        var coin = TianjinUi.Texture(_coin, new Vector2(32, 32));
        coin.Size = coin.CustomMinimumSize;
        coin.Name = payment ? "TrayPaymentCoin" : "CollectionCoin"; coin.Position = origin - coin.Size * .5f;
        coin.PivotOffset = coin.Size * .5f;
        Tween tween = Effect(coin);
        if (payment) _payments.Add(coin);
        tween.SetParallel(true).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.InOut);
        tween.TweenProperty(coin, "position", target - coin.Size * .5f, .28).SetDelay(delay);
        tween.TweenProperty(coin, "scale", new Vector2(.65f, .65f), .28).SetDelay(delay);
        if (payment && _tray is not null) _tray.AppendPaymentLanding(tween, coin, _root, index);
        else tween.Chain().TweenProperty(coin, "modulate:a", 0f, .1);
    }

    private Tween Effect(Control control)
    {
        control.MouseFilter = Control.MouseFilterEnum.Ignore; control.ZIndex = 87; _root.AddChild(control);
        Tween tween = CreateTween(); tween.Stop(); _effects.Add(control, tween);
        tween.Finished += () => { _effects.Remove(control); _payments.Remove(control); control.QueueFree(); };
        return tween;
    }

    public void Clear()
    {
        foreach (var pair in _effects) { pair.Value.Kill(); if (IsInstanceValid(pair.Key)) pair.Key.QueueFree(); }
        _effects.Clear(); _payments.Clear(); _pulse?.Kill(); _pulse = null;
        _trayPulse?.Kill(); _trayPulse = null;
        if (_tray is not null && IsInstanceValid(_tray)) _tray.Scale = _trayScale;
        if (_target is not null && IsInstanceValid(_target)) { _target.Scale = _targetScale; _target.Modulate = _targetColor; }
        _audio?.Stop();
    }

    public override void _ExitTree()
    {
        Clear();
        if (_tray is not null && IsInstanceValid(_tray)) { _tray.Collected -= OnCollected; _tray.CanCollect = null; }
    }
}
