using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private async Task TestWorkbenchPicking()
    {
        DataCatalog catalog = GetNode<DataCatalog>("/root/DataCatalog");
        string savePath = $"user://workbench-picking-{Guid.NewGuid():N}.json";
        var save = new SaveService(); AddChild(save); save.UsePathForTests(savePath);
        var controller = new DayController(); AddChild(controller);
        var screen = ProjectCake.Core.SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(controller);
        screen.SetProcess(false);
        for (int level = 1; level <= 3; level++)
        {
            save.Data.PurchasedStoveLevel = level;
            save.Data.PurchasedIngredientStationLevel = level;
            save.Data.PurchasedFryerLevel = level;
            screen.Initialize(catalog, save, controller, 11);
            screen.BeginDay(); controller.Tick(3);
            // Keep every customer slot occupied to include all foreground UI.
            for (int step = 0; step < 1000 && controller.CustomerQueue!.Slots.Count < 5; step++)
            {
                controller.Tick(.1);
                foreach (var customer in controller.CustomerQueue.Slots) customer.WaitSeconds = 0;
            }
            screen.RefreshForCapture(true);
            var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
            MakeBagged(station.Machine, catalog.RecipesById[StableIds.Recipes.Basic]);
            station.Tick(.3);
            station.RefreshForCapture();
            // Native tooltip windows can consume synthetic sampling events after a long
            // audit dwell. This fixture tests control routing, not tooltip timing.
            foreach (Control control in screen.FindChildren("*", "Control", true, false).OfType<Control>())
                control.TooltipText = string.Empty;
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            foreach (float scale in new[] { 1f, 2f / 3f })
            {
                screen.Scale = Vector2.One * scale;
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                foreach (string id in TianjinWorkbenchLayout.IngredientOrder)
                {
                    var slot = (IngredientStockSlotView)station.FindChild($"IngredientSlot_{id}", true, false);
                    var input = (Control)station.FindChild($"StockGesture_{id}", true, false);
                    AuditSlot(slot, input, $"Lv{level} {id} 缩放{scale:F2}");
                    // Repeat after the same hover transform used during play.
                    await WaitForAnimation(.16);
                    AuditSlot(slot, input, $"Lv{level} {id} 悬停后 缩放{scale:F2}");
                }
                var cups = (SoyMilkStockView)station.FindChild("SoyMilkStockArt", true, false);
                AuditArt(cups.Cups, (Control)station.FindChild("StockGesture_soy_milk", true, false), $"Lv{level} 豆浆 缩放{scale:F2}");
                AuditArt(new[] { (TextureRect)station.FindChild("FinishedPancakeArt", true, false) },
                    (Control)station.FindChild("FinishedPancakeDrag", true, false), $"Lv{level} 装袋煎饼 缩放{scale:F2}");
            }
            // Exercise the actual tool/button handlers as well as pointer routing.
            station.ResetForDay();
            var machine = station.Machine;
            var stroke = (StrokeInteractor)station.FindChild("PancakeStrokeInput", true, false);
            machine.TryExecute(PancakeCommand.PlaceBatter);
            station.RefreshForCapture();
            Click(stroke);
            Check(machine.Runtime.State == PancakeState.Spreading, $"Lv{level} 炉面鼠标可启动摊饼工具");
            machine.SetSpreadCoverage(1); machine.TryExecute(PancakeCommand.CompleteSpread);
            station.RefreshForCapture();
            Click((Control)station.FindChild("IngredientInput_egg", true, false));
            Check(machine.Runtime.State == PancakeState.SideACooking, $"Lv{level} 鸡蛋点击实际生效");
            machine.Tick(machine.Stove.SideAReadySeconds);
            station.RefreshForCapture();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Click((Control)station.FindChild("PancakeFlipAction", true, false));
            Check(machine.Runtime.State == PancakeState.SideBCooking, $"Lv{level} 翻面铲按钮实际生效");
            machine.Tick(machine.Stove.SideBReadySeconds);
            station.RefreshForCapture();
            Click((Control)station.FindChild("IngredientInput_sauce", true, false));
            Click(stroke);
            Check(machine.Runtime.State == PancakeState.Saucing, $"Lv{level} 炉面鼠标可启动刷酱工具");
            machine.SetSauceCoverage(1); machine.TryExecute(PancakeCommand.CompleteSauce);
            station.RefreshForCapture();
            Click((Control)station.FindChild("IngredientInput_scallion", true, false));
            Check(machine.Runtime.ExtraIngredients.Contains(StableIds.Ingredients.Scallion), $"Lv{level} 香葱点击实际生效");
            station.RefreshForCapture();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Click((Control)station.FindChild("PancakeFoldAction", true, false));
            Check(machine.Runtime.State == PancakeState.Folded, $"Lv{level} 折叠工具按钮实际生效");
            station.RefreshForCapture();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Click((Control)station.FindChild("PancakeBagAction", true, false));
            Check(machine.Runtime.State == PancakeState.Bagged && station.PancakeTray.Count == 0, $"Lv{level} 装袋按钮将成品留在炉面");
            foreach (string id in TianjinWorkbenchLayout.IngredientOrder)
            {
                while (station.Inventory.GetQuantity(id) > 1) station.Inventory.TryConsume(id);
                station.RefreshForCapture();
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                var slot = (IngredientStockSlotView)station.FindChild($"IngredientSlot_{id}", true, false);
                var gesture = (StockGesture)station.FindChild($"StockGesture_{id}", true, false);
                AuditSlot(slot, gesture, $"Lv{level} {id} 少量库存");
                Check(gesture.GetGlobalRect().End.X <= 1920 * screen.Scale.X && !slot.RefillButton.Visible,
                    $"Lv{level} {id} 长按区域位于画面内且没有独立加号");
                Vector2 point = gesture.GetGlobalRect().GetCenter();
                using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point }) GetViewport().PushInput(press, true);
                station.Tick(.45);
                using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = point }) GetViewport().PushInput(release, true);
                Check(station.Inventory.IsUnlimited(id)
                        ? station.Inventory.GetStatus(id) == IngredientStockStatus.Normal && !station.Inventory.CanRefill(id)
                            && slot.LiquidTier == 3 && !slot.StockBar.Visible
                        : station.Inventory.GetStatus(id) == IngredientStockStatus.Refilling,
                    $"Lv{level} {id} 原地长按按有限/无限库存规则响应");
            }
        }
        screen.Free(); controller.Free(); save.Free();
        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(savePath));

        void Click(Control control)
        {
            Vector2 point = control.GetGlobalTransform() * (control.Size * .5f);
            using var motion = new InputEventMouseMotion { Position = point };
            GetViewport().PushInput(motion, true);
            using var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point };
            GetViewport().PushInput(press, true);
            using var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = point };
            GetViewport().PushInput(release, true);
        }
    }

    private void AuditSlot(IngredientStockSlotView slot, Control expected, string label)
    {
        if (!slot.IngredientInBackground) { AuditArt(slot.IngredientVisuals, expected, label); return; }
        using var motion = new InputEventMouseMotion { Position = expected.GetGlobalRect().GetCenter() };
        GetViewport().PushInput(motion, true);
        Check(GetViewport().GuiGetHoveredControl() == expected, $"背景碗入口路由 {label}");
    }

    private void AuditArt(IEnumerable<TextureRect> visuals, Control expected, string label)
    {
        int total = 0, reached = 0;
        string firstMiss = string.Empty;
        foreach (TextureRect visual in visuals.Where(item => item.IsVisibleInTree()))
        {
            using Image image = visual.Texture.GetImage();
            Vector2 textureSize = visual.Texture.GetSize();
            Vector2 drawnSize = textureSize * Math.Min(visual.Size.X / textureSize.X, visual.Size.Y / textureSize.Y);
            Rect2 drawn = new((visual.Size - drawnSize) * .5f, drawnSize);
            for (float y = 1; y < drawn.Size.Y; y += 3)
            for (float x = 1; x < drawn.Size.X; x += 3)
            {
                Vector2 local = drawn.Position + new Vector2(x, y);
                Vector2 pixel = new Vector2(x, y) / drawn.Size * (Vector2)image.GetSize();
                if (image.GetPixel((int)pixel.X, (int)pixel.Y).A < .9f) continue;
                Vector2 point = visual.GetGlobalTransform() * local;
                bool clipped = false;
                for (Node? ancestor = visual.GetParent(); ancestor is not null; ancestor = ancestor.GetParent())
                    if (ancestor is Control { ClipContents: true } clip
                        && !new Rect2(Vector2.Zero, clip.Size).HasPoint(clip.GetGlobalTransform().AffineInverse() * point)) clipped = true;
                if (clipped) continue;
                total++;
                using var motion = new InputEventMouseMotion { Position = point };
                GetViewport().PushInput(motion, true);
                Control? actual = GetViewport().GuiGetHoveredControl();
                if (actual == expected || (actual is not null && expected.IsAncestorOf(actual))) reached++;
                else if (firstMiss.Length == 0) firstMiss = $"point={point}; receiver={actual?.GetPath()}; expected={expected.GetPath()}; rect={expected.GetGlobalRect()}; local={expected.GetGlobalTransform().AffineInverse() * point}; has={expected._HasPoint(expected.GetGlobalTransform().AffineInverse() * point)}; handled={GetViewport().IsInputHandled()}; popups={string.Join(" | ", GetTree().Root.FindChildren("*", "Window", true, false).OfType<Window>().Where(w => w.Visible).Select(w => $"{w.Name}/{w.Position}/{w.Size}"))}";
            }
        }
        Check(total > 0 && reached == total, $"工作台可见部分输入路由 {label}", $"{reached}/{total}; {firstMiss}");
    }
}
