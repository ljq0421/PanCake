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
        GD.Print($"WUHAN_TEST_RESULT passed={_passed} failed={_failed}"); GetTree().Quit(_failed==0?0:1);
    }
    private void TestData(DataCatalog c)
    {
        var days=c.GetDays(StableIds.Cities.Wuhan);Check(c.IsValid,"全量数据目录校验通过");Check(days.Count==12,"武汉包含 Day 1～12");Check(days.Values.Sum(d=>d.DurationSeconds)==1400,"营业时长合计 1400 秒");Check(days.Values.Sum(d=>d.ExpectedRevenue)==2389,"预计收入合计 2389");Check(c.NoodleCookersByLevel.Values.Sum(x=>x.UpgradePrice)+c.DoupiGriddlesByLevel.Values.Sum(x=>x.UpgradePrice)+c.WuhanIngredientStationsByLevel.Values.Sum(x=>x.UpgradePrice)==2000,"升级价格合计 2000");Check(ProjectCake.UI.TianjinMapScreen.CanEnterCity(false,true)&&!ProjectCake.UI.TianjinMapScreen.CanEnterCity(false,false)&&ProjectCake.UI.TianjinMapScreen.CanEnterCity(true,false),"开发测试入口可绕过城市前置解锁");
    }
    private void TestOrders(DataCatalog c)
    {
        DayConfig d=c.GetDays(StableIds.Cities.Wuhan)[12];DayPlan a=new OrderGenerator().Generate(d,c.RecipesById,c.ProductsById,c.CustomersById);DayPlan b=new OrderGenerator().Generate(d,c.RecipesById,c.ProductsById,c.CustomersById);
        Check(a.Customers.Select(x=>x.CustomerTypeId).SequenceEqual(b.Customers.Select(x=>x.CustomerTypeId)),"固定种子结果可重现");
        var people=a.Customers.GroupBy(x=>x.CustomerTypeId).ToDictionary(x=>x.Key,x=>x.Count());Check(people["wuhan_normal"]==9&&people["wuhan_office_worker"]==5&&people["wuhan_regular"]==4&&people["wuhan_tourist"]==4&&people["wuhan_big_order"]==4,"Day 12 顾客精确配额");
        var orders=a.Customers.GroupBy(x=>x.Order.OrderTypeId).ToDictionary(x=>x.Key,x=>x.Count());Check(orders["hot_dry_noodles"]==4&&orders["doupi"]==1&&orders["egg_rice_wine"]==1&&orders["noodles_doupi"]==5&&orders["noodles_egg_rice_wine"]==7&&orders["wuhan_full_combo"]==8,"Day 12 订单精确配额");
        Check(!a.Customers.Zip(a.Customers.Skip(1)).Any(pair=>pair.First.CustomerTypeId=="wuhan_big_order"&&pair.Second.CustomerTypeId=="wuhan_big_order"),"大单顾客不连续");int run=0,max=0;foreach(var x in a.Customers){run=x.Order.OrderTypeId=="wuhan_full_combo"?run+1:0;max=Math.Max(max,run);}Check(max<=2,"F 类最多连续两单");
        var allBig=new List<string>();for(int day=9;day<=12;day++)foreach(var x in new OrderGenerator().Generate(c.GetDays(StableIds.Cities.Wuhan)[day],c.RecipesById,c.ProductsById,c.CustomersById).Customers.Where(x=>x.CustomerTypeId=="wuhan_big_order"))allBig.Add(x.Order.OrderTypeId);Check(allBig.Count==9&&allBig.GroupBy(x=>x).All(g=>g.Count()==3),"三种大单跨章节各出现三次");
    }
    private void TestNoodles(DataCatalog c)
    {
        var lv1=new NoodleCookerStateMachine(c.NoodleCookersByLevel[1]);Check(lv1.TryStart(0),"Lv1 面条下锅");lv1.Tick(1.6);Check(lv1.Baskets[0].State==NoodleBasketState.Ready,"1.6 秒进入最佳");lv1.Tick(1.5);Check(lv1.Baskets[0].State==NoodleBasketState.Soft,"超过 3 秒偏软");lv1.Tick(1);Check(lv1.Baskets[0].State==NoodleBasketState.Overcooked,"超过 4 秒煮过头");
        var lv2=new NoodleCookerStateMachine(c.NoodleCookersByLevel[2]);lv2.TryStart(0);lv2.Tick(5);Check(lv2.Baskets[0].State==NoodleBasketState.Locked,"Lv2 最佳点锁熟且不自动提篮");
        var lv3=new NoodleCookerStateMachine(c.NoodleCookersByLevel[3]);lv3.TryStart(0);lv3.TryStart(1);lv3.Tick(1.3);Check(lv3.Baskets.All(x=>x.State==NoodleBasketState.Draining),"Lv3 双漏勺独立自动提篮");
        var bowl=new HotDryNoodlesStateMachine();bowl.TryAddNoodles(NoodleQuality.Optimal);bowl.TryAddBaseSeasoning();bowl.AddMixDistance(425);Check(bowl.State==NoodleBowlState.Ready&&bowl.MixProgress==100,"拌匀 85% 自动吸附至 100%");
    }
    private void TestDoupi(DataCatalog c)
    {
        var stock=new DoupiInventory();var machine=new DoupiStateMachine(c.DoupiGriddlesByLevel[1]);MakeBatch(machine,stock);Check(stock.Count==8,"豆皮一锅固定八块");MakeBatch(machine,stock);Check(stock.Count==16,"豆皮备餐盘容量十六块");var third=new DoupiStateMachine(c.DoupiGriddlesByLevel[1]);third.TryPourBatter();third.TryAddEgg();third.Tick(2.5);third.TryFlip();third.TryAddFilling();third.Tick(3.5);foreach(var direction in Enum.GetValues<DoupiCutDirection>())third.TryCut(direction);Check(third.TransferAvailable(stock)==0&&third.State==DoupiState.Cut,"库存满时成品留在锅中等待");
    }
    private static void MakeBatch(DoupiStateMachine m,DoupiInventory s){m.TryPourBatter();m.TryAddEgg();m.Tick(2.5);m.TryFlip();m.TryAddFilling();m.Tick(3.5);foreach(var direction in Enum.GetValues<DoupiCutDirection>())m.TryCut(direction);m.TransferAvailable(s);}
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
        string path=$"res://.tmp/wuhan-v3-{Guid.NewGuid():N}.json";var save=new SaveService();AddChild(save);save.UsePathForTests(path);save.Data.Coins=3000;CityProgressData city=save.Data.Wuhan;city.UnlockedContentIds.Add("equipment:wuhan_ingredient_station_lv2");Check(save.TryPurchase(StableIds.Cities.Wuhan,"equipment:wuhan_ingredient_station_lv2",c,out _)&&save.Data.Coins==2880&&save.Data.PurchasedIngredientStationLevel==1,"武汉升级扣全局金币且不改变天津设备");DayConfig day12=c.GetDays(StableIds.Cities.Wuhan)[12];DayResult result=new(){Day=12,PlannedCustomers=26,CompletedCustomers=24,Satisfaction=90,PerfectOrders=15,SaleRevenue=411};DayPlan plan=new OrderGenerator().Generate(day12,c.RecipesById,c.ProductsById,c.CustomersById);save.CommitDay(result,plan,day12);Check(save.Data.Wuhan.Completed&&save.Data.Wuhan.BestStars==3&&save.Data.Wuhan.UnlockedCollectibleIds.Count==4,"武汉三星完成并保存收藏徽章");save.QueueFree();string absolute=ProjectSettings.GlobalizePath(path);if(File.Exists(absolute))File.Delete(absolute);
    }
    private void TestV2Migration()
    {
        string current=$"res://.tmp/wuhan-migrate-v3-{Guid.NewGuid():N}.json",legacy=$"res://.tmp/wuhan-migrate-v2-{Guid.NewGuid():N}.json";string legacyAbsolute=ProjectSettings.GlobalizePath(legacy);Directory.CreateDirectory(Path.GetDirectoryName(legacyAbsolute)!);
        File.WriteAllText(legacyAbsolute,"{\"Version\":2,\"Coins\":777,\"HighestUnlockedDay\":15,\"PurchasedStoveLevel\":3,\"PurchasedIngredientStationLevel\":2,\"PurchasedFryerLevel\":3,\"UnlockedUpgradeIds\":[],\"DayBestRecords\":{},\"LastDayPlan\":null,\"TianjinBestStars\":1,\"TianjinCompleted\":true,\"UnlockedCityIds\":[\"city:wuhan\"]}");
        var save=new SaveService();AddChild(save);save.UsePathsForTests(current,legacy);Check(save.MigratedLegacySave&&save.Data.Version==3&&save.Data.Coins==777&&save.Data.PurchasedStoveLevel==3&&save.Data.Wuhan.HighestUnlockedDay==1,"V2 存档无损迁移并建立武汉进度");string backup=save.CorruptBackupPath;save.QueueFree();foreach(string path in new[]{ProjectSettings.GlobalizePath(current),legacyAbsolute,backup})if(path.Length>0&&File.Exists(path))File.Delete(path);
    }
    private void Check(bool value,string name){if(value){_passed++;GD.Print($"PASS {name}");}else{_failed++;GD.PushError($"FAIL {name}");}}
}
