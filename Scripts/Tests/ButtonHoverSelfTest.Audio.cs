using Godot;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class ButtonHoverSelfTest
{
    private async Task CheckAudio(StartScreen start, Button home, JourneySettings settings)
    {
        if (settings.Muted) settings.ToggleMute();
        settings.SetVolume("master", 100); settings.SetVolume("effects", 100);
        Move(new(1918, 1078)); await Settle();
        var audio = ButtonHoverAudio.For(home);
        audio._Notification((int)NotificationApplicationFocusIn);
        ulong now = Time.GetTicksMsec() + 1000;
        audio.Clock = () => now;
        int plays = 0; audio.Played += () => plays++;
        Move(home.GetGlobalRect().GetCenter()); await Settle();
        Require(plays == 1, "native mouse entry plays once");
        now += 200; await Settle();
        Require(plays == 1, "stationary pointer does not repeat");
        var next = start.Descendants<Button>().First(b => b.Name == "Settings");
        Move(next.GetGlobalRect().GetCenter()); await Frames();
        Require(plays == 2, "another menu button plays");
        Move(home.GetGlobalRect().GetCenter()); await Frames();
        Require(plays == 2, "rapid crossing shares cooldown");
        now += 200; await Settle();
        Require(plays == 2, "suppressed entry is never queued");
        Move(new(1918, 1078)); await Frames();
        home.Disabled = true; Move(home.GetGlobalRect().GetCenter()); await Frames();
        Require(plays == 2, "disabled button is silent");
        home.Disabled = false;
        Move(new(1918, 1078)); await Frames(); home.GrabFocus(); await Frames();
        Require(plays == 2, "keyboard focus is silent");
        settings.ToggleMute(); Move(home.GetGlobalRect().GetCenter()); await Frames();
        Require(plays == 2, "mute is respected"); settings.ToggleMute();
        Move(new(1918, 1078)); await Frames(); settings.SetVolume("effects", 0);
        Move(home.GetGlobalRect().GetCenter()); await Frames();
        Require(plays == 2, "zero effects volume is silent"); settings.SetVolume("effects", 100);
        Move(new(1918, 1078)); await Frames();
        audio._Notification((int)NotificationApplicationFocusOut);
        Move(home.GetGlobalRect().GetCenter()); await Frames();
        Require(plays == 2, "unfocused application is silent");
        audio._Notification((int)NotificationApplicationFocusIn);
        now += 200; await Frames(); Require(plays == 2, "focus restoration does not replay");
        Move(new(1918, 1078)); await Frames(); Move(home.GetGlobalRect().GetCenter()); await Frames();
        Require(plays == 3, "fresh entry resumes audio");
        var player = audio.GetChildren().OfType<AudioStreamPlayer>().Single();
        Require(player.Bus == JourneySettings.EffectsBus && player.VolumeDb == -4 && player.MaxPolyphony == 1,
            "clear single voice uses effects bus");
        Require(player.Stream.GetLength() < .06, "hover cue stays short");
        var book = new BusinessDetailsView();
        var button = new Button(); book.AddChild(button);
        book.Model.Closing = true;
        Require(ButtonHoverAudio.InScope(button), "shared settlement has audio");
        book.Model.Closing = false;
        Require(!ButtonHoverAudio.InScope(button), "live business details remain silent");
        book.Free();
        var upgrade = new EquipmentUpgradeView(); var buy = new Button(); upgrade.AddChild(buy);
        Require(ButtonHoverAudio.InScope(buy), "upgrade purchase has audio"); upgrade.Free();
        var cooking = new Button(); Require(!ButtonHoverAudio.InScope(cooking), "unregistered gameplay button stays silent"); cooking.Free();
        var slider = new HSlider(); start.AddChild(slider);
        Require(!ButtonHoverAudio.InScope(slider), "sliders stay silent"); slider.QueueFree();
        start.PresentMap(); await Settle();
        Move(new(1918, 1078)); await Frames(); now += 200;
        int beforeMap = plays;
        var marker = start.Descendants<Button>().First(b => b.Name == "Node0");
        Move(marker.GetGlobalRect().GetCenter()); await Frames();
        Require(marker.IsHovered() && plays == beforeMap + 1, "native map marker entry plays audio");
    }
}
