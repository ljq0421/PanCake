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
}

public partial class PancakeAudio : Node
{
    private readonly Dictionary<PancakeSound, AudioStreamWav> _sounds = new();
    private AudioStreamPlayer _player = null!;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _sounds[PancakeSound.PickUp] = MakeTone(720, 0.06, 0.28);
        _sounds[PancakeSound.Stroke] = MakeTone(320, 0.08, 0.18);
        _sounds[PancakeSound.Sizzle] = MakeNoise(0.12, 0.16);
        _sounds[PancakeSound.Flip] = MakeTone(460, 0.09, 0.30);
        _sounds[PancakeSound.Ready] = MakeChord(new[] { 620.0, 820.0 }, 0.14, 0.22);
        _sounds[PancakeSound.Success] = MakeChord(new[] { 660.0, 880.0 }, 0.18, 0.25);
        _sounds[PancakeSound.Overdone] = MakeTone(230, 0.18, 0.24);
        _sounds[PancakeSound.Error] = MakeTone(145, 0.12, 0.28);
        _sounds[PancakeSound.CoinCollect] = MakeCoinChime();
    }

    public void Play(PancakeSound sound)
    {
        if (!_sounds.TryGetValue(sound, out AudioStreamWav? stream))
        {
            return;
        }

        _player.StreamPaused = false;
        _player.Stream = stream;
        _player.Play();
    }

    public void SetPaused(bool paused) => _player.StreamPaused = paused;
    public void Stop() => _player?.Stop();

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
