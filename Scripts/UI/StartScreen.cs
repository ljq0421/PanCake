using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

/// <summary>The journey starts here; the cover remains independent of the city roster.</summary>
public partial class StartScreen : Control
{
    public event Action? NewGameRequested;
    public event Action? ContinueRequested;
    public event Action? QuitRequested;
    private SaveService? _save;
    private Control _canvas = null!, _confirmation = null!;
    private Button _newGame = null!, _continue = null!, _quit = null!, _cancel = null!, _confirm = null!;
    private Label _status = null!, _confirmationText = null!;
    private bool _busy;
    private Tween? _entrance;
    private Window.ContentScaleAspectEnum _previousAspect;
    private bool _ownsAspect;
    private readonly Dictionary<Button, Tween> _buttonTweens = new();
    public bool ConfirmationOpen => _confirmation.Visible;

    public override void _Ready()
    {
        Theme = StartScreenTheme.Create();
        _canvas = GetNode<Control>("Canvas");
        _confirmation = GetNode<Control>("Canvas/Confirmation");
        _newGame = GetNode<Button>("%NewGame");
        _continue = GetNode<Button>("%Continue");
        _quit = GetNode<Button>("%Quit");
        _cancel = GetNode<Button>("%Cancel");
        _confirm = GetNode<Button>("%Confirm");
        _status = GetNode<Label>("%Status");
        _confirmationText = GetNode<Label>("%ConfirmationText");
        GetNode<Panel>("Canvas/Confirmation/Panel").AddThemeStyleboxOverride("panel", StartScreenTheme.Box(StartScreenTheme.Cream, 4, true));
        GetNode<Label>("%Title").AddThemeColorOverride("font_color", StartScreenTheme.Teal);
        GetNode<Label>("%Subtitle").AddThemeColorOverride("font_color", StartScreenTheme.Muted);
        _status.AddThemeColorOverride("font_color", StartScreenTheme.Brick);
        StartScreenTheme.Apply(_cancel);
        StartScreenTheme.Apply(_confirm, destructive: true);
        foreach (Button button in new[] { _newGame, _continue, _quit, _cancel, _confirm })
        {
            button.MouseDefaultCursorShape = CursorShape.PointingHand;
            button.ButtonDown += () => AnimateButton(button, 0.98f);
            button.ButtonUp += () => AnimateButton(button, 1f);
        }
        _newGame.Pressed += RequestNewGame;
        _continue.Pressed += () =>
        {
            if (_busy || ConfirmationOpen || !IsVisibleInTree() || _save?.CanContinue != true) return;
            _busy = true; Refresh(); ContinueRequested?.Invoke();
        };
        _quit.Pressed += () =>
        {
            if (_busy || ConfirmationOpen || !IsVisibleInTree()) return;
            _busy = true; QuitRequested?.Invoke();
        };
        _cancel.Pressed += CloseConfirmation;
        _confirm.Pressed += () => { if (ConfirmationOpen && !_busy) DispatchNewGame(); };
        Resized += FitCanvas;
        VisibilityChanged += UpdateWindowAspect;
        UpdateWindowAspect();
        FitCanvas();
        Refresh();
    }

    public void Initialize(SaveService save)
    {
        if (_save is not null) _save.Changed -= Refresh;
        _save = save;
        _save.Changed += Refresh;
        Refresh();
    }

    public void Present()
    {
        _busy = false;
        _confirmation.Hide();
        Show();
        Refresh();
        FocusPrimary();
        _entrance?.Kill();
        _canvas.Modulate = new Color(1, 1, 1, 0);
        _entrance = CreateTween();
        _entrance.TweenProperty(_canvas, "modulate:a", 1f, 0.25).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
    }

    public void ShowError(string message)
    {
        _busy = false;
        _confirmation.Hide();
        Refresh();
        _status.Text = message.StartsWith("保存失败", StringComparison.Ordinal)
            ? "保存失败：请检查存档写入权限和\n可用空间后重试。" + (_save?.RequiresNewGameConfirmation == true ? "\n原有进度已保留。" : string.Empty)
            : message;
        FocusPrimary();
    }

    private void RequestNewGame()
    {
        if (_busy || ConfirmationOpen || !IsVisibleInTree() || _save is null) return;
        if (!_save.RequiresNewGameConfirmation) { DispatchNewGame(); return; }
        _confirmationText.Text = _save.HasLoadError
            ? "存档无法读取。重新开始将覆盖现有存档，\n清空所有城市进度、金币和设备升级。\n是否重新开始？"
            : "开始新游戏将清空所有城市的营业进度、\n金币和设备升级。\n是否重新开始？";
        _confirmation.Show();
        Refresh();
        _cancel.GrabFocus();
    }

    private void DispatchNewGame()
    {
        _busy = true;
        _confirmation.Hide();
        Refresh();
        NewGameRequested?.Invoke();
    }

    private void CloseConfirmation()
    {
        if (_busy) return;
        _confirmation.Hide();
        Refresh();
        _newGame.GrabFocus();
    }

    private void Refresh()
    {
        if (_newGame is null) return;
        bool canContinue = _save?.CanContinue == true;
        bool blocked = _busy || ConfirmationOpen;
        _newGame.Disabled = blocked || _save is null;
        _continue.Disabled = blocked || !canContinue;
        _quit.Disabled = blocked;
        _continue.Text = canContinue ? "继续游戏" : _save?.HasLoadError == true ? "继续游戏 · 无法读取" : "继续游戏 · 暂无存档";
        StartScreenTheme.Apply(_newGame, !canContinue);
        StartScreenTheme.Apply(_continue, canContinue);
        StartScreenTheme.Apply(_quit);
        _status.Text = _save?.HasLoadError == true ? "存档无法读取。可选择“开始游戏”\n确认重新开局。" : string.Empty;
    }

    private void FocusPrimary() { if (IsVisibleInTree()) (_save?.CanContinue == true ? _continue : _newGame).GrabFocus(); }

    private void FitCanvas()
    {
        if (_canvas is null) return;
        float scale = Math.Min(Size.X / 1920f, Size.Y / 1080f);
        _canvas.Scale = Vector2.One * scale;
        _canvas.Position = (Size - new Vector2(1920, 1080) * scale) / 2;
    }

    private void UpdateWindowAspect()
    {
        // Draw the title's letterbox inside its own viewport; city pages keep their original stretch mode.
        if (IsVisibleInTree() && !_ownsAspect)
        {
            _previousAspect = GetWindow().ContentScaleAspect;
            _ownsAspect = true;
            GetWindow().ContentScaleAspect = Window.ContentScaleAspectEnum.Expand;
        }
        else if (!IsVisibleInTree() && _ownsAspect)
        {
            GetWindow().ContentScaleAspect = _previousAspect;
            _ownsAspect = false;
        }
    }

    private void AnimateButton(Button button, float scale)
    {
        if (_buttonTweens.Remove(button, out Tween? previous)) previous.Kill();
        button.PivotOffset = button.Size / 2;
        Tween tween = CreateTween();
        _buttonTweens[button] = tween;
        tween.TweenProperty(button, "scale", Vector2.One * scale, 0.12).SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
    }

    public override void _Input(InputEvent input)
    {
        if (!IsVisibleInTree() || _busy || input is not InputEventKey key || !key.Pressed || key.Echo) return;
        if (key.Keycode == Key.Escape && ConfirmationOpen)
        {
            CloseConfirmation(); GetViewport().SetInputAsHandled(); return;
        }
        if (key.Keycode is not (Key.Tab or Key.Up or Key.Down or Key.Left or Key.Right)) return;
        Button[] candidates = ConfirmationOpen ? new[] { _cancel, _confirm } : new[] { _newGame, _continue, _quit };
        Button[] enabled = candidates.Where(button => !button.Disabled).ToArray();
        if (enabled.Length == 0) return;
        int current = Array.IndexOf(enabled, GetViewport().GuiGetFocusOwner());
        int direction = key.Keycode is Key.Up or Key.Left || key.Keycode == Key.Tab && key.ShiftPressed ? -1 : 1;
        enabled[(current + direction + enabled.Length) % enabled.Length].GrabFocus();
        GetViewport().SetInputAsHandled();
    }

    public override void _ExitTree()
    {
        if (_ownsAspect) { GetWindow().ContentScaleAspect = _previousAspect; _ownsAspect = false; }
        if (_save is not null) _save.Changed -= Refresh;
        _entrance?.Kill();
        foreach (Tween tween in _buttonTweens.Values) tween.Kill();
    }
}
