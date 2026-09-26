using Godot;
using ProjectCake.Orders;

namespace ProjectCake.UI;

/// <summary>Short, non-interactive feedback at the order or the action's position.</summary>
public partial class BusinessSceneFeedback : Control
{
    private readonly string _city;
    private readonly Func<bool> _active;
    private readonly List<(Control View, Tween? Tween, double Left)> _items = new();
    private ulong? _lastErrorAt;
    internal Func<ulong> Clock { get; set; } = Time.GetTicksMsec;
    internal const ulong ErrorIntervalMs = 1500;
    public BusinessSceneFeedback(string city, Func<bool> active) { _city = city; _active = active; Name = "SceneFeedback"; }
    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore; ZIndex = 90;
        TextureFilter = TextureFilterEnum.LinearWithMipmaps;
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
    }
    public override void _Process(double delta)
    {
        if (!IsVisibleInTree() || !_active()) { Clear(); return; }
        for (int i = _items.Count - 1; i >= 0; i--)
        {
            var item = _items[i]; item.Left -= delta;
            if (item.Left <= 0) { item.Tween?.Kill(); item.View.QueueFree(); _items.RemoveAt(i); }
            else _items[i] = item;
        }
    }
    public void Clear()
    {
        foreach (var item in _items) { item.Tween?.Kill(); item.View.QueueFree(); }
        _items.Clear();
        _lastErrorAt = null;
    }
    public void Delivery(DeliveryEvaluation result, Control target)
    {
        bool error = result.Grade is DeliveryGrade.Rejected or DeliveryGrade.Incorrect;
        Show(error ? "错误反馈叉" : result.Grade == DeliveryGrade.Perfect ? "Perfect 小星章" : "正确反馈小勾",
            target.GetGlobalRect().Position + new Vector2(target.GetGlobalRect().Size.X * .65f, 24),
            error ? result.Message : null);
    }
    public void Report(string message, bool error, Vector2 globalPosition, bool essential = false)
    {
        if (string.IsNullOrWhiteSpace(message)) return;
        if (message.StartsWith("铺门打开") || message.StartsWith("开始营业")) return;
        // Legacy workstations report stock notices as informational, not failed actions.
        bool instruction = message.Contains("用完") || message.Contains("补满") || message.Contains("请")
            || message.Contains("按住") || message.Contains("拖进") || message.Contains("先");
        string art = error ? "错误反馈叉" : message.Contains("翻面成功") && _city != "西安" ? "翻面成功图标" : "正确反馈小勾";
        // Tianjin and Wuhan reserve checkmarks for customer deliveries.
        if (_city is "天津" or "武汉" && art == "正确反馈小勾" && !essential && !instruction) return;
        Show(!error && (essential || instruction) ? "" : art, globalPosition, error || essential || instruction ? message : null);
    }
    public void Flip(Vector2 globalPosition) => Show("翻面成功图标", globalPosition);
    private void Show(string art, Vector2 globalPosition, string? text = null)
    {
        if (!IsVisibleInTree() || !_active()) return;
        if (art == "错误反馈叉")
        {
            ulong now = Clock();
            if (_lastErrorAt is ulong last && now - last < ErrorIntervalMs) return;
            _lastErrorAt = now;
        }
        if (_items.Count >= 4)
        {
            _items[0].Tween?.Kill(); _items[0].View.QueueFree(); _items.RemoveAt(0);
        }
        var view = new Control { MouseFilter = MouseFilterEnum.Ignore, Size = new(text is null ? 64 : 340, text is null ? 64 : 130) };
        Vector2 local = GetGlobalTransform().AffineInverse() * globalPosition;
        view.Position = new(Math.Clamp(local.X - view.Size.X / 2, 16, Math.Max(16, Size.X - view.Size.X - 16)),
            Math.Clamp(local.Y - 68, 140, Math.Max(140, Size.Y - view.Size.Y - 16)));
        AddChild(view);
        string suffix = art == "错误反馈叉" ? "" : $"-{_city}";
        var icon = new TextureRect { ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            Texture = art.Length == 0 ? null : GD.Load<Texture2D>($"res://resource/art/Global/HUDUI/{art}{suffix}.png"),
            Position = new((view.Size.X - 64) / 2, 0), Size = new(64, 64), MouseFilter = MouseFilterEnum.Ignore,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered };
        view.AddChild(icon);
        if (text is not null)
        {
            var label = TianjinUi.Label(text, 20, art == "错误反馈叉" ? new Color("#782F24") : TianjinUi.BrownText, HorizontalAlignment.Center);
            label.Position = new(0, art.Length == 0 ? 0 : 64); label.Size = new(340, 0); label.AutowrapMode = TextServer.AutowrapMode.WordSmart;
            label.MouseFilter = MouseFilterEnum.Ignore;
            label.AddThemeColorOverride("font_outline_color", TianjinUi.Paper); label.AddThemeConstantOverride("outline_size", 7);
            view.AddChild(label);
        }
        Tween? tween = null;
        if (!ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool())
        {
            icon.PivotOffset = new(32, 32); icon.Scale = Vector2.One * .8f;
            tween = CreateTween().SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(icon, "scale", Vector2.One, .12);
        }
        _items.Add((view, tween, text is null ? .85 : 3.2));
    }
}
