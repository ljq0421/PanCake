using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

/// <summary>One transient, captured frame; navigation and save callbacks remain synchronous.</summary>
public partial class JourneyTransition : CanvasLayer
{
    public enum Effect { Page, Curtain, OpenBook, CloseBook, TurnBookOpen, TurnBookClose, SpreadOpen, SpreadClose }
    private TextureRect _frame = null!;
    private ShaderMaterial _material = null!;
    private ImageTexture? _settingsMask;
    private ImageTexture? _ledgerMask;
    private Tween? _tween;
    private DayController? _day;
    private bool _active;
    private Effect _effect;
    public bool Active => _active;
    public static bool Reduced => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();
    public static bool InScope(Node node)
    {
        for (Node? current = node; current is not null; current = current.GetParent())
            if (current is StartScreen or ProjectCake.Gameplay.TianjinDayScreen or ProjectCake.Gameplay.WuhanDayScreen) return true;
        return false;
    }

    public static JourneyTransition For(Node owner)
    {
        var root = owner.GetTree().Root;
        var motion = root.GetNodeOrNull<JourneyTransition>("JourneyTransition");
        if (motion is not null) return motion;
        motion = new JourneyTransition { Name = "JourneyTransition", Layer = 120, ProcessMode = ProcessModeEnum.Always };
        root.AddChild(motion);
        return motion;
    }

    public override void _Ready()
    {
        Layer = 300; ProcessMode = ProcessModeEnum.Always;
        _material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/journey_transition.gdshader") };
        _frame = new TextureRect { Name = "TransitionFrame", Material = _material,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, MouseFilter = Control.MouseFilterEnum.Stop };
        AddChild(_frame); _frame.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        _frame.Hide();
        GetViewport().SizeChanged += Finish;
    }

    public void Play(Effect effect, bool reverse = false, Rect2? bounds = null, DayController? day = null, bool ledger = false)
    {
        // A scene curtain owns this frame even when the destination builds its book or closes a dialog.
        if (_active && _effect == Effect.Curtain && effect != Effect.Curtain) return;
        Finish();
        if (Reduced || DisplayServer.GetName() == "headless") return;
        using var image = GetViewport().GetTexture().GetImage();
        if (image is null || image.IsEmpty()) return;
        _frame.Texture = ImageTexture.CreateFromImage(image);
        _material.Shader = GD.Load<Shader>(effect is Effect.SpreadOpen or Effect.SpreadClose
            ? "res://resource/shaders/settings_book_fold.gdshader"
            : "res://resource/shaders/journey_transition.gdshader");
        if (effect is Effect.SpreadOpen or Effect.SpreadClose)
        {
            PrepareBookMask(ledger);
            _material.SetShaderParameter("backdrop", ledger ? new Color(.12f, .08f, .04f, .4f) : new Color(.15f, .1f, .06f, .65f));
        }
        Vector2 size = GetViewport().GetVisibleRect().Size;
        Rect2 area = bounds ?? new Rect2(Vector2.Zero, size);
        _material.SetShaderParameter("area", new Vector4(area.Position.X / size.X, area.Position.Y / size.Y, area.Size.X / size.X, area.Size.Y / size.Y));
        _material.SetShaderParameter("effect", (int)effect);
        _material.SetShaderParameter("reverse_turn", reverse);
        _material.SetShaderParameter("progress", 0f);
        _effect = effect; _active = true; _frame.Show();
        // Godot dispatches _Input in reverse tree order, before GUI mouse filtering.
        GetParent().MoveChild(this, -1);
        _day = day ?? FindActiveDay(GetTree().Root);
        if (_day is not null) { _day.SetPauseReason("journey-transition", true); _day.DayPrepared += KeepPause; }
        double duration = effect == Effect.Curtain ? .72
            : effect is Effect.Page or Effect.TurnBookOpen or Effect.TurnBookClose or Effect.SpreadOpen or Effect.SpreadClose ? .52 : .32;
        _tween = CreateTween();
        _tween.TweenMethod(Callable.From<float>(SetProgress), 0f, 1f, duration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _tween.TweenCallback(Callable.From(Finish));
    }

    private static DayController? FindActiveDay(Node node)
    {
        if (node is DayController day) return day;
        foreach (Node child in node.GetChildren())
            if (FindActiveDay(child) is { } found) return found;
        return null;
    }

    private void PrepareBookMask(bool ledger)
    {
        ImageTexture? mask = ledger ? _ledgerMask : _settingsMask;
        if (mask is null)
        {
            // Match HomeArt's alpha crop, then its KeepAspectCentered placement.
            using var source = GD.Load<Texture2D>("res://resource/art/Global/StartPage/旅行手账双页母版.png").GetImage();
            source.Convert(Image.Format.Rgba8);
            byte[] pixels = source.GetData();
            int width = source.GetWidth(), height = source.GetHeight();
            int left = width, top = height, right = 0, bottom = 0;
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
                if (pixels[(y * width + x) * 4 + 3] >= (ledger ? 32 : 128))
                {
                    left = Math.Min(left, x); top = Math.Min(top, y);
                    right = Math.Max(right, x); bottom = Math.Max(bottom, y);
                }
            using var cropped = source.GetRegion(new Rect2I(left, top, right - left + 1, bottom - top + 1));
            mask = ImageTexture.CreateFromImage(cropped);
            if (ledger) _ledgerMask = mask; else _settingsMask = mask;
        }
        Vector2 size = mask.GetSize();
        float scale = Math.Min(StartScreen.BookBounds.Size.X / size.X, StartScreen.BookBounds.Size.Y / size.Y);
        Vector2 fit = size * scale / StartScreen.BookBounds.Size;
        _material.SetShaderParameter("book_mask", mask);
        _material.SetShaderParameter("mask_fit", new Vector4((1 - fit.X) / 2, (1 - fit.Y) / 2, fit.X, fit.Y));
    }

    internal void SetProgress(float value) => _material.SetShaderParameter("progress", value);
    private void KeepPause(ProjectCake.Data.DayConfig config) => _day?.SetPauseReason("journey-transition", true);
    internal void HoldForCapture(float value) { _tween?.Pause(); SetProgress(value); }
    public void Finish()
    {
        _tween?.Kill(); _tween = null; _active = false;
        if (IsInstanceValid(_day)) { _day!.DayPrepared -= KeepPause; _day.SetPauseReason("journey-transition", false); }
        _day = null;
        if (_frame is not null) { _frame.Hide(); _frame.Texture = null; }
    }
    public override void _Input(InputEvent input)
    {
        if (_active) GetViewport().SetInputAsHandled();
    }
    public override void _Process(double delta)
    {
        if (_active && Reduced) Finish();
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) Finish();
    }
    public override void _ExitTree()
    {
        GetViewport().SizeChanged -= Finish;
        Finish();
    }

    /// <summary>Visibility belongs to the host; the previous rendered frame supplies the closing sheet.</summary>
    public static void Watch(Control panel, Func<bool>? enabled = null, Func<Rect2>? bounds = null, Func<bool>? book = null, bool ledger = false)
    {
        if (panel.HasMeta("journey_motion")) return;
        panel.SetMeta("journey_motion", true);
        bool shown = panel.IsVisibleInTree();
        panel.VisibilityChanged += () =>
        {
            bool visible = panel.IsVisibleInTree();
            if (visible == shown) return;
            shown = visible;
            if (!panel.IsInsideTree() || panel.GetParent() is CanvasItem parent && !parent.IsVisibleInTree()
                || enabled?.Invoke() == false) return;
            Effect effect = book?.Invoke() == true
                ? (visible ? Effect.SpreadOpen : Effect.SpreadClose)
                : (visible ? Effect.OpenBook : Effect.CloseBook);
            For(panel).Play(effect, bounds: bounds?.Invoke(), ledger: ledger);
        };
    }
}
