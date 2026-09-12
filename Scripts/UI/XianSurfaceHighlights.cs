using Godot;

namespace ProjectCake.UI;

public partial class XianSurface
{
    public InteractionHighlightState HighlightState
    {
        get
        {
            if (!IsVisibleInTree() || CanInteract?.Invoke() != true || Unavailable || Kind == "customer" && Amount == 0)
                return InteractionHighlightState.None;
            bool hovered = new Rect2(Vector2.Zero, Size).HasPoint(GetLocalMousePosition());
            Viewport viewport = GetViewport();
            if (viewport.GuiIsDragging())
            {
                Variant data = viewport.GuiGetDragData();
                bool accepts = data.VariantType == Variant.Type.String && AcceptToken?.Invoke(data.AsString()) == true;
                return hovered ? accepts ? InteractionHighlightState.Valid : InteractionHighlightState.Invalid
                    : accepts ? InteractionHighlightState.Eligible : InteractionHighlightState.None;
            }
            if (Selected || _held || HasFocus()) return InteractionHighlightState.Selected;
            return hovered ? InteractionHighlightState.Hover : InteractionHighlightState.None;
        }
    }

    private void DrawEquipmentHighlight()
    {
        InteractionHighlightState state = HighlightState;
        if (state == InteractionHighlightState.None) return;
        // These contours are measured on the 1672 x 941 shop artwork. Convert through
        // the common workbench coordinates so its responsive scale applies only once.
        void Background(Vector2[] points) => InteractionHighlightPresentation.DrawPath(this,
            points.Select(p => p * new Vector2(1920f / 1672f, 1080f / 941f) - Position).ToArray(), state);
        void Sprite(string id, Rect2 box)
        {
            Texture2D texture = _art.Texture(id);
            Vector2 size = texture.GetSize();
            float scale = Math.Min(box.Size.X / size.X, box.Size.Y / size.Y);
            Vector2 fitted = size * scale;
            DrawnArtContour.Draw(this, texture, new Rect2(box.Position + (box.Size - fitted) / 2, fitted), state);
        }
        switch (Kind)
        {
            case "oven":
                Background(new Vector2[] { new(36, 602), new(34, 583), new(58, 530), new(70, 515), new(98, 514),
                    new(119, 480), new(137, 469), new(542, 466), new(565, 474), new(577, 490), new(576, 513),
                    new(589, 515), new(597, 530), new(591, 588), new(581, 606), new(566, 610), new(558, 679),
                    new(546, 692), new(523, 693), new(519, 705), new(500, 705), new(492, 693), new(99, 693),
                    new(93, 705), new(68, 705), new(59, 692), new(43, 687), new(36, 674) });
                break;
            case "board":
                Background(new Vector2[] { new(590, 666), new(625, 522), new(634, 506), new(652, 498),
                    new(1048, 498), new(1067, 505), new(1077, 526), new(1114, 665), new(1115, 686),
                    new(1107, 700), new(1090, 706), new(611, 706), new(596, 698), new(590, 686) });
                break;
            case "juice":
                Background(new Vector2[] { new(674, 781), new(680, 760), new(697, 742), new(720, 731),
                    new(752, 725), new(783, 730), new(809, 705), new(821, 708), new(834, 720), new(831, 730),
                    new(815, 750), new(829, 768), new(834, 789), new(828, 817), new(816, 839), new(795, 856),
                    new(767, 865), new(736, 866), new(709, 858), new(689, 840), new(679, 815) });
                break;
            case "soup":
                Background(new Vector2[] { new(1226, 554), new(1230, 526), new(1241, 513), new(1270, 508),
                    new(1293, 484), new(1328, 466), new(1372, 454), new(1425, 451), new(1480, 456),
                    new(1527, 472), new(1564, 493), new(1583, 513), new(1610, 517), new(1622, 534),
                    new(1628, 562), new(1621, 581), new(1606, 589), new(1591, 592), new(1579, 632),
                    new(1555, 660), new(1517, 682), new(1474, 695), new(1428, 698), new(1380, 693),
                    new(1337, 680), new(1303, 657), new(1278, 629), new(1267, 590), new(1240, 582), new(1228, 572) });
                break;
            case "bun":
                if (Stage > 0) Sprite(Stage == 1 ? "完整熟白吉馍" : "切开白吉馍状态层", new Rect2(38, 0, 240, 140));
                else Background(new Vector2[] { new(864, 794), new(871, 765), new(891, 743), new(922, 725),
                    new(960, 715), new(1001, 712), new(1047, 717), new(1084, 730), new(1112, 752),
                    new(1130, 777), new(1136, 800), new(1129, 826), new(1108, 847), new(1076, 863),
                    new(1035, 872), new(990, 876), new(950, 870), new(913, 856), new(886, 837), new(870, 816) });
                break;
            case "meat":
                Sprite("预剁肉备货盘", new Rect2(5, 0, 118, 65));
                break;
            case "soup_bowl":
                Sprite(Amount > 0 ? "成品肉丸胡辣汤" : "胡辣汤空碗", new Rect2(66, 15, 190, 145));
                break;
        }
    }
}
