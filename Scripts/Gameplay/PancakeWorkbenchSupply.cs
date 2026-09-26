using Godot;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private static readonly string[] SupplyIngredients =
    {
        StableIds.Ingredients.Egg,
        StableIds.Ingredients.Crispy,
        StableIds.Ingredients.Scallion,
        StableIds.Ingredients.Ham,
        "soy_milk",
    };

    // Keep the artwork's visible lower edge on the customer-side counter edge.
    // The source has transparent padding and is aspect-fitted inside this frame.
    private static readonly Vector2 SupplyNpcPosition = new(.15f, 272.04f);
    private Button? _supplyBell;
    private TextureRect? _supplyNpc;
    private Button? _supplyNpcClick;
    private readonly Dictionary<TextureRect, (Tween Tween, TextureRect Target, Color Tint)> _supplyDrops = new();
    private Tween? _supplyNpcTween;
    private Tween? _supplyNpcDismissTween;
    private bool _supplyNpcCalled;
    internal bool SupplyNpcCalled => _supplyNpcCalled;
    internal Control? SupplyBellFocusTarget => _supplyBell;
    internal Control? SupplyNpcFocusTarget => _supplyNpcClick;

    private void BuildSupplyCall()
    {
        Texture2D bell = GD.Load<Texture2D>("res://resource/art/TianJin/SupplyCall/supply_bell_bold.png");
        Texture2D npc = GD.Load<Texture2D>("res://resource/art/TianJin/SupplyCall/supply_helper.png");

        _supplyBell = new Button
        {
            Name = "SupplyBell",
            Position = new Vector2(537.6f, 560),
            Size = new Vector2(124.8f, 120),
            PivotOffset = new Vector2(62.4f, 60),
            ZIndex = 35,
            Flat = true,
            FocusMode = FocusModeEnum.None,
            MouseDefaultCursorShape = CursorShape.PointingHand,
        };
        AddChild(_supplyBell);
        var art = new TextureRect
        {
            Name = "BellArtwork",
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            Texture = bell,
            Position = Vector2.Zero,
            Size = new Vector2(124.8f, 120),
            MouseFilter = MouseFilterEnum.Ignore,
        };
        _supplyBell.AddChild(art);
        _supplyBell.Pressed += CallSupplyNpc;

        _supplyNpc = new TextureRect
        {
            Name = "SupplyHelper",
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            Texture = npc,
            FlipH = false,
            Position = SupplyNpcPosition,
            Size = new Vector2(311.85f, 337.095f),
            PivotOffset = new Vector2(155.925f, 307.96f),
            ZIndex = 30,
            MouseFilter = MouseFilterEnum.Ignore,
            Visible = false,
        };
        AddChild(_supplyNpc);

        _supplyNpcClick = new Button
        {
            Name = "SupplyHelperClick",
            Position = SupplyNpcPosition + new Vector2(47, 39.56f),
            Size = new Vector2(234, 268.4f),
            ZIndex = 31,
            Flat = true,
            FocusMode = FocusModeEnum.None,
            MouseDefaultCursorShape = CursorShape.PointingHand,
            Visible = false,
        };
        AddChild(_supplyNpcClick);
        _supplyNpcClick.Pressed += SupplyOne;
    }

    private string? NextMissingSupply()
    {
        if (!_initialized) return null;
        foreach (string id in SupplyIngredients)
        {
            if (id == "soy_milk")
            {
                if (SoyMilkTray is { } soy && soy.Quantity < soy.Capacity) return id;
            }
            else if (_enabledIngredients.Contains(id) && !Inventory.IsUnlimited(id)
                && Inventory.GetQuantity(id) < Inventory.GetCapacity(id)) return id;
        }
        return null;
    }

    private void CallSupplyNpc()
    {
        if (!IsTianjinWorkbench || !CanInteract || _drag.IsDragging) return;
        _audio.Play(PancakeSound.SupplyBell);
        if (!ReducedMotion && _supplyBell is not null)
        {
            _supplyBell.Scale = new Vector2(.91f, .91f);
            CreateTween().SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out)
                .TweenProperty(_supplyBell, "scale", Vector2.One, .2);
        }
        _supplyNpcCalled = true;
        ShowSupplyNpc();
        if (NextMissingSupply() is null && !NeedsSupplyIntroduction)
            ScheduleSupplyNpcDismiss();
    }

    private void SupplyOne()
    {
        if (!_supplyNpcCalled || !CanInteract) return;
        if (NeedsSupplyIntroduction) LearnWorkbenchAction(SupplyIntroductionAction);
        string? id = NextMissingSupply();
        if (id is null)
        {
            ScheduleSupplyNpcDismiss();
            return;
        }
        bool added = id == "soy_milk" ? SoyMilkTray?.TryAddOne() == true : Inventory.TryAddOne(id);
        if (!added) return;
        PlaySupplyDrop(id);
        _audio.Play(PancakeSound.SoftDrop);
        BounceSupplyNpc();
        if (id == "soy_milk")
        {
            if (SoyMilkTray!.Quantity == SoyMilkTray.Capacity) LearnWorkbenchAction(RefillLessonAction);
        }
        else
        {
            if (Inventory.GetQuantity(id) == Inventory.GetCapacity(id)) LearnWorkbenchAction(RefillLessonAction);
        }
        if (NextMissingSupply() is null) ScheduleSupplyNpcDismiss();
    }

    private void PlaySupplyDrop(string id)
    {
        if (ReducedMotion) return;
        // Inventory already rendered the new unit; land at that unit's exact transform.
        TextureRect? target = id == "soy_milk"
            ? _soyStockArt?.Cups.ElementAtOrDefault(SoyMilkTray!.Quantity - 1)
            : _ingredientSlots.TryGetValue(id, out IngredientStockSlotView? slot)
                ? slot.IngredientVisuals.ElementAtOrDefault(Inventory.GetQuantity(id) - 1) : null;
        if (target is null) return;
        foreach (var active in _supplyDrops.Where(pair => pair.Value.Target == target).ToArray())
            FinishSupplyDrop(active.Key);
        Transform2D placement = GetGlobalTransform().AffineInverse() * target.GetGlobalTransform();
        Vector2 end = placement.Origin;
        var drop = new TextureRect
        {
            Name = "SupplyDrop_" + id, Texture = target.Texture, Material = target.Material,
            ExpandMode = target.ExpandMode, StretchMode = target.StretchMode,
            Size = target.Size, Position = end - new Vector2(0, 110),
            Rotation = placement.Rotation, Scale = placement.Scale,
            Modulate = target.Modulate, SelfModulate = target.SelfModulate,
            ZIndex = 60, MouseFilter = MouseFilterEnum.Ignore,
        };
        AddChild(drop);
        Tween tween = CreateTween();
        _supplyDrops.Add(drop, (tween, target, target.SelfModulate));
        target.SelfModulate = Colors.Transparent;
        tween.TweenMethod(Callable.From<float>(progress =>
        {
            drop.Position = end - new Vector2(0, 110 * (1 - progress));
            drop.Visible = target.IsVisibleInTree();
        }), 0f, 1f, .34).SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
        tween.TweenCallback(Callable.From(() => FinishSupplyDrop(drop)));
    }

    private void FinishSupplyDrop(TextureRect drop)
    {
        if (!_supplyDrops.Remove(drop, out var active)) return;
        active.Tween.Kill();
        active.Target.SelfModulate = active.Tint;
        drop.Hide();
        drop.QueueFree();
    }

    private void ShowSupplyNpc()
    {
        if (_supplyNpc is null) return;
        _supplyNpcDismissTween?.Kill();
        bool alreadyVisible = _supplyNpc.Visible;
        _supplyNpcTween?.Kill();
        _supplyNpc.Show();
        _supplyNpcClick?.Show();
        if (alreadyVisible) { BounceSupplyNpc(); return; }
        _supplyNpc.Position = ReducedMotion ? SupplyNpcPosition : SupplyNpcPosition + new Vector2(-24, 10);
        _supplyNpc.Scale = Vector2.One;
        _supplyNpc.Modulate = new Color(1, 1, 1, ReducedMotion ? 1 : 0);
        if (ReducedMotion) return;
        _supplyNpcTween = CreateTween().SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        _supplyNpcTween.TweenProperty(_supplyNpc, "position", SupplyNpcPosition, .24);
        _supplyNpcTween.Parallel().TweenProperty(_supplyNpc, "modulate:a", 1f, .18);
    }

    private void BounceSupplyNpc()
    {
        if (_supplyNpc is null || ReducedMotion) return;
        _supplyNpcTween?.Kill();
        _supplyNpc.Position = SupplyNpcPosition;
        _supplyNpc.Modulate = Colors.White;
        _supplyNpc.Scale = Vector2.One;
        _supplyNpcTween = CreateTween().SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        _supplyNpcTween.TweenProperty(_supplyNpc, "scale", new Vector2(1.055f, .96f), .08);
        _supplyNpcTween.TweenProperty(_supplyNpc, "scale", Vector2.One, .16);
    }

    private void ScheduleSupplyNpcDismiss()
    {
        _supplyNpcDismissTween?.Kill();
        _supplyNpcDismissTween = CreateTween();
        _supplyNpcDismissTween.TweenInterval(1.0);
        _supplyNpcDismissTween.TweenCallback(Callable.From(DismissSupplyNpc));
    }

    private void DismissSupplyNpc()
    {
        foreach (TextureRect drop in _supplyDrops.Keys.ToArray()) FinishSupplyDrop(drop);
        _supplyNpcCalled = false;
        _supplyNpcTween?.Kill();
        _supplyNpcDismissTween?.Kill();
        _supplyNpc?.Hide();
        _supplyNpcClick?.Hide();
    }

    internal bool HandleSupplyInput(InputEvent input)
    {
        if (input is InputEventKey { Keycode: Key.Escape, Pressed: true } && _supplyNpcCalled)
        {
            DismissSupplyNpc();
            return true;
        }
        if (input is not InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true } mouse)
            return false;
        Vector2 point = GetGlobalTransformWithCanvas().AffineInverse() * mouse.Position;
        if (_supplyBell is not null && new Rect2(_supplyBell.Position, _supplyBell.Size).HasPoint(point))
        {
            CallSupplyNpc();
            return true;
        }
        if (_supplyNpcCalled && _supplyNpcClick is not null
            && new Rect2(_supplyNpcClick.Position, _supplyNpcClick.Size).HasPoint(point))
        {
            // The foreground fryer occludes the helper's lower body.
            if (FryerMachine is not null && TianjinWorkbenchLayout.EmbeddedFryer.HasPoint(point))
                return false;
            SupplyOne();
            return true;
        }
        return false;
    }
}
