using Godot;
using ProjectCake.Gameplay;

namespace ProjectCake.UI;

/// <summary>Shared, bounded voices. Customer and cash cues never replace each other's stream.</summary>
public partial class BusinessFeedbackAudio : Node
{
    private static readonly Dictionary<BusinessCue, AudioStreamWav> Streams = new();
    private readonly Dictionary<BusinessCue, AudioStreamPlayer> _players = new();
    private readonly Dictionary<BusinessCue, ulong> _last = new();
    private BusinessFeedback? _source;
    private Func<bool>? _canPlay;
    private bool _useCartoonCoin;
    private bool _useCartoonError;
    private bool _useCartoonCompletion;
    internal const string CartoonCoinPath = "res://resource/audio/sfx/coin-credit-c03a.wav";
    internal const string CartoonCompletionPath = "res://resource/audio/sfx/order-complete-k11b.wav";
    internal Func<ulong> Clock { get; set; } = Time.GetTicksMsec;
    internal event Action<BusinessFeedbackEvent>? Played;

    public static BusinessFeedbackAudio Attach(Node owner, BusinessFeedback source, Func<bool> canPlay, bool useCartoonCoin = false, bool useCartoonError = false, bool useCartoonCompletion = false)
    {
        var audio = owner.GetNodeOrNull<BusinessFeedbackAudio>("BusinessFeedbackAudio");
        if (audio is null) { audio = new() { Name = "BusinessFeedbackAudio" }; owner.AddChild(audio); }
        audio.Bind(source, canPlay, useCartoonCoin, useCartoonError, useCartoonCompletion);
        return audio;
    }
    public void Bind(BusinessFeedback source, Func<bool> canPlay, bool useCartoonCoin = false, bool useCartoonError = false, bool useCartoonCompletion = false)
    {
        Unbind(); _source = source; _canPlay = canPlay;
        if (_useCartoonCoin != useCartoonCoin && _players.Remove(BusinessCue.CoinCredited, out var coinPlayer))
            coinPlayer.QueueFree();
        _useCartoonCoin = useCartoonCoin;
        if (_useCartoonError != useCartoonError && _players.Remove(BusinessCue.DeliveryError, out var errorPlayer))
            errorPlayer.QueueFree();
        _useCartoonError = useCartoonError;
        if (_useCartoonCompletion != useCartoonCompletion && _players.Remove(BusinessCue.OrderCompleted, out var completionPlayer))
            completionPlayer.QueueFree();
        _useCartoonCompletion = useCartoonCompletion;
        source.Requested += OnRequested; source.ResetRequested += Reset;
    }
    private void Unbind()
    {
        if (_source is not null) { _source.Requested -= OnRequested; _source.ResetRequested -= Reset; }
        _source = null; Reset();
    }
    private void OnRequested(BusinessFeedbackEvent feedback)
    {
        if (!IsInsideTree() || _canPlay?.Invoke() != true) return;
        ulong now = Clock();
        ulong interval = feedback.Cue == BusinessCue.DeliveryError ? 1500UL
            : feedback.Cue is BusinessCue.LowPatience or BusinessCue.CustomerLeft ? 500UL : 0;
        if (_last.TryGetValue(feedback.Cue, out ulong last) && now - last < interval) return;
        _last[feedback.Cue] = now;
        if (!_players.TryGetValue(feedback.Cue, out var player))
        {
            bool cartoonCoin = _useCartoonCoin && feedback.Cue == BusinessCue.CoinCredited;
            bool cartoonError = _useCartoonError && feedback.Cue == BusinessCue.DeliveryError;
            bool cartoonCompletion = _useCartoonCompletion && feedback.Cue == BusinessCue.OrderCompleted;
            AudioStreamWav stream;
            if (cartoonCoin) stream = GD.Load<AudioStreamWav>(CartoonCoinPath);
            else if (cartoonError) stream = CartoonActionClips.Load(CartoonActionClips.Error);
            else if (cartoonCompletion) stream = GD.Load<AudioStreamWav>(CartoonCompletionPath);
            else if (!Streams.TryGetValue(feedback.Cue, out stream!)) Streams[feedback.Cue] = stream = Make(feedback.Cue);
            player = new AudioStreamPlayer { Name = feedback.Cue.ToString(), Stream = stream,
                Bus = ProjectCake.Core.JourneySettings.EffectsBus,
                VolumeDb = feedback.Cue == BusinessCue.LowPatience ? -8 : cartoonCoin ? 0 : cartoonError ? -6 : cartoonCompletion ? -4 : -16,
                MaxPolyphony = cartoonError || feedback.Cue == BusinessCue.LowPatience ? 1 : 3 };
            AddChild(player); _players.Add(feedback.Cue, player);
        }
        player.Play(); Played?.Invoke(feedback);
    }
    public override void _Process(double delta) { if (_canPlay?.Invoke() != true) Stop(); }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) Stop();
    }
    private void Stop() { foreach (var player in _players.Values) player.Stop(); }
    public void Reset() { Stop(); _last.Clear(); }
    public override void _ExitTree() => Unbind();

    internal static AudioStreamWav Make(BusinessCue cue)
    {
        if (cue == BusinessCue.LowPatience) return MakeAngryGrumble();
        // Soft attack and exponential release avoid clicks; short melodic contours convey intent.
        double[] notes = cue switch
        {
            BusinessCue.ItemAccepted => new[] { 659.25, 880.0 },
            BusinessCue.OrderCompleted => new[] { 659.25, 880.0, 1108.73 },
            BusinessCue.DeliveryError => new[] { 349.23, 293.66 },
            BusinessCue.CustomerLeft => new[] { 440.0, 349.23, 261.63 },
            _ => new[] { 1046.5, 1318.51, 1567.98 },
        };
        double spacing = cue == BusinessCue.CoinCredited ? .055 : cue == BusinessCue.ItemAccepted ? .065 : .09;
        double duration = spacing * (notes.Length - 1) + .16;
        const int rate = 22050;
        byte[] data = new byte[(int)(rate * duration) * 2];
        for (int i = 0; i < data.Length / 2; i++)
        {
            double t = i / (double)rate, value = 0;
            for (int n = 0; n < notes.Length; n++)
            {
                double local = t - n * spacing;
                if (local < 0 || local > .16) continue;
                double phase = Math.Tau * notes[n] * local;
                double envelope = Math.Min(1, local / .005) * Math.Exp(-local * 28) * Math.Min(1, (.16 - local) / .025);
                value += (Math.Sin(phase) + (cue == BusinessCue.CoinCredited ? .3 * Math.Sin(phase * 2.76) : .12 * Math.Sin(phase * 2))) * envelope * .28;
            }
            short sample = (short)(Math.Clamp(value, -1, 1) * short.MaxValue);
            data[i * 2] = (byte)(sample & 255); data[i * 2 + 1] = (byte)(sample >> 8);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate, Data = data };
    }

    private static AudioStreamWav MakeAngryGrumble()
    {
        // Original synthesized cartoon "hm-HMM": two voiced grumbles, not a reward chime.
        // Harmonics and pitch wobble keep it audible without a sharp alarm-like attack.
        const int rate = 22050;
        const double duration = .76;
        byte[] data = new byte[(int)(rate * duration) * 2];
        double phase = 0;
        for (int i = 0; i < data.Length / 2; i++)
        {
            double t = i / (double)rate;
            bool second = t >= .31;
            double local = second ? t - .31 : t;
            double length = second ? .45 : .23;
            if (local >= length) { phase = 0; continue; }
            double progress = local / length;
            double frequency = (second ? 265 : 235) - 85 * progress
                + 10 * Math.Sin(Math.Tau * 17 * local);
            phase += Math.Tau * frequency / rate;
            double envelope = Math.Min(1, local / .018) * Math.Min(1, (length - local) / .085)
                * (1 - .25 * progress);
            double voice = Math.Sin(phase) + .48 * Math.Sin(2 * phase)
                + .32 * Math.Sin(3 * phase) + .18 * Math.Sin(5 * phase);
            double flutter = .88 + .12 * Math.Sin(Math.Tau * 31 * local);
            double value = .38 * voice * envelope * flutter * (second ? 1 : .85);
            short sample = (short)(Math.Clamp(value, -1, 1) * short.MaxValue);
            data[i * 2] = (byte)(sample & 255); data[i * 2 + 1] = (byte)(sample >> 8);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate, Data = data };
    }
}
