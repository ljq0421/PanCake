using Godot;

namespace ProjectCake.UI;

/// <summary>Collectable money presentation; the day ledger remains the sole money owner.</summary>
public partial class CoinTrayView : Control
{
    // A stable, interleaved scatter: small payments spread out before the pile fills in.
    private static readonly Vector2[] CoinCenters =
    [
        new(78, 26), new(66, 17), new(109, 23), new(23, 25),
        new(131, 16), new(44, 16), new(94, 15), new(53, 26),
        new(120, 26), new(81, 16), new(34, 26), new(100, 26),
    ];
    private static readonly float[] CoinAngles = [-17, 12, -9, 21, -15, 8, -22, 16, 6, -12, 18, -5];
    private readonly TextureRect[] _coins = new TextureRect[12];
    private Control _surface = null!;
    private Label _caption = null!;
    private Button _collect = null!;
    private int _revenue, _collectedRevenue;
    public Func<bool>? CanCollect { get; set; }
    public event Action<int>? Collected;
    public int PendingAmount => Math.Max(0, _revenue - _collectedRevenue);
    public int VisibleCoinCount { get; private set; }
    public Vector2 LandingPoint => _surface.GetGlobalTransform() * (_surface.Size * .5f);
    internal Rect2 SurfaceBounds => _surface.GetGlobalRect();
    internal IReadOnlyList<TextureRect> Coins => _coins;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _collect.Pressed += () => TryCollect();
        RenderRevenue(0);
    }

    /// <summary>Append a short outward hop to the existing payment tween, preserving its pause/cleanup owner.</summary>
    internal void AppendPaymentLanding(Tween tween, Control coin, Control root, int index)
    {
        int slot = index % 3;
        Transform2D surfaceToRoot = root.GetGlobalTransform().AffineInverse() * _surface.GetGlobalTransform();
        Vector2 target = surfaceToRoot * CoinCenters[slot] - coin.Size * .5f;
        Vector2 hop = surfaceToRoot.BasisXform(new Vector2(0, -7));
        Vector2 start = Vector2.Zero;
        tween.Chain().TweenCallback(Callable.From(() => start = coin.Position));
        tween.Chain().TweenMethod(Callable.From<float>(t =>
            coin.Position = start.Lerp(target, t) + hop * (4 * t * (1 - t))), 0f, 1f, .18)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        tween.Parallel().TweenProperty(coin, "rotation", Mathf.DegToRad(CoinAngles[slot]), .18)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        Vector2 sizeRatio = _coins[slot].Size / coin.Size;
        tween.Parallel().TweenProperty(coin, "scale", _coins[slot].Scale * sizeRatio * surfaceToRoot.Scale, .18);
        tween.Chain().TweenProperty(coin, "modulate:a", 0f, .1);
    }

    public void RenderRevenue(int revenue)
    {
        revenue = Math.Max(0, revenue);
        if (revenue < _revenue || revenue == 0) _collectedRevenue = 0;
        _revenue = revenue;
        VisibleCoinCount = (int)Math.Clamp(Math.Ceiling(PendingAmount / 10.0), 0, 12);
        for (int i = 0; i < _coins.Length; i++) _coins[i].Visible = i < VisibleCoinCount;
        _caption.Text = PendingAmount > 0 ? $"点击收钱 ¥{PendingAmount}" : "金币盘";
        _collect.MouseDefaultCursorShape = PendingAmount > 0 ? CursorShape.PointingHand : CursorShape.Arrow;
    }

    public bool TryCollect()
    {
        if (CanCollect?.Invoke() != true || PendingAmount == 0) return false;
        int amount = PendingAmount;
        _collectedRevenue = _revenue;
        RenderRevenue(_revenue);
        Collected?.Invoke(amount);
        return true;
    }
}
