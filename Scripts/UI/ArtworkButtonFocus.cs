using Godot;

namespace ProjectCake.UI;

/// <summary>Keyboard feedback follows image alpha, never the rectangular input area.</summary>
public partial class ArtworkButtonFocus : Control
{
    private Button _button = null!;
    private TextureRect? _art;
    private NinePatchRect? _patch;
    private Color _patchColor;
    private bool _textOnly;

    public static void Attach(Button button, TextureRect? art = null)
    {
        button.AddThemeStyleboxOverride("focus", new StyleBoxEmpty());
        if (button.GetNodeOrNull<ArtworkButtonFocus>("ArtworkFocus") is not null) return;
        button.AddChild(new ArtworkButtonFocus
        {
            Name = "ArtworkFocus", MouseFilter = MouseFilterEnum.Ignore,
            _button = button, _art = art
        });
    }

    public override void _Ready()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        // Factories append their artwork after creating the native Button.
        CallDeferred(nameof(Configure));
    }

    private bool Active => !_button.Disabled && _button.IsVisibleInTree() && _button.HasFocus();

    private void Configure()
    {
        if (!IsInsideTree() || IsQueuedForDeletion() || _button.IsQueuedForDeletion()) return;
        _art ??= _button.GetChildren().OfType<TextureRect>().FirstOrDefault();
        _patch = _button.GetChildren().OfType<NinePatchRect>().FirstOrDefault();
        if (_art is not null)
            ArtContourHighlight.Attach(_art, () => Active ? InteractionHighlightState.Selected : InteractionHighlightState.None);
        else if (_patch is not null)
        {
            // Nine-patch geometry is already authored; tint that exact rendered silhouette.
            _patchColor = _patch.SelfModulate;
        }
        else _textOnly = true;
        _button.FocusEntered += Refresh;
        _button.FocusExited += Refresh;
        _button.VisibilityChanged += Refresh;
        _button.Draw += Refresh;
        Refresh();
    }

    private void Refresh()
    {
        if (_patch is not null && IsInstanceValid(_patch))
            _patch.SelfModulate = Active ? _patchColor * new Color(1.12f, 1.06f, .82f) : _patchColor;
        if (_textOnly) { Visible = Active; QueueRedraw(); }
    }

    public override void _Draw()
    {
        // Plain text actions get an underline, not a box around empty space.
        if (_textOnly && Active)
            DrawLine(new(Size.X * .2f, Size.Y - 5), new(Size.X * .8f, Size.Y - 5), StartScreenTheme.Apricot, 3, true);
    }
}
