using Godot;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Interaction;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private const string TrashPayload = "tianjin_trash";
    private Func<bool>? _trashSourceValid;
    private Func<bool>? _trashCommit;
    private bool _rightPressed;
    private double _rightHeldSeconds;
    private Vector2 _rightOrigin;
    private Action? _beginHeldTrash;
    private Func<bool>? _canTapSauce;

    internal bool HandleRightFoodInput(InputEvent input)
    {
        if (input is InputEventKey { Keycode: Key.Escape, Pressed: true } && _rightPressed)
        {
            CancelRightFoodPress();
            return true;
        }
        if (input is InputEventMouseMotion motion && _rightPressed)
        {
            if (motion.Position.DistanceTo(_rightOrigin) > StockGesture.DragDistance) CancelRightFoodPress();
            return false;
        }
        if (input is not InputEventMouseButton { ButtonIndex: MouseButton.Right } mouse) return false;
        if (mouse.Pressed)
        {
            if (_rightPressed || _drag.IsDragging || !_initialized || !CanInteract || !IsVisibleInTree()) return false;
            var machine = Machine;
            long generation = machine.Runtime.Generation;
            bool sauce = machine.Runtime.State == PancakeState.Saucing;
            bool food = TryBeginTrashDrag(mouse.Position, prepareOnly: true);
            if (!food && !sauce) return false;
            _rightPressed = true;
            _rightHeldSeconds = 0;
            _rightOrigin = mouse.Position;
            _canTapSauce = () => sauce && ReferenceEquals(Machine, machine)
                && machine.Runtime.Generation == generation && machine.Runtime.State == PancakeState.Saucing;
            _stroke.CancelStroke();
            return true;
        }
        if (!_rightPressed) return false; // The drag service owns a long press's release.
        bool finishSauce = _rightHeldSeconds < PressRepeatGesture.HoldSeconds && _canTapSauce?.Invoke() == true;
        CancelRightFoodPress();
        if (finishSauce && CanInteract && !_drag.IsDragging) Execute(PancakeCommand.CompleteSauce);
        return true;
    }

    private void TickRightFoodPress(double delta)
    {
        if (!_rightPressed) return;
        if (!CanInteract || !IsVisibleInTree() || IsTransferringBag
            || (_beginHeldTrash is not null && _trashSourceValid?.Invoke() != true))
        {
            CancelRightFoodPress();
            return;
        }
        _rightHeldSeconds += Math.Max(0, delta);
        if (_rightHeldSeconds + 1e-9 < PressRepeatGesture.HoldSeconds) return;
        Action? begin = _beginHeldTrash;
        _rightPressed = false;
        _beginHeldTrash = null;
        _canTapSauce = null;
        begin?.Invoke();
    }

    private void CancelRightFoodPress()
    {
        _rightPressed = false;
        _beginHeldTrash = null;
        _canTapSauce = null;
        if (!_drag.IsDragging) { _trashSourceValid = null; _trashCommit = null; }
    }

    internal bool TryBeginTrashDrag(Vector2 globalPoint, bool prepareOnly = false)
    {
        if (!IsTianjinWorkbench || !_initialized || !IsVisibleInTree() || !CanInteract
            || IsTransferringBag || _drag.IsDragging) return false;

        Control source;
        Texture2D texture;
        string name;
        Func<bool> valid;
        Func<bool> commit;
        bool Hit(Control control) => control.IsVisibleInTree() && control.GetGlobalRect().HasPoint(globalPoint);
        if (UseServingTray && HasFinishedPancake && Hit(_finished) && PancakeTray.Selected is PreparedPancake prepared)
        {
            source = _finished; texture = _art.FinishedPancake; name = "装袋煎饼";
            valid = () => ReferenceEquals(PancakeTray.Selected, prepared);
            commit = () => PancakeTray.TryTake(prepared);
        }
        else if (Hit(_canvas) && Machine.Runtime.State is not (PancakeState.Empty or PancakeState.Delivered))
        {
            var machine = Machine;
            long generation = machine.Runtime.Generation;
            source = _canvas; name = "当前煎饼";
            texture = machine.Runtime.State switch {
                PancakeState.Bagged => _art.FinishedPancake,
                PancakeState.Folded => _art.FoldedPancake,
                PancakeState.Burnt => _art.PancakeBurntOverlay,
                _ => _art.PancakeBase };
            valid = () => ReferenceEquals(Machine, machine) && machine.Runtime.Generation == generation
                && machine.Runtime.State is not (PancakeState.Empty or PancakeState.Delivered);
            commit = () => { bool ok = machine.TryExecute(PancakeCommand.Discard).Success;
                if (ok) _stroke.ResetCoverage(); return ok; };
        }
        else if (Hit(_finishedYoutiaoSlot) && FryerMachine?.Inventory.Count > 0)
        {
            var inventory = FryerMachine.Inventory;
            long generation = inventory.HeadGeneration;
            source = _finishedYoutiaoSlot; texture = _art.Ingredient(StableIds.Ingredients.Youtiao); name = "一根熟油条";
            valid = () => ReferenceEquals(FryerMachine?.Inventory, inventory)
                && inventory.HeadGeneration == generation && inventory.Count > 0;
            commit = () => inventory.TryTake(out _);
        }
        else if (Hit(_fryerVisual) && FryerMachine is { } fryer
            && fryer.Runtime.Quantity > 0 && fryer.Runtime.State is not (FryerState.Empty or FryerState.Stored))
        {
            long generation = fryer.Runtime.Generation;
            source = _fryerVisual; name = $"当前整批油条（{fryer.Runtime.Quantity} 根）";
            texture = fryer.Runtime.State == FryerState.Burnt ? _art.BurntYoutiao
                : fryer.Runtime.State == FryerState.Loaded ? _art.RawYoutiao : _art.Ingredient(StableIds.Ingredients.Youtiao);
            valid = () => ReferenceEquals(FryerMachine, fryer) && fryer.Runtime.Generation == generation
                && fryer.Runtime.Quantity > 0 && fryer.Runtime.State is not (FryerState.Empty or FryerState.Stored);
            commit = () => fryer.TryExecute(FryerCommand.Discard).Success;
        }
        else return false;

        _trashSourceValid = valid;
        _trashCommit = commit;
        void Begin()
        {
            _stroke.CancelStroke();
            _rawYoutiaoInput.Cancel();
            foreach (var gesture in _stockGestures) gesture.Cancel();
            _drag.BeginDrag(source, TrashPayload, name, Colors.White,
                new DragVisualSpec(texture, new Vector2(150, 120)), MouseButton.Right);
        }
        if (prepareOnly) { _beginHeldTrash = Begin; return true; }
        Begin();
        return _drag.IsDragging;
    }

    private bool CanAcceptTianjinTrash(string payload) => payload == TrashPayload && _drag.IsDragging
        && CanInteract && !IsTransferringBag && _trashSourceValid?.Invoke() == true;

    private void CommitTianjinTrash(string payload)
    {
        if (!CanAcceptTianjinTrash(payload) || _trashCommit?.Invoke() != true) return;
        _trashSourceValid = null;
        _trashCommit = null;
        LearnWorkbenchAction("discard");
        Render();
        Inform("食物已丢弃。", false);
    }
}
