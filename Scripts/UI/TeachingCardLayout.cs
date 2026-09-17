using Godot;

namespace ProjectCake.UI;

/// <summary>Measure translated text with Godot's shaper before placing teaching controls.</summary>
internal static class TeachingCardLayout
{
    internal static float NaturalWidth(Label label) => label.Tr(label.Text).ToString().Split('\n')
        .Max(line => label.GetThemeFont("font").GetStringSize(line, fontSize: label.GetThemeFontSize("font_size")).X);

    internal static float Height(Label label, float width)
    {
        using var paragraph = new TextParagraph
        {
            Width = width,
            BreakFlags = TextServer.LineBreakFlag.Mandatory | TextServer.LineBreakFlag.WordBound | TextServer.LineBreakFlag.Adaptive,
        };
        paragraph.AddString(label.Tr(label.Text), label.GetThemeFont("font"), label.GetThemeFontSize("font_size"), label.GetLanguage());
        return Mathf.Ceil(paragraph.GetSize().Y + Math.Max(0, paragraph.GetLineCount() - 1) * label.GetThemeConstant("line_spacing"));
    }

    internal static float Place(Label label, float x, float y, float width)
    {
        label.Position = new(x, y);
        var size = new Vector2(width, Height(label, width));
        label.Size = size;
        // Label invalidates its wrapped minimum asynchronously after a width/text change.
        // Apply again after that update so an earlier narrow line does not retain a tall rect.
        label.SetDeferred(Control.PropertyName.Size, size);
        return size.Y;
    }

    internal static float ButtonWidth(Button button, float minimum) => Mathf.Max(minimum,
        button.GetThemeFont("font").GetStringSize(button.Tr(button.Text), fontSize: button.GetThemeFontSize("font_size")).X + 28);

    internal static void PlaceButton(Button button, Vector2 position, Vector2 size)
    {
        var frame = button.GetParent<Panel>();
        frame.Position = position; frame.Size = size; button.Size = size;
    }

    internal static void Lesson(Panel card, Label title, Label? body, Button action, float maxWidth)
    {
        const float left = 60, right = 36, top = 38, bottom = 22, gap = 16;
        bool summary = body?.Visible == true;
        float actionWidth = ButtonWidth(action, 160);
        float desired = summary ? Mathf.Max(NaturalWidth(title), NaturalWidth(body!))
            : NaturalWidth(title) + gap + actionWidth;
        float width = Mathf.Clamp(desired + left + right, 360, maxWidth);
        float inner = width - left - right;
        float titleHeight = Place(title, left, top, summary ? inner : inner - gap - actionWidth);
        float actionY, height;
        if (summary)
        {
            float bodyY = top + titleHeight + 12;
            float bodyHeight = Place(body!, left, bodyY, inner);
            actionY = bodyY + bodyHeight + 18;
            height = actionY + 58 + bottom;
        }
        else
        {
            float rowHeight = Mathf.Max(titleHeight, 58);
            title.Position += new Vector2(0, (rowHeight - titleHeight) / 2);
            actionY = top + (rowHeight - 58) / 2;
            height = top + rowHeight + bottom;
        }
        PlaceButton(action, new(width - right - actionWidth, actionY), new(actionWidth, 58));
        card.Size = new(width, height);
    }
}
