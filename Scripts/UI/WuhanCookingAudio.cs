using Godot;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

/// <summary>Quiet cooking textures; all playback follows the workstation's lifecycle.</summary>
internal sealed class WuhanCookingAudio
{
    private readonly AudioStreamPlayer _water, _pan, _ready;
    private bool _paused;

    internal WuhanCookingAudio(Node owner)
    {
        _water = Player(owner, "CookingWater", MakeWater());
        _pan = Player(owner, "CookingPan", MakeSizzle());
        _ready = Player(owner, "BasketReady", MakeReady());
        _ready.VolumeDb = -12;
    }

    private static AudioStreamPlayer Player(Node owner, string name, AudioStreamWav stream)
    {
        var player = new AudioStreamPlayer { Name = name, Stream = stream, VolumeDb = -24, Bus = "Master" };
        owner.AddChild(player);
        return player;
    }

    internal void Update(NoodleCookerStateMachine cooker, DoupiStateMachine? pan)
    {
        bool boiling = cooker.Baskets.Any(b => b.State is NoodleBasketState.Cooking or NoodleBasketState.Ready
            or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked);
        bool sizzling = pan?.State is DoupiState.SkinCooking or DoupiState.ReadyToFlip or DoupiState.SecondCooking
            or DoupiState.ReadyToCut or DoupiState.Overbrowned;
        float stress = pan?.HeatStress ?? 0;
        _pan.PitchScale = 1 + stress * .18f;
        _pan.VolumeDb = -26 + stress * 4;
        Sync(_water, boiling); Sync(_pan, sizzling);
    }

    private void Sync(AudioStreamPlayer player, bool active)
    {
        if (!active) { player.Stop(); return; }
        if (!player.Playing && !_paused) player.Play();
        player.StreamPaused = _paused;
    }

    internal void SetPaused(bool paused)
    {
        _paused = paused;
        _water.StreamPaused = _pan.StreamPaused = _ready.StreamPaused = paused;
    }

    internal void PlayBasketReady()
    {
        if (!_paused) _ready.Play();
    }

    internal void Stop() { _water.Stop(); _pan.Stop(); _ready.Stop(); _paused = false; }

    private static AudioStreamWav MakeReady() => MakeStream(t =>
        (Math.Sin(Math.Tau * 1046.5 * t) + .3 * Math.Sin(Math.Tau * 1569.75 * t))
        * .5 * Math.Min(1, t / .008) * Math.Exp(-t * 18), .28, false);

    private static AudioStreamWav MakeWater()
    {
        var random = new Random(9211);
        var bubbles = Enumerable.Range(0, 32).Select(_ => (Start: random.NextDouble() * 4,
            Frequency: 170 + random.NextDouble() * 280, Size: .15 + random.NextDouble() * .2)).ToArray();
        return MakeLoop(t => bubbles.Sum(b =>
        {
            double age = (t - b.Start + 4) % 4;
            return age > .18 ? 0 : Math.Sin(Math.Tau * b.Frequency * age * (1 - age))
                * Math.Exp(-age * 30) * Math.Min(1, age * 300) * b.Size;
        }));
    }

    private static AudioStreamWav MakeSizzle()
    {
        var random = new Random(9212);
        double filtered = 0;
        return MakeLoop(t =>
        {
            filtered = filtered * .45 + (random.NextDouble() * 2 - 1) * .55;
            double edge = Math.Min(1, Math.Min(t, 4 - t) * 100);
            return filtered * (.32 + .08 * Math.Sin(Math.Tau * 3 * t)) * edge;
        });
    }

    private static AudioStreamWav MakeLoop(Func<double, double> sample) => MakeStream(sample, 4, true);

    private static AudioStreamWav MakeStream(Func<double, double> sample, double seconds, bool loop)
    {
        const int rate = 22050;
        int count = (int)(rate * seconds);
        var bytes = new byte[count * 2];
        for (int i = 0; i < count; i++)
        {
            short value = (short)(Math.Clamp(sample(i / (double)rate), -1, 1) * short.MaxValue);
            bytes[i * 2] = (byte)(value & 255); bytes[i * 2 + 1] = (byte)(value >> 8);
        }
        return new AudioStreamWav { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate,
            Data = bytes, LoopMode = loop ? AudioStreamWav.LoopModeEnum.Forward : AudioStreamWav.LoopModeEnum.Disabled,
            LoopBegin = 0, LoopEnd = count };
    }
}
