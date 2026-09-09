using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

/// <summary>Real viewport input tests, with isolated orders and save files.</summary>
public partial class WuhanDeliverySelfTest : Node
{
    private DataCatalog _catalog = null!;
    private WuhanDayScreen _screen = null!;
    private DayController _controller = null!;
    private SaveService _save = null!;
    private int _passed;
    private bool _capture;
    private string _captureRoot = "";

    public override async void _Ready()
    {
        try
        {
            _catalog = GetNode<DataCatalog>("/root/DataCatalog");
            bool small = OS.GetCmdlineUserArgs().Contains("--capture-720");
            _capture = OS.GetCmdlineUserArgs().Contains("--capture");
            _captureRoot = $"res://.tmp/wuhan-theme/{(small ? 720 : 1080)}";
            GetWindow().Size = small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080);
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            await NewDay();
            await TestDelivery();
            await TestBatchDelivery();
            await TestLifecycle();
            TestTheme();
            if (_capture) await CaptureScreens();
            DisposeDay();
            await Frames(); GC.Collect(); GC.WaitForPendingFinalizers(); await Frames();
            GD.Print($"WUHAN_DELIVERY_TEST_RESULT passed={_passed} failed=0");
            GetTree().Quit();
        }
        catch (Exception e)
        {
            GD.PushError(e.ToString());
            GD.Print($"WUHAN_DELIVERY_TEST_RESULT passed={_passed} failed=1");
            GetTree().Quit(1);
        }
    }

    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++; GD.Print($"PASS {message}");
    }
    private async Task Frames(int count = 2)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    private async Task Settled() => await ToSignal(GetTree().CreateTimer(.4), SceneTreeTimer.SignalName.Timeout);

    private async Task NewDay(bool batchOnly = false)
    {
        if (_screen is not null) DisposeDay();
        _save = new SaveService(); _save.UsePathForTests($"res://.tmp/wuhan-delivery-{Guid.NewGuid():N}.json"); AddChild(_save);
        _save.Data.Coins = 3000;
        var city = _save.Data.Wuhan; city.HighestUnlockedDay = 12;
        city.EquipmentLevels["noodle_cooker"] = 3; city.EquipmentLevels["ingredient_station"] = 3;
        city.EquipmentLevels["doupi_griddle"] = 3; city.EquipmentLevels["egg_rice_wine_station"] = 1;
        _controller = new DayController(); AddChild(_controller);
        _screen = ProjectCake.Core.SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(_screen); _screen.ConnectController(_controller);
        _screen.Initialize(_catalog, _save, _controller, 8); _screen.SetProcess(false);
        // Order data is replaced before admission; production, delivery and queue logic remain real.
        for (int i = 0; i < _controller.CurrentPlan!.Customers.Count; i++)
        {
            var planned = _controller.CurrentPlan.Customers[i];
            planned.Order = new OrderData
            {
                OrderId = planned.Order.OrderId, CityId = StableIds.Cities.Wuhan,
                CustomerTypeId = planned.CustomerTypeId, OrderTypeId = "wuhan_full_combo",
                BasePrice = 30, PatienceSeconds = 100,
                Lines = batchOnly ? new[] { new OrderLineData(ProductKind.Doupi, StableIds.Products.Doupi, 1), new OrderLineData(ProductKind.Doupi, StableIds.Products.Doupi, 2) } : i == 2 ? new[] { new OrderLineData(ProductKind.HotDryNoodles, StableIds.Recipes.HotDryNoodlesClassic, 2) }
                    : new[] { new OrderLineData(ProductKind.HotDryNoodles, StableIds.Recipes.HotDryNoodlesClassic, 2),
                        new OrderLineData(ProductKind.Doupi, StableIds.Products.Doupi, 2),
                        new OrderLineData(ProductKind.EggRiceWine, StableIds.Products.EggRiceWine, 2) },
            };
        }
        _screen.BeginDay(); Step(3.01);
        for (int i = 0; i < 160 && _controller.CustomerQueue!.Slots.Count < 3; i++) Step(.25);
        Step(.4); await Frames();
        Check(_controller.CustomerQueue!.Slots.Count >= 3, "fixture has three waiting customers");
    }
    private void DisposeDay()
    {
        _screen.Free(); _controller.Free(); _save.Free();
        _screen = null!; _controller = null!; _save = null!;
    }
    private void Step(double seconds)
    {
        _screen._Notification((int)NotificationApplicationFocusIn);
        _screen._Process(seconds);
    }
    private void PrepareFood(NoodleQuality quality = NoodleQuality.Optimal, bool toppings = false)
    {
        var bowl = _screen.Bowl; bowl.Reset(); bowl.TryAddNoodles(quality); bowl.TryAddBaseSeasoning();
        if (toppings) foreach (string id in WuhanWorkstationView.IngredientIds.Skip(1)) bowl.TryAddTopping(id);
        bowl.AddMixDistance(425);
        if (_screen.DoupiStock.Count == 0) _screen.DoupiStock.TryAddBatch(8);
        if (!_screen.Egg!.HasFinishedCup) { _screen.Egg.TryStart(); _screen.Egg.Tick(.61); }
        _screen.Workstation.CancelAnimations(); Step(.001);
    }
    private Vector2 Source(ProductKind kind)
    {
        var view = _screen.Workstation;
        return view.GetGlobalTransformWithCanvas() * (kind == ProductKind.HotDryNoodles ? view.BowlCenter
            : kind == ProductKind.Doupi ? view.StockCenter : view.CupCenter);
    }
    private DropZone Zone(int slot) => (DropZone)_screen.FindChild($"WuhanCustomerDropZone{slot+1}", true, false);
    private Vector2 Target(int slot) => Zone(slot).GetGlobalTransformWithCanvas() * (Zone(slot).Size * .5f);
    private void Move(Vector2 p, bool held = false) => GetViewport().PushInput(new InputEventMouseMotion
        { Position = p, GlobalPosition = p, ButtonMask = held ? MouseButtonMask.Left : 0 }, true);
    private void Button(Vector2 p, bool pressed) => GetViewport().PushInput(new InputEventMouseButton
        { ButtonIndex = MouseButton.Left, Pressed = pressed, Position = p, GlobalPosition = p }, true);
    private void Press(ProductKind kind)
    {
        Vector2 p = Source(kind); Move(p); Button(p, true);
        Check(_screen.DeliveryDrag.IsDragging, $"{kind} starts from visible food through viewport input");
    }
    private async Task Drop(ProductKind kind, int slot)
    {
        Press(kind); Vector2 target = Target(slot); Move(target, true); Button(target, false);
        await Settled(); Step(.001);
        Check(!_screen.DeliveryDrag.IsDragging, "delivery animation releases input");
    }

    private async Task TestDelivery()
    {
        PrepareFood(NoodleQuality.Overcooked, true); await Frames();
        var queue = _controller.CustomerQueue!; var first = queue.Slots[0]; var second = queue.Slots[1];
        Check(queue.SelectedCustomerId is null, "no customer selection required");
        Press(ProductKind.HotDryNoodles);
        Check(_screen.Workstation.Busy("bowl"), "drag locks the current bowl");
        int scallion = _screen.Ingredients.Count(StableIds.Ingredients.WuhanScallion);
        _screen.IngredientAction(StableIds.Ingredients.WuhanScallion);
        Check(_screen.Ingredients.Count(StableIds.Ingredients.WuhanScallion) == scallion, "drag cannot mutate recipe or consume ingredients");
        var overlay = (Control)_screen.FindChild("WuhanDragOverlay", true, false);
        Check(overlay.GetChild(0).GetChild(0).GetChildCount() == 7, "preview contains bowl, noodles, mixed sauce, overcooking and three toppings");
        Check(overlay.GetChild(0).GetChild(0).GetChildren().OfType<TextureRect>().All(layer => layer.Size.X <= 224 && layer.Size.Y <= 174),
            "preview layers use authored bowl dimensions instead of source PNG minimum size");
        Move(new Vector2(950, 150), true); Button(new Vector2(950, 150), false); await Settled();
        Check(_screen.Bowl.State == NoodleBowlState.Ready && !_screen.Workstation.Busy("bowl"), "miss returns intact bowl and releases lock");
        Press(ProductKind.Doupi); GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
        Check(_screen.DoupiStock.Count == 8 && !_screen.DeliveryDrag.IsDragging, "Escape retains stock and cancels drag");
        await Drop(ProductKind.Doupi, 2);
        Check(_screen.DoupiStock.Count == 8, "customer without matching product rejects without consumption");
        await Drop(ProductKind.HotDryNoodles, 0);
        Check(first.Progress.GetDeliveredQuantity(0) == 1 && _screen.Bowl.State == NoodleBowlState.Empty, "unselected customer receives exactly one bowl");
        Check(first.Progress.HasNoodlesOvercooked && first.Progress.HasRecipeMismatch, "actual recipe and low quality follow existing scoring rules");
        Check(!first.Progress.IsComplete, "partial delivery keeps multi-item order active");
        queue.TrySelect(first.Id); await Drop(ProductKind.Doupi, 1);
        Check(second.Progress.GetDeliveredQuantity(1) == 2 && first.Progress.GetDeliveredQuantity(1) == 0
            && _screen.DoupiStock.Count == 6, "drop target wins over selection and receives its two missing pieces");
        _screen.EggAction();
        Check(_screen.Egg!.HasFinishedCup && second.Progress.GetDeliveredQuantity(2) == 0, "egg action never performs click delivery");
        await Drop(ProductKind.EggRiceWine, 1);
        Check(!_screen.Egg.HasFinishedCup && second.Progress.GetDeliveredQuantity(2) == 1, "finished cup can be dragged directly to customer");
        Check(!_screen.DeliverToCustomer(second.Id, ProductKind.EggRiceWine), "duplicate submit cannot consume an absent cup");
        Move(Source(ProductKind.HotDryNoodles)); Button(Source(ProductKind.HotDryNoodles), true); Button(Source(ProductKind.HotDryNoodles), false);
        Check(!_screen.DeliveryDrag.IsDragging, "empty bowl cannot start a delivery");
        _screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); _screen.Bowl.TryAddBaseSeasoning(); Step(.001);
        Vector2 center = Source(ProductKind.HotDryNoodles);
        Move(center); Button(center, true);
        for (int i = 0; i < 5; i++) { Move(center + new Vector2(i % 2 == 0 ? 60 : -60, 0), true); Step(.001); }
        Check(_screen.Bowl.State == NoodleBowlState.Ready && !_screen.DeliveryDrag.IsDragging, "mix completion does not turn held gesture into delivery");
        Button(center, false); Step(.001); await Frames(); Press(ProductKind.HotDryNoodles); _screen.Workstation.CancelInput();
        await Drop(ProductKind.HotDryNoodles, 0);
        Check(!first.Progress.IsComplete && first.Progress.GetDeliveredQuantity(0) == 2, "quantity-two line completes independently of other foods");
        // Completion must be atomic even if the target changes during the snap animation.
        Press(ProductKind.Doupi); Vector2 target = Target(1); Move(target, true); Button(target, false);
        second.State = CustomerState.Leaving; Step(.5); await Settled();
        Check(_screen.DoupiStock.Count == 6 && second.Progress.GetDeliveredQuantity(1) == 2, "satisfied or departing customer cannot consume additional pieces");
        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        await Drop(ProductKind.Doupi, 0);
        Check(_screen.DoupiStock.Count == 4, "reduced motion commits the two missing pieces once");
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
    }

    private async Task TestBatchDelivery()
    {
        await NewDay(true);
        var first = _controller.CustomerQueue!.Slots[0];
        _screen.DoupiStock.TryAddBatch(1, DoupiQuality.Overbrowned);
        _screen.DoupiStock.TryAddBatch(2, DoupiQuality.Normal);
        Step(.001); await Frames();
        int notifications = 0; _controller.DeliveryCompleted += _ => notifications++;
        Press(ProductKind.Doupi); Move(Target(0), true); Step(.001); await Frames();
        Check(_screen.DoupiStock.Count == 3 && first.Progress.DeliveredItems.Count == 0, "hover reserves no stock or order quantity");
        var preview = (Label)_screen.FindChild("DoupiDeliveryQuantity1", true, false);
        Check(preview.Visible && preview.Text == "豆皮×3", "hover preview sums remaining quantity across order lines");
        if (_capture) await Shot("07-batch-preview");
        Button(Target(0), false); await Settled(); Step(.001);
        Check(_screen.DoupiStock.Count == 0 && first.Progress.GetDeliveredQuantity(0) == 1 && first.Progress.GetDeliveredQuantity(1) == 2, "one drop fills multiple doupi lines without overdelivery");
        Check(first.Progress.DeliveredItems[0].WuhanQuality == WuhanFoodQuality.DoupiOverbrowned
            && first.Progress.DeliveredItems.Skip(1).All(item => item.WuhanQuality == WuhanFoodQuality.None), "batch preserves each piece quality in FIFO order");
        Check(first.Progress.HasDoupiOverbrowned && first.Progress.IsComplete && notifications == 1
            && _controller.Ledger!.Build().CompletedCustomers == 1, "mixed quality order evaluates and notifies exactly once");
        Check(!_screen.DeliverToCustomer(first.Id, ProductKind.Doupi) && notifications == 1, "duplicate batch cannot settle twice");
        await NewDay(true); first = _controller.CustomerQueue!.Slots[0];
        _screen.DoupiStock.TryAddBatch(1); Step(.001); await Frames();
        await Drop(ProductKind.Doupi, 0);
        Check(first.Progress.DeliveredItems.Count == 1 && !first.Progress.IsComplete && _screen.DoupiStock.Count == 0, "insufficient stock delivers available piece and leaves remaining demand");
        _screen.DoupiStock.TryAddBatch(3); Step(.001); await Frames();
        Press(ProductKind.Doupi); Move(Target(1), true); Button(Target(1), false);
        var leaving = _controller.CustomerQueue.Slots[1]; leaving.State = CustomerState.Leaving;
        Step(.01); await Settled();
        Check(_screen.DoupiStock.Count == 3 && leaving.Progress.DeliveredItems.Count == 0, "customer leaving during snap cancels entire pending batch");
        Step(.001); await Frames(); Press(ProductKind.Doupi); _screen.Workstation.CancelInput();
        Check(_screen.DoupiStock.Count == 3, "cancelled batch keeps all pieces");
    }

    private async Task TestLifecycle()
    {
        PrepareFood(); await Frames();
        foreach (string reason in new[] { "pause", "focus", "dialog", "hidden", "restart" })
        {
            Press(ProductKind.HotDryNoodles);
            switch (reason)
            {
                case "pause": _controller.IsPaused = true; _screen._Process(.01); _controller.IsPaused = false; break;
                case "focus": _screen._Notification((int)NotificationApplicationFocusOut); break;
                case "dialog":
                    var dialog = _screen.GetChildren().OfType<ConfirmationDialog>().Single(); dialog.PopupCentered();
                    _screen._Process(.01); dialog.Hide(); break;
                case "hidden": _screen.Hide(); _screen.Show(); break;
                case "restart": _screen.Initialize(_catalog, _save, _controller, 8); break;
            }
            Check(!_screen.DeliveryDrag.IsDragging && !_screen.Workstation.Busy("bowl"), $"{reason} cancels proxy and source lock");
            if (reason != "restart") Check(_screen.Bowl.State == NoodleBowlState.Ready, $"{reason} keeps uncommitted food");
            Step(.001); await Frames();
        }
        await NewDay(); PrepareFood(); await Frames(); Press(ProductKind.HotDryNoodles);
        _controller.Tick(1000); _controller.Tick(16); _screen._Process(.001);
        Check(_controller.State == DayState.Results && !_screen.DeliveryDrag.IsDragging, "settlement cancels active drag");
    }

    private void TestTheme()
    {
        static double L(Color c)
        {
            static double V(double x) => x <= .04045 ? x / 12.92 : Math.Pow((x + .055) / 1.055, 2.4);
            return .2126*V(c.R)+.7152*V(c.G)+.0722*V(c.B);
        }
        static double Contrast(Color a, Color b) => (Math.Max(L(a), L(b))+.05)/(Math.Min(L(a), L(b))+.05);
        Check(Contrast(WuhanUi.Text, WuhanUi.Paper) >= 4.5 && Contrast(WuhanUi.Ink, WuhanUi.Paper) >= 4.5,
            "receipt text, title and unlock hint exceed 4.5:1");
        Check(Contrast(WuhanUi.Muted, WuhanUi.Disabled) >= 4.5, "disabled labels remain readable");
        var button = WuhanUi.Button("test", true);
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
        {
            Color fg = button.GetThemeColor(state == "normal" ? "font_color" : $"font_{state}_color");
            Check(Contrast(fg, ((StyleBoxFlat)button.GetThemeStylebox(state)).BgColor) >= 4.5, $"primary button {state} contrast");
        }
        button.Free();
        var receipt = _screen.GetChildren().OfType<PanelContainer>().SelectMany(p=>p.FindChildren("*", "RichTextLabel", true, false)).OfType<RichTextLabel>().Single();
        Check(receipt.GetThemeColor("default_color") == WuhanUi.Text, "receipt explicitly overrides RichTextLabel color");
    }

    private async Task CaptureScreens()
    {
        await NewDay();
        _screen.Hide();
        var hub = ProjectCake.Core.SceneFactory.Instantiate<WuhanHub>("res://Scenes/UI/WuhanHub.tscn"); AddChild(hub); hub.Initialize(_catalog, _save);
        await Shot("01-hub"); hub.Free(); _screen.Show();
        PrepareFood(NoodleQuality.Overcooked, true); await Frames(); await Shot("02-workbench");
        Press(ProductKind.HotDryNoodles); Move(Target(0), true); await Shot("03-drag-noodles"); _screen.Workstation.CancelInput();
        Press(ProductKind.EggRiceWine); Move(Target(1), true); await Shot("04-drag-egg"); _screen.Workstation.CancelInput();
        Press(ProductKind.Doupi); Move(Target(2), true); await Shot("05-invalid-target"); _screen.Workstation.CancelInput();
        await Drop(ProductKind.HotDryNoodles, 0);
        for (int i=0;i<2;i++) { PrepareFood(); await Frames(); if(i==0) await Drop(ProductKind.HotDryNoodles,0); await Drop(ProductKind.Doupi,0); await Drop(ProductKind.EggRiceWine,0); }
        _controller.Tick(1000); _controller.Tick(16); _screen._Process(.001); await Shot("06-receipt");
    }
    private async Task Shot(string name)
    {
        await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string path = ProjectSettings.GlobalizePath($"{_captureRoot}/{name}.png");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        GetViewport().GetTexture().GetImage().SavePng(path);
    }
}
