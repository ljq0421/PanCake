using Godot;

namespace ProjectCake.UI;

/// <summary>One short emphasis per teaching instruction. Source text remains a translation key.</summary>
internal partial class TeachingEmphasis : RichTextLabel
{
    private Label _source = null!;
    private string _signature = "";
    private Font? _baseFont;
    private FontVariation _bold = null!;
    internal const string Ink = "#A83228";

    internal static void Attach(Label label)
    {
        if (label.GetNodeOrNull<TeachingEmphasis>("TeachingEmphasis") is not null) return;
        label.AddChild(new TeachingEmphasis { Name = "TeachingEmphasis", _source = label,
            MouseFilter = MouseFilterEnum.Ignore, ScrollActive = false, BbcodeEnabled = true,
            AutoTranslateMode = AutoTranslateModeEnum.Disabled });
    }

    // Ordered deliberately: specific gestures precede generic clicks/drags.
    private static readonly (string Chinese, string English)[] Phrases =
    {
        ("无需再次搅拌", "No more stirring"), ("再加牛肉", "then add beef"),
        ("左键点击煎饼外收刷", "Left-click outside the pancake"),
        ("长按右键 0.45 秒", "Hold right mouse"), ("右键长按 0.45 秒", "Hold right-click for 0.45 s"),
        ("左键长按", "Hold left mouse"), ("横划一次、竖划一次", "once across and once down"),
        ("点击右下方小刀", "Click the knife at bottom right"),
        ("点击炸锅锅体", "Click the fryer body"), ("点击蛋液容器", "Click the egg container"),
        ("点击酱碗", "Click the sauce bowl"), ("点击翻面", "Click Flip"),
        ("点击折叠", "Click Fold"), ("点击装袋", "Click Bag"), ("点击下锅", "Click Lower"),
        ("点击日期", "Select a date"), ("点击收银挂件", "Click the cash pendant"),
        ("点击挂件", "click charm"), ("点击可升级贴片", "click the upgrade sticker"),
        ("按 Esc", "Esc"), ("向上提篮", "drag it upward"), ("向上提起", "drag the basket upward"),
        ("向上划动", "swipe upward"), ("按住左键", "Hold left mouse"),
        ("拖进空漏勺", "into an empty basket"), ("拖到空碗", "to an empty bowl"),
        ("拖入空锅", "into the empty pan"), ("拖入锅内", "into the pan"),
        ("松手丢弃", "release"), ("松手交给", "Release"),
        ("拖入垃圾桶", "Drag to the bin"),
        ("长按右键", "Hold right mouse"), ("长按炸锅", "Hold on fryer"), ("长按补货", "Hold to restock"),
        ("拖给", "Drag"), ("拖到", "Drag"), ("拖入", "Drag"), ("点击", "Click"),
    };

    internal static (int Start, int Length) Find(string source, string translated)
    {
        // Waiting, summaries, errors and rule explanations retain their ordinary appearance.
        if (source.StartsWith("等", StringComparison.Ordinal) || source.Contains("补货中")
            || source.Contains("请重试") || source.Contains("重新制作") || source.StartsWith("接下来"))
            return (-1, 0);
        foreach (var phrase in Phrases)
        {
            if (!source.Contains(phrase.Chinese, StringComparison.Ordinal)) continue;
            string needle = translated == source ? phrase.Chinese : phrase.English;
            if (translated == source && needle == "松手交给") needle = "松手";
            int start = translated.IndexOf(needle, StringComparison.OrdinalIgnoreCase);
            return start < 0 ? (-1, 0) : (start, needle.Length);
        }
        return (-1, 0);
    }

    internal static string Markup(string source, string translated)
    {
        static string Escape(string value) => value.Replace("[", "[lb]", StringComparison.Ordinal);
        var (start, length) = Find(source, translated);
        return start < 0 ? Escape(translated) : Escape(translated[..start])
            + $"[b][color={Ink}]" + Escape(translated.Substring(start, length)) + "[/color][/b]" + Escape(translated[(start + length)..]);
    }

    internal static void Shape(TextParagraph paragraph, Label label, string text)
    {
        Font normal = label.GetThemeFont("font");
        int size = label.GetThemeFontSize("font_size");
        var (start, length) = label.GetNodeOrNull<TeachingEmphasis>("TeachingEmphasis") is not null
            ? Find(label.Text, text) : (-1, 0);
        if (start < 0) { paragraph.AddString(text, normal, size, label.GetLanguage()); return; }
        using var bold = new FontVariation { BaseFont = normal, VariationEmbolden = .65f };
        paragraph.AddString(text[..start], normal, size, label.GetLanguage());
        paragraph.AddString(text.Substring(start, length), bold, size, label.GetLanguage());
        paragraph.AddString(text[(start + length)..], normal, size, label.GetLanguage());
    }

    public override void _Process(double delta) => Refresh();

    internal float MeasureHeight(float width)
    {
        Refresh();
        Size = new(width, Size.Y);
        float height = GetContentHeight();
        _signature = ""; // Layout will now place the source at this measured size.
        return height;
    }

    internal void Refresh()
    {
        string translated = _source.Tr(_source.Text);
        Font font = _source.GetThemeFont("font");
        int size = _source.GetThemeFontSize("font_size");
        Color color = _source.GetThemeColor("font_color");
        string signature = $"{translated}|{size}|{color}|{_source.Size}|{_source.HorizontalAlignment}|{_source.VerticalAlignment}";
        if (_signature == signature && font == _baseFont) return;
        _signature = signature;
        if (font != _baseFont)
        {
            _baseFont = font;
            _bold = new FontVariation { BaseFont = font, VariationEmbolden = .65f };
            AddThemeFontOverride("normal_font", font); AddThemeFontOverride("bold_font", _bold);
        }
        AddThemeFontSizeOverride("normal_font_size", size); AddThemeFontSizeOverride("bold_font_size", size);
        AddThemeColorOverride("default_color", color);
        AddThemeConstantOverride("line_separation", _source.GetThemeConstant("line_spacing"));
        AutowrapMode = _source.AutowrapMode; HorizontalAlignment = _source.HorizontalAlignment;
        Text = Markup(_source.Text, translated);
        Size = _source.Size;
        float y = _source.VerticalAlignment == VerticalAlignment.Center ? Math.Max(0, (_source.Size.Y - GetContentHeight()) / 2)
            : _source.VerticalAlignment == VerticalAlignment.Bottom ? Math.Max(0, _source.Size.Y - GetContentHeight()) : 0;
        Position = new(0, y); Size = new(_source.Size.X, Math.Max(0, _source.Size.Y - y));
        // Preserve the Label API, translation and accessibility text; only replace its ink.
        _source.SelfModulate = new Color(1, 1, 1, 0);
    }
}
