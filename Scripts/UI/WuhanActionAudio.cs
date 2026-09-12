using Godot;

namespace ProjectCake.UI;

internal enum WuhanSound
{
    Drop, Raise, Pour, Season, Topping, Mix, Batter, Egg, Spread, Flip, Cut, Stock,
    Ready, Overdone, Success, Error, Discard, BookOpen, BookClose, Page,
}

/// <summary>Short, soft game cues. Cached PCM, bounded voices, and per-cue throttling.</summary>
internal sealed class WuhanActionAudio
{
    private static readonly Dictionary<WuhanSound, AudioStreamWav> Streams = new();
    private readonly Dictionary<WuhanSound, AudioStreamPlayer> _players = new();
    private readonly Dictionary<WuhanSound, ulong> _last = new();
    private readonly Node _owner;
    private bool _paused;

    internal WuhanActionAudio(Node owner) => _owner = owner;

    internal bool Play(WuhanSound sound)
    {
        if (_paused || !_owner.IsInsideTree()) return false;
        ulong now = Time.GetTicksMsec();
        ulong interval = sound is WuhanSound.Mix or WuhanSound.Spread ? 240UL
            : sound is WuhanSound.Error or WuhanSound.Overdone ? 400UL : 80UL;
        if (_last.TryGetValue(sound, out ulong last) && now - last < interval) return false;
        if (!_players.TryGetValue(sound, out var player))
        {
            if (!Streams.TryGetValue(sound, out var stream)) Streams[sound] = stream = Make(sound);
            player = new AudioStreamPlayer { Name = $"WuhanCue{sound}", Stream = stream,
                Bus = "Master", VolumeDb = sound is WuhanSound.Mix or WuhanSound.Spread ? -23 : -16,
                MaxPolyphony = 1 };
            _owner.AddChild(player);
            _players.Add(sound, player);
        }
        _last[sound] = now;
        player.Play();
        return true;
    }

    internal void SetPaused(bool paused)
    {
        if (paused && !_paused) Stop();
        _paused = paused;
    }

    internal void Stop()
    {
        foreach (var player in _players.Values) player.Stop();
        _last.Clear();
    }

    private static AudioStreamWav Make(WuhanSound sound)
    {
        (double pitch, double end, double length, double noise) = sound switch
        {
            WuhanSound.Drop => (480, 230, .14, .08),
            WuhanSound.Raise => (380, 780, .16, .04),
            WuhanSound.Pour => (760, 360, .22, .10),
            WuhanSound.Season => (920, 640, .13, .06),
            WuhanSound.Topping => (1100, 850, .09, .02),
            WuhanSound.Mix => (460, 540, .09, .12),
            WuhanSound.Batter => (360, 220, .20, .08),
            WuhanSound.Egg => (980, 520, .12, .04),
            WuhanSound.Spread => (330, 420, .10, .12),
            WuhanSound.Flip => (420, 1000, .18, .06),
            WuhanSound.Cut => (1250, 650, .065, .13),
            WuhanSound.Stock => (660, 880, .20, .02),
            WuhanSound.Ready => (880, 1100, .24, 0),
            WuhanSound.Overdone => (420, 230, .24, .02),
            WuhanSound.Success => (784, 1176, .25, 0),
            WuhanSound.Error => (340, 280, .13, 0),
            WuhanSound.Discard => (540, 180, .16, .08),
            WuhanSound.BookOpen => (520, 780, .15, .12),
            WuhanSound.BookClose => (680, 440, .12, .10),
            _ => (700, 850, .10, .16),
        };
        const int rate = 22050;
        int count = (int)(rate * length);
        byte[] data = new byte[count * 2];
        var random = new Random(92120 + (int)sound);
        double filtered = 0;
        for (int i = 0; i < count; i++)
        {
            double t = i / (double)rate, p = t / length;
            double phase = Math.Tau * (pitch * t + (end - pitch) * t * t / (2 * length));
            double envelope = Math.Min(1, t / .005) * Math.Pow(1 - p, 2) * Math.Exp(-p * 2);
            filtered = filtered * .55 + (random.NextDouble() * 2 - 1) * .45;
            double tone = Math.Sin(phase) * .65 + Math.Sin(phase * 2) * .12;
            if (sound is WuhanSound.Success or WuhanSound.Ready or WuhanSound.Stock)
                tone += Math.Sin(phase * 1.5) * .18;
            short value = (short)(Math.Clamp((tone + filtered * noise) * envelope * .7, -1, 1) * short.MaxValue);
            data[i * 2] = (byte)(value & 255);
            data[i * 2 + 1] = (byte)(value >> 8);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits,
            MixRate = rate, Data = data, LoopMode = AudioStreamWav.LoopModeEnum.Disabled };
    }
}
