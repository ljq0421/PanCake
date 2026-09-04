using Godot;

namespace ProjectCake.Interaction;

public partial class DropZone : PanelContainer
{
    private readonly StyleBoxFlat _style = new();
    private Func<string, bool>? _canAccept;
    private Action<string>? _accepted;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        _style.BgColor = new Color(0, 0, 0, 0);
        _style.BorderWidthLeft = 3;
        _style.BorderWidthTop = 3;
        _style.BorderWidthRight = 3;
        _style.BorderWidthBottom = 3;
        _style.BorderColor = new Color(1, 1, 1, 0);
        _style.CornerRadiusTopLeft = 18;
        _style.CornerRadiusTopRight = 18;
        _style.CornerRadiusBottomLeft = 18;
        _style.CornerRadiusBottomRight = 18;
        AddThemeStyleboxOverride("panel", _style);
    }

    public void Configure(Func<string, bool> canAccept, Action<string> accepted)
    {
        _canAccept = canAccept;
        _accepted = accepted;
    }

    public bool CanAccept(string payloadId) => _canAccept?.Invoke(payloadId) == true;

    public void Accept(string payloadId) => _accepted?.Invoke(payloadId);

    public void SetDragHighlight(bool visible, bool valid)
    {
        _style.BorderColor = visible
            ? valid ? new Color("#77D895") : new Color("#E36C5B")
            : new Color(1, 1, 1, 0);
        _style.BgColor = visible
            ? valid ? new Color(0.18f, 0.55f, 0.30f, 0.10f) : new Color(0.75f, 0.15f, 0.12f, 0.08f)
            : new Color(0, 0, 0, 0);
        QueueRedraw();
    }
}

