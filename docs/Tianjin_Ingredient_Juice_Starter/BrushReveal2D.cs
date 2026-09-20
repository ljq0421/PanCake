#nullable enable
using Godot;
using System;

/// <summary>
/// 挂在“最终酱料覆盖层”的 Sprite2D 上，仅负责路径显现。
/// 从现有输入控制器调用 PaintAtGlobal(brushTip.GlobalPosition)，
/// 抬起鼠标/离开制作区/切换阶段时调用 EndStroke()。
/// 业务确认刷酱完成后才调用 FinishVisual()，本组件不决定完成条件。
/// 第一版仅支持：独立单帧贴图、不使用 Region/AtlasTexture/FlipH/FlipV。
/// </summary>
public partial class BrushReveal2D : Sprite2D
{
    [Export] public Shader? RevealShader { get; set; }
    [Export(PropertyHint.Range, "64,512,1")]
    public int MaskResolution { get; set; } = 256;
    [Export(PropertyHint.Range, "0.005,0.20,0.005")]
    public float BrushRadiusUv { get; set; } = 0.07f;

    private Image _maskImage = null!;
    private ImageTexture _maskTexture = null!;
    private ShaderMaterial _revealMaterial = null!;
    private Vector2? _lastUv;
    private Tween? _finishTween;
    private int _size;
    private bool _dirty;
    private bool _configured;
    private float _completeReveal;

    public override void _Ready()
    {
        if (RevealShader == null || Texture == null)
        {
            GD.PushError($"{Name}: 请设置 Texture 和 RevealShader。");
            return;
        }
        if (RegionEnabled || Hframes != 1 || Vframes != 1 || FlipH || FlipV ||
            Texture is AtlasTexture)
        {
            GD.PushError($"{Name}: 此示例需要未翻转的独立单帧贴图，不支持图集/Region。");
            return;
        }

        _size = Mathf.Clamp(MaskResolution, 64, 512);
        _maskImage = Image.CreateEmpty(_size, _size, false, Image.Format.R8);
        _maskImage.Fill(Colors.Black);
        _maskTexture = ImageTexture.CreateFromImage(_maskImage);
        // 每个实例独立材质和遮罩，避免一张饼刷酱、其他饼同时变化。
        _revealMaterial = new ShaderMaterial { Shader = RevealShader };
        _revealMaterial.SetShaderParameter("reveal_mask", _maskTexture);
        _revealMaterial.SetShaderParameter("complete_reveal", 0.0f);
        UseParentMaterial = false;
        Material = _revealMaterial;
        _configured = true;
    }

    /// <summary>仅在本次刷涂被业务/输入控制器允许时调用。</summary>
    public void PaintAtGlobal(Vector2 globalBrushTip)
    {
        if (!_configured || !IsInsideTree() || !CanProcess() ||
            !globalBrushTip.IsFinite()) return;

        Rect2 rect = GetRect();
        Vector2 local = ToLocal(globalBrushTip);
        if (rect.Size.X <= 0.0f || rect.Size.Y <= 0.0f || !rect.HasPoint(local))
        {
            EndStroke();
            return;
        }
        Vector2 uv = (local - rect.Position) / rect.Size;
        float radius = float.IsFinite(BrushRadiusUv)
            ? Mathf.Clamp(BrushRadiusUv, 0.005f, 0.20f) : 0.07f;

        if (_lastUv is Vector2 previous)
        {
            // 沿路径补采样，而不是只画鼠标事件的两个端点。
            // 高频/低帧率下都避免断成一串圆点。
            int steps = Math.Max(1, Mathf.CeilToInt(previous.DistanceTo(uv) / (radius * 0.4f)));
            for (int i = 1; i <= steps; i++)
                Stamp(previous.Lerp(uv, i / (float)steps), radius);
        }
        else
        {
            Stamp(uv, radius);
        }
        _lastUv = uv;
    }

    public void EndStroke() => _lastUv = null;

    private void Stamp(Vector2 uv, float radiusUv)
    {
        Vector2 center = uv * (_size - 1);
        float radius = Math.Max(1.0f, radiusUv * (_size - 1));
        int x0 = Math.Max(0, Mathf.FloorToInt(center.X - radius));
        int y0 = Math.Max(0, Mathf.FloorToInt(center.Y - radius));
        int x1 = Math.Min(_size - 1, Mathf.CeilToInt(center.X + radius));
        int y1 = Math.Min(_size - 1, Mathf.CeilToInt(center.Y + radius));

        for (int y = y0; y <= y1; y++)
        for (int x = x0; x <= x1; x++)
        {
            float distance = new Vector2(x, y).DistanceTo(center);
            if (distance >= radius) continue;
            // 窄范围平滑边缘；不是大范围模糊/发光。
            float edge = Mathf.Clamp((radius - distance) / (radius * 0.20f), 0.0f, 1.0f);
            float value = edge * edge * (3.0f - 2.0f * edge);
            if (value <= _maskImage.GetPixel(x, y).R + 0.001f) continue;
            _maskImage.SetPixel(x, y, new Color(value, 0.0f, 0.0f, 1.0f));
            _dirty = true;
        }
    }

    public override void _Process(double delta)
    {
        // 一帧最多上传一次，只有遮罩被修改才更新。
        if (!_configured || !_dirty) return;
        _maskTexture.Update(_maskImage);
        _dirty = false;
    }

    /// <summary>
    /// 仅在现有业务规则已确认刷涂完成后，用很短时间整理剩余视觉。
    /// 是否补齐整张覆盖图属于表现选择；不需要补齐时不要调用。
    /// </summary>
    public void FinishVisual(double seconds = 0.08)
    {
        if (!_configured || !IsInsideTree() || !double.IsFinite(seconds)) return;
        EndStroke();
        KillFinishTween();
        if (seconds <= 0.0)
        {
            SetCompleteReveal(1.0f);
            return;
        }
        _finishTween = CreateTween();
        _finishTween.TweenMethod(Callable.From<float>(SetCompleteReveal),
                _completeReveal, 1.0f, Math.Clamp(seconds, 0.02, 0.15))
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _finishTween.TweenCallback(Callable.From(() => _finishTween = null));
    }

    /// <summary>新煎饼开始/对象池取出时调用，不清理或修改业务状态。</summary>
    public void ResetReveal()
    {
        if (!_configured) return;
        KillFinishTween();
        EndStroke();
        _maskImage.Fill(Colors.Black);
        _maskTexture.Update(_maskImage);
        _dirty = false;
        SetCompleteReveal(0.0f);
    }

    private void SetCompleteReveal(float value)
    {
        _completeReveal = value;
        _revealMaterial.SetShaderParameter("complete_reveal", value);
    }

    private void KillFinishTween()
    {
        if (_finishTween != null && _finishTween.IsValid()) _finishTween.Kill();
        _finishTween = null;
    }

    public override void _ExitTree()
    {
        KillFinishTween();
        EndStroke();
    }
}
