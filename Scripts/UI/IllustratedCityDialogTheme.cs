using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>Shared illustrated prompts; Wuhan retains its approved green frame.</summary>
public static class IllustratedCityDialogTheme
{
    private const string ArtRoot = "res://resource/art/TianJin/DialogUI/";
    private static Color Ink(string cityId) => cityId == StableIds.Cities.Wuhan ? WuhanUi.Text : new("#542D16");
    private static Texture2D? _primary;
    private static Texture2D? _secondary;
    public static readonly Vector2 PanelSize = new(1200, 630);

    public static StyleBoxTexture PanelFrame(string cityId, float top = 0, float bottom = 0) => new()
    {
        Texture = GD.Load<Texture2D>(cityId == StableIds.Cities.Wuhan
            ? "res://resource/art/Wuhan/DialogUI/dialog-panel-v1.png" : ArtRoot + "dialog-panel-v1.png"),
        ContentMarginLeft = top > 0 ? 100 : 0, ContentMarginRight = top > 0 ? 100 : 0,
        ContentMarginTop = top, ContentMarginBottom = bottom,
    };

    public static Control BuildPause(PanelContainer panel, string cityId)
    {
        string[] captions = panel.Descendants<Label>().Select(label => label.Text).ToArray();
        Button[] buttons = panel.Descendants<Button>().ToArray();
        Node oldLayout = panel.GetChild(0);
        var content = new Control { Name = "IllustratedContents", MouseFilter = Control.MouseFilterEnum.Ignore };
        panel.AddChild(content);
        foreach (Button button in buttons) button.Reparent(content);
        Label[] labels = captions.Select(caption => new Label
        {
            Text = caption, HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center, MouseFilter = Control.MouseFilterEnum.Ignore,
        }).ToArray();
        foreach (Label label in labels) content.AddChild(label);
        // QueueFree alone leaves the old container's minimum size active until frame end.
        // Detach it before sizing the replacement, or wrapped text can keep the panel stretched.
        panel.RemoveChild(oldLayout);
        oldLayout.QueueFree();
        panel.AddThemeStyleboxOverride("panel", PanelFrame(cityId));
        panel.Position = new(360, 225); panel.Size = PanelSize;

        Label title = labels[0];
        SetBounds(title, new(245, 17, 700, 114));
        TextStyle(title, 60, cityId, true);
        if (labels.Length > 1)
        {
            SetBounds(labels[1], new(125, 220, 950, 110));
            TextStyle(labels[1], 34, cityId);
        }
        if (labels.Length > 2)
        {
            SetBounds(labels[2], new(145, 345, 910, 52));
            TextStyle(labels[2], 25, cityId);
        }
        Button primary = buttons.First(b => b.Text == "继续营业");
        Button secondary = buttons.First(b => b != primary);
        SetBounds(secondary, new(140, 444, 420, 108));
        SetBounds(primary, new(640, 444, 420, 108));
        StyleAction(secondary, false, cityId); StyleAction(primary, true, cityId);
        return title;
    }

    public static void BuildPauseWithTeaching(Panel panel, string cityId)
    {
        panel.AddThemeStyleboxOverride("panel", PanelFrame(cityId));
        SetBounds(panel, new(360, 225, 1200, 630));
        var title = panel.GetNode<Label>("Title");
        SetBounds(title, new(318, 17, 564, 114));
        title.VerticalAlignment = VerticalAlignment.Center;
        TextStyle(title, 60, cityId, true);
        FitHeading(title);
        var teaching = panel.GetChildren().OfType<Label>().First(label => label != title);
        var actions = new List<Button>();
        foreach (string name in new[] { "resume", "help", "exit" })
        {
            var button = panel.GetNode<Button>(name);
            StyleAction(button, name == "resume", cityId);
            actions.Add(button);
        }
        foreach (Label label in panel.GetChildren().OfType<Label>().Where(label => label != title))
        {
            SetBounds(label, new(600, 190, 490, 370));
            TextStyle(label, 30, cityId);
        }
        void LayoutActions()
        {
            for (int row = 0; row < actions.Count; row++)
                SetBounds(actions[row], new(teaching.Visible ? 100 : 395, 185 + 130 * row, 410, 104));
        }
        teaching.VisibilityChanged += LayoutActions;
        LayoutActions();
    }

    public static void ApplyConfirmation(AcceptDialog dialog, string cityId)
    {
        dialog.MinSize = new(1200, 630);
        dialog.Size = new(1200, 630);
        dialog.Theme.SetStylebox("panel", "AcceptDialog", PanelFrame(cityId, 192, 85));
        dialog.Theme.SetConstant("buttons_separation", "AcceptDialog", 68);
        dialog.Theme.SetConstant("buttons_min_height", "AcceptDialog", 104);
        dialog.Theme.SetConstant("buttons_min_width", "AcceptDialog", 410);
        var label = dialog.GetLabel();
        label.CustomMinimumSize = new(920, 180);
        label.AddThemeStyleboxOverride("normal", new StyleBoxEmpty());
        label.AddThemeConstantOverride("line_spacing", 14);
        TextStyle(label, 40, cityId);
        StyleAction(dialog.GetOkButton(), dialog is not ConfirmationDialog, cityId);
        if (dialog is ConfirmationDialog confirmation) StyleAction(confirmation.GetCancelButton(), true, cityId);
        if (dialog.Name == "NavigationError" && dialog.GetParent().GetNodeOrNull<CanvasLayer>("IllustratedDialogShade") is null)
        {
            var shade = new CanvasLayer { Name = "IllustratedDialogShade", Layer = 99, Visible = false };
            dialog.GetParent().AddChild(shade);
            var dim = new ColorRect { Color = new(.2f, .09f, .04f, .42f), MouseFilter = Control.MouseFilterEnum.Stop };
            shade.AddChild(dim); dim.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            dialog.VisibilityChanged += () =>
            {
                bool wuhan = dialog.GetMeta("dialog_city", "").AsString() == StableIds.Cities.Wuhan;
                dim.Color = wuhan ? new(.06f, .15f, .12f, .42f) : new(.2f, .09f, .04f, .42f);
                shade.Visible = dialog.Visible && dialog.GetMeta("illustrated_dialog", false).AsBool();
            };
        }
    }

    public static void LayoutHeader(Control artwork, AcceptDialog dialog, string cityId)
    {
        Vector2 size = dialog.Size;
        var title = artwork.GetNode<Label>("Title");
        title.Text = dialog.Title;
        SetBounds(title, new(size.X * .265f, size.Y * .027f, size.X * .47f, size.Y * .18f));
        TextStyle(title, 60, cityId, true);
        FitHeading(title);
        // Keep the translated message intact; a Chinese comma is its natural line break.
        string message = System.Text.RegularExpressions.Regex.Replace(dialog.Tr(dialog.DialogText).ToString(), "，\\n*", "，\n");
        if (dialog.GetLabel().Text != message) dialog.GetLabel().Text = message;
        artwork.GetNode<Button>("Close").Hide();
    }

    public static void StyleAction(Button button, bool primary, string cityId)
    {
        ButtonHoverFeedback.Attach(button);
        // Match Wuhan's existing journey buttons, including reused navigation dialogs.
        button.Material = CityPageArtSkin.UsesWuhanPalette(cityId)
            ? CityPageArtSkin.MaterialFor(cityId) : null;
        button.GetNodeOrNull<Control>("CityButtonArt")?.Hide();
        Texture2D texture = primary ? _primary ??= PrimaryTexture() : _secondary ??= GD.Load<Texture2D>(ArtRoot + "button-secondary-v1.png");
        button.CustomMinimumSize = new(410, 104);
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            button.AddThemeStyleboxOverride(state, new StyleBoxTexture
            {
                Texture = texture,
                ModulateColor = state switch { "hover" => new Color(1.06f, 1.04f, 1), "pressed" => new Color(.92f, .88f, .80f),
                    "disabled" => new Color(1, 1, 1, .45f), _ => Colors.White },
                ContentMarginLeft = 30, ContentMarginRight = 30, ContentMarginTop = 16, ContentMarginBottom = 20,
            });
        button.AddThemeStyleboxOverride("focus", new StyleBoxFlat
        {
            BgColor = Colors.Transparent, BorderColor = Ink(cityId), BorderWidthLeft = 3, BorderWidthRight = 3,
            BorderWidthTop = 3, BorderWidthBottom = 3, CornerRadiusTopLeft = 55, CornerRadiusTopRight = 55,
            CornerRadiusBottomLeft = 55, CornerRadiusBottomRight = 55,
            ExpandMarginLeft = 6, ExpandMarginRight = 6, ExpandMarginTop = 6, ExpandMarginBottom = 6,
        });
        button.AddThemeFontSizeOverride("font_size", 40);
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color" })
            button.AddThemeColorOverride(state, Ink(cityId));
    }

    private static Texture2D PrimaryTexture()
    {
        // Use the requested source unchanged, excluding its nearly transparent export padding.
        var source = GD.Load<Texture2D>("res://resource/art/Global/StartPage/首页地图按钮底板.png");
        using var image = source.GetImage(); image.Convert(Image.Format.Rgba8);
        byte[] data = image.GetData(); int width = image.GetWidth(), height = image.GetHeight();
        int left = width, top = height, right = 0, bottom = 0;
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
            if (data[(y * width + x) * 4 + 3] >= 128)
            { left = Math.Min(left, x); right = Math.Max(right, x); top = Math.Min(top, y); bottom = Math.Max(bottom, y); }
        return new AtlasTexture { Atlas = source, Region = new(left, top, right - left + 1, bottom - top + 1) };
    }

    private static void SetBounds(Control control, Rect2 bounds)
    { control.Position = bounds.Position; control.Size = bounds.Size; }

    private static void TextStyle(Label label, int size, string cityId, bool heading = false)
    {
        label.AddThemeFontSizeOverride("font_size", size);
        label.AddThemeColorOverride("font_color", Ink(cityId));
        label.AddThemeColorOverride("font_shadow_color", Colors.Transparent);
        label.AddThemeColorOverride("font_outline_color", new Color("#FFF8E8"));
        label.AddThemeConstantOverride("outline_size", heading ? 8 : 0);
    }

    public static void FitHeading(Label title)
    {
        title.AutowrapMode = TextServer.AutowrapMode.Off;
        var font = title.GetThemeFont("font");
        string text = title.Tr(title.Text).ToString();
        int size = 60;
        while (size > 28 && font.GetStringSize(text, HorizontalAlignment.Left, -1, size).X > title.Size.X - 24) size--;
        title.AddThemeFontSizeOverride("font_size", size);
    }
}
