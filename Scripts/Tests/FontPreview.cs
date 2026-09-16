using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Opt-in, frozen copies of real screens. Never changes project or engine fonts.</summary>
public partial class FontPreview : Control
{
    private readonly string[] _names = { "当前字体", "荆南麦圆体", "资源圆体" };
    private readonly Font?[] _fonts = new Font?[3];
    private readonly Dictionary<Control, Theme?> _originalThemes = new();
    private readonly List<Button> _fontButtons = new();
    private StartScreen _city = null!;
    private TianjinDayScreen _day = null!;
    private DayController _controller = null!;
    private SaveService _save = null!;
    private Control _samples = null!, _bar = null!;
    private Label _status = null!;
    private Button _restore = null!;
    private OptionButton _sceneChoice = null!;
    private int _fontIndex;
    private string _output = "";

    public override async void _Ready()
    {
        try
        {
            _output = ProjectSettings.GlobalizePath("res://artifacts/font-preview");
            Directory.CreateDirectory(_output);
            var baseline = ThemeDB.FallbackFont;
            _fonts[1] = LoadFont("KNMaiyuan-Regular.ttf", baseline);
            var rounded = LoadFont("ResourceHanRoundedCN-VF.otf", baseline);
            var textServer = TextServerManager.GetPrimaryInterface();
            // This variable font defaults to ExtraLight (200); use Regular for UI comparison.
            _fonts[2] = new FontVariation { BaseFont = rounded,
                VariationOpentype = new Godot.Collections.Dictionary {
                    [textServer.NameToTag("wght")] = 400f, [textServer.NameToTag("ROND")] = 100f } };

            _samples = new Control { Name = "Samples" };
            AddChild(_samples); _samples.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
            _save = new SaveService { Name = "PreviewSave" };
            _save.UsePathForTests(Path.Combine(_output, "session-" + Guid.NewGuid().ToString("N"), "save.json"));
            AddChild(_save);
            _save.Data.Coins = 128;
            _save.Data.HighestUnlockedDay = 15;
            _save.Data.DayBestRecords[1] = new DayBestRecord { TotalRevenue = 128, CompletedCustomers = 8,
                Satisfaction = 92, PerfectOrders = 3 };
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            _city = GD.Load<PackedScene>("res://Scenes/UI/StartScreen.tscn").Instantiate<StartScreen>();
            _samples.AddChild(_city);
            _city.Initialize(_save); _city.ConfigureCities(catalog, null);
            _city.PresentCity(StableIds.Cities.Tianjin);

            _controller = new DayController { Name = "PreviewDayController" };
            AddChild(_controller); _controller.SetProcess(false);
            _day = GD.Load<PackedScene>("res://Scenes/Gameplay/TianjinDayScreen.tscn").Instantiate<TianjinDayScreen>();
            _samples.AddChild(_day); _day.SetProcess(false);
            _day.ConnectController(_controller);
            Require(_day.Initialize(catalog, _save, _controller, 15), "preview day initializes");
            _day.BeginDay(); _controller.Tick(3.1);
            for (int i = 0; i < 30 && _controller.CustomerQueue!.Slots.Count < 5; i++) _controller.Tick(.5);
            _day.RefreshForCapture();
            await Frames(18);
            // Inert samples keep orders, patience and amounts identical while comparing fonts.
            _samples.ProcessMode = ProcessModeEnum.Disabled;
            var shield = new Control { Name = "FrozenSampleInput", MouseFilter = MouseFilterEnum.Stop };
            AddChild(shield); shield.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
            BuildBar(LoadFont("ZCOOLKuaiLe-Regular.ttf", baseline));
            ShowScene(0);
            if (OS.GetCmdlineUserArgs().Contains("--verify-font-preview")) await VerifyAndCapture();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }

    private static FontFile LoadFont(string filename, Font fallback)
    {
        string folder = filename == "KNMaiyuan-Regular.ttf" ? "KNMaiyuan/" : "preview/";
        var source = GD.Load<FontFile>("res://resource/fonts/" + folder + filename)
            ?? throw new InvalidOperationException("无法读取字体：" + filename);
        var font = (FontFile)source.Duplicate();
        font.Fallbacks = new Godot.Collections.Array<Font> { fallback };
        return font;
    }

    private void BuildBar(Font titleFont)
    {
        _bar = new PanelContainer { Name = "ComparisonBar", Position = new(440, 876), Size = new(1040, 188) };
        _bar.Theme = StartScreenTheme.Create();
        _bar.AddThemeStyleboxOverride("panel", new StyleBoxFlat { BgColor = new Color("#FFF4DD"),
            BorderColor = new Color("#674735"), BorderWidthLeft = 2, BorderWidthRight = 2,
            BorderWidthTop = 2, BorderWidthBottom = 2, CornerRadiusTopLeft = 12, CornerRadiusTopRight = 12,
            CornerRadiusBottomLeft = 12, CornerRadiusBottomRight = 12,
            ContentMarginLeft = 18, ContentMarginRight = 18, ContentMarginTop = 12, ContentMarginBottom = 12 });
        AddChild(_bar);
        var rows = new VBoxContainer(); rows.AddThemeConstantOverride("separation", 8); _bar.AddChild(rows);
        var selectors = new HBoxContainer(); selectors.AddThemeConstantOverride("separation", 10); rows.AddChild(selectors);
        var scene = _sceneChoice = new OptionButton { Name = "SceneChoice", CustomMinimumSize = new(210, 40), FocusMode = FocusModeEnum.None };
        StartScreenTheme.Apply(scene);
        scene.AddThemeFontSizeOverride("font_size", 22);
        foreach (string name in new[] { "天津 · 城市页", "天津 · 营业现场", "天津 · 经营手账" }) scene.AddItem(name);
        scene.ItemSelected += index => ShowScene((int)index); selectors.AddChild(scene);
        for (int i = 0; i < _names.Length; i++)
        {
            int index = i;
            var button = new Button { Name = "Font" + i, Text = _names[i], ToggleMode = true,
                CustomMinimumSize = new(160, 40), FocusMode = FocusModeEnum.None };
            StartScreenTheme.Apply(button); button.AddThemeFontSizeOverride("font_size", 22);
            button.Pressed += () => SelectFont(index); selectors.AddChild(button); _fontButtons.Add(button);
        }
        var hide = new Button { Text = "隐藏对比栏 · F8", FocusMode = FocusModeEnum.None };
        StartScreenTheme.Apply(hide);
        hide.AddThemeFontSizeOverride("font_size", 20); hide.Pressed += ToggleBar; selectors.AddChild(hide);
        _status = new Label(); _status.AddThemeFontSizeOverride("font_size", 19); rows.AddChild(_status);
        var titleRow = new HBoxContainer(); titleRow.AddThemeConstantOverride("separation", 18); rows.AddChild(titleRow);
        var caption = new Label { Text = "站酷快乐体 · 标题试样", VerticalAlignment = VerticalAlignment.Center };
        caption.AddThemeFontSizeOverride("font_size", 19); titleRow.AddChild(caption);
        var sample = new Label { Text = "早餐铺子  今日开张", VerticalAlignment = VerticalAlignment.Center };
        sample.AddThemeFontOverride("font", titleFont); sample.AddThemeFontSizeOverride("font_size", 36); titleRow.AddChild(sample);
        _restore = new Button { Text = "字体对比 · F8", Position = new(1650, 1018), Size = new(235, 44),
            Visible = false, FocusMode = FocusModeEnum.None };
        _restore.AddThemeFontSizeOverride("font_size", 22); _restore.Pressed += ToggleBar; AddChild(_restore);
    }

    private void ShowScene(int index)
    {
        _sceneChoice.Select(index);
        _day.Visible = index == 1; _city.Visible = index != 1;
        if (index != 1)
        {
            _city.PresentCity(StableIds.Cities.Tianjin);
            if (index == 2)
            {
                _city.PresentLedger();
                _city.Descendants<Button>().Single(b => b.Name == "Date1").EmitSignal(BaseButton.SignalName.Pressed);
            }
            // The preview does not run the normal page entrance tween.
            _city.GetNode<Control>("Canvas/Page").Modulate = Colors.White;
        }
        SelectFont(_fontIndex);
    }

    private void SelectFont(int index)
    {
        _fontIndex = index;
        ApplyTheme(_city); ApplyTheme(_day);
        for (int i = 0; i < _fontButtons.Count; i++)
        {
            StartScreenTheme.Apply(_fontButtons[i], primary: i == index);
            _fontButtons[i].AddThemeFontSizeOverride("font_size", 22);
            _fontButtons[i].SetPressedNoSignal(i == index);
        }
        _status.Text = $"{_names[index]} · 原有字号 · 定格样例，金额为演示数据 · F7 切换字体 / F8 显隐";
    }

    private void ApplyTheme(Control root)
    {
        foreach (var control in root.Descendants<Control>().Prepend(root))
        {
            if (control != root && control.Theme is null) continue;
            if (!_originalThemes.TryGetValue(control, out var original))
                _originalThemes[control] = original = control.Theme;
            if (_fonts[_fontIndex] is not { } font) control.Theme = original;
            else
            {
                var theme = original is null ? new Theme() : (Theme)original.Duplicate();
                theme.DefaultFont = font;
                control.Theme = theme;
            }
            control.QueueRedraw();
        }
        // Rendered pages are rebuilt by StartScreen; discard references to their old controls.
        foreach (var control in _originalThemes.Keys.Where(c => !IsInstanceValid(c)).ToArray()) _originalThemes.Remove(control);
    }

    private void ToggleBar() { _bar.Visible = !_bar.Visible; _restore.Visible = !_bar.Visible; }

    public override void _Input(InputEvent input)
    {
        if (_bar is null || input is not InputEventKey { Pressed: true, Echo: false } key) return;
        if (key.Keycode == Key.F7) SelectFont((_fontIndex + 1) % _names.Length);
        else if (key.Keycode == Key.F8) ToggleBar();
        else return;
        GetViewport().SetInputAsHandled();
    }

    private async Task Frames(int count = 4)
    { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }

    private static void Require(bool value, string message)
    { if (!value) throw new InvalidOperationException(message); GD.Print("FONT_PREVIEW_PASS " + message); }

    private async Task VerifyAndCapture()
    {
        var baseline = ThemeDB.FallbackFont;
        var ts = TextServerManager.GetPrimaryInterface();
        var variation = ts.FontGetVariationCoordinates(_fonts[2]!.GetRids()[0]);
        GD.Print("FONT_PREVIEW_VARIATION ", variation);
        Require(variation[ts.NameToTag("wght")].AsDouble() == 400, "rounded font actually renders at weight 400");
        double remaining = _controller.DayRemainingSeconds;
        for (int scene = 0; scene < 3; scene++)
        {
            ShowScene(scene); await Frames();
            Control current = scene == 1 ? _day : _city;
            var label = current.Descendants<Label>().First(l => l.IsVisibleInTree() && l.Text.Length > 0);
            SelectFont(0); var original = label.GetThemeFont("font");
            for (int font = 0; font < 3; font++)
            {
                GetViewport().PushInput(new InputEventMouseButton { Position = _fontButtons[font].GetGlobalRect().GetCenter(),
                    ButtonIndex = MouseButton.Left, Pressed = true }, true);
                GetViewport().PushInput(new InputEventMouseButton { Position = _fontButtons[font].GetGlobalRect().GetCenter(),
                    ButtonIndex = MouseButton.Left, Pressed = false }, true);
                await Frames();
                Require(_fontIndex == font, "real button selects " + _names[font]);
                Require(label.GetThemeFont("font") == (font == 0 ? original : _fonts[font]), "scene label resolves selected font");
                Require(ThemeDB.FallbackFont == baseline, "engine fallback stays unchanged");
                if (DisplayServer.GetName() != "headless")
                {
                    await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                    using var image = GetViewport().GetTexture().GetImage();
                    Require(image.SavePng(Path.Combine(_output, $"scene-{scene}-font-{font}.png")) == Error.Ok, "viewport saved");
                }
            }
            SelectFont(0); Require(label.GetThemeFont("font") == original, "original font restored");
        }
        Require(_controller.DayRemainingSeconds == remaining, "font comparison keeps game time frozen");
        GetViewport().PushInput(new InputEventKey { Keycode = Key.F8, Pressed = true }, true);
        Require(!_bar.Visible && _restore.Visible, "F8 hides toolbar and exposes restore button");
        GD.Print("FONT_PREVIEW_VERIFY_OK"); GetTree().Quit();
    }
}
