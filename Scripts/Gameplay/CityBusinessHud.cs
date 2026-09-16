using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;
using ProjectCake.Xian;

namespace ProjectCake.Gameplay;

public partial class TianjinDayScreen
{
    private BusinessHud _hud = null!;
    private BusinessSceneFeedback _sceneFeedback = null!;
    private void BuildBusinessHud()
    {
        GetNode<Control>("@PanelContainer@2").Hide();
        _hud = new BusinessHud("天津"); AddChild(_hud);
        _hud.PauseButton.Pressed += () => SetManualPaused(true);
        _sceneFeedback = new("天津", () => _focused && !_manualPaused && !_detailsPaused && !_committed && _controller?.IsPaused != true);
        AddChild(_sceneFeedback);
        _feedbackPanel.Hide();
    }
    private void RenderBusinessHud() => _hud.Render(_controller,
        $"天津 · 第 {_controller.CurrentConfig!.Day} 天 · {DaySubtitle(_controller.CurrentConfig.Day)}",
        DaySubtitle(_controller.CurrentConfig.Day).Contains("高峰"),
        _focused && !_manualPaused && !_detailsPaused && !_committed && !_abandonDialog.Visible);
}

public partial class WuhanDayScreen
{
    private BusinessHud _hud = null!;
    private BusinessSceneFeedback _sceneFeedback = null!;
    private Control _hudPauseMenu = null!;
    private Button _hudResume = null!;
    private Control _hudPauseTitleTape = null!;
    private bool _hudPaused;
    private void BuildBusinessHud()
    {
        GetNode<Control>("@PanelContainer@312").Hide();
        _hud = new BusinessHud("武汉"); AddChild(_hud);
        _hud.PauseButton.Pressed += () => SetHudPaused(true);
        _sceneFeedback = new("武汉", () => _focused && !_detailsPaused && !_committed && _controller?.IsPaused != true);
        AddChild(_sceneFeedback); _feedback.Hide();
        _hudPauseMenu = new Control { Name = "HudPauseMenu", ZIndex = 150, Visible = false };
        AddChild(_hudPauseMenu); _hudPauseMenu.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var dim = new ColorRect { Color = new Color(0.12f, 0.08f, 0.04f, .46f) };
        _hudPauseMenu.AddChild(dim); dim.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var panel = new PanelContainer { Name = "HudPausePanel" };
        CityDialogChrome.ApplyPausePanel(panel, StableIds.Cities.Wuhan);
        _hudPauseMenu.AddChild(panel); panel.SetAnchorsAndOffsetsPreset(LayoutPreset.Center);
        panel.Position = new(740, 365); panel.Size = new(440, 310);
        var column = new VBoxContainer(); column.AddThemeConstantOverride("separation", 20); panel.AddChild(column);
        var title = TianjinUi.Label("歇一会儿", 32, alignment: HorizontalAlignment.Center);
        title.ZIndex = 2;
        column.AddChild(title);
        _hudPauseTitleTape = CityDialogChrome.AddTitleTape(_hudPauseMenu, "WuhanPauseTitleTape", new(795, 394, 330, 56), StableIds.Cities.Wuhan, 1);
        _hudPauseTitleTape.Visible = false;
        _hudResume = TianjinUi.Button("继续营业", minimumSize: new(380, 64));
        column.AddChild(_hudResume); _hudResume.Pressed += () => SetHudPaused(false);
        var abandon = TianjinUi.Button("放弃本日", minimumSize: new(380, 64));
        column.AddChild(abandon); abandon.Pressed += () => _abandon.PopupCentered();
        // These controls are created after the frame, so apply Wuhan's hierarchy last.
        CityDialogChrome.ApplyPauseAction(_hudResume, StableIds.Cities.Wuhan, primary: true);
        CityDialogChrome.ApplyPauseAction(abandon, StableIds.Cities.Wuhan, destructive: true);
        _hudResume.FocusNext = _hudResume.FocusPrevious = _hudResume.GetPathTo(abandon);
        abandon.FocusNext = abandon.FocusPrevious = abandon.GetPathTo(_hudResume);
        _abandon.Canceled += () => _hudResume.GrabFocus();
        _abandon.AboutToPopup += () => { panel.Hide(); _hudPauseTitleTape.Hide(); };
        _abandon.VisibilityChanged += () =>
        {
            if (!_abandon.Visible && _hudPaused) { panel.Show(); _hudPauseTitleTape.Show(); _hudResume.GrabFocus(); }
        };
        _abandon.Confirmed += () => SetHudPaused(false);
        VisibilityChanged += () => { if (!IsVisibleInTree()) SetHudPaused(false); };
    }
    private void SetHudPaused(bool paused)
    {
        if (paused && (_controller?.CurrentConfig is null || !_focused || _detailsPaused || _committed)) return;
        _hudPaused = paused;
        _controller?.SetPauseReason("wuhan-hud", paused);
        _hudPauseMenu.Visible = paused;
        _hudPauseMenu.GetNode<Control>("HudPausePanel").Visible = paused && !_abandon.Visible;
        _hudPauseTitleTape.Visible = paused;
        _hud.PauseButton.Disabled = paused;
        Workstation.CancelInput(); Workstation.SetCookingAudioPaused(!CanInteract);
        UpdatePendantState();
        if (paused) _hudResume.GrabFocus(); else if (IsVisibleInTree()) _hud.PauseButton.GrabFocus();
    }
    public override void _UnhandledKeyInput(InputEvent input)
    {
        if (!IsVisibleInTree() || _detailsPaused || _committed || _abandon.Visible) return;
        if (input is InputEventKey { Pressed: true, Echo: false, Keycode: Key.Escape })
        { SetHudPaused(!_hudPaused); GetViewport().SetInputAsHandled(); }
    }
    private void RenderBusinessHud() => _hud.Render(_controller,
        $"武汉 · 第 {_controller.CurrentConfig!.Day} 天 · {Subtitle(_controller.CurrentConfig.Day)}\n{Tutorial(_controller.CurrentConfig.Day)}",
        Subtitle(_controller.CurrentConfig.Day).Contains("高峰") || _controller.CurrentConfig.Day == 12,
        _focused && !_hudPaused && !_detailsPaused && !_committed && !_abandon.Visible);
}

public partial class XianDayScreen
{
    private BusinessHud _hud = null!;
    private BusinessSceneFeedback _sceneFeedback = null!;
    private void BuildBusinessHud()
    {
        _heading.Hide(); _clock.Hide(); _buttons["pause"].Hide();
        _hud = new BusinessHud("西安"); Workbench.AddChild(_hud);
        _hud.PauseButton.Pressed += Pause;
        _sceneFeedback = new("西安", () => _focused && !_committed && _controller?.IsPaused != true);
        Workbench.AddChild(_sceneFeedback); _feedback.Hide();
        // Preserve the existing book entry and click-to-collect cash tray.
        _book.Entry.Reparent(_hud, false);
        _book.Entry.Position = new(284, 30); _book.Entry.Size = new(52, 52);
        _book.Entry.TooltipText = "营业账本";
        BusinessHud.StyleIconButton(_book.Entry, _hud.LoadArt("经营手账页图标"));
        _book.Entry.Size = new(52, 52);
        // The existing collection control sits over the income coin, with the number remaining read-only.
        CoinTray.Position = new(1616, 29); CoinTray.CustomMinimumSize = Vector2.Zero; CoinTray.Size = new(60, 58); CoinTray.ZIndex = 71;
        var collect = CoinTray.Descendants<Button>().Single();
        collect.CustomMinimumSize = Vector2.Zero;
        foreach (string state in new[] { "normal", "hover", "pressed" }) collect.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        foreach (var caption in CoinTray.Descendants<Label>()) caption.Modulate = Colors.Transparent;
        CollectionFeedback.Bind(CoinTray, Workbench, _hud.IncomeTarget,
            GD.Load<Texture2D>("res://resource/art/Global/HUDUI/小费飞行金币.png"), () => CanInteract);
    }
    private void RenderBusinessHud()
    {
        CoinTray.TooltipText = CoinTray.PendingAmount > 0 ? $"点击收钱 ¥{CoinTray.PendingAmount}" : "暂无待收收入";
        _hud.Render(_controller,
        $"西安 · 第 {Session.Day} 天 · {XianRules.Titles[Session.Day - 1]}",
        XianRules.Titles[Session.Day - 1].Contains("高峰"),
        _focused && !_controller.IsPaused && !_results.Visible && !_exitDialog.Visible);
    }
}
