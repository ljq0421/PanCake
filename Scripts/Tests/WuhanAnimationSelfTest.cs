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
            using (var spoon = new WuhanArtCatalog().Texture("egg_ladle").GetImage())
            {
                Check(spoon.GetPixel(0, 0).A == 0, "蛋液勺白底已去除");
                Check(spoon.GetPixel(spoon.GetWidth() / 2, spoon.GetHeight() * 3 / 5).A > .99f, "蛋液勺内部高光和蛋液保持不透明");
            }
            TestBasketReadySound();
            if (!OS.GetCmdlineUserArgs().Contains("--basket-ready-sound"))
            {
                TestActionSounds(); TestTransfer(); TestClickFlow(); TestBeefTiming(); TestAutomatic(); TestDoupi(); TestEgg(); TestSupply(); TestLifecycle(); TestCookingPresentation();
            }
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
        var egg = NewDay(); var eggDay = egg.Screen;
        Check(!eggDay.AddDoupiEgg() && !eggDay.Workstation.Busy("pan"), "空锅点击蛋液不播放取料动画");
        eggDay.PourDoupiBatter(); eggDay._Process(.4);
        Check(eggDay.AddDoupiEgg(), "点击一次开始舀取蛋液及自动摊开");
        eggDay._Process(.2);
        float eggProgress = eggDay.Workstation.MotionProgress("pan");
        Check(!eggDay.AddDoupiEgg() && eggDay.Workstation.MotionProgress("pan") == eggProgress,
            "舀取蛋液期间重复点击不重启动画");
        egg.Controller.IsPaused = true; eggDay._Process(1);
        Check(eggDay.Workstation.MotionProgress("pan") == eggProgress, "暂停冻结倒蛋液阶段");
        egg.Controller.IsPaused = false; eggDay._Process(.2);
        Check(eggDay.Workstation.Busy("pan") && eggDay.Doupi!.SkinCookProgress > 0,
            "自动摊蛋时煎制计时继续");
        eggDay._Process(.21);
        Check(!eggDay.Workstation.Busy("pan") && eggDay.Doupi!.State == DoupiState.SkinCooking,
            "无需手动摊蛋即完成动画并保留煎制状态");
        DisposeDay(egg);
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
    private void TestBasketReadySound()
    {
        foreach (int level in new[] { 1, 2, 3 })
        {
            var f = NewDay(level); var s = f.Screen;
            var cue = s.Workstation.GetNode<AudioStreamPlayer>("BasketReady");
            Check(cue.Stream is AudioStreamWav { LoopMode: AudioStreamWav.LoopModeEnum.Disabled } && cue.Bus == "Master", "提篮提示为非循环音效并遵循主音量");
            s.BasketAction(0); s._Process(.1);
            Check(!cue.Playing, $"Lv{level} 未熟时不播放提示");
            s._Process(_catalog.NoodleCookersByLevel[level].OptimalSeconds);
            bool manual = !_catalog.NoodleCookersByLevel[level].AutoRaise;
            Check(cue.Playing == manual, $"Lv{level} 仅手动提篮高亮时播放一次提示");
            if (manual)
            {
                f.Controller.IsPaused = true; s._Process(.1);
                Check(cue.StreamPaused, "暂停营业同步暂停提示音");
                f.Controller.IsPaused = false; s._Process(.1);
                Check(!cue.StreamPaused, "恢复营业同步恢复提示音");
            }
            cue.Stop(); s._Process(4);
            Check(!cue.Playing, "等待和品质变化不会重复提示");
            s.Cooker.TryDiscard(0); s._Process(.01);
            s.BasketAction(0); s._Process(_catalog.NoodleCookersByLevel[level].OptimalSeconds + .1);
            Check(cue.Playing == manual, "下一篮煮熟可重新提示");
            s.Hide(); Check(!cue.Playing, "离开营业立即停止提示音");
            s.Show(); s.Initialize(_catalog, f.Save, f.Controller, 8);
            Check(!cue.Playing, "重新营业不遗留提示音");
            DisposeDay(f);
        }
    }
    private void TestBeefTiming()
    {
        foreach (bool reduced in new[] { false, true })
        {
            ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
            var f = NewDay(); var s = f.Screen; var view = s.Workstation;
            s.Bowl.TryAddNoodles(NoodleQuality.Optimal); s.Bowl.TryAddBaseSeasoning();
            Click(view, view.IngredientCenter(3));
            Check(!s.Bowl.Toppings.Contains(StableIds.Ingredients.WuhanBraisedBeef) && !view.Busy("bowl"),
                $"reduce_motion={reduced}: 提前点击牛肉无加料和成功动画");
            s.Bowl.AddMixDistance(100);
            Click(view, view.IngredientCenter(3));
            Check(s.Bowl.State == NoodleBowlState.Mixing && !view.Busy("bowl"), "搅拌中点击牛肉不推进状态或播动画");
            s.Bowl.AddMixDistance(325);
            Click(view, view.IngredientCenter(3));
            Check(s.Bowl.Toppings.Contains(StableIds.Ingredients.WuhanBraisedBeef) && view.Busy("bowl")
                && !view.CanDeliver(ProductKind.HotDryNoodles), "拌匀后点击牛肉加料，动画期间不能提前交付");
            s._Process(.5);
            Check(s.Bowl.State == NoodleBowlState.Ready && view.CanDeliver(ProductKind.HotDryNoodles), "加牛肉动画结束即可出餐");
            Click(view, view.IngredientCenter(3));
            Check(s.Bowl.Toppings.Count == 1 && !view.Busy("bowl"), "重复点击牛肉不重播成功动画");
            DisposeDay(f);
        }
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
    }
    private void TestActionSounds()
    {
        var owner = new Node(); AddChild(owner);
        var audio = new WuhanActionAudio(owner);
        foreach (WuhanSound sound in Enum.GetValues<WuhanSound>())
        {
            Check(audio.Play(sound), $"{sound} 首次可播放");
            var player = owner.GetNode<AudioStreamPlayer>($"WuhanCue{sound}");
            var stream = (AudioStreamWav)player.Stream;
            Check(stream.Data.Length > 0 && stream.Data.Any(b => b != 0)
                && stream.LoopMode == AudioStreamWav.LoopModeEnum.Disabled && player.Bus == "Master",
                $"{sound} 有声音数据、无循环并遵循主音量");
        }
        audio.Stop();
        Check(audio.Play(WuhanSound.Mix) && !audio.Play(WuhanSound.Mix), "连续搅拌输入限频");
        audio.SetPaused(true);
        Check(!audio.Play(WuhanSound.Drop) && owner.GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing),
            "暂停停止短音并阻止新音效");
        audio.SetPaused(false);
        Check(audio.Play(WuhanSound.Drop), "恢复后操作可重新发声");
        owner.Free();

        var f = NewDay(); var s = f.Screen; var v = s.Workstation;
        s.BasketAction(0);
        Check(v.GetNodeOrNull<AudioStreamPlayer>("WuhanCueDrop")?.Playing == true, "下面成功触发音效");
        s.IngredientAction(StableIds.Ingredients.WuhanBaseSeasoning);
        Check(v.GetNodeOrNull<AudioStreamPlayer>("WuhanCueSeason") is null
            && v.GetNodeOrNull<AudioStreamPlayer>("WuhanCueError")?.Playing == true,
            "空碗加酱只播错误，不播加酱成功声");
        s._Process(.3); s._Process(_catalog.NoodleCookersByLevel[1].OptimalSeconds);
        Check(s.RaiseBasket(0) && v.GetNodeOrNull<AudioStreamPlayer>("WuhanCueRaise")?.Playing == true,
            "拖拽提篮路径触发音效");
        s.OpenBusinessDetails(); s._Process(.01);
        Check(v.GetChildren().OfType<AudioStreamPlayer>().Where(p => p.Name.ToString().StartsWith("WuhanCue")).All(p => !p.Playing)
            && s.GetNodeOrNull<AudioStreamPlayer>("WuhanCueBookOpen") is not null,
            "明细暂停制作音，开本音可正常播放");
        s.BusinessDetails.SelectPage(true);
        Check(s.GetNodeOrNull<AudioStreamPlayer>("WuhanCuePage")?.Playing == true, "切换明细页触发翻页声");
        s.CloseBusinessDetails(); s._Process(.01);
        Check(s.GetNodeOrNull<AudioStreamPlayer>("WuhanCueBookClose")?.Playing == true, "关闭明细触发合本声");
        s.Hide();
        Check(v.GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing)
            && s.GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing), "隐藏章节清理制作及界面音效");
        DisposeDay(f);
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
