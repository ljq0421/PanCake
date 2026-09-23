using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>Presentation only: the successful settlement has already unlocked the destination.</summary>
public partial class WuhanUnlockPresentation : CanvasLayer
{
    private Control _root = null!, _canvas = null!;
    private TextureRect _tianjin = null!, _wuhan = null!, _locked = null!, _halo = null!;
    private ColorRect _paper = null!;
    private Action<string> _finished = null!;
    private Control _map = null!;
    private TextureRect _cover = null!;
    private ColorRect _sheet = null!;
    private Button _skip = null!;
    private readonly List<Control> _dashes = new(), _stars = new();
    private WuhanUnlockAudio _audio = null!;
    private Tween? _timeline;
    private SaveService _save = null!;
    private float _time;
    private bool _ready, _focused = true;
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

        _cover = Art(_canvas, "闭合旅行手账封面｜新旅程入口", new(685, 210, 540, 690));
        _sheet = new ColorRect { Size = new(32, 625), Color = new("#FFF5DF"), MouseFilter = Control.MouseFilterEnum.Ignore };
        _canvas.AddChild(_sheet);
        _skip = Button(_canvas, "跳过 · Esc", new(1530, 40, 275, 58), false, Skip);
        _paper = new ColorRect { Size = new(1920, 1080), Color = new("#FFF6E5"), MouseFilter = Control.MouseFilterEnum.Stop };
        _canvas.AddChild(_paper);
        if (SourceFrame is not null)
        {
            _sourceFrame = new TextureRect { Texture = SourceFrame, ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.Scale, MouseFilter = Control.MouseFilterEnum.Ignore };
            _paper.AddChild(_sourceFrame); _sourceFrame.Size = new(1920, 1080);
        }
        _audio = new WuhanUnlockAudio(); AddChild(_audio);
    }

    public void Begin(SaveService save, Action<string> finished)
    {
        _save = save; _finished = finished;
        JourneyTransition.For(this).Finish();
        ApplyTime(0); _audio.Play(WuhanUnlockCue.Sweep);
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
            if (_time < 1.7f && t >= 1.7f) _audio.Play(WuhanUnlockCue.Unlock);
            if (_time < 2.3f && t >= 2.3f) _audio.Play(WuhanUnlockCue.Paper);
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
        // Reveal the shared introduction beneath the map instead of building a second final page.
        float card = Ease(Beat(t, 2.3f, .7f));
        Alpha(_canvas, 1 - card);
        _cover.Position = new(685, 210 + 32 * (1 - card));
        Alpha(_cover, Beat(t, 2.3f, .15f) * (1 - Beat(t, 2.5f, .35f)));
        _sheet.Position = new(1510 - 1150 * Ease(Beat(t, 2.5f, .45f)), 225);
        Alpha(_sheet, Mathf.Sin(Beat(t, 2.5f, .45f) * Mathf.Pi) * .8f);
    }

    public void Skip()
    {
        if (_ready) return;
        _timeline?.Kill(); _audio.Stop(); _time = 4.4f; ShowFinal();
        GetViewport().SetInputAsHandled();
    }
    private void ShowFinal()
    {
        _timeline = null;
        _time = 4.4f; ApplyTime(4.4f); _paper.Hide(); _skip.Hide();
        _ready = true;
        string error = _save.TryMarkWuhanUnlockSeen(out string message) ? "" : "演出记录未保存：" + message + "（武汉仍已解锁）";
        GetViewport().GuiReleaseFocus();
        // Keep the input shield through the skip key release; only then enable the shared page.
        _timeline = CreateTween();
        _timeline.TweenInterval(.3);
        _timeline.TweenCallback(Callable.From(() => { _finished(error); QueueFree(); }));
    }
    public override void _Input(InputEvent input)
    {
        if (!_ready && input is InputEventKey { Pressed: true, Echo: false, Keycode: Key.Escape }) Skip();
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
