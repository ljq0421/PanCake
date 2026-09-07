using Godot;
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
        if(OS.GetCmdlineUserArgs().Contains("--animations"))
        {
            try { await CaptureAnimations(); GD.Print("WUHAN_ANIMATION_CAPTURE_DONE");GetTree().Quit(); }
            catch(Exception e){GD.PushError(e.ToString());GetTree().Quit(1);}
            return;
        }
        DataCatalog catalog=GetNode<DataCatalog>("/root/DataCatalog");
        string savePath=$"user://wuhan-capture-{Guid.NewGuid():N}.json";var save=new SaveService();AddChild(save);save.UsePathForTests(savePath);save.Data.Coins=3000;
        CityProgressData progress=save.Data.Wuhan;progress.HighestUnlockedDay=12;progress.EquipmentLevels["noodle_cooker"]=3;progress.EquipmentLevels["ingredient_station"]=3;progress.EquipmentLevels["doupi_griddle"]=3;progress.EquipmentLevels["egg_rice_wine_station"]=1;
        var hub=new WuhanHub();AddChild(hub);hub.Initialize(catalog,save);await Frames(3);Save("res://.tmp/wuhan_hub.png");hub.QueueFree();await Frames(2);
        var controller=new DayController();AddChild(controller);var day=new WuhanDayScreen();AddChild(day);day.ConnectController(controller);day.Initialize(catalog,save,controller,8);day.BeginDay();controller.Tick(3.1);controller.Tick(32);await Frames(3);Save("res://.tmp/wuhan_day8.png");
        string absolute=ProjectSettings.GlobalizePath(savePath);if(File.Exists(absolute))File.Delete(absolute);GD.Print("WUHAN_CAPTURE_DONE");GetTree().Quit();
    }
    private async Task Frames(int count){for(int i=0;i<count;i++)await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);}
    private void Save(string path){Directory.CreateDirectory(Path.GetDirectoryName(ProjectSettings.GlobalizePath(path))!);GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath(path));}

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
            var controller=new DayController();AddChild(controller);var day=new WuhanDayScreen();AddChild(day);
            day.ConnectController(controller);day.Initialize(catalog,save,controller,8);day.SetProcess(false);day.BeginDay();
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
            bool SelectCustomer(ProductKind kind)
            {
                foreach(var customer in controller.CustomerQueue!.Slots)
                    if(customer.Progress.CanAccept(kind)&&controller.CustomerQueue.TrySelect(customer.Id))return true;
                return false;
            }
            Step(6);await Shot("01-empty");
            Click(day.Workstation.BasketRect(0).GetCenter());Step(.1);await Shot("02-noodles-dropping");
            if(level==3)day.BasketAction(1);
            Step(level==3?1.22:1.55);await Shot("03-cooked-or-auto-raise");
            if(level<3)day.BasketAction(0);
            Step(.12);await Shot("04-raising");Step(.14);day.BasketAction(0);Step(.10);await Shot("05-shaking");
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
            if(!SelectCustomer(ProductKind.HotDryNoodles))throw new InvalidOperationException("Capture: no noodle customer");
            day.DeliverNoodles();Step(.18);await Shot("13-noodles-delivery");Step(.4);
            day.DoupiAction();Step(.17);await Shot("14-batter-spreading");Step(.25);
            day.DoupiAction();Step(.17);await Shot("15-egg-spreading");Step(2.4);
            if(level<3)day.DoupiAction();Step(.18);await Shot("16-flipping");Step(.35);
            day.DoupiAction();Step(.17);await Shot("17-filling");Step(3.4);await Shot("18-doupi-cooked");
            for(int cut=1;cut<=4;cut++)
            {day.DoupiAction();Step(.15);await Shot($"19-cut-{cut}");Step(.24);}
            day.DoupiAction();Step(.20);await Shot("20-stocking");Step(.3);await Shot("21-stocked-eight");
            if(day.DoupiStock.Count!=8)throw new InvalidOperationException("Capture: doupi batch was not stocked");
            if(SelectCustomer(ProductKind.Doupi)){day.DeliverDoupi();Step(.18);await Shot("22-doupi-delivery");Step(.4);}
            Click(day.Workstation.CupCenter);Step(.30);await Shot("23-egg-brewing");Step(.32);await Shot("24-egg-finished");
            if(!day.Egg!.HasFinishedCup)throw new InvalidOperationException("Capture: egg cup not prepared");
            if(SelectCustomer(ProductKind.EggRiceWine)){day.EggAction();Step(.18);await Shot("25-egg-delivery");Step(.4);}
            // Exhaust isolated fixtures only, then exercise the real refill commands.
            day.Egg.TryTake();for(int i=0;i<5;i++){day.Egg.TryStart();day.Egg.Tick(.61);day.Egg.TryTake();}
            day.EggAction();Step(.25);await Shot("26-egg-refilling");Step(.4);
            while(day.Ingredients.TryConsume(StableIds.Ingredients.WuhanScallion)){}
            day.IngredientAction(StableIds.Ingredients.WuhanScallion);Step(.3);await Shot("27-ingredient-refilling");Step(.8);
            day.BasketAction(0);Step(.1);controller.IsPaused=true;day._Process(1);await Shot("28-paused");controller.IsPaused=false;
            day.Workstation.CancelAnimations();day.Cooker.Tick(5);
            if(level==1){day.Workstation.Tick(.01);await Shot("29-overcooked");}
            await Shot("30-final-workbench");
            day.Free();controller.Free();save.Free();await Frames(2);
        }
    }
}
