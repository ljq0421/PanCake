using Godot;

namespace ProjectCake.UI;

public partial class EquipmentUpgradeView
{
    private static readonly Dictionary<string, Texture2D> CroppedArt = new();

    // Crop only the atlas region; preserve the source artwork shared by other pages.
    private static Texture2D TrimmedArt(string path)
    {
        if (CroppedArt.TryGetValue(path, out var cached)) return cached;
        var texture = GD.Load<Texture2D>(path);
        using var image = texture.GetImage();
        image.Convert(Image.Format.Rgba8);
        byte[] data = image.GetData();
        int width = image.GetWidth(), height = image.GetHeight(), left = width, top = height, right = -1, bottom = -1;
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
            if (data[(y * width + x) * 4 + 3] >= 128)
            { left = Math.Min(left, x); top = Math.Min(top, y); right = Math.Max(right, x); bottom = Math.Max(bottom, y); }
        if (right >= left && bottom >= top)
            texture = new AtlasTexture { Atlas = texture, Region = new Rect2(left, top, right - left + 1, bottom - top + 1) };
        CroppedArt[path] = texture;
        return texture;
    }

    private static TextureRect Sprite(Control parent, string name, string path, Rect2 rect, bool stretch = false)
    {
        var sprite = new TextureRect { Name = name, Position = rect.Position, Size = rect.Size, Texture = TrimmedArt(path),
            TextureFilter = TextureFilterEnum.Linear,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = stretch ? TextureRect.StretchModeEnum.Scale : TextureRect.StretchModeEnum.KeepAspectCentered,
            MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(sprite);
        return sprite;
    }

    internal static Control AddWallet(Control parent, int coins, Rect2 rect)
    {
        const string artPath = "res://resource/art/Global/StartPage/钱袋子.png";
        var texture = TrimmedArt(artPath);
        float height = rect.Size.X * texture.GetHeight() / texture.GetWidth();
        // Preserve the artwork's proportions and the gap above the return button.
        var plate = new Control { Name = "UpgradeWallet", Position = new(rect.Position.X, rect.End.Y - height),
            Size = new(rect.Size.X, height), MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(plate);
        Sprite(plate, "WalletArt", artPath, new(Vector2.Zero, plate.Size));
        var label = LabelAt(plate, "Coins", coins.ToString(),
            new(plate.Size.X * .40f, height * .23f, plate.Size.X * .54f, height * .62f), 28, Ink, true);
        label.AutowrapMode = TextServer.AutowrapMode.Off;
        int fontSize = 28;
        while (fontSize > 16 && label.GetThemeFont("font").GetStringSize(label.Text, fontSize: fontSize).X > label.Size.X) fontSize--;
        label.AddThemeFontSizeOverride("font_size", fontSize);
        return plate;
    }

    private static Control MoneyPlate(Control parent, string name, string labelName, string caption, Rect2 rect, bool showCoin)
    {
        var plate = new Control { Name = name, Position = rect.Position, Size = rect.Size, MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(plate);
        PaintedBackground(plate, "升级费用底板-v1.png", 48, 48);
        float iconSize = 36, gap = 12, available = rect.Size.X - 40 - (showCoin ? iconSize + gap : 0);
        var label = LabelAt(plate, labelName, caption, new(20, 8, available, rect.Size.Y - 16), 27, Ink, true);
        label.AutowrapMode = TextServer.AutowrapMode.Off;
        int fontSize = 27;
        var font = label.GetThemeFont("font");
        string translated = label.Tr(caption);
        while (fontSize > 16 && font.GetStringSize(translated, fontSize: fontSize).X > available) fontSize--;
        label.AddThemeFontSizeOverride("font_size", fontSize);
        label.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
        float textWidth = Math.Min(available, font.GetStringSize(translated, fontSize: fontSize).X + 2);
        float total = textWidth + (showCoin ? iconSize + gap : 0), start = (rect.Size.X - total) / 2;
        label.Position = new(start + (showCoin ? iconSize + gap : 0), 8);
        label.Size = new(textWidth, rect.Size.Y - 16);
        if (showCoin) Sprite(plate, "CoinIcon", "res://resource/art/TianJin/金币图标.png", new(start, (rect.Size.Y - iconSize) / 2, iconSize, iconSize));
        return plate;
    }

    private static void SkinPurchaseButton(Button button)
    {
        var texture = TrimmedArt("res://resource/art/Global/StartPage/首页地图按钮底板.png");
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        float scale = button.Size.Y / texture.GetHeight();
        var background = new NinePatchRect { Name = "UpgradeButtonArt", Texture = texture,
            TextureFilter = TextureFilterEnum.Linear,
            Size = button.Size / scale, Scale = Vector2.One * scale,
            PatchMarginLeft = texture.GetHeight() / 2, PatchMarginRight = texture.GetHeight() / 2,
            MouseFilter = MouseFilterEnum.Ignore, ShowBehindParent = true };
        button.AddChild(background);
        void Refresh() => background.SelfModulate = button.Disabled ? new(.72f, .69f, .63f, .7f)
            : button.IsPressed() ? new(.9f, .85f, .75f)
            : button.IsHovered() || button.HasFocus() ? new(1.06f, 1.04f, 1f) : Colors.White;
        button.Draw += Refresh;
        button.MouseEntered += Refresh; button.MouseExited += Refresh;
        button.FocusEntered += Refresh; button.FocusExited += Refresh;
        button.ButtonDown += Refresh; button.ButtonUp += Refresh;
        Refresh();
        button.AddThemeColorOverride("font_disabled_color", Muted);
    }
}
