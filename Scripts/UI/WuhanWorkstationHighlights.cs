using Godot;
using ProjectCake.Interaction;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private void DrawEquipmentHighlights()
    {
        if (CanInteract?.Invoke() != true) return;
        Vector2 pointer = GetLocalMousePosition();
        string hover = HitTarget(pointer);
        bool dragging = _drag?.IsDragging == true;
        InteractionHighlightState State(string target)
        {
            if (_trashPressed && _trashChannel == target) return InteractionHighlightState.Selected;
            if (dragging) return InteractionHighlightState.None;
            if (_mixHeld && target == "bowl") return InteractionHighlightState.Selected;
            if (HasProductionGesture)
            {
                if (_gesture == "raw" && target.StartsWith("basket"))
                {
                    int index = int.Parse(target[6..]);
                    bool valid = _cooker.Baskets[index].State == NoodleBasketState.Empty && !Busy(target);
                    bool over = BasketRect(index).Grow(22).HasPoint(_gesturePoint);
                    return over ? valid ? InteractionHighlightState.Valid : InteractionHighlightState.Invalid
                        : valid ? InteractionHighlightState.Eligible : InteractionHighlightState.None;
                }
                if (_gesture == "basket" && target == "bowl")
                {
                    bool valid = _bowl.State == NoodleBowlState.Empty && IsRaised(_cooker.Baskets[_gestureBasket].State);
                    bool over = BowlRect.Grow(20).HasPoint(_gesturePoint);
                    return over ? valid ? InteractionHighlightState.Valid : InteractionHighlightState.Invalid
                        : valid ? InteractionHighlightState.Eligible : InteractionHighlightState.None;
                }
                if (target == "pan" && _gesture is "batter" or "filling" or "spread" or "flip" or "cut")
                {
                    bool valid = _gesture switch
                    {
                        "batter" => _doupi?.State == DoupiState.Empty,
                        "filling" => _fillingDeposited || _doupi?.State == DoupiState.Flipped,
                        _ => true,
                    };
                    return OnPan(_gesturePoint) ? valid ? InteractionHighlightState.Valid : InteractionHighlightState.Invalid
                        : valid ? InteractionHighlightState.Eligible : InteractionHighlightState.None;
                }
                return InteractionHighlightState.None;
            }
            return hover == target ? InteractionHighlightState.Hover : InteractionHighlightState.None;
        }
        void Path(Vector2[] points, InteractionHighlightState state) => InteractionHighlightPresentation.DrawPath(this, points, state);
        void SourcePath(Vector2[] points, InteractionHighlightState state) => Path(points.Select(p => WuhanWorkbenchLayout.Point(p.X, p.Y)).ToArray(), state);
        void SpriteContour(string id, Rect2 box, InteractionHighlightState state)
        {
            Texture2D texture = _art.Texture(id);
            DrawnArtContour.Draw(this, texture, FitSprite(texture, box), state, Source(texture));
        }

        for (int i = 0; i < _cooker.Baskets.Count; i++)
        {
            if (HasProductionGesture && _gestureBasket == i && _gesture == "basket"
                || _cooker.PendingPourBasket == i || Find($"basket{i}")?.Kind == "pour" && !ReducedMotion) continue;
            SpriteContour("basket", BasketRect(i), State($"basket{i}"));
        }
        InteractionHighlightState cooker = !dragging && !HasProductionGesture && hover.Length == 0
            && CookerCanvas.HasPoint(pointer) ? InteractionHighlightState.Hover : InteractionHighlightState.None;
        SourcePath(new Vector2[] { new(59, 568), new(60, 540), new(69, 523), new(94, 519), new(105, 494),
            new(130, 471), new(171, 450), new(217, 437), new(270, 434), new(320, 440), new(369, 453),
            new(408, 476), new(434, 503), new(448, 519), new(474, 526), new(484, 546), new(482, 579),
            new(470, 596), new(449, 604), new(445, 642), new(430, 668), new(405, 689), new(365, 701),
            new(170, 703), new(127, 687), new(105, 664), new(94, 635), new(91, 599), new(69, 594) }, cooker);
        Path(_layout.BowlOutline, State("bowl"));
        SourcePath(new Vector2[] { new(42, 839), new(35, 814), new(55, 736), new(70, 725), new(79, 711),
            new(94, 704), new(370, 704), new(386, 714), new(389, 731), new(403, 737), new(397, 813),
            new(384, 830), new(379, 863), new(367, 879), new(60, 879) }, State("raw"));
        for (int i = 0; i < IngredientIds.Length; i++)
        {
            Rect2 r = IngredientRect(i);
            Path(BowlContour(r), State($"ingredient{i}"));
        }
        if (_doupi is not null)
        {
            SourcePath(new Vector2[] { new(1023, 590), new(1027, 542), new(1037, 523), new(1060, 516),
                new(1069, 491), new(1090, 477), new(1379, 477), new(1399, 488), new(1410, 516),
                new(1435, 522), new(1448, 543), new(1455, 594), new(1445, 611), new(1432, 618),
                new(1431, 672), new(1419, 691), new(1398, 701), new(1081, 701), new(1058, 692),
                new(1047, 675), new(1047, 616), new(1031, 611) },
                State("pan"));
            SourcePath(new Vector2[] { new(1282, 833), new(1291, 752), new(1302, 736), new(1317, 731),
                new(1598, 731), new(1615, 739), new(1623, 756), new(1640, 836), new(1631, 858),
                new(1613, 871), new(1310, 872), new(1292, 861) }, State("stock"));
            SourcePath(new Vector2[] { new(1070, 775), new(1074, 748), new(1094, 723), new(1130, 707),
                new(1172, 704), new(1217, 715), new(1251, 735), new(1268, 759), new(1270, 827),
                new(1255, 850), new(1220, 868), new(1171, 876), new(1123, 868), new(1088, 848), new(1070, 821) }, State("filling"));
            Path(TrayContour(BatterRect), State("batter"));
            Path(TrayContour(DoupiEggRect), State("doupi_egg"));
            if (_gesture != "batter" && (ReducedMotion || Find("pan")?.Kind != "batter"))
                SpriteContour("doupi_ladle", _layout.BatterLadle, State("batter"));
            if (ReducedMotion || Find("pan")?.Kind != "egg") SpriteContour("egg_ladle", _layout.DoupiEggFood, State("doupi_egg"));
        }
        if (IsInstanceValid(TrashZone))
        {
            var state = InteractionHighlightPresentation.FromDropZone(TrashZone.VisualState);
            if (state == InteractionHighlightState.None && !dragging && WuhanWorkbenchLayout.EmbeddedTrash.HasPoint(pointer))
                state = InteractionHighlightState.Hover;
            SourcePath(new Vector2[] { new(1007, 897), new(1010, 878), new(1020, 873), new(1026, 870),
                new(1134, 870), new(1140, 874), new(1153, 878), new(1158, 897), new(1150, 908),
                new(1145, 941), new(1019, 941), new(1016, 908) }, state);
        }
    }

    private static Vector2[] BowlContour(Rect2 rect) => new Vector2[] { new(0, .43f), new(.03f, .25f),
        new(.15f, .11f), new(.34f, .025f), new(.55f, 0), new(.77f, .075f), new(.94f, .23f), new(1, .43f),
        new(.96f, .66f), new(.85f, .86f), new(.67f, .98f), new(.44f, 1), new(.22f, .90f), new(.08f, .69f) }
        .Select(p => rect.Position + p * rect.Size).ToArray();
    private static Vector2[] TrayContour(Rect2 rect) => new Vector2[] { new(.02f, .13f), new(.10f, .035f),
        new(.23f, 0), new(.76f, 0), new(.90f, .04f), new(.96f, .16f), new(1, .67f), new(.97f, .85f),
        new(.88f, .97f), new(.15f, 1), new(.07f, .92f), new(.04f, .78f), new(0, .28f) }
        .Select(p => rect.Position + p * rect.Size).ToArray();
}
