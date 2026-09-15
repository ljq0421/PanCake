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
        else HomeArt(_modal, "旅行手账双页母版", BookBounds);
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
        _settings.RevertDisplay(); _modal.Hide(); _modalKind = "";
        _settingsMessage = null; _countdown = null; _displayConfirmation = null;
        foreach (var button in _buttons) if (GodotObject.IsInstanceValid(button)) button.FocusMode = FocusModeEnum.All;
        if (GodotObject.IsInstanceValid(_previousFocus) && _previousFocus!.IsInsideTree() && _previousFocus.IsVisibleInTree()) _previousFocus.GrabFocus();
        _previousFocus = null;
    }
    private void OpenSettings()
    {
        OpenModal("settings");
        Text(_modal, "DisplayTitle", "旅途设置", new(355, 280, 490, 70), 45);
        Button(_modal, "Language", _settings.Language == "en" ? "语言：English" : "语言：简体中文", new(1040, 849, 510, 45),
            () => { _settings.SetLanguage(_settings.Language == "en" ? "zh_CN" : "en"); OpenSettings(); });
        Text(_modal, "DisplayCaption", "画面与窗口", new(355, 380, 490, 60), 31);
        int y = 465;
        foreach (var size in JourneySettings.AvailableSizes())
        {
            Button(_modal, "Size" + size.X, $"{size.X} × {size.Y}  窗口", new(355, y, 480, 60), () => PreviewDisplay(false, size)).AddThemeFontSizeOverride("font_size", 26); y += 78;
        }
        Button(_modal, "Fullscreen", "无边框全屏", new(355, y, 480, 60), () => PreviewDisplay(true, GetWindow().Size)).AddThemeFontSizeOverride("font_size", 26);
        Text(_modal, "DisplayHint", "切换后 15 秒内确认，超时自动恢复。", new(355, 813, 500, 48), 23);
        Text(_modal, "AudioTitle", "声音", new(1040, 280, 460, 70), 45);
        Volume("master", "主音量", _settings.Master, 390);
        Volume("music", "音乐 · 暂无背景音乐", _settings.Music, 510);
        Volume("effects", "音效", _settings.Effects, 630);
        Button(_modal, "Mute", _settings.Muted ? "取消静音" : "全部静音", new(1040, 780, 245, 62), () => { _settings.ToggleMute(); RefreshMute(); }).AddThemeFontSizeOverride("font_size", 25);
        Button(_modal, "Close", "完成", new(1360, 780, 190, 62), CloseModal, true).AddThemeFontSizeOverride("font_size", 26);
        _settingsMessage = Text(_modal, "SettingsMessage", _settings.ErrorMessage, new(430, 938, 1060, 58), 24, true);
        _settingsMessage.AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        _modalControls[0].GrabFocus();
    }
    private void Volume(string key, string title, double value, int y)
    {
        Text(_modal, "Label" + key, title, new(1040, y, 440, 46), 27);
        TextureRect? icon = key == "master" ? null : Art(_modal, (key == "music" ? "音乐" : "音效") + (_settings.Muted || value == 0 ? "关闭" : "开启"), new(987, y + 2, 40, 40));
        var percent = Text(_modal, "Value" + key, value.ToString("0") + "%", new(1480, y + 40, 100, 45), 26, true);
        var slider = new HSlider { Name = "Volume" + key, Position = new(1040, y + 57), Size = new(415, 38), MinValue = 0, MaxValue = 100, Step = 1, Value = value };
        _modal.AddChild(slider); _modalControls.Add(slider);
        slider.ValueChanged += volume => { _settings.SetVolume(key, volume); percent.Text = volume.ToString("0") + "%"; };
        if (icon is not null) icon.Name = "ChannelIcon" + key;
    }
    private void RefreshMute()
    {
        var mute = _modalControls.OfType<Button>().FirstOrDefault(b => b.Name == "Mute");
        if (mute is not null) mute.Text = _settings.Muted ? "取消静音" : "全部静音";
        RefreshChannelIcons();
    }
    private void RefreshChannelIcons()
    {
        foreach (string key in new[] { "music", "effects" })
            if (_modal.GetNodeOrNull<TextureRect>("ChannelIcon" + key) is { } icon)
                icon.Texture = Texture((key == "music" ? "音乐" : "音效") + (_settings.Muted || (key == "music" ? _settings.Music : _settings.Effects) == 0 ? "关闭" : "开启"));
    }
    private void PreviewDisplay(bool fullscreen, Vector2I size)
    {
        _settings.PreviewDisplay(fullscreen, size);
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
        // Existing home buttons also need their translated text measured after a locale change.
        if (Page == JourneyPage.Home && _body is not null)
            foreach (string name in new[] { "Continue", "NewGame", "WorldMap" })
                if (_body.FindChild(name, true, false)?.GetNodeOrNull<Label>("Caption") is { } caption)
                    FitTextWidth(caption, name == "WorldMap" ? 34 : 48, name == "WorldMap" ? 25 : 32);
        RefreshChannelIcons();
        if (_audioButton is not null && GodotObject.IsInstanceValid(_audioButton))
        {
            _audioButton.GetNode<Label>("Caption").Text = _settings.Muted ? "已静音" : "声音";
            if (_audioIcon is not null && GodotObject.IsInstanceValid(_audioIcon)) _audioIcon.Texture = Texture(_settings.Muted ? "音效关闭" : "音效开启");
        }
        if (_settingsMessage is not null) _settingsMessage.Text = _settings.ErrorMessage;
        if (_countdown is not null) _countdown.Text = $"{_settings.SecondsRemaining} 秒后恢复原设置";
        if (_displayConfirmation is not null && !_settings.DisplayPending)
        {
            _displayConfirmation.Hide();
            foreach (var c in _modalControls) c.FocusMode = _displayConfirmation.IsAncestorOf(c) ? FocusModeEnum.None : FocusModeEnum.All;
            _modalControls.FirstOrDefault(c => c.Name == "Fullscreen")?.GrabFocus();
        }
    }
    private void OpenHelp()
    {
        if (ExperienceProfile.IsDemo) { OpenDemoHelp(); return; }
        OpenModal("help");
        Text(_modal, "HelpTitle", "一本早餐旅行手账", new(355, 285, 520, 80), 41);
        Text(_modal, "HelpJourney", "新的旅程\n从天津出发，建立一份新的旅行进度。\n确认重新开始后，会覆盖原有存档。\n\n继续旅程\n回到上次开张的城市早餐铺。\n选营业日、升级设备，再准备开张。\n\n世界地图\n完成一城后，下一站逐步开放。\n选择城市查看信息，再进入早餐铺。", new(350, 390, 490, 440), 27);
        Text(_modal, "HelpControlsTitle", "慢慢来，做好每份早餐", new(1040, 285, 515, 80), 36);
        Text(_modal, "HelpControls", "按各城工作台提示点击或拖动制作。\n天津、武汉：右键长按 0.45 秒，\n拖入垃圾桶可丢弃已投入制作的食物。\n\n天津、武汉自动收款；西安点击收钱。\n广州、扬州完成订单后自动入账。\n扬州先备餐，再整盘上桌。\n\nTab / 方向键选择入口\nEnter / 空格确认，Esc 返回或关闭。\n", new(1035, 390, 535, 365), 24);
        Button(_modal, "Close", "记住了", new(1220, 795, 300, 65), CloseModal, true); _modalControls[0].GrabFocus();
    }

    private void OpenDemoHelp()
    {
        OpenModal("help");
        Text(_modal, "HelpTitle", "一本早餐旅行手账", new(355, 285, 520, 80), 38);
        Text(_modal, "HelpJourney", "本次试玩：天津前三局。\n完成至少 1 单并收摊保存后开放下一局。\n零完成可以免费重试。\n\n第 3 局结束后，可以选择升级。\n从经营手账重玩第 3 局，感受变化。\n重玩只补超过历史最佳的收入差额。", new(350, 390, 490, 440), 25);
        Text(_modal, "HelpControlsTitle", "慢慢来，做好每份早餐", new(1040, 285, 515, 80), 32);
        Text(_modal, "HelpControls", "按住左键划动摊饼；点击鸡蛋。\n点击酱碗，按住左键刷酱。\nF：翻面、收刷、折叠或装袋。\n\n右键长按 0.45 秒后拖入垃圾桶丢弃。\n付款自动入账，点击挂件查看明细。\nEsc 暂停；教学可跳过或重看。", new(1035, 390, 535, 390), 24);
        Button(_modal, "Close", "记住了", new(1220, 795, 300, 65), CloseModal, true);
        _modalControls[0].GrabFocus();
    }
}
