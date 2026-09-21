using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private void DrawContinuePostcard(JourneyCity city)
    {
        var card = new Control { Name = "ContinuePostcard", Position = new(311, 319), Size = new(600, 365),
            PivotOffset = new(300, 182), RotationDegrees = -3, MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(card);
        var art = HomeArt(card, city.Art is null ? "继续旅程明信片底板" : city.Art[JourneyModel.ArtRoot.Length..^4], new(0, 0, 600, 365));
        art.Name = "PostcardArt";
        if (city.Art is null) HomeArt(card, "世界地图小早餐铺标记", new(65, 57, 245, 235));
        bool tianjin = city.Id == StableIds.Cities.Tianjin;
        var tag = new Control { Name = "PostcardLocation", Position = tianjin ? new(411, 279) : city.Art is null ? new(399, 268) : new(399, 286),
            Size = new(148, 44), MouseFilter = MouseFilterEnum.Ignore };
        card.AddChild(tag);
        // Tianjin and the generic card have a printed frame; Wuhan/Xian need a paper label.
        if (city.Art is not null && !tianjin)
            HomeArt(tag, "存档信息小纸签", new(-10, -5, 164, 56), stretch: true);
        HomeArt(tag, "定位符", new(5, 7, 25, 31)).Name = "LocationIcon";
        var name = Text(tag, "PostcardCity", city.Name, new(35, 0, 106, 44), 28, true);
        FitTextWidth(name, 28, 20);
    }

    private Control ContinueSummaryRow(Control parent, string name, string caption, string value, float y, bool wrap = false, string? icon = null)
    {
        var row = new Control { Name = name + "Row", Position = new(0, y), Size = new(460, 70), MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(row);
        var artwork = HomeArt(row, icon ?? caption, new(0, 17, 34, 36));
        artwork.Name = name + "Icon";
        CityPageArtSkin.Apply(artwork, BookPaletteCity);
        var label = Text(row, name + "Label", caption, new(44, 8, 99, 54), 23);
        if (CityPageArtSkin.UsesWuhanPalette(BookPaletteCity))
            label.AddThemeColorOverride("font_color", CitySettlementTheme.For("wuhan").Primary.Darkened(.42f));
        FitTextWidth(label, 23, 17);
        if (name == "LatestUnlock") return row;
        // Keep the first value clear of the luggage tag painted into the note's upper right.
        var field = Text(row, name, value, new(154, 3, name == "Coins" ? 190 : 300, 64), wrap ? 22 : 25);
        field.HorizontalAlignment = HorizontalAlignment.Right;
        if (wrap) FitContinueLines(field, 22, 17, 2);
        else { FitTextWidth(field, 25, 17); field.AutowrapMode = TextServer.AutowrapMode.Off; }
        return row;
    }

    private static void FitContinueLines(Label label, int size, int minimum, int lines)
    {
        Vector2 bounds = label.Size;
        for (; size >= minimum; size--)
        {
            label.AddThemeFontSizeOverride("font_size", size);
            label.Size = bounds;
            if (label.GetLineCount() <= lines) break;
        }
    }

    private void DrawLatestUnlocks(Control row, IReadOnlyList<CityUnlockView> unlocks)
    {
        if (unlocks.Count == 0)
        {
            Text(row, "LatestUnlock", "暂无解锁", new(154, 3, 300, 64), 24).HorizontalAlignment = HorizontalAlignment.Right;
            return;
        }
        var font = row.GetThemeFont("font");
        int size = 23;
        float[] widths;
        int lines;
        do
        {
            widths = unlocks.Select(u => 30 + font.GetStringSize(Tr(u.Name), HorizontalAlignment.Left, -1, size).X + 8).ToArray();
            float used = 0; lines = 1;
            foreach (float width in widths) { if (used > 0 && used + width > 300) { lines++; used = 0; } used += width; }
            if (lines <= 2 && widths.All(w => w <= 300) || size <= 16) break;
            size--;
        } while (true);
        float LineStart(int first)
        {
            float width = widths[first];
            for (int next = first + 1; next < widths.Length && width + widths[next] <= 300; next++)
                width += widths[next];
            return 454 - (width - 8);
        }
        float x = LineStart(0), y = lines == 1 ? 19 : 3;
        float lineWidth = 0;
        for (int i = 0; i < unlocks.Count; i++)
        {
            var item = unlocks[i];
            if (lineWidth > 0 && lineWidth + widths[i] > 300) { x = LineStart(i); y += 32; lineWidth = 0; }
            if (!string.IsNullOrEmpty(item.Art))
            {
                if (item.Art.StartsWith("res://resource/art/"))
                    HomeArt(row, "../../" + item.Art["res://resource/art/".Length..^4], new(x, y, 28, 30)).Name = "UnlockFood" + i;
                else Art(row, item.Art, new(x, y, 28, 30)).Name = "UnlockFood" + i;
            }
            else row.AddChild(new BookFoodIcon { Name = "UnlockFood" + i, Position = new(x, y), Size = new(28, 30), Product = new(item.Id, item.Name, 1, item.Visual) });
            var text = Text(row, "UnlockName" + i, item.Name, new(x + 30, y, widths[i] - 38, 30), size);
            text.AutowrapMode = TextServer.AutowrapMode.Off;
            x += widths[i];
            lineWidth += widths[i];
        }
    }
}
