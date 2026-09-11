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
    private void SpreadHeld()
    {
        for (int row = 0; row < 3; row++)
        {
            float y = .15f + row * .35f;
            Move(View.PanPoint(row % 2 == 0 ? .02f : .98f, y), true);
            Move(View.PanPoint(row % 2 == 0 ? .98f : .02f, y), true);
        }
    }
    private void FillDoupi()
    {
        Move(View.FillingCenter); Button(View.FillingCenter, true);
        Move(View.PanPoint(.02f,.15f), true); SpreadHeld();
        Button(View.PanPoint(.98f,.85f), false);
        Check(_screen.Doupi!.State == DoupiState.SecondCooking, "one continuous filling gesture starts second cooking");
    }
    private void PrepareDoupi(int level)
    {
        var data = GetNode<DataCatalog>("/root/DataCatalog").DoupiGriddlesByLevel[level];
        Drag(View.BatterCenter, View.PanCenter); Step(.4); Click(View.DoupiEggCenter);
        Step(data.StageSeconds / data.SpeedMultiplier + .01);
        if (level < 3) Drag(View.PanCenter, View.PanCenter - new Vector2(0,55));
        Step(.5); FillDoupi(); Step(data.SecondStageReadySeconds / data.SpeedMultiplier + .01);
    }
    private void Cut(DoupiCutLine line, bool reverse = false)
    {
        bool horizontal = line == DoupiCutLine.Horizontal;
        float position = DoupiInteraction.Position(line);
        Vector2 a = horizontal ? View.PanPoint(.05f,position) : View.PanPoint(position,.05f);
        Vector2 b = horizontal ? View.PanPoint(.95f,position) : View.PanPoint(position,.95f);
        Drag(reverse ? b : a, reverse ? a : b);
    }
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
                var controller=new DayController();AddChild(controller);_screen=ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");AddChild(_screen);
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
                Check(_screen.Cooker.Baskets[0].State==NoodleBasketState.Cooking&&_screen.Ingredients.Count(StableIds.Ingredients.WuhanNoodles)==noodles,$"Lv{level} raw drag starts once");
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
                Check(_screen.Bowl.State == NoodleBowlState.Seasoned, "sesame bowl seasons through viewport input");
                Click(View.IngredientCenter(0));
                Check(_screen.Bowl.State == NoodleBowlState.Seasoned && !View.Busy("bowl"), "repeated sesame click does not repeat the action");
                Click(View.IngredientCenter(1));Step(.5);
                Vector2 center=View.BowlCenter;Move(center);Button(center,true);for(int i=0;i<6;i++)Move(center+new Vector2(i%2==0?70:-70,0),true);Button(center,false);
                Check(_screen.Bowl.State==NoodleBowlState.Ready&&!_screen.DeliveryDrag.IsDragging,"mixing requires release before delivery");
                string raw=StableIds.Ingredients.WuhanNoodles;
                for(int i=0;i<100;i++) Check(_screen.Ingredients.TryConsume(raw), "raw noodles never run out");
                Step(.001);await Frames();
                var refill=View.GetNode<Button>("RefillNoodles");
                Check(!refill.Visible && refill.Disabled, "retired refill stays hidden");
                Move(View.RawCenter);Button(View.RawCenter,true);Move(View.RawCenter+new Vector2(12,0),true);
                Check(View.HasProductionGesture,"unlimited raw noodles remain draggable");
                View.CancelInput();Button(View.RawCenter,false);
                Drag(View.CupCenter,new Vector2(1400,20));
                Check(!_screen.EggUnlocked && !_screen.DeliveryDrag.IsDragging && !View.CanDeliver(ProductKind.EggRiceWine),"retired cup area never begins delivery");
                await Shot("02-noodles-ready");
                Click(View.PanCenter); Click(View.PanCenter); Click(View.DoupiEggCenter);
                Check(_screen.Doupi!.State == DoupiState.Empty, "pan and early egg clicks cannot bypass batter drag");
                Drag(View.FillingCenter, View.PanCenter); Drag(View.BatterCenter, new Vector2(950,1000));
                Check(_screen.Doupi.State == DoupiState.Empty, "wrong ingredient and missed batter drop preserve empty pan");
                Drag(View.BatterCenter, View.PanCenter); Step(.4);
                Click(View.PanCenter); Drag(View.FillingCenter, View.PanCenter);
                Check(_screen.Doupi.State == DoupiState.Batter, "batter state requires independent egg entry");
                Click(View.DoupiEggCenter); Step(catalog.DoupiGriddlesByLevel[level].StageSeconds/catalog.DoupiGriddlesByLevel[level].SpeedMultiplier+.01);
                if(level<3) {
                    Click(View.PanCenter);Check(_screen.Doupi.State==DoupiState.ReadyToFlip,"pan click does not flip");
                    Drag(View.PanCenter,View.PanCenter-new Vector2(0,20)); Step(.17);
                    Check(_screen.Doupi.State==DoupiState.ReadyToFlip,"short flip returns without changing state");
                    Move(View.PanCenter);Button(View.PanCenter,true);Move(View.PanCenter-new Vector2(0,55),true);
                    await Shot("02a-held-flip");Button(View.PanCenter-new Vector2(0,55),false);
                    Check(_screen.Doupi.State==DoupiState.Flipped,"upward pan stroke flips skin");
                }
                else Check(_screen.Doupi.State==DoupiState.Flipped,"upgraded griddle still flips automatically");
                Step(.5);
                Move(View.FillingCenter); Button(View.FillingCenter,true);Move(View.PanPoint(.1f,.3f),true);
                Move(View.PanPoint(.35f,.3f),true);
                Check(_screen.Doupi.State==DoupiState.Spreading && _screen.Doupi.IsCovered(5,5) && !_screen.Doupi.IsCovered(28,5), "filling appears only where the pointer travelled");
                await Shot("02b-partial-filling");
                for(int j=0;j<10;j++)Move(View.PanPoint(.35f,.3f),true);
                Check(_screen.Doupi.Coverage < .5f,"stationary corner cannot fill the pan");
                Button(View.PanPoint(.35f,.3f),false);
                foreach(string reason in new[]{"escape","pause","focus","hidden"})
                {
                    Move(View.PanPoint(.35f,.3f));Button(View.PanPoint(.35f,.3f),true);
                    float coverage = _screen.Doupi.Coverage;
                    if(reason=="escape")GetViewport().PushInput(new InputEventKey{Pressed=true,Keycode=Key.Escape},true);
                    if(reason=="pause"){controller.IsPaused=true;_screen._Process(2);controller.IsPaused=false;}
                    if(reason=="focus"){_screen._Notification((int)NotificationApplicationFocusOut);_screen._Process(2);_screen._Notification((int)NotificationApplicationFocusIn);}
                    if(reason=="hidden"){_screen.Hide();_screen._Process(2);_screen.Show();}
                    Button(View.PanPoint(.35f,.3f),false);
                    Check(!View.HasProductionGesture && _screen.Doupi.Coverage == coverage && _screen.Doupi.State == DoupiState.Spreading,$"{reason} retains filling coverage and releases input");
                }
                Step(10); Check(_screen.Doupi.State==DoupiState.Spreading,"spreading has no extra burn timer");
                float existing=_screen.Doupi.Coverage;
                Drag(View.FillingCenter,new Vector2(950,1000));
                Check(_screen.Doupi.Coverage==existing,"new missed portion never resets existing filling");
                Move(View.PanPoint(.35f,.3f));Button(View.PanPoint(.35f,.3f),true);SpreadHeld();
                Step(catalog.DoupiGriddlesByLevel[level].SecondStageReadySeconds/catalog.DoupiGriddlesByLevel[level].SpeedMultiplier+.01);
                Move(View.PanPoint(.05f,.5f),true);Move(View.PanPoint(.95f,.5f),true);
                Check(_screen.Doupi.CompletedCuts==0 && View.HasProductionGesture,"completed filling press cannot become a cutting gesture");
                Button(View.PanPoint(.95f,.5f),false);
                Click(View.PanCenter);Check(_screen.Doupi.CompletedCuts==0,"pan click does not cut");
                Drag(View.PanPoint(.45f,.5f),View.PanPoint(.5f,.5f));Check(_screen.Doupi.CompletedCuts==0,"short accidental stroke does not cut");
                _screen.DoupiStock.TryAddBatch(13);
                Move(View.PanPoint(.05f,.5f));Button(View.PanPoint(.05f,.5f),true);Move(View.PanPoint(.95f,.5f),true);
                Check(_screen.Doupi.State==DoupiState.Cutting&&_screen.Doupi.CompletedCuts==1,"first effective stroke locks quality before release");
                await Shot("03-first-cut");Step(10);Move(View.PanPoint(.25f,.95f),true);
                Check(_screen.Doupi.CompletedCuts==1&&_screen.Doupi.Quality==DoupiQuality.Normal,"same press cannot cut another line or burn");Button(View.PanCenter,false);
                Cut(DoupiCutLine.Horizontal);
                Check(_screen.Doupi.CompletedCuts==1,"duplicate line does not advance");
                foreach(var line in new[]{DoupiCutLine.Right,DoupiCutLine.Left,DoupiCutLine.Center})
                { Cut(line); if(line != DoupiCutLine.Center)Step(.4); }
                Check(_screen.Doupi.State==DoupiState.Cut&&_screen.Doupi.CompletedCuts==4,"four template lines finish eight pieces");Step(.4);
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
                _screen.DoupiStock.TryTake(_screen.DoupiStock.Count,out _); View.CancelAnimations();
                int batchPresses = _pressCount;
                PrepareDoupi(level);
                foreach(var line in Enum.GetValues<DoupiCutLine>()){Cut(line);Step(.4);}Step(.5);
                Check(_pressCount-batchPresses==(level==3?7:8) && _screen.DoupiStock.Count==8,$"Lv{level} full batch uses {(level==3?7:8)} presses");
                if(capture) {
                    // Fill all four slots for visual review without changing production fixtures.
                    for(int i=0;i<120&&controller.CustomerQueue!.Slots.Count<4;i++)Step(.2);
                    Move(new Vector2(900,25));Step(.001);await Frames();await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                    string root=ProjectSettings.GlobalizePath($"res://.tmp/wuhan-optimization/{(small?720:1080)}");System.IO.Directory.CreateDirectory(root);
                    GetViewport().GetTexture().GetImage().SavePng(root+$"/lv{level}.png");
                }
                _screen.Free();controller.Free();save.Free();await Frames();
            }
            await VerifyStageSwitching();
            await OperationBudget();
            GD.Print($"WUHAN_GESTURE_TEST_RESULT passed={_passed} failed=0");GetTree().Quit();
        } catch(Exception e) {GD.PushError(e.ToString());GD.Print($"WUHAN_GESTURE_TEST_RESULT passed={_passed} failed=1");GetTree().Quit(1);}
    }
    private async Task VerifyStageSwitching()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var controller = new DayController(); AddChild(controller);
        _screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
        AddChild(_screen); _screen.ConnectController(controller); _screen.SetProcess(false);
        // Reuse the same screen in both directions, as returning to an earlier save would do.
        foreach (int day in new[] { 1, 4, 1 })
        {
            var save = new SaveService(); save.UsePathForTests($"res://.tmp/wuhan-v2-switch-{Guid.NewGuid():N}.json"); AddChild(save);
            _screen.Initialize(catalog, save, controller, day);
            foreach (var planned in controller.CurrentPlan!.Customers)
                planned.Order = new ProjectCake.Orders.OrderData {
                    OrderId = planned.Order.OrderId, CityId = StableIds.Cities.Wuhan,
                    CustomerTypeId = planned.CustomerTypeId, BasePrice = 30, PatienceSeconds = 1000,
                    Lines = new[] { new ProjectCake.Orders.OrderLineData(ProductKind.HotDryNoodles, StableIds.Recipes.HotDryNoodlesScallion, 1) } };
            _screen.BeginDay(); Step(6); await Frames();
            async Task StageShot(string name)
            {
                if (!OS.GetCmdlineUserArgs().Contains("--capture")) return;
                await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                string root = ProjectSettings.GlobalizePath($"res://.tmp/wuhan-v2-stage-motion/{GetWindow().Size.Y}");
                Directory.CreateDirectory(root);
                GetViewport().GetTexture().GetImage().SavePng($"{root}/day-{day}-{name}.png");
            }
            bool unlocked = day == 4;
            string expected = unlocked ? "武汉-热干面-豆皮-v1.png" : "武汉-热干面-v1.png";
            Check(_screen.GetNode<TextureRect>("WorkbenchBackground").Texture.ResourcePath.EndsWith(expected), $"Day {day} selects its pendant sheet");
            // Independent points on the supplied PNGs, rather than deriving all input from layout constants.
            Vector2 P(float x, float y) => new Vector2(x * 1920 / 1672, y * 1080 / 941);
            Vector2 sesame = P(497, 780);
            Vector2 scallion = P(790, 780);
            Vector2 chili = P(645, 780);
            Vector2 beef = P(944, 780);
            Check(View.HitTarget(sesame) == "ingredient0" && View.HitTarget(scallion) == "ingredient1"
                && View.HitTarget(chili) == "ingredient2" && View.HitTarget(beef) == "ingredient3", "four visible bowls map to the correct ingredients");
            Check(View.HitTarget(P(225, 782)) == "raw", "visible raw noodle tray maps to supply");
            Check(View.HitTarget(P(757, 555)) == "bowl", "visible bowl maps to mixing and delivery");
            if (unlocked)
            {
                Check(View.HitTarget(P(1540, 546)) == "doupi_egg", "upper right tray supplies eggs");
                Check(View.HitTarget(P(1555, 656)) == "batter", "lower right tray supplies batter");
                Check(View.HitTarget(P(1170, 790)) == "filling", "bamboo container supplies filling");
                Check(View.HitTarget(P(1460, 805)) == "stock", "large lower tray holds finished doupi");
                Check(View.HitTarget(P(1240, 560)) == "pan", "visible griddle surface supports gestures");
            }
            if (!unlocked)
            {
                Check(View.HitTarget(P(1300, 550)) == "" && View.HitTarget(P(1530, 800)) == "", "empty counter has no pan or stock target");
                Click(P(1300, 550)); Click(P(1530, 800));
                Check(_screen.Doupi is null && !View.HasProductionGesture && View.DoupiSupplyHint == "", "empty counter produces no doupi interaction or hint");
            }
            Drag(View.RawCenter, View.BasketRect(0).GetCenter()); Step(1.61);
            Vector2 basket = View.BasketRect(0).GetCenter(); Move(basket); Button(basket, true);
            Move(basket - new Vector2(0, 65), true); Move(View.BowlCenter, true); Button(View.BowlCenter, false);
            Step(.71); Step(.7);
            Check(_screen.Bowl.State == NoodleBowlState.Noodles, "current stage supports cooking and pouring");
            await StageShot("noodles");
            Click(sesame); Step(.5); Click(scallion); Step(.5);
            Vector2 bowl = View.BowlCenter; Move(bowl); Button(bowl, true);
            for (int i = 0; i < 6; i++) Move(bowl + new Vector2(i % 2 == 0 ? 60 : -60, 0), true);
            Button(bowl, false); Step(.001);
            Check(_screen.Bowl.State == NoodleBowlState.Ready, "current stage supports seasoning and mixing");
            await StageShot("ready");
            Vector2 rim = P(777, 477);
            Move(rim); Button(rim, true); Move(P(1400, 400), true);
            Check(_screen.DeliveryDrag.IsDragging, "visible upper bowl rim starts delivery above the counter edge");
            await StageShot("drag");
            Move(P(1630, 400), true); Button(P(1630, 400), false);
            await ToSignal(GetTree().CreateTimer(.4), SceneTreeTimer.SignalName.Timeout); Step(.001);
            Check(_screen.Bowl.State == NoodleBowlState.Ready && !_screen.DeliveryDrag.IsDragging, "missed delivery preserves finished noodles");
            var zone = (Control)_screen.FindChild("WuhanCustomerDropZone1", true, false);
            Vector2 target = View.GetGlobalTransformWithCanvas().AffineInverse() * (zone.GetGlobalTransformWithCanvas() * (zone.Size * .5f));
            Drag(bowl, target);
            await ToSignal(GetTree().CreateTimer(.4), SceneTreeTimer.SignalName.Timeout); Step(.001);
            Check(_screen.Bowl.State == NoodleBowlState.Empty && controller.Ledger!.Build().CompletedCustomers == 1, "current stage delivers a real order");
            string raw = StableIds.Ingredients.WuhanNoodles;
            Check(Enumerable.Range(0,100).All(_ => _screen.Ingredients.TryConsume(raw)), "stage switching preserves unlimited supply");
            Step(.001);
            Check(!View.GetNode<Button>("RefillNoodles").Visible, "stage switching does not restore refill");
            save.Free();
        }
        _screen.Free(); controller.Free(); await Frames();
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
        var seasoning=_screen.Bowl.State;Click(View.IngredientCenter(0));
        Check(_screen.Bowl.State==seasoning,"duplicate base seasoning does not consume stock");
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

        Step(.001);await Frames();
        Move(View.CupCenter);Button(View.CupCenter,true);Move(View.CupCenter+new Vector2(15,0),true);Move(View.CupCenter,true);Button(View.CupCenter,false);
        Check(!View.CanDeliver(ProductKind.EggRiceWine),"retired cup area does not enable delivery");
        Click(View.CupCenter);Click(View.CupCenter);
        Check(!View.CanDeliver(ProductKind.EggRiceWine),"repeated clicks do not restore retired stock");
        await shot("07-finished-stock");
        _screen.DeliveryDrag.CancelDrag();Step(.001);
        foreach(var button in View.GetChildren().OfType<Button>().Where(b=>b.HasMeta("ingredient_id")))
            Check(!button.Visible && button.Disabled,"retired refill controls are disabled and hidden");
        Check(View.GetChildren().OfType<Button>().Count(b=>b.HasMeta("ingredient_id"))==1,
            "only legacy refill node is retained for scene compatibility");

        _screen.DoupiStock.TryTake(_screen.DoupiStock.Count,out _);View.CancelAnimations();
        PrepareDoupi(level);
        Drag(View.PanPoint(.2f,.2f),View.PanPoint(.6f,.6f));
        Check(_screen.Doupi!.CompletedCuts==0,"diagonal stroke is not classified as either cut direction");
        Drag(View.PanPoint(.5f,.95f),View.PanPoint(.5f,-.4f));Step(.4);
        Check(_screen.Doupi.CutLines.SetEquals(new[]{DoupiCutLine.Center}),"vertical first and fast stroke ending outside pan are accepted");
        _screen.DoupiStock.TryAddBatch(16);
        foreach(var line in new[]{DoupiCutLine.Horizontal,DoupiCutLine.Right,DoupiCutLine.Left}){Cut(line,true);Step(.4);}
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
        var controller=new DayController();AddChild(controller);_screen=ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");AddChild(_screen);
        _screen.ConnectController(controller);_screen.Initialize(catalog,save,controller,8);_screen.SetProcess(false);
        foreach(var planned in controller.CurrentPlan!.Customers)
            planned.Order=new ProjectCake.Orders.OrderData {
                OrderId=planned.Order.OrderId,CityId=StableIds.Cities.Wuhan,CustomerTypeId=planned.CustomerTypeId,BasePrice=30,PatienceSeconds=1000,
                Lines=new[]{new ProjectCake.Orders.OrderLineData(ProductKind.HotDryNoodles,StableIds.Recipes.HotDryNoodlesScallion,1),
                    new ProjectCake.Orders.OrderLineData(ProductKind.Doupi,StableIds.Products.Doupi,2)} };
        _screen.BeginDay();Step(6);for(int i=0;i<120&&controller.CustomerQueue!.Slots.Count<4;i++)Step(.25);await Frames();
        Check(controller.CustomerQueue!.Slots.Count==4,"operation budget uses four fixed identical orders and level-one equipment");
        var budgetCustomers = controller.CustomerQueue.Slots.ToArray();
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
        PrepareDoupi(1);
        foreach(var line in Enum.GetValues<DoupiCutLine>()){Cut(line);Step(.4);}Step(.5);
        Check(_pressCount-before==8&&_screen.DoupiStock.Count==8,"one doupi batch automatically stocks eight with exactly eight presses");
        for(int i=0;i<4;i++)Deliver(View.StockCenter,i);
        // Day 8 now admits a fifth waiting customer during cooking. The measured
        // budget still covers the four original quantity-two orders only.
        Check(_pressCount-before==12&&_screen.DoupiStock.Count==0&&budgetCustomers.All(c=>c.Progress.GetDeliveredQuantity(1)==2),
            $"batch and four quantity-two deliveries total twelve presses (presses={_pressCount-before}, stock={_screen.DoupiStock.Count}, delivered={string.Join(',', controller.CustomerQueue.Slots.Select(c=>c.Progress.GetDeliveredQuantity(1)))})");
        Check(controller.Ledger!.Build().CompletedCustomers==1,"noodles and doupi complete the first combo without egg");
        GD.Print("WUHAN_OPERATION_BUDGET noodles_with_one_topping=6 doupi_make_and_four_double_deliveries=12 egg=0");
        ProjectSettings.SetSetting("accessibility/reduce_motion",reduced);
        _screen.Free();controller.Free();save.Free();await Frames();
    }

}
