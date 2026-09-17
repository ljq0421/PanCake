using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>
/// The short, blocking prompts used while a city is open.  The illustrated paper
/// frame stays common to the journey, while the ink, title strip and actions take
/// their colours from the city the player is visiting.
/// </summary>
public static class CityDialogChrome
{
    private const string MainFramePath = "res://resource/art/Global/PanelUI/panel-main-v1.tres";
    private const string GroupFramePath = "res://resource/art/Global/PanelUI/panel-group-v1.tres";
    private static Texture2D? _buttonTexture;

    private readonly record struct Palette(Color Paper, Color Ink, Color Accent, Color SoftAccent, Color Warning);

    private static Palette For(string cityId) => cityId switch
    {
        StableIds.Cities.Tianjin => new(TianjinUi.Paper, TianjinUi.BrownText, TianjinUi.Yellow, TianjinUi.Cream, TianjinUi.Red),
        StableIds.Cities.Wuhan => new(WuhanUi.Paper, WuhanUi.Text, WuhanUi.Accent, WuhanUi.Surface, new Color("#A85B43")),
        StableIds.Cities.Xian => new(new Color("#FFF4DC"), new Color("#49362E"), new Color("#C77A36"), new Color("#E8CDA4"), new Color("#9D5940")),
        _ => new(StartScreenTheme.Cream, StartScreenTheme.Ink, StartScreenTheme.Apricot, StartScreenTheme.Cream, StartScreenTheme.Brick),
    };

    /// <summary>Applies the shared illustrated frame and city-coloured action hierarchy to a pause panel.</summary>
    public static void ApplyPausePanel(Control panel, string cityId)
    {
        Palette palette = For(cityId);
        panel.AddThemeStyleboxOverride("panel", Frame(MainFramePath));
        foreach (Label label in panel.Descendants<Label>())
        {
            label.AddThemeColorOverride("font_color", palette.Ink);
            label.AddThemeColorOverride("font_shadow_color", Colors.Transparent);
        }
        foreach (Button button in panel.Descendants<Button>())
            StyleButton(button, palette, IsDestructive(button.Text), button.Text.Contains("继续", StringComparison.Ordinal));
    }

    /// <summary>Sets the dialog body, title bar and controls without changing dialog behaviour or copy.</summary>
    public static void ApplyConfirmation(AcceptDialog dialog, string cityId)
    {
        bool illustrated = cityId is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan;
        dialog.SetMeta("illustrated_dialog", illustrated);
        dialog.SetMeta("dialog_city", cityId);
        Palette palette = For(cityId);
        var theme = new Theme();
        var frame = Frame(MainFramePath);
        frame.ContentMarginTop = 116;
        frame.ContentMarginBottom = 32;
        theme.SetStylebox("panel", "AcceptDialog", frame);
        dialog.Borderless = true;
        dialog.Transparent = true;
        dialog.TransparentBg = true;
        dialog.MinSize = new Vector2I(720, 360);
        theme.SetConstant("buttons_separation", "AcceptDialog", 20);
        theme.SetConstant("buttons_min_height", "AcceptDialog", 68);
        theme.SetConstant("buttons_min_width", "AcceptDialog", 240);
        theme.SetFontSize("font_size", "Label", 22);
        theme.SetColor("font_color", "Label", palette.Ink);
        dialog.Theme = theme;

        Label message = dialog.GetLabel();
        message.HorizontalAlignment = HorizontalAlignment.Center;
        message.VerticalAlignment = VerticalAlignment.Center;
        message.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        message.CustomMinimumSize = new Vector2(560, 92);
        message.AddThemeStyleboxOverride("normal", Frame(GroupFramePath));
        message.AddThemeColorOverride("font_color", palette.Ink);
        message.AddThemeColorOverride("font_shadow_color", Colors.Transparent);
        message.AddThemeFontSizeOverride("font_size", 22);

        StyleButton(dialog.GetOkButton(), palette, dialog is ConfirmationDialog, dialog is not ConfirmationDialog);
        if (dialog is ConfirmationDialog confirmation)
            StyleButton(confirmation.GetCancelButton(), palette, false, true);

        var header = dialog.GetNodeOrNull<CanvasLayer>("CityDialogHeader");
        if (header is null)
        {
            header = new CanvasLayer { Name = "CityDialogHeader" };
            dialog.AddChild(header);
            var root = new Control { Name = "Artwork", MouseFilter = Control.MouseFilterEnum.Ignore };
            header.AddChild(root);
            AddTitleTape(root, "TitleTape", new(80, 28, 560, 64), cityId);
            var title = new Label { Name = "Title", HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center, MouseFilter = Control.MouseFilterEnum.Ignore, ZIndex = 2 };
            title.AddThemeFontSizeOverride("font_size", 30);
            root.AddChild(title);
            var close = new Button { Name = "Close", Text = "×", TooltipText = "关闭", FocusMode = Control.FocusModeEnum.None };
            foreach (string state in new[] { "normal", "hover", "pressed", "focus" })
                close.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
            close.AddThemeFontSizeOverride("font_size", 30);
            root.AddChild(close);
            close.Pressed += () => { dialog.Hide(); dialog.EmitSignal(AcceptDialog.SignalName.Canceled); };
            void Layout()
            {
                float width = dialog.Size.X;
                root.Size = dialog.Size;
                bool usesIllustration = dialog.GetMeta("illustrated_dialog", false).AsBool();
                root.GetNode<NinePatchRect>("TitleTape").Visible = !usesIllustration;
                if (usesIllustration)
                {
                    IllustratedCityDialogTheme.LayoutHeader(root, dialog, dialog.GetMeta("dialog_city").AsString());
                    return;
                }
                title.AddThemeFontSizeOverride("font_size", 30);
                title.AddThemeConstantOverride("outline_size", 0);
                close.Show();
                close.Text = "×";
                title.Text = dialog.Title;
                title.Position = new(80, 28); title.Size = new(width - 160, 64);
                var tape = root.GetNode<NinePatchRect>("TitleTape");
                tape.Size = new Vector2(width - 160, 64) / tape.Scale;
                close.Position = new(width - 58, 20); close.Size = new(38, 38);
            }
            dialog.SizeChanged += Layout;
            dialog.AboutToPopup += Layout;
            Layout();
        }
        var artwork = header.GetNode<Control>("Artwork");
        artwork.GetNode<Label>("Title").AddThemeColorOverride("font_color", palette.Ink);
        var closeButton = artwork.GetNode<Button>("Close");
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color" })
            closeButton.AddThemeColorOverride(state, palette.Ink);
        var material = (ShaderMaterial)artwork.GetNode<NinePatchRect>("TitleTape").Material;
        material.SetShaderParameter("paper_color", palette.SoftAccent);
        if (illustrated) IllustratedCityDialogTheme.ApplyConfirmation(dialog, cityId);
        else message.AddThemeConstantOverride("line_spacing", 0);
    }

    public static NinePatchRect AddTitleTape(Control parent, string name, Rect2 bounds, string cityId, int zIndex = 1)
    {
        Palette palette = For(cityId);
        NinePatchRect tape = IllustratedPanelChrome.AddTitleTape(parent, name, bounds, zIndex);
        if (tape.Material is ShaderMaterial material)
        {
            material.SetShaderParameter("paper_color", palette.SoftAccent);
            material.SetShaderParameter("lighten_amount", .68f);
        }
        return tape;
    }

    /// <summary>Use when a pause action is created after its containing panel.</summary>
    public static void ApplyPauseAction(Button button, string cityId, bool destructive = false, bool primary = false)
        => StyleButton(button, For(cityId), destructive, primary);

    private static StyleBoxTexture Frame(string path) => (StyleBoxTexture)GD.Load<StyleBoxTexture>(path).Duplicate();

    private static Texture2D ButtonTexture()
    {
        if (_buttonTexture is not null) return _buttonTexture;
        var texture = GD.Load<Texture2D>("res://resource/art/Global/StartPage/通用次级按钮底板.png");
        using var image = texture.GetImage();
        _buttonTexture = new AtlasTexture { Atlas = texture, Region = image.GetUsedRect() };
        return _buttonTexture;
    }

    private static void StyleButton(Button button, Palette palette, bool destructive, bool primary)
    {
        // Pale city pigments keep the illustrated ink and every action caption legible.
        Color fill = destructive ? palette.Warning.Lightened(.72f) : primary ? palette.Accent.Lightened(.55f) : palette.Paper;
        Color text = palette.Ink;
        button.CustomMinimumSize = new Vector2(Math.Max(button.CustomMinimumSize.X, 220), Math.Max(button.CustomMinimumSize.Y, 60));
        button.AddThemeFontSizeOverride("font_size", 22);
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            button.AddThemeStyleboxOverride(state, new StyleBoxEmpty { ContentMarginLeft = 24, ContentMarginRight = 24,
                ContentMarginTop = 12, ContentMarginBottom = 12 });
        var art = button.GetNodeOrNull<NinePatchRect>("CityButtonArt");
        if (art is null)
        {
            var texture = ButtonTexture();
            art = new NinePatchRect { Name = "CityButtonArt", Texture = texture, ShowBehindParent = true,
                MouseFilter = Control.MouseFilterEnum.Ignore, PatchMarginLeft = (int)(texture.GetWidth() * .18f),
                PatchMarginRight = (int)(texture.GetWidth() * .18f),
                Material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/panel_tape_lighten.gdshader") } };
            button.AddChild(art);
            void Refresh()
            {
                float scale = Math.Max(1, button.Size.Y) / texture.GetHeight();
                art.Scale = Vector2.One * scale; art.Size = button.Size / scale;
                art.Modulate = button.Disabled ? new Color(.85f, .85f, .85f) : button.IsPressed()
                    ? new Color(.92f, .92f, .92f) : Colors.White;
            }
            button.Resized += Refresh; button.Draw += Refresh;
            Refresh();
        }
        button.AddThemeStyleboxOverride("focus", new StyleBoxFlat { BgColor = Colors.Transparent,
            BorderColor = palette.Ink, BorderWidthBottom = 3, ExpandMarginBottom = 3,
            ContentMarginLeft = 24, ContentMarginRight = 24, ContentMarginTop = 12, ContentMarginBottom = 12 });
        var shader = (ShaderMaterial)art.Material;
        art.Show();
        shader.SetShaderParameter("paper_color", fill);
        shader.SetShaderParameter("lighten_amount", .88f);
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color" })
            button.AddThemeColorOverride(state, text);
        button.AddThemeColorOverride("font_disabled_color", palette.Ink.Darkened(.25f));
    }

    private static bool IsDestructive(string text) => text.Contains("放弃", StringComparison.Ordinal)
        || text.Contains("离开", StringComparison.Ordinal) || text.Contains("返回首页", StringComparison.Ordinal);

}
