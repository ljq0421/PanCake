using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Exercises live customer delivery and drag feedback without advancing the business clock.</summary>
public partial class InteractionHighlightSelfTest : Node
{
    private int _passed;
    private SubViewport _viewport = null!;
    private bool Capture => OS.GetCmdlineUserArgs().Any(arg => arg is "--capture" or "--capture-720");
    private int CaptureWidth => OS.GetCmdlineUserArgs().Contains("--capture-720") ? 1280 : 1920;

    public override async void _Ready()
    {
        string savePath = $"res://.tmp/interaction-highlight-{Guid.NewGuid():N}.json";
        bool reduced = ProjectSettings.HasSetting("accessibility/reduce_motion")
            && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath("res://.tmp"));
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            GetWindow().Size = new Vector2I(CaptureWidth, CaptureWidth * 9 / 16);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests(savePath); AddChild(save);
            var controller = new DayController(); AddChild(controller);
            // A hidden native Window has no reliable OS pointer. This viewport
            // renders the unchanged scene and accepts deterministic player input.
            _viewport = new SubViewport { Name = "InteractionTestViewport", Disable3D = true,
                Size = new Vector2I(CaptureWidth, CaptureWidth * 9 / 16),
                Size2DOverride = new Vector2I(1920, 1080), Size2DOverrideStretch = true,
                RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport);
            _viewport.NotifyMouseEntered();
            if (OS.GetCmdlineUserArgs().Contains("--render-only"))
            {
                await CheckRenderedContours();
                GD.Print($"INTERACTION_RENDER_TEST_RESULT passed={_passed} failed=0");
                GetTree().Quit();
                return;
            }
            var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
            _viewport.AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller);
            screen.Initialize(catalog, save, controller, 15);

            // Three-item orders expose a progress refresh while the same customer
            // remains at the counter, which used to replay the arrival fade.
            foreach (PlannedCustomer planned in controller.CurrentPlan!.Customers)
                planned.Order = new OrderData { OrderId = planned.Order.OrderId, CustomerTypeId = planned.CustomerTypeId,
                    Lines = new[] { new OrderLineData(ProductKind.Youtiao, StableIds.Products.Youtiao, 2),
                        new OrderLineData(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1) }, BasePrice = 7 };
            screen.BeginDay(); controller.Tick(3.1);
            controller.CustomerQueue!.Tick(1000, .4, true);
            screen.RefreshForCapture(true);
            var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
            var drag = station.GetChildren().OfType<DragService>().Single();
            var source = (DragItem)station.FindChild("FinishedYoutiaoDrag", true, false);
            var slot = (Control)screen.FindChild("CustomerSlot1", true, false);
            var zone = (DropZone)screen.FindChild("CustomerDropZone1", true, false);
            var portrait = slot.FindChildren("*", "", true, false).OfType<CustomerPortraitView>().Single();
            var contour = portrait.GetChildren().OfType<ArtContourHighlight>().Single();
            TextureRect[] layers = portrait.GetChildren().OfType<TextureRect>().ToArray();
            CustomerRuntime customer = controller.CustomerQueue.CustomerAtSlot(0)!;
            Check(controller.CustomerQueue.Slots.Count == 5 && slot.Modulate.A < .999f,
                "new customers keep their normal arrival fade");
            await Wait(.30);
            Check(slot.Modulate.A > .999f, "arrival reaches full opacity");
            Material?[] materials = layers.Select(layer => layer.Material).ToArray();
            Color[] colors = layers.Select(layer => layer.Modulate).ToArray();
            Color portraitColor = portrait.Modulate;
            Rect2? hitRect = zone.FixedHitRect;
            float hitPadding = zone.HitPadding;
            Vector2[] slotPositions = screen.FindChildren("CustomerSlot*", "", true, false).OfType<Control>()
                .Select(view => view.GlobalPosition).ToArray();

            station.FryerMachine!.Inventory.TryStore(2, YoutiaoQuality.Golden);
            customer.WaitSeconds = 10;
            screen.RefreshForCapture(true);
            await Shot("tianjin-before-delivery");
            double patienceBefore = customer.WaitSeconds;
            Check(zone.TryAccept("stored_youtiao"), "first item follows the real customer delivery path");
            screen.RefreshForCapture(true);
            Check(ReferenceEquals(controller.CustomerQueue.CustomerAtSlot(0), customer)
                && customer.Progress.GetDeliveredQuantity(0) == 1 && !customer.WasServed
                && customer.WaitSeconds < patienceBefore,
                "partial delivery keeps the customer and restores patience");
            Check(slot.Modulate.A > .999f && portrait.Modulate == portraitColor,
                "partial delivery refresh does not restart the portrait fade or tint");
            await Shot("tianjin-after-partial-delivery");

            // Start through the real stock input, then move the actual drag over
            // empty counter space and onto the customer. No manual visual state.
            BeginYoutiaoDrag(source);
            Check(drag.IsDragging, "finished food starts dragging through its stock input");
            MoveDrag(drag, new Vector2(1840, 1030));
            await Wait(.13);
            Check(zone.VisualState == DropZoneVisualState.Eligible && contour.Visible,
                "a carried matching item exposes the eligible customer contour");
            Vector2 target = zone.GetGlobalRect().GetCenter();
            MoveDrag(drag, target);
            await Wait(.13);
            Check(zone.VisualState == DropZoneVisualState.HoverValid && contour.Visible,
                "moving the item over its customer strengthens the contour");
            Check(layers.Select((layer, i) => layer.Material == materials[i] && layer.Modulate == colors[i]).All(value => value)
                && portrait.Modulate == portraitColor && zone.FixedHitRect == hitRect && zone.HitPadding == hitPadding
                && zone.ContainsPoint(target, false),
                "highlighting preserves source materials, portrait color and delivery hit geometry");
            await Shot("tianjin-valid-customer-contour");
            MoveDrag(drag, new Vector2(1840, 1030));
            using (var escape = new InputEventKey { Keycode = Key.Escape, Pressed = true }) drag._Input(escape);
            await Wait(.16);
            Check(!drag.IsDragging && zone.VisualState == DropZoneVisualState.Idle && !contour.Visible
                && customer.Progress.GetDeliveredQuantity(0) == 1 && station.FryerMachine.Inventory.Count == 1,
                "Esc clears the drag contour without delivering or consuming food");

            float deliveredOpacity = -1;
            DragResult? dragResult = null;
            drag.DragEnded += result =>
            {
                dragResult = result;
                if (result.Completion != DragCompletion.Accepted) return;
                screen.RefreshForCapture(true);
                deliveredOpacity = slot.Modulate.A;
            };
            BeginYoutiaoDrag(source);
            MoveDrag(drag, target);
            using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = target })
                drag._Input(release);
            await Wait(.30);
            Check(dragResult?.Completion == DragCompletion.Accepted && deliveredOpacity > .999f
                && customer.Progress.GetDeliveredQuantity(0) == 2 && station.FryerMachine.Inventory.Count == 0
                && controller.CustomerQueue.Slots.Where(other => other != customer).All(other => other.Progress.DeliveredItems.Count == 0),
                "dropping the second item serves only the target and keeps its portrait fully visible");

            station.SoyMilkTray!.Tick(.3);
            Check(zone.TryAccept("soy_milk_cup") && customer.WasServed, "the final item completes the same customer's order");
            controller.CustomerQueue.Tick(1000, CustomerQueue.LeaveDurationSeconds + .01, false);
            screen.RefreshForCapture(true);
            Check(controller.CustomerQueue.CustomerAtSlot(0)?.Id != customer.Id
                && controller.CustomerQueue.CustomerAtSlot(0) is not null && slot.Visible && slot.Modulate.A < .999f,
                "a replacement customer still receives an entrance fade");
            Check(screen.FindChildren("CustomerSlot*", "", true, false).OfType<Control>()
                .Select(view => view.GlobalPosition).SequenceEqual(slotPositions),
                "delivery and replacement preserve all five counter positions");
            await Wait(.30);
            Check(slot.Modulate.A > .999f, "replacement customer becomes fully visible");
            await Wait(.75); // Let the completed order's celebration leave the equipment comparison.
            MovePointer(TianjinWorkbenchLayout.EmbeddedSurface.GetCenter());
            Check(_viewport.GetMousePosition().DistanceTo(TianjinWorkbenchLayout.EmbeddedSurface.GetCenter()) < 2,
                "equipment capture moves the viewport pointer onto the stove");
            await Shot("tianjin-stove-contour");
            MovePointer(TianjinWorkbenchLayout.EmbeddedIngredient(StableIds.Ingredients.Batter).GetCenter());
            await Shot("tianjin-bowl-contour");
            MovePointer(TianjinWorkbenchLayout.EmbeddedSoyTray.GetCenter());
            await Shot("tianjin-soy-contour");
            MovePointer(TianjinWorkbenchLayout.EmbeddedTrash.GetCenter());
            await Shot("tianjin-trash-contour");
            screen.CashPendant.GrabFocus();
            await Shot("tianjin-pendant-contour");
            screen.CashPendant.ReleaseFocus();
            var pendant = (TianjinPendantButton)screen.CashPendant;
            foreach (Vector2 sourcePoint in new Vector2[] { new(1270,100), new(1280,200), new(1277,307) })
                Check(pendant._HasPoint(sourcePoint * TianjinWorkbenchLayout.SourceScale - pendant.Position),
                    "pendant accepts its visible cord, pouch and tassel: " + sourcePoint);
            Check(!pendant._HasPoint(new Vector2(1285,112) * TianjinWorkbenchLayout.SourceScale - pendant.Position),
                "empty space between pendant cords is not clickable");
            MovePointer(TianjinWorkbenchLayout.EmbeddedYoutiaoTray.GetCenter());
            await Shot("tianjin-youtiao-tray-contour");
            if (Capture) CheckTrayTopEdge();

            foreach (string ingredient in new[] { StableIds.Ingredients.Egg, StableIds.Ingredients.Crispy,
                StableIds.Ingredients.Scallion, StableIds.Ingredients.Ham, StableIds.Ingredients.Sauce })
            {
                MovePointer(TianjinWorkbenchLayout.EmbeddedIngredient(ingredient).GetCenter());
                await Shot("tianjin-ingredient-" + ingredient);
            }
            foreach (int day in new[] { 1, 6 })
            {
                controller.AbandonDay(); screen.Initialize(catalog, save, controller, day);
                screen.BeginDay(); controller.Tick(3.1); screen.RefreshForCapture(true);
                MovePointer(TianjinWorkbenchLayout.EmbeddedSurface.GetCenter());
                await Shot($"tianjin-day-{day}-stove");
                MovePointer(TianjinWorkbenchLayout.EmbeddedOpening.GetCenter());
                await Shot($"tianjin-day-{day}-fryer");
                if (day == 6)
                {
                    MovePointer(TianjinWorkbenchLayout.EmbeddedYoutiaoTray.GetCenter());
                    await Shot("tianjin-day-6-youtiao-tray-contour");
                    if (Capture) CheckTrayTopEdge();
                }
            }
            screen.Hide();
            if (Capture)
            {
                Texture2D background = new TianjinArtCatalog().WorkbenchBackground(new[] { ProductKind.SoyMilk });
                var painted = new Node2D();
                painted.Draw += () =>
                {
                    painted.DrawTextureRect(background, new Rect2(0, 0, 1920, 1080), false);
                    foreach (var id in Enum.GetValues<TianjinPaintedObject>())
                        TianjinPaintedObjectContour.Draw(painted, background, id, InteractionHighlightState.Hover);
                };
                _viewport.AddChild(painted); painted.QueueRedraw();
                await Shot("tianjin-painted-contours-unoccluded");
                painted.QueueFree(); await Frames();
            }
            if (Capture) await CheckRenderedContours();

            _viewport.QueueFree(); controller.QueueFree(); save.QueueFree();
            await Frames();
            GD.Print($"INTERACTION_HIGHLIGHT_TEST_RESULT passed={_passed} failed=0");
            GetTree().Quit();
        }
        catch (Exception error)
        {
            GD.PushError(error.ToString());
            GD.Print($"INTERACTION_HIGHLIGHT_TEST_RESULT passed={_passed} failed=1");
            GetTree().Quit(1);
        }
        finally
        {
            ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
            string absolute = ProjectSettings.GlobalizePath(savePath);
            if (File.Exists(absolute)) File.Delete(absolute);
        }
    }

    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++;
        GD.Print("PASS " + message);
    }

    private void CheckTrayTopEdge()
    {
        using Image image = _viewport.GetTexture().GetImage();
        float scale = image.GetWidth() / 1672f;
        Color ink = InteractionHighlightTheme.Tianjin.HoverColor;
        var rows = new List<int>();
        for (int x = (int)(150 * scale); x < (int)(405 * scale); x++)
        {
            int found = -1;
            for (int y = (int)(702 * scale); y < (int)(714 * scale); y++)
            {
                Color pixel = image.GetPixel(x, y);
                if (Math.Abs(pixel.R - ink.R) + Math.Abs(pixel.G - ink.G) + Math.Abs(pixel.B - ink.B) > .025f) continue;
                found = y;
                break;
            }
            if (found >= 0) rows.Add(found);
        }
        Check(rows.Count >= (int)(250 * scale) && rows.Max() - rows.Min() <= 1,
            "finished tray top stays straight below both fryer feet, within one rendered pixel");
    }

    private async Task CheckRenderedContours()
    {
        _viewport.TransparentBg = true;
        using var pixels = Image.CreateEmpty(128, 128, false, Image.Format.Rgba8);
        pixels.Fill(Colors.Transparent);
        pixels.FillRect(new Rect2I(32, 32, 64, 64), Colors.Red);
        var texture = ImageTexture.CreateFromImage(pixels);
        var fixture = new Control { Position = new Vector2(300, 250), MouseFilter = Control.MouseFilterEnum.Ignore };
        _viewport.AddChild(fixture);
        var body = new TextureRect { Texture = texture, Position = new Vector2(20, 30), Size = new Vector2(128, 128),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.Scale,
            MouseFilter = Control.MouseFilterEnum.Ignore };
        fixture.AddChild(body);
        var head = new TextureRect { Texture = texture, Position = new Vector2(76, 46), Size = new Vector2(96, 96),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.Scale,
            MouseFilter = Control.MouseFilterEnum.Ignore };
        fixture.AddChild(head);
        var state = InteractionHighlightState.Hover;
        var contour = ArtContourHighlight.Attach(body, () => state, head);
        static bool Near(Color a, Color b) => Math.Abs(a.R - b.R) + Math.Abs(a.G - b.G) + Math.Abs(a.B - b.B) < .14f;
        bool IsHighlight(Color color) => Near(color, InteractionHighlightPresentation.ColorFor(state, body));
        async Task Verify(float expected, string description, float edgeX = 32, float edgeY = 64)
        {
            await Wait(.16); await Frames();
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            using Image rendered = _viewport.GetTexture().GetImage();
            Vector2 edge = InteractionHighlightPresentation.PixelTransform(body) * new Vector2(edgeX, edgeY);
            int count = 0;
            for (int x = (int)MathF.Floor(edge.X) - 9; x < (int)MathF.Ceiling(edge.X) + 2; x++)
                if (IsHighlight(rendered.GetPixel(x, (int)edge.Y))) count++;
            if (Math.Abs(count - expected) > 1)
            {
                rendered.SavePng(ProjectSettings.GlobalizePath("res://.tmp/hover-render-failure.png"));
                GD.Print("EDGE_PIXELS " + string.Join(",", Enumerable.Range(-9, 12).Select(x => rendered.GetPixel((int)edge.X + x, (int)edge.Y).ToHtml())));
            }
            Check(Math.Abs(count - expected) <= 1, $"{description}: rendered stroke {count}px (expected {expected}px)");
            if (InteractionHighlightTheme.Applies(body, state))
            {
                // At fractional positions the 1px backing mixes with its neighbours;
                // measure the complete exterior coverage, not exact-color pixel count.
                int exterior = Enumerable.Range(-9, 9).Count(x => rendered.GetPixel((int)edge.X + x, (int)edge.Y).A > .15f);
                Check(exterior is >= 5 and <= 7 && exterior > count,
                    $"{description}: full 6px exterior including backing is not clipped ({exterior}px)");
                Vector2 inside = edge + new Vector2(3, 0);
                Check(Near(rendered.GetPixel((int)inside.X, (int)inside.Y), Colors.Red), "themed shader preserves source interior");
            }
            if (head.Visible)
            {
                Vector2 overlap = InteractionHighlightPresentation.PixelTransform(body) * new Vector2(96, 64);
                Check(!IsHighlight(rendered.GetPixel((int)overlap.X, (int)overlap.Y)), "combined layers have no internal seam");
            }
        }
        await Verify(4, "hover follows alpha at viewport scale");
        using var otherCity = new Control();
        InteractionHighlightTheme.Set(fixture, InteractionHighlightTheme.Tianjin);
        Check(InteractionHighlightPresentation.ColorFor(state, body) == InteractionHighlightTheme.Tianjin.HoverColor
            && InteractionHighlightPresentation.WidthFor(state, otherCity) == 4
            && InteractionHighlightPresentation.ColorFor(state, otherCity) == new Color("#FFE7A4"), "theme inherits within its scene without affecting other cities");
        await Verify(5, "Tianjin themed hover");
        InteractionHighlightTheme.Set(fixture, InteractionHighlightTheme.Wuhan);
        await Verify(5, "Wuhan themed hover");
        state = InteractionHighlightState.None; contour._Process(.1);
        Check(!contour.Visible, "themed hover clears immediately on exit");
        state = InteractionHighlightState.Hover; contour._Process(.025);
        float alpha = ((ShaderMaterial)contour.Material).GetShaderParameter("contour_color").AsColor().A;
        Check(alpha > .2f && alpha < .3f, "hover reentry starts a fresh 100ms fade");
        ProjectSettings.SetSetting("accessibility/reduce_motion", true); contour._Process(0);
        Check(((ShaderMaterial)contour.Material).GetShaderParameter("contour_color").AsColor().A == 1, "reduced motion shows the themed contour immediately");
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
        fixture.Scale = new Vector2(.7f, 1.15f);
        await Verify(5, "themed hover survives non-uniform parent scaling");
        foreach (var semantic in new[] { InteractionHighlightState.Selected, InteractionHighlightState.Eligible,
            InteractionHighlightState.Valid, InteractionHighlightState.Invalid, InteractionHighlightState.Attention })
            Check(InteractionHighlightPresentation.ColorFor(semantic, body) == InteractionHighlightPresentation.ColorFor(semantic)
                && InteractionHighlightPresentation.WidthFor(semantic, body) == InteractionHighlightPresentation.WidthFor(semantic), "theme preserves semantic state " + semantic);
        state = InteractionHighlightState.Valid;
        await Verify(5, "valid outline survives non-uniform parent scaling");
        // Atlas cropping uses the actual region; unrelated pixels in the atlas cannot leak in.
        using var atlasPixels = Image.CreateEmpty(256, 128, false, Image.Format.Rgba8);
        atlasPixels.Fill(Colors.Blue); atlasPixels.BlitRect(pixels, new Rect2I(0, 0, 128, 128), new Vector2I(128, 0));
        body.Texture = new AtlasTexture { Atlas = ImageTexture.CreateFromImage(atlasPixels), Region = new Rect2(128, 0, 128, 128) };
        await Verify(5, "live texture replacement and atlas region remain aligned");
        pixels.FillRect(new Rect2I(16, 32, 16, 64), Colors.Red);
        body.Texture = ImageTexture.CreateFromImage(pixels);
        await Verify(5, "changed silhouette follows the replacement expression", 16);
        body.FlipH = true;
        await Verify(5, "asymmetric flipped artwork follows its visible edge");
        head.Hide(); body.Size = new Vector2(128, 64); body.StretchMode = TextureRect.StretchModeEnum.KeepAspectCovered;
        await Verify(5, "covered texture follows its cropped fitted rectangle", 32, 32);
        state = InteractionHighlightState.None;
        await Wait(.18);
        Check(!fixture.GetChildren().OfType<ArtContourHighlight>().Single().Visible, "cleared state removes the contour");
        fixture.QueueFree();
        await Frames();
        _viewport.TransparentBg = false;
        await CheckRasterSilhouette();
    }

    private async Task CheckRasterSilhouette()
    {
        using var pixels = Image.CreateEmpty(32, 32, false, Image.Format.Rgba8);
        pixels.Fill(Colors.Transparent);
        pixels.FillRect(new Rect2I(8, 8, 16, 16), Colors.White);
        pixels.FillRect(new Rect2I(12, 12, 8, 8), Colors.Transparent);
        Texture2D texture = ImageTexture.CreateFromImage(pixels);
        var raster = new Node2D { Position = new Vector2(600, 400), Scale = new Vector2(.8f, .7f) };
        _viewport.AddChild(raster);
        raster.Draw += () => DrawnArtContour.Draw(raster, texture, new Rect2(0, 0, 160, 120), InteractionHighlightState.Hover);
        raster.QueueRedraw(); await Frames();
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using Image rendered = _viewport.GetTexture().GetImage();
        Transform2D transform = InteractionHighlightPresentation.PixelTransform(raster);
        bool Highlight(Vector2 p)
        {
            Color c = rendered.GetPixel((int)p.X, (int)p.Y);
            return c.R > .8f && c.G > .65f && c.B > .3f;
        }
        Vector2 left = transform * new Vector2(40, 60);
        int count = Enumerable.Range(-8, 11).Count(x => Highlight(left + new Vector2(x, 0)));
        Check(Math.Abs(count - 4) <= 1, $"raster silhouette retains a 4px outer stroke under scaling ({count}px)");
        Check(!Highlight(transform * new Vector2(60, 60)) && !Highlight(transform * new Vector2(80, 60)),
            "filter mesh holes have no internal highlight");
        foreach (var theme in new[] { InteractionHighlightTheme.Tianjin, InteractionHighlightTheme.Wuhan })
        {
            _viewport.TransparentBg = true;
            InteractionHighlightTheme.Set(raster, theme);
            ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            raster.QueueRedraw(); await Frames();
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            using Image themed = _viewport.GetTexture().GetImage();
            bool Near(Color a, Color b) => Math.Abs(a.R-b.R) + Math.Abs(a.G-b.G) + Math.Abs(a.B-b.B) < .16f;
            int core = Enumerable.Range(-9, 10).Count(x => Near(themed.GetPixel((int)left.X+x, (int)left.Y), theme.HoverColor));
            int exterior = Enumerable.Range(-9, 9).Count(x => themed.GetPixel((int)left.X+x, (int)left.Y).A > .15f);
            Check(core is >= 3 and <= 6 && exterior is >= 5 and <= 7 && exterior > core,
                $"themed raster preserves 6px exterior with distinct core and backing ({core}/{exterior})");
            Color interior = themed.GetPixel((int)(transform * new Vector2(60,60)).X, (int)(transform * new Vector2(60,60)).Y);
            Check(!Near(interior, theme.HoverColor) && !Near(interior, InteractionHighlightTheme.BackingColor), "themed raster does not paint source interior");
        }
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
        _viewport.TransparentBg = true;
        raster.Rotation = .23f;
        raster.QueueRedraw(); await Wait(.2); await Frames();
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using Image angled = _viewport.GetTexture().GetImage();
        byte[] rgba = angled.GetData();
        int partial = 0, opaque = 0;
        for (int i = 3; i < rgba.Length; i += 4)
        {
            if (rgba[i] > 0 && rgba[i] < 255) partial++;
            if (rgba[i] == 255) opaque++;
        }
        Check(partial > 20 && opaque > 20,
            "angled raster contour has antialiased coverage and an opaque stroke core");
        _viewport.TransparentBg = false;
        raster.QueueFree();
        await Frames();
        await CheckDrawnTargetSwitch();
    }

    private async Task CheckDrawnTargetSwitch()
    {
        var canvas = new Node2D { Position = new Vector2(400, 350), Scale = new Vector2(.8f, 1.1f) };
        _viewport.AddChild(canvas);
        InteractionHighlightTheme.Set(canvas, InteractionHighlightTheme.Wuhan);
        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        int target = 0;
        Vector2[][] paths = {
            new[] { new Vector2(0,0), new Vector2(80,0), new Vector2(80,80), new Vector2(0,80) },
            new[] { new Vector2(120,0), new Vector2(200,0), new Vector2(200,80), new Vector2(120,80) },
        };
        canvas.Draw += () => {
            for (int i = 0; i < 2; i++)
            {
                canvas.DrawColoredPolygon(paths[i], Colors.Red);
                InteractionHighlightPresentation.DrawPath(canvas, paths[i], target == i
                    ? InteractionHighlightState.Hover : InteractionHighlightState.None);
            }
        };
        foreach (int next in new[] { 0, 1, -1 })
        {
            target = next; canvas.QueueRedraw(); await Frames();
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            using Image rendered = _viewport.GetTexture().GetImage();
            for (int i = 0; i < 2; i++)
            {
                Vector2 p = InteractionHighlightPresentation.PixelTransform(canvas) * new Vector2(i * 120, 40);
                Color outside = rendered.GetPixel((int)p.X - 3, (int)p.Y);
                bool lit = outside.G > .5f && outside.B > .45f && outside.R < .3f;
                Check(lit == (target == i), $"direct path switch {next}: only the current target {i} is highlighted");
                Color inside = rendered.GetPixel((int)p.X + 3, (int)p.Y);
                Check(inside.R > .95f && inside.G < .05f, "direct path preserves original interior pixels");
            }
        }
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
        canvas.QueueFree(); await Frames();
    }

    private static void BeginYoutiaoDrag(DragItem source)
    {
        using var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true,
            Position = source.Size * .5f };
        source._GuiInput(press);
    }

    private void MoveDrag(DragService drag, Vector2 point)
    {
        MovePointer(point);
        using var motion = new InputEventMouseMotion { Position = point, GlobalPosition = point };
        drag._Input(motion);
    }

    private void MovePointer(Vector2 point)
    {
        using var motion = new InputEventMouseMotion { Position = point, GlobalPosition = point };
        _viewport.PushInput(motion, true);
    }

    private async Task Frames()
    {
        for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task Wait(double seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);

    private async Task Shot(string name)
    {
        if (!Capture) return;
        await Wait(.15);
        await Frames();
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string directory = ProjectSettings.GlobalizePath("res://.tmp/interaction-highlights");
        Directory.CreateDirectory(directory);
        Error saved = _viewport.GetTexture().GetImage().SavePng(Path.Combine(directory, $"{name}-{CaptureWidth}.png"));
        Check(saved == Error.Ok, "saved " + name);
    }
}
