using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private async Task TestRawYoutiaoGestures(DataCatalog catalog)
    {
        string savePath = $"user://raw-youtiao-{Guid.NewGuid():N}.json";
        var save = new SaveService(); AddChild(save); save.UsePathForTests(savePath);
        var controller = new DayController(); AddChild(controller);
        var screen = ProjectCake.Core.SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(controller);
        screen.Initialize(catalog, save, controller, 11);
        screen.SetProcess(false);
        screen.BeginDay(); controller.Tick(3);
        screen.RefreshForCapture(true);
        var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        var gesture = (PressRepeatGesture)station.FindChild("RawYoutiaoInput", true, false);
        var slot = (WorkstationSlotView)station.FindChild("RawYoutiaoSlot", true, false);
        var drag = station.GetChildren().OfType<DragService>().Single();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        try
        {
            foreach (int level in new[] { 1, 2, 3 })
            foreach (float scale in new[] { 1f, 2f / 3f })
            {
                screen.Scale = Vector2.One * scale;
                station.Initialize(catalog, level, level, level, catalog.DaysByNumber[11]);
                FryerStateMachine fryer = station.FryerMachine!;
                Vector2 point = PickPoint();
                Press(point); station.Tick(.1); Release(point);
                Check(fryer.Runtime.Quantity == 1 && !drag.IsDragging, $"Lv{level}/{scale} 实际短按只装一根且不启动拖拽");
                Press(point); station.Tick(.1); Release(point);
                Check(fryer.Runtime.Quantity == 2, $"Lv{level}/{scale} 连续点击逐根累加");
                station.ResetForDay();
                Press(point); station.Tick(.449);
                Check(fryer.Runtime.Quantity == 0, $"Lv{level}/{scale} 长按门槛前不装料");
                station.Tick(.001);
                Check(fryer.Runtime.Quantity == 1, $"Lv{level}/{scale} 长按0.45秒装第一根");
                station.Tick(.149);
                Check(fryer.Runtime.Quantity == 1, $"Lv{level}/{scale} 重复间隔前不提前装料");
                station.Tick(.001);
                Check(fryer.Runtime.Quantity == 2, $"Lv{level}/{scale} 每0.15秒继续装一根");
                Release(point); station.Tick(1);
                Check(fryer.Runtime.Quantity == 2, $"Lv{level}/{scale} 长按松手不补一根也不继续装料");

                Press(point); station.Tick(3);
                Check(fryer.Runtime.Quantity == fryer.Level.Capacity, $"Lv{level}/{scale} 大时间步也只装至容量上限");
                fryer.TryExecute(FryerCommand.Discard); station.Tick(1); Release(point);
                Check(fryer.Runtime.Quantity == 0, $"Lv{level}/{scale} 装满停止后清空炸篮不会自动重新装料");

                Press(point); station.Tick(.45);
                Move(point + new Vector2(400, 0)); Move(point); station.Tick(1); Release(point);
                Check(fryer.Runtime.Quantity == 1 && !drag.IsDragging, $"Lv{level}/{scale} 移出再移回不会恢复连装或变成拖拽");
                station.ResetForDay();
                Press(point); Release(point + new Vector2(400, 0)); station.Tick(1);
                Check(fryer.Runtime.Quantity == 0, $"Lv{level}/{scale} 区域外松手取消短按");

                foreach (string reason in new[] { "暂停", "禁止交互", "失焦", "隐藏", "Esc", "重开" })
                {
                    station.ResetForDay();
                    Press(point); station.Tick(.45);
                    switch (reason)
                    {
                        case "暂停": station.Paused = true; station.Tick(.2); station.Paused = false; break;
                        case "禁止交互": station.InteractionEnabled = false; station.Tick(.2); station.InteractionEnabled = true; break;
                        case "失焦":
                            screen._Notification((int)NotificationApplicationFocusOut);
                            screen._Notification((int)NotificationApplicationFocusIn);
                            break;
                        case "隐藏": screen.Hide(); screen.Show(); break;
                        case "Esc":
                            using (var escape = new InputEventKey { Keycode = Key.Escape, Pressed = true }) gesture._Input(escape);
                            break;
                        case "重开": station.ResetForDay(); break;
                    }
                    station.Tick(1); Release(point);
                    Check(fryer.Runtime.Quantity == (reason == "重开" ? 0 : 1), $"Lv{level}/{scale} {reason}后不恢复连装，松手不补料");
                }

                station.ResetForDay();
                Press(point); station.Tick(.45);
                Check(station.TryInvokeProductionShortcut(Key.G), $"Lv{level}/{scale} 装料中仍可按G下锅");
                station.Tick(.15); Release(point);
                Check(fryer.Runtime.Quantity == 1 && fryer.Runtime.State == FryerState.Frying,
                    $"Lv{level}/{scale} 下锅立即停止连装，不往炸制中的篮子加料");
                Press(point); station.Tick(.6); Release(point);
                Check(fryer.Runtime.Quantity == 1, $"Lv{level}/{scale} 炸制期间短按与长按均不能装料");
                station.ResetForDay();
                fryer.Inventory.TryStore(fryer.Level.Capacity, YoutiaoQuality.Golden);
                Press(point); Release(point);
                Check(fryer.Runtime.Quantity == 1 && fryer.Inventory.Count == fryer.Level.Capacity,
                    $"Lv{level}/{scale} 熟油条架满时仍按原规则备料，不改变库存容量");
            }
        }
        finally
        {
            screen.Free(); controller.Free(); save.Free();
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(savePath));
        }

        Vector2 PickPoint()
        {
            // Use actual rendered alpha and viewport routing, including overlapping page controls.
            TextureRect visual = slot.IngredientVisuals[0];
            using Image image = visual.Texture.GetImage();
            for (int y = image.GetHeight() / 3; y < image.GetHeight(); y += 8)
            for (int x = image.GetWidth() / 3; x < image.GetWidth(); x += 8)
            {
                if (image.GetPixel(x, y).A <= .9f) continue;
                Vector2 global = visual.GetGlobalTransform() * (new Vector2(x + .5f, y + .5f) / image.GetSize() * visual.Size);
                if (gesture._HasPoint(gesture.GetGlobalTransform().AffineInverse() * global)) return global;
            }
            throw new InvalidOperationException("生油条没有可点击的实体采样点");
        }
        void Move(Vector2 point)
        {
            using var motion = new InputEventMouseMotion { Position = point };
            GetViewport().PushInput(motion, true);
        }
        void Press(Vector2 point)
        {
            Move(point);
            using var input = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point };
            GetViewport().PushInput(input, true);
        }
        void Release(Vector2 point)
        {
            using var input = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = point };
            GetViewport().PushInput(input, true);
        }
    }
}
