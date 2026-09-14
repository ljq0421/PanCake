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
        Art(_body, "晨光透明覆盖层", new(0, 0, 1920, 1080)).Modulate = new(1, 1, 1, .12f);
        // Restrict clouds to clear sky inside the existing left window, above buildings and foliage.
        var window = new Control { Position = new(0, 336), Size = new(183, 54), ClipContents = true, MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(window);
        var clouds = Art(window, "窗外慢移云层", new(-70, 0, 310, 54)); clouds.Modulate = new(1, 1, 1, .28f);
        var drift = CreateTween().SetLoops(); _tweens.Add(drift);
        drift.TweenProperty(clouds, "position:x", -20f, 18).SetTrans(Tween.TransitionType.Sine);
        drift.TweenProperty(clouds, "position:x", -70f, 18).SetTrans(Tween.TransitionType.Sine);
        Frames(_body, "早餐铺蒸汽动画", new(1600, 748, 120, 145), 1.1, true, .23f);
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
        var tab = Button(_body, name, "", new(1490, 195, 195, 92), action, bare: true);
        Art(tab, "旅行手账书签母版", new(0, 0, 195, 92));
        Text(tab, "Caption", caption, new(24, 18, 148, 52), 23, true);
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
            if (_save is not null && JourneyModel.Cities.All(c => JourneyModel.Progress(_save, c.Id).Completed))
                Art(_body, "中国阶段完成纪念章", new(480, 365, 360, 360));
            return;
        }
        int index = Array.FindIndex(JourneyModel.Cities, c => c.Id == next.Id);
        Vector2 at = MapPoints[index];
        var glow = Art(_body, "城市解锁轻光效", new(at + new Vector2(-10, -45), new Vector2(170, 160)));
        glow.PivotOffset = glow.Size / 2; glow.Scale = Vector2.One * .75f;
        var tween = CreateTween().SetParallel(); _tweens.Add(tween);
        tween.TweenProperty(glow, "scale", Vector2.One * 1.12f, 1.5);
        tween.TweenProperty(glow, "modulate:a", 0f, 1.2).SetDelay(.4);
        Frames(_body, "城市节点点亮星闪", new(at + new Vector2(85, -25), new Vector2(95, 95)), .4, false);
        Art(_body, "城市解锁小飘带", new(730, 140, 460, 95));
        Text(_body, "UnlockCaption", next.Name + "已开放", new(805, 165, 310, 44), 25, true);
    }
}
