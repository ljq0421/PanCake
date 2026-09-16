using Godot;
using ProjectCake.UI;
using ProjectCake.Gameplay;
namespace ProjectCake.Tests;
public partial class DemoMusicAudition : Node
{
    public override void _Ready()
    {
        try
        {
            string dir = ProjectSettings.GlobalizePath("res://output/music-audition");
            int rate = (int)AudioServer.GetMixRate();
            foreach (var (name, tag) in new[] { ("Wholesome", "01-home"), ("Carefree", "02-tianjin"), ("Local Forecast - Elevator", "03-wuhan") })
            {
                using var stream = new AudioStreamMP3 { Data = File.ReadAllBytes(Path.Combine(dir, name + ".mp3")) };
                using var playback = stream.InstantiatePlayback(); playback.Start(24);
                var samples = playback.MixAudio(1, rate * 30);
                var data = new byte[samples.Length * 4];
                // Same -16 dB cues as gameplay; candidate bed starts at -18 dB.
                var cues = new[] { BusinessCue.ItemAccepted, BusinessCue.OrderCompleted, BusinessCue.CoinCredited, BusinessCue.DeliveryError, BusinessCue.LowPatience };
                var voices = new List<(int Start, Vector2[] Samples)>();
                for (int i = 0; i < 24; i++)
                {
                    using var cue = BusinessFeedbackAudio.Make(cues[i % cues.Length]);
                    using var voice = cue.InstantiatePlayback(); voice.Start();
                    voices.Add(((int)((3 + i * .94) * rate), voice.MixAudio(1, (int)(rate * .5))));
                }
                for (int i = 0; i < samples.Length; i++)
                {
                    Vector2 value = samples[i] * Mathf.DbToLinear(-18);
                    foreach (var voice in voices)
                        if (i >= voice.Start && i - voice.Start < voice.Samples.Length) value += voice.Samples[i - voice.Start] * Mathf.DbToLinear(-16);
                    float fade = Math.Min(1, Math.Min(i / (float)rate, (samples.Length - i) / (float)rate));
                    for (int ch = 0; ch < 2; ch++)
                    {
                        short pcm = (short)(Math.Clamp(value[ch] * fade, -1, 1) * short.MaxValue);
                        data[i * 4 + ch * 2] = (byte)(pcm & 255); data[i * 4 + ch * 2 + 1] = (byte)(pcm >> 8);
                    }
                }
                using var wav = new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate, Stereo = true, Data = data };
                if (wav.SaveToWav(Path.Combine(dir, tag + "-peak.wav")) != Error.Ok) throw new IOException("Cannot save audition.");
                GD.Print("AUDITION_OK " + name + " frames=" + samples.Length);
            }
            GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}

