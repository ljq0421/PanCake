using Godot;
using ProjectCake.Data;
using ProjectCake.Interaction;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private static void PositionEmbedded(Control control, Rect2 rect)
    {
        control.SetAnchorsPreset(LayoutPreset.TopLeft);
        control.CustomMinimumSize = Vector2.Zero;
        control.Position = rect.Position;
        control.Size = rect.Size;
        control.Scale = Vector2.One;
    }

    private void ConfigureTianjinPresentation()
    {
        foreach (DropZone zone in this.Descendants<DropZone>())
            zone.HideInteractionFrame();
        foreach (WorkstationSlotView slot in this.Descendants<WorkstationSlotView>())
            slot.HideInteractionFrame();
        Rect2 viewport = new(0, 0, 1920, 1080);
        MouseFilter = MouseFilterEnum.Ignore;
        // Keep the canvas, stroke and drop zone in one coordinate space.
        Control stoveStage = _canvas.GetParent<Control>();
        stoveStage.Reparent(this, false);
        PositionEmbedded(stoveStage, viewport);
        stoveStage.MouseFilter = MouseFilterEnum.Ignore;
        PositionEmbedded(_canvas, TianjinWorkbenchLayout.EmbeddedStove);
        Rect2 surface = TianjinWorkbenchLayout.EmbeddedSurface;
        _canvas.EmbeddedSurface = new Rect2(surface.Position - _canvas.Position, surface.Size);
        _canvas.ShowBaggedPancake = false;
        foreach (Button button in new[] { _flip, _finishSauce, _fold, _bag, _discard })
            button.CustomMinimumSize = new Vector2(0, 48);
        foreach (Button button in new[] { _lowerBasket, _raiseBasket, _discardBatch })
            button.CustomMinimumSize = new Vector2(0, 44);
        PositionEmbedded(_pancakeActions, new Rect2(910, 948, 143, 48));
        LayoutStoveInputs();

        PositionEmbedded(_fryerPanel, viewport);
        _fryerPanel.ZIndex = 35;
        // The painted fryer rises above the counter and must occlude customer waists.
        // Sample the unchanged source art through its silhouette, not a rectangular patch.
        Vector2[] fryerOutline = {
            new(162, 447), new(389, 447), new(414, 461), new(428, 506), new(452, 510),
            new(466, 555), new(452, 573), new(449, 665), new(435, 699), new(396, 709),
            new(141, 709), new(117, 692), new(111, 577), new(97, 565), new(108, 516),
            new(123, 508), new(139, 467) };
        var foreground = new Polygon2D {
            Name = "EmbeddedFryerForeground", Polygon = fryerOutline, UV = fryerOutline,
            Texture = _art.WorkbenchBackground(new[] { ProductKind.Youtiao }), Scale = TianjinWorkbenchLayout.SourceScale };
        _fryerPanel.AddChild(foreground);
        // Trace the source silhouette: the exact painted tongs must remain in
        // front of customers without covering the gap between their two arms.
        Vector2[][] tongOutlines = {
            new Vector2[] { new(480, 477), new(487, 480), new(489, 487), new(487, 497),
                new(492, 506), new(491, 514), new(488, 518), new(492, 526), new(490, 534),
                new(493, 541), new(489, 549), new(494, 575), new(501, 595), new(486, 596),
                new(479, 570), new(474, 548), new(469, 536), new(466, 521), new(463, 508),
                new(464, 490), new(468, 480), new(473, 477) },
            new Vector2[] { new(529, 478), new(536, 480), new(541, 492), new(542, 505),
                new(539, 520), new(537, 531), new(533, 544), new(528, 560), new(522, 591),
                new(506, 596), new(510, 577), new(515, 553), new(513, 541), new(511, 532),
                new(514, 524), new(511, 517), new(513, 509), new(517, 502), new(516, 493), new(521, 481) },
            new Vector2[] { new(469, 568), new(481, 562), new(518, 562), new(535, 570),
                new(541, 582), new(540, 654), new(535, 668), new(516, 677), new(482, 675),
                new(468, 667), new(461, 653), new(461, 585) }
        };
        var tongs = new Node2D { Name = "EmbeddedTongsForeground" };
        _fryerPanel.AddChild(tongs);
        foreach (Vector2[] outline in tongOutlines)
            tongs.AddChild(new Polygon2D { Polygon = outline, UV = outline,
                Texture = foreground.Texture, Scale = TianjinWorkbenchLayout.SourceScale });
        _fryerVisual.Reparent(_fryerPanel, false);
        _fryerVisual.ZIndex = 1;
        PositionEmbedded(_fryerVisual, TianjinWorkbenchLayout.EmbeddedFryer);
        _fryerVisual.EmbeddedOpening = new Rect2(
            TianjinWorkbenchLayout.EmbeddedOpening.Position - _fryerVisual.Position,
            TianjinWorkbenchLayout.EmbeddedOpening.Size);
        EquipmentProgressView.Attach(this, "PancakeCookingProgress", new Rect2(700, 893, 240, 42),
            () => EquipmentProgressPresentation.Pancake(Machine));
        EquipmentProgressView.Attach(_fryerPanel, "FryerCookingProgress", new Rect2(196, 767, 240, 42),
            () => EquipmentProgressPresentation.Fryer(FryerMachine)).ZIndex = 3;
        Control rawSlot = _rawYoutiaoInput.GetParent().GetParent<Control>();
        _rawYoutiaoInput.Reparent(_fryerPanel, false);
        _rawYoutiaoInput.ZIndex = 2;
        rawSlot.Hide();
        PositionEmbedded(_rawYoutiaoInput, TianjinWorkbenchLayout.EmbeddedFryer);
        _rawYoutiaoInput.Contains = null;
        _rawYoutiaoInput.ActivateOnTap = false;
        _rawYoutiaoInput.TooltipText = "长按炸锅连续装料，松开停止";
        _rawYoutiaoInput.CanActivate = () => CanLoadRawYoutiao() && !_drag.IsDragging;
        PositionEmbedded(_fryerStatus.GetParent<Control>(), new Rect2(108, 955, 266, 44));
        PositionEmbedded(_fryerActions, new Rect2(383, 955, 150, 44));
        _finishedYoutiaoSlot.Reparent(_fryerPanel, false);
        Rect2 rack = TianjinWorkbenchLayout.EmbeddedYoutiaoTray;
        var rackSpec = TianjinWorkbenchLayout.EmbeddedFinishedYoutiaoSlot();
        _finishedYoutiaoSlot.ContainerInBackground = true;
        _finishedYoutiaoSlot.Configure(_art.WorkbenchFinishedYoutiaoRack, _art.Ingredient(StableIds.Ingredients.Youtiao),
            "熟油条", rackSpec, IngredientVisualMode.WideStock);
        PositionEmbedded(_finishedYoutiaoSlot, rack);
        _finishedYoutiaoSlot.HideNameplate();
        _storedYoutiao.CustomMinimumSize = Vector2.Zero;

        foreach ((string id, IngredientStockSlotView slot) in _ingredientSlots)
        {
            slot.Reparent(this, false);
            bool bowl = id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce;
            slot.ContainerInBackground = true;
            slot.IngredientInBackground = bowl;
            slot.ConfigureStock(_art.WorkbenchTray, _art.Ingredient(id), IngredientName(id),
                TianjinWorkbenchLayout.EmbeddedIngredientSlot(id), bowl ? IngredientVisualMode.Single
                    : id == StableIds.Ingredients.Scallion ? IngredientVisualMode.LooseStock : IngredientVisualMode.HybridStock);
            PositionEmbedded(slot, TianjinWorkbenchLayout.EmbeddedIngredient(id));
            slot.ShowStockNumbers = false;
            slot.HideNameplate();
            foreach (StockGesture gesture in slot.GetChildren().OfType<StockGesture>())
                PositionEmbedded(gesture, slot.ClickBounds);
            var firstUse = slot.GetNode<Label>("FirstUseHint");
            PositionEmbedded(firstUse, new Rect2(0, slot.Size.Y - 5, slot.Size.X, 24));
            firstUse.AddThemeFontSizeOverride("font_size", 16);
            slot.GetNode<Label>("HoldRefillHint").AddThemeFontSizeOverride("font_size", 16);
        }

        Control finishedSlot = _finished.GetParent<Control>();
        finishedSlot.Reparent(this, false);
        PositionEmbedded(finishedSlot, new Rect2(surface.GetCenter() - new Vector2(122, 110), new Vector2(244, 220)));
        finishedSlot.ZIndex = 40;
        finishedSlot.GetNode<TextureRect>("FinishedTrayArt").Hide();
        PositionEmbedded(_finished, new Rect2(0, 0, 244, 220));
        var finishedArt = (TextureRect)_finished.FindChild("FinishedPancakeArt", true, false);
        PositionEmbedded(finishedArt, new Rect2(12, 5, 220, 210));
        PositionEmbedded(_directDeliveryHint, new Rect2(10, 208, 224, 26));
        _previousPancake?.Hide(); _nextPancake?.Hide(); _bagTransfer.Hide();

        _soyPanel.Reparent(this, false);
        Rect2 soy = TianjinWorkbenchLayout.EmbeddedSoyTray;
        PositionEmbedded(_soyPanel, soy);
        _soyPanel.GetNode<TextureRect>("SoyMilkTrayArt").Hide();
        PositionEmbedded(_soyCup, new Rect2(Vector2.Zero, soy.Size));
        if (_soyStockArt is not null)
        {
            PositionEmbedded(_soyStockArt, new Rect2(Vector2.Zero, soy.Size));
            for (int i = 0; i < _soyStockArt.Cups.Count; i++)
            {
                var cup = _soyStockArt.Cups[i];
                PositionEmbedded(cup, TianjinWorkbenchLayout.EmbeddedSoyCup(i, cup.Texture.GetSize()));
            }
        }
        PositionEmbedded(_soyStatus, new Rect2(0, soy.Size.Y - 2, soy.Size.X, 26));
        StockGesture soyGesture = _stockGestures.Single(g => g.Name == "StockGesture_soy_milk");
        PositionEmbedded(soyGesture, new Rect2(Vector2.Zero, soy.Size));
        if (_soyHoldProgress is not null) PositionEmbedded(_soyHoldProgress, new Rect2(14, soy.Size.Y + 23, soy.Size.X - 28, 4));

        // Tianjin uses the painted cash pendant. Keep the legacy node inert for shared scene binding.
        CoinTray!.Reparent(this, false);
        PositionEmbedded(CoinTray, new Rect2(1562, 98, 180, 50));
        CoinTray.ZIndex = 75;
        CoinTray.ConfigureButtonPresentation();
        CoinTray.Hide();
        CoinTray.CanCollect = () => false;
        _trashZone.Reparent(this, false);
        _trashZone.GetNode<Control>("TrashArtLayer").Hide();
        _trashZone.GetNode<Control>("TrashLabelLayer").Hide();
        _trashZone.ResetSize();
        PositionEmbedded(_trashZone, TianjinWorkbenchLayout.EmbeddedTrash);
        _trashZone.ZIndex = 75;
        _trashZone.MouseFilter = MouseFilterEnum.Stop;
        _trashZone.TooltipText = "长按鼠标右键 0.45 秒后拖入食物，松开丢弃；豆浆不可丢弃";
        _trashZone.HitPadding = 0;
        _trashZone.FixedHitRect = TianjinWorkbenchLayout.EmbeddedTrash;
        _trashZone.Configure(CanAcceptTianjinTrash, CommitTianjinTrash);
        _deliveryZone.Hide();
        ConfigureTianjinHighlights(fryerOutline);
    }
}
