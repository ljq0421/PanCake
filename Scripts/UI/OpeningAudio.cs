using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public enum OpeningCue { Click, Locate, Paper, Postcard }

/// <summary>Short opening cues; independent of business rewards and progress.</summary>
public partial class OpeningAudio : Node
{
    private static readonly Dictionary<OpeningCue, AudioStreamWav> Streams = new();
    private AudioStreamPlayer? _player;
    internal const string ClickPath = "res://resource/audio/sfx/home-click-h05.wav";
    internal const string PaperPath = "res://resource/audio/sfx/home-paper-h08c.wav";
    internal event Action<OpeningCue>? Played;
    public void Play(OpeningCue cue)
    {
        if (!IsInsideTree()) return;
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        if (settings.Muted || settings.Master <= 0 || settings.Effects <= 0) return;
        if (_player is null)
        {
            _player = new AudioStreamPlayer { Bus = JourneySettings.EffectsBus, VolumeDb = -19, MaxPolyphony = 1 };
            AddChild(_player);
        }
        if (!Streams.TryGetValue(cue, out var stream)) Streams[cue] = stream = Make(cue);
        _player.VolumeDb = cue == OpeningCue.Locate ? -19 : -4;
        _player.Stream = stream; _player.Play(); Played?.Invoke(cue);
    }
    public void Stop() => _player?.Stop();
    public override void _Notification(int what) { if (what == NotificationApplicationFocusOut) Stop(); }
    public override void _ExitTree() => Stop();
    internal static AudioStreamWav Make(OpeningCue cue)
    {
        if (cue == OpeningCue.Click) return GD.Load<AudioStreamWav>(ClickPath);
        if (cue is OpeningCue.Paper or OpeningCue.Postcard) return GD.Load<AudioStreamWav>(PaperPath);
        const int rate = 22050;
        double duration = cue == OpeningCue.Paper ? .32 : cue == OpeningCue.Locate ? .18 : .10;
        var data = new byte[(int)(rate * duration) * 2];
        var random = new Random(731 + (int)cue); double filtered = 0;
        for (int i = 0; i < data.Length / 2; i++)
        {
            double t = (double)i / rate, p = t / duration;
            double noise = random.NextDouble() * 2 - 1;
            filtered = .65 * filtered + .35 * noise;
            double envelope = Math.Min(1, t / .006) * Math.Pow(1 - p, cue == OpeningCue.Paper ? 1.2 : 3);
            double value = cue switch
            {
                OpeningCue.Paper => (noise - filtered) * .32 * Math.Sin(Math.PI * p),
                OpeningCue.Locate => .38 * Math.Sin(Math.Tau * (780 * t - 900 * t * t)),
                OpeningCue.Postcard => .32 * filtered + .12 * Math.Sin(Math.Tau * 180 * t),
                _ => .24 * Math.Sin(Math.Tau * 380 * t) + .14 * filtered
            };
            short sample = (short)(Math.Clamp(value * envelope, -.9, .9) * short.MaxValue);
            data[2 * i] = (byte)(sample & 255); data[2 * i + 1] = (byte)(sample >> 8);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate, Stereo = false, Data = data };
    }
}
