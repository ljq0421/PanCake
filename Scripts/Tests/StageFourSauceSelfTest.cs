using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private static double TestSauceAmount(SaucePreference sauce) => sauce switch
    {
        SaucePreference.Light => .25,
        SaucePreference.Extra => 1.25,
        _ => .75,
    };

    private void TestSauceOrders(DataCatalog catalog)
    {
        var evaluator = new OrderEvaluator();
        foreach ((double amount, SaucePreference expected) in new[]
        {
            (0d, SaucePreference.Light), (.4999, SaucePreference.Light),
            (.5, SaucePreference.Normal), (.75, SaucePreference.Normal), (1d, SaucePreference.Normal),
            (1.0001, SaucePreference.Extra), (1.5, SaucePreference.Extra),
        })
        {
            foreach (SaucePreference requested in Enum.GetValues<SaucePreference>())
            {
                var order = SauceTestOrder(new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Basic, 1, requested));
                var progress = new OrderProgress(order);
                Check(progress.TryAccept(new DeliveredItem(ProductKind.Pancake, StableIds.Recipes.Basic,
                    PancakeQuality.Perfect, SauceAmount: amount)).Accepted, $"{amount:P2} 可交付给{requested}订单");
                DeliveryEvaluation result = evaluator.EvaluateCompleted(progress, CustomerState.Happy, catalog.CustomersById["normal"]);
                Check(result.Grade == (requested == expected ? DeliveryGrade.Perfect : DeliveryGrade.Incorrect),
                    $"{amount:P2} 对{requested}的判定正确");
                if (requested != expected)
                    Check(result.Message.Contains("酱量不符") && result.Tip == 0 && result.SaleRevenue == 7,
                        "酱量不符沿用错配结算并说明原因");
                var prepared = new PreparedPancake(PancakeQuality.Perfect, new HashSet<string>(), SauceAmount: amount);
                Check(evaluator.Evaluate(order, CustomerState.Happy, prepared, catalog.RecipesById[StableIds.Recipes.Basic]).Grade == result.Grade,
                    "直接评价与整单评价使用相同酱量规则");
            }
        }
        Check(!SauceRules.Matches(SaucePreference.Light, -.01)
            && !SauceRules.Matches(SaucePreference.Extra, 1.51)
            && !SauceRules.Matches(SaucePreference.Extra, double.NaN), "无效酱量不能匹配订单");

        var mixed = new OrderProgress(SauceTestOrder(
            new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Basic, 1, SaucePreference.Light),
            new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Basic, 1, SaucePreference.Extra)));
        mixed.TryAccept(new DeliveredItem(ProductKind.Pancake, StableIds.Recipes.Basic, PancakeQuality.Perfect, SauceAmount: 1.25));
        Check(mixed.GetDeliveredQuantity(0) == 0 && mixed.GetDeliveredQuantity(1) == 1 && !mixed.HasRecipeMismatch,
            "同配方不同酱量优先匹配正确订单行");
        mixed.TryAccept(new DeliveredItem(ProductKind.Pancake, StableIds.Recipes.Basic, PancakeQuality.Perfect, SauceAmount: .25));
        Check(mixed.IsComplete && !mixed.HasRecipeMismatch, "反序交付不同酱量仍正确完成整单");

        DayConfig config = JsonSerializer.Deserialize<DayConfig>(JsonSerializer.Serialize(catalog.DaysByNumber[15]))!;
        var counts = new Dictionary<SaucePreference, int> { [SaucePreference.Normal] = 0, [SaucePreference.Light] = 0, [SaucePreference.Extra] = 0 };
        for (int seed = 0; seed < 1000; seed++)
        {
            config.RandomSeed = seed;
            DayPlan plan = new OrderGenerator().Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
            foreach (PlannedCustomer customer in plan.Customers)
            {
                OrderLineData? pancake = customer.Order.Lines.FirstOrDefault(line => line.ProductKind == ProductKind.Pancake);
                if (pancake is not null) counts[pancake.Sauce]++;
            }
        }
        double total = counts.Values.Sum();
        Check(Math.Abs(counts[SaucePreference.Normal] / total - .8) < .015
            && Math.Abs(counts[SaucePreference.Light] / total - .1) < .015
            && Math.Abs(counts[SaucePreference.Extra] / total - .1) < .015,
            "1000个种子的煎饼订单接近正常80%、少酱10%、多酱10%", JsonSerializer.Serialize(counts));
        Check(JsonSerializer.Serialize(Generate(catalog, 15)) == JsonSerializer.Serialize(Generate(catalog, 15)),
            "相同种子完整复现酱量订单");
    }

    private async Task TestSauceWorkstation(DataCatalog catalog)
    {
        string savePath = $"user://sauce-test-{Guid.NewGuid():N}.json";
        var save = new SaveService(); AddChild(save); save.UsePathForTests(savePath);
        var controller = new DayController(); AddChild(controller);
        var screen = ProjectCake.Core.SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(controller);
        screen.Initialize(catalog, save, controller, 15);
        screen.SetProcess(false);
        SaucePreference[] preferences = { SaucePreference.Light, SaucePreference.Normal, SaucePreference.Extra };
        for (int index = 0; index < preferences.Length; index++)
        {
            PlannedCustomer planned = controller.CurrentPlan!.Customers[index];
            planned.Order = new OrderData
            {
                OrderId = $"sauce-ui-{index}", CustomerTypeId = planned.CustomerTypeId, BasePrice = 10,
                Lines = new[] { new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Basic, 1, preferences[index]),
                    new OrderLineData(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1) },
            };
        }
        screen.BeginDay(); controller.Tick(3);
        for (int step = 0; step < 1000 && controller.CustomerQueue!.Slots.Count < 3; step++)
        {
            controller.Tick(.1);
            foreach (CustomerRuntime customer in controller.CustomerQueue.Slots) customer.WaitSeconds = 0;
        }
        controller.CustomerQueue!.Tick(controller.DayElapsedSeconds, CustomerQueue.EnterDurationSeconds, false);
        screen.RefreshForCapture(true);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        var stroke = (StrokeInteractor)station.FindChild("PancakeStrokeInput", true, false);
        var finish = (Button)station.FindChild("PancakeFinishSauceAction", true, false);
        var status = (Label)station.FindChild("PancakeStatusText", true, false);
        TextureRect[] sauceIcons = screen.FindChildren("OrderSauceIcon", "TextureRect", true, false).OfType<TextureRect>().ToArray();
        Check(sauceIcons.Length == 2 && sauceIcons.All(icon => icon.Texture is not null)
            && sauceIcons.Select(icon => icon.GetMeta("sauce").AsInt32()).Order().SequenceEqual(new[] { 1, 2 }),
            "少酱、多酱显示独立图标，正常酱不显示标记");
        Check(screen.FindChildren("OrderSauceLabel", "Label", true, false).Count == 0,
            "订单气泡不再显示酱量文字说明");

        foreach (double amount in new[] { 0d, .4375, .5, 1d, 1.0625 })
        {
            PrepareSauce();
            station.Machine.SetSauceCoverage(amount);
            int stock = station.Inventory.GetQuantity(StableIds.Ingredients.Sauce);
            Check(finish.Visible && !finish.Disabled, $"{amount:P0} 可提前收刷");
            if (amount == 1)
                Check(station.TryInvokeProductionShortcut(Key.F), "F可收刷");
            else finish.EmitSignal(Button.SignalName.Pressed);
            Check(station.Machine.Runtime.State == PancakeState.Sauced && station.Machine.Runtime.SauceCoverage == amount
                && station.Inventory.GetQuantity(StableIds.Ingredients.Sauce) == stock && stroke.IsToolHeld?.Invoke() == false,
                "收刷保留酱量、仅扣一次库存并释放光标");
            station.Machine.TryExecute(PancakeCommand.Fold);
            station.Machine.TryExecute(PancakeCommand.Bag);
            station.Tick(.3);
            Check(station.PancakeTray.Selected?.SauceAmount == amount && station.Machine.Runtime.State == PancakeState.Empty,
                "成品入盘和炉面重置不丢失酱量");
            Check(((Control)station.FindChild("FinishedPancakeDrag", true, false)).TooltipText.Contains(SauceRules.Describe(amount)),
                "成品提示包含实际酱量");
        }

        PrepareSauce();
        EllipseGeometry geometry = stroke.ResolveSpreadGeometry!();
        for (int cell = 0; cell < 24; cell++)
        {
            float radius = (cell / 8 + .5f) / 4;
            float angle = (cell % 8 + .5f) / 8 * Mathf.Tau;
            Vector2 point = geometry.Center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * geometry.Radii * radius;
            using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point }) stroke._GuiInput(press);
            using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = point }) stroke._GuiInput(release);
            if (cell is 7 or 15)
                Check(station.Machine.Runtime.State == PancakeState.Saucing
                    && station.Machine.Runtime.SauceCoverage == (cell + 1) / 16d
                    && status.Text.EndsWith("正常"), "真实刷酱达到50%或100%仍为正常且可继续操作");
        }
        Check(station.Machine.Runtime.State == PancakeState.Sauced && station.Machine.Runtime.SauceCoverage == 1.5,
            "真实刷酱可越过100%并在150%自动结束");
        station.Machine.SetSauceCoverage(2);
        Check(station.Machine.Runtime.SauceCoverage == 1.5, "酱量上限为150%");

        // Wrong sauce must not restore patience; the correct prepared amount must survive delivery.
        CustomerRuntime lightCustomer = controller.CustomerQueue.Slots.First();
        lightCustomer.WaitSeconds = 20;
        double wait = lightCustomer.WaitSeconds;
        var wrong = new PreparedPancake(PancakeQuality.Perfect, new HashSet<string>(), SauceAmount: 1.25);
        DeliveryEvaluation mismatch = controller.TryDeliverPreparedPancakeTo(lightCustomer.Id, wrong, catalog, () => true);
        Check(mismatch.ItemAccepted && lightCustomer.Progress.HasSauceMismatch && lightCustomer.WaitSeconds == wait,
            "错酱量成品可接收但不恢复耐心");
        PrepareSauce(); station.Machine.SetSauceCoverage(1.25); finish.EmitSignal(Button.SignalName.Pressed);
        station.Machine.TryExecute(PancakeCommand.Fold); station.Machine.TryExecute(PancakeCommand.Bag); station.Tick(.3);
        CustomerRuntime extraCustomer = controller.CustomerQueue.Slots[2];
        extraCustomer.WaitSeconds = 20;
        Check(station.DeliverPancakeTo(controller, extraCustomer.Id, catalog).ItemAccepted
            && extraCustomer.Progress.DeliveredItems.Single().SauceAmount == 1.25
            && !extraCustomer.Progress.HasRecipeMismatch && extraCustomer.WaitSeconds < 20 && station.PancakeTray.Count == 0,
            "多酱成品经托盘实际交付后保留125%、匹配订单并恢复耐心");

        if (OS.GetCmdlineUserArgs().Contains("--sauce-capture", StringComparer.Ordinal))
        {
            foreach (double amount in new[] { .4375, 1.25 })
            {
                PrepareSauce(); station.Machine.SetSauceCoverage(amount); screen.RefreshForCapture(true);
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                string path = $"res://.godot/sauce-{amount * 100:0}.png";
                Check(GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath(path)) == Error.Ok,
                    $"保存酱量画面 {path}");
            }
        }
        screen.Free(); controller.Free(); save.Free();
        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(savePath));

        void PrepareSauce()
        {
            station.ResetForDay();
            station.Machine.TryExecute(PancakeCommand.PlaceBatter);
            station.Machine.TryExecute(PancakeCommand.BeginSpread);
            station.Machine.TryExecute(PancakeCommand.CompleteSpread);
            station.Machine.Tick(station.Machine.Stove.SideAReadySeconds);
            station.Machine.TryExecute(PancakeCommand.Flip);
            station.Machine.TryExecute(PancakeCommand.BeginSauce);
            station.RefreshForCapture();
        }
    }

    private static OrderData SauceTestOrder(params OrderLineData[] lines) => new()
    {
        OrderId = "sauce-test", CustomerTypeId = "normal", BasePrice = 10, Lines = lines,
    };
}
