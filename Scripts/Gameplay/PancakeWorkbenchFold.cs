using Godot;
using ProjectCake.Pancake;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private bool _foldHeld;
    private Vector2 _foldOrigin;
    private int _foldDirection;
    private long _foldGeneration;
    private float _foldAmount;
    private PancakeFoldVisual? _foldVisual;
    internal bool IsFoldDragging => _foldHeld;
    private bool IsFoldGrabPoint(Vector2 local)
    {
        Rect2 bounds = _canvas.GetSurfaceRect();
        Vector2 unit = (local - bounds.GetCenter()) / (bounds.Size * .5f);
        return unit.LengthSquared() <= 1.12f && Math.Abs(unit.X) >= .35f;
    }
    private bool CanFoldGesture => IsTianjinWorkbench && _initialized && CanInteract
        && IsVisibleInTree() && !IsFlipping && !DirectBusy && !_drag.IsDragging && !_rightPressed
        && Machine.Runtime.State is PancakeState.Sauced or PancakeState.Toppings;

    // Input positions are viewport coordinates; inverse canvas transform also handles 720p.
    internal bool HandleFoldInput(InputEvent input)
    {
        if (_foldHeld && (!CanFoldGesture || Machine.Runtime.Generation != _foldGeneration)) CancelFold();
        if (_foldHeld && input is InputEventKey { Keycode: Key.Escape, Pressed: true })
        {
            ReleaseFold(false);
            return true;
        }
        if (_foldHeld && input is InputEventMouseButton { ButtonIndex: MouseButton.Right, Pressed: true })
        {
            ReleaseFold(false);
            return true;
        }
        if (input is InputEventMouseMotion motion && _foldHeld)
        {
            MoveFold(motion.Position);
            return true;
        }
        if (input is not InputEventMouseButton { ButtonIndex: MouseButton.Left } mouse) return false;
        if (!mouse.Pressed)
        {
            if (!_foldHeld) return false;
            MoveFold(mouse.Position);
            Rect2 surface = _canvas.GetSurfaceRect();
            Vector2 point = _canvas.GetGlobalTransformWithCanvas().AffineInverse() * mouse.Position;
            bool finish = _foldAmount >= .6f && surface.Grow(surface.Size.Y * .3f).HasPoint(point);
            ReleaseFold(finish);
            return true;
        }
        if (_foldHeld || !CanFoldGesture) return false;
        Rect2 bounds = _canvas.GetSurfaceRect();
        Vector2 local = _canvas.GetGlobalTransformWithCanvas().AffineInverse() * mouse.Position;
        Vector2 unit = (local - bounds.GetCenter()) / (bounds.Size * .5f);
        if (!IsFoldGrabPoint(local)) return false;
        CancelFold();
        _foldHeld = true;
        _foldOrigin = local;
        _foldDirection = unit.X < 0 ? 1 : -1;
        _foldGeneration = Machine.Runtime.Generation;
        _foldAmount = 0;
        _stroke.CancelStroke();
        _loopMotion?.Reset();
        _drag.ClearAcceptedVisuals();
        _canvas.ResetIngredientMotion();
        _foldVisual = new PancakeFoldVisual { Name = "PancakeFoldPreview", ZIndex = 3 };
        _canvas.AddChild(_foldVisual);
        _foldVisual.Configure(_canvas, _foldDirection, (local.Y - bounds.Position.Y) / bounds.Size.Y);
        RenderLive();
        return true;
    }

    private void MoveFold(Vector2 point)
    {
        Vector2 local = _canvas.GetGlobalTransformWithCanvas().AffineInverse() * point;
        float distance = (local.X - _foldOrigin.X) * _foldDirection;
        _foldAmount = Mathf.Clamp(distance / (_canvas.GetSurfaceRect().Size.X * .7f), 0, 1);
        _foldVisual?.SetProgress(_foldAmount);
        RenderLive();
    }

    private void ReleaseFold(bool finish)
    {
        _foldHeld = false;
        if (finish && CanFoldGesture && Machine.Runtime.Generation == _foldGeneration)
        {
            // Commit through the same recipe/tutorial path as the retained F shortcut.
            _foldVisual?.Finish(true, ReducedMotion);
            Execute(PancakeCommand.Fold);
        }
        else _foldVisual?.Finish(false, ReducedMotion);
        RenderLive();
    }

    private void CancelFold()
    {
        _foldHeld = false;
        _foldAmount = 0;
        if (IsInstanceValid(_foldVisual)) _foldVisual!.DisposePreview();
        _foldVisual = null;
    }

    private void SyncFold()
    {
        if (_foldVisual is not null && !IsInstanceValid(_foldVisual)) _foldVisual = null;
        if (_foldVisual is null) return;
        if (Machine.Runtime.Generation != _foldGeneration || !CanInteract || !IsVisibleInTree()
            || Machine.Runtime.State is not (PancakeState.Sauced or PancakeState.Toppings or PancakeState.Folded))
            CancelFold();
        else if (_foldHeld && !CanFoldGesture) CancelFold();
    }
}
