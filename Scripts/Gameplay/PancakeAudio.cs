using Godot;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public enum PancakeSound
{
    PickUp,
    Stroke,
    Sizzle,
    Flip,
    Ready,
    Success,
    Overdone,
    Error,
    CoinCollect,
    BookOpen,
    BookStamp,
    SoftDrop,
    CrispDrop,
    PaperBag,
    SpreadComplete,
    SupplyBell,
}

public partial class PancakeAudio : Node
{
    private readonly Dictionary<PancakeSound, AudioStreamWav> _sounds = new();
    private AudioStreamPlayer _player = null!;
    private AudioStreamPlayer _spreadPlayer = null!;
    private AudioStreamPlayer _supplyPlayer = null!;
    private bool _paused;
    private ulong? _lastErrorAt;
    internal Func<ulong> Clock { get; set; } = Time.GetTicksMsec;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        if (_player is null) { _player = new AudioStreamPlayer { VolumeDb = -12 }; AddChild(_player); }
        _player.Bus = ProjectCake.Core.JourneySettings.EffectsBus;
        _spreadPlayer = new AudioStreamPlayer
        {
            Name = "SpreadCompletePlayer",
            Bus = ProjectCake.Core.JourneySettings.EffectsBus,
            VolumeDb = -5,
            Stream = MakeChord(new[] { 880.0, 1320.0 }, .22, .38),
        };
        AddChild(_spreadPlayer);
        _supplyPlayer = new AudioStreamPlayer
        {
            Name = "SupplyBellPlayer",
            Bus = ProjectCake.Core.JourneySettings.EffectsBus,
            VolumeDb = SupplyBellAudio.VolumeDb,
            Stream = SupplyBellAudio.Stream,
        };
        AddChild(_supplyPlayer);
        _sounds[PancakeSound.BookOpen] = MakeNoise(.18, .10);
        _sounds[PancakeSound.BookStamp] = MakeNoise(.07, .18);
        _sounds[PancakeSound.SoftDrop] = CartoonActionClips.Load(CartoonActionClips.Drop);
        _sounds[PancakeSound.CrispDrop] = _sounds[PancakeSound.SoftDrop];
        _sounds[PancakeSound.PaperBag] = MakePaperRustle();
        _sounds[PancakeSound.PickUp] = CartoonActionClips.Load(CartoonActionClips.PickUp);
        _sounds[PancakeSound.Stroke] = CartoonActionClips.Load(CartoonActionClips.Mix);
        _sounds[PancakeSound.Sizzle] = MakeNoise(0.12, 0.16);
        _sounds[PancakeSound.Flip] = MakeTone(460, 0.09, 0.30);
        _sounds[PancakeSound.Ready] = MakeChord(new[] { 620.0, 820.0 }, 0.14, 0.22);
        _sounds[PancakeSound.Success] = MakeChord(new[] { 660.0, 880.0 }, 0.18, 0.25);
        _sounds[PancakeSound.Overdone] = MakeTone(230, 0.18, 0.24);
        _sounds[PancakeSound.Error] = CartoonActionClips.Load(CartoonActionClips.Error);
        _sounds[PancakeSound.CoinCollect] = MakeCoinChime();
    }

    public void Play(PancakeSound sound)
    {
        // Keep the completion cue audible even when the next ingredient is used immediately.
        if (sound == PancakeSound.SpreadComplete)
        {
            if (!_paused) _spreadPlayer.Play();
            return;
        }
        if (sound == PancakeSound.SupplyBell)
        {
            if (!_paused) _supplyPlayer.Play();
            return;
        }
        if (_paused || !_sounds.TryGetValue(sound, out AudioStreamWav? stream))
        {
            return;
        }
        if (sound == PancakeSound.Error)
        {
            ulong now = Clock();
            if (_lastErrorAt is ulong last && now - last < 1500) return;
            _lastErrorAt = now;
        }

        _player.StreamPaused = false;
        _player.VolumeDb = sound == PancakeSound.Stroke ? -8 : sound == PancakeSound.Error ? -6
            : sound is PancakeSound.PickUp or PancakeSound.SoftDrop or PancakeSound.CrispDrop ? -4 : -12;
        _player.Stream = stream;
        _player.Play();
    }

    public void SetPaused(bool paused) { _paused = paused; if (paused) { Stop(); _lastErrorAt = null; } }
    public void Stop()
    {
        _player?.Stop();
        _spreadPlayer?.Stop();
        _supplyPlayer?.Stop();
    }

    private static AudioStreamWav MakeCoinChime() => MakeWave(.28, sample =>
    {
        double t = sample / 22050.0, value = 0;
        for (int i = 0; i < 3; i++)
        {
            double local = t - i * .055;
            if (local < 0) continue;
            double frequency = 1046.5 * Math.Pow(1.25, i);
            value += (Math.Sin(Math.Tau * frequency * local) + .3 * Math.Sin(Math.Tau * frequency * 2.76 * local))
                * Math.Exp(-local * 30) * Math.Min(1, local * 800) * .24;
        }
        return value;
    });

    private static AudioStreamWav MakePaperRustle()
    {
        var random = new Random(219);
        double previous = 0;
        return MakeWave(.16, sample =>
        {
            double noise = random.NextDouble() * 2 - 1;
            double value = (noise - previous * .75) * .14
                * (.4 + .6 * Math.Pow(Math.Sin(sample / 22050.0 * 65), 2));
            previous = noise;
            return value;
        });
    }

    private static AudioStreamWav MakeTone(double frequency, double seconds, double amplitude) =>
        MakeWave(seconds, sample => Math.Sin(Math.Tau * frequency * sample / 22050.0) * amplitude);

    private static AudioStreamWav MakeChord(double[] frequencies, double seconds, double amplitude) =>
        MakeWave(seconds, sample => frequencies.Sum(frequency => Math.Sin(Math.Tau * frequency * sample / 22050.0)) * amplitude / frequencies.Length);

    private static AudioStreamWav MakeNoise(double seconds, double amplitude)
    {
        var random = new Random(1978);
        return MakeWave(seconds, _ => (random.NextDouble() * 2 - 1) * amplitude);
    }

    private static AudioStreamWav MakeWave(double seconds, Func<int, double> sampleValue)
    {
        const int sampleRate = 22050;
        int sampleCount = (int)(sampleRate * seconds);
        var data = new byte[sampleCount * 2];
        for (int sample = 0; sample < sampleCount; sample++)
        {
            double fade = 1.0 - (double)sample / sampleCount;
            short value = (short)Math.Clamp(sampleValue(sample) * fade * short.MaxValue, short.MinValue, short.MaxValue);
            data[sample * 2] = (byte)(value & 0xff);
            data[sample * 2 + 1] = (byte)((value >> 8) & 0xff);
        }

        return new AudioStreamWav
        {
            Format = AudioStreamWav.FormatEnum.Format16Bits,
            MixRate = sampleRate,
            Stereo = false,
            Data = data,
        };
    }
}
