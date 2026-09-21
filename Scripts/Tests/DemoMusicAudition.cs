using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;
using ProjectCake.Gameplay;
namespace ProjectCake.Tests;
public partial class DemoMusicAudition : Node
{
    public override void _Ready()
    {
        try
        {
            var music = new DemoMusicPlayer();
            AddChild(music);
            music.SetProcess(false);
            music._Notification((int)NotificationApplicationFocusIn);
            music.SetContext(StableIds.Cities.Tianjin, false, 2);
            music.SetContext(StableIds.Cities.Wuhan, false, 2);
            var active = music.GetChildren().OfType<AudioStreamPlayer>().Single(p => p.Playing);
            var expected = File.ReadAllBytes(ProjectSettings.GlobalizePath("res://resource/audio/demo/Monkeys Spinning Monkeys.mp3"));
            if (active.Stream is not AudioStreamMP3 actual || !actual.Loop || !actual.Data.SequenceEqual(expected))
                throw new InvalidOperationException("Wuhan must play and loop the approved music after switching from Tianjin.");
            music.SetContext(StableIds.Cities.Wuhan, true, 2);
            if (music.DuckGain != .25f) throw new InvalidOperationException("Music attenuation failed.");
            music._Notification((int)NotificationApplicationFocusOut);
            if (!active.StreamPaused) throw new InvalidOperationException("Focus loss must pause music.");
            music._Notification((int)NotificationApplicationFocusIn);
            if (active.StreamPaused) throw new InvalidOperationException("Focus return must resume music.");
            GD.Print("MUSIC_PLAYBACK_OK Wuhan: approved stream, loop, city switch, attenuation, focus pause/resume");
            music.QueueFree();
            string dir = ProjectSettings.GlobalizePath("res://output/music-audition");
            int rate = (int)AudioServer.GetMixRate();
            foreach (var (name, tag) in new[] { ("Wholesome", "01-home"), ("Carefree", "02-tianjin"), ("Monkeys Spinning Monkeys", "03-wuhan") })
            {
                using var stream = new AudioStreamMP3 { Data = File.ReadAllBytes(ProjectSettings.GlobalizePath("res://resource/audio/demo/" + name + ".mp3")) };
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
