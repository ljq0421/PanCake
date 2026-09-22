using Godot;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private TextureRect? _audioIcon;

    private Button Utility(string name, string caption, string icon, float x, Action action)
    {
        var button = Button(_body, name, "", new(x, 913, 88, 102), action, bare: true);
        Art(button, "圆形功能按钮底板", new(9, 0, 70, 70));
        var picture = Art(button, icon, new(22, 13, 44, 44));
        Text(button, "Caption", caption, new(0, 72, 88, 30), 22, true);
        if (name == "Audio") _audioIcon = picture;
        return button;
    }

    private void Ambient()
    {
        // Sample only the repaired steam area. All other artwork remains the original.
        var clean = Texture("开始页面早餐铺背景-无蒸汽-v2");
        var patch = new Rect2(.844f, .720f, .064f, .106f);
        _body.AddChild(new TextureRect
        {
            Name = "HomeSteamBackdrop", MouseFilter = MouseFilterEnum.Ignore,
            Texture = new AtlasTexture { Atlas = clean,
                Region = new Rect2(patch.Position * clean.GetSize(), patch.Size * clean.GetSize()) },
            Position = patch.Position * new Vector2(1920, 1080), Size = patch.Size * new Vector2(1920, 1080),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.Scale,
            Material = new ShaderMaterial { Shader = new Shader { Code = """
                shader_type canvas_item;
                void fragment() {
                    vec2 edge = min(UV - vec2(0.844, 0.720), vec2(0.908, 0.826) - UV);
                    vec2 fade = smoothstep(vec2(0.0), vec2(0.003, 0.005), edge);
                    COLOR = texture(TEXTURE, UV) * vec4(1.0, 1.0, 1.0, fade.x * fade.y);
                }
                """ } }
        });
        Art(_body, "晨光透明覆盖层", new(0, 0, 1920, 1080)).Modulate = new(1, 1, 1, .12f);
        var sunlight = new ShaderMaterial { Shader = new Shader { Code = """
            shader_type canvas_item;
            uniform float phase = 0.0;
            void fragment() {
                // Two soft shafts travel across the visible wall and floor beneath the window.
                float drift = sin(phase) * 0.21;
                float diagonal = UV.x - UV.y * 0.48 + drift;
                float first = smoothstep(-0.14, -0.02, diagonal) * (1.0 - smoothstep(0.18, 0.30, diagonal));
                float second = smoothstep(0.32, 0.43, diagonal) * (1.0 - smoothstep(0.58, 0.70, diagonal));
                float beam = max(first, second * 0.85);
                vec2 edge = smoothstep(vec2(0.0), vec2(0.12), UV) * (1.0 - smoothstep(vec2(0.82), vec2(1.0), UV));
                float strength = 0.36 + 0.16 * sin(phase);
                COLOR = vec4(1.0, 0.92, 0.70, beam * edge.x * edge.y * strength);
            }
            """ } };
        _body.AddChild(new ColorRect { Name = "HomeWindowLight", Position = new(305, 605), Size = new(670, 235),
            MouseFilter = MouseFilterEnum.Ignore, Material = sunlight });
        var signClean = Texture("开始页面早餐铺背景-无木牌-v1");
        // Match the original image coordinates; feather only the boundary outside the removed sign.
        var signPatch = new Rect2(1380f / 1672, 224f / 941, 111f / 1672, 189f / 941);
        _body.AddChild(new TextureRect
        {
            Name = "HomeSignBackdrop", MouseFilter = MouseFilterEnum.Ignore,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.Scale,
            Texture = signClean, Position = signPatch.Position * new Vector2(1920, 1080),
            Size = signPatch.Size * new Vector2(1920, 1080),
            Material = new ShaderMaterial { Shader = new Shader { Code = """
                shader_type canvas_item;
                void fragment() {
                    vec2 atlas_uv = vec2(1380.0 / 1672.0, 224.0 / 941.0) + UV * vec2(111.0 / 1672.0, 189.0 / 941.0);
                    vec2 edge = min(UV, 1.0 - UV);
                    vec2 fade = smoothstep(vec2(0.0), vec2(0.055, 0.025), edge);
                    COLOR = texture(TEXTURE, atlas_uv) * vec4(1.0, 1.0, 1.0, fade.x * fade.y);
                }
                """ } }
        });
        var sign = HomeArt(_body, "首页悬挂木牌-v1", new(1596, 247, 108, 214), stretch: true);
        sign.Name = "HomeHangingSign";
        sign.PivotOffset = new(54, 0);
        // Restrict clouds to clear sky inside the existing left window, above buildings and foliage.
        var window = new Control { Position = new(0, 336), Size = new(183, 54), ClipContents = true, MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(window);
        var clouds = Art(window, "窗外慢移云层", new(-70, 0, 310, 54)); clouds.Modulate = new(1, 1, 1, .28f);
        var steam = Enumerable.Range(1, 3).Select(i =>
        {
            var puff = HomeArt(_body, "早餐铺蒸汽动画" + i, new(1601, 779, 95, 105));
            puff.Name = "HomeSteam" + i;
            puff.PivotOffset = new(47.5f, 105);
            return puff;
        }).ToArray();
        _body.AddChild(new HomeAmbientMotion { Screen = this, Clouds = clouds, Steam = steam, Sign = sign, Sunlight = sunlight });
    }

    private void Frames(Control parent, string prefix, Rect2 rect, double duration, bool loop, float opacity = 1)
    {
        var frames = Enumerable.Range(1, 3).Select(i => Art(parent, prefix + i, rect)).ToArray();
        foreach (var frame in frames) frame.Modulate = new(1, 1, 1, 0);
        var tween = CreateTween(); _tweens.Add(tween); if (loop) tween.SetLoops();
        foreach (var frame in frames)
        {
            tween.TweenProperty(frame, "modulate:a", opacity, duration * .45);
            tween.TweenProperty(frame, "modulate:a", 0f, duration * .55);
        }
    }

    private void JournalTab(string name, string caption, Action action)
    {
        var tab = Button(_body, name, "", new(1610, 554, 245, 100), action, bare: true);
        HomeArt(tab, "旅行手账书签母版", new(0, 0, 245, 100), stretch: true);
        Text(tab, "Caption", caption, new(40, 18, 194, 64), 28, true);
    }

    private void NodeFeedback(Button node, JourneyCity city, bool unlocked)
    {
        if (!unlocked) return;
        var selected = Art(node, "当前选中城市定位底座", new(10, -12, 130, 118));
        selected.ShowBehindParent = true;
        selected.Visible = city.Id == _city;
        var ring = Art(node, "城市节点悬停高亮环", new(4, -19, 142, 128));
        ring.Visible = false;
        node.MouseEntered += () => ring.Visible = true;
        node.MouseExited += () => ring.Visible = node.HasFocus();
        node.FocusEntered += () => ring.Visible = true;
        node.FocusExited += () => ring.Visible = node.IsHovered();
    }

    private void UnlockDecoration()
    {
        var next = JourneyModel.Next(_completedCity!);
        if (next is null)
        {
            // DrawMap already places the final travel stamp inside the map.
            return;
        }
        int index = Array.FindIndex(JourneyModel.Cities, c => c.Id == next.Id);
        Vector2 center = MapNodePosition(index) + MapMarkerSize / 2;
        Vector2 glowSize = MapMarkerSize * 1.8f;
        var glow = Art(_body, "城市解锁轻光效", new(center - glowSize / 2, glowSize));
        glow.Name = "MapUnlockGlow";
        glow.PivotOffset = glow.Size / 2; glow.Scale = Vector2.One * .75f;
        var tween = CreateTween().SetParallel(); _tweens.Add(tween);
        tween.TweenProperty(glow, "scale", Vector2.One * 1.12f, 1.5);
        tween.TweenProperty(glow, "modulate:a", 0f, 1.2).SetDelay(.4);
        Frames(_body, "城市节点点亮星闪", new(center - MapMarkerSize * .7f, MapMarkerSize * 1.4f), .4, false);
        Art(_body, "城市解锁小飘带", new(730, 850, 460, 95));
        Text(_body, "UnlockCaption", next.Name + "已开放", new(805, 875, 310, 44), 25, true);
    }
}
