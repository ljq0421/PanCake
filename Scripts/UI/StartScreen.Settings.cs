using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private Control? _displayReturnFocus;
    private readonly Dictionary<string, Texture2D> _settingsIcons = new();
    private Vector2I[] _resolutionChoices = Array.Empty<Vector2I>();

    private void OpenSettings()
    {
        OpenModal("settings");
        SettingsGroup("DisplayGroup", new(340, 350, 553, 300));
        SettingsGroup("AudioGroup", new(1005, 350, 528, 309));

        SettingsRowLabel("DisplayModeLabel", "显示模式", "04_显示模式", 350, 369, 185);
        var windowed = SettingsButton("Windowed", "窗口化", new(546, 373, 130, 58),
            () => PreviewDisplay(false, _settings.WindowedSize));
        var full = SettingsButton("Fullscreen", "无边框全屏", new(686, 373, 194, 58),
            () => PreviewDisplay(true, _settings.WindowedSize));
        SettingsRule(356, 450, 522);
        SettingsRowLabel("ResolutionLabel", "分辨率", "05_分辨率", 350, 474, 185);
        var resolution = SettingsChoice("Resolution", new(546, 474, 334, 58));
        resolution.ItemSelected += index => PreviewDisplay(false, _resolutionChoices[(int)index]);
        SettingsRule(356, 555, 522);
        SettingsRowLabel("VSyncLabel", "垂直同步", "06_垂直同步", 350, 574, 185);
        SettingsSwitch("VSync", new(546, 574, 124, 56), () => _settings.SetVSync(!_settings.VSyncEnabled));
        var hint = Text(_modal, "DisplayHint", "切换后 15 秒内确认，超时自动恢复。", new(492, 785, 380, 66), 21);
        hint.AddThemeColorOverride("font_color", JournalSettingsTheme.Muted);

        SettingsGroup("LanguageGroup", new(340, 682, 553, 64));
        SettingsRowLabel("LanguageLabel", "语言", "03_语言", 350, 687, 185);
        var language = SettingsChoice("Language", new(546, 688, 334, 52));
        language.AddItem("简体中文", 0); language.AddItem("English", 1);
        language.ItemSelected += index => _settings.SetLanguage(index == 1 ? "en" : "zh_CN");

        SettingsVolume("master", "主音量", 359);
        SettingsVolume("music", "音乐", 434);
        SettingsVolume("effects", "音效", 509);
        SettingsRule(1021, 590, 496);
        SettingsRowLabel("MuteLabel", "全部静音", "02_全部静音", 1020, 597, 305);
        SettingsSwitch("Mute", new(1374, 596, 124, 52), _settings.ToggleMute);

        var done = Button(_modal, "Close", "完成", new(1150, 796, 262, 63), CloseModal, true, bare: true);
        Art(done, "首页地图按钮底板", new(0, 0, 262, 63)).ShowBehindParent = true;
        done.AddThemeFontSizeOverride("font_size", 30);
        _settingsMessage = Text(_modal, "SettingsMessage", "", new(420, 939, 1080, 62), 23, true);
        _settingsMessage.AddThemeColorOverride("font_color", StartScreenTheme.Cream);
        RefreshSettingsControls();
        windowed.GrabFocus();
    }

    private void SettingsGroup(string name, Rect2 bounds)
    {
        var panel = new Panel { Name = name, Position = bounds.Position, Size = bounds.Size, MouseFilter = MouseFilterEnum.Ignore };
        panel.AddThemeStyleboxOverride("panel", JournalSettingsTheme.Box(new Color(.965f, .885f, .735f, .30f), 18, 0));
        _modal.AddChild(panel);
    }

    private void SettingsRule(float x, float y, float width) => _modal.AddChild(new ColorRect
    {
        Position = new(x, y), Size = new(width, 2), Color = new Color(.71f, .49f, .29f, .18f), MouseFilter = MouseFilterEnum.Ignore
    });

    private void SettingsRowLabel(string name, string text, string icon, float x, float y, float width)
    {
        SettingsIcon(icon, new(x + 5, y + 9, 36, 36));
        var label = Text(_modal, name, text, new(x + 50, y, width - 50, 56), 26);
        FitTextWidth(label, 26, 20);
    }

    private TextureRect SettingsIcon(string name, Rect2 bounds)
    {
        // The supplied small icons contain unrelated white export marks at their edges.
        // These atlas rectangles keep only the illustration, without altering the PNGs.
        if (!_settingsIcons.TryGetValue(name, out var texture))
        {
            Rect2 region = name switch
            {
                "01_主音量" => new(29, 24, 194, 177),
                "02_全部静音" => new(44, 51, 182, 158),
                "03_语言" => new(36, 28, 193, 185),
                "04_显示模式" => new(30, 43, 188, 160),
                "05_分辨率" => new(48, 47, 170, 151),
                "06_垂直同步" => new(43, 41, 184, 163),
                _ => default,
            };
            texture = region.Size.X > 0 ? new AtlasTexture { Atlas = Texture(name), Region = region } : Texture(name);
            _settingsIcons[name] = texture;
        }
        var art = new TextureRect { Position = bounds.Position, Size = bounds.Size, Texture = texture,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, MouseFilter = MouseFilterEnum.Ignore };
        _modal.AddChild(art); return art;
    }

    private Button SettingsButton(string name, string caption, Rect2 bounds, Action action)
    {
        var button = new Button { Name = name, Text = caption, Position = bounds.Position, Size = bounds.Size, ClipText = true, MouseDefaultCursorShape = CursorShape.PointingHand };
        button.SetMeta("settings_size", bounds.Size);
        JournalSettingsTheme.Apply(button);
        _modal.AddChild(button); _modalControls.Add(button);
        button.Pressed += () => { if (!_busy && ModalOpen && !_settings.DisplayPending) action(); };
        return button;
    }

    private OptionButton SettingsChoice(string name, Rect2 bounds)
    {
        var choice = new OptionButton { Name = name, Position = bounds.Position, Size = bounds.Size,
            FitToLongestItem = false, MouseDefaultCursorShape = CursorShape.PointingHand };
        JournalSettingsTheme.Apply(choice);
        _modal.AddChild(choice); _modalControls.Add(choice);
        choice.GetPopup().AboutToPopup += () => RefreshResolutionChoices();
        return choice;
    }

    private void SettingsSwitch(string name, Rect2 bounds, Action action)
    {
        var button = SettingsButton(name, "", bounds, action);
        button.ToggleMode = true;
        var knob = new Panel { Name = "Knob", Size = new(42, 42), MouseFilter = MouseFilterEnum.Ignore };
        var style = JournalSettingsTheme.Box(new Color("#FFF9EC"), 21, 2); style.BorderColor = new Color("#B68B60");
        knob.AddThemeStyleboxOverride("panel", style); button.AddChild(knob);
        Text(button, "State", "", new(10, 0, 58, bounds.Size.Y), 24, true);
    }

    private void RefreshSettingsSwitch(string name, bool on)
    {
        var button = _modal.GetNodeOrNull<Button>(name);
        if (button is null) return;
        button.SetPressedNoSignal(on);
        JournalSettingsTheme.Apply(button, on, 28);
        button.GetNode<Panel>("Knob").Position = new(on ? button.Size.X - 48 : 6, (button.Size.Y - 42) / 2);
        var label = button.GetNode<Label>("State");
        label.Text = on ? "开" : "关"; label.Position = new(on ? 8 : 52, 0);
        button.TooltipText = (name == "Mute" ? Tr("全部静音") : Tr("垂直同步")) + ": " + Tr(on ? "开" : "关");
    }

    private void SettingsVolume(string key, string title, int y)
    {
        var icon = SettingsIcon(key == "master" ? "01_主音量" : (key == "music" ? "音乐开启" : "音效开启"), new(1025, y + 4, 34, 34));
        icon.Name = "ChannelIcon" + key;
        Text(_modal, "Label" + key, title, new(1070, y, 310, 40), 26);
        var percent = Text(_modal, "Value" + key, "", new(1402, y, 99, 40), 25);
        percent.HorizontalAlignment = HorizontalAlignment.Right;
        var slider = new HSlider { Name = "Volume" + key, Position = new(1050, y + 33), Size = new(432, 42),
            MinValue = 0, MaxValue = 100, Step = 1, MouseDefaultCursorShape = CursorShape.PointingHand };
        JournalSettingsTheme.Apply(slider);
        _modal.AddChild(slider); _modalControls.Add(slider);
        slider.ValueChanged += value => _settings.SetVolume(key, value);
        if (key != "effects") SettingsRule(1021, y + 76, 496);
    }

    private void RefreshResolutionChoices()
    {
        if (_modalKind != "settings" || !ModalOpen || _modal.GetNodeOrNull<OptionButton>("Resolution") is not { } choice) return;
        if (_settings.Fullscreen)
        {
            choice.Clear(); choice.AddItem("跟随桌面分辨率"); choice.Select(0); choice.Disabled = true;
            return;
        }
        choice.Disabled = false;
        var choices = JourneySettings.AvailableSizes();
        Vector2I current = GetWindow().Size;
        // Also describe a manually resized current window accurately; it is not a new preset.
        if (!choices.Contains(current)) choices = choices.Append(current).OrderBy(s => s.X).ToArray();
        if (!_resolutionChoices.SequenceEqual(choices) || choice.ItemCount != choices.Length || choice.GetItemText(0) == "跟随桌面分辨率")
        {
            _resolutionChoices = choices; choice.Clear();
            foreach (var size in choices) choice.AddItem($"{size.X} × {size.Y}");
        }
        choice.Select(Array.IndexOf(choices, current));
    }

    private void RefreshSettingsControls()
    {
        if (_modal is null || _modalKind != "settings" || !ModalOpen) return;
        if (_modal.GetNodeOrNull<Button>("Windowed") is { } windowed) JournalSettingsTheme.Apply(windowed, !_settings.Fullscreen);
        if (_modal.GetNodeOrNull<Button>("Fullscreen") is { } full) JournalSettingsTheme.Apply(full, _settings.Fullscreen);
        foreach (string name in new[] { "Windowed", "Fullscreen" })
            if (_modal.GetNodeOrNull<Button>(name) is { } button)
            {
                var bounds = button.GetMeta("settings_size").AsVector2();
                string translated = button.Tr(button.Text);
                var font = button.GetThemeFont("font");
                int size = 24;
                while (size > 18 && font.GetStringSize(translated, fontSize: size).X > bounds.X - 26) size--;
                button.AddThemeFontSizeOverride("font_size", size); button.Size = bounds;
            }
        RefreshResolutionChoices();
        RefreshSettingsSwitch("Mute", _settings.Muted);
        RefreshSettingsSwitch("VSync", _settings.VSyncEnabled);
        if (_modal.GetNodeOrNull<OptionButton>("Language") is { } language) language.Select(_settings.Language == "en" ? 1 : 0);
        foreach (var (key, value) in new[] { ("master", _settings.Master), ("music", _settings.Music), ("effects", _settings.Effects) })
        {
            if (_modal.GetNodeOrNull<HSlider>("Volume" + key) is { } slider) slider.SetValueNoSignal(value);
            if (_modal.GetNodeOrNull<Label>("Value" + key) is { } percent) percent.Text = value.ToString("0") + "%";
            if (key != "master" && _modal.GetNodeOrNull<TextureRect>("ChannelIcon" + key) is { } icon)
                icon.Texture = Texture((key == "music" ? "音乐" : "音效") + (_settings.Muted || _settings.Master == 0 || value == 0 ? "关闭" : "开启"));
        }
        foreach (string name in new[] { "DisplayModeLabel", "ResolutionLabel", "VSyncLabel", "MuteLabel", "LanguageLabel" })
            if (_modal.GetNodeOrNull<Label>(name) is { } label) FitTextWidth(label, 26, 20);
        if (_settingsMessage is not null) _settingsMessage.Text = string.IsNullOrEmpty(_settings.ErrorMessage) ? _settings.DisplayMessage : _settings.ErrorMessage;
    }

    private bool SettingsPopupOpen() => _modalKind == "settings" && _modalControls.OfType<OptionButton>().Any(c => GodotObject.IsInstanceValid(c) && c.GetPopup().Visible);
    private void CloseSettingsPopups()
    {
        foreach (var choice in _modalControls.OfType<OptionButton>())
            if (GodotObject.IsInstanceValid(choice)) choice.GetPopup().Hide();
    }
}
