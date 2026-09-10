using Godot;
using System.Reflection;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class WuhanVisualCapture : Node
{
    public override async void _Ready()
    {
        if (OS.GetCmdlineUserArgs().Contains("--stages"))
        {
            try { await CaptureUnlockStages(); GD.Print("WUHAN_STAGES_CAPTURE_DONE"); GetTree().Quit(); }
            catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
            return;
        }
        if(OS.GetCmdlineUserArgs().Contains("--supply-hub"))
        {
            try
            {
                bool small=OS.GetCmdlineUserArgs().Contains("--capture-720");
                GetWindow().Size=small?new Vector2I(1280,720):new Vector2I(1920,1080);
                var supplyCatalog=GetNode<DataCatalog>("/root/DataCatalog");
                var supplySave=new SaveService();supplySave.UsePathForTests("res://.tmp/wuhan-supply/hub-fixture.json");AddChild(supplySave);
                supplySave.Data.Coins=1000;supplySave.Data.Wuhan.HighestUnlockedDay=12;
                supplySave.Data.Wuhan.UnlockedContentIds.Add("equipment:wuhan_ingredient_station_lv2");
                supplySave.Data.Wuhan.UnlockedContentIds.Add("equipment:wuhan_ingredient_station_lv3");
                for(int level=1;level<=3;level++)
                {
                    supplySave.Data.Wuhan.EquipmentLevels["ingredient_station"]=level;
                    var supplyHub=SceneFactory.Instantiate<WuhanHub>("res://Scenes/UI/WuhanHub.tscn");AddChild(supplyHub);supplyHub.Initialize(supplyCatalog,supplySave);
                    await Frames(3);await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                    Save($"res://.tmp/wuhan-supply/hub-{(small?720:1080)}-lv{level}.png");
                    var button=supplyHub.GetNode<Button>("%WuhanStationUpgrade");
                    if(level<3 && (!button.Visible || !supplyHub.GetGlobalRect().Encloses(button.GetGlobalRect())))
                        throw new InvalidOperationException("Supply upgrade button must fit the hub.");
                    supplyHub.QueueFree();await Frames(2);
                }
                GD.Print("WUHAN_SUPPLY_HUB_CAPTURE_DONE");GetTree().Quit();
            }
            catch(Exception e){GD.PushError(e.ToString());GetTree().Quit(1);}
            return;
        }
        if(OS.GetCmdlineUserArgs().Contains("--layout"))
        {
            try { await CaptureLayout(); GD.Print("WUHAN_LAYOUT_CAPTURE_DONE");GetTree().Quit(); }
            catch(Exception e){GD.PushError(e.ToString());GetTree().Quit(1);}
            return;
        }
        if(OS.GetCmdlineUserArgs().Contains("--animations"))
        {
            try { await CaptureAnimations(); GD.Print("WUHAN_ANIMATION_CAPTURE_DONE");GetTree().Quit(); }
            catch(Exception e){GD.PushError(e.ToString());GetTree().Quit(1);}
            return;
        }
        DataCatalog catalog=GetNode<DataCatalog>("/root/DataCatalog");
        string savePath=$"user://wuhan-capture-{Guid.NewGuid():N}.json";var save=new SaveService();AddChild(save);save.UsePathForTests(savePath);save.Data.Coins=3000;
        CityProgressData progress=save.Data.Wuhan;progress.HighestUnlockedDay=12;progress.EquipmentLevels["noodle_cooker"]=3;progress.EquipmentLevels["ingredient_station"]=3;progress.EquipmentLevels["doupi_griddle"]=3;progress.EquipmentLevels["egg_rice_wine_station"]=1;
        var hub=ProjectCake.Core.SceneFactory.Instantiate<WuhanHub>("res://Scenes/UI/WuhanHub.tscn");AddChild(hub);hub.Initialize(catalog,save);await Frames(3);Save("res://.tmp/wuhan_hub.png");hub.QueueFree();await Frames(2);
        var controller=new DayController();AddChild(controller);var day=ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");AddChild(day);day.ConnectController(controller);day.Initialize(catalog,save,controller,8);day.BeginDay();controller.Tick(3.1);controller.Tick(32);await Frames(3);Save("res://.tmp/wuhan_day8.png");
        string absolute=ProjectSettings.GlobalizePath(savePath);if(File.Exists(absolute))File.Delete(absolute);GD.Print("WUHAN_CAPTURE_DONE");GetTree().Quit();
    }
    private async Task Frames(int count){for(int i=0;i<count;i++)await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);}
    private async Task CaptureUnlockStages()
    {
        bool small = OS.GetCmdlineUserArgs().Contains("--capture-720");
        GetWindow().Size = small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080);
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        foreach (int number in new[] { 1, 3, 4, 5, 6, 7, 12 })
        {
            var save = new SaveService(); save.UsePathForTests($"res://.tmp/wuhan-stages-{Guid.NewGuid():N}.json"); AddChild(save);
            for (int previous = 1; previous < number; previous++)
                if (!save.ApplyStartUnlocks(catalog.GetDays(StableIds.Cities.Wuhan)[previous], out string error)) throw new InvalidOperationException(error);
            var controller = new DayController(); AddChild(controller);
            var day = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(day);
            day.ConnectController(controller); day.Initialize(catalog, save, controller, number); day.SetProcess(false);
            day.BeginDay(); day._Notification((int)NotificationApplicationFocusIn); day._Process(3.1);
            if ((day.Doupi is not null) != (number >= 4) || day.EggUnlocked != (number >= 6))
                throw new InvalidOperationException($"Incorrect unlock stage: {number}");
            await Frames(3); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            Save($"res://.tmp/wuhan-integrated-stages/{(small ? 720 : 1080)}/day-{number:00}.png");
            day.Free(); controller.Free(); save.Free(); await Frames(2);
        }
    }
    private void Save(string path){Directory.CreateDirectory(Path.GetDirectoryName(ProjectSettings.GlobalizePath(path))!);GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath(path));}

    private async Task CaptureLayout()
    {
        bool small=OS.GetCmdlineUserArgs().Contains("--capture-720");
        GetWindow().Size=small?new Vector2I(1280,720):new Vector2I(1920,1080);
        ProjectSettings.SetSetting("accessibility/reduce_motion",false);
        DataCatalog catalog=GetNode<DataCatalog>("/root/DataCatalog");
        string root=$"res://.tmp/wuhan-layout/{(small?"720":"1080")}";
        await Frames(3);
        for(int level=1;level<=3;level++)
        {
            var save=new SaveService();save.UsePathForTests($"res://.tmp/wuhan-capture-layout-{level}.json");AddChild(save);
            CityProgressData progress=save.Data.Wuhan;progress.HighestUnlockedDay=12;
            progress.EquipmentLevels["noodle_cooker"]=level;progress.EquipmentLevels["ingredient_station"]=3;
            progress.EquipmentLevels["doupi_griddle"]=level;progress.EquipmentLevels["egg_rice_wine_station"]=1;
            var controller=new DayController();AddChild(controller);var day=ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");AddChild(day);
            day.ConnectController(controller);day.Initialize(catalog,save,controller,8);day.SetProcess(false);
            foreach (var planned in controller.CurrentPlan!.Customers)
                planned.Order = new ProjectCake.Orders.OrderData {
                    OrderId=planned.Order.OrderId, CityId=StableIds.Cities.Wuhan, CustomerTypeId=planned.CustomerTypeId,
                    BasePrice=30, PatienceSeconds=1000,
                    Lines=new[]{new ProjectCake.Orders.OrderLineData(ProductKind.HotDryNoodles,StableIds.Recipes.HotDryNoodlesScallion,2),
                        new ProjectCake.Orders.OrderLineData(ProductKind.Doupi,StableIds.Products.Doupi,2),
                        new ProjectCake.Orders.OrderLineData(ProductKind.EggRiceWine,StableIds.Products.EggRiceWine,2)} };
            day.BeginDay();
            WuhanWorkstationView view=day.Workstation;
            void Require(bool condition,string message)
            {
                if(!condition)throw new InvalidOperationException($"Layout Lv{level} {(small?720:1080)}: {message}");
                GD.Print($"PASS layout Lv{level}: {message}");
            }
            void Step(double seconds)
            {
                day._Notification((int)NotificationApplicationFocusIn);
                while(seconds>0){double dt=Math.Min(1.0/60,seconds);day._Process(dt);seconds-=dt;}
            }
            Vector2 Point(Vector2 local)=>view.GetGlobalTransformWithCanvas()*local;
            void Move(Vector2 local,bool held=false)
            {
                Vector2 p=Point(local);
                GetViewport().PushInput(new InputEventMouseMotion{Position=p,GlobalPosition=p,ButtonMask=held?MouseButtonMask.Left:0},true);
            }
            void Button(Vector2 local,bool pressed)
            {
                Vector2 p=Point(local);
                GetViewport().PushInput(new InputEventMouseButton{ButtonIndex=MouseButton.Left,Pressed=pressed,Position=p,GlobalPosition=p},true);
            }
            void Click(Vector2 local)
            {
                Move(local);Button(local,true);Button(local,false);
            }
            async Task Shot(string name)
            {
                // Keep rendering deterministic while layout and viewport hit testing remain real.
                Move(new Vector2(-10,-10));Step(.00001);view.QueueRedraw();
                await Frames(2);await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                Save($"{root}/lv{level}/{name}.png");
            }

            Step(6);
            for (int i=0;i<300 && controller.CustomerQueue!.Slots.Count<5;i++) Step(.25);
            Require(controller.CustomerQueue!.Slots.Count==5, "five full combo orders visible");
            await Shot("01-idle");
            // Inspect thumbnail bounds without exposing presentation-only test APIs.
            const BindingFlags hidden = BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static;
            Type viewType = typeof(WuhanWorkstationView);
            Rect2 stockBounds = (Rect2)viewType.GetField("StockRect", hidden)!.GetValue(view)!;
            var art = (WuhanArtCatalog)viewType.GetField("_art", hidden)!.GetValue(view)!;
            Rect2 VisualRect(string property) => (Rect2)viewType.GetProperty(property, hidden)!.GetValue(view)!;
            Rect2 ingredientTray = (Rect2)viewType.GetMethod("IngredientRect", hidden)!.Invoke(view, new object[] { 1 })!;
            Require(ingredientTray == WuhanWorkbenchLayout.Ingredient(1) && stockBounds == WuhanWorkbenchLayout.Stock,
                "ingredient and stock anchors follow the integrated background");
            Require(VisualRect("CookerCanvas") == WuhanWorkbenchLayout.Cooker && VisualRect("PanRect") == WuhanWorkbenchLayout.Pan,
                "all equipment levels keep identical body geometry");
            Require(VisualRect("BowlRect") == WuhanWorkbenchLayout.Bowl, "bowl stays aligned with the baked-in bowl");
            var countertop = new Rect2(0, 560, 1920, 520);
            var equipment = new Dictionary<string, Rect2> {
                ["pan"] = VisualRect("PanRect"), ["bowl"] = VisualRect("BowlRect"),
                ["batter"] = VisualRect("BatterRect"), ["filling"] = VisualRect("FillingRect"),
                ["stock"] = stockBounds,
                ["raw"] = (Rect2)viewType.GetField("RawTrayRect", hidden)!.GetValue(view)!,
                ["base sauce"] = VisualRect("SauceBottleRect"),
            };
            for (int ingredient = 0; ingredient < 4; ingredient++)
                equipment[$"ingredient{ingredient}"] = (Rect2)viewType.GetMethod("IngredientRect", hidden)!.Invoke(view, new object[] { ingredient })!;
            foreach (var (name, bounds) in equipment)
            {
                Require(new Rect2(Vector2.Zero, WuhanWorkbenchLayout.DesignSize).Encloses(bounds), $"{name} fits the workbench");
                foreach (var other in equipment.Where(pair => string.CompareOrdinal(pair.Key, name) > 0))
                    Require(!bounds.Intersects(other.Value), $"{name} does not cover {other.Key}");
            }
            Rect2 eggUi = WuhanWorkbenchLayout.EggUi;
            Require(!day.CoinTray.GetNode<Control>("CoinTrayArt").Visible, "UI collection hides the physical coin tray");
            Require(day.CoinTray.GetRect() == WuhanWorkbenchLayout.CoinUi && !day.CoinTray.GetRect().Intersects(eggUi),
                "egg and collection UI are separate HUD controls");
            Require(day.CoinTray.LandingPoint.IsEqualApprox(day.CoinTray.GetGlobalRect().GetCenter()),
                "payment feedback lands on the collection button");
            Require(eggUi.End.Y < 130 && day.CoinTray.GetRect().End.Y < 130, "HUD controls clear all customer orders");
            Rect2 singleSource = (Rect2)viewType.GetMethod("Source", hidden)!.Invoke(view, new object[] { art.Texture("doupi_single") })!;
            for (int piece = 0; piece < 16; piece++)
            {
                Rect2 placement = (Rect2)viewType.GetMethod("StockItemRect", hidden)!.Invoke(view, new object[] { piece })!;
                Require(placement.Size.X <= 52.5f && placement.Size.Y <= 37.5f, $"stock piece {piece + 1} fits the enlarged serving tray");
                Require(Math.Abs(placement.Size.Aspect() - singleSource.Size.Aspect()) < .01f, "stock thumbnail keeps source aspect");
                Require(stockBounds.Encloses(placement), $"stock piece {piece + 1} remains inside tray");
            }
            for(int basket=0;basket<day.Cooker.Baskets.Count;basket++)
            {
                int before=day.Ingredients.Count(StableIds.Ingredients.WuhanNoodles);
                Move(view.RawCenter);Button(view.RawCenter,true);Move(view.BasketRect(basket).GetCenter(),true);Button(view.BasketRect(basket).GetCenter(),false);
                Require(day.Cooker.Baskets[basket].State==NoodleBasketState.Cooking&&day.Ingredients.Count(StableIds.Ingredients.WuhanNoodles)==before-1,$"viewport basket {basket+1} starts one portion");
            }
            // Legal state-machine transitions avoid replaying the long animation capture suite.
            day.Cooker.Tick(catalog.NoodleCookersByLevel[level].OptimalSeconds+.001);
            for(int basket=0;basket<day.Cooker.Baskets.Count;basket++)
            {
                day.Cooker.TryRaise(basket);
                Require(day.Cooker.TryQuickDrain(basket),$"basket {basket+1} reaches drained fixture");
            }
            view.CancelAnimations();
            Require(day.Cooker.TryTransferTo(0,day.Bowl),"noodles reach bowl fixture");
            view.PlayBasket(0,NoodleBasketState.Drained,NoodleQuality.Optimal);
            Step(.55);await Shot("02-basket-return");Step(.15);
            for(int ingredient=0;ingredient<WuhanWorkstationView.IngredientIds.Length;ingredient++)
            {
                string id=WuhanWorkstationView.IngredientIds[ingredient];
                Click(view.IngredientCenter(ingredient));
                Require((ingredient==0 ? day.Bowl.State==NoodleBowlState.Seasoned : day.Bowl.Toppings.Contains(id)) && day.Ingredients.CanUse(id),$"viewport ingredient {ingredient+1} adds one serving");
                Step(.5);
            }
            Click(view.PanCenter);Require(day.Doupi!.State==DoupiState.Batter,"viewport pan accepts batter");
            Require(day.EggUnlocked && view.CanDeliver(ProductKind.EggRiceWine), "egg UI is continuously available");
            Step(.18);await Shot("02-preparing");Step(.5);

            Vector2 center=view.BowlCenter;
            Require(view.InBowl(center+new Vector2(60,0))&&view.InBowl(center-new Vector2(60,0)),"bowl contains mixing gesture");
            Move(center);Button(center,true);
            for(int i=0;i<5;i++)Move(center+new Vector2(i%2==0?60:-60,0),true);
            Button(center,false);
            Require(day.Bowl.State==NoodleBowlState.Ready&&!view.IsMixing,"viewport bowl drag completes mixing");
            Click(view.PanCenter);Require(day.Doupi.State==DoupiState.SkinCooking,"viewport pan adds egg");
            DoupiGriddleLevelData griddle=catalog.DoupiGriddlesByLevel[level];
            day.Doupi.Tick(griddle.StageSeconds/Math.Max(.01,griddle.SpeedMultiplier)+.001);
            if(!griddle.AutoFlip)Require(day.Doupi.TryFlip(),"doupi skin flips for fixture");
            Require(day.Doupi.TryAddFilling(),"doupi filling enters fixture");
            day.Doupi.Tick(griddle.SecondStageReadySeconds/Math.Max(.01,griddle.SpeedMultiplier)+.001);
            for(int cut=0;cut<day.Doupi.RequiredCuts;cut++)Require(day.Doupi.TryCut((DoupiCutDirection)cut),$"doupi fixture cut {cut+1}");
            view.CancelAnimations();Step(2.5);
            Require(day.EggUnlocked,"finished egg cup remains visible");
            await Shot("03-ready");

            Require(day.DoupiStock.TryAddBatch(DoupiInventory.Capacity-day.DoupiStock.Count),"stock fixture fills all 16 portions");
            Step(.001); Click(view.StockCenter); day.DeliveryDrag.CancelDrag(); Require(day.DoupiStock.Count==16,"stock click without customer drop retains food");
            Click(view.CupCenter); day.DeliveryDrag.CancelDrag(); Require(day.EggUnlocked,"cup click without customer drop retains food");
            Click(view.BowlCenter); day.DeliveryDrag.CancelDrag(); Require(day.Bowl.State==NoodleBowlState.Ready,"bowl click without customer drop retains food");
            Step(2.5);await Shot("04-stock-full");
            // Fixed-count fixtures expose both rows and the second layer, including
            // the transition back to one layer after a partial delivery.
            foreach (int count in new[] { 0, 1, 7, 8, 9, 15, 16, 8 })
            {
                day.DoupiStock.TryTake(day.DoupiStock.Count, out _);
                if (count > 0) Require(day.DoupiStock.TryAddBatch(count), $"stock fixture sets {count} portions");
                await Shot($"05-stock-{count:00}");
            }
            // Dispatch from the compact tray front edge to verify the entire
            // inventory remains an accessible drag source.
            Vector2 front = view.StockCenter + new Vector2(0, 30);
            Move(front);Button(front,true);Move(front + new Vector2(0,-15),true);
            Require(day.DeliveryDrag.IsDragging, "front edge of compact stock tray starts delivery");
            day.DeliveryDrag.CancelDrag();Button(front,false);
            string raw = StableIds.Ingredients.WuhanNoodles;
            while (day.Ingredients.Count(raw) > 2) day.Ingredients.TryConsume(raw);
            await Shot("06-low-noodles");
            Button refill = view.GetChildren().OfType<Button>().Single(b=>b.HasMeta("ingredient_id"));
            Require(refill.Visible && !refill.Disabled, "two portions reveal the only refill control");
            Click(refill.Position+refill.Size/2);
            Require(view.Busy("refill:"+raw), "noodle refill starts");
            Step(.3);await Shot("07-refilling");Step(.8);
            Require(day.Ingredients.Count(raw)==day.Ingredients.Capacity(raw), "noodle refill completes");
            await Shot("08-egg-continuous-supply");
            view.PlayCupReplacement();Step(.08);await Shot("09-cup-replacement");
            Require(view.CanDeliver(ProductKind.EggRiceWine), "cup replacement never blocks delivery");
            Step(.21);
            var strip=day.GetNode<Control>("WuhanCustomerStrip");
            Require(strip.ClipContents && Math.Abs(strip.GetGlobalRect().End.Y - 560)<1, "customer crop meets counter edge without a gap");
            foreach (var customer in strip.GetChildren().OfType<Control>().Where(c=>c.Visible))
            {
                var order=customer.FindChild("OrderBubble",true,false) as Control;
                Require(order is not null && order.GetGlobalRect().End.Y<560, "complete order remains above counter crop");
            }
            foreach (string id in WuhanWorkstationView.IngredientIds)
                Require(day.Ingredients.CanUse(id), $"unlimited ingredient remains available {id}");
            var last = controller.CustomerQueue.Slots[3];
            var lastCard = strip.GetChild<Control>(3);
            var portrait = lastCard.GetChildren().OfType<CustomerPortraitView>().Single();
            var bubble = lastCard.GetChildren().OfType<OrderBubbleView>().Single();
            Rect2 portraitBefore = portrait.GetGlobalRect();
            Vector2 layerScaleBefore = portrait.BodyLayerScale;
            float orderHeightBefore = bubble.Size.Y;
            var fullOrder = last.Plan.Order;
            last.Plan.Order = new ProjectCake.Orders.OrderData
            {
                OrderId = fullOrder.OrderId, CityId = fullOrder.CityId, CustomerTypeId = fullOrder.CustomerTypeId,
                BasePrice = fullOrder.BasePrice, PatienceSeconds = fullOrder.PatienceSeconds,
                Lines = new[] { new ProjectCake.Orders.OrderLineData(ProductKind.HotDryNoodles, StableIds.Recipes.HotDryNoodlesScallion, 1) },
            };
            await Shot("10-mixed-order-heights");
            Require(bubble.Size.Y < orderHeightBefore, "single-portion order shrinks after full combo");
            Require(portrait.GetGlobalRect() == portraitBefore && portrait.BodyLayerScale == layerScaleBefore,
                "short order does not move or enlarge the customer");
            foreach (Control customer in strip.GetChildren().OfType<Control>().Where(c => c.Visible))
            {
                var person = customer.GetChildren().OfType<CustomerPortraitView>().Single();
                Require(person.Size == portrait.Size && Math.Abs(person.GetGlobalRect().End.Y - 560) < 1,
                    "all customer viewports share size and counter baseline");
            }
            last.Plan.Order = fullOrder;
            day.CoinTray.RenderRevenue(13, 1);
            await Frames(2);
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            Save($"{root}/lv{level}/11-coins-pending.png");
            Require(day.CoinTray.GetNode<Label>("CoinTrayHint").Text == "收钱 ¥13", "collection UI shows the pending amount");
            Require(day.CoinTray.TryCollect(), "relocated coin tray still collects pending money");
            Require(day.CoinTray.GetNode<Label>("CoinTrayHint").Text == "收钱", "empty collection UI retains its label");
            await Shot("12-coins-collected");
            day.Free();controller.Free();save.Free();await Frames(2);
        }
    }

    private async Task CaptureAnimations()
    {
        string[] args=OS.GetCmdlineUserArgs();bool small=args.Contains("--capture-720"),reduced=args.Contains("--reduced-motion");
        GetWindow().Size=small?new Vector2I(1280,720):new Vector2I(1920,1080);
        ProjectSettings.SetSetting("accessibility/reduce_motion",reduced);
        DataCatalog catalog=GetNode<DataCatalog>("/root/DataCatalog");
        string root=$"res://.tmp/wuhan-animations/{(small?"720":"1080")}-{(reduced?"reduced":"normal")}";
        for(int level=1;level<=3;level++)
        {
            var save=new SaveService();save.UsePathForTests($"res://.tmp/wuhan-capture-animation-{level}.json");AddChild(save);
            CityProgressData progress=save.Data.Wuhan;progress.HighestUnlockedDay=12;
            progress.EquipmentLevels["noodle_cooker"]=level;progress.EquipmentLevels["ingredient_station"]=3;
            progress.EquipmentLevels["doupi_griddle"]=level;progress.EquipmentLevels["egg_rice_wine_station"]=1;
            var controller=new DayController();AddChild(controller);var day=ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");AddChild(day);
            day.ConnectController(controller);day.Initialize(catalog,save,controller,8);day.SetProcess(false);
            foreach (var planned in controller.CurrentPlan!.Customers)
                planned.Order = new ProjectCake.Orders.OrderData {
                    OrderId=planned.Order.OrderId, CityId=StableIds.Cities.Wuhan, CustomerTypeId=planned.CustomerTypeId,
                    BasePrice=30, PatienceSeconds=1000,
                    Lines=new[]{new ProjectCake.Orders.OrderLineData(ProductKind.HotDryNoodles,StableIds.Recipes.HotDryNoodlesScallion,2),
                        new ProjectCake.Orders.OrderLineData(ProductKind.Doupi,StableIds.Products.Doupi,2),
                        new ProjectCake.Orders.OrderLineData(ProductKind.EggRiceWine,StableIds.Products.EggRiceWine,2)} };
            day.BeginDay();
            void Step(double seconds)
            {
                day._Notification((int)NotificationApplicationFocusIn);
                while(seconds>0){double dt=Math.Min(1.0/60,seconds);day._Process(dt);seconds-=dt;}
            }
            async Task Shot(string name)
            {
                Step(.00001); // Refresh labels after synchronous GUI input, without advancing the action visibly.
                day.Workstation.QueueRedraw();await Frames(2);await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                Save($"{root}/lv{level}/{name}.png");
            }
            void Click(Vector2 p,bool hold=false)
            {
                // Route through Godot's viewport, including actual z-order/hit testing.
                // This catches invisible controls intercepting clicks at either window size.
                Vector2 viewportPoint=day.Workstation.GetGlobalTransformWithCanvas()*p;
                GetViewport().PushInput(new InputEventMouseMotion{Position=viewportPoint,GlobalPosition=viewportPoint},true);
                GetViewport().PushInput(new InputEventMouseButton{ButtonIndex=MouseButton.Left,Pressed=true,Position=viewportPoint,GlobalPosition=viewportPoint},true);
                if(!hold)GetViewport().PushInput(new InputEventMouseButton{ButtonIndex=MouseButton.Left,Pressed=false,Position=viewportPoint,GlobalPosition=viewportPoint},true);
            }
            void Drag(Vector2 p)
            {
                Vector2 viewportPoint=day.Workstation.GetGlobalTransformWithCanvas()*p;
                GetViewport().PushInput(new InputEventMouseMotion{ButtonMask=MouseButtonMask.Left,Position=viewportPoint,GlobalPosition=viewportPoint},true);
            }
            async Task Deliver(ProductKind kind,string shot)
            {
                Step(.001);
                int slot=controller.CustomerQueue!.Slots.ToList().FindIndex(c=>controller.CanDeliverTo(c.Id,kind));
                if(slot<0)throw new InvalidOperationException($"Capture: no customer for {kind}");
                Vector2 source=kind==ProductKind.HotDryNoodles?day.Workstation.BowlCenter:kind==ProductKind.Doupi?day.Workstation.StockCenter:day.Workstation.CupCenter;
                Click(source,true);
                var zone=(Control)day.FindChild($"WuhanCustomerDropZone{slot+1}",true,false);
                Vector2 target=zone.GetGlobalTransformWithCanvas()*(zone.Size*.5f);
                GetViewport().PushInput(new InputEventMouseMotion{Position=target,ButtonMask=MouseButtonMask.Left},true);
                await Shot(shot);
                GetViewport().PushInput(new InputEventMouseButton{ButtonIndex=MouseButton.Left,Position=target},true);
                await ToSignal(GetTree().CreateTimer(.3),SceneTreeTimer.SignalName.Timeout);
                Step(.001);
            }
            Step(6);await Shot("01-empty");
            day.BasketAction(0);Step(.1);await Shot("02-noodles-dropping");
            if(level==3)day.BasketAction(1);
            Step(level==3?1.22:1.55);await Shot("03-cooked-or-auto-raise");
            if(level<3)day.BasketAction(0);
            Step(.12);await Shot("04-raising");Step(.14);Step(.71);await Shot("05-drained");
            Step(.18);day.BasketAction(0);Step(.30);await Shot("06-pouring-midway");Step(.14);await Shot("07-noodles-landing");Step(.25);
            if(day.Bowl.State!=NoodleBowlState.Noodles)throw new InvalidOperationException("Capture: noodles did not enter bowl");
            await Shot("08-bowl-noodles");
            foreach(int ingredient in new[]{0,2,3})
            {
                Click(day.Workstation.IngredientCenter(ingredient));Step(.21);await Shot($"09-ingredient-{ingredient}-pouring");Step(.30);
            }
            await Shot("10-seasoned");
            Vector2 center=day.Workstation.BowlCenter;Click(center,true);Drag(center+new Vector2(75,0));Drag(center+new Vector2(-60,0));
            await Shot("11-mixing-half");
            Drag(center+new Vector2(75,0));Drag(center+new Vector2(-75,0));await Shot("12-noodles-ready");
            if(day.Bowl.State!=NoodleBowlState.Ready)throw new InvalidOperationException("Capture: mixing did not complete");
            Vector2 release = day.Workstation.GetGlobalTransformWithCanvas() * center;
            GetViewport().PushInput(new InputEventMouseButton { ButtonIndex=MouseButton.Left, Pressed=false, Position=release }, true);
            await Deliver(ProductKind.HotDryNoodles,"13-noodles-delivery");
            day.DoupiAction();Step(.17);await Shot("14-batter-spreading");Step(.25);
            day.DoupiAction();Step(.17);await Shot("15-egg-spreading");Step(2.4);
            if(level<3)day.DoupiAction();Step(.18);await Shot("16-flipping");Step(.35);
            day.DoupiAction();Step(.17);await Shot("17-filling");Step(3.4);await Shot("18-doupi-cooked");
            for(int cut=1;cut<=2;cut++)
            {day.CutDoupi((DoupiCutDirection)(cut-1));Step(.15);await Shot($"19-cut-{cut}");Step(.24);}
            day.DoupiAction();Step(.20);await Shot("20-stocking");Step(.3);await Shot("21-stocked-eight");
            if(day.DoupiStock.Count!=8)throw new InvalidOperationException("Capture: doupi batch was not stocked");
            await Deliver(ProductKind.Doupi,"22-doupi-delivery");
            await Shot("23-egg-stock");await Shot("24-egg-finished");
            if(!day.EggUnlocked)throw new InvalidOperationException("Capture: egg cup not prepared");
            await Deliver(ProductKind.EggRiceWine,"25-egg-delivery");
            day.Workstation.PlayCupReplacement();Step(.08);await Shot("26-cup-replacement");Step(.2);
            while(day.Ingredients.TryConsume(StableIds.Ingredients.WuhanNoodles)){}
            var refillButton=day.Workstation.GetNode<Button>("RefillNoodles");
            Step(.001);Click(refillButton.Position+refillButton.Size/2);Step(.3);await Shot("27-noodles-refilling");Step(.8);
            day.BasketAction(0);Step(.1);controller.IsPaused=true;day._Process(1);await Shot("28-paused");controller.IsPaused=false;
            day.Workstation.CancelAnimations();day.Cooker.Tick(5);
            if(level==1){day.Workstation.Tick(.01);await Shot("29-overcooked");}
            await Shot("30-final-workbench");
            day.Free();controller.Free();save.Free();await Frames(2);
        }
    }
}
