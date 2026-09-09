using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

/// <summary>Exercise the real Main scene, routing and uninterrupted frame processing.</summary>
public partial class WuhanMainDeliverySelfTest : Node
{
    private Node _main = null!;
    private WuhanDayScreen _day = null!;
    private int _passed;
    public override async void _Ready()
    {
        try
        {
            GetWindow().Size = OS.GetCmdlineUserArgs().Contains("--720") ? new Vector2I(1280,720) : new Vector2I(1920,1080);
            var save = GetNode<SaveService>("/root/SaveService");
            save.UsePathForTests($"res://.tmp/wuhan-main-{Guid.NewGuid():N}.json");
            save.Data.Wuhan.HighestUnlockedDay = 8;
            save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
            save.Data.Wuhan.EquipmentLevels["ingredient_station"] = 3;
            save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
            save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"] = 1;
            _main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate(); AddChild(_main);
            await Frames(4);
            await ClickButton(_main.GetNode<Control>("UI/MorningHub"), "城市地图");
            await ClickButton(_main.GetNode<Control>("UI/TianjinMapScreen"), "测试直达武汉");
            var hub = _main.GetNode<WuhanHub>("UI/WuhanHub");
            Check(hub.IsVisibleInTree(), "Main navigation opens Wuhan hub");
            await ClickButton(hub, "经营手账");
            await ClickButton(hub.GetNode<WuhanLedger>("WuhanLedger"), "开始营业 · Day 8");
            _day = _main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen");
            var controller = _main.GetNode<DayController>("DayController");
            Check(_day.IsVisibleInTree() && _day.IsProcessing(), "real Wuhan day is visible and frame processing stays enabled");
            // Only deterministic order fixtures are replaced; all screen routing/input/ticks stay live.
            foreach(var planned in controller.CurrentPlan!.Customers)
                planned.Order = new ProjectCake.Orders.OrderData
                {
                    OrderId = planned.Order.OrderId, CityId = StableIds.Cities.Wuhan, CustomerTypeId = planned.CustomerTypeId,
                    OrderTypeId = "wuhan_full_combo", BasePrice = 30, PatienceSeconds = 100,
                    Lines = new[] { new ProjectCake.Orders.OrderLineData(ProductKind.HotDryNoodles, StableIds.Recipes.HotDryNoodlesClassic,2),
                        new ProjectCake.Orders.OrderLineData(ProductKind.Doupi,StableIds.Products.Doupi,2),
                        new ProjectCake.Orders.OrderLineData(ProductKind.EggRiceWine,StableIds.Products.EggRiceWine,2) },
                };
            await Until(() => controller.State == DayState.Running && controller.CustomerQueue!.Slots.Count>0
                && controller.CanDeliverTo(controller.CustomerQueue.Slots[0].Id,ProductKind.HotDryNoodles), 12);
            Check(!controller.IsPaused, "shared controller is running");
            _day.Bowl.TryAddNoodles(NoodleQuality.Optimal); _day.Bowl.TryAddBaseSeasoning(); _day.Bowl.AddMixDistance(425);
            _day.DoupiStock.TryAddBatch(8);
            await Until(() => _day.Workstation.CanDeliver(ProductKind.EggRiceWine), 2); await Frames(4);
            foreach (ProductKind kind in new[] { ProductKind.HotDryNoodles, ProductKind.Doupi, ProductKind.EggRiceWine })
            {
                var source=(DragItem)_day.FindChild($"WuhanDrag_{kind}",true,false);
                Vector2 position=source.GetGlobalTransformWithCanvas()*(source.Size*.5f);
                Check(source.IsVisibleInTree(), $"{kind} source visible in real Main");
                Move(position); await Frames();
                GD.Print($"SOURCE {kind} {source.GetGlobalRect()} hover={GetViewport().GuiGetHoveredControl()?.GetPath()}");
                Button(position,true); await Frames(3);
                Check(_day.DeliveryDrag.IsDragging, $"{kind} lifts and survives normal frames");
                var customer=controller.CustomerQueue!.Slots[0];
                int before=customer.Progress.DeliveredItems.Count;
                var zone=(Control)_day.FindChild("WuhanCustomerDropZone1",true,false);
                Vector2 target=zone.GetGlobalTransformWithCanvas()*(zone.Size*.5f);
                Move(target,true); await Frames(3); Button(target,false);
                await Until(()=>!_day.DeliveryDrag.IsDragging,2);
                Check(customer.Progress.DeliveredItems.Count==before+(kind==ProductKind.Doupi?2:1),$"{kind} reaches customer in real Main");
            }
            _main.Free(); await Frames(3); GC.Collect(); GC.WaitForPendingFinalizers();
            GD.Print($"WUHAN_MAIN_DELIVERY_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch(Exception e) { GD.PushError(e.ToString()); GD.Print($"WUHAN_MAIN_DELIVERY_RESULT passed={_passed} failed=1"); GetTree().Quit(1); }
    }
    private void Check(bool ok,string message) { if(!ok)throw new InvalidOperationException(message);_passed++;GD.Print($"PASS {message}"); }
    private async Task Frames(int count=2) { for(int i=0;i<count;i++)await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame); }
    private async Task Until(Func<bool> condition,double timeout)
    {
        ulong end=Time.GetTicksMsec()+(ulong)(timeout*1000);
        while(!condition()&&Time.GetTicksMsec()<end)await Frames(1);
        if(!condition())throw new InvalidOperationException("Timed out waiting for live game state");
    }
    private async Task ClickButton(Control screen,string text,bool prefix=false)
    {
        var button=screen.FindChildren("*","Button",true,false).OfType<Button>().First(b=>prefix?b.Text.StartsWith(text):b.Text==text);
        Check(screen.IsVisibleInTree()&&!button.Disabled,$"navigation button {text} is available");
        Vector2 p=button.GetGlobalTransformWithCanvas()*(button.Size*.5f);Move(p);Button(p,true);Button(p,false);await Frames(3);
    }
    private void Move(Vector2 p,bool held=false)=>GetViewport().PushInput(new InputEventMouseMotion { Position=p,GlobalPosition=p,ButtonMask=held?MouseButtonMask.Left:0 },true);
    private void Button(Vector2 p,bool pressed)=>GetViewport().PushInput(new InputEventMouseButton { Position=p,GlobalPosition=p,ButtonIndex=MouseButton.Left,Pressed=pressed },true);
}
