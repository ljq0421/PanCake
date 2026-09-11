using Godot;

namespace ProjectCake.UI;

/// <summary>Collectable money presentation; the day ledger remains the sole money owner.</summary>
public partial class CoinTrayView : Control
{
    private bool _buttonPresentation;
    /// <summary>Use button visuals already authored in CoinButtonView.tscn.</summary>
    [Export] public bool SceneButtonPresentation { get; set; }
    internal bool IsButtonPresentation => _buttonPresentation;
    public void ConfigureButtonPresentation()
    {
        _buttonPresentation = true;
        GetNode<TextureRect>("CoinTrayArt").Hide();
        _surface.Hide();
        _collect.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        _collect.CustomMinimumSize = Vector2.Zero;
        _collect.Flat = false;
        _caption.MouseFilter = MouseFilterEnum.Ignore;
        _collect.AddThemeStyleboxOverride("normal", TianjinUi.Box(TianjinUi.Cream, 10, 2, false));
        _collect.AddThemeStyleboxOverride("hover", TianjinUi.Box(TianjinUi.Yellow.Lightened(.4f), 10, 2, false));
        _collect.AddThemeStyleboxOverride("pressed", TianjinUi.Box(TianjinUi.Yellow, 10, 2, false));
        _collect.TooltipText = "点击收钱";
        _caption.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        _caption.CustomMinimumSize = Vector2.Zero;
        _caption.HorizontalAlignment = HorizontalAlignment.Center;
        _caption.VerticalAlignment = VerticalAlignment.Center;
        _caption.ZIndex = 1;
        _caption.AddThemeFontSizeOverride("font_size", 20);
        _caption.AddThemeStyleboxOverride("normal", new StyleBoxEmpty());
    }
    internal const int CoinsPerPayment = 3;
    private readonly List<TextureRect> _coins = new();
    private Control _surface = null!;
    private Label _caption = null!;
    private Button _collect = null!;
    private int _revenue, _collectedRevenue;
    private int _paymentCount, _collectedPaymentCount;
    public Func<bool>? CanCollect { get; set; }
    public event Action<int>? Collected;
    public int PendingAmount => Math.Max(0, _revenue - _collectedRevenue);
    public int VisibleCoinCount { get; private set; }
    [Export] public bool AmountOnly { get; set; }
    public bool CompactCaption { get; set; }
    [Export] public Rect2 CoinSurface { get; set; } = new(26, 16, 198, 52);
    public Vector2 LandingPoint => _buttonPresentation ? GetGlobalRect().GetCenter()
        : _surface.GetGlobalTransform() * (_surface.Size * .5f);
    internal Rect2 SurfaceBounds => _surface.GetGlobalRect();
    internal IReadOnlyList<TextureRect> Coins => _coins;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _buttonPresentation = SceneButtonPresentation;
        _surface.Position = CoinSurface.Position;
        _surface.Size = CoinSurface.Size;
        for (int i = 0; i < _coins.Count; i++) LayoutCoin(_coins[i], i);
        _collect.Pressed += () => TryCollect();
        RenderRevenue(0);
    }

    /// <summary>Append a short outward hop to the existing payment tween, preserving its pause/cleanup owner.</summary>
    internal void AppendPaymentLanding(Tween tween, Control coin, Control root, int index)
    {
        if (_buttonPresentation)
        {
            tween.Chain().TweenProperty(coin, "modulate:a", 0f, .1);
            return;
        }
        int slot = Math.Max(0, VisibleCoinCount - CoinsPerPayment) + index % CoinsPerPayment;
        EnsureCoins(slot + 1);
        Transform2D surfaceToRoot = root.GetGlobalTransform().AffineInverse() * _surface.GetGlobalTransform();
        Vector2 target = surfaceToRoot * (_coins[slot].Position + _coins[slot].Size * .5f) - coin.Size * .5f;
        Vector2 hop = surfaceToRoot.BasisXform(new Vector2(0, -7));
        Vector2 start = Vector2.Zero;
        tween.Chain().TweenCallback(Callable.From(() => start = coin.Position));
        tween.Chain().TweenMethod(Callable.From<float>(t =>
            coin.Position = start.Lerp(target, t) + hop * (4 * t * (1 - t))), 0f, 1f, .18)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        tween.Parallel().TweenProperty(coin, "rotation", _coins[slot].Rotation, .18)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        Vector2 sizeRatio = _coins[slot].Size / coin.Size;
        tween.Parallel().TweenProperty(coin, "scale", _coins[slot].Scale * sizeRatio * surfaceToRoot.Scale, .18);
        tween.Chain().TweenProperty(coin, "modulate:a", 0f, .1);
    }

    public void RenderRevenue(int revenue, int? paymentCount = null)
    {
        revenue = Math.Max(0, revenue);
        if (revenue < _revenue || revenue == 0)
        {
            _collectedRevenue = 0;
            _paymentCount = 0;
            _collectedPaymentCount = 0;
        }
        // Production passes the ledger's paid-customer count so multiple payments
        // between frames still leave one handful each. Previews may supply deltas.
        _paymentCount = paymentCount ?? (_paymentCount + (revenue > _revenue ? 1 : 0));
        _revenue = revenue;
        VisibleCoinCount = PendingAmount == 0 ? 0 : Math.Max(0, _paymentCount - _collectedPaymentCount) * CoinsPerPayment;
        EnsureCoins(VisibleCoinCount);
        for (int i = 0; i < _coins.Count; i++) _coins[i].Visible = i < VisibleCoinCount;
        _caption.Text = AmountOnly || CompactCaption ? (PendingAmount > 0 ? $"¥{PendingAmount}" : "")
            : PendingAmount > 0 ? $"点击收钱 ¥{PendingAmount}" : "金币盘";
        _caption.Visible = _buttonPresentation || !(AmountOnly || CompactCaption) || PendingAmount > 0;
        if (_buttonPresentation) _caption.Text = PendingAmount > 0 ? $"收钱 ¥{PendingAmount}" : "收钱";
        _collect.MouseDefaultCursorShape = PendingAmount > 0 ? CursorShape.PointingHand : CursorShape.Arrow;
    }

    private void EnsureCoins(int count)
    {
        while (_coins.Count < count)
        {
            var coin = TianjinUi.Texture(_coins[0].Texture, new Vector2(24, 24));
            coin.Name = $"SettledCoin{_coins.Count + 1}";
            coin.Visible = false;
            _surface.AddChild(coin);
            LayoutCoin(coin, _coins.Count);
            _coins.Add(coin);
        }
    }

    private void LayoutCoin(TextureRect coin, int index)
    {
        // Irrational strides spread successive handfuls across both tray axes.
        // Positions depend only on the coin index; existing coins never reshuffle.
        float x = (float)((.19 + index * .61803398875) % 1);
        float y = (float)((.37 + index * .41421356237) % 1);
        coin.Size = new Vector2(24, 24);
        coin.PivotOffset = coin.Size * .5f;
        coin.Position = new Vector2((15 + x * 168) / 198 * CoinSurface.Size.X,
            (14 + y * 24) / 52 * CoinSurface.Size.Y) - coin.PivotOffset;
        float fit = Math.Min(1, Math.Min(CoinSurface.Size.X / 198, CoinSurface.Size.Y / 52));
        coin.Scale = new Vector2(.9f, index % 2 == 0 ? .66f : .78f) * fit;
        coin.Rotation = Mathf.DegToRad(-24 + (index * 37 % 49));
        coin.ZIndex = index + 1;
    }

    public bool TryCollect()
    {
        if (CanCollect?.Invoke() != true || PendingAmount == 0) return false;
        int amount = PendingAmount;
        _collectedRevenue = _revenue;
        _collectedPaymentCount = _paymentCount;
        RenderRevenue(_revenue);
        Collected?.Invoke(amount);
        return true;
    }
}
