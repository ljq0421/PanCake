using Godot;

namespace ProjectCake.Gameplay;

public enum PancakeSound
{
    PickUp,
    Stroke,
    Sizzle,
    Flip,
    Success,
    Overdone,
    Error,
}

public partial class PancakeAudio : Node
{
    private readonly Dictionary<PancakeSound, AudioStreamWav> _sounds = new();
    private AudioStreamPlayer _player = null!;

    public override void _Ready()
    {
        _player = new AudioStreamPlayer { VolumeDb = -10 };
        AddChild(_player);
        _sounds[PancakeSound.PickUp] = MakeTone(720, 0.06, 0.28);
        _sounds[PancakeSound.Stroke] = MakeTone(320, 0.08, 0.18);
        _sounds[PancakeSound.Sizzle] = MakeNoise(0.12, 0.16);
        _sounds[PancakeSound.Flip] = MakeTone(460, 0.09, 0.30);
        _sounds[PancakeSound.Success] = MakeChord(new[] { 660.0, 880.0 }, 0.18, 0.25);
        _sounds[PancakeSound.Overdone] = MakeTone(230, 0.18, 0.24);
        _sounds[PancakeSound.Error] = MakeTone(145, 0.12, 0.28);
    }

    public void Play(PancakeSound sound)
    {
        if (!_sounds.TryGetValue(sound, out AudioStreamWav? stream))
        {
            return;
        }

        _player.Stream = stream;
        _player.Play();
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
