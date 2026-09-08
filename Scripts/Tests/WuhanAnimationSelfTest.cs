using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class WuhanAnimationSelfTest : Node
{
    private int _passed, _failed;
    private DataCatalog _catalog = null!;
    public override void _Ready()
    {
        try
        {
            _catalog = GetNode<DataCatalog>("/root/DataCatalog");
            Check(new WuhanArtCatalog().MissingRequiredAssets().Count == 0, "全部武汉必需美术可加载");
            TestTransfer(); TestClickFlow(); TestAutomatic(); TestDoupi(); TestEgg(); TestLifecycle();
        }
        catch (Exception e) { _failed++; GD.PushError(e.ToString()); }
        GD.Print($"WUHAN_ANIMATION_TEST_RESULT passed={_passed} failed={_failed}");
        GetTree().Quit(_failed == 0 ? 0 : 1);
    }

    private (WuhanDayScreen Screen, DayController Controller, SaveService Save) NewDay(int level=1, int day=8)
    {
        var save=new SaveService();save.UsePathForTests($"res://.tmp/wuhan-animation-test-{Guid.NewGuid():N}.json");AddChild(save);
        save.Data.Wuhan.HighestUnlockedDay=12;
        save.Data.Wuhan.EquipmentLevels["noodle_cooker"]=level;
        save.Data.Wuhan.EquipmentLevels["ingredient_station"]=3;
        save.Data.Wuhan.EquipmentLevels["doupi_griddle"]=level;
        save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"]=1;
        var controller=new DayController();AddChild(controller);
        var screen=new WuhanDayScreen();AddChild(screen);screen.ConnectController(controller);screen.Initialize(_catalog,save,controller,day);
        screen.SetProcess(false);screen.BeginDay();screen._Process(3.1);
        return (screen,controller,save);
    }
    private void DisposeDay((WuhanDayScreen Screen,DayController Controller,SaveService Save) f)
    { f.Screen.Free();f.Controller.Free();f.Save.Free(); }
    private static void Click(WuhanWorkstationView view,Vector2 p) => view._GuiInput(new InputEventMouseButton { ButtonIndex=MouseButton.Left,Pressed=true,Position=p });
    private static void Move(WuhanWorkstationView view,Vector2 p) => view._GuiInput(new InputEventMouseMotion { ButtonMask=MouseButtonMask.Left,Position=p });

    private void TestTransfer()
    {
        var cooker=new NoodleCookerStateMachine(_catalog.NoodleCookersByLevel[3]);var bowl=new HotDryNoodlesStateMachine();
        cooker.TryStart(0);cooker.TryStart(1);cooker.Tick(1.3);cooker.Tick(.8);
        bowl.TryAddNoodles(NoodleQuality.Soft);
        Check(!cooker.TryTransferTo(0,bowl)&&cooker.Baskets[0].State==NoodleBasketState.Drained&&bowl.Quality==NoodleQuality.Soft,"碗满倒面不丢失源面条及碗内品质");
        bowl.Reset();Check(cooker.TryTransferTo(0,bowl)&&cooker.Baskets[0].State==NoodleBasketState.Empty,"空碗原子接收熟面");
        Check(!cooker.TryTransferTo(1,bowl)&&cooker.Baskets[1].State==NoodleBasketState.Drained,"双漏勺争用同一个碗只成功一次");
        var burnt=new NoodleCookerStateMachine(_catalog.NoodleCookersByLevel[1]);burnt.TryStart(0);burnt.Tick(5);burnt.TryRaise(0);burnt.TryQuickDrain(0);burnt.TryTake(0,out _);burnt.TryStart(0);
        Check(burnt.Baskets[0].Quality==NoodleQuality.Optimal,"新一份面条清除上一份过熟品质");
    }
    private void TestClickFlow()
    {
        var f=NewDay();var s=f.Screen;var v=s.Workstation;
        int stock=s.Ingredients.Count(StableIds.Ingredients.WuhanNoodles);
        Click(v,v.BasketRect(0).GetCenter());s.BasketAction(0);
        Check(s.Ingredients.Count(StableIds.Ingredients.WuhanNoodles)==stock-1&&v.Busy("basket0"),"实物和按钮共用下面动作，连点只扣一份");
        s._Process(.12);Check(v.MotionProgress("basket0")>.1f&&v.MotionProgress("basket0")<1,"下面动画存在可捕获的中间帧");
        s._Process(1.5);s.BasketAction(0);s._Process(.25);s.BasketAction(0);
        Check(s.Cooker.Baskets[0].State==NoodleBasketState.Drained&&v.Busy("basket0"),"手动提篮、快速抖水均有动作锁");
        s._Process(.25);s.BasketAction(0);
        int seasoning=s.Ingredients.Count(StableIds.Ingredients.WuhanBaseSeasoning);s.IngredientAction(StableIds.Ingredients.WuhanBaseSeasoning);
        Check(v.Busy("basket0")&&v.Busy("bowl")&&s.Bowl.State==NoodleBowlState.Noodles&&s.Ingredients.Count(StableIds.Ingredients.WuhanBaseSeasoning)==seasoning,"倒面同时锁住漏勺和碗，期间不能提前加料");
        s.EggAction();Check(s.Egg!.IsPreparing,"倒面不阻塞其他工位");
        s._Process(.7);Click(v,v.IngredientCenter(0));s.IngredientAction(StableIds.Ingredients.WuhanBaseSeasoning);
        Check(s.Ingredients.Count(StableIds.Ingredients.WuhanBaseSeasoning)==seasoning-1,"基础调味动画只扣一次库存");
        s._Process(.5);Click(v,v.IngredientCenter(1));s._Process(.5);
        Check(s.Bowl.Toppings.Contains(StableIds.Ingredients.WuhanScallion),"点击葱花实物加入碗内");
        Click(v,new Vector2(600,320));Move(v,v.BowlCenter+new Vector2(70,0));
        Check(s.Bowl.MixProgress==0,"碗外按下不能带入拌面手势");
        Click(v,v.BowlCenter);Move(v,v.BowlCenter+new Vector2(70,0));
        double mixed=s.Bowl.MixProgress;Move(v,new Vector2(600,320));Move(v,v.BowlCenter);
        Check(mixed>0&&s.Bowl.MixProgress==mixed&&!v.IsMixing,"离开碗口立即结束手势，重入不会连线加进度");
        Click(v,v.BowlCenter);for(int i=0;i<5;i++)Move(v,v.BowlCenter+new Vector2(i%2==0?85:-85,0));
        Check(s.Bowl.State==NoodleBowlState.Ready&&!v.IsMixing,"碗内拌匀后筷子归位");
        s.DeliverToCustomer("missing",ProductKind.HotDryNoodles);Check(s.Bowl.State==NoodleBowlState.Ready&&!v.Busy("bowl"),"无效顾客拒绝交付，食物和画面保留");
        DisposeDay(f);
    }
    private void TestAutomatic()
    {
        var f=NewDay(3);var s=f.Screen;s.BasketAction(0);s.BasketAction(1);s._Process(1.31);
        Check(s.Cooker.Baskets.All(b=>b.State==NoodleBasketState.Draining)&&s.Workstation.Busy("basket0")&&s.Workstation.Busy("basket1"),"Lv3 两个漏勺同帧自动提篮都播放动画");
        s._Process(.8);Check(s.Cooker.Baskets.All(b=>b.State==NoodleBasketState.Drained),"自然沥水结束状态同步");
        s.BasketAction(0);s._Process(.7);s.BasketAction(1);
        Check(s.Cooker.Baskets[1].State==NoodleBasketState.Drained&&!s.Workstation.Busy("basket1"),"界面碗满拒绝倒入第二勺，不播放虚假成功动作");DisposeDay(f);
        f=NewDay(2);s=f.Screen;s.BasketAction(0);s._Process(5);
        Check(s.Cooker.Baskets[0].State==NoodleBasketState.Locked&&!s.Workstation.Busy("basket0"),"Lv2 只锁熟，不误播自动提篮");DisposeDay(f);
    }
    private static void MakeDoupi(WuhanDayScreen s,bool automatic=false)
    {
        s.DoupiAction();s._Process(.4);s.DoupiAction();s._Process(2.51);
        if(!automatic)s.DoupiAction();s._Process(.5);s.DoupiAction();s._Process(3.51);
        for(int i=0;i<4;i++){s.DoupiAction();s._Process(.4);}
    }
    private void TestDoupi()
    {
        var f=NewDay();var s=f.Screen;MakeDoupi(s);
        Check(s.Doupi!.State==DoupiState.Cut&&s.Doupi.CompletedCuts==4,"豆皮实物流程完成四刀且未被动画延迟烧焦");
        s.DoupiAction();s.DoupiAction();Check(s.DoupiStock.Count==8&&s.Workstation.Busy("stock"),"豆皮入库连点不重复增加一锅");
        s._Process(.5);MakeDoupi(s);s.DoupiAction();s._Process(.5);MakeDoupi(s);s.DoupiAction();
        Check(s.DoupiStock.Count==16&&s.Doupi.State==DoupiState.Cut&&!s.Workstation.Busy("pan"),"备货满盘保留锅内成品，不播放入库动作");DisposeDay(f);
        f=NewDay(3);s=f.Screen;s.DoupiAction();s._Process(.4);s.DoupiAction();s._Process(2.1);
        Check(s.Doupi!.State==DoupiState.Flipped&&s.Workstation.Busy("pan"),"Lv3 豆皮自动翻面可见");DisposeDay(f);
        f=NewDay();s=f.Screen;s.DoupiAction();s._Process(.4);s.DoupiAction();s._Process(2.6);s._Process(2);
        Check(s.Doupi!.State==DoupiState.Burnt,"豆皮仍遵守焦糊时限");s.DoupiAction();s._Process(.4);
        Check(s.Doupi.State==DoupiState.Empty&&!s.Workstation.Busy("pan"),"丢弃焦糊豆皮后清空锅面与动画");DisposeDay(f);
    }
    private void TestEgg()
    {
        var f=NewDay();var s=f.Screen;s.EggAction();s.EggAction();
        Check(s.Egg!.BaseCups==5&&s.Egg.IsPreparing,"冲泡连点只消耗一杯底料");s._Process(.61);s.EggAction();
        Check(s.Egg.HasFinishedCup&&!s.Workstation.Busy("egg"),"点击蛋酒设备保留成品杯等待拖拽");
        s.Egg.TryTake();for(int i=0;i<5;i++){s.EggAction();s._Process(.61);s.Egg.TryTake();}
        s.EggAction();s._Process(.3);Check(s.Egg.IsRefilling&&s.Egg.BaseCups==0,"补底料等待真实计时");s._Process(.31);
        Check(s.Egg.BaseCups==6&&!s.Egg.IsRefilling,"补料结束六杯底料恢复");DisposeDay(f);
        f=NewDay(1,1);s=f.Screen;s.Bowl.TryAddNoodles(NoodleQuality.Optimal);s.Bowl.TryAddBaseSeasoning();s.Bowl.AddMixDistance(425);
        for(int i=0;i<80 && f.Controller.CustomerQueue!.Slots.Count==0;i++)s._Process(.25);
        for(int i=0;i<10;i++)s._Process(.25);
        var customer=f.Controller.CustomerQueue!.Slots[0];
        s.DeliverToCustomer(customer.Id,ProductKind.HotDryNoodles);s.DeliverToCustomer(customer.Id,ProductKind.HotDryNoodles);
        Check(s.Bowl.State==NoodleBowlState.Empty&&!s.Workstation.Busy("bowl")&&customer.Progress.IsComplete,"接受交付后清空食品，重复点击不重复交付");DisposeDay(f);
    }
    private void TestLifecycle()
    {
        var f=NewDay();var s=f.Screen;s.BasketAction(0);s._Process(.1);float progress=s.Workstation.MotionProgress("basket0");double cook=s.Cooker.Baskets[0].CookSeconds;
        f.Controller.IsPaused=true;s._Process(2);s.EggAction();
        Check(s.Workstation.MotionProgress("basket0")==progress&&s.Cooker.Baskets[0].CookSeconds==cook&&!s.Egg!.IsPreparing,"暂停冻结动作、制作和输入");
        f.Controller.IsPaused=false;s._Notification((int)NotificationApplicationFocusOut);s._Process(2);
        Check(s.Workstation.MotionProgress("basket0")==progress,"失焦冻结动画");s._Notification((int)NotificationApplicationFocusIn);s._Process(.2);
        Check(!s.Workstation.Busy("basket0"),"恢复后继续原动画");s.EggAction();s.Hide();
        Check(s.Workstation.ActiveMotionCount==0,"隐藏页面清理所有临时动作");s.Show();s.Initialize(_catalog,f.Save,f.Controller,8);
        Check(s.Cooker.Baskets[0].State==NoodleBasketState.Empty&&s.Workstation.ActiveMotionCount==0,"重新开局复位全部制作画面");DisposeDay(f);
        ProjectSettings.SetSetting("accessibility/reduce_motion",true);
        f=NewDay();s=f.Screen;s.BasketAction(0);s._Process(.13);
        Check(!s.Workstation.Busy("basket0")&&s.Cooker.Baskets[0].State==NoodleBasketState.Cooking,"减少动态模式保留正确终态");DisposeDay(f);
        ProjectSettings.SetSetting("accessibility/reduce_motion",false);
    }
    private void Check(bool condition,string name)
    { if(condition){_passed++;GD.Print("PASS "+name);}else{_failed++;GD.PushError("FAIL "+name);} }
}
