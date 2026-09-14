using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public enum JourneyPage { Splash, Home, Opening, NewJourney, Continue, Map, City, Completion, Ledger, Upgrades }

/// <summary>Travel navigation uses a single fitted canvas, independent of gameplay views.</summary>
public partial class StartScreen : Control
{
    public event Action? NewGameRequested;
    public event Action? ContinueRequested;
    public event Action? QuitRequested;
    public JourneyPage Page { get; private set; }
    public bool ConfirmationOpen => ModalOpen && _modalKind == "confirm";
    public bool ModalOpen => _modal is not null && _modal.Visible;
    public bool DeveloperToolsVisible => OS.GetCmdlineUserArgs().Contains("--dev-ui");
    private SaveService? _save;
    private JourneySettings _settings = null!;
    private Control _canvas = null!, _body = null!, _modal = null!;
    private Label _status = null!;
    private string _city = JourneyModel.Cities[0].Id, _modalKind = "", _error = "";
    private string? _completedCity;
    private bool _busy, _started, _ownsAspect;
    private Action? _mapReturn;
    private Window.ContentScaleAspectEnum _previousAspect;
    private readonly List<Tween> _tweens = new();
    private readonly Dictionary<Control, Tween> _hoverTweens = new();
    private readonly List<Button> _buttons = new();
    private readonly List<Control> _modalControls = new();
    private Control? _previousFocus;
    private Button? _audioButton;
    private Label? _settingsMessage, _countdown;
    private Control? _displayConfirmation;
    private readonly Dictionary<string, Texture2D> _textures = new();

    public override void _Ready()
    {
        Theme = StartScreenTheme.Create();
        _settings = GetNode<JourneySettings>("/root/JourneySettings");
        _settings.Changed += SettingsChanged;
        _canvas = GetNode<Control>("Canvas");
        _body = GetNode<Control>("Canvas/Page");
        _modal = GetNode<Control>("Canvas/Modal");
        Resized += FitCanvas; VisibilityChanged += UpdateVisibility; FitCanvas(); UpdateVisibility();
    }
    public void Initialize(SaveService save)
    {
        if (_save is not null) _save.Changed -= SaveChanged;
        _save = save; _save.Changed += SaveChanged;
    }
    private void SaveChanged() { if (!IsVisibleInTree() || _busy) return; if (Page == JourneyPage.Home) RenderHome(); else if (Page is JourneyPage.City or JourneyPage.Ledger or JourneyPage.Upgrades) RefreshCityPage(); }
    public void Present() { Show(); if (!_started) { _started = true; RenderSplash(); } else RenderHome(); }
    public void PresentHome() { Show(); RenderHome(); }
    public void PresentMap(Action? returnToSource = null) { Show(); _mapReturn = returnToSource ?? RenderHome; _city = _save?.ContinueCityId ?? JourneyModel.Cities[0].Id; RenderMap(); }
    public void PresentCompletion(string cityId, Action returnToSource)
    { Show(); _mapReturn = returnToSource; _completedCity = cityId; RenderCompletion(); }
    public void ShowError(string message)
    {
        _busy = false; CloseModal();
        _error = message.StartsWith("保存失败", StringComparison.Ordinal) ? "保存失败：请检查写入权限和可用空间。原有进度已保留。" : message; SetStatus();
    }
    private void SetStatus()
    {
        if (_status is not null) _status.Text = _error.Length > 0 ? _error : _save?.HasLoadError == true ? "存档无法读取。可在新的旅程中确认重新开局。" : "";
    }
    private void Begin(JourneyPage page)
    {
        CloseModal(); KillAnimations(); Clear(_body); _buttons.Clear(); _audioButton = null;
        Page = page; _busy = false; _error = "";
        _body.Modulate = Colors.White;
        if (page is JourneyPage.NewJourney or JourneyPage.Continue or JourneyPage.City)
        {
            _body.Modulate = new Color(1, 1, 1, .6f);
            var fade = CreateTween(); _tweens.Add(fade);
            fade.TweenProperty(_body, "modulate:a", 1f, .25).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
        }
        if (page is JourneyPage.Opening)
            _body.AddChild(new ColorRect { Size = new(1920, 1080), Color = new Color(.23f, .15f, .08f, .36f), MouseFilter = MouseFilterEnum.Ignore });
        _status = Text(_body, "Status", "", new(340, 1006, 1240, 60), 23, true);
        _status.AddThemeColorOverride("font_color", StartScreenTheme.Cream); SetStatus();
    }
    private static void Clear(Node parent)
    { foreach (Node child in parent.GetChildren()) { parent.RemoveChild(child); child.QueueFree(); } }
    private void Focus(string name)
    { (_body.Descendants<Button>().FirstOrDefault(b => b.Name == name && !b.Disabled) ?? _buttons.FirstOrDefault(b => !b.Disabled))?.GrabFocus(); }
    private void Chrome(Action back, string title)
    {
        var previous = Button(_body, "Back", "", new(72, 48, 140, 62), back, bare: true);
        Art(previous, "账本翻页箭头｜左", new(0, 7, 55, 48));
        Text(previous, "Caption", "返回", new(62, 0, 78, 62), 25);
        Text(_body, "PageTitle", title, new(350, 38, 1220, 76), 42, true).AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        Button(_body, "Home", "首页", new(1690, 48, 140, 62), RenderHome);
    }
    private void Utilities()
    {
        if (Page == JourneyPage.Home)
        {
            HomeUtility("Settings", "设置", "设置图标", 1540, OpenSettings);
            HomeUtility("Help", "帮助", "帮助图标", 1664, OpenHelp);
            HomeUtility("Quit", "退出", "返回主界面图标", 1788, () => { _busy = true; QuitRequested?.Invoke(); });
            return;
        }
        Utility("Settings", "设置", "设置图标", 1390, OpenSettings);
        _audioButton = Utility("Audio", _settings.Muted ? "已静音" : "声音", _settings.Muted ? "音效关闭" : "音效开启", 1506, _settings.ToggleMute);
        Utility("Help", "帮助", "帮助图标", 1622, OpenHelp);
        Utility("Quit", "退出", "返回主界面图标", 1738, () => { _busy = true; QuitRequested?.Invoke(); });
    }
    private void Schedule(double seconds, Action action)
    { var t = CreateTween(); _tweens.Add(t); t.TweenInterval(seconds); t.TweenCallback(Callable.From(action)); }
    private void KillAnimations()
    {
        foreach (var t in _tweens) t.Kill(); _tweens.Clear();
        foreach (var t in _hoverTweens.Values) t.Kill(); _hoverTweens.Clear();
    }
    private void FitCanvas()
    {
        if (_canvas is null) return; float scale = Math.Min(Size.X / 1920, Size.Y / 1080);
        _canvas.Scale = Vector2.One * scale; _canvas.Position = (Size - new Vector2(1920, 1080) * scale) / 2;
    }
    private void UpdateVisibility()
    {
        if (IsVisibleInTree() && !_ownsAspect) { _previousAspect = GetWindow().ContentScaleAspect; _ownsAspect = true; GetWindow().ContentScaleAspect = Window.ContentScaleAspectEnum.Expand; }
        else if (!IsVisibleInTree())
        {
            KillAnimations(); CloseModal();
            if (_ownsAspect) { GetWindow().ContentScaleAspect = _previousAspect; _ownsAspect = false; }
        }
    }
    public override void _Input(InputEvent input)
    {
        if (!IsVisibleInTree() || _busy) return;
        if (Page == JourneyPage.Splash && input is InputEventMouseButton { Pressed: true }) { RenderHome(); GetViewport().SetInputAsHandled(); return; }
        if (input is not InputEventKey { Pressed: true, Echo: false } key) return;
        if (key.Keycode == Key.Escape)
        {
            if (ModalOpen) { if (_settings.DisplayPending) _settings.RevertDisplay(); else CloseModal(); }
            else if (Page == JourneyPage.Opening) RenderNewJourney();
            else if (Page == JourneyPage.Completion) FinishCompletion();
            else if (Page is JourneyPage.Ledger or JourneyPage.Upgrades) RenderCity();
            else if (Page == JourneyPage.City) (_cityReturn ?? RenderHome)();
            else if (Page == JourneyPage.Map) (_mapReturn ?? RenderHome)();
            else RenderHome();
            GetViewport().SetInputAsHandled(); return;
        }
        if (key.Keycode is not (Key.Tab or Key.Up or Key.Down or Key.Left or Key.Right)) return;
        if (!ModalOpen && Page == JourneyPage.Ledger && key.Keycode != Key.Tab && GetViewport().GuiGetFocusOwner()?.Name.ToString() is { } dateName && dateName.StartsWith("Date") && int.TryParse(dateName[4..], out int date))
        {
            int offset = key.Keycode == Key.Up ? -3 : key.Keycode == Key.Down ? 3 : key.Keycode == Key.Left ? -1 : 1;
            Focus("Date" + Math.Clamp(date + offset, 1, JourneyModel.City(_city).Days)); GetViewport().SetInputAsHandled(); return;
        }
        if (GetViewport().GuiGetFocusOwner() is HSlider && key.Keycode is Key.Left or Key.Right) return;
        Control[] candidates = ModalOpen ? _modalControls.Where(c => c.IsVisibleInTree() && (c is not BaseButton b || !b.Disabled)).ToArray()
            : _body.Descendants<Button>().Where(b => !b.Disabled && b.IsVisibleInTree()).Cast<Control>().ToArray();
        if (_settings.DisplayPending && _displayConfirmation is not null) candidates = candidates.Where(c => _displayConfirmation.IsAncestorOf(c)).ToArray();
        if (candidates.Length == 0) return;
        int current = Array.IndexOf(candidates, GetViewport().GuiGetFocusOwner());
        int direction = key.Keycode is Key.Up or Key.Left || key.Keycode == Key.Tab && key.ShiftPressed ? -1 : 1;
        candidates[(current + direction + candidates.Length) % candidates.Length].GrabFocus(); GetViewport().SetInputAsHandled();
    }
    public override void _ExitTree()
    {
        if (_save is not null) _save.Changed -= SaveChanged;
        if (_settings is not null) { _settings.Changed -= SettingsChanged; _settings.RevertDisplay(); }
        KillAnimations(); if (_ownsAspect) GetWindow().ContentScaleAspect = _previousAspect;
    }
}
