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
    private static readonly Vector2I[] CaptureSizes = { new(1920,1080), new(1280,720), new(1600,720) };
    private string CaptureDirectory => OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--capture-dir=", StringComparison.Ordinal))?[14..]
        ?? "res://.impeccable/review/ledger-book-v3";
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
                if(city is "Tianjin" or "Wuhan" or "Xian")
                {
                    foreach(var size in CaptureSizes)
                    {
                        GetWindow().ContentScaleAspect=Window.ContentScaleAspectEnum.Expand;GetWindow().Size=size;await Frames(5);view.Open(Fixture(city.ToLowerInvariant()));view.FinishAnimation();await Frames();
                        CheckArtPage(view,city.ToLowerInvariant(),"summary");
                        if(Capture)await Shot($"{city}-{size.X}-summary");
                        view.SelectPage(true);await Frames();CheckArtPage(view,city.ToLowerInvariant(),"details");
                        if(Capture)await Shot($"{city}-{size.X}-details");
                    }
                }
                view.Open(Fixture(city.ToLowerInvariant()));view.FinishAnimation();await Frames();
                Check(view.Descendants<TextureRect>().Any(t => t.IsVisibleInTree() && t.Texture is AtlasTexture a && a.Atlas.ResourcePath.Contains("/BookUI/")) == (city is "Tianjin" or "Wuhan" or "Xian"), city + " artwork skin remains city scoped");
                if (city is "Tianjin" or "Wuhan" or "Xian")
                {
                    var images = view.Descendants<TextureRect>().Where(t => t.IsVisibleInTree()).ToArray();
                    var divider = images.First(t => t.Texture is AtlasTexture a && a.Atlas.ResourcePath.EndsWith("账本轻分隔线.png"));
                    Check(divider.Material is ShaderMaterial material && material.GetShaderParameter("accent").AsColor() == CitySettlementTheme.For(city.ToLowerInvariant()).Divider, city + " separator uses own city palette");
                }
                view.SelectFilter(BookFilter.Incorrect);Check(view.Model.Filter(BookFilter.Incorrect).Single().Number==4,"filter retains original numbering");
                Click(view.CloseButton);await Frames();Check(returned,city+" close book returns home");
                screen.QueueFree();controller.QueueFree();await Frames();
            }
            GetWindow().Size=CaptureSizes[0];await Frames(5);
            foreach(string city in new[]{"tianjin","wuhan","xian"})await CheckArtEdges(city);
            // Save failure and retry use the same snapshot and prevent an Esc bypass.
            var d=catalog.GetDays(StableIds.Cities.Xian)[2];var plan=new OrderGenerator().Generate(d,catalog.RecipesById,catalog.ProductsById,catalog.CustomersById);
            string bad="res://.tmp/book-tests/bad-"+Guid.NewGuid();Directory.CreateDirectory(ProjectSettings.GlobalizePath(bad));save.UsePathForTests(bad);
            var failed=BusinessBookSettlement.Commit(Fixture("xian"),save,plan,d,catalog);Check(failed.CanRetry&&!failed.CanClose&&failed.Stickers.Length==0,"failed commit state");
            var v=new BusinessDetailsView();AddChild(v);bool close=false,requestedRetry=false;
            v.CloseRequested+=()=>close=true;v.RetryRequested+=()=>requestedRetry=true;v.Open(failed);v.FinishAnimation();await Frames();
            CheckArtPage(v,"xian","real save exception summary");
            var saveMessage=v.Descendants<Label>().Single(l=>l.Text==failed.SaveMessage);
            Check(saveMessage.MaxLinesVisible==2&&saveMessage.GetVisibleLineCount()<=2&&saveMessage.TooltipText==failed.SaveMessage&&saveMessage.MouseFilter!=Control.MouseFilterEnum.Ignore,"real save exception is bounded and exposes its complete message in a usable tooltip");
            Click(v.Descendants<Button>().Single(b=>b.Text=="重试保存"));Check(requestedRetry,"real save exception leaves retry clickable");
            Click(v.Descendants<Button>().Single(b=>b.Text=="统计说明"));await Frames();CheckStaticPaperBounds(v,"real save exception with statistics explanation");
            var explanation=v.Descendants<Label>().Single(l=>l.Text.StartsWith("完成率按已结束客单",StringComparison.Ordinal));
            var info=v.Descendants<Button>().Single(b=>b.Text=="统计说明");
            Check(!saveMessage.GetGlobalRect().Intersects(explanation.GetGlobalRect())&&!saveMessage.GetGlobalRect().Intersects(info.GetGlobalRect()),"real save exception does not overlap footer statistics");
            if(Capture)await Shot("xian-save-exception-summary");
            v.SelectPage(true);await Frames();CheckArtPage(v,"xian","real save exception details");
            if(Capture)await Shot("xian-save-exception-details");
            GetViewport().PushInput(new InputEventKey { Keycode=Key.Escape,Pressed=true },true);Check(!close,"Esc cannot bypass failed save");v.QueueFree();
            save.UsePathForTests("res://.tmp/book-tests/retry-"+Guid.NewGuid()+".json");int before=save.Data.Coins;
            var good=BusinessBookSettlement.Commit(Fixture("xian"),save,plan,d,catalog);Check(good.CanClose&&!good.CanRetry,"retry saves");int after=save.Data.Coins;
            BusinessBookSettlement.Commit(Fixture("xian"),save,plan,d,catalog);Check(save.Data.Coins==after&&after>=before,"replay only pays best delta");
            BusinessBookSettlement.Commit(Fixture("guangzhou"),save,plan,d,catalog,practice:true);Check(save.Data.Coins==after,"practice doesn't save");
            GD.Print($"BUSINESS_BOOK_TEST_RESULT passed={_checks} failed=0");GetTree().Quit();
        }
        catch(Exception e) {GD.PushError(e.ToString());GetTree().Quit(1);}
    }
    private void CheckArtPage(BusinessDetailsView view, string city, string page)
    {
        string expected = city switch
        {
            "tianjin" => "res://resource/art/TianJin/Ledger/ledger_book.png",
            "wuhan" => "res://resource/art/Global/BookUI/营业结算账本底板-武汉-v3.png",
            "xian" => "res://resource/art/Global/BookUI/营业结算账本底板-西安-v3.png",
            _ => throw new ArgumentOutOfRangeException(nameof(city)),
        };
        Check(BookArtCatalog.BoardPath(city)==expected,city+" board resolves complete resource path");
        Check(ReferenceEquals(BookArtCatalog.GetBoard(city),BookArtCatalog.GetBoard(city)),city+" board reuses texture cache");
        var board=view.Descendants<TextureRect>().Single(t=>t.IsVisibleInTree()&&t.Name=="BookBoard");
        Check(board.Texture is AtlasTexture boardAtlas&&boardAtlas.Atlas.ResourcePath==expected&&board.Material is null&&board.Modulate==Colors.White&&board.SelfModulate==Colors.White,city+" "+page+" uses city board without additional tint");
        Check(board.StretchMode==TextureRect.StretchModeEnum.KeepAspectCentered,city+" "+page+" preserves artwork aspect ratio");
        var book=board.GetParent().GetParent<Control>();
        Check(book.Size==new Vector2(1680,900)&&book.Scale==Vector2.One,city+" book retains design container without horizontal compression");
        var semanticNames=new[]{"总收入图标.png","小费图标.png","完成顾客图标.png","流失顾客图标.png","满意度图标.png","Perfect 图标.png","Perfect 印章.png","状态章-正确完成.png","状态章-错误完成.png","状态章-顾客流失.png"};
        var semantic=view.Descendants<TextureRect>().Where(t=>t.IsVisibleInTree()&&t.Texture is AtlasTexture a&&semanticNames.Any(n=>a.Atlas.ResourcePath.EndsWith(n,StringComparison.Ordinal))).ToArray();
        Check(semantic.Length>0&&semantic.All(t=>t.Material is null&&t.Modulate==Colors.White&&t.SelfModulate==Colors.White),city+" "+page+" preserves semantic icon colors");
        Check(view.Descendants<BookFoodIcon>().Where(t=>t.IsVisibleInTree()).All(t=>t.Material is null&&t.Modulate==Colors.White&&t.SelfModulate==Colors.White),city+" "+page+" preserves natural food colors");
        foreach(var widget in book.Descendants<Control>().Where(c=>c.IsVisibleInTree()&&c!=board&&(c is Label or Button or TextureRect or BookFoodIcon)))
        {
            bool inScroll=false;
            for(Node? ancestor=widget.GetParent();ancestor is not null&&ancestor!=book;ancestor=ancestor.GetParent())if(ancestor is ScrollContainer){inScroll=true;break;}
            if(inScroll)continue;
            var bounds=InLocalSpace(book,widget);
            Check(InPaperColumn(bounds)&&bounds.Position.Y>=77&&bounds.End.Y<=826,$"{city} {page} {WidgetText(widget)} stays inside paper: {bounds}");
        }
    }
    private async Task CheckArtEdges(string city)
    {
        var stress=new BusinessDetailsView();AddChild(stress);
        string food=Fixture(city).Orders[0].Products[0].Name;
        var longOrder=new BookOrder(1,"long","赶着去码头上早班又要给同事带早餐的街坊熟客", "male_office",
            Enumerable.Range(0,6).Select(i=>new BookProduct("long"+i,food+"双份加料香葱少酱特别早餐套餐请单独打包给同行客人，并注明每份不同口味和酱料要求以及额外配料",2,Fixture(city).Orders[0].Products[0].Visual,"加料少酱")).ToArray(),
            BookOutcome.Incorrect,20,0,55,"出餐时配料与客人点单不一致，请留意多份商品各自的配料和酱量要求，并在交付前再次确认每一份商品。");
        stress.Open(new BusinessBookModel{CityId=city,Orders=new[]{longOrder},Result=new(){CompletedCustomers=1,SaleRevenue=20,Satisfaction=55},SaveMessage="演示数据 · 长名称与多商品边界"});
        stress.SelectPage(true);await Frames();CheckArtPage(stress,city,"long details");
        var scroll=stress.Descendants<ScrollContainer>().Single();
        var orderRow=scroll.GetChild<VBoxContainer>(0).GetChild<Control>(0);
        var labels=orderRow.GetChildren().OfType<Label>().ToArray();
        var products=labels.Where(l=>l.Text.Contains("特别早餐套餐",StringComparison.Ordinal)).OrderBy(l=>l.Position.Y).ToArray();
        Check(products.Length==6&&products.All(l=>l.Size.X<=503&&l.GetLineCount()>1&&l.GetVisibleLineCount()==l.GetLineCount()),city+" long products wrap completely inside their column");
        Check(products.Select(l=>l.Position.X).Distinct().Count()==1&&products.Zip(products.Skip(1),(a,b)=>a.Position.Y+a.Size.Y<=b.Position.Y).All(ok=>ok),city+" multiple products form a single nonoverlapping column");
        Check(orderRow.Size.Y>scroll.Size.Y&&labels.All(l=>l.Position.Y+l.Size.Y<=orderRow.Size.Y-8),city+" long order grows to fit customer, products and reason");
        var score=labels.Single(l=>l.Text.StartsWith("评分",StringComparison.Ordinal));
        var revenue=labels.Single(l=>l.Text.StartsWith("收入",StringComparison.Ordinal));
        Check(score.Position.Y>=revenue.Position.Y+revenue.Size.Y,city+" score occupies its own line");
        var board=stress.Descendants<TextureRect>().Single(t=>t.Name=="BookBoard");
        var book=board.GetParent().GetParent<Control>();
        Check(orderRow.Descendants<Control>().Where(c=>c is Label or TextureRect or BookFoodIcon).All(c=>InPaperColumn(InLocalSpace(book,c))),city+" long order avoids spine and page edges");
        if(Capture)await Shot(city+"-long-details-top");
        scroll.ScrollVertical=int.MaxValue;await Frames();Check(scroll.ScrollVertical>0,city+" long order can scroll to its final product");
        if(Capture)await Shot(city+"-long-details-bottom");
        stress.SelectFilter(BookFilter.Lost);await Frames();Check(stress.Descendants<Label>().Any(l=>l.Text.Contains("这一类客单",StringComparison.Ordinal)),city+" empty filter feedback");
        if(Capture)await Shot(city+"-empty-filter");
        stress.Open(new BusinessBookModel{CityId=city});stress.FinishAnimation();await Frames();
        Check(stress.Model.Satisfaction is null,city+" empty live summary");
        CheckStaticPaperBounds(stress,city+" empty summary");
        if(Capture)await Shot(city+"-empty-summary");
        var stickerFixture=Fixture(city);stickerFixture.Stickers=new[]{"本次评级 ★★★","章节已点亮","新开放 2 项内容 · 回店查看","可升级：早餐摊等3项"};
        stress.Open(stickerFixture);stress.FinishAnimation();await Frames();CheckArtPage(stress,city,"double stickers");
        var unlock=stress.FindChild("UnlockSticker",true,false) as Control;
        var upgrade=stress.FindChild("UpgradeSticker",true,false) as Control;
        Check(unlock is not null&&upgrade is not null&&!unlock.GetGlobalRect().Intersects(upgrade.GetGlobalRect()),city+" unlock and upgrade stickers coexist without overlap");
        if(Capture)await Shot(city+"-unlocks-summary");
        stickerFixture.CanClose=false;stickerFixture.CanRetry=true;stickerFixture.Stickers=Array.Empty<string>();
        stickerFixture.SaveMessage="未保存 · 存档暂时无法写入；本次金币与进度已回退。";
        stress.Open(stickerFixture);stress.FinishAnimation();await Frames();CheckArtPage(stress,city,"failed save");
        Check(stress.CloseButton.Disabled,city+" skin respects disabled close");
        bool retried=false;stress.RetryRequested+=()=>retried=true;
        var retry=stress.Descendants<Button>().Single(b=>b.Text=="重试保存");
        Click(retry);Check(retried,city+" visible retry button remains clickable");
        Click(stress.Descendants<Button>().Single(b=>b.Text=="统计说明"));await Frames();CheckStaticPaperBounds(stress,city+" statistics explanation");
        if(Capture)await Shot(city+"-unsaved-summary");
        stress.QueueFree();await Frames();
    }
    private void CheckStaticPaperBounds(BusinessDetailsView view,string scenario)
    {
        var board=view.Descendants<TextureRect>().Single(t=>t.Name=="BookBoard");
        var book=board.GetParent().GetParent<Control>();
        var controls=book.Descendants<Control>().Where(c=>c.IsVisibleInTree()&&(c is Label or Button));
        foreach(var control in controls)
        {
            var bounds=InLocalSpace(book,control);
            Check(InPaperColumn(bounds)&&bounds.Position.Y>=77&&bounds.End.Y<=826,$"{scenario} {WidgetText(control)} stays inside paper: {bounds}");
        }
    }
    private static Rect2 InLocalSpace(Control parent,Control child)
    {
        var inverse=parent.GetGlobalTransform().AffineInverse();
        var rect=child.GetGlobalRect();
        var start=inverse*rect.Position;
        return new Rect2(start,inverse*rect.End-start);
    }
    private static bool InPaperColumn(Rect2 bounds) =>
        (bounds.Position.X>=229&&bounds.End.X<=791)||(bounds.Position.X>=889&&bounds.End.X<=1451);
    private static string WidgetText(Control widget)=>widget is Label label?label.Text:widget is Button button?button.Text:widget.Name.ToString();
    private async Task Shot(string name)
    {
        await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        string dir=ProjectSettings.GlobalizePath(CaptureDirectory);Directory.CreateDirectory(dir);
        using var image=GetViewport().GetTexture().GetImage();
        Check(image.GetWidth()==GetWindow().Size.X && image.GetHeight()==GetWindow().Size.Y,$"capture dimensions {name}: {image.GetWidth()}x{image.GetHeight()} vs {GetWindow().Size}");
        Check(image.SavePng(dir+"/"+name+".png")==Error.Ok,"capture saved "+name);
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
