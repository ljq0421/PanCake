using Godot;
using ProjectCake.Interaction;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private void DrawEquipmentHighlights(bool basketsOnly = false)
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
        // A narrow search keeps close-set trays and spoon handles from snapping
        // to the dark edges of neighbouring cookware.
        void SourcePath(Vector2[] points, InteractionHighlightState state, int radius = 10) => BackgroundArtContour.Draw(this,
            _art.WorkbenchBackground(_doupi is not null), points.Select(p => WuhanWorkbenchLayout.Point(p.X, p.Y)).ToArray(),
            new Rect2(0, 0, 1920, 1080), state, edgeSearchRadius: radius);
        void SpriteContour(string id, Rect2 box, InteractionHighlightState state)
        {
            Texture2D texture = _art.Texture(id);
            DrawnArtContour.Draw(this, texture, FitSprite(texture, box), state, Source(texture));
        }

        if (basketsOnly)
        {
            for (int i = 0; i < _cooker.Baskets.Count; i++)
            {
                if (HasProductionGesture && _gestureBasket == i && _gesture == "basket"
                    || _cooker.PendingPourBasket == i || Find($"basket{i}")?.Kind == "pour" && !ReducedMotion) continue;
                InteractionHighlightState state = State($"basket{i}");
                // Readiness remains green under the pointer; hover never hides cooking information.
                if (!HasProductionGesture && IsBasketReady(_cooker.Baskets[i].State)) state = InteractionHighlightState.Valid;
                SpriteContour("basket", BasketRect(i), state);
            }
            return;
        }
        SourcePath(WuhanArtworkContours.MixingBowl, State("bowl"), radius: 0);
        SourcePath(RawTraySilhouette, State("raw"), radius: 0);
        for (int i = 0; i < IngredientIds.Length; i++)
        {
            SourcePath(IngredientSilhouette(i), State($"ingredient{i}"), radius: i is 1 or 3 ? 0 : i == 0 ? 10 : 2);
        }
        if (_doupi is not null)
        {
            SourcePath(new Vector2[] { new(1282, 833), new(1291, 752), new(1302, 736), new(1317, 731),
                new(1598, 731), new(1615, 739), new(1623, 756), new(1640, 836), new(1631, 858),
                new(1613, 871), new(1310, 872), new(1292, 861) }, State("stock"));
            SourcePath(new Vector2[] { new(1070, 775), new(1074, 748), new(1094, 723), new(1130, 707),
                new(1172, 704), new(1217, 715), new(1251, 735), new(1268, 759), new(1270, 827),
                new(1255, 850), new(1220, 868), new(1171, 876), new(1123, 868), new(1088, 848), new(1070, 821) }, State("filling"));
            SourcePath(new Vector2[] { new(1466,629), new(1466,618), new(1470,610), new(1479,604),
                new(1490,602), new(1530,602), new(1570,602), new(1605,602), new(1618,603), new(1624,607),
                new(1631,617), new(1635,630), new(1642,650), new(1648,667), new(1647,678), new(1642,697), new(1637,708), new(1630,714),
                new(1616,717), new(1500,717), new(1487,712), new(1480,703), new(1476,688) }, State("batter"), radius: 2);
            SourcePath(new Vector2[] { new(1451,514), new(1452,506), new(1458,499), new(1469,496),
                new(1585,496), new(1596,500), new(1604,509), new(1610,528), new(1626,563),
                new(1628,573), new(1625,586), new(1621,597), new(1618,601), new(1480,601),
                new(1471,596), new(1466,587), new(1462,570) }, State("doupi_egg"), radius: 2);
            if (_gesture != "batter" && (ReducedMotion || Find("pan")?.Kind != "batter"))
                SpriteContour("doupi_ladle", _layout.BatterLadle, State("batter"));
            if (ReducedMotion || Find("pan")?.Kind != "egg") SpriteContour("egg_ladle", _layout.DoupiEggFood, State("doupi_egg"));
        }
        if (IsInstanceValid(TrashZone))
        {
            var state = InteractionHighlightPresentation.FromDropZone(TrashZone.VisualState);
            if (state == InteractionHighlightState.None && !dragging && WuhanWorkbenchLayout.EmbeddedTrash.HasPoint(pointer))
                state = InteractionHighlightState.Hover;
            SourcePath(WuhanArtworkContours.Trash, state, radius: 0);
        }
    }

    // Independent source-art traces include the spoon handles and the full bowl bases.
    private static Vector2[] IngredientSilhouette(int index) => index switch {
        0 => new Vector2[] { new(423,767), new(428,751), new(440,738), new(457,729), new(481,721),
            new(504,720), new(532,725), new(550,701), new(559,695), new(568,697), new(573,704),
            new(571,711), new(551,740), new(563,755), new(568,773), new(564,795), new(555,819),
            new(540,838), new(518,849), new(493,852), new(468,846), new(449,832), new(436,812), new(427,789) },
        1 => ScallionSilhouette,
        2 => new Vector2[] { new(573,769), new(579,750), new(592,736), new(613,727), new(639,721),
            new(660,722), new(675,726), new(682,729), new(700,699), new(706,695), new(714,695), new(721,701), new(720,710),
            new(701,738), new(711,754), new(718,775), new(714,798), new(704,824), new(687,842),
            new(661,853), new(635,855), new(611,846), new(592,829), new(581,806), new(575,784) },
        3 => BeefSilhouette,
        _ => throw new ArgumentOutOfRangeException(nameof(index)),
    };
}
