using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class OrderBubbleSelfTest : Node
{
    private int _passed;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++;
    }
    private async Task Frames(int count = 4)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    public override async void _Ready()
    {
        try
        {
            ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (int width in new[] { 1920, 1280 })
            foreach (bool wuhan in new[] { false, true })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                var save = new SaveService(); AddChild(save);
                save.UsePathForTests($"res://.tmp/order-bubbles/save-{wuhan}-{width}.json");
                save.Data.PurchasedStoveLevel = 3; save.Data.PurchasedFryerLevel = 3; save.Data.PurchasedIngredientStationLevel = 3;
                save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
                save.Data.Wuhan.EquipmentLevels["ingredient_station"] = 3;
                save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
                save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"] = 1;
                var controller = new DayController(); AddChild(controller);
                Control screen = wuhan ? new WuhanDayScreen() : new TianjinDayScreen(); AddChild(screen); screen.SetProcess(false);
                if (screen is WuhanDayScreen ws) { ws.ConnectController(controller); ws.Initialize(catalog, save, controller, 12); }
                else { var ts = (TianjinDayScreen)screen; ts.ConnectController(controller); ts.Initialize(catalog, save, controller, 15); }
                OrderLineData Main(string recipe, int quantity = 1, SaucePreference sauce = SaucePreference.Normal) =>
                    new(wuhan ? ProductKind.HotDryNoodles : ProductKind.Pancake, recipe, quantity, sauce);
                OrderLineData sideA = wuhan ? new(ProductKind.EggRiceWine, "egg_rice_wine", 1) : new(ProductKind.SoyMilk, "soy_milk", 1);
                OrderLineData sideB = wuhan ? new(ProductKind.Doupi, "doupi", 2) : new(ProductKind.Youtiao, "youtiao", 2);
                string firstRecipe = wuhan ? "hot_dry_noodles_scallion_chili" : "pancake_scallion_crispy";
                string secondRecipe = wuhan ? "hot_dry_noodles_beef" : "pancake_ham";
                string plainRecipe = wuhan ? "hot_dry_noodles_classic" : "pancake_basic";
                OrderLineData[][] fixtures =
                {
                    new[] { Main(firstRecipe, sauce: SaucePreference.Light), Main(secondRecipe, sauce: SaucePreference.Extra), sideA, sideB },
                    new[] { Main(secondRecipe, 2), sideA },
                    new[] { Main(plainRecipe) },
                    new[] { sideA, sideB },
                    new[] { Main(firstRecipe), sideA, sideB },
                };
                int count = wuhan ? 4 : 5;
                for (int i = 0; i < count; i++)
                {
                    PlannedCustomer planned = controller.CurrentPlan!.Customers[i];
                    planned.Order = new OrderData { OrderId = $"bubble-{i}", CityId = wuhan ? "wuhan" : "tianjin",
                        CustomerTypeId = planned.CustomerTypeId, BasePrice = 50, Lines = fixtures[i] };
                }
                if (screen is WuhanDayScreen startWuhan) startWuhan.BeginDay(); else ((TianjinDayScreen)screen).BeginDay();
                controller.Tick(3.1);
                for (int step = 0; step < 1200 && controller.CustomerQueue!.Slots.Count < count; step++)
                {
                    controller.Tick(.1);
                    foreach (CustomerRuntime customer in controller.CustomerQueue.Slots) customer.WaitSeconds = 0;
                }
                Check(controller.CustomerQueue!.Slots.Count == count, "fixture fills all customer slots");
                controller.CustomerQueue.Tick(controller.DayElapsedSeconds, CustomerQueue.EnterDurationSeconds, false);
                void Refresh()
                {
                    if (screen is WuhanDayScreen refreshWuhan) refreshWuhan.RefreshForCapture(); else ((TianjinDayScreen)screen).RefreshForCapture(true);
                }
                Refresh(); await Frames();
                OrderBubbleView[] bubbles = screen.FindChildren("OrderBubble", "", true, false).OfType<OrderBubbleView>().Where(b => b.IsVisibleInTree()).ToArray();
                Check(bubbles.Length == count, "every customer owns one visible bubble");
                foreach (OrderBubbleView bubble in bubbles)
                {
                    Check(bubble.FindChildren("*", "Label", true, false).OfType<Label>().All(l => System.Text.RegularExpressions.Regex.IsMatch(l.Text, @"^\d+/\d+$")), "only side quantities are visible text");
                    Check(bubble.FindChildren("*", "Control", true, false).OfType<Control>().All(c => c.MouseFilter == Control.MouseFilterEnum.Ignore), "all bubble descendants ignore pointer input");
                    var rows = bubble.FindChild("OrderRows", true, false).GetChildren().OfType<Container>().ToArray();
                    Check(rows.All(r => Math.Abs(r.Size.X - rows[0].Size.X) < .5 && Math.Abs(r.Position.X - rows[0].Position.X) < .5), "all food rows have equal width and aligned edges");
                    Check(bubble.GetGlobalRect().End.Y + 12 < (wuhan ? 625 : 575), "bubble tail stays above workbench");
                    foreach (Control icon in bubble.FindChildren("*", "TextureRect", true, false).OfType<Control>())
                        Check(bubble.GetGlobalRect().Grow(.5f).Encloses(icon.GetGlobalRect()), "food and sauce icons remain within the paper");
                    Check(bubble.Size.X <= (wuhan ? 365 : 332) && bubble.Size.Y <= 196, "largest order remains inside customer column budget");
                }
                for (int i = 1; i < bubbles.Length; i++) Check(!bubbles[i-1].GetGlobalRect().Intersects(bubbles[i].GetGlobalRect()), "adjacent customers' bubbles do not overlap");
                Control[] firstRows = Regions(bubbles[0], "OrderMainRow");
                Check(firstRows.Length == 2, "different recipes remain two separate portions");
                for (int i = 0; i < 2; i++)
                {
                    string[] actual = firstRows[i].FindChildren("OrderIngredientIcon*", "TextureRect", true, false).Select(n => n.GetMeta("ingredient_id").AsString()).ToArray();
                    Check(actual.SequenceEqual(catalog.RecipesById[fixtures[0][i].DefinitionId].ExtraIngredients), "each portion has exactly its own topping icons");
                }
                Check(Regions(bubbles[1], "OrderMainRow").Length == 2, "quantity two of same recipe expands into two rows");
                Check(Regions(bubbles[2], "OrderMainRow")[0].FindChildren("OrderIngredientIcon*", "", true, false).Count == 0, "plain recipe has no invented topping icons");
                Check(bubbles[2].FindChildren("OrderSauceIcon*", "", true, false).Count == 0, "normal sauce has no badge");
                Check(bubbles[0].FindChildren("OrderSauceIcon*", "", true, false).Count == (wuhan ? 0 : 2), "only Tianjin uses the light and extra sauce badges");
                Check(Regions(bubbles[0], "OrderSideProduct").Length == 2 && bubbles[0].FindChildren("OrderSideRow", "", true, false).Count == 1, "both side products share one row with two independent regions");
                await Shot($"{(wuhan ? "wuhan" : "tianjin")}-{width}-initial");

                CustomerRuntime first = controller.CustomerQueue.Slots[0];
                // Deliver the second recipe first: it must not mark the first displayed row.
                Accept(first, fixtures[0][1]); Refresh(); await Frames();
                Check(!Done(firstRows[0]) && Done(firstRows[1]), "out-of-order recipe delivery marks the matching portion only");
                Accept(first, sideA); Accept(first, sideB); Refresh(); await Frames();
                Control[] sideRegions = Regions(bubbles[0], "OrderSideProduct");
                Check(Done(sideRegions[0]) && !Done(sideRegions[1]), "one complete side is green while partial second side stays paper");
                Check(((Label)sideRegions[0].FindChild("OrderQuantity",true,false)).Text == "1/1"
                    && ((Label)sideRegions[1].FindChild("OrderQuantity",true,false)).Text == "1/2", "independent delivered fractions are accurate");
                CustomerRuntime repeated = controller.CustomerQueue.Slots[1];
                Accept(repeated, fixtures[1][0]); Refresh(); await Frames();
                Control[] repeatedRows = Regions(bubbles[1], "OrderMainRow");
                Check(Done(repeatedRows[0]) && !Done(repeatedRows[1]), "only one of two identical portions is green");
                ulong[] ids = bubbles[0].FindChildren("*","",true,false).Select(n => n.GetInstanceId()).ToArray();
                for (int i=0;i<10;i++) Refresh();
                Check(ids.SequenceEqual(bubbles[0].FindChildren("*","",true,false).Select(n=>n.GetInstanceId())), "progress refresh reuses nodes and food icons");
                await Shot($"{(wuhan ? "wuhan" : "tianjin")}-{width}-partial");
                Accept(first, sideB); Refresh(); await Frames();
                Check(Done(sideRegions[1]) && ((Label)sideRegions[1].FindChild("OrderQuantity",true,false)).Text == "2/2", "second side greens only at full quantity");
                screen.Free(); controller.Free(); save.Free(); await Frames();
            }
            GD.Print($"ORDER_BUBBLE_TEST: {_passed} passed, 0 failed"); GetTree().Quit();
        }
        catch(Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private static Control[] Regions(OrderBubbleView bubble, string name) => bubble.FindChildren(name + "*", "PanelContainer", true, false).OfType<Control>().ToArray();
    private static bool Done(Control region) => region.GetMeta("complete").AsBool();
    private void Accept(CustomerRuntime customer, OrderLineData line)
    {
        var item = new DeliveredItem(line.ProductKind, line.DefinitionId, PancakeQuality.Perfect, YoutiaoQuality.Golden,
            WuhanQuality: WuhanFoodQuality.MixedComplete, SauceAmount: line.Sauce == SaucePreference.Light ? .25 : line.Sauce == SaucePreference.Extra ? 1.25 : .75);
        Check(customer.Progress.TryAccept(item).Accepted, "fixture delivery accepted by real order progress");
    }
    private async Task Shot(string name)
    {
        if (!Capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string path = ProjectSettings.GlobalizePath($"res://.tmp/order-bubbles/{name}.png");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        using Image image = GetViewport().GetTexture().GetImage();
        Check(image.SavePng(path) == Error.Ok, "capture saved");
    }
}
