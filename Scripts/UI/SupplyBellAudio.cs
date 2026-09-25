using Godot;

namespace ProjectCake.UI;

/// <summary>One bell timbre and playback level for every city's supply call.</summary>
internal static class SupplyBellAudio
{
    internal const float VolumeDb = -9;
    internal static AudioStreamWav Stream { get; } = Create();

    private static AudioStreamWav Create()
    {
        const int rate = 22050;
        int count = (int)(rate * .34);
        byte[] data = new byte[count * 2];
        for (int sample = 0; sample < count; sample++)
        {
            double t = sample / (double)rate;
            double strike = Math.Min(1, t * 1800) * Math.Exp(-t * 10);
            double tone = strike * (.22 * Math.Sin(Math.Tau * 880 * t)
                + .09 * Math.Sin(Math.Tau * 1764 * t)
                + .04 * Math.Sin(Math.Tau * 2652 * t));
            short value = (short)Math.Clamp(tone * (1.0 - (double)sample / count)
                * short.MaxValue, short.MinValue, short.MaxValue);
            data[sample * 2] = (byte)(value & 0xff);
            data[sample * 2 + 1] = (byte)((value >> 8) & 0xff);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits,
            MixRate = rate, Stereo = false, Data = data };
    }
}
