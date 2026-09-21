using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>Presentation only: the successful settlement has already unlocked the destination.</summary>
public partial class WuhanUnlockPresentation : CanvasLayer
{
    private Control _root = null!, _canvas = null!, _card = null!, _copy = null!, _actions = null!;
    private TextureRect _tianjin = null!, _wuhan = null!, _locked = null!, _halo = null!, _food = null!, _stamp = null!;
    private ColorRect _paper = null!;
    private Label _error = null!;
    private Control _map = null!;
    private TextureRect _cover = null!;
    private ColorRect _sheet = null!;
    private Button _skip = null!, _depart = null!, _stay = null!;
    private readonly List<Control> _dashes = new(), _stars = new(), _steam = new();
    private OpeningAudio _audio = null!;
    private Tween? _timeline;
    private SaveService _save = null!;
    private Func<string, string> _navigate = null!;
    private float _time;
    private bool _ready, _leaving, _focused = true;
    private double _armedAt;
    public Texture2D? SourceFrame { get; set; }
    private TextureRect? _sourceFrame;
    public bool FinalVisible => _ready;
    public bool WuhanMusicReady => _time >= 2.9f;
    private static bool Reduced => JourneyTransition.Reduced;
    private static readonly Color Teal = new("#387F70");

    public override void _Ready()
    {
        Layer = 310;
        _root = new Control { MouseFilter = Control.MouseFilterEnum.Stop, Theme = TianjinUi.CreateTheme() };
        AddChild(_root); _root.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        var background = new ColorRect { Color = new("#F4E7CD"), MouseFilter = Control.MouseFilterEnum.Stop };
        _root.AddChild(background); background.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        _canvas = new Control { Size = new(1920, 1080), MouseFilter = Control.MouseFilterEnum.Ignore };
        _root.AddChild(_canvas);
        void Fit() { float s = Math.Min(_root.Size.X / 1920, _root.Size.Y / 1080); _canvas.Scale = Vector2.One * s; _canvas.Position = (_root.Size - new Vector2(1920, 1080) * s) / 2; }
        _root.Resized += Fit; Fit();
        Art(_canvas, "开始页面早餐铺背景", new(0, 0, 1920, 1080)).StretchMode = TextureRect.StretchModeEnum.Scale;
        // Match the first journey's wall map and camera before opening the next book page.
        _map = new Control { Name = "JourneyWallMap", Size = new(1080, 640), MouseFilter = Control.MouseFilterEnum.Ignore };
        _canvas.AddChild(_map);
        Art(_map, "世界地图墙挂底板", new(0, 0, 1080, 640)).StretchMode = TextureRect.StretchModeEnum.Scale;
        Art(_map, "卡通世界地图母版", new(45, 105, 990, 470)).StretchMode = TextureRect.StretchModeEnum.Scale;
        for (int i = 0; i < 17; i++)
        {
            float p = i / 16f;
            Vector2 at = new Vector2(809, 248).Lerp(new(704, 345), p) + new Vector2(-18 * Mathf.Sin(p * Mathf.Pi), 0);
            var dash = new ColorRect { Position = at, Size = new(5, 3), Rotation = -.72f, Color = Teal, MouseFilter = Control.MouseFilterEnum.Ignore };
            _map.AddChild(dash); _dashes.Add(dash);
        }
        _tianjin = Art(_map, "第一站天津节点专属素材", new(770, 160, 94, 90));
        MapCaption("天津", new(757, 252, 120, 35));
        _halo = Art(_map, "城市节点悬停高亮环", new(644, 283, 132, 116));
        _locked = Art(_map, "未解锁城市节点", new(658, 295, 94, 90));
        _wuhan = Art(_map, JourneyModel.NodeArt(JourneyModel.City(StableIds.Cities.Wuhan)), new(658, 295, 94, 90));
        // Keep the supplied illustration; tint only its golden marker rim into the chapter's teal.
        _wuhan.Material = new ShaderMaterial { Shader = new Shader { Code = """
            shader_type canvas_item;
            varying vec4 tint;
            void vertex() { tint = COLOR; }
            void fragment() {
                vec4 c = texture(TEXTURE, UV);
                bool rim = length((UV - vec2(0.5, 0.44)) * vec2(1.0, 1.1)) > 0.29;
                if (rim && c.r > c.g * 1.04 && c.g > c.b * 1.45 && c.g > 0.5) {
                    float light = dot(c.rgb, vec3(0.3, 0.59, 0.11));
                    c.rgb = mix(vec3(0.24, 0.50, 0.43), vec3(0.77, 0.89, 0.76), light);
                }
                COLOR = c * tint;
            }
            """ } };
        MapCaption("下一站 · 武汉", new(600, 390, 220, 38));
        for (int i = 0; i < 3; i++) _stars.Add(Art(_map, "城市节点点亮星闪" + (i + 1), new(650 + i * 42, 285 - (i % 2) * 20, 30, 30)));

        _card = new Control { Name = "WuhanPostcard", Size = new(1920, 1080), PivotOffset = new(960, 540), MouseFilter = Control.MouseFilterEnum.Ignore };
        _canvas.AddChild(_card);
        var book = Art(_card, "旅行手账双页母版", StartScreen.BookBounds);
        CityPageArtSkin.Apply(book, StableIds.Cities.Wuhan);
        _copy = new Control { MouseFilter = Control.MouseFilterEnum.Ignore }; _card.AddChild(_copy);
        Text(_copy, "下一站，武汉", new(350, 277, 530, 75), 48, true);
        _food = Art(_card, "武汉旅行明信片", new(335, 390, 550, 350));
        _stamp = Art(_card, "武汉城市旅行印章", new(733, 709, 120, 120));
        Text(_copy, "从摊煎饼，到拌一碗热干面。", new(1015, 288, 505, 65), 32, true);
        var noodles = new BookFoodIcon { Position = new(1075, 397), Size = new(140, 125), CropTransparentMargins = true, Product = new("", "热干面", 1, "HotDryNoodles") };
        _copy.AddChild(noodles);
        var doupi = new BookFoodIcon { Position = new(1320, 397), Size = new(140, 125), CropTransparentMargins = true, Product = new("", "三鲜豆皮", 1, "Doupi") };
        _copy.AddChild(doupi);
        Text(_copy, "热干面", new(1055, 532, 180, 42), 28, true);
        Text(_copy, "三鲜豆皮", new(1300, 532, 180, 42), 28, true);
        Text(_copy, "天津仍然开放\n熟悉的小店，随时都能回来", new(1040, 603, 465, 105), 27, true);
        for (int i = 0; i < 2; i++) _steam.Add(Art(_card, "早餐铺蒸汽动画" + (i + 1), new(540 + 65 * i, 472, 48, 80)));
        _actions = new Control { MouseFilter = Control.MouseFilterEnum.Ignore }; _card.AddChild(_actions);
        _depart = Button(_actions, "前往武汉", new(1080, 748, 390, 70), true, () => Leave(StableIds.Cities.Wuhan));
        _stay = Button(_actions, "留在天津", new(1160, 813, 230, 48), false, () => Leave(StableIds.Cities.Tianjin));
        Text(_actions, "天津的营业进度与设备升级都会保留。", new(345, 813, 540, 36), 22, true);
        _cover = Art(_canvas, "闭合旅行手账封面｜新旅程入口", new(685, 210, 540, 690));
        _sheet = new ColorRect { Size = new(32, 625), Color = new("#FFF5DF"), MouseFilter = Control.MouseFilterEnum.Ignore };
        _canvas.AddChild(_sheet);
        _error = Text(_canvas, "", new(390, 960, 1140, 64), 22, true);
        _skip = Button(_canvas, "跳过 · Esc", new(1530, 40, 275, 58), false, Skip);
        _paper = new ColorRect { Size = new(1920, 1080), Color = new("#FFF6E5"), MouseFilter = Control.MouseFilterEnum.Stop };
        _canvas.AddChild(_paper);
        if (SourceFrame is not null)
        {
            _sourceFrame = new TextureRect { Texture = SourceFrame, ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.Scale, MouseFilter = Control.MouseFilterEnum.Ignore };
            _paper.AddChild(_sourceFrame); _sourceFrame.Size = new(1920, 1080);
        }
        _audio = new OpeningAudio(); AddChild(_audio);
    }

    public void Begin(SaveService save, Func<string, string> navigate)
    {
        _save = save; _navigate = navigate;
        JourneyTransition.For(this).Finish();
        ApplyTime(0); _audio.Play(OpeningCue.Paper);
        _timeline = CreateTween();
        if (Reduced)
        {
            _time = 4.4f; ApplyTime(4.4f); _paper.Position = Vector2.Zero; _paper.Modulate = Colors.White;
            _timeline.TweenProperty(_paper, "modulate:a", 0f, .18);
        }
        else _timeline.TweenMethod(Callable.From<float>(ApplyTime), 0f, 4.4f, 4.4);
        _timeline.TweenCallback(Callable.From(ShowFinal));
    }

    private static float Beat(float t, float start, float length) => Mathf.Clamp((t - start) / length, 0, 1);
    private static float Ease(float p) => 1 - Mathf.Pow(1 - p, 3);
    private static void Alpha(Control node, float a) => node.Modulate = new(1, 1, 1, a);
    private void ApplyTime(float t)
    {
        if (_focused)
        {
            if (_time < 1.7f && t >= 1.7f) _audio.Play(OpeningCue.Locate);
            if (_time < 2.3f && t >= 2.3f) _audio.Play(OpeningCue.Paper);
            if (_time < 3.8f && t >= 3.8f) _audio.Play(OpeningCue.Postcard);
        }
        _time = t;
        _paper.Position = Vector2.Zero;
        Alpha(_paper, 1 - Ease(Beat(t, 0, .55f)));
        float move = Ease(Beat(t, .1f, .9f));
        _map.Position = new Vector2(445, 100).Lerp(new(247, 130), move);
        _map.Scale = Vector2.One * Mathf.Lerp(1, 1.32f, move);
        Alpha(_map, 1 - Ease(Beat(t, 2.3f, .6f)));
        if (_sourceFrame is not null) Alpha(_sourceFrame, 1 - Beat(t, 0, .35f));
        for (int i = 0; i < _dashes.Count; i++) Alpha(_dashes[i], Beat(t, .6f + i * .06f, .1f));
        _tianjin.PivotOffset = _tianjin.Size / 2;
        _tianjin.Scale = Vector2.One * (1 + .045f * Mathf.Sin(Beat(t, .6f, .5f) * Mathf.Pi));
        float light = Beat(t, 1.7f, .4f);
        Alpha(_locked, 1 - light); Alpha(_wuhan, light);
        _wuhan.PivotOffset = _wuhan.Size / 2;
        _wuhan.Position = new(658, 295 - 24 * (1 - Ease(light)));
        float squash = Mathf.Sin(Beat(t, 2.0f, .22f) * Mathf.Pi);
        _wuhan.Scale = new(1 + .035f * squash, 1 - .055f * squash);
        float halo = Beat(t, 1.7f, .6f); _halo.PivotOffset = _halo.Size / 2; _halo.Scale = Vector2.One * (1 + halo * .25f);
        Alpha(_halo, Mathf.Sin(halo * Mathf.Pi) * .8f);
        foreach (var star in _stars) Alpha(star, Mathf.Sin(Beat(t, 1.75f, .55f) * Mathf.Pi));
        float card = Ease(Beat(t, 2.3f, .7f)); Alpha(_card, card);
        _card.Position = new(0, 32 * (1 - card));
        _cover.Position = new(685, 210 + 32 * (1 - card));
        Alpha(_cover, Beat(t, 2.3f, .15f) * (1 - Beat(t, 2.5f, .35f)));
        _sheet.Position = new(1510 - 1150 * Ease(Beat(t, 2.5f, .45f)), 225);
        Alpha(_sheet, Mathf.Sin(Beat(t, 2.5f, .45f) * Mathf.Pi) * .8f);
        Alpha(_copy, Beat(t, 2.9f, .35f));
        float postcard = Ease(Beat(t, 2.9f, .5f)); Alpha(_food, postcard);
        _food.PivotOffset = _food.Size / 2;
        _food.RotationDegrees = -2 * (1 - postcard);
        _food.Position = new(335, 390 - 18 * (1 - postcard));
        for (int i = 0; i < _steam.Count; i++)
        {
            float steam = Beat(t, 3.1f + .15f * i, 1);
            Alpha(_steam[i], Mathf.Sin(steam * Mathf.Pi) * .65f); _steam[i].Position = new(540 + 65 * i, 472 - steam * 32);
        }
        float stamp = Beat(t, 3.8f, .25f); Alpha(_stamp, stamp); _stamp.PivotOffset = _stamp.Size / 2; _stamp.Scale = Vector2.One * Mathf.Lerp(1.14f, 1, Ease(stamp));
        Alpha(_actions, Beat(t, 4.0f, .4f)); _depart.Disabled = _stay.Disabled = true;
    }

    public void Skip()
    {
        if (_ready || _leaving) return;
        _timeline?.Kill(); _audio.Stop(); _time = 4.4f; ShowFinal();
        GetViewport().SetInputAsHandled();
    }
    private void ShowFinal()
    {
        _timeline = null;
        _time = 4.4f; ApplyTime(4.4f); _paper.Hide(); _skip.Hide();
        _ready = true; _armedAt = Time.GetTicksMsec() + 300;
        _depart.Disabled = _stay.Disabled = false;
        if (!_save.TryMarkWuhanUnlockSeen(out string error)) _error.Text = "演出记录未保存：" + error + "（武汉仍已解锁）";
        // Do not focus a newly revealed action with the key used to skip.
        GetViewport().GuiReleaseFocus();
    }
    private void Leave(string city)
    {
        if (!_ready || _leaving || Time.GetTicksMsec() < _armedAt) return;
        _leaving = true; _depart.Disabled = _stay.Disabled = true;
        _audio.Play(OpeningCue.Paper);
        _paper.Show(); _paper.Modulate = Colors.White; _paper.Position = new(1920, 0);
        _timeline = CreateTween();
        _timeline.TweenProperty(_paper, "position", Vector2.Zero, Reduced ? .1 : .35).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.InOut);
        if (!Reduced) _timeline.Parallel().TweenProperty(_card, "scale", Vector2.One * 1.035f, .35);
        _timeline.TweenCallback(Callable.From(() =>
        {
            string error = _navigate(city);
            JourneyTransition.For(this).Finish();
            if (error.Length == 0)
            {
                foreach (var control in _root.GetChildren().OfType<Control>().Where(c => c != _canvas)) control.Hide();
                foreach (var control in _canvas.GetChildren().OfType<Control>().Where(c => c != _paper)) control.Hide();
            }
            else { _error.Text = "暂时无法出发：" + error; _leaving = false; _depart.Disabled = _stay.Disabled = false; }
        }));
        // The paper lives separately during the reveal; keep the destination visible beneath it.
        _timeline.TweenProperty(_paper, "position", new Vector2(-1920, 0), Reduced ? .1 : .35).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.InOut);
        _timeline.TweenCallback(Callable.From(() => { _timeline = null; if (_leaving) QueueFree(); else { _paper.Hide(); _card.Scale = Vector2.One; } }));
    }
    public override void _Input(InputEvent input)
    {
        if (input is InputEventKey { Pressed: true, Echo: false, Keycode: Key.Escape })
        { if (!_ready) Skip(); GetViewport().SetInputAsHandled(); }
        else if (_ready && !_leaving && Time.GetTicksMsec() >= _armedAt && input is InputEventKey key)
        {
            if (key.Pressed && !key.Echo)
            {
                if (key.Keycode == Key.Tab)
                {
                    if (GetViewport().GuiGetFocusOwner() == _depart) _stay.GrabFocus(); else _depart.GrabFocus();
                }
                else if (key.Keycode is Key.Enter or Key.Space && GetViewport().GuiGetFocusOwner() is Button focused)
                {
                    if (focused == _depart) Leave(StableIds.Cities.Wuhan);
                    else if (focused == _stay) Leave(StableIds.Cities.Tianjin);
                }
            }
            GetViewport().SetInputAsHandled();
        }
        else if ((!_ready && input is InputEventKey) || _leaving || (_ready && Time.GetTicksMsec() < _armedAt))
            GetViewport().SetInputAsHandled();
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) { _focused = false; _audio?.Stop(); _timeline?.Pause(); }
        if (what == NotificationApplicationFocusIn) { _focused = true; _timeline?.Play(); }
    }
    public override void _ExitTree() { _timeline?.Kill(); _audio?.Stop(); }
    private static Label Text(Control parent, string text, Rect2 bounds, int size, bool centered = false)
    {
        var label = TianjinUi.Label(text, size, StartScreenTheme.Ink, centered ? HorizontalAlignment.Center : HorizontalAlignment.Left);
        label.Position = bounds.Position; label.Size = bounds.Size; label.MouseFilter = Control.MouseFilterEnum.Ignore; parent.AddChild(label); return label;
    }
    private static TextureRect Art(Control parent, string name, Rect2 bounds)
    {
        var image = new TextureRect { Texture = GD.Load<Texture2D>(JourneyModel.ArtRoot + name + ".png"), Position = bounds.Position, Size = bounds.Size,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, MouseFilter = Control.MouseFilterEnum.Ignore };
        parent.AddChild(image); image.Size = bounds.Size; return image;
    }
    private void MapCaption(string text, Rect2 bounds)
    {
        var label = Text(_map, text, bounds, 25, true);
        label.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
        label.AddThemeConstantOverride("outline_size", 4);
    }
    private static Button Button(Control parent, string text, Rect2 bounds, bool primary, Action pressed)
    {
        var button = TianjinUi.Button(text, primary, bounds.Size); button.Position = bounds.Position; button.Size = bounds.Size;
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_focus_color" })
            button.AddThemeColorOverride(state, StartScreenTheme.Ink);
        button.AddThemeFontSizeOverride("font_size", primary ? 32 : 26);
        button.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
        button.AddThemeConstantOverride("outline_size", 3);
        parent.AddChild(button);
        if (primary)
        {
            var texture = GD.Load<Texture2D>("res://resource/art/Wuhan/武汉解锁按钮底板-v1.png");
            using var image = texture.GetImage();
            image.Convert(Image.Format.Rgba8);
            byte[] pixels = image.GetData(); int width = image.GetWidth(), height = image.GetHeight();
            int left = width, right = 0, top = height, bottom = 0;
            // Match the journey buttons: faint export noise must not shrink the painted plate.
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
                if (pixels[(y * width + x) * 4 + 3] >= 128)
                { left = Math.Min(left, x); right = Math.Max(right, x); top = Math.Min(top, y); bottom = Math.Max(bottom, y); }
            var region = left <= right && top <= bottom ? new Rect2(left, top, right - left + 1, bottom - top + 1) : image.GetUsedRect();
            var cropped = new AtlasTexture { Atlas = texture, Region = region };
            float scale = bounds.Size.Y / cropped.GetHeight();
            button.AddChild(new NinePatchRect { Texture = cropped, Size = bounds.Size / scale, Scale = Vector2.One * scale,
                PatchMarginLeft = cropped.GetHeight() / 2, PatchMarginRight = cropped.GetHeight() / 2,
                MouseFilter = Control.MouseFilterEnum.Ignore, ShowBehindParent = true });
        }
        button.Pressed += pressed; ButtonHoverFeedback.Attach(button); return button;
    }
}
