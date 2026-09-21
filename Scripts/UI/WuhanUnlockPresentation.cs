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
    private Label _error = null!, _state = null!;
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
        Art(_canvas, "卡通世界地图母版", new(-1000, 135, 1900, 840)).Modulate = new(1, 1, 1, .48f);
        Text(_canvas, "早餐旅程", new(100, 95, 550, 72), 48);
        Text(_canvas, "从天津出发，发现下一份早餐", new(105, 175, 590, 48), 26);
        for (int i = 0; i < 17; i++)
        {
            float p = i / 16f;
            Vector2 at = new Vector2(578, 389).Lerp(new(396, 594), p) + new Vector2(-65 * Mathf.Sin(p * Mathf.Pi), 0);
            var dash = new ColorRect { Position = at, Size = new(11, 6), Rotation = -.72f, Color = Teal, MouseFilter = Control.MouseFilterEnum.Ignore };
            _canvas.AddChild(dash); _dashes.Add(dash);
        }
        _tianjin = Art(_canvas, "第一站天津节点专属素材", new(498, 267, 165, 165));
        Text(_canvas, "天津", new(503, 423, 155, 45), 31, true);
        _halo = Art(_canvas, "城市解锁轻光效", new(273, 462, 255, 255));
        _locked = Art(_canvas, "未解锁城市节点", new(315, 492, 165, 165));
        _wuhan = Art(_canvas, JourneyModel.NodeArt(JourneyModel.City(StableIds.Cities.Wuhan)), new(315, 492, 165, 165));
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
        Text(_canvas, "武汉", new(322, 660, 155, 45), 34, true);
        _state = Text(_canvas, "新的目的地", new(274, 711, 250, 38), 24, true);
        _state.AddThemeColorOverride("font_color", Teal);
        for (int i = 0; i < 3; i++) _stars.Add(Art(_canvas, "城市节点点亮星闪" + (i + 1), new(285 + i * 80, 482 - (i % 2) * 40, 48, 48)));
        Text(_canvas, "天津仍然开放\n熟悉的小店，随时都能回来", new(100, 858, 600, 104), 27);

        _card = new Control { Name = "WuhanPostcard", Position = new(770, 95), Size = new(1040, 885), PivotOffset = new(520, 442), MouseFilter = Control.MouseFilterEnum.Stop };
        _canvas.AddChild(_card);
        var panel = new Panel { Size = _card.Size, MouseFilter = Control.MouseFilterEnum.Ignore };
        panel.AddThemeStyleboxOverride("panel", TianjinUi.Box(new Color("#FFF6E5"), 24, 3)); _card.AddChild(panel);
        _copy = new Control { MouseFilter = Control.MouseFilterEnum.Ignore }; _card.AddChild(_copy);
        Text(_copy, "新城市已解锁", new(65, 36, 650, 40), 25).AddThemeColorOverride("font_color", Teal);
        Text(_copy, "下一站，武汉", new(65, 84, 770, 85), 61);
        _food = Art(_card, "武汉旅行明信片", new(42, 176, 745, 430));
        var doupi = new BookFoodIcon { Position = new(799, 435), Size = new(164, 115), CropTransparentMargins = true, Product = new("", "三鲜豆皮", 1, "Doupi") };
        _copy.AddChild(doupi);
        Text(_copy, "三鲜豆皮", new(790, 561, 182, 40), 25, true);
        _stamp = Art(_card, "武汉城市旅行印章", new(816, 180, 152, 150));
        Text(_copy, "从摊煎饼，到拌一碗热干面。", new(65, 624, 925, 53), 35);
        Text(_copy, "本章特色：热干面 · 三鲜豆皮", new(65, 683, 925, 42), 26);
        for (int i = 0; i < 2; i++) _steam.Add(Art(_card, "早餐铺蒸汽动画" + (i + 1), new(300 + 115 * i, 303, 72, 115)));
        _actions = new Control { MouseFilter = Control.MouseFilterEnum.Ignore }; _card.AddChild(_actions);
        _depart = Button(_actions, "前往武汉", new(65, 752, 400, 72), true, () => Leave(StableIds.Cities.Wuhan));
        _stay = Button(_actions, "留在天津", new(500, 752, 310, 72), false, () => Leave(StableIds.Cities.Tianjin));
        Text(_actions, "天津的营业进度与设备升级都会保留。", new(65, 834, 930, 34), 23);
        _error = Text(_canvas, "", new(785, 988, 1015, 64), 22);
        _skip = Button(_canvas, "跳过 · Esc", new(1530, 20, 275, 58), false, Skip);
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
            _time = 4.4f; ApplyTime(4.4f); _paper.Position = Vector2.Zero;
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
        _paper.Position = new(-1920 * Ease(Beat(t, 0, .6f)), 0);
        if (_sourceFrame is not null) Alpha(_sourceFrame, 1 - Beat(t, 0, .35f));
        for (int i = 0; i < _dashes.Count; i++) Alpha(_dashes[i], Beat(t, .6f + i * .06f, .1f));
        _tianjin.PivotOffset = _tianjin.Size / 2;
        _tianjin.Scale = Vector2.One * (1 + .045f * Mathf.Sin(Beat(t, .6f, .5f) * Mathf.Pi));
        float light = Beat(t, 1.7f, .4f);
        Alpha(_locked, 1 - light); Alpha(_wuhan, light);
        _wuhan.PivotOffset = _wuhan.Size / 2;
        float bounce = light < .5f ? Mathf.Lerp(.86f, 1.12f, light * 2) : light < .8f ? Mathf.Lerp(1.12f, .98f, (light - .5f) / .3f) : Mathf.Lerp(.98f, 1, (light - .8f) / .2f);
        _wuhan.Scale = Vector2.One * bounce;
        float halo = Beat(t, 1.7f, .6f); _halo.PivotOffset = _halo.Size / 2; _halo.Scale = Vector2.One * (1 + halo * .25f);
        Alpha(_halo, Mathf.Sin(halo * Mathf.Pi) * .8f);
        foreach (var star in _stars) Alpha(star, Mathf.Sin(Beat(t, 1.75f, .55f) * Mathf.Pi));
        _state.Text = t >= 1.7f ? "已解锁 · 可以前往" : "新的目的地";
        float card = Ease(Beat(t, 2.3f, .6f)); Alpha(_card, card);
        _card.Scale = Vector2.One * (card < .8f ? Mathf.Lerp(.93f, 1.02f, card / .8f) : Mathf.Lerp(1.02f, 1, (card - .8f) / .2f));
        _card.RotationDegrees = -3 * (1 - card); _card.Position = new(770, 95 + 28 * (1 - card));
        Alpha(_copy, Beat(t, 2.9f, .35f));
        _food.PivotOffset = _food.Size / 2; _food.Scale = Vector2.One * (1 + .05f * Mathf.Sin(Beat(t, 2.9f, .6f) * Mathf.Pi));
        for (int i = 0; i < _steam.Count; i++)
        {
            float steam = Beat(t, 3.1f + .15f * i, 1);
            Alpha(_steam[i], Mathf.Sin(steam * Mathf.Pi) * .65f); _steam[i].Position = new(300 + 115 * i, 303 - steam * 42);
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
    private static Button Button(Control parent, string text, Rect2 bounds, bool primary, Action pressed)
    {
        var button = TianjinUi.Button(text, primary, bounds.Size); button.Position = bounds.Position; button.Size = bounds.Size;
        parent.AddChild(button); button.Pressed += pressed; ButtonHoverFeedback.Attach(button); return button;
    }
}
