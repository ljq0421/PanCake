using Godot;

namespace ProjectCake.Core;

/// <summary>Preferences are independent of gameplay saves. Display changes are transactional.</summary>
public partial class JourneySettings : Node
{
    public const string EffectsBus = "Effects", MusicBus = "Music";
    public string SettingsPath { get; private set; } = "user://journey_settings.cfg";
    public double Master { get; private set; } = 100;
    public double Music { get; private set; } = 100;
    public double Effects { get; private set; } = 100;
    public bool Muted { get; private set; }
    public string ErrorMessage { get; private set; } = "";
    public bool DisplayPending => _remaining > 0;
    public int SecondsRemaining => (int)Math.Ceiling(_remaining);
    public event Action? Changed;
    private double _remaining;
    private Window.ModeEnum _oldMode;
    private Vector2I _oldSize, _oldPosition;
    private bool _oldBorderless;
    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
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
        var cfg = new ConfigFile(); Error load = cfg.Load(SettingsPath);
        ErrorMessage = load is Error.Ok or Error.FileNotFound ? "" : "设置无法读取，已使用默认值。";
        Master = ReadVolume(cfg, "master"); Music = ReadVolume(cfg, "music"); Effects = ReadVolume(cfg, "effects");
        Muted = cfg.GetValue("audio", "muted", false).AsBool(); ApplyAudio();
        if (load == Error.Ok && DisplayServer.GetName() != "headless")
        {
            bool full = cfg.GetValue("display", "fullscreen", false).AsBool();
            var size = new Vector2I(cfg.GetValue("display", "width", 1920).AsInt32(), cfg.GetValue("display", "height", 1080).AsInt32());
            if (full) GetWindow().Mode = Window.ModeEnum.Fullscreen;
            else if (AvailableSizes().Contains(size)) { GetWindow().Mode = Window.ModeEnum.Windowed; GetWindow().Size = size; Center(); }
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
        var sizes = new[] { new Vector2I(1280, 720), new Vector2I(1600, 900), new Vector2I(1920, 1080) };
        if (DisplayServer.GetName() == "headless") return sizes;
        var available = DisplayServer.ScreenGetUsableRect().Size;
        return sizes.Where(s => s.X <= available.X && s.Y + 40 <= available.Y).ToArray();
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
        _oldMode = window.Mode; _oldSize = window.Size; _oldPosition = window.Position; _oldBorderless = window.Borderless;
        window.Mode = fullscreen ? Window.ModeEnum.Fullscreen : Window.ModeEnum.Windowed;
        if (!fullscreen) { window.Borderless = false; window.Size = size; Center(); }
        _remaining = 15; Changed?.Invoke();
    }
    private void Center() => GetWindow().Position = DisplayServer.ScreenGetUsableRect().Position + (DisplayServer.ScreenGetUsableRect().Size - GetWindow().Size) / 2;
    public void ConfirmDisplay() { if (!DisplayPending) return; _remaining = 0; SavePreferences(); Changed?.Invoke(); }
    public void RevertDisplay()
    {
        if (!DisplayPending) return;
        _remaining = 0; var window = GetWindow(); window.Mode = _oldMode; window.Borderless = _oldBorderless;
        window.Size = _oldSize; window.Position = _oldPosition; Changed?.Invoke();
    }
    public override void _Process(double delta)
    {
        if (!DisplayPending) return;
        if (delta >= _remaining) RevertDisplay(); else { _remaining -= delta; Changed?.Invoke(); }
    }
    public bool SavePreferences()
    {
        var cfg = new ConfigFile();
        cfg.SetValue("audio", "master", Master); cfg.SetValue("audio", "music", Music); cfg.SetValue("audio", "effects", Effects); cfg.SetValue("audio", "muted", Muted);
        cfg.SetValue("display", "fullscreen", (DisplayPending ? _oldMode : GetWindow().Mode) == Window.ModeEnum.Fullscreen);
        Vector2I size = DisplayPending ? _oldSize : GetWindow().Size;
        cfg.SetValue("display", "width", size.X); cfg.SetValue("display", "height", size.Y);
        Error result = cfg.Save(SettingsPath);
        ErrorMessage = result == Error.Ok ? "" : "设置未能保存，请检查写入权限与可用空间。";
        return result == Error.Ok;
    }
    public override void _ExitTree() => RevertDisplay();
}
