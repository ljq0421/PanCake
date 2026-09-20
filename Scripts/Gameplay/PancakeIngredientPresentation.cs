using Godot;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private TextureRect? _batterStream;
    private void StartDetailedBatterDrop()
    {
        if (ReducedMotion) { FinishBatterDropAnimation(); return; }
        _batterTween?.Kill();
        Vector2 target = GetGlobalTransform().AffineInverse() * (_canvas.GetGlobalTransform() * _canvas.GetSurfaceRect().GetCenter());
        Vector2 size = _batterLadle.Size;
        _batterLadle.Position = target - size * .5f - new Vector2(-16, 78);
        _batterLadle.PivotOffset = size * .5f;
        _batterLadle.RotationDegrees = 0;
        _batterLadle.Scale = Vector2.One;
        _batterLadle.Modulate = Colors.White;
        _batterLadle.Show();
        if (_batterStream is null)
        {
            _batterStream = new TextureRect { Name = "BatterPourStream", Texture = _art.BatterStream,
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.Scale,
                MouseFilter = MouseFilterEnum.Ignore, ZIndex = 84 };
            AddChild(_batterStream);
        }
        _batterStream.Size = new(18, 44);
        _batterStream.Position = target - new Vector2(9, 44);
        _batterStream.Modulate = new Color(1, 1, 1, 0);
        _batterStream.Show();
        Tween tween = CreateTween();
        _batterTween = tween;
        tween.TweenMethod(Callable.From<float>(t =>
        {
            _batterLadle.RotationDegrees = -18 * Mathf.Clamp(t / .07f, 0, 1);
            _batterStream.Modulate = new Color(1, 1, 1, Mathf.Clamp((t - .05f) / .03f, 0, 1) * (1 - Mathf.Clamp((t - .16f) / .07f, 0, 1)));
            _canvas.BatterDropProgress = Mathf.Clamp((t - .08f) / .12f, 0, 1);
            _batterLadle.Modulate = new Color(1, 1, 1, 1 - Mathf.Clamp((t - .16f) / .08f, 0, 1));
        }), 0f, .24f, .24);
        tween.Finished += () => { if (_batterTween == tween) FinishBatterDropAnimation(); };
    }
}
