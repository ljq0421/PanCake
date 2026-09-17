using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private void OpenModal(string kind)
    {
        CloseModal(); _previousFocus = GetViewport().GuiGetFocusOwner(); _modalKind = kind;
        Clear(_modal); _modalControls.Clear(); _modal.Show();
        _modal.AddChild(new ColorRect { Size = new(1920, 1080), Color = new Color(.15f, .1f, .06f, .65f) });
        if (kind is "confirm" or "reset-ledger" or "developer")
        {
            bool illustratedConfirmation = kind is "confirm" or "reset-ledger";
            var panel = new Panel { Position = new(495, 275), Size = new(930, 535), MouseFilter = MouseFilterEnum.Ignore };
            panel.AddThemeStyleboxOverride("panel", illustratedConfirmation
                ? GD.Load<StyleBoxTexture>("res://resource/art/Global/PanelUI/panel-main-v1.tres")
                : StartScreenTheme.Box(StartScreenTheme.Cream, 3, true));
            _modal.AddChild(panel);
            if (illustratedConfirmation)
            {
                string prefix = kind == "confirm" ? "Confirmation" : "ResetLedger";
                panel.Name = prefix + "Panel";
                var group = new Panel { Name = prefix + "MessagePanel", Position = new(550, 445), Size = new(820, 160), MouseFilter = MouseFilterEnum.Ignore };
                group.AddThemeStyleboxOverride("panel", GD.Load<StyleBoxTexture>("res://resource/art/Global/PanelUI/panel-group-v1.tres"));
                _modal.AddChild(group);
                var decorations = new Control { Name = prefix + "Decorations", Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Ignore };
                _modal.AddChild(decorations);
                AddPanelTitleTape(decorations, prefix + "TitleTape", new(625, 332, 670, 94));
                var tape = Art(decorations, "res://resource/art/Global/PanelUI/corner-tape-v4.png", new(480, 270, 135, 45));
                tape.PivotOffset = tape.Size / 2;
                tape.RotationDegrees = -24;
                var stamp = Art(decorations, "res://resource/art/Global/PanelUI/bowl-stamp-v2.png", new(1320, 702, 72, 72));
                stamp.Modulate = new Color(1, 1, 1, .60f);
                stamp.PivotOffset = stamp.Size / 2;
                stamp.RotationDegrees = 8;
            }
        }
        else
        {
            var book = HomeArt(_modal, "旅行手账双页母版", kind == "help" ? HelpBookBounds : BookBounds);
            if (kind == "settings")
            {
                book.Name = "SettingsBook";
                book.Material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/settings_book_decor.gdshader") };
            }
        }
        foreach (var button in _buttons) button.FocusMode = FocusModeEnum.None;
    }
    private void AddPanelTitleTape(Control parent, string name, Rect2 bounds)
    {
        var texture = Texture("res://resource/art/Global/PanelUI/corner-tape-v4.png");
        float scale = bounds.Size.Y / texture.GetHeight();
        var tape = new NinePatchRect
        {
            Name = name, Position = bounds.Position, Size = bounds.Size / scale,
            Scale = Vector2.One * scale, Texture = texture,
            PatchMarginLeft = 50, PatchMarginRight = 50,
            MouseFilter = MouseFilterEnum.Ignore,
            Material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/panel_tape_lighten.gdshader") },
        };
        parent.AddChild(tape);
    }
    private void CloseModal()
    {
        if (_modal is null || !_modal.Visible) return;
        CloseSettingsPopups();
        _settings.RevertDisplay(); _modal.Hide(); _modalKind = "";
        _settingsMessage = null; _countdown = null; _displayConfirmation = null;
        foreach (var button in _buttons) if (GodotObject.IsInstanceValid(button)) button.FocusMode = FocusModeEnum.All;
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
        _displayConfirmation.AddChild(new ColorRect { Size = new(1920, 1080), Color = new Color(.12f, .08f, .04f, .7f) });
        var panel = new Panel { Name = "DisplayConfirmationPanel", Position = new(535, 330), Size = new(850, 400), MouseFilter = MouseFilterEnum.Ignore };
        panel.AddThemeStyleboxOverride("panel", GD.Load<StyleBoxTexture>("res://resource/art/Global/PanelUI/panel-main-v1.tres")); _displayConfirmation.AddChild(panel);
        var message = new Panel { Name = "DisplayConfirmationMessagePanel", Position = new(580, 465), Size = new(760, 90), MouseFilter = MouseFilterEnum.Ignore };
        message.AddThemeStyleboxOverride("panel", GD.Load<StyleBoxTexture>("res://resource/art/Global/PanelUI/panel-group-v1.tres")); _displayConfirmation.AddChild(message);
        var decorations = new Control { Name = "DisplayConfirmationDecorations", Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Ignore };
        _displayConfirmation.AddChild(decorations);
        AddPanelTitleTape(decorations, "DisplayConfirmationTitleTape", new(690, 365, 540, 75));
        var tape = Art(decorations, "res://resource/art/Global/PanelUI/corner-tape-v4.png", new(520, 321, 112, 39));
        tape.PivotOffset = tape.Size / 2;
        tape.RotationDegrees = -24;
        Text(_displayConfirmation, "DisplayConfirmationTitle", "保留这个显示设置？", new(710, 378, 500, 46), 32, true);
        _countdown = Text(_displayConfirmation, "Countdown", "15 秒后恢复原设置", new(615, 486, 690, 42), 26, true);
        Button(_displayConfirmation, "RevertDisplay", "恢复原设置", new(620, 575, 295, 70), _settings.RevertDisplay);
        Button(_displayConfirmation, "KeepDisplay", "保留设置", new(1000, 575, 285, 70), _settings.ConfirmDisplay, true);
        _modalControls.First(c => c.Name == "RevertDisplay").GrabFocus();
    }
    private void SettingsChanged()
    {
        if (_body is not null)
        {
            if (_body.GetNodeOrNull<Label>("PageTitle") is { } heading) FitTextWidth(heading, 42, 26);
            foreach (string name in new[] { "Home", "Settings", "Help", "Quit" })
                if (_body.GetNodeOrNull<Button>(name)?.GetNodeOrNull<Label>("Caption") is { } caption)
                    FitTextWidth(caption, 26, 20);
        }
        // Existing home buttons also need their translated text measured after a locale change.
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
