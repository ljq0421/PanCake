using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class JourneyTransition
{
    private bool _paperDeparture;
    private ColorRect? _departurePaper;
    private Action? _whenCovered, _whenRevealed;
    private OpeningAudio? _departureAudio;
    public bool PaperDepartureActive => _paperDeparture;

    public void PlayPaperDeparture(DayController day, Action covered, Action revealed)
    {
        if (_paperDeparture) return;
        Finish();
        _paperDeparture = true; _active = true; _day = day;
        _whenCovered = covered; _whenRevealed = revealed;
        day.SetPauseReason("first-journey-departure", true);
        _departurePaper ??= new ColorRect { Name = "DeparturePaper", MouseFilter = Control.MouseFilterEnum.Stop };
        if (_departurePaper.GetParent() is null)
        {
            AddChild(_departurePaper);
            _departurePaper.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        }
        var material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/journey_departure.gdshader") };
        _departurePaper.Material = material;
        material.SetShaderParameter("reduced", Reduced);
        material.SetShaderParameter("progress", 0f);
        _departurePaper.Show();
        GetParent().MoveChild(this, -1);
        _departureAudio ??= new OpeningAudio { Name = "DepartureAudio" };
        if (_departureAudio.GetParent() is null) AddChild(_departureAudio);
        _departureAudio.Play(OpeningCue.Paper);
        double half = Reduced ? .1 : .55;
        _tween = CreateTween();
        _tween.TweenMethod(Callable.From<float>(p => material.SetShaderParameter("progress", p)), 0f, .5f, half);
        _tween.TweenCallback(Callable.From(CoverPaperDeparture));
        _tween.TweenMethod(Callable.From<float>(p => material.SetShaderParameter("progress", p)), .5f, 1f, half);
        _tween.TweenCallback(Callable.From(CompletePaperDeparture));
    }

    private void CoverPaperDeparture()
    {
        var callback = _whenCovered; _whenCovered = null;
        callback?.Invoke();
    }
    private void CompletePaperDeparture()
    {
        if (!_paperDeparture) return;
        CoverPaperDeparture();
        var callback = _whenRevealed; _whenRevealed = null;
        // BeginDay may prepare the demo tutorial; release only our own pause reason afterward.
        callback?.Invoke();
        CancelPaperDeparture();
    }
    private void CancelPaperDeparture()
    {
        _tween?.Kill(); _tween = null;
        _whenCovered = null; _whenRevealed = null;
        _departurePaper?.Hide(); _departureAudio?.Stop();
        if (IsInstanceValid(_day)) _day!.SetPauseReason("first-journey-departure", false);
        _day = null; _paperDeparture = false; _active = false;
    }
}
