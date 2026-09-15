using Godot;
using ProjectCake.Pancake;

namespace ProjectCake.UI;

/// <summary>Presentation only. No timers here advance the cooking or payment models.</summary>
public partial class TianjinLivingWorkbench : Control
{
    public Func<bool> Active { get; set; } = () => false;
    public Func<PancakeRuntime?> Runtime { get; set; } = () => null;
    public Func<bool> Spreading { get; set; } = () => false;
    public Action? StopPaymentFeedback { get; set; }
    private TextureRect _pendant = null!, _scraper = null!, _spatula = null!;
    private Tween? _pendantTween;
    private float _steamLeft, _flipLeft;
    private PancakeState? _lastState;
    private bool _wasReduced;
    private readonly List<(Control View, Tween Tween)> _papers = new();
    public int CompletedPaperCount => _papers.Count;
    public float SteamRemaining => _steamLeft;
    public float PendantRotation => _pendant.RotationDegrees;
    public bool ToolsAtRest => _scraper.Visible && _flipLeft <= 0;
    public void BindPendantHighlight(Func<InteractionHighlightState> state) => ArtContourHighlight.Attach(_pendant, state);
    private static bool Reduced => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();
    private static readonly Rect2 ScraperRect = TianjinWorkbenchLayout.FromSource(1138, 505, 135, 51);
    private static readonly Rect2 SpatulaRect = TianjinWorkbenchLayout.FromSource(1324, 512, 140, 43);

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore; ZIndex = 40;
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        _pendant = Sprite("pendant", TianjinWorkbenchLayout.FromSource(1220, 53, 128, 278));
        _pendant.PivotOffset = new Vector2(_pendant.Size.X * .47f, 0);
        // Keep the pouch behind customers and their order papers, like the original background.
        _pendant.ZAsRelative = false; _pendant.ZIndex = 1;
        _scraper = Sprite("scraper", ScraperRect);
        _spatula = Sprite("spatula", SpatulaRect);
    }

    private TextureRect Sprite(string name, Rect2 rect)
    {
        var sprite = new TextureRect { Name = name, MouseFilter = MouseFilterEnum.Ignore,
            Texture = GD.Load<Texture2D>($"res://resource/art/TianJin/LivingWorkbench/{name}.png"),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.Scale,
            Position = rect.Position, Size = rect.Size, TextureFilter = TextureFilterEnum.LinearWithMipmaps };
        AddChild(sprite); return sprite;
    }

    public override void _Process(double delta)
    {
        var state = Runtime()?.State;
        if (!IsVisibleInTree() || !Active())
        {
            ResetMotion(); _lastState = state; return;
        }
        if (Reduced)
        {
            if (!_wasReduced) ResetMotion();
            _wasReduced = true; _lastState = state; return;
        }
        _wasReduced = false;
        if (state != _lastState && state is PancakeState.SideAReady or PancakeState.SideBReady) _steamLeft = .85f;
        _lastState = state;
        _steamLeft = Math.Max(0, _steamLeft - (float)delta);
        if (state is PancakeState.Empty or PancakeState.Burnt or PancakeState.Folded or PancakeState.Bagged) _steamLeft = 0;
        _scraper.Visible = !Spreading();
        if (_flipLeft > 0)
        {
            _flipLeft = Math.Max(0, _flipLeft - (float)delta);
            float arc = Mathf.Sin((1 - _flipLeft / .25f) * Mathf.Pi);
            _spatula.Position = SpatulaRect.Position.Lerp(TianjinWorkbenchLayout.EmbeddedSurface.GetCenter() + new Vector2(60, -30), arc);
            _spatula.RotationDegrees = -12 * arc;
        }
        QueueRedraw();
    }

    public void Flip()
    {
        if (Active() && !Reduced) _flipLeft = .25f;
    }

    public void ReceivePayment()
    {
        if (!Active() || Reduced || !IsVisibleInTree()) return;
        _pendantTween?.Kill(); _pendant.RotationDegrees = 0;
        _pendantTween = CreateTween().SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _pendantTween.TweenProperty(_pendant, "rotation_degrees", 2f, .09);
        _pendantTween.TweenProperty(_pendant, "rotation_degrees", -1f, .13);
        _pendantTween.TweenProperty(_pendant, "rotation_degrees", 0f, .18);
    }

    public void CompleteOrder(OrderBubbleView original, bool perfect)
    {
        if (!Active() || !IsVisibleInTree()) return;
        // A visual copy owns its own content and lifetime, never the customer's queue slot.
        var paper = original.CreatePaperCopy(this);
        if (paper is null) return;
        paper.ZAsRelative = false; paper.ZIndex = 86;
        var stamp = new TextureRect { Name = "CompletionStamp", MouseFilter = MouseFilterEnum.Ignore,
            Texture = GD.Load<Texture2D>($"res://resource/art/Global/HUDUI/{(perfect ? "Perfect 小星章" : "正确反馈小勾")}-天津.png"),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            Position = new Vector2(paper.Size.X - 66, Math.Max(2, paper.Size.Y - 61)), Size = new Vector2(54, 54) };
        // A plain overlay avoids PanelContainer including the stamp in the paper's minimum size.
        var overlay = new Control { MouseFilter = MouseFilterEnum.Ignore, ZAsRelative = false, ZIndex = 87, TopLevel = true };
        paper.AddChild(overlay); overlay.GlobalPosition = paper.GlobalPosition; overlay.AddChild(stamp);
        stamp.PivotOffset = stamp.Size * .5f;
        Tween tween = CreateTween();
        if (!Reduced) { stamp.Scale = Vector2.One * 1.12f; tween.TweenProperty(stamp, "scale", Vector2.One, .1); }
        tween.TweenInterval(Reduced ? .35 : .25);
        tween.TweenProperty(paper, "modulate:a", 0f, .18);
        tween.Parallel().TweenProperty(overlay, "modulate:a", 0f, .18);
        _papers.Add((paper, tween));
        tween.Finished += () => { _papers.RemoveAll(item => item.View == paper); paper.QueueFree(); };
        if (_papers.Count > 5) { var first = _papers[0]; first.Tween.Kill(); first.View.QueueFree(); _papers.RemoveAt(0); }
    }

    public void ResetMotion()
    {
        StopPaymentFeedback?.Invoke();
        _steamLeft = _flipLeft = 0;
        _pendantTween?.Kill(); _pendantTween = null;
        if (IsInstanceValid(_pendant)) _pendant.RotationDegrees = 0;
        if (IsInstanceValid(_scraper)) _scraper.Show();
        if (IsInstanceValid(_spatula)) { _spatula.Position = SpatulaRect.Position; _spatula.RotationDegrees = 0; }
        foreach (var item in _papers) { item.Tween.Kill(); item.View.QueueFree(); }
        _papers.Clear(); QueueRedraw();
    }

    public override void _ExitTree() => ResetMotion();

    public override void _Draw()
    {
        if (_steamLeft <= 0 || Reduced || !Active()) return;
        float t = 1 - _steamLeft / .85f;
        Vector2 center = TianjinWorkbenchLayout.EmbeddedSurface.GetCenter();
        for (int i = 0; i < 3; i++)
        {
            var points = new Vector2[12];
            for (int n = 0; n < points.Length; n++) points[n] = center + new Vector2((i - 1) * 42 + Mathf.Sin(n * .55f + i + t * 3) * 3,
                -12 - n * 2 - t * 25);
            DrawPolyline(points, new Color(1, .96f, .85f, .3f * Mathf.Sin(t * Mathf.Pi)), 2, true);
        }
    }
}
