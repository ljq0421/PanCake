using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Pancake;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private async Task TestTianjinTrash(DataCatalog catalog)
    {
        var station = SceneFactory.Instantiate<PancakeWorkstation>("res://Scenes/Gameplay/PancakeWorkstation.tscn");
        AddChild(station);
        station.Initialize(catalog, 1, 1, 1, catalog.DaysByNumber[15]);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var drag = station.GetChildren().OfType<DragService>().Single();
        var trash = (DropZone)station.FindChild("TrashZone", true, false);
        Control Find(string name) => (Control)station.FindChild(name, true, false);
        Vector2 Point(string name) => Find(name).GetGlobalRect().GetCenter();
        Vector2 Target() => trash.GetParent<Control>().GetGlobalTransform() * trash.FixedHitRect!.Value.GetCenter();
        void Release(MouseButton button, Vector2 point)
        {
            using var e = new InputEventMouseButton { ButtonIndex = button, Pressed = false, Position = point };
            drag._Input(e);
        }
        Variant reduced = ProjectSettings.GetSetting("accessibility/reduce_motion", false);
        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        try
        {
            Check(!station.TryBeginTrashDrag(Point("PancakeCanvas")), "空炉面不能右键丢弃");
            foreach (PancakeState state in Enum.GetValues<PancakeState>().Where(s => s is not (PancakeState.Empty or PancakeState.Delivered)))
            {
                station.Machine.Runtime.State = state;
                Check(station.TryBeginTrashDrag(Point("PancakeCanvas")), $"{state} 可发起右键丢弃");
                Check(station.Machine.Runtime.State == state, "按下时不扣除食物");
                Release(MouseButton.Left, Target());
                Check(drag.IsDragging && station.Machine.Runtime.State == state, "左键松开不能提交右键拖动");
                Check(!station.CanDeliverProduct("tianjin_trash"), "丢弃载荷不能交付");
                Release(MouseButton.Right, Target());
                Check(station.Machine.Runtime.State == PancakeState.Empty && !drag.IsDragging, $"{state} 丢弃清空炉面");
                Release(MouseButton.Right, Target());
                Check(station.Machine.Runtime.State == PancakeState.Empty, "重复松开不重复清理");
            }
            foreach (FryerState state in new[] { FryerState.Loaded, FryerState.Frying, FryerState.Raised, FryerState.Draining, FryerState.Burnt })
            {
                var runtime = station.FryerMachine!.Runtime;
                runtime.State = state; runtime.Quantity = 3;
                Check(station.TryBeginTrashDrag(Point("FryerVisual")), $"{state} 可拖动炸锅整批");
                Release(MouseButton.Right, Target());
                Check(runtime.State == FryerState.Empty && runtime.Quantity == 0, "炸锅整批清空");
            }
            var inventory = station.FryerMachine!.Inventory;
            inventory.TryStore(3, YoutiaoQuality.Golden);
            Check(station.TryBeginTrashDrag(Point("FinishedYoutiaoDrag")), "熟油条可右键拖动");
            Release(MouseButton.Right, Target());
            Check(inventory.Count == 2, "熟油条只丢弃一根");
            drag.BeginDrag(Find("FinishedYoutiaoDrag"), "stored_youtiao", "油条", Colors.White);
            Check(!trash.CanAccept("stored_youtiao") && !trash.CanAccept("soy_milk_cup"), "垃圾桶拒绝左键成品及豆浆");
            drag.CancelDrag();
            Check(inventory.Count == 2, "取消不扣库存");
            station.TryBeginTrashDrag(Point("FinishedYoutiaoDrag"));
            inventory.TryTake(out _);
            Check(!trash.CanAccept("tianjin_trash"), "库存队首变化后拒绝旧来源");
            station.CancelInput();
            station.Machine.TryExecute(PancakeCommand.PlaceBatter);
            station.TryBeginTrashDrag(Point("PancakeCanvas"));
            station.Machine.TryExecute(PancakeCommand.Discard);
            station.Machine.TryExecute(PancakeCommand.PlaceBatter);
            Check(!trash.CanAccept("tianjin_trash"), "新煎饼不会被旧拖动清理");
            station.CancelInput();
            station.TryBeginTrashDrag(Point("PancakeCanvas"));
            using (var esc = new InputEventKey { Keycode = Key.Escape, Pressed = true }) drag._Input(esc);
            Check(!drag.IsDragging && station.Machine.Runtime.State == PancakeState.BatterPlaced, "Esc 保留制作中食物");
            station.TryBeginTrashDrag(Point("PancakeCanvas"));
            station.Paused = true; station.Tick(.01);
            Check(!drag.IsDragging && !station.TryBeginTrashDrag(Point("PancakeCanvas")), "暂停取消并禁止丢弃");
            station.Paused = false;
            station.TryBeginTrashDrag(Point("PancakeCanvas"));
            Release(MouseButton.Right, Vector2.Zero);
            await WaitForAnimation(.3);
            Check(station.Machine.Runtime.State == PancakeState.BatterPlaced, "桶外松开保留食物");
            station.FryerMachine.Runtime.State = FryerState.Draining;
            station.FryerMachine.Runtime.Quantity = 1;
            station.TryBeginTrashDrag(Point("FryerVisual"));
            station.FryerMachine.Tick(100);
            Check(!trash.CanAccept("tianjin_trash"), "炸锅入库后拒绝原批次拖动");
            station.CancelInput();
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            station.TryBeginTrashDrag(Point("PancakeCanvas"));
            Release(MouseButton.Right, Target());
            station.Paused = true;
            station.CancelInput();
            await WaitForAnimation(.3);
            Check(station.Machine.Runtime.State == PancakeState.BatterPlaced, "吸附动画中暂停不会迟到扣除");
            station.Paused = false;
            station.TryBeginTrashDrag(Point("PancakeCanvas"));
            Release(MouseButton.Right, Target());
            await WaitForAnimation(.3);
            Check(station.Machine.Runtime.State == PancakeState.Empty, "普通动画完成后准确提交丢弃");
            ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            void Right(bool pressed)
            {
                using var input = new InputEventMouseButton { ButtonIndex = MouseButton.Right,
                    Pressed = pressed, Position = Point("PancakeCanvas") };
                station.HandleRightFoodInput(input);
            }
            station.Machine.Runtime.State = PancakeState.Saucing;
            station.Machine.SetSauceCoverage(.35);
            Right(true);
            Check(!drag.IsDragging && station.Machine.Runtime.State == PancakeState.Saucing, "右键按下等待区分短按和长按");
            station.Tick(.1); Right(false);
            Check(!drag.IsDragging && station.Machine.Runtime.State == PancakeState.Sauced
                && Close(station.Machine.Runtime.SauceCoverage, .35), "短按右键只收刷并保留酱量");
            station.Machine.Runtime.State = PancakeState.Saucing;
            Right(true); station.Tick(.44);
            Check(!drag.IsDragging && station.Machine.Runtime.State == PancakeState.Saucing, "0.45秒前不拾取也不收刷");
            station.Tick(.01);
            Check(drag.IsDragging && station.Machine.Runtime.State == PancakeState.Saucing, "达到长按门槛开始拖动且不收刷");
            Release(MouseButton.Right, Target());
            Check(station.Machine.Runtime.State == PancakeState.Empty, "长按右键后投放丢弃");
            station.Machine.TryExecute(PancakeCommand.PlaceBatter);
            Right(true); station.Tick(.2); station.CancelInput(); station.Tick(.5); Right(false);
            Check(!drag.IsDragging && station.Machine.Runtime.State == PancakeState.BatterPlaced, "取消长按后松手不会拾取或清理");
            Right(true);
            using (var motion = new InputEventMouseMotion { Position = Point("PancakeCanvas") + new Vector2(20, 0) })
                station.HandleRightFoodInput(motion);
            station.Tick(.5); Right(false);
            Check(!drag.IsDragging && station.Machine.Runtime.State == PancakeState.BatterPlaced, "门槛前直接拖动不触发丢弃");
        }
        finally
        {
            ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
            station.QueueFree();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
    }
}
