using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private void OpenModal(string kind)
    {
        // A utility dialog opened from a home-book overlay returns to the unchanged
        // home backdrop first; utility dialogs are not nested inside journey books.
        CloseModal(); _previousFocus = GetViewport().GuiGetFocusOwner(); _modalKind = kind;
        Clear(_modal); _modalControls.Clear(); _modal.Show();
        _modal.AddChild(new ColorRect { Size = new(1920, 1080), Color = new Color(.15f, .1f, .06f, .65f) });
        if (kind == "confirm")
            AddConfirmationPanel(_modal, "Confirmation");
        else if (kind == "developer")
        {
            var panel = new Panel { Position = new(495, 275), Size = new(930, 535), MouseFilter = MouseFilterEnum.Ignore };
            panel.AddThemeStyleboxOverride("panel", StartScreenTheme.Box(StartScreenTheme.Cream, 3, true));
            _modal.AddChild(panel);
        }
        else if (kind != "home-overlay")
        {
            var book = HomeArt(_modal, "旅行手账双页母版", BookBounds);
            if (kind == "settings")
            {
                book.Name = "SettingsBook";
                ApplyHomeBookBackground(book);
            }
        }
        foreach (var button in _buttons) button.FocusMode = FocusModeEnum.None;
    }
    private static void ApplyHomeBookBackground(TextureRect book)
        => book.Material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/settings_book_decor.gdshader") };
    // Reference: the approved Tianjin dialog, using the supplied panel and button art unchanged.
    private void AddConfirmationPanel(Control parent, string prefix)
    {
        var panel = new Panel { Name = prefix + "Panel", Position = new(360, 225),
            Size = IllustratedCityDialogTheme.PanelSize, MouseFilter = MouseFilterEnum.Ignore };
        panel.AddThemeStyleboxOverride("panel", IllustratedCityDialogTheme.PanelFrame(ProjectCake.Data.StableIds.Cities.Tianjin));
        parent.AddChild(panel);
    }
    private Label ConfirmationTitle(Control parent, string name, string caption)
    {
        var title = Text(parent, name, caption, new(678, 242, 564, 114), 60, true);
        title.AddThemeColorOverride("font_color", new Color("#542D16"));
        IllustratedCityDialogTheme.FitHeading(title);
        return title;
    }
    private Label ConfirmationMessage(Control parent, string name, string caption)
    {
        var message = Text(parent, name, caption, new(535, 432, 850, 180), 40, true);
        message.AddThemeColorOverride("font_color", new Color("#542D16"));
        message.AddThemeConstantOverride("line_spacing", 14);
        FitTextWidth(message, 40, 28);
        return message;
    }
    private Button ConfirmationAction(Control parent, string name, string caption, Action action, bool primary = false)
    {
        var button = Button(parent, name, caption, new(primary ? 990 : 520, 669, 410, 104), action,
            bare: true, highlightFocus: false);
        IllustratedCityDialogTheme.StyleAction(button, primary, ProjectCake.Data.StableIds.Cities.Tianjin);
        return button;
    }
    private void CloseModal()
    {
        if (_modal is null || !_modal.Visible) return;
        bool restoreHomeBody = _homeOverlayOpen;
        CloseSettingsPopups();
        _settings.RevertDisplay(); _modal.Hide(); _modalKind = "";
        _settingsMessage = null; _countdown = null; _displayConfirmation = null;
        foreach (var button in _buttons) if (GodotObject.IsInstanceValid(button)) button.FocusMode = FocusModeEnum.All;
        if (restoreHomeBody) RestoreHomeBody();
        if (GodotObject.IsInstanceValid(_previousFocus) && _previousFocus!.IsInsideTree() && _previousFocus.IsVisibleInTree()) _previousFocus.GrabFocus();
        _previousFocus = null;
    }
    private void PreviewDisplay(bool fullscreen, Vector2I size)
    {
        _displayReturnFocus = GetViewport().GuiGetFocusOwner();
        _settings.PreviewDisplay(fullscreen, size);
        if (!_settings.DisplayPending) return;
        if (_displayConfirmation is not null)
        {
            _modalControls.RemoveAll(c => _displayConfirmation.IsAncestorOf(c));
            _modal.RemoveChild(_displayConfirmation); _displayConfirmation.QueueFree();
        }
        foreach (var control in _modalControls) control.FocusMode = FocusModeEnum.None;
        _displayConfirmation = new Control { Name = "DisplayConfirmation", Size = new(1920, 1080) }; _modal.AddChild(_displayConfirmation);
        JourneyTransition.For(this).Play(JourneyTransition.Effect.OpenBook,
            bounds: new Rect2(_canvas.GetGlobalTransformWithCanvas() * new Vector2(360, 225), new Vector2(1200, 630) * _canvas.Scale));
        _displayConfirmation.AddChild(new ColorRect { Size = new(1920, 1080), Color = new Color(.12f, .08f, .04f, .7f) });
        AddConfirmationPanel(_displayConfirmation, "DisplayConfirmation");
        ConfirmationTitle(_displayConfirmation, "DisplayConfirmationTitle", "保留这个显示设置？");
        _countdown = ConfirmationMessage(_displayConfirmation, "Countdown", "15 秒后恢复原设置");
        ConfirmationAction(_displayConfirmation, "RevertDisplay", "恢复原设置", _settings.RevertDisplay);
        ConfirmationAction(_displayConfirmation, "KeepDisplay", "保留设置", _settings.ConfirmDisplay, true);
        _modalControls.First(c => c.Name == "RevertDisplay").GrabFocus();
    }
    private void SettingsChanged()
    {
        if (_body is not null) FitJourneyIntroduction();
        if (_body is not null)
        {
            if (_body.GetNodeOrNull<Label>("PageTitle") is { } heading) FitTextWidth(heading, 42, 26);
            foreach (string name in new[] { "Home", "Settings", "Help", "Quit" })
                if (_body.GetNodeOrNull<Button>(name)?.GetNodeOrNull<Label>("Caption") is { } caption)
                    FitTextWidth(caption, 26, 20);
        }
        // Existing home buttons also need their translated text measured after a locale change.
        if (_body is not null)
            foreach (string name in new[] { "LedgerTab", "UpgradeTab" })
                if (_body.GetNodeOrNull<Button>(name)?.GetNodeOrNull<Label>("Caption") is { } bookmarkCaption)
                    FitContinueLines(bookmarkCaption, 25, 16, 2);
        if (Page == JourneyPage.Home && _body is not null)
            foreach (string name in new[] { "Continue", "NewGame", "WorldMap" })
                if (_body.FindChild(name, true, false)?.GetNodeOrNull<Label>("Caption") is { } caption)
                    FitTextWidth(caption, name == "WorldMap" ? 34 : 48, name == "WorldMap" ? 25 : 32);
        RefreshSettingsControls();
        if (_audioButton is not null && GodotObject.IsInstanceValid(_audioButton))
        {
            _audioButton.GetNode<Label>("Caption").Text = _settings.Muted ? "已静音" : "声音";
            if (_audioIcon is not null && GodotObject.IsInstanceValid(_audioIcon)) _audioIcon.Texture = Texture(_settings.Muted ? "音效关闭" : "音效开启");
        }
        if (_settingsMessage is not null) _settingsMessage.Text = string.IsNullOrEmpty(_settings.ErrorMessage) ? _settings.DisplayMessage : _settings.ErrorMessage;
        if (_countdown is not null) _countdown.Text = $"{_settings.SecondsRemaining} 秒后恢复原设置";
        if (_displayConfirmation is { Visible: true } && !_settings.DisplayPending)
        {
            JourneyTransition.For(this).Play(JourneyTransition.Effect.CloseBook,
                bounds: new Rect2(_canvas.GetGlobalTransformWithCanvas() * new Vector2(360, 225), new Vector2(1200, 630) * _canvas.Scale));
            _displayConfirmation.Hide();
            foreach (var c in _modalControls) c.FocusMode = _displayConfirmation.IsAncestorOf(c) ? FocusModeEnum.None : FocusModeEnum.All;
            if (GodotObject.IsInstanceValid(_displayReturnFocus) && _displayReturnFocus!.IsVisibleInTree()) _displayReturnFocus.GrabFocus();
        }
    }
    private void OpenDemoMusicCredits()
    {
        OpenModal("music-credits");
        Text(_modal, "CreditsTitle", "配乐与署名", new(355, 285, 490, 70), 42);
        Text(_modal, "CreditsComposer", "配乐：Kevin MacLeod（incompetech.com）", new(355, 400, 480, 110), 26);
        Text(_modal, "CreditsLicense", "使用 CC BY 4.0；曲目与许可详见随包 MUSIC-CREDITS.md。", new(355, 560, 480, 180), 25);
        Text(_modal, "CreditsTracks", "Wholesome\nCarefree\nLocal Forecast - Elevator\n\nhttps://creativecommons.org/licenses/by/4.0/\n\nMix: -18 dB; loop and scene fades.", new(1030, 320, 490, 450), 25);
        Button(_modal, "Close", "记住了", new(1220, 795, 300, 65), CloseModal, true);
    }
}
