using Godot;

namespace ProjectCake.UI;

/// <summary>Home-only environmental motion; its clock stops behind books and on focus loss.</summary>
public partial class HomeAmbientMotion : Node
{
    public StartScreen Screen { get; init; } = null!;
    public TextureRect Clouds { get; init; } = null!;
    public TextureRect[] Steam { get; init; } = Array.Empty<TextureRect>();
    public TextureRect Sign { get; init; } = null!;
    public ShaderMaterial Sunlight { get; init; } = null!;
    private double _time;
    private bool _focused = true;

    public override void _Ready() => Apply(0);

    public override void _Process(double delta)
    {
        if (!Screen.IsVisibleInTree() || Screen.ModalOpen || Screen.Page != JourneyPage.Home || !_focused) return;
        if (!JourneyTransition.Reduced) _time += delta;
        Apply(JourneyTransition.Reduced ? 0 : _time);
    }

    private void Apply(double time)
    {
        // CPU-owned phase also freezes shader motion behind modals and on focus loss.
        Sunlight.SetShaderParameter("phase", (float)(time * Math.PI / 3.5));
        Sign.Rotation = Mathf.DegToRad(5f) * Mathf.Sin((float)(time * Math.PI / 2.4));
        Clouds.Position = new(-45 - 25 * Mathf.Cos((float)(time * Math.PI / 18)), 0);
        for (int i = 0; i < Steam.Length; i++)
        {
            float phase = (float)((time / 3.6 + i / 3.0) % 1);
            // Invisible at each wrap, so the next wisp starts at the bowl without popping.
            float alpha = .30f * Mathf.Sin(phase * Mathf.Pi);
            Steam[i].Position = new(1601 + (i - 1) * 8 + Mathf.Sin(phase * Mathf.Pi) * 9,
                779 - phase * 62);
            Steam[i].Scale = new(.70f + phase * .38f, .72f + phase * .35f);
            Steam[i].Modulate = new(1, 1, 1, alpha);
        }
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) _focused = false;
        else if (what == NotificationApplicationFocusIn) _focused = true;
    }
}
