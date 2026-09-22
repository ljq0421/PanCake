using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

/// <summary>Contextual, optional teaching. No tooltip windows or gameplay/save mutations.</summary>
public partial class InterfaceTeaching : CanvasLayer
{
    private Control _owner = null!, _canvas = null!, _previousFocus = null!;
    private InterfaceLesson[] _lessons = Array.Empty<InterfaceLesson>();
    private string _key = "";
    private JourneySettings? _settings;
    private Action<bool>? _pause;
    private Func<bool>? _eligible;
    private Panel _card = null!;
    private Label _title = null!, _body = null!, _progress = null!;
    private Button _next = null!, _previous = null!, _skip = null!;
    private InterfaceTeachingShade _shade = null!;
    private int _index;
    private bool _closed, _replay, _pauseHeld;
    internal int StepIndex => _index;
    internal int StepCount => _lessons.Length;
    internal string LessonKey => _key;
    internal string CurrentTitle => _lessons[_index].Title;

    internal static InterfaceTeaching? Offer(Control owner, string key, InterfaceLesson[] lessons,
        Func<bool>? eligible = null, Action<bool>? pause = null, bool replay = false)
    {
        var settings = owner.GetNodeOrNull<JourneySettings>("/root/JourneySettings");
        if (!replay && (settings is null || settings.HasSeenInterfaceLesson(key))) return null;
        if (owner.GetNodeOrNull<InterfaceTeaching>("InterfaceTeaching") is { } existing) return existing;
        var guide = new InterfaceTeaching { Name = "InterfaceTeaching", Layer = 220,
            _owner = owner, _key = key, _lessons = lessons, _settings = settings,
            _eligible = eligible, _pause = pause, _replay = replay };
        owner.AddChild(guide);
        return guide;
    }

    public override void _Ready()
    {
        Callable.From(() => ButtonHoverFeedback.AttachTree(this)).CallDeferred();
        Hide();
        _previousFocus = GetViewport().GuiGetFocusOwner();
        _canvas = new Control { Name = "TeachingCanvas", Size = new(1920, 1080), MouseFilter = Control.MouseFilterEnum.Stop };
        AddChild(_canvas);
        _shade = new InterfaceTeachingShade { Size = _canvas.Size, MouseFilter = Control.MouseFilterEnum.Ignore };
        _canvas.AddChild(_shade);
        _card = new Panel { Name = "TeachingCard", Position = new(510, 640), Size = new(900, 360) };
        TianjinTeachingUi.ApplyPanel(_card); _canvas.AddChild(_card);
        _title = LabelAt("TeachingTitle", new(64, 30, 700, 52), 34);
        _progress = LabelAt("TeachingProgress", new(733, 37, 98, 40), 23);
        _body = LabelAt("TeachingText", new(64, 103, 772, 137), 27);
        TeachingEmphasis.Attach(_body);
        _skip = Action("SkipTeaching", "跳过教学", new(60, 267, 190, 62), () => Close(true));
        _previous = Action("PreviousTeaching", "上一步", new(336, 267, 180, 62), () => { _index--; Refresh(); });
        _next = Action("NextTeaching", "下一步", new(592, 267, 244, 62), Next);
        _owner.VisibilityChanged += OwnerVisibilityChanged;
        GetViewport().SizeChanged += Fit;
        Fit();
    }
    // Wait for the real page's entrance and cooking tutorial; never stack teaching modals.
    public override void _Process(double delta)
    {
        if (_closed) return;
        if (!_owner.IsVisibleInTree()) { if (Visible) Close(false); return; }
        if (!Visible)
        {
            if (JourneyTransition.InScope(_owner) && JourneyTransition.For(this).Active) return;
            if (_eligible?.Invoke() == false) return;
            if (_pause is not null) { _pause(true); _pauseHeld = true; }
            Show(); Refresh();
            if (JourneyTransition.InScope(_owner)) JourneyTransition.For(this).Play(JourneyTransition.Effect.OpenBook,
                bounds: new Rect2(_card.GetGlobalTransformWithCanvas().Origin, _card.Size * _canvas.Scale));
        }
        UpdateSpotlight();
    }
    private void OwnerVisibilityChanged() { if (!_owner.IsVisibleInTree()) Close(false); }
    private void Fit()
    {
        Vector2 size = GetViewport().GetVisibleRect().Size;
        float scale = Math.Min(size.X / 1920, size.Y / 1080);
        _canvas.Scale = Vector2.One * scale; _canvas.Position = (size - _canvas.Size * scale) / 2;
    }
    private Control? Target()
    {
        if (_replay || _lessons[_index].Target.Length == 0) return null;
        return _owner.FindChild(_lessons[_index].Target, true, false) as Control;
    }
    private void UpdateSpotlight()
    {
        Control? target = Target();
        Rect2? rect = null;
        if (target is not null && target.IsVisibleInTree())
        {
            Transform2D transform = _canvas.GetGlobalTransformWithCanvas().AffineInverse() * target.GetGlobalTransformWithCanvas();
            Vector2 start = transform * Vector2.Zero, end = transform * target.Size;
            rect = new Rect2(start, end - start).Grow(10);
        }
        _shade.Spotlight = rect;
        _card.Position = new((1920 - _card.Size.X) / 2,
            rect?.GetCenter().Y > 540 ? 110 : Math.Min(640, 1000 - _card.Size.Y));
        if (_replay) _card.Position = (new Vector2(1920, 1080) - _card.Size) / 2;
        _shade.QueueRedraw();
    }
    private void Refresh()
    {
        _title.Text = _lessons[_index].Title; _body.Text = _lessons[_index].Text;
        _progress.Text = $"{_index + 1} / {_lessons.Length}";
        _previous.Disabled = _index == 0;
        _next.Text = _index + 1 == _lessons.Length ? "记住了" : "下一步";
        _skip.Text = _replay ? "返回帮助" : "跳过教学";
        LayoutCard();
        _next.GrabFocus(); UpdateSpotlight();
    }
    private void LayoutCard()
    {
        const float padding = 60, gap = 24, buttonHeight = 62;
        var buttons = new[] { _skip, _previous, _next };
        float[] widths = buttons.Select(b => TeachingCardLayout.ButtonWidth(b, 170)).ToArray();
        float buttonRow = widths.Sum() + gap * 2;
        float width = Mathf.Clamp(Mathf.Max(TeachingCardLayout.NaturalWidth(_body), buttonRow) + padding * 2, 690, 900);
        float inner = width - padding * 2;
        float titleHeight = TeachingCardLayout.Place(_title, padding, 40, inner - 110);
        TeachingCardLayout.Place(_progress, width - padding - 86, 46, 86);
        float bodyY = 40 + titleHeight + 16;
        float bodyHeight = TeachingCardLayout.Place(_body, padding, bodyY, inner);
        float actionY = bodyY + bodyHeight + 24;
        float spacing = (inner - widths.Sum()) / 2, x = padding;
        for (int i = 0; i < buttons.Length; i++)
        {
            TeachingCardLayout.PlaceButton(buttons[i], new(x, actionY), new(widths[i], buttonHeight));
            x += widths[i] + spacing;
        }
        _card.Size = new(width, actionY + buttonHeight + 26);
    }
    private void Next() { if (_index + 1 == _lessons.Length) Close(true); else { _index++; Refresh(); } }
    internal void Close(bool acknowledge)
    {
        if (_closed) return;
        if (Visible && _owner.IsVisibleInTree() && JourneyTransition.InScope(_owner))
            JourneyTransition.For(this).Play(JourneyTransition.Effect.CloseBook,
                bounds: new Rect2(_card.GetGlobalTransformWithCanvas().Origin, _card.Size * _canvas.Scale));
        _closed = true;
        if (acknowledge && !_replay) _settings?.MarkInterfaceLessonSeen(_key);
        ReleasePause(); Hide();
        if (IsInstanceValid(_previousFocus) && _previousFocus.IsVisibleInTree()) _previousFocus.GrabFocus();
        QueueFree();
    }
    private void ReleasePause() { if (_pauseHeld) { _pauseHeld = false; _pause?.Invoke(false); } }
    public override void _ExitTree()
    {
        ReleasePause();
        if (IsInstanceValid(_owner)) _owner.VisibilityChanged -= OwnerVisibilityChanged;
        GetViewport().SizeChanged -= Fit;
    }
    public override void _Input(InputEvent input)
    {
        if (!Visible || _closed || input is not InputEventKey { Pressed: true, Echo: false } key) return;
        GetViewport().SetInputAsHandled();
        if (key.Keycode == Key.Escape) Close(true);
        else if (key.Keycode is Key.Enter or Key.Space)
        {
            if (_skip.HasFocus()) Close(true);
            else if (_previous.HasFocus() && !_previous.Disabled) { _index--; Refresh(); }
            else Next();
        }
        else if (key.Keycode is Key.Tab or Key.Left or Key.Right or Key.Up or Key.Down)
        {
            var buttons = new[] { _skip, _previous, _next }.Where(b => !b.Disabled).ToArray();
            int index = Array.FindIndex(buttons, b => b.HasFocus());
            int direction = key.ShiftPressed || key.Keycode is Key.Left or Key.Up ? -1 : 1;
            buttons[(index + direction + buttons.Length) % buttons.Length].GrabFocus();
        }
    }
    private Label LabelAt(string name, Rect2 rect, int size)
    {
        var label = new Label { Name = name, Position = rect.Position, Size = rect.Size,
            AutowrapMode = TextServer.AutowrapMode.WordSmart, MouseFilter = Control.MouseFilterEnum.Ignore };
        label.AddThemeFontSizeOverride("font_size", size); label.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        _card.AddChild(label); return label;
    }
    private Button Action(string name, string caption, Rect2 rect, Action action)
    {
        var button = new Button { Name = name, Text = caption };
        _card.AddChild(TianjinTeachingUi.ActionFrame(button, rect.Position, rect.Size));
        button.AddThemeFontSizeOverride("font_size", 24); button.Pressed += action; return button;
    }
}

internal partial class InterfaceTeachingShade : Control
{
    internal Rect2? Spotlight;
    public override void _Draw()
    {
        var dim = new Color(.10f, .07f, .03f, .50f);
        if (Spotlight is not { } hole) { DrawRect(new Rect2(Vector2.Zero, Size), dim); return; }
        hole = hole.Intersection(new Rect2(Vector2.Zero, Size));
        DrawRect(new(0, 0, Size.X, hole.Position.Y), dim);
        DrawRect(new(0, hole.End.Y, Size.X, Size.Y - hole.End.Y), dim);
        DrawRect(new(0, hole.Position.Y, hole.Position.X, hole.Size.Y), dim);
        DrawRect(new(hole.End.X, hole.Position.Y, Size.X - hole.End.X, hole.Size.Y), dim);
        DrawRect(hole, new Color("#FFD779"), false, 3);
    }
}
