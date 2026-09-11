using System.Text.Json;
using System.Text.Json.Nodes;
using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private async Task TestTianjinWorkbenchV1(DataCatalog catalog)
    {
        string path = $"res://.tmp/tianjin-workbench-save-{Guid.NewGuid():N}.json";
        string absolute = ProjectSettings.GlobalizePath(path);
        var legacyJson = JsonSerializer.SerializeToNode(new SaveData())!;
        foreach (var city in legacyJson["Cities"]!.AsObject()) city.Value!.AsObject().Remove("LearnedWorkbenchActions");
        File.WriteAllText(absolute, legacyJson.ToJsonString());
        var save = new SaveService(); AddChild(save); save.UsePathForTests(path);
        Check(!save.HasLoadError && save.Data.Tianjin.LearnedWorkbenchActions.Count == 0,
            "无教学字段的旧版存档正常读取，不按历史进度推测已学操作");
        save.Data.PurchasedStoveLevel = save.Data.PurchasedIngredientStationLevel = save.Data.PurchasedFryerLevel = 3;
        save.Data.PurchasedFryerLevel = 1; // Exercise the manual raise action before its Lv3 automatic replacement.
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
        AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller);
        screen.Initialize(catalog, save, controller, 15); screen.BeginDay(); controller.Tick(3);
        screen.RefreshForCapture(true);
        var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var egg = (Button)station.FindChild("IngredientInput_egg", true, false);
        var stove = (DropZone)station.FindChild("PancakeDropZone", true, false);
        int learnedEvents = 0;
        station.WorkbenchActionLearned += _ => learnedEvents++;
        egg.EmitSignal(Button.SignalName.Pressed);
        Check(learnedEvents == 0 && save.Data.Tianjin.LearnedWorkbenchActions.Count == 0,
            "空炉错点鸡蛋不学习、不写入教学记录");
        Check(stove.TryAccept("batter"), "实际炉面接收面糊");
        station.CancelInput();
        Check(learnedEvents == 1 && save.Data.Tianjin.LearnedWorkbenchActions.Contains("take:batter"),
            "成功放浆只记录一次教学");
        Check(!stove.CanAccept("batter") && learnedEvents == 1, "重复放浆被拒绝且不重复记录");
        station.Machine.TryExecute(PancakeCommand.BeginSpread);
        station.Machine.SetSpreadCoverage(1);
        var stroke = (StrokeInteractor)station.FindChild("PancakeStrokeInput", true, false);
        stroke.StrokeCompleted?.Invoke(StrokeMode.Spread);
        egg.EmitSignal(Button.SignalName.Pressed);
        int quantity = station.Inventory.GetQuantity("egg"), eventsBefore = learnedEvents;
        egg.EmitSignal(Button.SignalName.Pressed);
        Check(save.Data.Tianjin.LearnedWorkbenchActions.Contains("spread")
            && save.Data.Tianjin.LearnedWorkbenchActions.Contains("take:egg")
            && learnedEvents == eventsBefore && station.Inventory.GetQuantity("egg") == quantity,
            "成功摊面和加蛋记录，重复加蛋不消费也不重复学习");
        var loaded = new SaveService(); AddChild(loaded); loaded.UsePathForTests(path);
        Check(loaded.Data.Tianjin.LearnedWorkbenchActions.SetEquals(save.Data.Tianjin.LearnedWorkbenchActions),
            "教学记录经真实磁盘写入和重新加载保留");
        loaded.Free();
        station.ResetForDay();
        Check(!((Control)station.FindChild("PancakeStatusTag", true, false)).Visible
            && ((Control)station.FindChild("FryerStatusTag", true, false)).Visible,
            "已学放浆说明收起，未学炸锅仍显示首次说明");
        var raw = (PressRepeatGesture)station.FindChild("RawYoutiaoInput", true, false);
        raw.Activate?.Invoke();
        Check(station.FryerMachine!.Runtime.Quantity == 1 && save.Data.Tianjin.LearnedWorkbenchActions.Contains("fryer:load"),
            "生油条既有装料手势成功后学习");
        ((Button)station.FindChild("FryerLowerAction", true, false)).EmitSignal(Button.SignalName.Pressed);
        Check(save.Data.Tianjin.LearnedWorkbenchActions.Contains("fryer:lower"), "下锅按钮成功后独立学习");
        var refill = (StockGesture)station.FindChild("StockGesture_egg", true, false);
        refill.Refill?.Invoke();
        Check(!save.Data.Tianjin.LearnedWorkbenchActions.Contains("refill:egg"), "满盘补货失败不学习");
        station.Inventory.TryConsume("egg");
        refill.Refill?.Invoke();
        Check(station.Inventory.IsAnyRefilling && save.Data.Tianjin.LearnedWorkbenchActions.Contains("refill:egg"),
            "补货成功启动后单独记录教学");
        var coins = (CoinTrayView)station.FindChild("CoinTray", true, false);
        Check(!coins.TryCollect() && !save.Data.Tianjin.LearnedWorkbenchActions.Contains("collect_coins"), "空盘收钱不学习");
        coins.RenderRevenue(20, 1);
        Check(!coins.IsVisibleInTree() && !coins.TryCollect() && !save.Data.Tianjin.LearnedWorkbenchActions.Contains("collect_coins"), "天津旧收钱入口隐藏且停用，不再学习收钱");

        // A directory at the destination deterministically rejects the atomic file move.
        File.Delete(absolute);
        Directory.CreateDirectory(absolute);
        raw.Activate?.Invoke(); // Lowered basket rejects loading; no save attempt.
        Check(!station.LearnedWorkbenchActions.Contains("fryer:raise"), "炸篮未成功升起前不学习");
        ((Button)station.FindChild("FryerRaiseAction", true, false)).EmitSignal(Button.SignalName.Pressed);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check(station.LearnedWorkbenchActions.Contains("fryer:raise")
            && save.Data.Tianjin.LearnedWorkbenchActions.Contains("fryer:raise"),
            "保存失败不回滚升篮操作，当前会话保留已掌握状态");
        Directory.Delete(absolute);
        Check(save.TrySave(out _) , "保存路径恢复后可保存当前会话教学记录");
        var afterFailure = new SaveService(); AddChild(afterFailure); afterFailure.UsePathForTests(path);
        Check(afterFailure.Data.Tianjin.LearnedWorkbenchActions.Contains("fryer:raise"), "保存重试后重启仍记住操作");
        afterFailure.Free();

        var art = new TianjinArtCatalog();
        var portrait = screen.Descendants<CustomerPortraitView>().First();
        foreach (var appearance in CustomerAppearanceCatalog.All)
        {
            portrait.SetVisual(art.CustomerPortrait(appearance.Id, CustomerExpression.Normal));
            portrait.SetCounterCalibration(art.CustomerLayout(appearance.Id).NormalVisibleBounds);
            TextureRect head = portrait.GetChildren().OfType<TextureRect>().Single(node => node.Texture == portrait.HeadTexture);
            Rect2I pixels = VisibleBounds(portrait.HeadTexture!);
            Vector2 headSize = (Vector2)pixels.Size * head.Size / portrait.HeadTexture!.GetSize();
            Check(headSize.Y is >= 151 and <= 159, $"{appearance.Id} 天津头部按实体边界统一视觉高度");
        }
        var order = screen.Descendants<OrderBubbleView>().First();
        Control portraitWindow = portrait.GetParent<Control>();
        Vector2 waist = portraitWindow.GetGlobalRect().End;
        var largeOrder = new OrderData { OrderId = "workbench-large", CustomerTypeId = "big_order", Lines = new[] { new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Basic, 2),
            new OrderLineData(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1) } };
        order.Render(largeOrder, new OrderProgress(largeOrder), catalog.RecipesById);
        order.ResetSize();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check(portraitWindow.GetGlobalRect().End.IsEqualApprox(waist)
            && order.GetGlobalRect().End.Y + 12 <= portraitWindow.GetGlobalRect().Position.Y + 15,
            "双煎饼套餐增高订单卡时人物腰线稳定，气泡尾部不压人物头部");
        Check(!screen.GetNode<TianjinDeskGuide>("TianjinDeskGuide").Visible, "正式运行隐藏桌面开发辅助线");

        var trash = (DropZone)station.FindChild("TrashZone", true, false);
        var drag = station.GetChildren().OfType<DragService>().Single();
        var food = (Control)station.FindChild("FinishedYoutiaoDrag", true, false);
        Variant motion = ProjectSettings.GetSetting("accessibility/reduce_motion", false);
        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        foreach (float scale in new[] { 1f, 2f / 3f })
        {
            screen.Scale = Vector2.One * scale;
            station.FryerMachine.Inventory.TryStore(1, YoutiaoQuality.Golden);
            Rect2 hit = trash.FixedHitRect!.Value;
            Transform2D transform = trash.GetParent<Control>().GetGlobalTransform();
            Vector2 outside = transform * new Vector2(hit.End.X + 1, hit.GetCenter().Y);
            Vector2 inside = transform * hit.GetCenter();
            int stock = station.FryerMachine.Inventory.Count;
            drag.BeginDrag(food, "stored_youtiao", "油条", Colors.White);
            trash.Scale = Vector2.One * 1.03f;
            Check(!trash.ContainsPoint(outside) && trash.ContainsPoint(inside), $"缩放{scale} 垃圾桶放大高亮不扩大命中区域");
            using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = outside }) drag._Input(release);
            await WaitForAnimation(.15);
            Check(station.FryerMachine.Inventory.Count == stock && !station.LearnedWorkbenchActions.Contains("discard"),
                $"缩放{scale} 桶外松手不会消费物品或学习丢弃");
            // Both iterations exercise the outside path before the single valid discard below.
        }
        screen.Scale = Vector2.One;
        Check(!trash.TryAccept("soy_milk_cup"), "垃圾桶拒绝豆浆，取杯区不会成为丢弃入口");
        station.CancelInput();
        drag.BeginDrag(food, "stored_youtiao", "油条", Colors.White);
        Vector2 target = trash.GetParent<Control>().GetGlobalTransform() * trash.FixedHitRect!.Value.GetCenter();
        int beforeDiscard = station.FryerMachine!.Inventory.Count;
        using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = target }) drag._Input(release);
        Check(station.FryerMachine.Inventory.Count == beforeDiscard - 1 && save.Data.Tianjin.LearnedWorkbenchActions.Contains("discard"),
            "有效垃圾桶区域松手准确丢弃一件并保存教学");
        ProjectSettings.SetSetting("accessibility/reduce_motion", motion);

        Vector2? stoveCenter = null, fryerContact = null, fryerOpening = null;
        for (int level = 1; level <= 3; level++)
        {
            station.Initialize(catalog, level, level, level, catalog.DaysByNumber[15]);
            var canvas = (PancakeCanvas)station.FindChild("PancakeCanvas", true, false);
            var fryer = (FryerVisualView)station.FindChild("FryerVisual", true, false);
            stoveCenter ??= canvas.GetSurfaceRect().GetCenter();
            fryerContact ??= fryer.TableContactAnchor; fryerOpening ??= fryer.OpeningCenter;
            Check(canvas.GetSurfaceRect().GetCenter().IsEqualApprox(stoveCenter.Value)
                && fryer.TableContactAnchor.IsEqualApprox(fryerContact.Value) && fryer.OpeningCenter.IsEqualApprox(fryerOpening.Value)
                && fryer.HasNode("BasketAnchor"), $"Lv{level} 炉面圆心、炸锅锅口和接触锚点升级不漂移");
        }
        screen.Initialize(catalog, save, controller, 9);
        Check(station.LearnedWorkbenchActions.Contains("take:batter") && station.LearnedWorkbenchActions.Contains("refill:egg")
            && !station.LearnedWorkbenchActions.Contains("take:ham"), "切换关卡保留已学操作，未成功的新操作继续教学");
        screen.Free(); controller.Free(); save.Free(); DeleteIfExists(absolute);
    }
}
