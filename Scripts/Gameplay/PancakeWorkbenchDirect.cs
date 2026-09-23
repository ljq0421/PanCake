using Godot;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private enum DirectGesture { None, Flip, Bag }
    private DirectGesture _directGesture;
    private long _directGeneration;
    private Vector2 _directOrigin, _directInward, _bagGrabOffset;
    private float _flipDragAmount;
    private const float FlipCommitAmount = .65f;
    private const float FlipDragDistance = 55;
    private bool IsFlipGrabPoint(Vector2 local)
    {
        Rect2 bounds = _canvas.GetSurfaceRect();
        Vector2 unit = (local - bounds.GetCenter()) / (bounds.Size * .5f);
        // Allow a little space outside the painted rim, and a wider inner grip.
        return unit.LengthSquared() is >= .16f and <= 1.44f;
    }
    private TianjinBagVisual? _directBag;
    internal bool IsDirectDragging => _directGesture != DirectGesture.None;
    private bool DirectBusy => IsDirectDragging || _directBag?.Animating == true;
    internal float ToolFlipProgress => _canvas.FlipPickup > 0 ? .08f + .12f * _canvas.FlipPickup : FlipProgress;
    internal Rect2 BagStackBounds => _directBag?.StackBounds ?? default;
    private bool CanDirectGesture => IsTianjinWorkbench && _initialized && CanInteract && IsVisibleInTree()
        && !IsFlipping && !_foldHeld && !_drag.IsDragging && !_rightPressed;
    private Vector2 DirectLocal(Vector2 point) => GetGlobalTransformWithCanvas().AffineInverse() * point;
    private Vector2 FoodCenter => GetGlobalTransformWithCanvas().AffineInverse()
        * (_canvas.GetGlobalTransformWithCanvas() * (_canvas.GetSurfaceRect().GetCenter() + new Vector2(0, -12)));

    internal bool HandleDirectFoodInput(InputEvent input)
    {
        SyncDirectGesture();
        if (IsDirectDragging && (input is InputEventKey { Keycode: Key.Escape, Pressed: true }
            || input is InputEventMouseButton { ButtonIndex: MouseButton.Right, Pressed: true }))
        {
            ReleaseDirectGesture(false);
            return true;
        }
        if (input is InputEventMouseMotion motion && IsDirectDragging)
        {
            MoveDirectGesture(motion.Position);
            return true;
        }
        if (input is not InputEventMouseButton { ButtonIndex: MouseButton.Left } mouse) return false;
        if (!mouse.Pressed)
        {
            if (!IsDirectDragging) return false;
            MoveDirectGesture(mouse.Position);
            bool success = _directGesture == DirectGesture.Flip
                ? _flipDragAmount >= FlipCommitAmount
                : _directBag!.OverFood;
            ReleaseDirectGesture(success);
            return true;
        }
        if (!CanDirectGesture || DirectBusy) return false;
        if (Machine.Runtime.State is PancakeState.SideAReady or PancakeState.SideAOverdone)
        {
            Rect2 bounds = _canvas.GetSurfaceRect();
            Vector2 local = _canvas.GetGlobalTransformWithCanvas().AffineInverse() * mouse.Position;
            Vector2 unit = (local - bounds.GetCenter()) / (bounds.Size * .5f);
            if (!IsFlipGrabPoint(local)) return false;
            _directGesture = DirectGesture.Flip;
            _directOrigin = local;
            _directInward = (bounds.GetCenter() - local).Normalized();
            _canvas.FlipEdge = unit.X < 0 ? -1 : 1;
            _flipDragAmount = 0;
            _canvas.FlipPickup = ReducedMotion ? 0 : .08f;
        }
        else if (Machine.Runtime.State == PancakeState.Folded)
        {
            Vector2 point = DirectLocal(mouse.Position);
            if (!_directBag!.StackBounds.HasPoint(point))
                return new Rect2(FoodCenter - new Vector2(130, 110), new Vector2(260, 220)).HasPoint(point);
            CancelFold();
            _directGesture = DirectGesture.Bag;
            _bagGrabOffset = _directBag.StackBounds.GetCenter() - point;
            _directBag!.Begin(FoodCenter, Machine.Runtime.Quality == PancakeQuality.Overdone
                ? new Color(.82f, .56f, .33f) : Colors.White);
        }
        else return false;
        _directGeneration = Machine.Runtime.Generation;
        _stroke.CancelStroke();
        _loopMotion?.Reset();
        _canvas.ResetIngredientMotion();
        RenderLive();
        return true;
    }

    private void MoveDirectGesture(Vector2 point)
    {
        if (_directGesture == DirectGesture.Flip)
        {
            Vector2 local = _canvas.GetGlobalTransformWithCanvas().AffineInverse() * point;
            _flipDragAmount = Mathf.Clamp((local - _directOrigin).Dot(_directInward) / FlipDragDistance, 0, 1);
            _canvas.FlipPickup = ReducedMotion ? 0 : .08f + .92f * _flipDragAmount;
            _canvas.QueueRedraw();
        }
        else _directBag!.MoveBag(DirectLocal(point) + _bagGrabOffset, ReducedMotion);
        RenderLive();
    }

    private void ReleaseDirectGesture(bool success)
    {
        DirectGesture gesture = _directGesture;
        _directGesture = DirectGesture.None;
        if (gesture == DirectGesture.Flip)
        {
            if (success && CanDirectGesture)
            {
                _canvas.FlipPickup = 0;
                if (Execute(PancakeCommand.Flip) && !ReducedMotion) _canvas.SetFlipProgress(.2f);
            }
            // An incomplete lift relaxes in TickDirectGesture without committing.
        }
        else if (gesture == DirectGesture.Bag)
        {
            _directBag!.Release(success, ReducedMotion);
            if (success)
            {
                _canvas.DirectFoodHidden = !ReducedMotion;
                CompleteDirectBag();
            }
            else if (ReducedMotion) _canvas.DirectFoodHidden = false;
        }
        RenderLive();
    }

    private void CompleteDirectBag()
    {
        // Commit once, on release. The visual tail may be skipped by pause or focus loss.
        Execute(PancakeCommand.Bag);
        if (_directBag?.Animating == true) _finished.Hide();
        else _canvas.DirectFoodHidden = false;
    }

    private void SyncDirectGesture()
    {
        if (!IsTianjinWorkbench) return;
        if ((IsDirectDragging || _directBag?.Animating == true || _canvas.FlipPickup > 0)
            && (!CanInteract || !IsVisibleInTree() || Machine.Runtime.Generation != _directGeneration
                || (_directGesture == DirectGesture.Flip && Machine.Runtime.State is not (PancakeState.SideAReady or PancakeState.SideAOverdone))
                || (_directGesture == DirectGesture.Bag && Machine.Runtime.State != PancakeState.Folded)
                || (_directBag?.Animating == true && Machine.Runtime.State is not (PancakeState.Folded or PancakeState.Bagged))))
            CancelDirectGesture();
        if (_directBag is not null)
        {
            _directBag.Show();
            _directBag.MouseDefaultCursorShape = CanDirectGesture && Machine.Runtime.State == PancakeState.Folded
                ? CursorShape.Drag : CursorShape.Arrow;
            if (_directBag.Animating) _finished.Hide();
        }
    }

    private void TickDirectGesture(double delta)
    {
        if (!IsTianjinWorkbench) return;
        SyncDirectGesture();
        if (ReducedMotion && _directGesture == DirectGesture.Flip) { _canvas.FlipPickup = 0; _canvas.QueueRedraw(); }
        if (_directGesture != DirectGesture.Flip && _canvas.FlipPickup > 0)
        {
            _canvas.FlipPickup = ReducedMotion ? 0 : Mathf.MoveToward(_canvas.FlipPickup, 0, (float)delta * 8);
            _canvas.QueueRedraw();
        }
        if (_directBag?.Tick((float)delta, ReducedMotion) == true)
        {
            _canvas.DirectFoodHidden = false;
            Render();
        }
    }

    private void CancelDirectGesture()
    {
        _directGesture = DirectGesture.None;
        _flipDragAmount = 0;
        _directBag?.Cancel();
        if (_canvas is not null) { _canvas.FlipPickup = 0; _canvas.DirectFoodHidden = false; _canvas.QueueRedraw(); }
        if (_initialized && IsTianjinWorkbench) _finished.Visible = HasFinishedPancake && !IsTransferringBag;
    }

    private void ConfigureDirectFood()
    {
        _directBag = new TianjinBagVisual { Name = "DirectPaperBag", ZIndex = 42,
            Size = new Vector2(1920, 1080), MouseFilter = MouseFilterEnum.Pass };
        AddChild(_directBag);
        _directBag.Configure(_art.FoldedPancake, _art.FinishedPancake);
        // Packaging stays on the stove; the stack remains available beside it.
        Control slot = _finished.GetParent<Control>();
        slot.Position = FoodCenter - new Vector2(130, 130);
        slot.Size = new Vector2(260, 260);
        _bagArt!.Position = new Vector2(0, 0);
        _bagArt.Size = new Vector2(260, 260);
        _finished.Size = new Vector2(260, 260);
        _directDeliveryHint.Position = new Vector2(18, 255);
    }
}
