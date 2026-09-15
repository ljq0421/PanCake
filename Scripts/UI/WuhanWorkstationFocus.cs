using Godot;
namespace ProjectCake.UI;
public partial class WuhanWorkstationView
{
    internal string TeachingGesture => _gesture;
    internal int TeachingBasket => _gestureBasket;
    internal bool TeachingTrashActive => _drag?.IsDragging == true && _trashValid is not null;
    private static Vector2[] EquipmentSilhouette(string id) => id switch {
        "stock" => new Vector2[] { new(1282, 834), new(1288, 750), new(1301, 735), new(1467, 735),
                new(1484, 746), new(1498, 839), new(1486, 871), new(1305, 872), new(1288, 861) },
        "knife" => new Vector2[] { new(1502, 750), new(1514, 736), new(1605, 736), new(1623, 749),
                new(1650, 856), new(1637, 878), new(1531, 880), new(1517, 866) },
        "filling" => new Vector2[] { new(1070, 775), new(1074, 748), new(1094, 723), new(1130, 707),
                new(1172, 704), new(1217, 715), new(1251, 735), new(1268, 759), new(1270, 827),
                new(1255, 850), new(1220, 868), new(1171, 876), new(1123, 868), new(1088, 848), new(1070, 821) },
        "doupi_egg" => new Vector2[] { new(1466,629), new(1466,618), new(1470,610), new(1479,604),
                new(1490,602), new(1530,602), new(1570,602), new(1605,602), new(1618,603), new(1624,607),
                new(1631,617), new(1635,630), new(1642,650), new(1648,667), new(1647,678), new(1642,697), new(1637,708), new(1630,714),
                new(1616,717), new(1500,717), new(1487,712), new(1480,703), new(1476,688) },
        "batter" => new Vector2[] { new(1451,514), new(1452,506), new(1458,499), new(1469,496),
                new(1585,496), new(1596,500), new(1604,509), new(1610,528), new(1626,563),
                new(1628,573), new(1625,586), new(1621,597), new(1618,601), new(1480,601),
                new(1471,596), new(1466,587), new(1462,570) },
        _ => throw new ArgumentOutOfRangeException(nameof(id)),
    };
    internal TutorialFocusTarget TeachingTarget(string id)
    {
        Vector2[] path;
        if (id.StartsWith("basket")) {
            Texture2D texture = _art.Texture("basket");
            return TutorialFocusTarget.Sprite(this, texture, FitSprite(texture, BasketRect(int.Parse(id[6..]))), Source(texture));
        }
        else if (id == "pan") path = PanCorners;
        else if (id == "bowl") path = WuhanArtworkContours.MixingBowl.Select(p => WuhanWorkbenchLayout.Point(p.X, p.Y)).ToArray();
        else if (id == "raw") path = RawTraySilhouette.Select(p => WuhanWorkbenchLayout.Point(p.X, p.Y)).ToArray();
        else if (id.StartsWith("ingredient")) path = IngredientSilhouette(int.Parse(id[10..])).Select(p => WuhanWorkbenchLayout.Point(p.X, p.Y)).ToArray();
        else if (id == "trash") path = WuhanArtworkContours.Trash.Select(p => WuhanWorkbenchLayout.Point(p.X, p.Y)).ToArray();
        else path = EquipmentSilhouette(id).Select(p => WuhanWorkbenchLayout.Point(p.X, p.Y)).ToArray();
        if (id == "pan") return new(this, path);
        int radius = id is "bowl" or "raw" or "trash" ? 0
            : id.StartsWith("ingredient") ? int.Parse(id[10..]) switch { 1 or 3 => 0, 0 => 10, _ => 2 }
            : id == "filling" ? 10 : 2;
        return TutorialFocusTarget.Background(this, _art.WorkbenchBackground(_doupi is not null), path, radius: radius);
    }
    internal IEnumerable<TutorialFocusTarget> TeachingClearAreas()
    {
        foreach (var progress in _basketProgress.Append(_doupiProgress).OfType<EquipmentProgressView>())
            if (progress.IsVisibleInTree()) yield return TutorialFocusTarget.Area(progress, new Rect2(0, 28, progress.Size.X, 12), false);
        if (HasProductionGesture || IsKnifeHeld || _mixHeld)
        {
            Vector2 at = IsKnifeHeld && !HasProductionGesture ? _pointer : _gesturePoint;
            string sprite = IsKnifeHeld ? "cut_tool" : _gesture is "flip" or "filling" ? "flip_tool"
                : _gesture == "raw" ? "raw_noodles" : _gesture == "batter" ? "doupi_ladle" : "basket";
            if (_mixHeld) yield break;
            Texture2D texture = _art.Texture(sprite);
            Vector2 size = _gesture == "raw" ? BasketFoodRect(At(Vector2.Zero, BasketSize)).Size : new Vector2(100, 100);
            Rect2 bounds = _gesture == "basket" ? BasketRect(_gestureBasket) : At(at, size);
            if (_gesture is "flip" or "filling") bounds = At(at + new Vector2(30, -23), new Vector2(138, 91));
            foreach (var target in TutorialFocusTarget.Art(this, texture, FitSprite(texture, bounds), Source(texture), false)) yield return target;
            if (_gesture == "filling")
                yield return TutorialFocusTarget.Ellipse(this, new Rect2(at + new Vector2(-33, -17), new Vector2(54, 26))) with { Outline = false };
        }
    }
}
