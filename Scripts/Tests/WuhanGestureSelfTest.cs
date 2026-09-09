using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

/// <summary>Production gestures dispatched through the actual viewport at both window sizes.</summary>
public partial class WuhanGestureSelfTest : Node
{
    private WuhanDayScreen _screen=null!;
    private int _passed;
    private int _pressCount;
    private WuhanWorkstationView View=>_screen.Workstation;
    private void Check(bool condition,string text) { if(!condition)throw new InvalidOperationException(text);_passed++;GD.Print("PASS "+text); }
    private void Move(Vector2 point,bool held=false) {
        Vector2 p=View.GetGlobalTransformWithCanvas()*point;
        GetViewport().PushInput(new InputEventMouseMotion{Position=p,GlobalPosition=p,ButtonMask=held?MouseButtonMask.Left:0},true);
    }
    private void Button(Vector2 point,bool pressed) {
        if (pressed) _pressCount++;
        Vector2 p=View.GetGlobalTransformWithCanvas()*point;
        GetViewport().PushInput(new InputEventMouseButton{Position=p,GlobalPosition=p,ButtonIndex=MouseButton.Left,Pressed=pressed},true);
    }
    private void Drag(Vector2 from,Vector2 to) { Move(from);Button(from,true);Move(to,true);Button(to,false); }
    private void Click(Vector2 point)=>Drag(point,point);
    private void Step(double dt) { _screen._Notification((int)NotificationApplicationFocusIn);_screen._Process(dt); }
    private async Task Frames() { for(int i=0;i<3;i++)await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame); }
    public override async void _Ready()
    {
        try {
            bool small=OS.GetCmdlineUserArgs().Contains("--capture-720");
            bool capture=OS.GetCmdlineUserArgs().Contains("--capture");
            GetWindow().Size=small?new Vector2I(1280,720):new Vector2I(1920,1080);
            var catalog=GetNode<DataCatalog>("/root/DataCatalog");
            for(int level=1;level<=3;level++) {
                var save=new SaveService();save.UsePathForTests($"res://.tmp/wuhan-gesture-{level}.json");AddChild(save);
                var city=save.Data.Wuhan;city.HighestUnlockedDay=12;
                city.EquipmentLevels["noodle_cooker"]=level;city.EquipmentLevels["ingredient_station"]=3;
                city.EquipmentLevels["doupi_griddle"]=level;city.EquipmentLevels["egg_rice_wine_station"]=1;
                var controller=new DayController();AddChild(controller);_screen=new WuhanDayScreen();AddChild(_screen);
                _screen.ConnectController(controller);_screen.Initialize(catalog,save,controller,8);_screen.SetProcess(false);_screen.BeginDay();Step(6);await Frames();
                async Task Shot(string name) {
                    if (!capture) return;
                    Step(.00001); await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                    string root=ProjectSettings.GlobalizePath($"res://.tmp/wuhan-optimization/{(small?720:1080)}/lv{level}");
                    System.IO.Directory.CreateDirectory(root); GetViewport().GetTexture().GetImage().SavePng(root+"/"+name+".png");
                }
                await Shot("01-idle");
                int noodles=_screen.Ingredients.Count(StableIds.Ingredients.WuhanNoodles);
                Drag(View.RawCenter,new Vector2(900,30));
                Check(_screen.Ingredients.Count(StableIds.Ingredients.WuhanNoodles)==noodles,"missed raw noodle drop preserves stock");
                Move(View.RawCenter);Button(View.RawCenter,true);
                GetViewport().PushInput(new InputEventKey{Pressed=true,Keycode=Key.Escape},true);Button(View.RawCenter,false);
                Check(!View.HasProductionGesture&&_screen.Ingredients.Count(StableIds.Ingredients.WuhanNoodles)==noodles,"Escape cancels production without consumption");
                Move(View.RawCenter);Button(View.RawCenter,true);_screen._Notification((int)NotificationApplicationFocusOut);
                Check(!View.HasProductionGesture,"focus loss cancels production");Step(.001);
                Drag(View.RawCenter,View.BasketRect(0).GetCenter());
                Check(_screen.Cooker.Baskets[0].State==NoodleBasketState.Cooking&&_screen.Ingredients.Count(StableIds.Ingredients.WuhanNoodles)==noodles-1,$"Lv{level} raw drag starts once");
                if(level==3) { Drag(View.RawCenter,View.BasketRect(1).GetCenter());Check(_screen.Cooker.Baskets[1].State==NoodleBasketState.Cooking,"second basket accepts independent noodle drag"); }
                Step(catalog.NoodleCookersByLevel[level].OptimalSeconds+.01);
                if(level<3) {
                    var home=View.BasketRect(0).GetCenter();Click(home);Check(_screen.Cooker.Baskets[0].State is NoodleBasketState.Ready or NoodleBasketState.Locked,"basket click cannot substitute for lifting");
                    Drag(home,home-new Vector2(0,65));Check(_screen.Cooker.Baskets[0].State==NoodleBasketState.Raised,"upward stroke raises basket");
                }
                Step(.25);
                Vector2 raised=View.BasketRect(0).GetCenter();
                Drag(raised, View.BowlCenter);
                Check(_screen.Cooker.PendingPourBasket==0&&_screen.Bowl.State==NoodleBowlState.Empty,"early drop reserves bowl and releases mouse");
                if(level==3) {
                    Drag(View.BasketRect(1).GetCenter(), View.BowlCenter);
                    Check(_screen.Cooker.PendingPourBasket==0,"second basket cannot replace reservation");
                }
                Step(.71);
                Check(_screen.Bowl.State==NoodleBowlState.Noodles&&_screen.Cooker.Baskets[0].State==NoodleBasketState.Empty,"reserved pour commits once after draining");Step(.7);
                if(level==3) { Step(1);Drag(View.BasketRect(1).GetCenter(),View.BowlCenter);Check(_screen.Cooker.Baskets[1].State==NoodleBasketState.Drained,"occupied bowl rejects second basket"); }
                Click(View.IngredientCenter(0));Step(.5);
                Click(View.IngredientCenter(1));Step(.5);
                Vector2 center=View.BowlCenter;Move(center);Button(center,true);for(int i=0;i<6;i++)Move(center+new Vector2(i%2==0?70:-70,0),true);Button(center,false);
                Check(_screen.Bowl.State==NoodleBowlState.Ready&&!_screen.DeliveryDrag.IsDragging,"mixing requires release before delivery");
                string scallion=StableIds.Ingredients.WuhanScallion;
                while(_screen.Ingredients.Count(scallion)>1)_screen.Ingredients.TryConsume(scallion);
                Click(View.IngredientCenter(1));Check(!View.Busy("refill:"+scallion),"invalid seasoning click never silently refills inventory");
                Step(.001);await Frames();
                var refill=View.GetChildren().OfType<Button>().Single(b=>b.GetMeta("ingredient_id").AsString()==scallion);
                Click(refill.Position+refill.Size/2);Check(View.Busy("refill:"+scallion),"separate refill control starts timed replenishment");Step(1.01);
                Check(_screen.Ingredients.Count(scallion)==_screen.Ingredients.Capacity(scallion)&&!refill.Visible,"full ingredient stock hides refill control");
                Drag(View.BaseCupCenter,new Vector2(1400,20));Check(_screen.Egg!.BaseCups==6,"wrong cup drop preserves base cups");
                Drag(View.BaseCupCenter,View.CupCenter);Check(_screen.Egg.IsPreparing&&_screen.Egg.BaseCups==5,"base cup at spout starts brewing once");Step(.7);
                Check(_screen.Egg.HasFinishedCup,"brewed cup becomes deliverable");await Shot("02-noodles-egg-ready");
                Click(View.PanCenter);Step(.4);Click(View.PanCenter);Step(catalog.DoupiGriddlesByLevel[level].StageSeconds/catalog.DoupiGriddlesByLevel[level].SpeedMultiplier+.01);
                if(level<3) {
                    Click(View.PanCenter);Check(_screen.Doupi!.State==DoupiState.ReadyToFlip,"pan click does not flip");
                    Drag(View.PanCenter,View.PanCenter-new Vector2(0,55));Check(_screen.Doupi.State==DoupiState.Flipped,"upward pan stroke flips skin");
                }
                else Check(_screen.Doupi!.State==DoupiState.Flipped,"upgraded griddle still flips automatically");
                Step(.5);Click(View.PanCenter);Step(catalog.DoupiGriddlesByLevel[level].SecondStageReadySeconds/catalog.DoupiGriddlesByLevel[level].SpeedMultiplier+.01);
                Click(View.PanCenter);Check(_screen.Doupi!.CompletedCuts==0,"pan click does not cut");
                Drag(View.PanCenter,View.PanCenter+new Vector2(10,0));Check(_screen.Doupi.CompletedCuts==0,"short accidental stroke does not cut");
                _screen.DoupiStock.TryAddBatch(13);
                Move(View.PanCenter-new Vector2(45,0));Button(View.PanCenter-new Vector2(45,0),true);Move(View.PanCenter+new Vector2(45,0),true);
                Check(_screen.Doupi.State==DoupiState.Cutting&&_screen.Doupi.CompletedCuts==1,"first effective stroke locks quality before release");
                await Shot("03-first-cut");Step(10);Move(View.PanCenter-new Vector2(0,45),true);
                Check(_screen.Doupi.CompletedCuts==1&&_screen.Doupi.Quality==DoupiQuality.Normal,"same press cannot cut another direction or burn");Button(View.PanCenter,false);
                Drag(View.PanCenter-new Vector2(45,0),View.PanCenter+new Vector2(45,0));
                Check(_screen.Doupi.CompletedCuts==1,"duplicate direction does not advance");
                Drag(View.PanCenter-new Vector2(0,45),View.PanCenter+new Vector2(0,45));
                Check(_screen.Doupi.State==DoupiState.Cut&&_screen.Doupi.CompletedCuts==2,"two directions finish eight pieces");Step(.4);
                Check(_screen.DoupiStock.Count==16&&_screen.Doupi.RemainingPieces==5,"three free slots receive three pieces with five left in pan");Step(.5);
                await Shot("04-partial-stock");
                Check(!_screen.Doupi.TryPourBatter(),"leftover pieces block new batch");
                _screen.DoupiStock.TryTake(2,out _);Step(.01);
                Check(_screen.DoupiStock.Count==16&&_screen.Doupi.RemainingPieces==3,"selling two automatically replenishes two");Step(.5);
                _screen.DoupiStock.TryTake(16,out _);Step(.01);Step(.5);
                Check(_screen.DoupiStock.Count==3&&_screen.Doupi.State==DoupiState.Empty,"last pieces transfer without duplication and free pan");
                Move(View.RawCenter);Button(View.RawCenter,true);controller.IsPaused=true;_screen._Process(.01);Button(View.BasketRect(0).GetCenter(),false);
                Check(!View.HasProductionGesture&&_screen.Cooker.Baskets[0].State==NoodleBasketState.Empty,"pause cancels pending production");controller.IsPaused=false;
                await AdditionalGestures(level, controller, Shot);
                if(capture) {
                    // Fill all four slots for visual review without changing production fixtures.
                    for(int i=0;i<120&&controller.CustomerQueue!.Slots.Count<4;i++)Step(.2);
                    Move(new Vector2(900,25));Step(.001);await Frames();await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                    string root=ProjectSettings.GlobalizePath($"res://.tmp/wuhan-optimization/{(small?720:1080)}");System.IO.Directory.CreateDirectory(root);
                    GetViewport().GetTexture().GetImage().SavePng(root+$"/lv{level}.png");
                }
                _screen.Free();controller.Free();save.Free();await Frames();
            }
            await OperationBudget();
            GD.Print($"WUHAN_GESTURE_TEST_RESULT passed={_passed} failed=0");GetTree().Quit();
        } catch(Exception e) {GD.PushError(e.ToString());GD.Print($"WUHAN_GESTURE_TEST_RESULT passed={_passed} failed=1");GetTree().Quit(1);}
    }
    private async Task AdditionalGestures(int level, DayController controller, Func<string,Task> shot)
    {
        var catalog=GetNode<DataCatalog>("/root/DataCatalog");
        View.CancelAnimations();_screen.Bowl.Reset();
        Drag(View.RawCenter,View.BasketRect(0).GetCenter());Step(catalog.NoodleCookersByLevel[level].OptimalSeconds+.01);
        if(level==3)Step(.25);
        Vector2 start=View.BasketRect(0).GetCenter();Move(start);Button(start,true);Move(start-new Vector2(0,50),true);
        Check(_screen.Cooker.Baskets[0].State is NoodleBasketState.Raised or NoodleBasketState.Draining,"continuous lift commits before release");
        Move(View.BowlCenter,true);Button(View.BowlCenter,false);
        Check(_screen.Cooker.PendingPourBasket==0&&!View.HasProductionGesture,"same press reaches bowl and releases mouse while waiting");
        await shot("05-pending-pour");
        foreach(string reason in new[]{"escape","pause","focus","hidden"})
        {
            double drain=_screen.Cooker.Baskets[0].DrainSeconds;
            if(reason=="escape")GetViewport().PushInput(new InputEventKey{Pressed=true,Keycode=Key.Escape},true);
            if(reason=="pause"){controller.IsPaused=true;_screen._Process(2);controller.IsPaused=false;}
            if(reason=="focus"){_screen._Notification((int)NotificationApplicationFocusOut);_screen._Process(2);_screen._Notification((int)NotificationApplicationFocusIn);}
            if(reason=="hidden"){_screen.Hide();_screen._Process(2);_screen.Show();}
            Check(_screen.Cooker.PendingPourBasket is null&&_screen.Bowl.State==NoodleBowlState.Empty,$"{reason} cancels pending bowl reservation");
            Check(_screen.Cooker.Baskets[0].DrainSeconds==drain&&_screen.Cooker.Baskets[0].Quality==NoodleQuality.Optimal,$"{reason} keeps lifted noodles and does not advance suspended processing");
            Step(.001);Drag(View.BasketRect(0).GetCenter(),View.BowlCenter);
        }
        Step(.71);Step(.7);
        Check(_screen.Bowl.State==NoodleBowlState.Noodles&&_screen.Cooker.PendingPourBasket is null,"resumed transfer completes exactly once");
        Click(View.IngredientCenter(0));Step(.5);
        int seasoning=_screen.Ingredients.Count(StableIds.Ingredients.WuhanBaseSeasoning);Click(View.IngredientCenter(0));
        Check(_screen.Ingredients.Count(StableIds.Ingredients.WuhanBaseSeasoning)==seasoning,"duplicate base seasoning does not consume stock");
        Vector2 center=View.BowlCenter;Move(center);Button(center,true);Move(center+new Vector2(60,0),true);
        double progress=_screen.Bowl.MixProgress;Move(center+new Vector2(0,150),true);Move(center,true);
        Check(View.IsMixing&&_screen.Bowl.MixProgress==progress,"outside bowl path adds no progress and preserves held session");
        Move(center+new Vector2(0,20),true);Button(center,false);
        Check(_screen.Bowl.MixProgress>progress&&!View.IsMixing,"vertical mixing advances and release keeps progress");
        Move(center);Button(center,true);
        for(int i=0;i<6;i++)Move(center+new Vector2(i%2==0?60:-60,0),true);
        Step(.001);Move(center+new Vector2(200,0),true);
        Check(_screen.Bowl.State==NoodleBowlState.Ready&&View.IsMixing&&!_screen.DeliveryDrag.IsDragging,"completed mixing remains mixing outside bowl until release");
        Button(center,false);Step(.001);
        await shot("06-mixed-ready");

        _screen.Egg!.TryTake();Step(.001);await Frames();int cups=_screen.Egg.BaseCups;
        Move(View.BaseCupCenter);Button(View.BaseCupCenter,true);Move(View.BaseCupCenter+new Vector2(15,0),true);Move(View.BaseCupCenter,true);Button(View.BaseCupCenter,false);
        Check(_screen.Egg.BaseCups==cups&&!_screen.Egg.IsPreparing,"cup drag returning to source never becomes click brew");
        Click(View.BaseCupCenter);Click(View.BaseCupCenter);
        Check(_screen.Egg.BaseCups==cups-1&&_screen.Egg.IsPreparing,"cup click brews once and duplicate click is ignored");
        await shot("07-click-brew");Step(.7);
        Click(View.BaseCupCenter);Check(_screen.Egg.BaseCups==cups-1,"occupied station cannot consume another base cup");
        _screen.Egg.TryTake();Step(.001);await Frames();
        Drag(View.BaseCupCenter,View.BrewTargetRect.Position+new Vector2(8,8));
        Check(_screen.Egg.BaseCups==cups-2&&_screen.Egg.IsPreparing,"whole brew base accepts cup drag away from spout");Step(.7);
        foreach(var button in View.GetChildren().OfType<Button>().Where(b=>b.HasMeta("ingredient_id")))
            Check(button.Size.X>=44&&button.Size.Y>=44,"refill hit target at least 44 design pixels");
        var eggRefill=View.GetChildren().OfType<Button>().Single(b=>b.GetMeta("ingredient_id").AsString()=="egg");
        Click(eggRefill.Position+eggRefill.Size/2);Click(eggRefill.Position+eggRefill.Size/2);
        Check(_screen.Egg.IsRefilling,"explicit egg refill starts once");Step(.7);
        Check(_screen.Egg.BaseCups==6&&!_screen.Egg.IsRefilling,"egg refill restores exact capacity");

        _screen.DoupiStock.TryTake(_screen.DoupiStock.Count,out _);View.CancelAnimations();
        Click(View.PanCenter);Step(.4);Click(View.PanCenter);Step(catalog.DoupiGriddlesByLevel[level].StageSeconds/catalog.DoupiGriddlesByLevel[level].SpeedMultiplier+.01);
        if(level<3)Drag(View.PanCenter,View.PanCenter-new Vector2(0,55));Step(.5);
        Click(View.PanCenter);Step(catalog.DoupiGriddlesByLevel[level].SecondStageReadySeconds/catalog.DoupiGriddlesByLevel[level].SpeedMultiplier+.01);
        Drag(View.PanCenter-new Vector2(30,30),View.PanCenter+new Vector2(30,30));
        Check(_screen.Doupi!.CompletedCuts==0,"diagonal stroke is not classified as either cut direction");
        Drag(View.PanCenter+new Vector2(0,40),View.PanCenter-new Vector2(0,140));Step(.4);
        Check(_screen.Doupi.CutDirections.SetEquals(new[]{DoupiCutDirection.Vertical}),"vertical first and fast stroke ending outside pan are accepted");
        _screen.DoupiStock.TryAddBatch(16);
        Drag(View.PanCenter+new Vector2(45,0),View.PanCenter-new Vector2(45,0));Step(.4);
        Check(_screen.Doupi.State==DoupiState.Cut&&_screen.Doupi.RemainingPieces==8,"full tray keeps entire cut batch in pan");
        _screen.Doupi.Tick(100);
        Check(_screen.Doupi.Quality==DoupiQuality.Normal,"fully cut batch does not burn while waiting for capacity");
        await shot("08-full-tray");
        _screen.DoupiStock.TryTake(16,out _);Step(.001);Step(.5);
        Check(_screen.Doupi.State==DoupiState.Empty&&_screen.DoupiStock.Count==8,"emptying tray transfers leftover batch once");
    }

    private async Task OperationBudget()
    {
        var catalog=GetNode<DataCatalog>("/root/DataCatalog");
        var save=new SaveService();save.UsePathForTests("res://.tmp/wuhan-operation-budget.json");AddChild(save);
        save.Data.Wuhan.HighestUnlockedDay=12;
        foreach(string id in new[]{"noodle_cooker","ingredient_station","doupi_griddle","egg_rice_wine_station"})save.Data.Wuhan.EquipmentLevels[id]=1;
        var controller=new DayController();AddChild(controller);_screen=new WuhanDayScreen();AddChild(_screen);
        _screen.ConnectController(controller);_screen.Initialize(catalog,save,controller,8);_screen.SetProcess(false);
        foreach(var planned in controller.CurrentPlan!.Customers)
            planned.Order=new ProjectCake.Orders.OrderData {
                OrderId=planned.Order.OrderId,CityId=StableIds.Cities.Wuhan,CustomerTypeId=planned.CustomerTypeId,BasePrice=30,PatienceSeconds=1000,
                Lines=new[]{new ProjectCake.Orders.OrderLineData(ProductKind.HotDryNoodles,StableIds.Recipes.HotDryNoodlesScallion,1),
                    new ProjectCake.Orders.OrderLineData(ProductKind.Doupi,StableIds.Products.Doupi,2),new ProjectCake.Orders.OrderLineData(ProductKind.EggRiceWine,StableIds.Products.EggRiceWine,1)} };
        _screen.BeginDay();Step(6);for(int i=0;i<120&&controller.CustomerQueue!.Slots.Count<4;i++)Step(.25);await Frames();
        Check(controller.CustomerQueue!.Slots.Count==4,"operation budget uses four fixed identical orders and level-one equipment");
        bool reduced=WuhanWorkstationView.ReducedMotion;ProjectSettings.SetSetting("accessibility/reduce_motion",true);
        void Deliver(Vector2 source,int slot) {
            var zone=(Control)_screen.FindChild($"WuhanCustomerDropZone{slot+1}",true,false);
            Vector2 target=View.GetGlobalTransformWithCanvas().AffineInverse()*(zone.GetGlobalTransformWithCanvas()*(zone.Size*.5f));
            Drag(source,target);Step(.001);
        }
        int before=_pressCount;
        Drag(View.RawCenter,View.BasketRect(0).GetCenter());Step(1.61);
        Vector2 basket=View.BasketRect(0).GetCenter();Move(basket);Button(basket,true);Move(basket-new Vector2(0,50),true);Move(View.BowlCenter,true);Button(View.BowlCenter,false);Step(.71);Step(.7);
        Click(View.IngredientCenter(0));Step(.5);Click(View.IngredientCenter(1));Step(.5);
        Vector2 bowl=View.BowlCenter;Move(bowl);Button(bowl,true);for(int i=0;i<6;i++)Move(bowl+new Vector2(i%2==0?60:-60,0),true);Button(bowl,false);Step(.001);
        Deliver(bowl,0);
        Check(_pressCount-before==6&&controller.CustomerQueue.Slots[0].Progress.GetDeliveredQuantity(0)==1,"one scallion noodle bowl including delivery needs exactly six presses");
        before=_pressCount;
        Click(View.PanCenter);Step(.4);Click(View.PanCenter);Step(2.51);Drag(View.PanCenter,View.PanCenter-new Vector2(0,55));Step(.5);
        Click(View.PanCenter);Step(3.51);Drag(View.PanCenter-new Vector2(45,0),View.PanCenter+new Vector2(45,0));Step(.4);
        Drag(View.PanCenter-new Vector2(0,45),View.PanCenter+new Vector2(0,45));Step(.4);Step(.5);
        Check(_pressCount-before==6&&_screen.DoupiStock.Count==8,"one doupi batch automatically stocks eight with exactly six presses");
        for(int i=0;i<4;i++)Deliver(View.StockCenter,i);
        Check(_pressCount-before==10&&_screen.DoupiStock.Count==0&&controller.CustomerQueue.Slots.All(c=>c.Progress.GetDeliveredQuantity(1)==2),"batch and four quantity-two deliveries total ten presses");
        before=_pressCount;Click(View.BaseCupCenter);Step(.61);Deliver(View.CupCenter,0);
        Check(_pressCount-before==2&&controller.Ledger!.Build().CompletedCustomers==1,"egg needs one click and one delivery to complete first combo");
        GD.Print("WUHAN_OPERATION_BUDGET noodles_with_one_topping=6 doupi_make_and_four_double_deliveries=10 egg=2");
        ProjectSettings.SetSetting("accessibility/reduce_motion",reduced);
        _screen.Free();controller.Free();save.Free();await Frames();
    }

}

