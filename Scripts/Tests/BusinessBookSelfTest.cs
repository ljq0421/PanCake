using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Yangzhou;
using ProjectCake.Orders;
namespace ProjectCake.Tests;

public partial class BusinessBookSelfTest : Node
{
    private int _checks;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private void Check(bool ok, string message) { if (!ok) throw new InvalidOperationException(message); _checks++; }
    private async Task Frames(int n = 3) { for(int i=0;i<n;i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private void Click(Control node) { var p=node.GetGlobalRect().GetCenter(); foreach(bool pressed in new[]{true,false}) GetViewport().PushInput(new InputEventMouseButton { Position=p, GlobalPosition=p, Pressed=pressed, ButtonIndex=MouseButton.Left },true); }
    public override async void _Ready()
    {
        try
        {
            GetWindow().Position = new(-10000,-10000);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog"); Check(catalog.IsValid,"catalog valid");
            var empty = new BusinessBookModel(); Check(empty.CompletionRate is null && empty.Satisfaction is null && empty.BestSeller is null,"empty aggregates");
            var m=Fixture("tianjin"); Check(m.Filter(BookFilter.Completed).Count()==4 && m.Filter(BookFilter.Incorrect).Count()==1 && m.Filter(BookFilter.Lost).Count()==9,"overlapping complete and error filters");
            Check(Math.Abs(m.CompletionRate!.Value-400d/13)<.001 && m.DailyNote.Contains("等太久"),"ratio and deterministic note");
            Check(m.BestSeller!.Id=="a" && m.BestSeller.Quantity==4,"completed-only best seller and stable ties");
            var yc = YangzhouCatalog.Load(); var ys=new YangzhouSession(yc,2,1,0); ys.Tick(500);
            var ym=YangzhouBusinessBook.Snapshot(ys,yc); Check(ym.Orders.Count==ys.Result().Lost && ym.Orders.All(o=>o.Lost && o.Score is null),"Yangzhou lost snapshots match ledger");
            int count=ys.BusinessRecords.Count;ys.Tick(500);Check(ys.BusinessRecords.Count==count,"outcomes never duplicate");
            Check(ym.Orders.Select(o=>o.Id).Distinct().Count()==count,"unique Yangzhou IDs");
            var save = new SaveService(); save.UsePathForTests("res://.tmp/book-tests/"+Guid.NewGuid()+".json"); AddChild(save);
            save.Data.Yangzhou.HighestUnlockedDay=2;
            var yzUnlock=YangzhouBusinessBook.Commit(ys,yc,save,false);
            Check(yzUnlock.Stickers.Any(t=>t.Contains("新设备"))&&yzUnlock.Stickers.Any(t=>t.Contains("新菜品")),"Yangzhou only announces actual new equipment and menu");
            foreach(var id in new[]{StableIds.Cities.Tianjin,StableIds.Cities.Wuhan,StableIds.Cities.Xian,StableIds.Cities.Guangzhou,YangzhouCatalog.CityId}) save.Data.GetCity(id).HighestUnlockedDay=15;
            foreach(string city in new[]{"Tianjin","Wuhan","Xian","Guangzhou","Yangzhou"})
            {
                var controller=new DayController();AddChild(controller);controller.SetProcess(false);
                var screen=GD.Load<PackedScene>($"res://Scenes/Gameplay/{city}DayScreen.tscn").Instantiate<Control>(); AddChild(screen);screen.SetProcess(false);
                BusinessDetailsView view; Button entry;
                switch(screen)
                {
                    case TianjinDayScreen s: s.ConnectController(controller);s.Initialize(catalog,save,controller,2);s.BeginDay();controller.Tick(3.1);s.RefreshForCapture(true);view=s.BusinessDetails;entry=s.CashPendant;break;
                    case WuhanDayScreen s: s.ConnectController(controller);s.Initialize(catalog,save,controller,2);s.BeginDay();controller.Tick(3.1);s.RefreshForCapture();view=s.BusinessDetails;entry=s.CashPendant;break;
                    case XianDayScreen s: Check(s.Initialize(catalog,save,controller,2),"Xian initialize");s.BeginDay();controller.Tick(3.1);s.Render();view=s.BusinessDetails;entry=s.FindChild("OpenBusinessBook",true,false) as Button ?? throw new Exception();break;
                    case GuangzhouDayScreen s: Check(s.Initialize(catalog,save,controller,2),"Guangzhou initialize");s.BeginDay();controller.Tick(3.1);s._Process(0);view=s.BusinessDetails;entry=s.FindChild("OpenBusinessBook",true,false) as Button ?? throw new Exception();break;
                    case YangzhouDayScreen s: Check(s.Initialize(yc,save,2),"Yangzhou initialize");s.Session.Tick(5.1);s._Process(0);view=s.BusinessDetails;entry=s.FindChild("OpenBusinessBook",true,false) as Button ?? throw new Exception();break;
                    default:throw new Exception();
                }
                if (screen is GuangzhouDayScreen gz)
                {
                    controller.CustomerQueue!.Tick(1000,.4,true);gz._Process(0);await Frames();
                    var cards=gz.Descendants<GuangzhouCustomerCard>().OrderBy(c=>c.Position.X).ToArray();
                    Check(cards.Length==5 && !cards[4].Disabled,"fifth Guangzhou customer renders and accepts input");
                    Click(cards[4]);Check(controller.CustomerQueue.SelectedCustomerId==controller.CustomerQueue.CustomerAtSlot(4)!.Id,"fifth Guangzhou customer selectable");
                    if(Capture)await Shot("Guangzhou-five-customers");
                }
                if (screen is YangzhouDayScreen yzFive)
                {
                    var planned=(List<YangzhouPlannedOrder>)yzFive.Session.Plan;
                    for(int i=0;i<planned.Count;i++)planned[i]=planned[i] with { Arrival=0 };
                    yzFive.Session.Tick(20);yzFive._Process(0);await Frames();
                    var fifth=yzFive.FindChild("Customer3BookFifth",true,false) as Button;
                    Check(yzFive.Session.Waiting.Count==5 && fifth is { Disabled:false },$"fifth Yangzhou table renders: waiting={yzFive.Session.Waiting.Count},paused={yzFive.Session.Paused},fifth={fifth?.Disabled}");
                    Click(fifth!);Check(yzFive.Session.SelectedId==yzFive.Session.Waiting[4].Plan.Id,"fifth Yangzhou table selectable");
                    if(Capture)await Shot("Yangzhou-five-customers");
                }
                await Frames();Click(entry);await Frames();Check(view.Visible&&!view.Model.Closing,city+" live entry");
                Click(view.Descendants<Button>().Single(b=>b.Text=="顾客明细"));await Frames();Check(view.DetailVisible,city+" real tab click");
                var errorFilter=view.Descendants<Button>().Single(b=>b.Text.StartsWith("错误 "));Check(!errorFilter.Disabled,city+" filters enabled");Click(errorFilter);
                Click(view.Descendants<Button>().Single(b=>b.Text=="今日小结"));await Frames();Check(!view.DetailVisible,city+" summary tab click");
                double time=controller.DayElapsedSeconds;
                if(screen is YangzhouDayScreen yz) { double elapsed=yz.Session.Elapsed;yz._Process(10);Check(yz.Session.Elapsed==elapsed,"Yangzhou book pauses"); }
                else { screen.Call("_Process",10d);Check(controller.DayElapsedSeconds==time,city+" book pauses"); }
                GetViewport().PushInput(new InputEventKey { Keycode=Key.Escape,Pressed=true },true);await Frames();Check(!view.Visible,city+" closes live book");
                // Actual closing path must commit once and replace its old modal.
                if(screen is YangzhouDayScreen y) { y.Session.Tick(1000);y._Process(0); }
                else {controller.Tick(1000);controller.Tick(1000);}
                await Frames();Check(view.Visible && view.Model.Closing,city+" real closing uses shared book");
                int coins=save.Data.Coins;view.SelectPage(true);view.SelectPage(false);Check(save.Data.Coins==coins,"tabs cannot settle twice");
                bool returned=false;
                switch(screen) {case TianjinDayScreen s:s.HubRequested+=()=>returned=true;break;case WuhanDayScreen s:s.HubRequested+=()=>returned=true;break;case XianDayScreen s:s.HubRequested+=()=>returned=true;break;case GuangzhouDayScreen s:s.HubRequested+=()=>returned=true;break;case YangzhouDayScreen s:s.HubRequested+=()=>returned=true;break;}
                if(Capture)
                {
                    foreach(var size in new[]{new Vector2I(1920,1080),new Vector2I(1280,720),new Vector2I(1600,720)})
                    {
                        GetWindow().ContentScaleAspect=Window.ContentScaleAspectEnum.Expand;GetWindow().Size=size;await Frames(5);view.Open(Fixture(city.ToLowerInvariant()));view.FinishAnimation();await Frames();
                        await Shot($"{city}-{size.X}-summary");view.SelectPage(true);await Frames();await Shot($"{city}-{size.X}-details");
                    }
                }
                view.Open(Fixture(city.ToLowerInvariant()));view.FinishAnimation();await Frames();
                Check(view.Descendants<TextureRect>().Any(t => t.IsVisibleInTree() && t.Texture is AtlasTexture a && a.Atlas.ResourcePath.Contains("/BookUI/")) == (city is "Tianjin" or "Wuhan" or "Xian"), city + " artwork skin remains city scoped");
                if (city is "Tianjin" or "Wuhan" or "Xian")
                {
                    var images = view.Descendants<TextureRect>().Where(t => t.IsVisibleInTree()).ToArray();
                    Check(images.Any(t => t.Texture is AtlasTexture a && a.Atlas.ResourcePath == "res://resource/art/Global/BookUI/营业结算账本底板-v1.png"), city + " loads global v1 board");
                    Check(images.Where(t => t.Texture is AtlasTexture a && (a.Atlas.ResourcePath.EndsWith("总收入图标.png") || a.Atlas.ResourcePath.EndsWith("Perfect 印章.png"))).All(t => t.Material is null), city + " semantic artwork remains unfiltered");
                    var divider = images.First(t => t.Texture is AtlasTexture a && a.Atlas.ResourcePath.EndsWith("账本轻分隔线.png"));
                    Check(divider.Material is ShaderMaterial material && material.GetShaderParameter("accent").AsColor() == CitySettlementTheme.For(city.ToLowerInvariant()).Divider, city + " separator uses own city palette");
                }
                view.SelectFilter(BookFilter.Incorrect);Check(view.Model.Filter(BookFilter.Incorrect).Single().Number==4,"filter retains original numbering");
                Click(view.CloseButton);await Frames();Check(returned,city+" close book returns home");
                screen.QueueFree();controller.QueueFree();await Frames();
            }
            var stress = new BusinessDetailsView(); AddChild(stress);
            var longOrder = new BookOrder(1, "long", "赶着去码头上早班的街坊熟客", "male_office",
                Enumerable.Range(0, 6).Select(i => new BookProduct("long"+i, "双份火腿薄脆煎饼加香葱少酱特别早餐套餐", 2, "Pancake")).ToArray(),
                BookOutcome.Incorrect, 20, 0, 55, "出餐时配料与客人点单不一致，请留意多份商品各自的配料和酱量要求。");
            stress.Open(new BusinessBookModel { Orders = new[]{longOrder}, Result = new(){CompletedCustomers=1,SaleRevenue=20,Satisfaction=55}, SaveMessage="演示数据 · 长名称与多商品边界" });
            stress.SelectPage(true);await Frames();
            var orderRow=stress.FindChildren("*","ScrollContainer",true,false).OfType<ScrollContainer>().Single().GetChild<VBoxContainer>(0).GetChild<Control>(0);
            Check(orderRow.GetChildren().OfType<Label>().Where(l=>l.Text.Contains("特别早餐套餐")).All(l=>l.Size.X<=238 && l.Size.Y>48),"long products stay inside their own column");
            Check(orderRow.Size.Y>230 && orderRow.GetChildren().OfType<Label>().All(l=>l.Position.Y+l.Size.Y<=orderRow.Size.Y),"long names and multi-product rows grow without clipping");
            if(Capture)await Shot("edge-long-order");
            stress.SelectFilter(BookFilter.Lost);await Frames();Check(stress.Descendants<Label>().Any(l=>l.Text.Contains("这一类客单")),"empty filter feedback");
            if(Capture)await Shot("Tianjin-empty-filter");
            stress.Open(new BusinessBookModel());await Frames();Check(stress.Model.Satisfaction is null,"empty live summary");
            stress.FinishAnimation();if(Capture)await Shot("Tianjin-empty-summary");
            var stickerFixture=Fixture("tianjin");stickerFixture.Stickers=new[]{"本次评级 ★★★","天津章节已点亮","新开放 2 项内容 · 回店查看","可升级：煎饼摊等3项"};
            stress.Open(stickerFixture);stress.FinishAnimation();await Frames();if(Capture)await Shot("Tianjin-unlocks-summary");
            stickerFixture.CanClose=false;stickerFixture.CanRetry=true;stickerFixture.Stickers=Array.Empty<string>();stickerFixture.SaveMessage="未保存 · 存档暂时无法写入；本次金币与进度已回退。";
            stress.Open(stickerFixture);stress.FinishAnimation();await Frames();Check(stress.CloseButton.Disabled,"Tianjin skin respects disabled close");if(Capture)await Shot("Tianjin-unsaved-summary");
            stress.QueueFree();await Frames();
            // Save failure and retry use the same snapshot and prevent an Esc bypass.
            var d=catalog.GetDays(StableIds.Cities.Xian)[2];var plan=new OrderGenerator().Generate(d,catalog.RecipesById,catalog.ProductsById,catalog.CustomersById);
            string bad="res://.tmp/book-tests/bad-"+Guid.NewGuid();Directory.CreateDirectory(ProjectSettings.GlobalizePath(bad));save.UsePathForTests(bad);
            var failed=BusinessBookSettlement.Commit(Fixture("xian"),save,plan,d,catalog);Check(failed.CanRetry&&!failed.CanClose&&failed.Stickers.Length==0,"failed commit state");
            var v=new BusinessDetailsView();AddChild(v);bool close=false;v.CloseRequested+=()=>close=true;v.Open(failed);GetViewport().PushInput(new InputEventKey { Keycode=Key.Escape,Pressed=true },true);Check(!close,"Esc cannot bypass failed save");v.QueueFree();
            save.UsePathForTests("res://.tmp/book-tests/retry-"+Guid.NewGuid()+".json");int before=save.Data.Coins;
            var good=BusinessBookSettlement.Commit(Fixture("xian"),save,plan,d,catalog);Check(good.CanClose&&!good.CanRetry,"retry saves");int after=save.Data.Coins;
            BusinessBookSettlement.Commit(Fixture("xian"),save,plan,d,catalog);Check(save.Data.Coins==after&&after>=before,"replay only pays best delta");
            BusinessBookSettlement.Commit(Fixture("guangzhou"),save,plan,d,catalog,practice:true);Check(save.Data.Coins==after,"practice doesn't save");
            GD.Print($"BUSINESS_BOOK_TEST_RESULT passed={_checks} failed=0");GetTree().Quit();
        }
        catch(Exception e) {GD.PushError(e.ToString());GetTree().Quit(1);}
    }
    private async Task Shot(string name)
    {
        await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        string dir=ProjectSettings.GlobalizePath("res://.impeccable/review/global-book-ui");Directory.CreateDirectory(dir);
        using var image=GetViewport().GetTexture().GetImage();
        Check(image.GetWidth()==GetWindow().Size.X && image.GetHeight()==GetWindow().Size.Y,$"capture dimensions {name}: {image.GetWidth()}x{image.GetHeight()} vs {GetWindow().Size}");image.SavePng(dir+"/"+name+".png");
    }
    private static BusinessBookModel Fixture(string city)
    {
        (string food,string visual,string drink,string dv)=city switch {"wuhan"=>("牛肉热干面","HotDryNoodles","蛋酒","EggRiceWine"),"xian"=>("多肉加汁肉夹馍","Roujiamo","胡辣汤","Hulatang"),"guangzhou"=>("鲜虾肠粉","RiceRoll","早茶","MorningTea"),"yangzhou"=>("扬州烫干丝","G01","龙井茶","T01"),_=>("火腿薄脆煎饼","Pancake","豆浆","SoyMilk")};
        var rows=Enumerable.Range(1,13).Select(i=>new BookOrder(i,"order-"+i,i%2==0?"赶时间上班族":"街坊老熟客",i%2==0?"male_office":"elder_regular",
            new[]{new BookProduct("a",food,1,visual),new BookProduct("b",drink,1,dv)},i>4?BookOutcome.Lost:i<=2?BookOutcome.Perfect:i==4?BookOutcome.Incorrect:BookOutcome.Correct,i<=4?i==4?10:13:0,i==1?3:0,i<=4?85:null,i==4?"配料与客人的点单不符":"")).ToArray();
        return new(){CityId=city,Closing=true,Result=new(){Day=2,CompletedCustomers=4,LostCustomers=9,SaleRevenue=49,Tips=3,Satisfaction=85,PerfectOrders=2},Orders=rows,
            SaveMessage="演示数据 · 已入账 ¥52 · 新纪录",ExtraNotes=new[]{"最高连续正确 3 单"},Stickers=new[]{"有设备可以升级 · 回店查看"}};
    }
}
