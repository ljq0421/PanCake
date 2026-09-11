using Godot;
using ProjectCake.Interaction;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    internal const string TrashPayload = "wuhan_trash";
    private bool _trashPressed;
    private double _trashHeld;
    private Vector2 _trashOrigin;
    private Func<bool>? _trashValid, _trashCommit;
    private string _trashChannel = "";
    private Control _trashSource = null!;
    private DragVisualSpec _trashVisual;
    internal DropZone TrashZone { get; private set; } = null!;

    private void ConfigureTrash(DragService drag)
    {
        TrashZone = GetNode<DropZone>("TrashZone");
        Rect2 rect = WuhanWorkbenchLayout.EmbeddedTrash;
        TrashZone.Position = rect.Position; TrashZone.Size = rect.Size;
        TrashZone.FixedHitRect = rect; TrashZone.HitPadding = 0;
        TrashZone.MouseFilter = MouseFilterEnum.Stop;
        TrashZone.TooltipText = "长按鼠标右键 0.45 秒后拖入食物，松开丢弃";
        TrashZone.ConfigureResult(CanAcceptTrash, CommitTrash);
        drag.RegisterZone(TrashZone);
        _trashSource = new Control { Name = "TrashSource", MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_trashSource);
    }

    internal bool HandleTrashInput(InputEvent input)
    {
        if (input is InputEventMouseMotion motion && _trashPressed)
        {
            if (motion.Position.DistanceTo(_trashOrigin) > StockGesture.DragDistance) CancelTrashPress();
            return true;
        }
        if (input is not InputEventMouseButton { ButtonIndex: MouseButton.Right } mouse) return false;
        if (!mouse.Pressed)
        {
            if (!_trashPressed) return false; // DragService owns the long press release.
            CancelTrashPress(); return true;
        }
        if (_trashPressed || !TryPrepareTrash(mouse.Position)) return false;
        _trashPressed = true; _trashHeld = 0; _trashOrigin = mouse.Position;
        return true;
    }

    private void TickTrashPress(double delta)
    {
        if (!_trashPressed) return;
        if (!IsVisibleInTree() || CanInteract?.Invoke() != true || _trashValid?.Invoke() != true)
        { CancelTrashPress(); return; }
        _trashHeld += Math.Max(0, delta);
        if (_trashHeld + 1e-9 < PressRepeatGesture.HoldSeconds) return;
        _trashPressed = false;
        _drag!.BeginDrag(_trashSource, TrashPayload, "丢弃食物", Colors.White, _trashVisual, MouseButton.Right);
    }

    private void CancelTrashPress()
    {
        _trashPressed = false; _trashHeld = 0;
        if (_drag?.IsDragging != true) ClearTrashSource();
    }

    private void ClearTrashSource()
    {
        _trashValid = null; _trashCommit = null; _trashChannel = "";
    }

    private bool TryPrepareTrash(Vector2 globalPoint)
    {
        if (_cooker is null || _drag is null || _drag.IsDragging || !IsVisibleInTree()
            || CanInteract?.Invoke() != true || HasProductionGesture || _mixHeld) return false;
        Vector2 point = GetGlobalTransformWithCanvas().AffineInverse() * globalPoint;
        string hit = HitTarget(point);
        if (Busy(hit)) return false;
        Rect2 rect;
        Texture2D texture;
        Vector2 displaySize = new(150, 120);
        Func<Control>? previewFactory = null;
        if (hit.StartsWith("basket") && int.TryParse(hit[6..], out int index)
            && _cooker.Baskets[index].State != NoodleBasketState.Empty)
        {
            var cooker = _cooker; var basket = cooker.Baskets[index]; long generation = basket.Generation;
            _trashValid = () => ReferenceEquals(_cooker, cooker) && basket.Generation == generation && basket.State != NoodleBasketState.Empty;
            _trashCommit = () => cooker.TryDiscard(index);
            rect = BasketRect(index); texture = _art.Texture("raw_noodles");
        }
        else if (hit == "bowl" && _bowl.State != NoodleBowlState.Empty)
        {
            var bowl = _bowl; long generation = bowl.Generation;
            _trashValid = () => ReferenceEquals(_bowl, bowl) && bowl.Generation == generation && bowl.State != NoodleBowlState.Empty;
            _trashCommit = () => { _cooker.CancelPendingPour(); bowl.Reset(); return true; };
            rect = BowlRect; texture = _art.Texture("mixed");
        }
        else if (hit == "pan" && _doupi is { State: not DoupiState.Empty } doupi)
        {
            long generation = doupi.Generation;
            _trashValid = () => ReferenceEquals(_doupi, doupi) && doupi.Generation == generation && doupi.State != DoupiState.Empty;
            _trashCommit = () => { doupi.Discard(); return true; };
            rect = PanRect; texture = _art.Texture(doupi.State == DoupiState.Burnt ? "doupi_burnt" : "doupi_finished");
            if (doupi.State == DoupiState.Burnt)
            {
                displaySize = new Vector2(180, 85);
                previewFactory = () => CreateBurntDoupiPreview(doupi.Coverage > 0, displaySize);
            }
        }
        else if (hit == "stock" && _stock.Count > 0)
        {
            var stock = _stock; long generation = stock.HeadGeneration;
            _trashValid = () => ReferenceEquals(_stock, stock) && stock.HeadGeneration == generation && stock.Count > 0;
            _trashCommit = () => stock.TryTake(1, out _);
            rect = StockRect; texture = _art.Texture("doupi_single");
        }
        else return false;
        _trashChannel = hit;
        _trashSource.Position = rect.Position; _trashSource.Size = rect.Size;
        _trashVisual = new DragVisualSpec(texture, displaySize, PreviewFactory: previewFactory);
        return true;
    }

    private bool CanAcceptTrash(string payload) => payload == TrashPayload && _drag?.IsDragging == true
        && IsVisibleInTree() && CanInteract?.Invoke() == true && _trashValid?.Invoke() == true;

    private bool CommitTrash(string payload)
    {
        if (!CanAcceptTrash(payload) || _trashCommit?.Invoke() != true) return false;
        foreach (Motion motion in _motions.Where(m => m.Locks.Contains(_trashChannel)).ToArray())
        { motion.Tween.Kill(); _motions.Remove(motion); }
        CancelGesture(); EndMix(); ClearTrashSource(); RememberStates();
        RefreshDeliverySources(); QueueRedraw(); FoodDiscarded?.Invoke();
        return true;
    }
}
