using Godot;

namespace ProjectCake.Core;

/// <summary>Preferences are independent of gameplay saves. Display changes are transactional.</summary>
public partial class JourneySettings : Node
{
    public const string EffectsBus = "Effects", MusicBus = "Music";
    public string SettingsPath { get; private set; } = "user://journey_settings.cfg";
    public string Language { get; private set; } = "zh_CN";
    public double Master { get; private set; } = 100;
    public double Music { get; private set; } = 100;
    public double Effects { get; private set; } = 100;
    public bool Muted { get; private set; }
    public bool ReduceMotion { get; private set; }
    public bool VSyncEnabled { get; private set; } = true;
    public string DisplayMessage { get; private set; } = "";
    public Vector2I WindowedSize { get; private set; } = new(1920, 1080);
    public bool Fullscreen => GetWindow().Mode is Window.ModeEnum.Fullscreen or Window.ModeEnum.ExclusiveFullscreen;
    public string ErrorMessage { get; private set; } = "";
    public bool DisplayPending => _remaining > 0;
    private readonly HashSet<string> _seenInterfaceLessons = new(StringComparer.Ordinal);
    public bool HasSeenInterfaceLesson(string key) => _seenInterfaceLessons.Contains(key);
    public void MarkInterfaceLessonSeen(string key)
    {
        if (_seenInterfaceLessons.Add(key)) SavePreferences();
    }
    public int SecondsRemaining => (int)Math.Ceiling(_remaining);
    public event Action? Changed;
    private double _remaining;
    private Window.ModeEnum _oldMode;
    private Vector2I _oldSize, _oldPosition;
    private bool _oldBorderless;
    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        GameTranslation.Install();
        if (ExperienceProfile.IsDemo)
        {
            SettingsPath = "user://demo/journey_settings.cfg";
        }
        var args = OS.GetCmdlineUserArgs();
        int index = Array.IndexOf(args, "--journey-settings");
        if (index >= 0 && index + 1 < args.Length) SettingsPath = args[index + 1];
        EnsureBuses(); LoadPreferences();
    }
    public static void EnsureBuses()
    {
        foreach (string bus in new[] { EffectsBus, MusicBus })
            if (AudioServer.GetBusIndex(bus) < 0)
            {
                AudioServer.AddBus(); int index = AudioServer.BusCount - 1;
                AudioServer.SetBusName(index, bus); AudioServer.SetBusSend(index, "Master");
            }
    }
    public void UsePathForTests(string path) { RevertDisplay(); SettingsPath = path; LoadPreferences(); }
    public void LoadPreferences()
    {
        RevertDisplay();
        var cfg = new ConfigFile(); Error load = cfg.Load(SettingsPath);
        _seenInterfaceLessons.Clear();
        foreach (string key in cfg.GetValue("teaching", "seen_interface_lessons", Array.Empty<string>()).AsStringArray())
            _seenInterfaceLessons.Add(key);
        Language = cfg.GetValue("language", "locale", "zh_CN").AsString() == "en" ? "en" : "zh_CN";
        TranslationServer.SetLocale(Language);
        ErrorMessage = load is Error.Ok or Error.FileNotFound ? "" : "设置无法读取，已使用默认值。";
        Master = ReadVolume(cfg, "master"); Music = ReadVolume(cfg, "music"); Effects = ReadVolume(cfg, "effects");
        Muted = cfg.GetValue("audio", "muted", false).AsBool(); ApplyAudio();
        ReduceMotion = cfg.GetValue("accessibility", "reduce_motion", false).AsBool();
        ProjectSettings.SetSetting("accessibility/reduce_motion", ReduceMotion);
        WindowedSize = ResolveWindowedSize(new Vector2I(
            cfg.GetValue("display", "window_width", cfg.GetValue("display", "width", 1920)).AsInt32(),
            cfg.GetValue("display", "window_height", cfg.GetValue("display", "height", 1080)).AsInt32()));
        ApplyVSync(cfg.GetValue("display", "vsync", true).AsBool());
        if (load == Error.Ok && DisplayServer.GetName() != "headless")
        {
            bool full = cfg.GetValue("display", "fullscreen", false).AsBool();
            if (full) GetWindow().Mode = Window.ModeEnum.Fullscreen;
            else { GetWindow().Mode = Window.ModeEnum.Windowed; GetWindow().Borderless = false; GetWindow().Size = WindowedSize; Center(); }
        }
        Changed?.Invoke();
    }
    private static double ReadVolume(ConfigFile cfg, string key)
    {
        double v = cfg.GetValue("audio", key, 100d).AsDouble();
        return double.IsFinite(v) ? Math.Clamp(v, 0, 100) : 100;
    }
    public static Vector2I[] AvailableSizes()
    {
        if (DisplayServer.GetName() == "headless") return SizesForArea(new(7680, 4320));
        var available = DisplayServer.ScreenGetUsableRect(DisplayServer.WindowGetCurrentScreen()).Size;
        var border = DisplayServer.WindowGetSizeWithDecorations() - DisplayServer.WindowGetSize();
        // Fullscreen has no decoration; retain a safe window-frame allowance in that mode.
        border = new(Math.Max(16, border.X), Math.Max(40, border.Y));
        return SizesForArea(available - border);
    }
    public static Vector2I[] SizesForArea(Vector2I available)
    {
        var sizes = new[] { new Vector2I(1280, 720), new Vector2I(1600, 900), new Vector2I(1920, 1080), new Vector2I(2560, 1440), new Vector2I(3840, 2160) };
        var fitting = sizes.Where(s => s.X <= available.X && s.Y <= available.Y).ToArray();
        if (fitting.Length > 0) return fitting;
        int units = Math.Max(1, Math.Min(available.X / 16, available.Y / 9));
        return new[] { new Vector2I(units * 16, units * 9) };
    }
    public static Vector2I ResolveWindowedSize(Vector2I requested)
    {
        var sizes = AvailableSizes();
        return sizes.Contains(requested) ? requested : sizes[^1];
    }
    public void SetVSync(bool enabled)
    {
        ApplyVSync(enabled); SavePreferences(); Changed?.Invoke();
    }
    private void ApplyVSync(bool enabled)
    {
        VSyncEnabled = enabled; DisplayMessage = "";
        if (DisplayServer.GetName() == "headless") return;
        DisplayServer.WindowSetVsyncMode(enabled ? DisplayServer.VSyncMode.Enabled : DisplayServer.VSyncMode.Disabled);
        VSyncEnabled = DisplayServer.WindowGetVsyncMode() != DisplayServer.VSyncMode.Disabled;
        if (VSyncEnabled != enabled) DisplayMessage = "当前设备不支持关闭垂直同步，已保持开启。";
    }
    public void SetVolume(string channel, double value)
    {
        value = double.IsFinite(value) ? Math.Clamp(value, 0, 100) : 100;
        switch (channel) { case "master": Master = value; break; case "music": Music = value; break; case "effects": Effects = value; break; default: return; }
        ApplyAudio(); SavePreferences(); Changed?.Invoke();
    }
    public void ToggleMute() { Muted = !Muted; ApplyAudio(); SavePreferences(); Changed?.Invoke(); }
    private void ApplyAudio()
    {
        EnsureBuses();
        foreach (var (name, value) in new[] { ("Master", Master), (MusicBus, Music), (EffectsBus, Effects) })
            AudioServer.SetBusVolumeDb(AudioServer.GetBusIndex(name), value <= 0 ? -80f : Mathf.LinearToDb((float)value / 100));
        AudioServer.SetBusMute(AudioServer.GetBusIndex("Master"), Muted || Master <= 0);
        AudioServer.SetBusMute(AudioServer.GetBusIndex(MusicBus), Music <= 0);
        AudioServer.SetBusMute(AudioServer.GetBusIndex(EffectsBus), Effects <= 0);
    }
    public void PreviewDisplay(bool fullscreen, Vector2I size)
    {
        RevertDisplay(); var window = GetWindow();
        if (fullscreen == Fullscreen && (fullscreen || window.Mode == Window.ModeEnum.Windowed && window.Size == size)) return;
        if (!fullscreen) size = ResolveWindowedSize(size);
        if (fullscreen == Fullscreen && (fullscreen || window.Mode == Window.ModeEnum.Windowed && window.Size == size)) return;
        if (window.Mode == Window.ModeEnum.Windowed) WindowedSize = window.Size;
        _oldMode = window.Mode; _oldSize = window.Size; _oldPosition = window.Position; _oldBorderless = window.Borderless;
        window.Mode = fullscreen ? Window.ModeEnum.Fullscreen : Window.ModeEnum.Windowed;
        if (!fullscreen) { window.Borderless = false; window.Size = size; Center(); }
        _remaining = 15; Changed?.Invoke();
    }
    private void Center()
    {
        if (DisplayServer.GetName() == "headless") return;
        var area = DisplayServer.ScreenGetUsableRect(GetWindow().CurrentScreen);
        GetWindow().Position = area.Position + (area.Size - GetWindow().Size) / 2;
    }
    public void ConfirmDisplay()
    {
        if (!DisplayPending) return;
        _remaining = 0;
        if (!Fullscreen) WindowedSize = GetWindow().Size;
        SavePreferences(); Changed?.Invoke();
    }
    public void RevertDisplay()
    {
        if (!DisplayPending) return;
        _remaining = 0; var window = GetWindow(); window.Mode = _oldMode; window.Borderless = _oldBorderless;
        window.Size = _oldSize; window.Position = _oldPosition; Changed?.Invoke();
    }
    public override void _Process(double delta)
    {
        if (!DisplayPending) return;
        if (delta >= _remaining) RevertDisplay();
        else { int seconds = SecondsRemaining; _remaining -= delta; if (SecondsRemaining != seconds) Changed?.Invoke(); }
    }
    public bool SavePreferences()
    {
        var cfg = new ConfigFile();
        cfg.SetValue("accessibility", "reduce_motion", ReduceMotion);
        cfg.SetValue("teaching", "seen_interface_lessons", _seenInterfaceLessons.OrderBy(key => key).ToArray());
        cfg.SetValue("language", "locale", Language);
        Error directory = DirAccess.MakeDirRecursiveAbsolute(Path.GetDirectoryName(ProjectSettings.GlobalizePath(SettingsPath))!);
        if (directory != Error.Ok) { ErrorMessage = "设置未能保存，请检查写入权限与可用空间。"; return false; }
        cfg.SetValue("audio", "master", Master); cfg.SetValue("audio", "music", Music); cfg.SetValue("audio", "effects", Effects); cfg.SetValue("audio", "muted", Muted);
        cfg.SetValue("display", "fullscreen", (DisplayPending ? _oldMode : GetWindow().Mode) == Window.ModeEnum.Fullscreen);
        if (!DisplayPending && GetWindow().Mode == Window.ModeEnum.Windowed) WindowedSize = GetWindow().Size;
        Vector2I size = WindowedSize;
        cfg.SetValue("display", "width", size.X); cfg.SetValue("display", "height", size.Y);
        cfg.SetValue("display", "window_width", size.X); cfg.SetValue("display", "window_height", size.Y);
        cfg.SetValue("display", "vsync", VSyncEnabled);
        Error result = cfg.Save(SettingsPath);
        ErrorMessage = result == Error.Ok ? "" : "设置未能保存，请检查写入权限与可用空间。";
        return result == Error.Ok;
    }
    public override void _ExitTree() => RevertDisplay();
    public void SetLanguage(string language)
    {
        if (language is not ("zh_CN" or "en")) return;
        Language = language; TranslationServer.SetLocale(language); SavePreferences(); Changed?.Invoke();
    }
    public void SetReduceMotion(bool enabled)
    {
        ReduceMotion = enabled;
        ProjectSettings.SetSetting("accessibility/reduce_motion", enabled);
        SavePreferences(); Changed?.Invoke();
    }
}
