using Godot;

namespace ProjectCake.UI;

/// <summary>Presentation only: payment is already recorded by the day ledger.</summary>
public sealed class CashPendantFeedback
{
    private readonly Dictionary<Control, Tween> _flights = new();
    private bool _paused;
    public IReadOnlyCollection<Control> Coins => _flights.Keys;

    public void Spawn(Control host, Texture2D texture, Vector2 origin, Vector2 target, double delay)
    {
        var coin = TianjinUi.Texture(texture, new Vector2(38, 38));
        coin.Name = "FlyingPaymentCoin";
        coin.Size = coin.CustomMinimumSize;
        coin.Position = origin - coin.Size * .5f;
        coin.PivotOffset = coin.Size * .5f;
        coin.MouseFilter = Control.MouseFilterEnum.Ignore;
        coin.ZIndex = 87;
        host.AddChild(coin);
        Tween tween = host.CreateTween().SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.InOut);
        _flights[coin] = tween;
        tween.TweenProperty(coin, "position", target - coin.Size * .5f, .62).SetDelay(delay);
        tween.Parallel().TweenProperty(coin, "scale", Vector2.One * .65f, .62).SetDelay(delay);
        tween.TweenProperty(coin, "scale", Vector2.One * .15f, .12);
        tween.Parallel().TweenProperty(coin, "modulate", new Color(1, 1, 1, 0), .12);
        tween.Finished += () => { _flights.Remove(coin); coin.QueueFree(); };
        if (_paused) tween.Pause();
    }

    public void SetPaused(bool paused)
    {
        _paused = paused;
        foreach (Tween tween in _flights.Values)
            if (paused) tween.Pause(); else tween.Play();
    }

    public void Clear()
    {
        foreach (var (coin, tween) in _flights)
        {
            tween.Kill();
            if (GodotObject.IsInstanceValid(coin)) coin.QueueFree();
        }
        _flights.Clear();
    }
}
