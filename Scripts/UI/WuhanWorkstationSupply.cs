using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    public Func<string, bool>? SupplyRequested;
    private Button? _supplyBell;
    private Sprite2D? _supplyNpc;
    private Button? _supplyNpcButton;
    private static readonly string[] SupplyOrder = { StableIds.Ingredients.WuhanBaseSeasoning,
        StableIds.Ingredients.WuhanChiliOil, StableIds.Ingredients.WuhanScallion, StableIds.Ingredients.WuhanBraisedBeef };
    private Tween? _supplyNpcTween;
    private Tween? _supplyNpcDismissTween;
    private Tween? _supplyBellTween;
    private readonly Dictionary<TextureRect, Tween> _supplyDrops = new();
    private static readonly Vector2 SupplyNpcPosition = new(-20, 340);
    private Vector2 _supplyNpcScale;
    private bool _supplySelecting;
    internal bool SupplySelecting => _supplySelecting;

    private void BuildSupplyCall()
    {
        _supplyBell = new Button
        {
            Name = "SupplyBell", Position = new Vector2(554, 556), Size = new Vector2(70, 70),
            PivotOffset = new Vector2(35, 35), ZIndex = 35, Flat = true,
            FocusMode = FocusModeEnum.None, MouseDefaultCursorShape = CursorShape.PointingHand,
        };
        AddChild(_supplyBell);
        Texture2D bellArt = GD.Load<Texture2D>("res://resource/art/TianJin/SupplyCall/supply_bell.png");
        _supplyBell.AddChild(new Sprite2D
        {
            Name = "BellArtwork", Texture = bellArt,
            Position = Vector2.Zero, Centered = false,
            Scale = Vector2.One * (70f / bellArt.GetWidth()),
        });
        _supplyBell.Pressed += OpenSupplySelection;

        Texture2D npcArt = GD.Load<Texture2D>("res://resource/art/Wuhan/SupplyCall/supply_helper.png");
        _supplyNpc = new Sprite2D
        {
            Name = "SupplyHelper", Texture = npcArt, Centered = false,
            Position = SupplyNpcPosition,
            Scale = new Vector2(260f / npcArt.GetWidth(), 260f / npcArt.GetHeight()),
            ZIndex = 20, Visible = false,
        };
        // Match the left counter lip and the noodle pot's silhouette. The helper
        // stands behind them instead of painting its crate over the equipment.
        _supplyNpc.Material = new ShaderMaterial
        {
            Shader = new Shader { Code = """
                shader_type canvas_item;
                uniform vec2 supply_origin;
                uniform vec2 supply_size;
                void fragment() {
                    vec2 p = supply_origin + UV * supply_size;
                    float edge = mix(625.0, 583.0, clamp(p.x / 45.0, 0.0, 1.0));
                    edge += (566.0 - 583.0) * clamp((p.x - 45.0) / 35.0, 0.0, 1.0);
                    edge += (560.0 - 566.0) * clamp((p.x - 80.0) / 30.0, 0.0, 1.0);
                    edge += (537.0 - 560.0) * clamp((p.x - 110.0) / 35.0, 0.0, 1.0);
                    edge += (516.0 - 537.0) * clamp((p.x - 145.0) / 45.0, 0.0, 1.0);
                    edge += (502.0 - 516.0) * clamp((p.x - 190.0) / 55.0, 0.0, 1.0);
                    COLOR.a *= 1.0 - smoothstep(edge - 1.0, edge, p.y);
                }
                """ },
        };
        AddChild(_supplyNpc);
        UpdateSupplyNpcOcclusion();
        _supplyNpcScale = _supplyNpc.Scale;
        _supplyNpcButton = new Button
        {
            Name = "SupplyNpcButton", Position = new Vector2(24, 353), Size = new Vector2(165, 158),
            ZIndex = 35, Flat = true, Visible = false, FocusMode = FocusModeEnum.None,
            MouseDefaultCursorShape = CursorShape.PointingHand,
        };
        AddChild(_supplyNpcButton);
        _supplyNpcButton.Pressed += SupplyNextPortion;

    }

    private void LayoutSupplyCall() => CancelSupplySelection();

    private bool CanSupply(string id) => _ingredients is not null && CanInteract?.Invoke() == true
        && (AllowedIngredients is null || AllowedIngredients.Contains(id)) && _ingredients.CanRefill(id);

    private void OpenSupplySelection()
    {
        if (_supplyBell is null || CanInteract?.Invoke() != true || _drag?.IsDragging == true) return;
        EndMix();
        _supplySelecting = true;
        PlaySound(WuhanSound.SupplyBell);
        PlaySupplyNpc();
        if (!SupplyOrder.Any(CanSupply)) ScheduleSupplyNpcDismiss();
        if (ReducedMotion) return;
        _supplyBellTween?.Kill();
        _supplyBell.Scale = new Vector2(.91f, .91f);
        _supplyBellTween = SupplyTween().SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        _supplyBellTween
            .TweenProperty(_supplyBell, "scale", Vector2.One, .2);
    }

    private void RefreshSupplyControls()
    {
        QueueRedraw();
    }

    private void CancelSupplySelection()
    {
        _supplySelecting = false;
        foreach (TextureRect drop in _supplyDrops.Keys.ToArray()) FinishSupplyDrop(drop);
        _supplyNpcDismissTween?.Kill();
        _supplyBellTween?.Kill();
        if (_supplyBell is not null) _supplyBell.Scale = Vector2.One;
        StopSupplyNpc();
    }

    private bool HandleSupplyInput(InputEvent input)
    {
        if (!_supplySelecting) return false;
        if (input is InputEventKey { Keycode: Key.Escape, Pressed: true })
        {
            CancelSupplySelection(); return true;
        }
        if (CanInteract?.Invoke() != true) { CancelSupplySelection(); return false; }
        return false;
    }

    private void SupplyNextPortion()
    {
        if (!_supplySelecting || CanInteract?.Invoke() != true || _drag?.IsDragging == true) return;
        string? chosen = SupplyOrder.FirstOrDefault(CanSupply);
        if (chosen is null) { ScheduleSupplyNpcDismiss(); return; }
        if (SupplyRequested?.Invoke(chosen) != true) return;
        PlaySound(WuhanSound.Stock);
        PlaySupplyDrop(chosen);
        BounceSupplyNpc();
        if (!SupplyOrder.Any(CanSupply)) ScheduleSupplyNpcDismiss();
        RefreshSupplyControls();
    }

    private void PlaySupplyNpc()
    {
        if (_supplyNpc is null) return;
        _supplyNpcDismissTween?.Kill();
        bool alreadyVisible = _supplyNpc.Visible;
        _supplyNpcTween?.Kill();
        _supplyNpc.Show();
        _supplyNpcButton?.Show();
        if (alreadyVisible) { BounceSupplyNpc(); return; }
        Vector2 target = SupplyNpcPosition;
        _supplyNpc.Scale = _supplyNpcScale;
        _supplyNpc.Position = ReducedMotion ? target : target + new Vector2(-28, 12);
        _supplyNpc.Modulate = new Color(1, 1, 1, ReducedMotion ? 1f : 0f);
        if (!ReducedMotion)
        {
            _supplyNpcTween = SupplyTween();
            _supplyNpcTween.TweenProperty(_supplyNpc, "position", target, .2)
                .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
            _supplyNpcTween.Parallel().TweenProperty(_supplyNpc, "modulate:a", 1f, .16);
        }
    }

    private Tween SupplyTween()
    {
        Tween tween = CreateTween();
        tween.Pause(); // Follow the workstation clock, including pause and focus loss.
        return tween;
    }

    private void TickSupply(double delta)
    {
        if (CanInteract?.Invoke() != true) { CancelSupplySelection(); return; }
        if (_supplyNpcTween?.IsValid() == true) _supplyNpcTween.CustomStep(delta);
        if (_supplyBellTween?.IsValid() == true) _supplyBellTween.CustomStep(delta);
        foreach (Tween tween in _supplyDrops.Values.ToArray()) tween.CustomStep(delta);
        if (_supplyNpcDismissTween?.IsValid() == true) _supplyNpcDismissTween.CustomStep(delta);
        UpdateSupplyNpcOcclusion();
    }

    private void UpdateSupplyNpcOcclusion()
    {
        if (_supplyNpc?.Material is not ShaderMaterial material) return;
        material.SetShaderParameter("supply_origin", _supplyNpc.Position);
        material.SetShaderParameter("supply_size", _supplyNpc.Texture.GetSize() * _supplyNpc.Scale);
    }

    private void BounceSupplyNpc()
    {
        if (_supplyNpc is null) return;
        _supplyNpcTween?.Kill();
        _supplyNpc.Position = SupplyNpcPosition;
        _supplyNpc.Modulate = Colors.White;
        _supplyNpc.Scale = _supplyNpcScale;
        if (ReducedMotion) return;
        _supplyNpcTween = SupplyTween().SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        // Keep the feet anchored while the body responds to each click.
        Vector2 anchor = new(130, 260);
        _supplyNpcTween.TweenMethod(Callable.From<Vector2>(factor =>
        {
            _supplyNpc.Scale = _supplyNpcScale * factor;
            _supplyNpc.Position = SupplyNpcPosition + anchor * (Vector2.One - factor);
        }), Vector2.One, new Vector2(1.055f, .96f), .08);
        _supplyNpcTween.TweenMethod(Callable.From<Vector2>(factor =>
        {
            _supplyNpc.Scale = _supplyNpcScale * factor;
            _supplyNpc.Position = SupplyNpcPosition + anchor * (Vector2.One - factor);
        }), new Vector2(1.055f, .96f), Vector2.One, .16);
    }

    private void ScheduleSupplyNpcDismiss()
    {
        _supplyNpcDismissTween?.Kill();
        _supplyNpcDismissTween = SupplyTween();
        _supplyNpcDismissTween.TweenInterval(1.0);
        _supplyNpcDismissTween.TweenCallback(Callable.From(CancelSupplySelection));
    }

    private void PlaySupplyDrop(string id)
    {
        if (ReducedMotion) return;
        int index = Array.IndexOf(IngredientIds, id);
        // The Wuhan stock art is a whole bowl, not individual inventory sprites.
        // Drop only food into its opening; never duplicate the bowl or its spoon.
        string artId = index switch { 0 => "unmixed", 1 => "scallion", 2 => "chili_overlay", _ => "beef" };
        Texture2D texture = _art.Texture(artId);
        Vector2 size = index == 3 ? new Vector2(39, 27) : new Vector2(40, 24);
        Vector2 end = IngredientFoodRect(index).GetCenter() - size / 2;
        var drop = new TextureRect
        {
            Name = "SupplyDrop_" + id,
            Texture = new AtlasTexture { Atlas = texture, Region = Source(texture) },
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            Position = end - new Vector2(0, 110), Size = size,
            ZIndex = 60, MouseFilter = MouseFilterEnum.Ignore,
        };
        AddChild(drop, true);
        Tween tween = SupplyTween();
        _supplyDrops.Add(drop, tween);
        tween.TweenProperty(drop, "position", end, .34)
            .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
        tween.TweenCallback(Callable.From(() => FinishSupplyDrop(drop)));
    }

    private void FinishSupplyDrop(TextureRect drop)
    {
        if (!_supplyDrops.Remove(drop, out Tween? tween)) return;
        tween.Kill();
        drop.Hide();
        drop.QueueFree();
    }

    private void StopSupplyNpc()
    {
        _supplyNpcTween?.Kill();
        _supplyNpc?.Hide();
        _supplyNpcButton?.Hide();
    }
}
