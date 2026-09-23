using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

internal enum WuhanUnlockCue { Sweep, Unlock, Paper }

/// <summary>Original soft journey accents, independent of the shared homepage cues.</summary>
public partial class WuhanUnlockAudio : Node
{
    private readonly Dictionary<WuhanUnlockCue, AudioStreamWav> _streams = new();
    private AudioStreamPlayer? _player;
    private bool _focused = true;
    internal event Action<WuhanUnlockCue>? Played;

    internal void Play(WuhanUnlockCue cue)
    {
        if (!_focused || !IsInsideTree()) return;
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        if (settings.Muted || settings.Master <= 0 || settings.Effects <= 0) return;
        if (_player is null)
        {
            _player = new AudioStreamPlayer { Bus = JourneySettings.EffectsBus, VolumeDb = -4, MaxPolyphony = 1 };
            AddChild(_player);
        }
        if (!_streams.TryGetValue(cue, out var stream)) _streams[cue] = stream = Make(cue);
        _player.Stream = stream; _player.Play(); Played?.Invoke(cue);
    }
    public void Stop() => _player?.Stop();
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) { _focused = false; Stop(); }
        if (what == NotificationApplicationFocusIn) _focused = true;
    }
    public override void _ExitTree()
    {
        Stop();
        if (_player is not null) _player.Stream = null;
        foreach (var (cue, stream) in _streams)
            if (cue != WuhanUnlockCue.Paper) stream.Dispose();
        _streams.Clear();
    }

    internal static AudioStreamWav Make(WuhanUnlockCue cue)
    {
        if (cue == WuhanUnlockCue.Paper) return GD.Load<AudioStreamWav>(OpeningAudio.PaperPath);
        const int rate = 22050;
        double duration = cue == WuhanUnlockCue.Sweep ? .28 : .44;
        var samples = new double[(int)(rate * duration)];
        var random = new Random(923);
        double filtered = 0, smooth = 0, energy = 0, peak = 0;
        for (int i = 0; i < samples.Length; i++)
        {
            double t = (double)i / rate, p = (double)i / (samples.Length - 1);
            filtered += .18 * (random.NextDouble() * 2 - 1 - filtered);
            smooth += .12 * (filtered - smooth);
            // Air and a rounded upward glide; the destination uses two warm ascending notes.
            double value = cue == WuhanUnlockCue.Sweep
                ? Math.Pow(Math.Sin(Math.PI * p), 1.7) * (.85 * (filtered - smooth)
                    + .035 * Math.Sin(Math.Tau * (220 * t + 380 * t * t)))
                : Note(t, 523.25, .33) + .85 * Note(t - .105, 783.99, .335);
            value *= Math.Min(1, (duration - t) / .012);
            if (i == 0 || i == samples.Length - 1) value = 0;
            samples[i] = value; energy += value * value; peak = Math.Max(peak, Math.Abs(value));
        }
        double targetDb = cue == WuhanUnlockCue.Sweep ? -29 : -25;
        double gain = Math.Min(Math.Pow(10, targetDb / 20) / Math.Sqrt(energy / samples.Length), .8 / peak);
        var data = new byte[samples.Length * 2];
        for (int i = 0; i < samples.Length; i++)
        {
            short sample = (short)(samples[i] * gain * short.MaxValue);
            data[2 * i] = (byte)(sample & 255); data[2 * i + 1] = (byte)(sample >> 8);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate, Data = data };
    }
    private static double Note(double t, double frequency, double duration)
    {
        if (t <= 0 || t >= duration) return 0;
        double envelope = Math.Min(1, t / .012) * Math.Pow(1 - t / duration, 2.4);
        return envelope * (Math.Sin(Math.Tau * frequency * t) + .12 * Math.Sin(Math.Tau * frequency * 2 * t));
    }
}
