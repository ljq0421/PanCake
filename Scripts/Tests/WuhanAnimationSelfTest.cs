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
            if (OS.GetCmdlineUserArgs().Contains("--loop-only"))
            {
                TestImmediateLoop();
                GD.Print($"WUHAN_ANIMATION_TEST_RESULT passed={_passed} failed={_failed}");
                GetTree().Quit(_failed == 0 ? 0 : 1);
                return;
            }
            Check(new WuhanArtCatalog().MissingRequiredAssets().Count == 0, "全部武汉必需美术可加载");
            using (var spoon = new WuhanArtCatalog().Texture("egg_ladle").GetImage())
            {
                Check(spoon.GetPixel(0, 0).A == 0, "蛋液勺白底已去除");
                Check(spoon.GetPixel(spoon.GetWidth() / 2, spoon.GetHeight() * 3 / 5).A > .99f, "蛋液勺内部高光和蛋液保持不透明");
            }
            TestBasketReadySound();
            if (!OS.GetCmdlineUserArgs().Contains("--basket-ready-sound"))
            {
                TestActionSounds(); TestTransfer(); TestClickFlow(); TestBeefTiming(); TestAutomatic(); TestDoupi(); TestSupply(); TestLifecycle(); TestCookingPresentation(); TestImmediateLoop();
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
        Check(s.Ingredients.Count(StableIds.Ingredients.WuhanNoodles)==stock&&v.MotionProgress("basket0")<1&&!v.Busy("basket0"),"下面有视觉反馈但不锁操作，不消耗无限供应");
        s._Process(.12);Check(v.MotionProgress("basket0")>.1f&&v.MotionProgress("basket0")<1,"下面动画存在可捕获的中间帧");
        s._Process(1.5);s.BasketAction(0);s._Process(.71);
        Check(s.Cooker.Baskets[0].State==NoodleBasketState.Drained&&!v.Busy("basket0"),"提篮后自然沥水完成");
        s._Process(.25);s.BasketAction(0);
        s.IngredientAction(StableIds.Ingredients.WuhanBaseSeasoning);
        Check(!v.Busy("basket0")&&!v.Busy("bowl")&&s.Bowl.State==NoodleBowlState.Seasoned,"倒面后立即接受调味，旧倒面表现落定");
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
        Check(s.Cooker.Baskets.All(b=>b.State==NoodleBasketState.Draining)&&s.Workstation.MotionProgress("basket0")<1&&s.Workstation.MotionProgress("basket1")<1,"Lv3 两个漏勺同帧自动提篮都播放动画");
        s._Process(.8);Check(s.Cooker.Baskets.All(b=>b.State==NoodleBasketState.Drained),"自然沥水结束状态同步");
        s.BasketAction(0);s._Process(.7);s.BasketAction(1);
        Check(s.Cooker.Baskets[1].State==NoodleBasketState.Drained&&!s.Workstation.Busy("basket1"),"界面碗满拒绝倒入第二勺，不播放虚假成功动作");DisposeDay(f);
        f=NewDay(2);s=f.Screen;s.BasketAction(0);s._Process(5);
        Check(s.Cooker.Baskets[0].State==NoodleBasketState.Locked&&!s.Workstation.Busy("basket0"),"Lv2 只锁熟，不误播自动提篮");DisposeDay(f);
    }
    private static void MakeDoupi(WuhanDayScreen s,bool automatic=false)
    {
        s.PourDoupiBatter();s._Process(.4);s.AddDoupiEgg();s._Process(2.51);
        if(!automatic)s.FlipDoupi();s._Process(.5);s.AddDoupiFilling();s._Process(3.51);
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
        Check(eggDay.Workstation.ActiveMotionCount == 0 && eggDay.Doupi!.HasEgg, "暂停结束倒蛋液表现，保留已提交蛋液");
        egg.Controller.IsPaused = false; eggDay._Process(.2);
        Check(!eggDay.Workstation.Busy("pan") && eggDay.Doupi!.SkinCookProgress > 0,
            "恢复后煎制计时继续，旧动画不补播");
        eggDay._Process(.21);
        Check(!eggDay.Workstation.Busy("pan") && eggDay.Doupi!.State == DoupiState.SkinCooking,
            "无需手动摊蛋即完成动画并保留煎制状态");
        DisposeDay(egg);
        var meshDay=NewDay();var meshView=meshDay.Screen.Workstation;
        foreach(float lift in new[]{0f,.5f,1f})
        {
            bool valid=true;
            for(int frame=0;frame<=100;frame++) for(int y=0;y<4;y++) for(int x=0;x<12;x++)
            {
                Vector2[] cell=meshView.FlipSurfaceQuad(frame/100f,lift,new Rect2(x/12f,y/4f,1/12f,1/4f));
                valid &= cell.All(v=>v.IsFinite()) && Geometry2D.TriangulatePolygon(cell).Length==6;
            }
            Check(valid,$"翻面全程网格不交叉且能三角化 lift={lift}");
        }
        Vector2[] initial=meshView.FlipSurfaceQuad(0,1,new Rect2(0,0,1,1));
        Vector2[] landed=meshView.FlipSurfaceQuad(1,1,new Rect2(0,0,1,1));
        Check(initial[0].DistanceTo(meshView.PanPoint(0,0))<.001f && initial[3].DistanceTo(meshView.PanPoint(0,1)-new Vector2(0,24))<.001f,
            "翻面第一帧继承前缘抬起姿态");
        Check(landed[0].DistanceTo(meshView.PanPoint(0,0))<.001f && landed[2].DistanceTo(meshView.PanPoint(1,1))<.001f,"翻面落锅精确回到原锅面");
        DisposeDay(meshDay);
        var waiting = NewDay(); var hot = waiting.Screen;
        hot.PourDoupiBatter(); hot._Process(.4);
        Check(hot.Workstation.GetNode<AudioStreamPlayer>("CookingPan").Playing && hot.Doupi!.SideSeconds > 0,
            "倒浆后未加蛋也持续煎制并播放煎制声");
        hot._Process(3.6);hot.AddDoupiEgg();hot._Process(.51);
        Check(hot.Doupi!.State==DoupiState.Burnt && !hot.Workstation.Busy("pan"),
            "晚加蛋期间烧焦会结束原料动画且不延后火候");
        DisposeDay(waiting);
        waiting=NewDay();hot=waiting.Screen;
        hot.PourDoupiBatter();hot._Process(.4);hot.AddDoupiEgg();hot._Process(2.2);hot.FlipDoupi();hot._Process(.5);
        Check(hot.Workstation.GetNode<AudioStreamPlayer>("CookingPan").Playing && hot.Doupi!.SideSeconds > 0 && !hot.Doupi.HasFilling,
            "翻面后未加馅也持续煎制并播放煎制声");
        hot._Process(7.5);hot.AddDoupiFilling();hot._Process(.51);
        Check(hot.Doupi!.State==DoupiState.Burnt && !hot.Workstation.Busy("pan") && hot.DoupiStock.Count==0,
            "自动铺馅期间烧焦不完成或入库，允许直接丢弃");
        DisposeDay(waiting);
        var f=NewDay();var s=f.Screen;MakeDoupi(s);
        Check(s.Doupi!.State==DoupiState.Empty&&s.DoupiStock.Count==8,"豆皮四刀切割后自动入盘");
        s.PourDoupiBatter();s.PourDoupiBatter();Check(s.DoupiStock.Count==8&&s.Doupi.State==DoupiState.Batter&&!s.Workstation.Busy("stock"),"豆皮入库立即可开始下一锅，连点不重复增加一锅");
        s._Process(.5);MakeDoupi(s);s.PourDoupiBatter();s._Process(.5);MakeDoupi(s);s.PourDoupiBatter();
        Check(s.DoupiStock.Count==8&&s.Doupi.State==DoupiState.Cut&&!s.Workstation.Busy("pan"),"备货满盘保留锅内成品，不播放入库动作");DisposeDay(f);
        f=NewDay(3);s=f.Screen;s.PourDoupiBatter();s._Process(.4);s.AddDoupiEgg();s._Process(2.1);
        Check(s.Doupi!.State==DoupiState.Flipped&&s.Workstation.MotionProgress("pan")<1,"Lv3 豆皮自动翻面可见");DisposeDay(f);
        f=NewDay();s=f.Screen;s.PourDoupiBatter();s._Process(.4);s.AddDoupiEgg();s._Process(2.6);s._Process(2);
        Check(s.Doupi!.State==DoupiState.Burnt,"豆皮仍遵守焦糊时限");s.DiscardDoupi();s._Process(.4);
        Check(s.Doupi.State==DoupiState.Empty&&!s.Workstation.Busy("pan"),"丢弃焦糊豆皮后清空锅面与动画");DisposeDay(f);
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
        Check(s.Workstation.ActiveMotionCount==0&&s.Cooker.Baskets[0].CookSeconds==cook,"暂停复位表现，冻结制作和输入");
        f.Controller.IsPaused=false;s._Notification((int)NotificationApplicationFocusOut);s._Process(2);
        Check(s.Workstation.ActiveMotionCount==0,"失焦不恢复旧动画");s._Notification((int)NotificationApplicationFocusIn);s._Process(.2);
        Check(!s.Workstation.Busy("basket0")&&s.Workstation.ActiveMotionCount==0,"恢复后不补播原动画");s.Hide();
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
            Check(cue.Stream is AudioStreamWav { LoopMode: AudioStreamWav.LoopModeEnum.Disabled } && cue.Bus == JourneySettings.EffectsBus, "提篮提示为非循环音效并遵循主音量");
            s.BasketAction(0); s._Process(.1);
            Check(!cue.Playing, $"Lv{level} 未熟时不播放提示");
            s._Process(_catalog.NoodleCookersByLevel[level].OptimalSeconds);
            bool manual = !_catalog.NoodleCookersByLevel[level].AutoRaise;
            Check(cue.Playing == manual, $"Lv{level} 仅手动提篮高亮时播放一次提示");
            if (manual)
            {
                f.Controller.IsPaused = true; s._Process(.1);
                Check(!cue.Playing, "暂停营业停止提示音");
                f.Controller.IsPaused = false; s._Process(.1);
                Check(!cue.Playing, "恢复营业不补播提示音");
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
            Check(s.Bowl.Toppings.Contains(StableIds.Ingredients.WuhanBraisedBeef) && !view.Busy("bowl")
                && view.CanDeliver(ProductKind.HotDryNoodles), "拌匀后点击牛肉立即可交付，不等落料动画");
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
                && stream.LoopMode == AudioStreamWav.LoopModeEnum.Disabled && player.Bus == JourneySettings.EffectsBus,
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
        Check(!water.Playing, "营业暂停停止煮水声");
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
        Check(AudioServer.IsBusMute(bus) && water.Bus == JourneySettings.EffectsBus, "烹饪音效遵循主音量静音");
        AudioServer.SetBusMute(bus, muted);
        s.Hide(); Check(!water.Playing && !pan.Playing, "离开营业清理所有烹饪声音");
        s.Show(); s.Initialize(_catalog, f.Save, f.Controller, 8);
        Check(!water.Playing && !pan.Playing, "重新营业不遗留上一局声音");
        DisposeDay(f);
    }
    private void TestImmediateLoop()
    {
        foreach (bool reduced in new[] { false, true })
        {
            ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
            var f = NewDay(); var s = f.Screen; var v = s.Workstation;
            Vector2 bowlCenter = v.BowlCenter, panCenter = v.PanCenter;
            s.BasketAction(0);
            Check(!v.Busy("basket0") && s.Cooker.Baskets[0].State == NoodleBasketState.Cooking,
                "下面立即提交，制作时间仍由面篮状态控制");
            s._Process(1.7); s.BasketAction(0);
            s.BasketAction(0);
            Check(s.Bowl.State == NoodleBowlState.Empty, "动画不锁定也不能跳过实际沥水时间");
            s._Process(.9); s.BasketAction(0);
            s.IngredientAction(StableIds.Ingredients.WuhanBaseSeasoning);
            s.IngredientAction(StableIds.Ingredients.WuhanScallion);
            s.IngredientAction(StableIds.Ingredients.WuhanChiliOil);
            Check(s.Bowl.State == NoodleBowlState.Seasoned && s.Bowl.Toppings.Count == 2 && v.ActiveMotionCount == 1,
                "同帧倒面、调味、葱花和辣油均生效，旧动画不叠加");
            Click(v, bowlCenter); Move(v, bowlCenter + new Vector2(75, 0));
            Check(s.Bowl.MixProgress > 0 && v.ActiveMotionCount == 0, "立即搅拌会落定加料表现，不丢输入");
            v.EndMix(); s.Bowl.AddMixDistance(500);
            s.IngredientAction(StableIds.Ingredients.WuhanBraisedBeef);
            Check(v.CanDeliver(ProductKind.HotDryNoodles) && s.DeliveryDrag.ImmediateAcceptance,
                "牛肉加入后立即可拖出，并启用松手即时交付");
            Check(!s.DeliverToCustomer("missing", ProductKind.HotDryNoodles) && s.Bowl.State == NoodleBowlState.Ready,
                "动画未结束时错误交付仍保留成品");
            s.PourDoupiBatter(); s.AddDoupiEgg();
            Check(s.Doupi!.HasEgg && !s.AddDoupiEgg() && !s.FlipDoupi(),
                "倒浆后立即加蛋，重复加蛋和未熟翻面仍被状态机拒绝");
            s._Process(2.51); s.FlipDoupi(); s.AddDoupiFilling();
            Check(s.Doupi.HasFilling && !s.CutDoupi(DoupiCutLine.Horizontal),
                "翻面后立即加馅，实际煎制时间不能跳过");
            s._Process(3.51);
            Check(s.CutDoupi(DoupiCutLine.Horizontal) && s.CutDoupi(DoupiCutLine.Left),
                "横切后可立即竖切，不等刀具收尾");
            s._Process(.001);
            Check(s.DoupiStock.Count == 8 && v.CanDeliver(ProductKind.Doupi) && !v.Busy("pan"),
                "切完立即入盘并可出餐，不等入盘动画");
            Check(s.PourDoupiBatter() && s.AddDoupiEgg() && s.DoupiStock.Count == 8,
                "入盘期间可直接做下一锅，上一锅库存完整");
            Check(v.BowlCenter == bowlCenter && v.PanCenter == panCenter, "连续动效不改变容器与命中区域");
            s.OpenBusinessDetails(); s._Process(.01);
            Check(v.ActiveMotionCount == 0 && !v.CanDeliver(ProductKind.Doupi), "明细暂停清除收尾并禁止出餐");
            s.CloseBusinessDetails(); s._Process(.01);
            Check(v.ActiveMotionCount == 0 && s.Doupi.HasEgg, "恢复不重播，保留已提交制作状态");
            DisposeDay(f);
        }
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
    }

    private void Check(bool condition,string name)
    { if(condition){_passed++;GD.Print("PASS "+name);}else{_failed++;GD.PushError("FAIL "+name);} }
}
