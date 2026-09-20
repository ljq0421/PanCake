using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

/// <summary>One transient, captured frame; navigation and save callbacks remain synchronous.</summary>
public partial class JourneyTransition : CanvasLayer
{
    public enum Effect { Page, Curtain, OpenBook, CloseBook }
    private TextureRect _frame = null!;
    private ShaderMaterial _material = null!;
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

    public void Play(Effect effect, bool reverse = false, Rect2? bounds = null, DayController? day = null)
    {
        // A scene curtain owns this frame even when the destination builds its book or closes a dialog.
        if (_active && _effect == Effect.Curtain && effect != Effect.Curtain) return;
        Finish();
        if (Reduced || DisplayServer.GetName() == "headless") return;
        using var image = GetViewport().GetTexture().GetImage();
        if (image is null || image.IsEmpty()) return;
        _frame.Texture = ImageTexture.CreateFromImage(image);
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
        double duration = effect == Effect.Curtain ? .72 : effect == Effect.Page ? .52 : .32;
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
    public static void Watch(Control panel, Func<bool>? enabled = null, Func<Rect2>? bounds = null)
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
            For(panel).Play(visible ? Effect.OpenBook : Effect.CloseBook, bounds: bounds?.Invoke());
        };
    }
}
