using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

/// <summary>One clear interface voice and one cooldown shared across menus.</summary>
public partial class ButtonHoverAudio : Node
{
    private AudioStreamPlayer _player = null!;
    private Control? _source;
    private bool _focused = true;
    private ulong? _last;
    internal Func<ulong> Clock { get; set; } = Time.GetTicksMsec;
    internal event Action? Played;

    internal static bool InScope(Control source)
    {
        // Sliders and cooking controls retain their existing feedback.
        if (source is Godot.Range) return false;
        for (Node? node = source; node is not null; node = node.GetParent())
        {
            if (node is EquipmentUpgradeView) return true;
            if (node is BusinessDetailsView book) return book.Model.Closing;
            if (node is StartScreen or TianjinMapScreen) return true;
        }
        return false;
    }

    internal static ButtonHoverAudio For(Node source)
    {
        var root = source.GetTree().Root;
        var audio = root.GetNodeOrNull<ButtonHoverAudio>("ButtonHoverAudio");
        if (audio is null) { audio = new() { Name = "ButtonHoverAudio" }; root.AddChild(audio); }
        return audio;
    }

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        _player = new AudioStreamPlayer { Bus = JourneySettings.EffectsBus, VolumeDb = -4, MaxPolyphony = 1, Stream = Make() };
        AddChild(_player);
    }

    internal void Play(Control source)
    {
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        if (!_focused || settings.Muted || settings.Master <= 0 || settings.Effects <= 0) return;
        ulong now = Clock();
        if (_last is { } last && now - last < 100) return;
        _last = now; _source = source;
        _player.Play(); Played?.Invoke();
    }

    public override void _Process(double delta)
    {
        if (!IsInstanceValid(_source) || !_source!.IsVisibleInTree() || _source.IsQueuedForDeletion()) _player.Stop();
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) { _focused = false; _player?.Stop(); }
        if (what == NotificationApplicationFocusIn) _focused = true;
    }
    public override void _ExitTree() => _player?.Stop();

    private static AudioStreamWav Make()
    {
        const int rate = 22050;
        const double duration = .055;
        var data = new byte[(int)(rate * duration) * 2];
        for (int i = 0; i < data.Length / 2; i++)
        {
            double t = (double)i / rate;
            double envelope = Math.Min(1, t / .004) * Math.Pow(1 - t / duration, 3);
            short sample = (short)(short.MaxValue * .4 * envelope * Math.Sin(Math.Tau * (480 * t - 800 * t * t)));
            data[2 * i] = (byte)(sample & 255); data[2 * i + 1] = (byte)(sample >> 8);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate, Data = data };
    }
}
