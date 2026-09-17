using Godot;
using System.Text.Json;
using ProjectCake.Data;
namespace ProjectCake.Core;

/// <summary>Two bounded voices crossfade city beds; focus loss freezes playback without catch-up.</summary>
public partial class DemoMusicPlayer : Node
{
    private readonly Dictionary<string, AudioStream> _tracks = new();
    private readonly AudioStreamPlayer[] _voices = new AudioStreamPlayer[2];
    private Func<(string Key, bool Ducked)>? _context;
    private string _key = "";
    private int _active;
    private float _crossfade = 1, _duck = 1;
    private bool _focused = true;
    internal string CurrentKey => _key;
    internal bool FocusPaused => !_focused;
    internal float DuckGain => _duck;
    public void Bind(Func<(string Key, bool Ducked)> context) => _context = context;
    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        JourneySettings.EnsureBuses();
        for (int i = 0; i < 2; i++)
        {
            _voices[i] = new AudioStreamPlayer { Name = "Bed" + i, Bus = JourneySettings.MusicBus, VolumeDb = -80, ProcessMode = ProcessModeEnum.Always };
            AddChild(_voices[i]);
        }
        foreach (var (key, filename) in new[] { ("home", "Wholesome"), (StableIds.Cities.Tianjin, "Carefree"), (StableIds.Cities.Wuhan, "Local Forecast - Elevator") })
        {
            string path = "res://resource/audio/demo/" + filename + ".mp3";
            if (ResourceLoader.Exists(path))
            {
                var stream = (AudioStreamMP3)GD.Load<AudioStreamMP3>(path).Duplicate();
                stream.Loop = true; _tracks[key] = stream;
            }
            else GD.PushError("Demo music resource missing: " + path);
        }
    }
    public override void _Process(double delta)
    {
        if (_context is null) return;
        var (key, ducked) = _context();
        SetContext(key, ducked, delta);
    }
    internal void SetContext(string key, bool ducked, double delta)
    {
        if (_key != key)
        {
            _tracks.TryGetValue(key, out var stream);
            // At most two voices, even if the user changes cities again during a fade.
            _active = 1 - _active; _voices[_active].Stop();
            _voices[_active].Stream = stream; _voices[_active].VolumeDb = -80;
            if (stream is not null) _voices[_active].Play();
            _voices[_active].StreamPaused = !_focused;
            _key = key; _crossfade = 0;
        }
        if (!_focused) return;
        _crossfade = Math.Min(1, _crossfade + (float)delta / 1.2f);
        _duck = Mathf.MoveToward(_duck, ducked ? .25f : 1, (float)delta * 2);
        for (int i = 0; i < 2; i++)
        {
            float gain = (i == _active ? _crossfade : 1 - _crossfade) * _duck;
            _voices[i].VolumeDb = gain > .0001f ? -18 + Mathf.LinearToDb(gain) : -80;
            if (i != _active && _crossfade >= 1) _voices[i].Stop();
        }
    }
    public override void _Notification(int what)
    {
        if (what != NotificationApplicationFocusIn && what != NotificationApplicationFocusOut) return;
        _focused = what == NotificationApplicationFocusIn;
        foreach (var voice in _voices) if (voice is not null) voice.StreamPaused = !_focused;
    }
}
