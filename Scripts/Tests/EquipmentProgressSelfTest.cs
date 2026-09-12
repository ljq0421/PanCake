using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Pancake;
using ProjectCake.Fryer;
using ProjectCake.Wuhan;
using ProjectCake.Xian;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class EquipmentProgressSelfTest : Node
{
    private int _passed;
    private void Check(bool value, string message)
    {
        if (!value) throw new InvalidOperationException(message);
        _passed++;
    }
    public override async void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            TestClocks(catalog);
            await TestScreens(catalog, OS.GetCmdlineUserArgs().Contains("--capture"));
            GD.Print($"EQUIPMENT_PROGRESS_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private void TestClocks(DataCatalog catalog)
    {
        for (int level = 1; level <= 3; level++)
        {
            catalog.TryGetStove(level, out var stove);
            var pancake = new PancakeStateMachine(stove);
            Check(!EquipmentProgressPresentation.Pancake(pancake).Visible, "空炉隐藏");
            pancake.TryExecute(PancakeCommand.PlaceBatter); pancake.TryExecute(PancakeCommand.BeginSpread);
            pancake.SetSpreadCoverage(1); pancake.TryExecute(PancakeCommand.CompleteSpread); pancake.TryExecute(PancakeCommand.AddEgg);
            pancake.Tick(stove.SideAReadySeconds / 2);
            Check(Math.Abs(EquipmentProgressPresentation.Pancake(pancake).Progress - .5) < .001, "煎饼按等级读取实际计时");
            var paused = EquipmentProgressPresentation.Pancake(pancake); pancake.Tick(0);
            Check(EquipmentProgressPresentation.Pancake(pancake) == paused, "暂停不改变进度");
            pancake.Tick(stove.SideAReadySeconds / 2);
            Check(EquipmentProgressPresentation.Pancake(pancake).Ready, "第一面完成");
            pancake.TryExecute(PancakeCommand.Flip);
            Check(EquipmentProgressPresentation.Pancake(pancake).Progress == 0, "翻面重置");
            pancake.Tick(100);
            Check(stove.CanBurn ? EquipmentProgressPresentation.Pancake(pancake).Failed
                : EquipmentProgressPresentation.Pancake(pancake) is { Ready: true, Risk: 0, Failed: false }, "烧焦或教学防焦");
            pancake.TryExecute(PancakeCommand.Discard);
            Check(!EquipmentProgressPresentation.Pancake(pancake).Visible, "丢弃隐藏");

            catalog.TryGetFryer(level, out var fryerData);
            var fryer = new FryerStateMachine(fryerData);
            fryer.TryExecute(FryerCommand.LoadOne); fryer.TryExecute(FryerCommand.LowerBasket);
            fryer.Tick(fryerData.GoldenStartSeconds / 2);
            Check(Math.Abs(EquipmentProgressPresentation.Fryer(fryer).Progress - .5) < .001, "油条制作中点");
            fryer.Tick(fryerData.GoldenStartSeconds / 2);
            if (!fryerData.AutoRaise) fryer.TryExecute(FryerCommand.RaiseBasket);
            else fryer.Tick(Math.Max(0, fryerData.AutoRaiseAtSeconds - fryerData.GoldenStartSeconds));
            fryer.Tick(.00001); fryer.Tick(fryerData.DrainSeconds / 2);
            Check(EquipmentProgressPresentation.Fryer(fryer).Caption == "沥油中", "手动自动起锅均进入沥油");
            fryer.Tick(fryerData.DrainSeconds);
            Check(!EquipmentProgressPresentation.Fryer(fryer).Visible, "入盘后隐藏");

            var noodleData = catalog.NoodleCookersByLevel[level];
            var cooker = new NoodleCookerStateMachine(noodleData);
            cooker.TryStart(0); cooker.Tick(noodleData.OptimalSeconds / 2);
            Check(Math.Abs(EquipmentProgressPresentation.Noodles(cooker, 0).Progress - .5) < .001, "煮面中点");
            if (cooker.Baskets.Count > 1)
            {
                cooker.TryStart(1);
                Check(EquipmentProgressPresentation.Noodles(cooker, 1).Progress == 0, "多面篮独立计时");
            }
            cooker.Tick(noodleData.OptimalSeconds / 2);
            if (!noodleData.AutoRaise) cooker.TryRaise(0);
            Check(EquipmentProgressPresentation.Noodles(cooker, 0).Progress == 0, "提篮重置为沥水进度");
            cooker.Tick(noodleData.NaturalDrainSeconds / 2);
            Check(Math.Abs(EquipmentProgressPresentation.Noodles(cooker, 0).Progress - .5) < .001, "沥水中点");
            cooker.TryQuickDrain(0);
            Check(EquipmentProgressPresentation.Noodles(cooker, 0).Ready, "快速沥水立即完成");
            cooker.TryTake(0, out _);
            Check(!EquipmentProgressPresentation.Noodles(cooker, 0).Visible, "倒面隐藏");

            var panData = catalog.DoupiGriddlesByLevel[level]; var pan = new DoupiStateMachine(panData);
            pan.TryPourBatter(); pan.TryAddEgg(); pan.Tick(panData.StageSeconds / panData.SpeedMultiplier / 2);
            Check(Math.Abs(EquipmentProgressPresentation.Doupi(pan).Progress - .5) < .001, "豆皮升级速度同步");
            pan.Tick(panData.StageSeconds / panData.SpeedMultiplier / 2);
            if (!panData.AutoFlip) pan.TryFlip();
            pan.TryAddFilling(); DoupiTestFixture.Spread(pan);
            Check(EquipmentProgressPresentation.Doupi(pan).Progress == 0, "豆皮第二段重置");
            pan.Tick(100);
            Check(panData.CanBurn ? EquipmentProgressPresentation.Doupi(pan).Failed
                : EquipmentProgressPresentation.Doupi(pan) is { Ready: true, Risk: 0 }, "豆皮防焦和烧焦");
            pan.Discard(); Check(!EquipmentProgressPresentation.Doupi(pan).Visible, "豆皮清空隐藏");

            var ovenData = catalog.GetXianEquipment(XianRules.Oven, level); var oven = new BunOvenStateMachine(ovenData);
            var buns = new BunInventory(ovenData.StockCapacity, ovenData.StockCapacity);
            oven.TryStart(1); oven.Tick(ovenData.ActionSeconds / 2, buns);
            Check(Math.Abs(EquipmentProgressPresentation.Oven(oven, ovenData).Progress - .5) < .001, "馍炉中点");
            oven.Tick(ovenData.ActionSeconds / 2, buns);
            if (!ovenData.Automatic) oven.TryFlip();
            Check(EquipmentProgressPresentation.Oven(oven, ovenData).Progress == 0, "馍炉手动自动翻面重置");
            oven.Tick(ovenData.ActionSeconds, buns);
            Check(EquipmentProgressPresentation.Oven(oven, ovenData).Ready, "馍篮满保留完成提示");
            var soupData = catalog.GetXianEquipment(XianRules.Soup, level); var soup = new HulatangRuntime(soupData, 2);
            soup.TryServe(); soup.Tick(soupData.ActionSeconds / 2);
            Check(Math.Abs(EquipmentProgressPresentation.Soup(soup, soupData).Progress - .5) < .001, "盛汤中点");
            soup.Tick(soupData.ActionSeconds); Check(EquipmentProgressPresentation.Soup(soup, soupData).Ready, "盛汤完成");
            soup.TryTake(); Check(!EquipmentProgressPresentation.Soup(soup, soupData).Visible, "端汤隐藏");
            soup.Stock.TryRefill(); Check(!EquipmentProgressPresentation.Soup(soup, soupData).Visible, "补锅不显示制作进度");
        }
        Check(EquipmentProgressView.FillColor(EquipmentProgressState.Working(1, 2, "")) == new Color("#E8B650"), "制作暖黄");
        Check(EquipmentProgressView.FillColor(EquipmentProgressState.Done("")) == new Color("#78A65A"), "完成绿色");
        Check(EquipmentProgressView.FillColor(EquipmentProgressState.Done("", failed: true)) == new Color("#C95343"), "失败红色");
        Check(EquipmentProgressView.FillColor(EquipmentProgressState.Done("", .5)) == new Color("#E58A3D").Lerp(new Color("#C95343"), .5f), "风险橙红过渡");
        var manualNoodles = new NoodleCookerStateMachine(catalog.NoodleCookersByLevel[1]);
        manualNoodles.TryStart(0); manualNoodles.Tick(3.5);
        Check(EquipmentProgressPresentation.Noodles(manualNoodles, 0) is { Ready: true, Risk: > 0, Failed: false }, "偏软风险提示");
        manualNoodles.Tick(1);
        Check(EquipmentProgressPresentation.Noodles(manualNoodles, 0).Failed, "煮烂红色");
        manualNoodles.TryRaise(0); manualNoodles.TryQuickDrain(0);
        Check(EquipmentProgressPresentation.Noodles(manualNoodles, 0).Failed, "沥干不恢复煮烂品质");
        var warningPan = new DoupiStateMachine(catalog.DoupiGriddlesByLevel[1]);
        warningPan.TryPourBatter(); warningPan.TryAddEgg(); warningPan.Tick(3);
        Check(EquipmentProgressPresentation.Doupi(warningPan) is { Ready: true, Risk: > 0, Failed: false }, "豆皮待翻面风险");
        warningPan.TryFlip(); warningPan.TryAddFilling(); DoupiTestFixture.Spread(warningPan); warningPan.Tick(7);
        Check(EquipmentProgressPresentation.Doupi(warningPan).Risk > 0, "豆皮二次加热偏焦");
        warningPan.TryCut(DoupiCutLine.Horizontal); warningPan.Tick(100);
        Check(EquipmentProgressPresentation.Doupi(warningPan) is { Ready: true, Risk: 0, Failed: false }, "切块收火后不再推进风险");
    }

    private async Task TestScreens(DataCatalog catalog, bool capture)
    {
        bool small = OS.GetCmdlineUserArgs().Contains("--capture-720");
        GetWindow().Size = small ? new(1280, 720) : new(1920, 1080);
        var save = new SaveService(); save.UsePathForTests($"res://.tmp/equipment-progress/fixture-{Guid.NewGuid():N}.json"); AddChild(save);
        save.Data.PurchasedStoveLevel = 1; save.Data.PurchasedFryerLevel = 1;
        save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
        save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 1;
        save.Data.Xian.HighestUnlockedDay = 12;
        var controller = new DayController(); AddChild(controller);
        var tianjin = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
        AddChild(tianjin); tianjin.SetProcess(false); tianjin.ConnectController(controller);
        tianjin.Initialize(catalog, save, controller, 15); tianjin.BeginDay(); controller.Tick(3);
        var station = tianjin.GetChildren().OfType<PancakeWorkstation>().Single(); station.SetProcess(false);
        station.Machine.Runtime.State = PancakeState.SideACooking;
        station.Machine.Runtime.CookingSeconds = station.Machine.Stove.SideAReadySeconds / 2;
        station.FryerMachine!.TryExecute(FryerCommand.LoadOne); station.FryerMachine.TryExecute(FryerCommand.LowerBasket);
        station.FryerMachine.Tick(station.FryerMachine.Level.GoldenStartSeconds / 2); station.RefreshForCapture();
        await Shot(tianjin, "tianjin-cooking", 2);
        station.Machine.Tick(100); station.FryerMachine.Tick(station.FryerMachine.Level.GoldenStartSeconds / 2);
        station.RefreshForCapture(); await Shot(tianjin, "tianjin-ready-burnt", 2);
        controller.AbandonDay(); tianjin.Free(); controller.Free();
        controller = new DayController(); AddChild(controller);

        var wuhan = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
        AddChild(wuhan); wuhan.SetProcess(false); wuhan.ConnectController(controller);
        wuhan.Initialize(catalog, save, controller, 8); wuhan.BeginDay(); controller.Tick(3);
        wuhan.Cooker.TryStart(0); wuhan.Cooker.Tick(.6); wuhan.Cooker.TryStart(1); wuhan.Cooker.Tick(.2);
        wuhan.Doupi!.TryPourBatter(); wuhan.Doupi.TryAddEgg(); wuhan.Doupi.Tick(1);
        await Shot(wuhan, "wuhan-cooking", 3);
        wuhan.Cooker.Tick(1.1); wuhan.Doupi.Tick(1.5);
        await Shot(wuhan, "wuhan-draining-ready", 3);
        controller.AbandonDay(); wuhan.Free(); controller.Free();
        controller = new DayController(); AddChild(controller);

        var xian = SceneFactory.Instantiate<XianDayScreen>("res://Scenes/Gameplay/XianDayScreen.tscn");
        AddChild(xian); xian.SetProcess(false); xian.ConnectController(controller);
        Check(xian.Initialize(catalog, save, controller, 6), "西安测试关卡初始化"); xian.BeginDay(); controller.Tick(3);
        xian.Session.Oven!.TryStart(3); xian.Session.Oven.Tick(xian.Session.OvenData.ActionSeconds / 2, xian.Session.Buns);
        xian.Session.Soup!.TryServe(); xian.Session.Soup.Tick(xian.Session.SoupData.ActionSeconds / 2); xian.Render();
        await Shot(xian, "xian-cooking", 2);
        xian.Session.Oven.Tick(xian.Session.OvenData.ActionSeconds / 2 + 2.7, xian.Session.Buns);
        xian.Session.Soup.Tick(xian.Session.SoupData.ActionSeconds); xian.Render();
        await Shot(xian, "xian-warning-ready", 2);
        controller.AbandonDay(); xian.Free(); controller.Free();

        async Task Shot(Control screen, string name, int expected)
        {
            var bars = screen.FindChildren("*Progress*", "", true, false).OfType<EquipmentProgressView>().ToArray();
            foreach (var bar in bars) bar.Refresh();
            Check(bars.Count(b => b.IsVisibleInTree()) == expected, name + "绑定及可见数量");
            Check(bars.All(b => b.MouseFilter == Control.MouseFilterEnum.Ignore), name + "不拦截输入");
            foreach (var bar in bars.Where(b => b.Visible))
            {
                var before = bar.Presentation; for (int i = 0; i < 3; i++) bar._Process(10);
                Check(before == bar.Presentation, name + "展示不推进计时");
            }
            if (!capture) return;
            for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            string output = ProjectSettings.GlobalizePath($"res://.tmp/equipment-progress/{(small ? 720 : 1080)}");
            Directory.CreateDirectory(output);
            Check(GetViewport().GetTexture().GetImage().SavePng($"{output}/{name}.png") == Error.Ok, "保存截图");
        }
    }
}
