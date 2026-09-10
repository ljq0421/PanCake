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
    private async Task TestProductionShortcuts(DataCatalog catalog)
    {
        string savePath = $"user://shortcuts-{Guid.NewGuid():N}.json";
        var save = new SaveService(); AddChild(save); save.UsePathForTests(savePath);
        var controller = new DayController(); AddChild(controller);
        var screen = ProjectCake.Core.SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(controller);
        screen.Initialize(catalog, save, controller, 15);
        screen.SetProcess(false);
        screen.BeginDay();
        var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        var drag = station.GetChildren().OfType<DragService>().Single();
        var machine = station.Machine;
        var fryer = station.FryerMachine!;
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        try
        {
            // Feed real viewport events so GUI focus and input propagation are covered.
            PrepareFirstSide();
            machine.Tick(machine.Stove.SideAReadySeconds);
            Send(Key.F);
            Check(machine.Runtime.State == PancakeState.SideAReady, "开门倒计时屏蔽 F");
            controller.Tick(3);
            screen.RefreshForCapture(true);
            Button flip = (Button)station.FindChild("PancakeFlipAction", true, false);
            flip.GrabFocus();
            Send(Key.F);
            Check(machine.Runtime.State == PancakeState.SideBCooking && machine.Runtime.CookingSeconds == 0,
                "按钮聚焦时 F 仍通过真实输入翻面并保留第二面熟制");
            Send(Key.F);
            Check(machine.Runtime.State == PancakeState.SideBCooking, "连续 F 不能跳过第二面熟制");
            machine.Tick(machine.Stove.SideBReadySeconds);
            Send(Key.F);
            Check(machine.Runtime.State == PancakeState.SideBReady, "F 不能代替手动抹酱");
            RightClick();
            Check(machine.Runtime.State == PancakeState.SideBReady, "未拿刷时右键不开始刷酱");
            machine.TryExecute(PancakeCommand.BeginSauce);
            screen.RefreshForCapture(true);
            RightClick(pressed: false);
            Check(machine.Runtime.State == PancakeState.Saucing, "右键松开不收刷");
            Send(Key.Escape); RightClick();
            Check(machine.Runtime.State == PancakeState.Saucing, "暂停时右键不收刷");
            Send(Key.Escape);
            screen._Notification((int)NotificationApplicationFocusOut); RightClick();
            Check(machine.Runtime.State == PancakeState.Saucing, "失焦时右键不收刷");
            screen._Notification((int)NotificationApplicationFocusIn);
            screen.Hide(); RightClick(); screen.Show();
            Check(machine.Runtime.State == PancakeState.Saucing, "隐藏天津界面时右键不收刷");
            var sauceDialog = screen.GetChildren().OfType<ConfirmationDialog>().Single();
            sauceDialog.Show();
            using (var mouse = new InputEventMouseButton { ButtonIndex = MouseButton.Right, Pressed = true }) screen._Input(mouse);
            sauceDialog.Hide();
            Check(machine.Runtime.State == PancakeState.Saucing, "确认弹窗时右键不收刷");
            drag.BeginDrag(station, "stored_youtiao", "熟油条", Colors.White);
            RightClick();
            Check(machine.Runtime.State == PancakeState.Saucing && drag.IsDragging, "拖拽期间右键不收刷或取消物品");
            drag.CancelDrag();
            var stroke = (StrokeInteractor)station.FindChild("PancakeStrokeInput", true, false);
            Vector2 brushPoint = stroke.GetGlobalRect().GetCenter();
            using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = brushPoint })
                GetViewport().PushInput(press);
            machine.SetSauceCoverage(0.35);
            RightClick();
            Check(machine.Runtime.State == PancakeState.Sauced && Close(machine.Runtime.SauceCoverage, 0.35)
                && Input.MouseMode == Input.MouseModeEnum.Visible, "饼面按住左键时右键收刷，保留少酱量并恢复鼠标");
            using (var motion = new InputEventMouseMotion { Position = brushPoint + new Vector2(40, 0), ButtonMask = MouseButtonMask.Left })
                GetViewport().PushInput(motion);
            using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = brushPoint })
                GetViewport().PushInput(release);
            RightClick();
            Check(machine.Runtime.State == PancakeState.Sauced && Close(machine.Runtime.SauceCoverage, 0.35),
                "收刷后移动、松开左键和重复右键不继续刷酱或折叠");
            Send(Key.F);
            Check(machine.Runtime.State == PancakeState.Folded, "一次 F 只折叠，不连带装袋");
            Send(Key.F, echo: true);
            Send(Key.F, pressed: false);
            Send(Key.F, ctrl: true);
            Check(machine.Runtime.State == PancakeState.Folded, "长按重复、松键与 Ctrl+F 不装袋");

            fryer.TryExecute(FryerCommand.LoadOne);
            drag.BeginDrag(station, "stored_youtiao", "熟油条", Colors.White);
            Send(Key.F); Send(Key.G);
            Check(machine.Runtime.State == PancakeState.Folded && fryer.Runtime.State == FryerState.Loaded,
                "拖拽物品时 F/G 均不推进生产");
            Send(Key.Escape);
            Check(!drag.IsDragging && !station.Paused, "Esc 优先取消拖拽，不同时暂停");
            Send(Key.Escape);
            Send(Key.F); Send(Key.G);
            Check(station.Paused && machine.Runtime.State == PancakeState.Folded && fryer.Runtime.State == FryerState.Loaded,
                "暂停期间 F/G 均不推进生产");
            Send(Key.Escape);
            screen._Notification((int)NotificationApplicationFocusOut);
            Send(Key.F); Send(Key.G);
            Check(machine.Runtime.State == PancakeState.Folded && fryer.Runtime.State == FryerState.Loaded,
                "失焦期间 F/G 均不推进生产");
            screen._Notification((int)NotificationApplicationFocusIn);
            screen.Hide(); Send(Key.F); Send(Key.G); screen.Show();
            Check(machine.Runtime.State == PancakeState.Folded && fryer.Runtime.State == FryerState.Loaded,
                "隐藏营业界面不响应 F/G");
            var dialog = screen.GetChildren().OfType<ConfirmationDialog>().Single();
            dialog.Show();
            using (var key = new InputEventKey { Keycode = Key.F, Pressed = true }) screen._UnhandledInput(key);
            using (var key = new InputEventKey { Keycode = Key.G, Pressed = true }) screen._UnhandledInput(key);
            dialog.Hide();
            Check(machine.Runtime.State == PancakeState.Folded && fryer.Runtime.State == FryerState.Loaded,
                "确认弹窗显式屏蔽 F/G");
            screen.RefreshForCapture(true);
            Send(Key.F);
            Check(machine.Runtime.State == PancakeState.Bagged && station.PancakeTray.Count == 0 && !station.IsTransferringBag,
                "再次按 F 装袋后留在炉面，无移盘动画");
            Send(Key.F);
            Check(machine.Runtime.State == PancakeState.Bagged && station.PancakeTray.Count == 0, "装袋后 F 不自动交付或丢弃");
            Send(Key.G);
            Check(fryer.Runtime.State == FryerState.Frying && fryer.Runtime.Quantity == 1 && fryer.Runtime.FrySeconds == 0,
                "G 只放下已装料炸篮，不自动加料或跳过炸制");
            Send(Key.G, echo: true); Send(Key.G, pressed: false);
            Check(fryer.Runtime.State == FryerState.Frying, "长按 G 不立即抬篮");
            fryer.Tick(fryer.Level.GoldenStartSeconds);
            Send(Key.G);
            Check(fryer.Runtime.State == FryerState.Draining && fryer.Runtime.Quality == YoutiaoQuality.Golden
                && fryer.Inventory.Count == 0, "G 抬篮保留火候和沥油等待");

            station.ResetForDay();
            PrepareFirstSide();
            Send(Key.F);
            Check(machine.Runtime.State == PancakeState.SideACooking, "第一面未熟时 F 无效");
            machine.Tick(100);
            fryer.TryExecute(FryerCommand.LoadOne); fryer.TryExecute(FryerCommand.LowerBasket); fryer.Tick(100);
            Send(Key.F); Send(Key.G);
            Check(machine.Runtime.State == PancakeState.Burnt && fryer.Runtime.State == FryerState.Burnt,
                "焦糊时 F/G 均不能触发清理");
            ((Button)station.FindChild("PancakeDiscardAction", true, false)).EmitSignal(Button.SignalName.Pressed);
            ((Button)station.FindChild("FryerDiscardAction", true, false)).EmitSignal(Button.SignalName.Pressed);
            Check(machine.Runtime.State == PancakeState.Empty && fryer.Runtime.State == FryerState.Empty,
                "清理按钮仍可独立使用鼠标操作");

            station.Initialize(catalog, 1, 1, 3, catalog.DaysByNumber[15]);
            fryer = station.FryerMachine!;
            fryer.TryExecute(FryerCommand.LoadOne); Send(Key.G); Send(Key.G);
            Check(fryer.Runtime.State == FryerState.Frying, "高级炸锅 G 可下锅但不提前手动抬篮");
            fryer.Tick(fryer.Level.AutoRaiseAtSeconds);
            Check(fryer.Runtime.State == FryerState.Draining, "高级炸锅仍在原定时刻自动抬篮");
            station.Initialize(catalog, 1, 1, 0, catalog.DaysByNumber[1]); Send(Key.G);
            Check(station.FryerMachine is null, "未解锁炸锅时 G 安全无效");
            Check(flip.Text == "翻面 F"
                && ((Button)station.FindChild("PancakeDiscardAction", true, false)).Text == "清理炉面",
                "制作按钮显示键位，清理按钮不显示制作快捷键");
        }
        finally
        {
            screen.QueueFree(); controller.QueueFree(); save.QueueFree();
            DeleteIfExists(ProjectSettings.GlobalizePath(savePath));
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }

        void PrepareFirstSide()
        {
            machine.TryExecute(PancakeCommand.PlaceBatter);
            machine.TryExecute(PancakeCommand.BeginSpread); machine.SetSpreadCoverage(1);
            machine.TryExecute(PancakeCommand.CompleteSpread); machine.TryExecute(PancakeCommand.AddEgg);
        }
        void Send(Key code, bool pressed = true, bool echo = false, bool ctrl = false)
        {
            using var input = new InputEventKey { Keycode = code, Pressed = pressed, Echo = echo, CtrlPressed = ctrl };
            GetViewport().PushInput(input);
        }
        void RightClick(bool pressed = true)
        {
            var stroke = (Control)station.FindChild("PancakeStrokeInput", true, false);
            using var input = new InputEventMouseButton
            {
                ButtonIndex = MouseButton.Right, Pressed = pressed, Position = stroke.GetGlobalRect().GetCenter(),
            };
            GetViewport().PushInput(input);
        }
    }
}
