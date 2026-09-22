using Godot;

namespace ProjectCake.UI;

/// <summary>A single shop-opening beat per application session, with immediately usable controls.</summary>
public partial class HomeEntranceMotion : Node
{
    public StartScreen Screen { get; init; } = null!;
    public Control Logo { get; init; } = null!;
    public Control[] Actions { get; init; } = Array.Empty<Control>();
    private Vector2 _logoRest;
    private float[] _actionAlpha = Array.Empty<float>();
    private double _elapsed;
    public bool Finished { get; private set; }

    public override void _Ready()
    {
        _logoRest = Logo.Position;
        Logo.PivotOffset = Logo.Size * .5f;
        _actionAlpha = Actions.Select(a => a.Modulate.A).ToArray();
        Apply(0);
        if (JourneyTransition.Reduced) Finish();
    }

    public override void _Process(double delta)
    {
        if (Finished) return;
        if (JourneyTransition.Reduced || !Screen.IsVisibleInTree() || Screen.ModalOpen || Screen.Page != JourneyPage.Home)
        { Finish(); return; }
        // Initial texture uploads can stall a frame; do not consume the reveal before it is drawn.
        _elapsed += Math.Min(delta, .05);
        Apply((float)_elapsed);
        if (_elapsed >= .90) Finish();
    }

    private void Apply(float time)
    {
        float logo = 1 - Mathf.Pow(1 - Mathf.Clamp(time / .58f, 0, 1), 3);
        Logo.Position = _logoRest + new Vector2(0, -40 * (1 - logo));
        float scale = time < .30f ? Mathf.Lerp(.90f, 1.035f, Ease(time / .30f))
            : time < .45f ? Mathf.Lerp(1.035f, .99f, Ease((time - .30f) / .15f))
            : Mathf.Lerp(.99f, 1, Ease((time - .45f) / .15f));
        Logo.Scale = Vector2.One * scale;
        // Remain visible from frame one; buttons never move or lose their hit regions.
        Logo.Modulate = new(1, 1, 1, .35f + .65f * logo);
        for (int i = 0; i < Actions.Length; i++)
        {
            float progress = Mathf.Clamp((time - .20f - i * .06f) / .52f, 0, 1);
            Actions[i].Modulate = new(1, 1, 1, _actionAlpha[i] * (.30f + .70f * progress));
        }
    }

    private static float Ease(float progress) => Mathf.SmoothStep(0, 1, Mathf.Clamp(progress, 0, 1));

    private void Finish()
    {
        Apply(1);
        Finished = true;
        SetProcess(false);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut && _actionAlpha.Length == Actions.Length) Finish();
    }
}
