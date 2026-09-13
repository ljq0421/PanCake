using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;
using System.Reflection;

namespace ProjectCake.Tests;

// Render the actual production surface and both preview paths at fixed cooking times.
public partial class WuhanDoupiMaterialCapture : Node
{
    private WuhanDayScreen _day = null!;
    private string _output = "";
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--720");
            GetWindow().Size = small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080);
            GetWindow().ContentScaleSize = new Vector2I(1920, 1080);
            _output = ProjectSettings.GlobalizePath($"res://.tmp/doupi-materials/{(small ? 720 : 1080)}");
            Directory.CreateDirectory(_output);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests(_output + "/fixture.json"); AddChild(save);
            save.Data.Wuhan.HighestUnlockedDay = 12;
            save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 1;
            save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 1;
            var controller = new DayController(); AddChild(controller);
            _day = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
            AddChild(_day); _day.ConnectController(controller); _day.Initialize(catalog, save, controller, 8);
            _day.SetProcess(false); _day.BeginDay(); Step(3.1);
            await CaptureVisualRepairs();
            var pan = _day.Doupi!;
            _day.PourDoupiBatter(); Step(.5); await Shot("01-batter", true);
            _day.AddDoupiEgg(); Step(.65); await Shot("02-egg-spread");
            Step(2); await Shot("03-egg-ready");
            _day.FlipDoupi(); Step(.23); await Shot("04-flip"); Step(.4);
            _day.AddDoupiFilling();
            Step(.30);
            await Shot("05-auto-filling", true);
             await Shot("06-uncooked", true);
            Step(1.75); await Shot("07-half-cooked", true);
            Step(1.76); Require(pan.State == DoupiState.ReadyToCut, "ready to cut");
            await Shot("08-cooked", true);
            _day.CutDoupi(DoupiCutLine.Horizontal); Step(.4); await Shot("09-horizontal", true);
            _day.CutDoupi(DoupiCutLine.Center); await Shot("10-eight-pieces");
            Step(.4); Step(.15); await Shot("11-transfer"); Step(.6);
            Require(_day.DoupiStock.Count == 8, "two cuts supply eight pieces");
            await Shot("12-stock", stockPreview: true);
            VerifyStockProportions();
            _day.PourDoupiBatter(); Step(.5); _day.AddDoupiEgg(); Step(2.6); _day.FlipDoupi(); Step(.6);
            _day.AddDoupiFilling();  Step(3.6);
            await Shot("12a-stock-and-pan");
            _day.CutDoupi(DoupiCutLine.Horizontal); Step(.4); _day.CutDoupi(DoupiCutLine.Center);
            Step(.4); Step(.24); await Shot("12a-refill-transfer"); Step(.3);
            Require(_day.DoupiStock.Count == 8 && pan.RemainingPieces == 8, "second batch waits beside the full tray");
            _day.DiscardDoupi(); Step(.5);
            await Shot("12b-full-stock", stockPreview: true);
            _day.DoupiStock.TryTake(3, out _);
            _day.PourDoupiBatter(); Step(.5); _day.AddDoupiEgg(); Step(2.6); _day.FlipDoupi(); Step(.6);
            _day.AddDoupiFilling();  Step(3.6);
            _day.CutDoupi(DoupiCutLine.Horizontal); Step(.4); _day.CutDoupi(DoupiCutLine.Center);
            Step(.4); Step(.08); await Shot("12c-partial-transfer"); Step(.5);
            Require(_day.DoupiStock.Count == 8 && pan.RemainingPieces == 5, "partial refill keeps the other five pieces in the pan");
            ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            _day.DoupiStock.TryTake(2, out _); Step(.12); await Shot("12d-reduced-partial-transfer"); Step(.5);
            Require(pan.FirstRemainingPiece == 5 && _day.DoupiStock.PieceAt(6).Tile == 3 && _day.DoupiStock.PieceAt(7).Tile == 4,
                "continued refill preserves the original food fragments");
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            _day.DiscardDoupi(); Step(.5);
            _day.DoupiStock.TryTake(8, out _);
            _day.PourDoupiBatter(); Step(.5); _day.AddDoupiEgg(); Step(2.6); _day.FlipDoupi(); Step(.6);
            _day.AddDoupiFilling();
            Step(7); Require(pan.State == DoupiState.Overbrowned, "overbrowned"); await Shot("13-overbrowned", true);
            Step(2); Require(pan.State == DoupiState.Burnt, "burnt"); await Shot("14-burnt", true);
            _day.Free(); controller.Free(); save.Free();
            GD.Print("WUHAN_DOUPI_MATERIAL_CAPTURE_OK"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private async Task CaptureVisualRepairs()
    {
        var view=_day.Workstation;
        _day.Cooker.TryStart(0);Step(.5);await Shot("repair-01-basket-water");
        Step(1.2);_day.RaiseBasket(0);Step(.05);await Shot("repair-02-water-contact");
        Step(.25);await Shot("repair-03-basket-raised");
        _day.Cooker.TryDiscard(0);view.CancelAnimations();
        _day.Bowl.TryAddNoodles(NoodleQuality.Optimal);_day.Bowl.TryAddBaseSeasoning();
        _day.Bowl.TryAddTopping(StableIds.Ingredients.WuhanChiliOil);_day.Bowl.AddMixDistance(1000);
        _day.Bowl.TryAddTopping(StableIds.Ingredients.WuhanBraisedBeef);
        foreach(bool dark in new[]{false,true})
        {
            var backdrop=new ColorRect {Position=new Vector2(850,310),Size=new Vector2(370,290),Color=dark?new Color("#323C40"):new Color("#F2F4F6"),MouseFilter=Control.MouseFilterEnum.Ignore};
            view.AddChild(backdrop);
            var preview=(Control)typeof(WuhanWorkstationView).GetMethod("CreateDeliveryPreview",BindingFlags.Instance|BindingFlags.NonPublic)!.Invoke(view,new object[]{ProductKind.HotDryNoodles})!;
            preview.Position=new Vector2(885,325);view.AddChild(preview);
            await Shot(dark?"repair-05-bowl-dark":"repair-04-bowl-light");preview.Free();backdrop.Free();
        }
        _day.Bowl.Reset();
        _day.DoupiStock.TryAddBatch(8);await Shot("repair-06-stock-eight");
        _day.DoupiStock.TryTake(1,out _);await Shot("repair-07-stock-seven");
        VerifyTrayPixels("repair-06-stock-eight","repair-07-stock-seven",new[]{0});
        _day.DoupiStock.TryTake(2,out _);await Shot("repair-08-stock-five");
        VerifyTrayPixels("repair-07-stock-seven","repair-08-stock-five",new[]{1,2});
        _day.DoupiStock.TryAddBatch(3,DoupiQuality.Overbrowned,4);await Shot("repair-09-stock-refill-holes");
        _day.DoupiStock.TryTake(8,out _);
    }
    private void VerifyTrayPixels(string beforeFile,string afterFile,int[] removedSlots)
    {
        using Image before=Image.LoadFromFile(Path.Combine(_output,beforeFile+".png"));
        using Image after=Image.LoadFromFile(Path.Combine(_output,afterFile+".png"));
        var view=_day.Workstation;Transform2D transform=view.GetGlobalTransformWithCanvas();
        Vector2 visible=GetViewport().GetVisibleRect().Size;
        Vector2 pixelScale=new(before.GetWidth()/visible.X,before.GetHeight()/visible.Y);
        Rect2 ScreenRect(Rect2 r) => new((transform*r.Position)*pixelScale,((transform*r.End)-(transform*r.Position))*pixelScale);
        var slotMethod=typeof(WuhanWorkstationView).GetMethod("StockItemRect",BindingFlags.Instance|BindingFlags.NonPublic)!;
        Rect2[] changedAreas=removedSlots.Select(slot=>ScreenRect((Rect2)slotMethod.Invoke(view,new object[]{slot})!).Grow(2)).ToArray();
        Rect2 tray=ScreenRect(WuhanWorkbenchLayout.Doupi.Stock);
        Require(new Rect2(0,0,before.GetWidth(),before.GetHeight()).Encloses(tray),"tray pixel bounds fit captured image");
        int changed=0;
        for(int y=(int)tray.Position.Y;y<(int)tray.End.Y;y++) for(int x=(int)tray.Position.X;x<(int)tray.End.X;x++)
        {
            if(before.GetPixel(x,y)==after.GetPixel(x,y))continue;
            changed++;
            Require(changedAreas.Any(area=>area.HasPoint(new Vector2(x+.5f,y+.5f))),"delivery changed a pixel outside the removed pieces");
        }
        Require(changed>0,"delivery visibly removes food");
        GD.Print($"WUHAN_TRAY_PIXEL_DIFF_OK removed={removedSlots.Length} changed_pixels={changed}");
    }
    private static void Require(bool ok, string message) { if (!ok) throw new InvalidOperationException(message); }
    private void VerifyStockProportions()
    {
        const BindingFlags hidden = BindingFlags.Instance | BindingFlags.Static | BindingFlags.NonPublic;
        Type type = typeof(WuhanWorkstationView);
        var art = new WuhanArtCatalog();
        for (int slot=0; slot<8; slot++)
        {
            int tile = (slot + 3) % 8; // Partially transferred batches need not start at tile zero.
            Rect2 bounds = (Rect2)type.GetMethod("StockItemRect", hidden)!.Invoke(_day.Workstation, new object[]{slot})!;
            Vector2[] fitted = (Vector2[])type.GetMethod("FitDoupiPieceQuad", hidden)!.Invoke(_day.Workstation, new object[]{tile,bounds})!;
            Vector2 pixels = art.DoupiPiece(tile).GetSize();
            Vector2[] source = { Vector2.Zero, new(pixels.X, 0), pixels, new(0, pixels.Y) };
            float scale = fitted[0].DistanceTo(fitted[1]) / source[0].DistanceTo(source[1]);
            for (int a=0; a<4; a++) for (int b=a+1; b<4; b++)
                Require(Math.Abs(fitted[a].DistanceTo(fitted[b])/source[a].DistanceTo(source[b])-scale)<.00001f,
                    "stock preserves the illustrated sprite's edge and diagonal proportions");
            Require(fitted.All(p=>p.X>=bounds.Position.X-.001f && p.Y>=bounds.Position.Y-.001f && p.X<=bounds.End.X+.001f && p.Y<=bounds.End.Y+.001f),
                "stock food stays inside its slot");
            // StockFood positions the stack centers; the upper layer may extend above it.
            // Compare the drawn geometry against the physical tray's inner margin.
            Rect2 tray = WuhanWorkbenchLayout.Doupi.Stock.Grow(-WuhanWorkbenchLayout.Point(12,12).X);
            Vector2 min = new(fitted.Min(p=>p.X),fitted.Min(p=>p.Y));
            Vector2 max = new(fitted.Max(p=>p.X),fitted.Max(p=>p.Y));
            Require(tray.Encloses(new Rect2(min-Vector2.One*.5f,max-min+Vector2.One)),
                "stacked food including its outline and front edge stays inside the tray");
        }
        GD.Print("WUHAN_DOUPI_STOCK_PROPORTIONS_OK slots=8");
    }
    private void Step(double seconds)
    {
        for (int i=0; i<(int)Math.Ceiling(seconds*60); i++)
        { _day._Notification((int)NotificationApplicationFocusIn); _day._Process(1.0/60); }
    }
    private async Task Shot(string name, bool panPreview = false, bool stockPreview = false)
    {
        Control? preview = null;
        if (panPreview || stockPreview)
        {
            string method = panPreview ? "CreatePanDoupiPreview" : "CreateDeliveryPreview";
            object argument = panPreview ? new Vector2(180,85) : ProductKind.Doupi;
            preview = (Control)typeof(WuhanWorkstationView).GetMethod(method, BindingFlags.Instance|BindingFlags.NonPublic)!.Invoke(_day.Workstation,new[]{argument})!;
            preview.Position = new Vector2(900, 620); _day.Workstation.AddChild(preview);
        }
        _day.RefreshForCapture();
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using Image image = GetViewport().GetTexture().GetImage();
        Require(image.SavePng(Path.Combine(_output, name+".png")) == Error.Ok, "save capture");
        preview?.Free();
    }
}
