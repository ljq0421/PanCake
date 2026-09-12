using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class WuhanSelfTest : Node
{
    private int _passed, _failed;
    public override void _Ready()
    {
        DataCatalog catalog=GetNode<DataCatalog>("/root/DataCatalog");
        TestData(catalog); TestOrders(catalog); TestNoodles(catalog); TestDoupi(catalog); TestSatisfaction(catalog); TestPressure(catalog); TestSave(catalog); TestV2Migration();
        TestCustomerParity(catalog); TestRetiredCompatibility(catalog); TestPartialPieces(catalog); TestDoupiInteraction(catalog);
        GD.Print($"WUHAN_TEST_RESULT passed={_passed} failed={_failed}"); GetTree().Quit(_failed==0?0:1);
    }
    private void TestDoupiInteraction(DataCatalog catalog)
    {
        DoupiStateMachine NewPan()
        {
            var pan = new DoupiStateMachine(catalog.DoupiGriddlesByLevel[1]);
            pan.TryPourBatter(); pan.TryAddEgg(); pan.Tick(2.5); pan.TryFlip(); pan.TryAddFilling();
            return pan;
        }
        var pan = NewPan();
        Check(!pan.TryAddFilling() && !pan.TryCut(DoupiCutLine.Left), "铺馅阶段拒绝重复加料和提前切割");
        Check(!pan.Spread(new(-.2f,.2f),new(-.1f,.8f),2.75f) && pan.Coverage==0, "完全锅外的笔刷不增加覆盖");
        pan.Spread(new(.02f,.15f),new(.98f,.15f),2.75f);
        float coverage = pan.Coverage;
        pan.Spread(new(.98f,.15f),new(.02f,.15f),2.75f);
        pan.Tick(100);
        Check(pan.Coverage==coverage && pan.State==DoupiState.Spreading && pan.Quality==DoupiQuality.Normal, "重复区域不累加，铺馅期间不烧焦");
        var fine = NewPan();
        for(int i=0;i<24;i++) fine.Spread(new(.02f+i*.04f,.15f),new(.02f+(i+1)*.04f,.15f),2.75f);
        Check(Math.Abs(pan.Coverage-fine.Coverage)<.0001f, "快速长划与密集鼠标采样覆盖一致");
        DoupiTestFixture.Spread(pan);
        Check(pan.Coverage==1 && pan.State==DoupiState.SecondCooking, "85%覆盖补齐并进入第二段煎制");
        Check(!pan.TryCut(DoupiCutLine.Left), "第二段未成熟不能收火");
        pan.Tick(7);
        Check(pan.TryCut(DoupiCutLine.Right) && pan.Quality==DoupiQuality.Overbrowned, "偏焦第一刀锁定原品质");
        pan.Tick(100);
        Check(pan.State==DoupiState.Cutting && pan.Quality==DoupiQuality.Overbrowned, "收火后长时间中断不焦糊且不恢复品质");
        Check(!pan.TryCut(DoupiCutLine.Right) && !pan.TryCut((DoupiCutLine)99) && pan.CompletedCuts==3, "重复刀及无效刀线编号不计数");
        foreach(var line in new[]{DoupiCutLine.Horizontal,DoupiCutLine.Left,DoupiCutLine.Center})pan.TryCut(line);
        var stock = new DoupiInventory();stock.TryAddBatch(12);
        Check(pan.TransferAvailable(stock)==4 && pan.RemainingPieces==4, "十二块库存仅接收四块，另四块留锅");
        Check(Enumerable.Range(0,12).All(i=>stock.PieceAt(i).Quality==DoupiQuality.Normal)
            && Enumerable.Range(12,4).All(i=>stock.PieceAt(i).Quality==DoupiQuality.Overbrowned), "不同锅次逐块保留品质");
        stock.TryTake(4,out _);pan.TransferAvailable(stock);
        Check(pan.State==DoupiState.Empty && pan.Coverage==0 && pan.CompletedCuts==0, "最后余块出锅后重置铺馅和刀线");
        var burnt = NewPan();DoupiTestFixture.Spread(burnt);burnt.Tick(9);
        Check(burnt.State==DoupiState.Burnt && !burnt.TryCut(DoupiCutLine.Left), "焦糊不可通过切割挽救");
        burnt.Discard();Check(burnt.Coverage==0 && burnt.Quality==DoupiQuality.Normal,"清锅清除覆盖及品质");
        var shortStroke=new DoupiCutStroke(new(.05f,.5f));
        for(int i=0;i<30;i++){shortStroke.Move(new(.25f,.5f));shortStroke.Move(new(.05f,.5f));}
        Check(shortStroke.Coverage<.3f,"刀线局部来回划不靠累计路程完成");
        var offLine=new DoupiCutStroke(new(.05f,.7f));
        Check(!offLine.Move(new(.95f,.7f)) && offLine.Coverage==0,"吸附带外水平划动无效");
        foreach (bool reverse in new[]{false,true})
        {
            var jitter = new DoupiCutStroke(new(reverse ? .95f : .05f, .5f));
            jitter.Move(new(reverse ? .85f : .15f, .5f));
            for (int i=11;i<=90;i++)
                jitter.Move(new(reverse ? .95f-i*.01f : .05f+i*.01f, i%2==0 ? .62f : .5f));
            Check(jitter.Line==DoupiCutLine.Horizontal && jitter.Coverage>=DoupiInteraction.CutTarget,
                "横切正反向连续抖动仍累计有效覆盖");
        }
        Check(pan.CompletedCuts==0,"新锅没有遗留刀痕");
        var diagonal=new DoupiCutStroke(new(.1f,.1f));
        Check(!diagonal.Move(new(.9f,.9f)) && diagonal.Line is null,"对角划动不选刀线");
        var edge=new DoupiCutStroke(new(.32f,.05f));
        Check(edge.Move(new(.32f,.95f)) && edge.Line==DoupiCutLine.Left,"宽松吸附接受靠近左刀线的完整划动");
        var crossing=new DoupiCutStroke(new(.5f,.5f));
        crossing.Move(new(.51f,.51f));
        Check(crossing.Line is null,"交点微动不会提前锁定刀线");
        crossing.Move(new(.5f,.1f));
        Check(crossing.Line==DoupiCutLine.Center,"明确移动方向后才锁定刀线");
        Vector2[] quad={new(1124,491),new(1521,491),new(1550,642),new(1107,642)};
        var uv = new Vector2(.75f,.35f);
        var world = quad[0].Lerp(quad[1],uv.X).Lerp(quad[3].Lerp(quad[2],uv.X),uv.Y);
        Check(DoupiInteraction.ToSurface(quad,world).DistanceTo(uv)<.0001f,"锅面透视映射与绘制坐标一致");
    }
    private void TestRetiredCompatibility(DataCatalog catalog)
    {
        string path = $"res://.tmp/wuhan-retired-{Guid.NewGuid():N}.json";
        var save = new SaveService(); save.UsePathForTests(path); AddChild(save);
        save.Data.Coins = 777;
        save.Data.Wuhan.EquipmentLevels["ingredient_station"] = 3;
        save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"] = 1;
        save.Data.Wuhan.UnlockedCollectibleIds.Add("collectible:wuhan_egg_rice_wine");
        Check(save.TrySave(out _), "旧设备与蛋酒收藏存档可写入");
        var loaded = new SaveService(); loaded.UsePathForTests(path); AddChild(loaded);
        Check(!loaded.HasLoadError && loaded.Data.Coins == 777 && loaded.Data.Wuhan.EquipmentLevels["ingredient_station"] == 3
            && loaded.Data.Wuhan.UnlockedCollectibleIds.Contains("collectible:wuhan_egg_rice_wine"), "读取旧存档保留等级收藏且不退款");
        var hub = SceneFactory.Instantiate<ProjectCake.UI.WuhanHub>("res://Scenes/UI/WuhanHub.tscn"); AddChild(hub); hub.Initialize(catalog, loaded);
        Check(!hub.GetNode<Button>("%WuhanStationUpgrade").Visible && hub.GetNode<Label>("%WuhanStationNote").Text == "生面无限供应", "旧满级备料台显示无限供应且无升级入口");
        hub.Free(); loaded.Free(); save.Free(); File.Delete(ProjectSettings.GlobalizePath(path));
    }
    private void TestPartialPieces(DataCatalog catalog)
    {
        var stock = new DoupiInventory(); stock.TryAddBatch(13);
        var pan = new DoupiStateMachine(catalog.DoupiGriddlesByLevel[1]);
        pan.TryPourBatter(); pan.TryAddEgg(); pan.Tick(2.5); pan.TryFlip(); pan.TryAddFilling();DoupiTestFixture.Spread(pan);
        pan.Tick(7); foreach (var line in Enum.GetValues<DoupiCutLine>()) pan.TryCut(line);
        Check(pan.TransferAvailable(stock) == 3 && pan.RemainingPieces == 5 && pan.FirstRemainingPiece == 3, "部分入盘保留五块及原锅面位置");
        Check(Enumerable.Range(0, 3).All(i => stock.PieceAt(13 + i) == new DoupiInventory.Piece(DoupiQuality.Overbrowned, i)), "前三块的纹理编号和煎制品质进入托盘");
        stock.TryTake(16, out _);
        Check(pan.TransferAvailable(stock) == 5 && pan.State == DoupiState.Empty && Enumerable.Range(0, 5).All(i => stock.PieceAt(i).Tile == i + 3), "释放容量后剩余块沿用原纹理且只转移一次");
    }
    private void TestCustomerParity(DataCatalog catalog)
    {
        Check(catalog.GetDays(StableIds.Cities.Wuhan).Values.All(day => day.MaxWaitingCustomers == 5), "武汉所有营业日最多五名同屏顾客");
        var controller = new DayController(); AddChild(controller);
        Check(controller.TryPrepareDay(StableIds.Cities.Wuhan, 1, catalog, out _), "准备顾客机制测试");
        foreach (var planned in controller.CurrentPlan!.Customers)
            planned.Order = new OrderData { OrderId = planned.Order.OrderId, CityId = StableIds.Cities.Wuhan,
                CustomerTypeId = planned.CustomerTypeId, BasePrice = 15,
                Lines = new[] { new OrderLineData(ProductKind.Doupi, StableIds.Products.Doupi, 1),
                    new OrderLineData(ProductKind.EggRiceWine, StableIds.Products.EggRiceWine, 1) } };
        controller.TryStartDay(out _); controller.Tick(3.01);
        var queue = controller.CustomerQueue!;
        queue.Tick(60, 0, true); queue.Tick(60, .4, true);
        Check(queue.Slots.Count == 5 && queue.CustomerAtSlot(4) is not null && queue.HasUnscheduled,
            "第五名顾客入位，满员时延后后续顾客入场");
        var customer = queue.CustomerAtSlot(4)!;
        customer.WaitSeconds = customer.LeaveAtSeconds * .7; customer.Tick(0);
        var doupi = new DeliveredItem(ProductKind.Doupi, StableIds.Products.Doupi);
        Check(!controller.TryDeliverWuhanTo(customer.Id, doupi, () => false).ItemAccepted
            && Math.Abs(customer.PatienceProgress - .7) < .001, "库存不足不恢复耐心");
        Check(controller.TryDeliverWuhanTo(customer.Id, doupi, () => true).ItemAccepted
            && !customer.Progress.IsComplete && Math.Abs(customer.PatienceProgress - .55) < .001,
            "第五位顾客收到部分商品后恢复15%耐心");
        Check(!controller.TryDeliverWuhanTo(customer.Id, doupi, () => true).ItemAccepted
            && Math.Abs(customer.PatienceProgress - .55) < .001, "重复交付不恢复耐心");
        customer.WaitSeconds = 1;
        Check(controller.TryDeliverWuhanTo(customer.Id, new DeliveredItem(ProductKind.EggRiceWine,
            StableIds.Products.EggRiceWine), () => true).CompletesOrder && customer.WaitSeconds == 0,
            "耐心恢复不超过满值且整单正常完成");
        controller.Free();
    }
    private void TestData(DataCatalog c)
    {
        var days=c.GetDays(StableIds.Cities.Wuhan);Check(c.IsValid,"全量数据目录校验通过");Check(days.Count==12,"武汉包含 Day 1～12");Check(days.Values.Sum(d=>d.DurationSeconds)==1400,"营业时长合计 1400 秒");Check(days.Values.All(d => d.ExpectedRevenue == new OrderGenerator().Generate(d,c.RecipesById,c.ProductsById,c.CustomersById).Customers.Sum(p => p.Order.BasePrice)),"预计收入与固定种子订单一致");Check(c.NoodleCookersByLevel.Values.Sum(x=>x.UpgradePrice)+c.DoupiGriddlesByLevel.Values.Sum(x=>x.UpgradePrice)==1580,"在售升级价格合计 1580");Check(ProjectCake.UI.TianjinMapScreen.CanEnterCity(false,true)&&!ProjectCake.UI.TianjinMapScreen.CanEnterCity(false,false)&&ProjectCake.UI.TianjinMapScreen.CanEnterCity(true,false),"开发测试入口可绕过城市前置解锁");
    }
    private void TestOrders(DataCatalog c)
    {
        foreach (var day in c.GetDays(StableIds.Cities.Wuhan).Values)
        {
            int seed = day.RandomSeed;
            GD.Print($"WUHAN_REVENUE {day.Day} {new OrderGenerator().Generate(day,c.RecipesById,c.ProductsById,c.CustomersById).Customers.Sum(p=>p.Order.BasePrice)}");
            try
            {
                foreach (int sample in new[] { seed, 1, 42, 99, 2026 })
                {
                    day.RandomSeed = sample;
                    DayPlan plan = new OrderGenerator().Generate(day,c.RecipesById,c.ProductsById,c.CustomersById);
                    Check(plan.Customers.All(p=>p.Order.Lines.Count>0 && p.Order.Lines.All(l=>l.ProductKind is ProductKind.HotDryNoodles or ProductKind.Doupi && l.Quantity>0)), $"Day {day.Day} seed {sample}: no retired or empty orders");
                }
            }
            finally { day.RandomSeed = seed; }
        }
        DayConfig d=c.GetDays(StableIds.Cities.Wuhan)[12];DayPlan a=new OrderGenerator().Generate(d,c.RecipesById,c.ProductsById,c.CustomersById);DayPlan b=new OrderGenerator().Generate(d,c.RecipesById,c.ProductsById,c.CustomersById);
        Check(a.Customers.Select(x=>x.CustomerTypeId).SequenceEqual(b.Customers.Select(x=>x.CustomerTypeId)),"固定种子结果可重现");
        var people=a.Customers.GroupBy(x=>x.CustomerTypeId).ToDictionary(x=>x.Key,x=>x.Count());Check(people["wuhan_normal"]==9&&people["wuhan_office_worker"]==5&&people["wuhan_regular"]==4&&people["wuhan_tourist"]==4&&people["wuhan_big_order"]==4,"Day 12 顾客精确配额");
        var orders=a.Customers.GroupBy(x=>x.Order.OrderTypeId).ToDictionary(x=>x.Key,x=>x.Count());Check(orders.Count==3&&orders["hot_dry_noodles"]==10&&orders["doupi"]==3&&orders["noodles_doupi"]==13,"Day 12 订单精确配额");
        Check(!a.Customers.Zip(a.Customers.Skip(1)).Any(pair=>pair.First.CustomerTypeId=="wuhan_big_order"&&pair.Second.CustomerTypeId=="wuhan_big_order"),"大单顾客不连续");int run=0,max=0;foreach(var x in a.Customers){run=x.Order.OrderTypeId=="noodles_doupi"?run+1:0;max=Math.Max(max,run);}Check(max<=2,"面加豆皮最多连续两单");
        var allBig=new List<string>();for(int day=9;day<=12;day++)foreach(var x in new OrderGenerator().Generate(c.GetDays(StableIds.Cities.Wuhan)[day],c.RecipesById,c.ProductsById,c.CustomersById).Customers.Where(x=>x.CustomerTypeId=="wuhan_big_order"))allBig.Add(x.Order.OrderTypeId);Check(allBig.Count==9&&allBig.All(x=>x is "hot_dry_noodles" or "noodles_doupi"),"大单仅出现单面或面加豆皮");
    }
    private void TestNoodles(DataCatalog c)
    {
        const string beef = StableIds.Ingredients.WuhanBraisedBeef;
        const string chili = StableIds.Ingredients.WuhanChiliOil;
        const string scallion = StableIds.Ingredients.WuhanScallion;
        var timing = new HotDryNoodlesStateMachine();
        Check(!timing.TryAddTopping(beef), "空碗不能加牛肉");
        timing.TryAddNoodles(NoodleQuality.Optimal);
        Check(!timing.TryAddTopping(beef), "未调味不能加牛肉");
        timing.TryAddBaseSeasoning();
        Check(!timing.TryAddTopping(beef) && timing.Toppings.Count == 0, "已调味未拌面不能加牛肉");
        Check(timing.TryAddTopping(chili) && !timing.TryAddTopping(chili), "辣油拌面前加入且禁止重复");
        timing.AddMixDistance(100);
        double partial = timing.MixProgress;
        Check(!timing.TryAddTopping(beef) && !timing.TryAddTopping(scallion) && timing.MixProgress == partial,
            "搅拌中拒绝加牛肉和葱花且不改变进度");
        timing.AddMixDistance(325);
        Check(!timing.TryAddTopping(scallion) && !timing.TryAddTopping("unknown"), "拌匀后拒绝葱花和未知小料");
        Check(timing.TryAddTopping(beef) && timing.State == NoodleBowlState.Ready && timing.MixProgress == 100,
            "拌匀后加入牛肉保持可出餐且无需再拌");
        Check(!timing.TryAddTopping(beef) && timing.Toppings.Count == 2, "牛肉只添加一份");
        Check(timing.TryPrepare(c.RecipesById, out var beefChili) && beefChili.RecipeId == StableIds.Recipes.HotDryNoodlesBeefChili,
            "后加牛肉正确匹配牛肉辣油配方");
        foreach (var recipe in c.RecipesById.Values.Where(r => r.Id.StartsWith("hot_dry_noodles_", StringComparison.Ordinal)))
        {
            timing.Reset(); timing.TryAddNoodles(NoodleQuality.Optimal); timing.TryAddBaseSeasoning();
            foreach (string ingredient in recipe.ExtraIngredients.Where(id => id != beef))
                Check(timing.TryAddTopping(ingredient), $"{recipe.Id}: 拌面前小料生效");
            timing.AddMixDistance(425);
            if (recipe.ExtraIngredients.Contains(beef)) Check(timing.TryAddTopping(beef), $"{recipe.Id}: 拌面后牛肉生效");
            Check(timing.TryPrepare(c.RecipesById, out var prepared) && prepared.RecipeId == recipe.Id,
                $"{recipe.Id}: 按新顺序正确出餐");
        }
        var lv1=new NoodleCookerStateMachine(c.NoodleCookersByLevel[1]);Check(lv1.TryStart(0),"Lv1 面条下锅");lv1.Tick(1.6);Check(lv1.Baskets[0].State==NoodleBasketState.Ready,"1.6 秒进入最佳");lv1.Tick(1.5);Check(lv1.Baskets[0].State==NoodleBasketState.Soft,"超过 3 秒偏软");lv1.Tick(1);Check(lv1.Baskets[0].State==NoodleBasketState.Overcooked,"超过 4 秒煮过头");
        var lv2=new NoodleCookerStateMachine(c.NoodleCookersByLevel[2]);lv2.TryStart(0);lv2.Tick(5);Check(lv2.Baskets[0].State==NoodleBasketState.Locked,"Lv2 最佳点锁熟且不自动提篮");
        var lv3=new NoodleCookerStateMachine(c.NoodleCookersByLevel[3]);lv3.TryStart(0);lv3.TryStart(1);lv3.Tick(1.3);Check(lv3.Baskets.All(x=>x.State==NoodleBasketState.Draining),"Lv3 双漏勺独立自动提篮");
        var bowl=new HotDryNoodlesStateMachine();bowl.TryAddNoodles(NoodleQuality.Optimal);bowl.TryAddBaseSeasoning();bowl.AddMixDistance(425);Check(bowl.State==NoodleBowlState.Ready&&bowl.MixProgress==100,"拌匀 85% 自动吸附至 100%");
    }
    private void TestDoupi(DataCatalog c)
    {
        var stock=new DoupiInventory();var machine=new DoupiStateMachine(c.DoupiGriddlesByLevel[1]);MakeBatch(machine,stock);Check(stock.Count==8,"豆皮一锅固定八块");MakeBatch(machine,stock);Check(stock.Count==16,"豆皮备餐盘容量十六块");var third=new DoupiStateMachine(c.DoupiGriddlesByLevel[1]);third.TryPourBatter();third.TryAddEgg();third.Tick(2.5);third.TryFlip();third.TryAddFilling();DoupiTestFixture.Spread(third);third.Tick(3.5);foreach(var direction in Enum.GetValues<DoupiCutLine>())third.TryCut(direction);Check(third.TransferAvailable(stock)==0&&third.State==DoupiState.Cut,"库存满时成品留在锅中等待");
    }
    private static void MakeBatch(DoupiStateMachine m,DoupiInventory s){m.TryPourBatter();m.TryAddEgg();m.Tick(2.5);m.TryFlip();m.TryAddFilling();DoupiTestFixture.Spread(m);m.Tick(3.5);foreach(var direction in Enum.GetValues<DoupiCutLine>())m.TryCut(direction);m.TransferAvailable(s);}
    private void TestSatisfaction(DataCatalog c)
    {
        var order=new OrderData{OrderId="test",CityId=StableIds.Cities.Wuhan,OrderTypeId="hot_dry_noodles",CustomerTypeId="wuhan_normal",PatienceSeconds=50,BasePrice=20,Lines=new[]{new OrderLineData(ProductKind.HotDryNoodles,StableIds.Recipes.HotDryNoodlesClassic,2)}};var progress=new OrderProgress(order);var flags=WuhanFoodQuality.MixedComplete|WuhanFoodQuality.NoodlesOvercooked;progress.TryAccept(new DeliveredItem(ProductKind.HotDryNoodles,StableIds.Recipes.HotDryNoodlesChili,null,null,null,flags));progress.TryAccept(new DeliveredItem(ProductKind.HotDryNoodles,StableIds.Recipes.HotDryNoodlesChili,null,null,null,flags));DeliveryEvaluation result=new OrderEvaluator().EvaluateCompletedWuhan(progress,.70,c.CustomersById["wuhan_normal"]);Check(result.SatisfactionScore==55&&result.SaleRevenue==14,"等待、错配方、过熟叠加且同类只扣一次");
        var ledger=new DayLedger(1,7,SatisfactionAverageMode.CompletedCustomers);ledger.RecordDelivery(new DeliveryEvaluation(DeliveryGrade.Correct,10,0,80,""));ledger.RecordLost();Check(Math.Abs(ledger.Build().Satisfaction-80)<.001,"武汉满意度只统计已完成订单");
    }
    private void TestPressure(DataCatalog c)
    {
        CustomerTypeData type=c.CustomersById["wuhan_normal"];var types=new Dictionary<string,CustomerTypeData>{{type.Id,type}};PlannedCustomer Make(int i,double at)=>new(){CustomerId=$"p{i}",CustomerTypeId=type.Id,ArrivalTime=at,Order=new OrderData{OrderId=$"o{i}",CityId=StableIds.Cities.Wuhan,OrderTypeId="noodles_doupi",CustomerTypeId=type.Id,PatienceSeconds=50,BasePrice=15,Lines=new[]{new OrderLineData(ProductKind.HotDryNoodles,StableIds.Recipes.HotDryNoodlesClassic,1),new OrderLineData(ProductKind.Doupi,StableIds.Products.Doupi,1)}}};var plan=new DayPlan{Day=1,RandomSeed=1,Customers=new[]{Make(1,0),Make(2,.1),Make(3,.2)}};var q=new CustomerQueue(plan,types,1,4,2,4);q.Tick(0,.01,true);q.Tick(.1,.1,true);q.Tick(.2,.1,true);Check(q.Slots.Count==2,"两个复杂单触发软延迟");q.Tick(2.2,2,true);Check(q.Slots.Count==2,"持续高压累计第二次延迟");q.Tick(4.2,2,true);Check(q.Slots.Count==3,"软延迟到四秒后仍按原计划生成");
    }
    private void TestSave(DataCatalog c)
    {
        string path=$"res://.tmp/wuhan-v3-{Guid.NewGuid():N}.json";var save=new SaveService();AddChild(save);save.UsePathForTests(path);save.Data.Coins=3000;CityProgressData city=save.Data.Wuhan;city.UnlockedContentIds.Add("equipment:wuhan_ingredient_station_lv2");Check(!save.TryPurchase(StableIds.Cities.Wuhan,"equipment:wuhan_ingredient_station_lv2",c,out _)&&save.Data.Coins==3000&&save.Data.PurchasedIngredientStationLevel==1,"旧容量升级已下架且不扣金币");DayConfig day12=c.GetDays(StableIds.Cities.Wuhan)[12];DayResult result=new(){Day=12,PlannedCustomers=26,CompletedCustomers=24,Satisfaction=90,PerfectOrders=15,SaleRevenue=411};DayPlan plan=new OrderGenerator().Generate(day12,c.RecipesById,c.ProductsById,c.CustomersById);save.CommitDay(result,plan,day12);Check(save.Data.Wuhan.Completed&&save.Data.Wuhan.BestStars==3&&save.Data.Wuhan.UnlockedCollectibleIds.Count==3,"武汉三星完成并保存收藏徽章");save.QueueFree();string absolute=ProjectSettings.GlobalizePath(path);if(File.Exists(absolute))File.Delete(absolute);
    }
    private void TestV2Migration()
    {
        string current=$"res://.tmp/wuhan-migrate-v3-{Guid.NewGuid():N}.json",legacy=$"res://.tmp/wuhan-migrate-v2-{Guid.NewGuid():N}.json";string legacyAbsolute=ProjectSettings.GlobalizePath(legacy);Directory.CreateDirectory(Path.GetDirectoryName(legacyAbsolute)!);
        File.WriteAllText(legacyAbsolute,"{\"Version\":2,\"Coins\":777,\"HighestUnlockedDay\":15,\"PurchasedStoveLevel\":3,\"PurchasedIngredientStationLevel\":2,\"PurchasedFryerLevel\":3,\"UnlockedUpgradeIds\":[],\"DayBestRecords\":{},\"LastDayPlan\":null,\"TianjinBestStars\":1,\"TianjinCompleted\":true,\"UnlockedCityIds\":[\"city:wuhan\"]}");
        var save=new SaveService();AddChild(save);save.UsePathsForTests(current,legacy);Check(save.MigratedLegacySave&&save.Data.Version==3&&save.Data.Coins==777&&save.Data.PurchasedStoveLevel==3&&save.Data.Wuhan.HighestUnlockedDay==1,"V2 存档无损迁移并建立武汉进度");string backup=save.CorruptBackupPath;save.QueueFree();foreach(string path in new[]{ProjectSettings.GlobalizePath(current),legacyAbsolute,backup})if(path.Length>0&&File.Exists(path))File.Delete(path);
    }
    private void Check(bool value,string name){if(value){_passed++;GD.Print($"PASS {name}");}else{_failed++;GD.PushError($"FAIL {name}");}}
}
