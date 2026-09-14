using Godot;
namespace ProjectCake.UI;

public partial class StartScreen
{
    private Texture2D Texture(string path)
    {
        if (!path.StartsWith("res://")) path = JourneyModel.ArtRoot + path + ".png";
        if (!_textures.TryGetValue(path, out var texture))
        {
            texture = GD.Load<Texture2D>(path);
            // Routes contain large transparent margins; use an atlas region without editing source art.
            if (path.Contains("手绘旅行虚线路径", StringComparison.Ordinal) || path.Contains("按钮底板", StringComparison.Ordinal))
            {
                using var image = texture.GetImage();
                image.Convert(Image.Format.Rgba8);
                byte[] pixels = image.GetData(); int width = image.GetWidth(), height = image.GetHeight();
                int left = width, right = 0, top = height, bottom = 0;
                // Ignore almost-transparent export noise surrounding the painted dashes.
                for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
                    if (pixels[(y * width + x) * 4 + 3] >= 128)
                    { left = Math.Min(left, x); right = Math.Max(right, x); top = Math.Min(top, y); bottom = Math.Max(bottom, y); }
                if (left <= right && top <= bottom)
                    texture = new AtlasTexture { Atlas = texture, Region = new Rect2(left, top, right - left + 1, bottom - top + 1) };
            }
            _textures[path] = texture;
        }
        return texture;
    }
    private TextureRect Art(Control parent, string path, Rect2 rect)
    {
        var node = new TextureRect { Position = rect.Position, Size = rect.Size, Texture = Texture(path),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(node); return node;
    }
    private Label Text(Control parent, string name, string text, Rect2 rect, int fontSize = 30, bool centered = false)
    {
        var label = new Label { Name = name, Text = text, Position = rect.Position, Size = rect.Size,
            VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = centered ? HorizontalAlignment.Center : HorizontalAlignment.Left,
            AutowrapMode = TextServer.AutowrapMode.WordSmart, MouseFilter = MouseFilterEnum.Ignore };
        label.AddThemeFontSizeOverride("font_size", fontSize); parent.AddChild(label); return label;
    }
    private Button Button(Control parent, string name, string caption, Rect2 rect, Action action, bool primary = false, bool bare = false)
    {
        var button = new Button { Name = name, Text = caption, Position = rect.Position, Size = rect.Size, MouseDefaultCursorShape = CursorShape.PointingHand };
        parent.AddChild(button); StartScreenTheme.Apply(button, primary);
        if (bare)
        {
            foreach (string state in new[] { "normal", "hover", "pressed", "disabled" }) button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
            foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color" }) button.AddThemeColorOverride(state, StartScreenTheme.Ink);
        }
        else
        {
            // The image keeps its native aspect; native Button still owns text, focus and input.
            foreach (string state in new[] { "normal", "hover", "pressed", "disabled" }) button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
            foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color" }) button.AddThemeColorOverride(state, StartScreenTheme.Ink);
            var texture = Texture(primary ? "通用主操作按钮底板" : "通用次级按钮底板");
            float scale = rect.Size.Y / texture.GetHeight();
            // Nine-patch stretches only the blank centre; end ornaments retain their proportions.
            var background = new NinePatchRect { Texture = texture, Size = rect.Size / scale, Scale = Vector2.One * scale,
                PatchMarginLeft = (int)(texture.GetWidth() * .18f), PatchMarginRight = (int)(texture.GetWidth() * .18f),
                MouseFilter = MouseFilterEnum.Ignore, ShowBehindParent = true };
            button.AddChild(background);
            button.AddThemeFontSizeOverride("font_size", rect.Size.X < 250 ? 23 : 28);
        }
        bool modalButton = parent == _modal || _modal.IsAncestorOf(parent);
        if (modalButton) _modalControls.Add(button); else _buttons.Add(button);
        button.Pressed += () => { if (!button.Disabled && !_busy && IsVisibleInTree() && (!ModalOpen || modalButton) && button.IsVisibleInTree()) action(); };
        ArtworkButtonFocus.Attach(button);
        Vector2 position = rect.Position;
        void RefreshHover()
        {
            bool active = button.IsHovered() || button.HasFocus();
            Hover(button, active ? 1.015f : 1, active ? position - new Vector2(0, 4) : position);
        }
        button.MouseEntered += RefreshHover;
        button.MouseExited += RefreshHover;
        button.FocusEntered += RefreshHover;
        button.FocusExited += RefreshHover;
        button.ButtonDown += () => Hover(button, .98f, position);
        button.ButtonUp += RefreshHover;
        return button;
    }
    private void Hover(Control node, float scale, Vector2 position)
    {
        if (!node.IsInsideTree() || node is BaseButton { Disabled: true }) return;
        if (_hoverTweens.Remove(node, out var old)) old.Kill(); node.PivotOffset = node.Size / 2;
        var tween = CreateTween().SetParallel(); _hoverTweens[node] = tween;
        tween.TweenProperty(node, "scale", Vector2.One * scale, .14).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(node, "position", position, .14).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
    }
}
