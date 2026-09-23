using Godot;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class WuhanUnlockSelfTest
{
    private void CheckUnlockAudio()
    {
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        if (settings.Muted) settings.ToggleMute();
        settings.SetVolume("master", 100); settings.SetVolume("effects", 100);
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
        var show = new WuhanUnlockPresentation(); AddChild(show);
        var audio = show.GetChildren().OfType<WuhanUnlockAudio>().Single();
        var cues = new List<WuhanUnlockCue>(); audio.Played += cues.Add;
        show.Begin(_save, _ => { });
        var timeline = (Tween)typeof(WuhanUnlockPresentation).GetField("_timeline",
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!.GetValue(show)!;
        timeline.Pause(); timeline.CustomStep(1.71); timeline.CustomStep(.6); timeline.CustomStep(1.6);
        Check(cues.SequenceEqual(new[] { WuhanUnlockCue.Sweep, WuhanUnlockCue.Unlock, WuhanUnlockCue.Paper }),
            "journey sounds follow map, unlock and book with exactly one paper cue");
        var player = audio.GetChildren().OfType<AudioStreamPlayer>().Single();
        Check(player.Bus == JourneySettings.EffectsBus && player.MaxPolyphony == 1, "unlock uses single effects voice");
        show.Skip();
        Check(!player.Playing && cues.Count == 3, "skip stops sound and never replays skipped cues");
        audio.Play(WuhanUnlockCue.Unlock);
        audio.Notification((int)NotificationApplicationFocusOut);
        int count = cues.Count;
        audio.Play(WuhanUnlockCue.Sweep);
        Check(!player.Playing && cues.Count == count, "focus loss stops audio and suppresses fresh cues");
        audio.Notification((int)NotificationApplicationFocusIn);
        Check(cues.Count == count, "focus restoration never replays sound");
        settings.ToggleMute(); audio.Play(WuhanUnlockCue.Unlock);
        Check(cues.Count == count, "unlock respects mute"); settings.ToggleMute();
        settings.SetVolume("effects", 0); audio.Play(WuhanUnlockCue.Unlock);
        Check(cues.Count == count, "unlock respects zero effects volume"); settings.SetVolume("effects", 100);
        settings.SetVolume("master", 0); audio.Play(WuhanUnlockCue.Unlock);
        Check(cues.Count == count, "unlock respects zero master volume"); settings.SetVolume("master", 100);
        audio.Play(WuhanUnlockCue.Sweep); RemoveChild(show);
        Check(!player.Playing, "exiting presentation stops sound"); show.Free();
        foreach (var cue in new[] { WuhanUnlockCue.Sweep, WuhanUnlockCue.Unlock })
        {
            using var stream = WuhanUnlockAudio.Make(cue);
            byte[] pcm = stream.Data;
            int peak = 0; double energy = 0;
            for (int i = 0; i < pcm.Length; i += 2)
            {
                int sample = (short)(pcm[i] | pcm[i + 1] << 8);
                peak = Math.Max(peak, Math.Abs(sample)); energy += (double)sample * sample;
            }
            Check(peak > 0 && peak < 30000 && energy > 0 && pcm[0] == 0 && pcm[1] == 0
                && pcm[^1] == 0 && pcm[^2] == 0, cue + " has audible, unclipped PCM with silent boundaries");
            Check(stream.SaveToWav(Path.Combine(_dir, cue + ".wav")) == Error.Ok, "export " + cue + " audition");
        }
        var reduced = new WuhanUnlockPresentation(); AddChild(reduced);
        var reducedCues = new List<WuhanUnlockCue>();
        reduced.GetChildren().OfType<WuhanUnlockAudio>().Single().Played += reducedCues.Add;
        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        reduced.Begin(_save, _ => { });
        Check(reducedCues.SequenceEqual(new[] { WuhanUnlockCue.Sweep }), "reduced motion does not burst skipped cues");
        reduced.Free(); ProjectSettings.SetSetting("accessibility/reduce_motion", false);
    }
}
