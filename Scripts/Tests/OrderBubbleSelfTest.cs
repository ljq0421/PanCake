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
    private readonly HashSet<ulong> _checkedIconTextures = new();
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
            Directory.CreateDirectory(ProjectSettings.GlobalizePath("res://.tmp/order-bubbles"));
            GetWindow().Position = new Vector2I(-10000, -10000);
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests("res://.tmp/order-bubbles/settings.cfg");
            settings.MarkInterfaceLessonSeen(InterfaceLessons.BusinessKey);
            settings.MarkInterfaceLessonSeen(InterfaceLessons.PendantKey);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (int width in new[] { 1920, 1280 })
            foreach (bool wuhan in new[] { false, true })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                var save = new SaveService(); AddChild(save);
                save.UsePathForTests($"res://.tmp/order-bubbles/save-{wuhan}-{width}.json");
                save.Data.PurchasedStoveLevel = 3; save.Data.PurchasedFryerLevel = 3; save.Data.PurchasedIngredientStationLevel = 3;
                save.Data.Tianjin.LearnedWorkbenchActions.UnionWith(PancakeWorkstation.AllWorkbenchActions);
                save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
                save.Data.Wuhan.EquipmentLevels["ingredient_station"] = 3;
                save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
                save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"] = 1;
                var controller = new DayController(); AddChild(controller);
                Control screen = wuhan ? ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn") : ProjectCake.Core.SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen); screen.SetProcess(false);
                if (screen is WuhanDayScreen ws) { ws.ConnectController(controller); ws.Initialize(catalog, save, controller, 12); }
                else { var ts = (TianjinDayScreen)screen; ts.ConnectController(controller); ts.Initialize(catalog, save, controller, 15); }
                OrderLineData Main(string recipe, int quantity = 1, SaucePreference sauce = SaucePreference.Normal) =>
                    new(wuhan ? ProductKind.HotDryNoodles : ProductKind.Pancake, recipe, quantity, sauce);
                OrderLineData sideA = wuhan ? new(ProductKind.EggRiceWine, "egg_rice_wine", 1) : new(ProductKind.SoyMilk, "soy_milk", 1);
                OrderLineData sideB = wuhan ? new(ProductKind.Doupi, "doupi", 2) : new(ProductKind.Youtiao, "youtiao", 2);
                string firstRecipe = wuhan ? "hot_dry_noodles_scallion_chili" : "pancake_scallion_crispy";
                string secondRecipe = wuhan ? "hot_dry_noodles_beef_chili" : "pancake_ham";
                string plainRecipe = wuhan ? "hot_dry_noodles_classic" : "pancake_basic";
                OrderLineData[][] fixtures =
                {
                    new[] { Main(firstRecipe, sauce: SaucePreference.Light), Main(secondRecipe, sauce: SaucePreference.Extra), sideB },
                    new[] { Main(secondRecipe, 2), sideA },
                    new[] { Main(plainRecipe), sideA },
                    new[] { sideA, sideB },
                    new[] { Main(plainRecipe), sideA, sideB },
                };
                int count = 5;
                // Keep these visual fixtures when Tianjin resolves live orders on arrival.
                controller.CustomerQueue!.ResolveBeforeArrival = null;
                for (int i = 0; i < count; i++)
                {
                    PlannedCustomer planned = controller.CurrentPlan!.Customers[i];
                    planned.Order = new OrderData { OrderId = $"bubble-{i}", CityId = wuhan ? "wuhan" : "tianjin",
                        CustomerTypeId = planned.CustomerTypeId, BasePrice = 50, Lines = fixtures[i] };
                }
                if (screen is WuhanDayScreen startWuhan) startWuhan.BeginDay(); else ((TianjinDayScreen)screen).BeginDay();
                if (screen is WuhanDayScreen captureWuhan) captureWuhan.TeachingFocus.Dismiss();
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
                var slotBubbles = screen.FindChildren("OrderBubble", "", true, false).OfType<OrderBubbleView>().ToArray();
                OrderBubbleView[] bubbles = controller.CustomerQueue.Slots.Select(c => slotBubbles[c.SlotIndex]).ToArray();
                Check(bubbles.Length == count, "every customer owns one visible bubble");
                foreach (OrderBubbleView bubble in bubbles)
                {
                    Rect2 visibleFrame = bubble.GetGlobalTransform() * new Rect2(0, -24, bubble.Size.X, bubble.Size.Y + 36);
                    for (Node? ancestor = bubble.GetParent(); ancestor is not null; ancestor = ancestor.GetParent())
                        if (ancestor is Control { ClipContents: true } clip)
                            Check(clip.GetGlobalRect().Grow(.5f).Encloses(visibleFrame), "ornaments and tail remain inside ancestor clipping bounds");
                    Check(bubble.FindChildren("*", "Label", true, false).OfType<Label>().All(l => System.Text.RegularExpressions.Regex.IsMatch(l.Text, @"^\d+/\d+$")), "only side quantities are visible text");
                    Check(bubble.FindChildren("*", "Control", true, false).OfType<Control>().All(c => c.MouseFilter == Control.MouseFilterEnum.Ignore), "all bubble descendants ignore pointer input");
                    var rows = bubble.FindChild("OrderRows", true, false).GetChildren().OfType<Container>().ToArray();
                    Check(rows.All(r => Math.Abs(r.Size.X - rows[0].Size.X) < .5 && Math.Abs(r.Position.X - rows[0].Position.X) < .5), "all food rows have equal width and aligned edges");
                    Check(bubble.GetGlobalRect().End.Y + 12 < (wuhan ? 625 : 575), "bubble tail stays above workbench");
                    foreach (TextureRect icon in bubble.FindChildren("*", "TextureRect", true, false).OfType<TextureRect>())
                    {
                        Check(bubble.GetGlobalRect().Grow(.5f).Encloses(icon.GetGlobalRect()),
                            $"food and sauce icons remain within the paper ({(wuhan ? "wuhan" : "tianjin")}/{width}/{icon.Name}: bubble={bubble.GetGlobalRect()}, icon={icon.GetGlobalRect()})");
                        CheckIconEdges(icon);
                        Node? row = icon.GetParent();
                        while (row is not null && row is not PanelContainer) row = row.GetParent();
                        Check(row is Control region && region.GetGlobalRect().Grow(.1f).Encloses(icon.GetGlobalRect()),
                            $"{icon.Name}: enlarged image remains inside its own product row");
                    }
                    Check(Math.Abs(bubble.Size.X - OrderBubbleView.CompactWidth) < .5 && bubble.Size.Y <= 204,
                        $"all cards use the same narrow width and three product rows fit above the customer ({wuhan}/{width}/{Array.IndexOf(bubbles, bubble)}: {bubble.Size})");
                    Check(Math.Abs(bubble.GetGlobalRect().Size.X - OrderBubbleView.CompactWidth) < .5,
                        "both cities preserve the same displayed width and icon scale");
                    foreach (Control row in Regions(bubble, "OrderSideProduct"))
                    {
                        Control product = (Control)row.FindChild("OrderProductIcon", true, false);
                        if (!row.HasMeta("shared_row"))
                            Check(Math.Abs(product.GetGlobalRect().GetCenter().X - row.GetGlobalRect().GetCenter().X) < .5,
                                "standalone side product stays centered with or without its quantity");
                        int line = row.GetMeta("line_index").AsInt32();
                        int quantity = controller.CustomerQueue.Slots[bubbles.ToList().IndexOf(bubble)].Order.Lines[line].Quantity;
                        Check(row.FindChildren("OrderQuantity", "", true, false).Count == (quantity > 1 ? 1 : 0),
                            "single sides are icon-only; repeated sides retain one quantity progress");
                        if (row.FindChild("OrderQuantity", true, false) is Label countLabel)
                        {
                            Check(row.GetGlobalRect().Encloses(countLabel.GetGlobalRect()), "quantity stays inside the row after enlarging food");
                            Check(!product.GetGlobalRect().Intersects(countLabel.GetGlobalRect()), "enlarged side product does not overlap its quantity");
                        }
                    }
                    foreach (GridContainer grid in bubble.FindChildren("OrderToppings", "", true, false).OfType<GridContainer>())
                    {
                        Check(grid.Columns is 1 or 2, "ingredients use at most two columns");
                        var icons = grid.GetChildren().OfType<Control>().ToArray();
                        Check(icons.All(icon => icon.Size.IsEqualApprox(new Vector2(36, 26))), "toppings use the approved enlarged slots");
                        Check(icons.All(icon => grid.GetGlobalRect().Grow(.5f).Encloses(icon.GetGlobalRect())), "all toppings fit within their grid");
                        Control product = grid.GetParent().GetNode<Control>("OrderProductIcon");
                        Check(!product.GetGlobalRect().Intersects(grid.GetGlobalRect()), "large product and topping columns do not overlap");
                    }
                    Check(bubble.FindChildren("OrderProductIcon", "", true, false).OfType<Control>()
                        .All(icon => icon.Size.X > 24 && icon.Size.X <= 74.1f && Math.Abs(icon.Size.Y - 54) < .1),
                        "products retain enlarged height with artwork-aware widths in shared rows");
                }
                var spatialBubbles = bubbles.OrderBy(b => b.GlobalPosition.X).ToArray();
                for (int i = 1; i < spatialBubbles.Length; i++) Check(!spatialBubbles[i-1].GetGlobalRect().Intersects(spatialBubbles[i].GetGlobalRect()), "adjacent customers' bubbles do not overlap");
                Control[] firstRows = Regions(bubbles[0], "OrderMainRow");
                Check(firstRows.Length == 2, "different recipes remain two separate portions");
                for (int i = 0; i < 2; i++)
                {
                    string[] actual = firstRows[i].FindChildren("OrderIngredientIcon*", "TextureRect", true, false).Select(n => n.GetMeta("ingredient_id").AsString()).ToArray();
                    string[] expected = wuhan
                        ? i == 0 ? new[] { "wuhan_chili_oil", "wuhan_scallion" } : new[] { "wuhan_chili_oil", "wuhan_braised_beef" }
                        : catalog.RecipesById[fixtures[0][i].DefinitionId].ExtraIngredients.ToArray();
                    Check(actual.SequenceEqual(expected), "each portion displays its own toppings in the city presentation order");
                }
                Check(Regions(bubbles[1], "OrderMainRow").Length == 2, "quantity two of same recipe expands into two rows");
                if (wuhan)
                    foreach (Control row in Regions(bubbles[1], "OrderMainRow"))
                        Check(row.FindChildren("OrderIngredientIcon*", "TextureRect", true, false)
                            .Select(n => n.GetMeta("ingredient_id").AsString()).SequenceEqual(new[] { "wuhan_chili_oil", "wuhan_braised_beef" }),
                            "both repeated portions display chili before beef");
                Check(Regions(bubbles[2], "OrderMainRow")[0].FindChildren("OrderIngredientIcon*", "", true, false).Count == 0, "plain recipe has no invented topping icons");
                Check(bubbles[2].FindChildren("OrderSauceIcon*", "", true, false).Count == 0, "normal sauce has no badge");
                Check(bubbles[0].FindChildren("OrderSauceIcon*", "", true, false).Count == (wuhan ? 0 : 2), "only Tianjin uses the light and extra sauce badges");
                Control[] sharedSides = Regions(bubbles[3], "OrderSideProduct");
                Check(sharedSides.Length == 2 && sharedSides[0].GetParent() == sharedSides[1].GetParent()
                    && !sharedSides[0].GetGlobalRect().Intersects(sharedSides[1].GetGlobalRect()),
                    "two side types share a row with independent nonoverlapping regions");
                Check(Regions(bubbles[2], "OrderMainRow")[0].GetParent() == Regions(bubbles[2], "OrderSideProduct")[0].GetParent(),
                    "a plain main and one side share a single row");
                Check(Regions(bubbles[4], "OrderSideProduct").All(side =>
                    side.GlobalPosition.Y > Regions(bubbles[4], "OrderMainRow")[0].GlobalPosition.Y)
                    && bubbles[4].FindChildren("OrderSimpleRow", "", true, false).Count == 1,
                    "three plain products use main on first row and both sides on second row");
                Check(bubbles[2].Size.Y < 100 && bubbles[3].Size.Y < 100 && bubbles[4].Size.Y < 150,
                    "sharing rows reduces card height for pairs and three-product combos");
                Vector2[] initialSizes = bubbles.Select(b => b.Size).ToArray();
                Vector2[] initialPositions = bubbles.Select(b => b.Position).ToArray();
                await Shot($"{(wuhan ? "wuhan" : "tianjin")}-{width}-initial");

                CustomerRuntime first = controller.CustomerQueue.Slots[0];
                // Deliver the second recipe first: it must not mark the first displayed row.
                Accept(first, fixtures[0][1]); Refresh(); await Frames();
                Check(!Done(firstRows[0]) && Done(firstRows[1]), "out-of-order recipe delivery marks the matching portion only");
                CustomerRuntime sidesCustomer = controller.CustomerQueue.Slots[3];
                Accept(sidesCustomer, sideA); Accept(sidesCustomer, sideB); Refresh(); await Frames();
                Control[] sideRegions = Regions(bubbles[3], "OrderSideProduct");
                Check(Done(sideRegions[0]) && !Done(sideRegions[1]), "one complete side is green while partial second side stays paper");
                Check(sideRegions[0].FindChild("OrderQuantity",true,false) is null
                    && ((Label)sideRegions[1].FindChild("OrderQuantity",true,false)).Text == "1/2", "single side remains icon-only and repeated side progress is accurate");
                CustomerRuntime repeated = controller.CustomerQueue.Slots[1];
                Accept(repeated, fixtures[1][0]); Refresh(); await Frames();
                Control[] repeatedRows = Regions(bubbles[1], "OrderMainRow");
                Check(Done(repeatedRows[0]) && !Done(repeatedRows[1]), "only one of two identical portions is green");
                Accept(controller.CustomerQueue.Slots[2], fixtures[2][0]); Refresh(); await Frames();
                Check(Done(Regions(bubbles[2], "OrderMainRow")[0]) && !Done(Regions(bubbles[2], "OrderSideProduct")[0]),
                    "delivering the main in a shared row leaves the adjacent side incomplete");
                ulong[] ids = bubbles[0].FindChildren("*","",true,false).Select(n => n.GetInstanceId()).ToArray();
                for (int i=0;i<10;i++) Refresh();
                Check(ids.SequenceEqual(bubbles[0].FindChildren("*","",true,false).Select(n=>n.GetInstanceId())), "progress refresh reuses nodes and food icons");
                Check(bubbles.Select((bubble, i) => bubble.Size.DistanceTo(initialSizes[i]) < .1f
                        && bubble.Position.DistanceTo(initialPositions[i]) < .1f).All(stable => stable),
                    "partial delivery keeps every card's size and position stable: " + string.Join("; ",
                        bubbles.Select((bubble, i) => $"{i}: {initialSizes[i]}/{initialPositions[i]} -> {bubble.Size}/{bubble.Position}")));
                await Shot($"{(wuhan ? "wuhan" : "tianjin")}-{width}-partial");
                Accept(sidesCustomer, sideB); Refresh(); await Frames();
                Check(Done(sideRegions[1]) && ((Label)sideRegions[1].FindChild("OrderQuantity",true,false)).Text == "2/2", "second side greens only at full quantity");
                screen.Free(); controller.Free(); save.Free(); await Frames();
            }
            await CheckPlainVariants(catalog);
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                await CheckXian(catalog);
            }
            GD.Print($"ORDER_BUBBLE_TEST: {_passed} passed, 0 failed"); GetTree().Quit();
        }
        catch(Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private async Task CheckPlainVariants(DataCatalog catalog)
    {
        var bubble = SceneFactory.Instantiate<OrderBubbleView>("res://Scenes/UI/OrderBubbleView.tscn");
        AddChild(bubble); bubble.ConfigureTianjinPaper();
        foreach (SaucePreference sauce in Enum.GetValues<SaucePreference>())
        {
            var order = new OrderData { OrderId = $"plain-{sauce}", CityId = "tianjin", CustomerTypeId = "normal", Lines = new[] {
                new OrderLineData(ProductKind.Pancake, "pancake_basic", 2, sauce),
                new OrderLineData(ProductKind.Youtiao, "youtiao", 2) } };
            var progress = new OrderProgress(order);
            bubble.Render(order, progress, catalog.RecipesById); await Frames();
            Check(bubble.FindChildren("OrderSimpleRow", "", true, false).Count == (sauce == SaucePreference.Normal ? 1 : 0),
                "only normal-sauce plain pancakes may share with a side");
            Check(bubble.FindChildren("OrderSauceIcon*", "", true, false).Count == (sauce == SaucePreference.Normal ? 0 : 2),
                "both special-sauce portions keep their visible requirement");
            Check(Regions(bubble, "OrderMainRow").Length == 2, "pairing preserves each repeated main portion");
            Check(Math.Abs(bubble.Size.X - OrderBubbleView.CompactWidth) < .5, "plain pancake plus repeated youtiao keeps fixed width");
            foreach (TextureRect icon in bubble.FindChildren("*", "TextureRect", true, false).OfType<TextureRect>()) CheckIconEdges(icon);
        }
        var sides = new OrderData { OrderId = "double-sides", CityId = "tianjin", CustomerTypeId = "normal", Lines = new[] {
            new OrderLineData(ProductKind.SoyMilk, "soy_milk", 2), new OrderLineData(ProductKind.Youtiao, "youtiao", 2) } };
        bubble.Render(sides, new OrderProgress(sides), catalog.RecipesById); await Frames();
        Check(Math.Abs(bubble.Size.X - OrderBubbleView.CompactWidth) < .5 && bubble.Size.Y < 100,
            "two repeated side types and both quantity labels fit a single narrow row");
        foreach (Control side in Regions(bubble, "OrderSideProduct"))
        {
            var icon = (TextureRect)side.FindChild("OrderProductIcon", true, false);
            var quantity = (Control)side.FindChild("OrderQuantity", true, false);
            Check(side.GetGlobalRect().Grow(.1f).Encloses(quantity.GetGlobalRect())
                && !icon.GetGlobalRect().Intersects(quantity.GetGlobalRect()), "both shared progress labels fit without overlapping food");
            CheckIconEdges(icon);
        }
        bubble.Free();
    }
    private async Task CheckXian(DataCatalog catalog)
    {
        var bubble = SceneFactory.Instantiate<OrderBubbleView>("res://Scenes/UI/OrderBubbleView.tscn");
        AddChild(bubble); bubble.ConfigureXian(new XianArtCatalog());
        bubble.Position = new Vector2(40, 40);
        foreach (var recipe in catalog.RecipesById.Values.OfType<XianRecipeData>())
        {
            string id = ProjectCake.Xian.XianRules.RecipeId(recipe.MeatPortions, recipe.HasJuice);
            var order = new OrderData { OrderId = id, CityId = "xian", CustomerTypeId = "xian_normal", Lines = new[] {
                new OrderLineData(ProductKind.Roujiamo, id, 2), new OrderLineData(ProductKind.Hulatang, "hulatang", 1) } };
            var progress = new OrderProgress(order);
            bubble.Render(order, progress, catalog.RecipesById); await Frames();
            Check(Regions(bubble, "OrderMainRow").Length == 2, "Xi'an double buns own separate rows");
            Check(Math.Abs(bubble.Size.X - 332) < .5 && bubble.FindChildren("OrderToppings", "", true, false).Count == 0,
                "Xi'an keeps its original width and horizontal ingredients");
            Check(bubble.FindChildren("OrderExtraMeat", "", true, false).Count == (recipe.MeatPortions == 2 ? 2 : 0), "Xi'an meat badges match both portions");
            Check(bubble.FindChildren("OrderJuice", "", true, false).Count == (recipe.HasJuice ? 2 : 0), "Xi'an juice badges match both portions");
            Check(bubble.Size.Y <= 200 && bubble.Size.X <= 332, "largest Xi'an combo fits customer column");
            Check(progress.TryAccept(new DeliveredItem(ProductKind.Hulatang, "hulatang")).Accepted, "soup first accepted");
            bubble.Render(order, progress, catalog.RecipesById);
            Check(Done(Regions(bubble, "OrderSideProduct")[0]) && Regions(bubble, "OrderMainRow").All(r => !Done(r)), "soup delivery leaves both buns incomplete");
            Check(progress.TryAccept(new DeliveredItem(ProductKind.Roujiamo, id, BunQuality: ProjectCake.Xian.BunQuality.Golden,
                MeatPortions: recipe.MeatPortions, HasJuice: recipe.HasJuice)).Accepted, "Xi'an completed bun accepted");
            bubble.Render(order, progress, catalog.RecipesById); await Frames();
            var rows = Regions(bubble, "OrderMainRow");
            Check(Done(rows[0]) && !Done(rows[1]), "Xi'an partial double order marks only one bun");
            Check(!progress.TryAccept(new DeliveredItem(ProductKind.Hulatang, "hulatang")).Accepted, "duplicate soup is rejected");
            bubble.RenderXianState(.85, true);
            Check(Math.Abs(bubble.Patience.Value - 85) < .01, "Xi'an patience immediately reflects restored amount");
            await Shot($"xian-{GetWindow().Size.X}-{id}-partial");
        }
        bubble.Free();
    }
    private static Control[] Regions(OrderBubbleView bubble, string name) => bubble.FindChildren(name + "*", "PanelContainer", true, false).OfType<Control>().ToArray();
    private static bool Done(Control region) => region.GetMeta("complete").AsBool();
    private void CheckIconEdges(TextureRect icon)
    {
        if (!_checkedIconTextures.Add(icon.Texture.GetInstanceId())) return;
        using Image pixels = icon.Texture.GetImage();
        Rect2I visible = pixels.GetUsedRect();
        Check(pixels.HasMipmaps(), $"{icon.Name}: small icons retain filtered outlines through mipmaps");
        float fit = Math.Min(icon.Size.X / pixels.GetWidth(), icon.Size.Y / pixels.GetHeight());
        float guard = Math.Min(Math.Min(visible.Position.X, visible.Position.Y),
            Math.Min(pixels.GetWidth() - visible.End.X, pixels.GetHeight() - visible.End.Y)) * fit;
        Check(guard >= 1.8f, $"{icon.Name}: every image edge has room for filtering and ink (guard={guard})");
    }
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
        if (name is "tianjin-1920-initial" or "wuhan-1920-initial")
        {
            Rect2I detail = name.StartsWith("tianjin") ? new(840, 85, 220, 250) : new(735, 95, 220, 250);
            using Image zoom = image.GetRegion(detail);
            zoom.Resize(660, 750, Image.Interpolation.Nearest);
            Check(zoom.SavePng(path.Replace("-initial.png", "-icon-detail.png")) == Error.Ok, "actual rendered icon detail saved");
        }
    }
}
