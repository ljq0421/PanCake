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
            TestTransfer(); TestClickFlow(); TestAutomatic(); TestDoupi(); TestEgg(); TestSupply(); TestLifecycle(); TestCookingPresentation();
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
        if (day >= 6) save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"]=1;
        var controller=new DayController();AddChild(controller);
        var screen=ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");AddChild(screen);screen.ConnectController(controller);screen.Initialize(_catalog,save,controller,day);
        screen.SetProcess(false);screen.BeginDay();screen._Process(3.1);
        return (screen,controller,save);
    }
    private void DisposeDay((WuhanDayScreen Screen,DayController Controller,SaveService Save) f)
    { f.Screen.Free();f.Controller.Free();f.Save.Free(); }
    private static void Click(WuhanWorkstationView view,Vector2 p) => view._GuiInput(new InputEventMouseButton { ButtonIndex=MouseButton.Left,Pressed=true,Position=p });
    private static void Move(WuhanWorkstationView view,Vector2 p) => view._Input(new InputEventMouseMotion { ButtonMask=MouseButtonMask.Left,Position=view.GetGlobalTransformWithCanvas()*p });

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
        Check(s.Ingredients.Count(StableIds.Ingredients.WuhanNoodles)==stock&&v.Busy("basket0"),"空漏勺点击不下面，制作提交不消耗无限供应");
        s._Process(.12);Check(v.MotionProgress("basket0")>.1f&&v.MotionProgress("basket0")<1,"下面动画存在可捕获的中间帧");
        s._Process(1.5);s.BasketAction(0);s._Process(.71);
        Check(s.Cooker.Baskets[0].State==NoodleBasketState.Drained&&!v.Busy("basket0"),"提篮后自然沥水完成");
        s._Process(.25);s.BasketAction(0);
        s.IngredientAction(StableIds.Ingredients.WuhanBaseSeasoning);
        Check(v.Busy("basket0")&&v.Busy("bowl")&&s.Bowl.State==NoodleBowlState.Noodles,"倒面同时锁住漏勺和碗，期间不能提前加料");
        Check(!s.Workstation.CanDeliver(ProductKind.EggRiceWine),"蛋酒已下架");
        s._Process(.7);Click(v,v.IngredientCenter(0));s.IngredientAction(StableIds.Ingredients.WuhanBaseSeasoning);
        Check(s.Bowl.State==NoodleBowlState.Seasoned && s.Ingredients.CanUse(StableIds.Ingredients.WuhanBaseSeasoning),"基础调味加入一次后仍持续供应");
        s._Process(.5);Click(v,v.IngredientCenter(1));s._Process(.5);
        Check(s.Bowl.Toppings.Contains(StableIds.Ingredients.WuhanScallion),"点击葱花实物加入碗内");
        Click(v,new Vector2(600,320));Move(v,v.BowlCenter+new Vector2(70,0));
        Check(s.Bowl.MixProgress==0,"碗外按下不能带入拌面手势");
        Click(v,v.BowlCenter);Move(v,v.BowlCenter+new Vector2(70,0));
        double mixed=s.Bowl.MixProgress;Move(v,new Vector2(600,320));Move(v,v.BowlCenter);
        Check(mixed>0&&s.Bowl.MixProgress==mixed&&v.IsMixing,"离开碗口保持会话，重入不会连线加进度");
        Click(v,v.BowlCenter);for(int i=0;i<5;i++)Move(v,v.BowlCenter+new Vector2(i%2==0?85:-85,0));
        Check(s.Bowl.State==NoodleBowlState.Ready&&v.IsMixing,"拌匀后保持当前输入模式直到松手");
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
        s.PourDoupiBatter();s._Process(.4);s.AddDoupiEgg();s._Process(2.51);
        if(!automatic)s.FlipDoupi();s._Process(.5);s.AddDoupiFilling();DoupiTestFixture.Spread(s.Doupi!);s._Process(3.51);
        foreach(var direction in Enum.GetValues<DoupiCutLine>()){s.CutDoupi(direction);s._Process(.4);}
    }
    private void TestDoupi()
    {
        var f=NewDay();var s=f.Screen;MakeDoupi(s);
        Check(s.Doupi!.State==DoupiState.Empty&&s.DoupiStock.Count==8,"豆皮四刀切割后自动入盘");
        s.PourDoupiBatter();s.PourDoupiBatter();Check(s.DoupiStock.Count==8&&s.Workstation.Busy("stock"),"豆皮入库连点不重复增加一锅");
        s._Process(.5);MakeDoupi(s);s.PourDoupiBatter();s._Process(.5);MakeDoupi(s);s.PourDoupiBatter();
        Check(s.DoupiStock.Count==16&&s.Doupi.State==DoupiState.Cut&&!s.Workstation.Busy("pan"),"备货满盘保留锅内成品，不播放入库动作");DisposeDay(f);
        f=NewDay(3);s=f.Screen;s.PourDoupiBatter();s._Process(.4);s.AddDoupiEgg();s._Process(2.1);
        Check(s.Doupi!.State==DoupiState.Flipped&&s.Workstation.Busy("pan"),"Lv3 豆皮自动翻面可见");DisposeDay(f);
        f=NewDay();s=f.Screen;s.PourDoupiBatter();s._Process(.4);s.AddDoupiEgg();s._Process(2.6);s._Process(2);
        Check(s.Doupi!.State==DoupiState.Burnt,"豆皮仍遵守焦糊时限");s.DiscardDoupi();s._Process(.4);
        Check(s.Doupi.State==DoupiState.Empty&&!s.Workstation.Busy("pan"),"丢弃焦糊豆皮后清空锅面与动画");DisposeDay(f);
    }
    private void TestEgg()
    {
        var f=NewDay();var s=f.Screen;
        Check(!s.EggUnlocked && !s.Workstation.CanDeliver(ProductKind.EggRiceWine), "旧存档解锁蛋酒也不可再交付");
        Check(!s.Workstation.GetNode<Control>("WuhanDrag_EggRiceWine").Visible, "旧蛋酒拖拽入口隐藏");
        DisposeDay(f);
        f=NewDay(1,1);s=f.Screen;Check(!s.EggUnlocked && !s.Workstation.CanDeliver(ProductKind.EggRiceWine), "Day 1 不可提前交付蛋酒");s.Bowl.TryAddNoodles(NoodleQuality.Optimal);s.Bowl.TryAddBaseSeasoning();s.Bowl.AddMixDistance(425);
        for(int i=0;i<80 && f.Controller.CustomerQueue!.Slots.Count==0;i++)s._Process(.25);
        for(int i=0;i<10;i++)s._Process(.25);
        var customer=f.Controller.CustomerQueue!.Slots[0];
        s.DeliverToCustomer(customer.Id,ProductKind.HotDryNoodles);s.DeliverToCustomer(customer.Id,ProductKind.HotDryNoodles);
        Check(s.Bowl.State==NoodleBowlState.Empty&&!s.Workstation.Busy("bowl")&&customer.Progress.IsComplete,"接受交付后清空食品，重复点击不重复交付");DisposeDay(f);
    }
    private void TestSupply()
    {
        foreach (int level in new[] { 1, 2, 3 })
        {
            var inventory = new WuhanIngredientInventory(_catalog.WuhanIngredientStationsByLevel[level]);
            foreach (string id in WuhanWorkstationView.IngredientIds.Append(StableIds.Ingredients.WuhanNoodles))
                Check(inventory.IsUnlimited(id) && Enumerable.Range(0, 100).All(_ => inventory.TryConsume(id)) && inventory.CanUse(id), $"Lv{level} {id} 连续使用不耗尽");
            Check(!inventory.TryConsume("unknown"), "未知原料不能使用");
        }
        var f = NewDay(3); var s = f.Screen;
        var refill = s.Workstation.GetNode<Button>("RefillNoodles");
        refill.EmitSignal(Button.SignalName.Pressed); s._Process(.3);
        Check(!refill.Visible && !s.Workstation.Busy("refill:" + StableIds.Ingredients.WuhanNoodles), "旧补货事件不会创建补货动作");
        for (int i = 0; i < 30; i++)
        {
            s.BasketAction(0); s.BasketAction(0);
            Check(s.Cooker.Baskets[0].State == NoodleBasketState.Cooking, "超过旧容量仍可下锅，重复操作不重置烹煮");
            s._Process(1.31); s._Process(.8); s.BasketAction(0); s._Process(.7); s.Bowl.Reset();
        }
        DisposeDay(f);
    }
    private void TestLifecycle()
    {
        var f=NewDay();var s=f.Screen;s.BasketAction(0);s._Process(.1);float progress=s.Workstation.MotionProgress("basket0");double cook=s.Cooker.Baskets[0].CookSeconds;
        f.Controller.IsPaused=true;s._Process(2);
        Check(s.Workstation.MotionProgress("basket0")==progress&&s.Cooker.Baskets[0].CookSeconds==cook&&!s.Workstation.CanDeliver(ProductKind.EggRiceWine),"暂停冻结动作、制作和输入");
        f.Controller.IsPaused=false;s._Notification((int)NotificationApplicationFocusOut);s._Process(2);
        Check(s.Workstation.MotionProgress("basket0")==progress,"失焦冻结动画");s._Notification((int)NotificationApplicationFocusIn);s._Process(.2);
        Check(!s.Workstation.Busy("basket0"),"恢复后继续原动画");s.Hide();
        Check(s.Workstation.ActiveMotionCount==0,"隐藏页面清理所有临时动作");s.Show();s.Initialize(_catalog,f.Save,f.Controller,8);
        Check(s.Cooker.Baskets[0].State==NoodleBasketState.Empty&&s.Workstation.ActiveMotionCount==0,"重新开局复位全部制作画面");DisposeDay(f);
        ProjectSettings.SetSetting("accessibility/reduce_motion",true);
        f=NewDay();s=f.Screen;s.BasketAction(0);s._Process(.13);
        Check(!s.Workstation.Busy("basket0")&&s.Cooker.Baskets[0].State==NoodleBasketState.Cooking,"减少动态模式保留正确终态");DisposeDay(f);
        ProjectSettings.SetSetting("accessibility/reduce_motion",false);
    }
    private void TestCookingPresentation()
    {
        var f = NewDay(); var s = f.Screen;
        var water = s.Workstation.GetNode<AudioStreamPlayer>("CookingWater");
        var pan = s.Workstation.GetNode<AudioStreamPlayer>("CookingPan");
        s.BasketAction(0); s._Process(.1);
        Check(water.Playing && !pan.Playing, "煮水声只在锅内有面时播放");
        f.Controller.IsPaused = true; s._Process(1);
        Check(water.StreamPaused, "营业暂停冻结煮水声");
        f.Controller.IsPaused = false; s._Process(.1);
        Check(water.Playing && !water.StreamPaused, "恢复营业继续煮水声");
        s.PourDoupiBatter(); s._Process(.5); s.AddDoupiEgg(); s._Process(.7);
        Check(pan.Playing && s.Doupi!.SkinCookProgress > 0 && s.Doupi.SkinCookProgress < 1, "皮边熟度沿用制作时钟且同步煎制声");
        s._Process(2.1);
        Check(s.Doupi!.State == DoupiState.ReadyToFlip && s.Doupi.HeatStress > 0 && pan.PitchScale > 1, "过热时皮边与煎制声一起变化");
        s._Process(2);
        Check(s.Doupi.State == DoupiState.Burnt && !pan.Playing, "焦糊后停止正常煎制声");
        s.DiscardDoupi(); s._Process(.4);
        Check(s.Doupi.HeatStress == 0 && s.Doupi.SkinCookProgress == 0, "清理后熟度提示复位");
        int bus = AudioServer.GetBusIndex("Master"); bool muted = AudioServer.IsBusMute(bus);
        AudioServer.SetBusMute(bus, true);
        s.BasketAction(0); s._Process(.1);
        Check(AudioServer.IsBusMute(bus) && water.Bus == "Master", "烹饪音效遵循主音量静音");
        AudioServer.SetBusMute(bus, muted);
        s.Hide(); Check(!water.Playing && !pan.Playing, "离开营业清理所有烹饪声音");
        s.Show(); s.Initialize(_catalog, f.Save, f.Controller, 8);
        Check(!water.Playing && !pan.Playing, "重新营业不遗留上一局声音");
        DisposeDay(f);
    }
    private void Check(bool condition,string name)
    { if(condition){_passed++;GD.Print("PASS "+name);}else{_failed++;GD.PushError("FAIL "+name);} }
}
