using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

/// <summary>Render the real city screens with single, full and refilled fixed positions.</summary>
public partial class CustomerPlacementCapture : Node
{
    private int _checks;
    public override async void _Ready()
    {
        try
        {
            GetWindow().Size = new(1920, 1080);
            GetWindow().Position = new(-10000, -10000);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (string city in new[] { "Tianjin", "Wuhan", "Xian", "Guangzhou", "Yangzhou" })
            {
                var save = new SaveService(); save.UsePathForTests($"res://.tmp/center-capture/{city}-{Guid.NewGuid():N}-save.json"); AddChild(save);
                foreach (string id in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou, YangzhouCatalog.CityId }) save.Data.GetCity(id).HighestUnlockedDay = 12;
                var controller = new DayController(); AddChild(controller); controller.SetProcess(false);
                var screen = GD.Load<PackedScene>($"res://Scenes/Gameplay/{city}DayScreen.tscn").Instantiate<Control>();
                AddChild(screen); screen.SetProcess(false);
                switch (screen)
                {
                    case TianjinDayScreen s: s.ConnectController(controller); s.Initialize(catalog, save, controller, 2); s.BeginDay(); break;
                    case WuhanDayScreen s: s.ConnectController(controller); s.Initialize(catalog, save, controller, 2); s.BeginDay(); break;
                    case XianDayScreen s: s.ConnectController(controller); s.Initialize(catalog, save, controller, 2); s.BeginDay(); break;
                    case GuangzhouDayScreen s: s.ConnectController(controller); s.Initialize(catalog, save, controller, 2); s.BeginDay(); break;
                    case YangzhouDayScreen s: s.Initialize(YangzhouCatalog.Load(), save, 2); break;
                }
                if (screen is YangzhouDayScreen yz)
                {
                    var session = yz.Session;
                    var plan = (List<YangzhouPlannedOrder>)session.Plan;
                    double firstArrival = plan[0].Arrival;
                    for (int i = 0; i < plan.Count; i++) plan[i] = plan[i] with { Arrival = 0, TemplateId = "B", CustomerId = "ordinary" };
                    session.Tick(5 + firstArrival + .01);
                    Check(session.Waiting.Count == 1 && session.CustomerAtSlot(2) is not null, city + " single center");
                    Render(); await Shot(city + "-single");
                    session.Tick(1.1);
                    Check(session.Waiting.Select(c => c.SlotIndex).SequenceEqual(new[] { 2, 1, 3, 0, 4 }), city + " full order");
                    Render(); await Shot(city + "-full");
                    var remaining = session.CustomerAtSlot(4)!;
                    foreach (var order in session.Waiting.Where(o => o != remaining).ToArray())
                    {
                        session.Select(order.Plan.Id); session.Kitchen.TakeTea(); session.Kitchen.Tick(.31);
                        Check(session.Stage("T01") && session.Serve(), city + " serve fixed position");
                    }
                    Render(); await Shot(city + "-side-survivor");
                    session.Tick(.3); Render();
                    Check(session.CustomerAtSlot(2) is not null && session.CustomerAtSlot(4) == remaining, city + " refill center");
                    var middle = screen.GetNode<Button>("Canvas/Customer2");
                    middle.EmitSignal(Button.SignalName.Pressed);
                    Check(session.Selected == session.CustomerAtSlot(2), city + " card selects actual center customer");
                    await Shot(city + "-refilled");
                }
                else
                {
                    controller.Tick(3.01);
                    var queue = controller.CustomerQueue!;
                    queue.Tick(controller.CurrentPlan!.Customers[0].ArrivalTime, .4, true);
                    Check(queue.Slots.Count == 1 && queue.CustomerAtSlot(2) is not null, city + " single center");
                    Render(); await Shot(city + "-single");
                    for (int t = 100; t <= 180 && queue.Slots.Count < 5; t += 2) queue.Tick(t, 0, true);
                    queue.Tick(180, .4, false);
                    Check(queue.Slots.Select(c => c.SlotIndex).SequenceEqual(new[] { 2, 1, 3, 0, 4 }), city + " full order");
                    Render(); await Shot(city + "-full");
                    var survivors = queue.Slots.Where(c => c.SlotIndex != 2).ToDictionary(c => c.Id, c => c.SlotIndex);
                    queue.TryMarkServed(queue.CustomerAtSlot(2)!.Id);
                    queue.Tick(180, .45, false);
                    for (int t = 182; t <= 200 && queue.CustomerAtSlot(2) is null; t += 2) queue.Tick(t, 0, true);
                    queue.Tick(200, .4, false); Render();
                    Check(queue.CustomerAtSlot(2) is not null && queue.Slots.Where(c => survivors.ContainsKey(c.Id)).All(c => survivors[c.Id] == c.SlotIndex), city + " refill leaves survivors stationary");
                    await Shot(city + "-refilled");
                }
                screen.Free(); controller.Free(); save.Free();
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                void Render()
                {
                    screen._Notification((int)NotificationApplicationFocusIn);
                    switch (screen)
                    {
                        case TianjinDayScreen s: s.RefreshForCapture(true); break;
                        case WuhanDayScreen s: s.RefreshForCapture(); break;
                        case XianDayScreen s: s.Render(); break;
                        default: screen._Process(0); break;
                    }
                }
            }
            GD.Print($"CUSTOMER_PLACEMENT_CAPTURE passed={_checks} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private void Check(bool ok, string name)
    {
        if (!ok) throw new InvalidOperationException(name);
        _checks++; GD.Print("PASS " + name);
    }
    private async Task Shot(string name)
    {
        await ToSignal(GetTree().CreateTimer(.5), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string directory = ProjectSettings.GlobalizePath("res://.tmp/center-capture"); Directory.CreateDirectory(directory);
        using var image = GetViewport().GetTexture().GetImage();
        Check(image.SavePng(directory + "/" + name + ".png") == Error.Ok, "saved " + name);
    }
}
