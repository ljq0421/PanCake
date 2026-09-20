using Godot;

namespace ProjectCake.UI;

/// <summary>One owner per visual property; hit controls and business state stay untouched.</summary>
public partial class TianjinLoopMotion : Node
{
    public Func<bool> Active { get; set; } = () => true;
    private sealed class Visual
    {
        public required Control Art;
        public required Func<int> State;
        public Vector2 Rest;
        public int Last = -1;
        public Tween? Tween;
    }
    private readonly List<Visual> _visuals = new();
    private readonly List<(Control Art, Tween Tween)> _flights = new();
    private readonly List<Tween> _contacts = new();
    public void Contact(Action action, double delay = .11)
    {
        if (!Active()) return;
        if (Reduced) { action(); return; }
        var tween = CreateTween();
        _contacts.Add(tween);
        tween.TweenInterval(delay);
        tween.Finished += () => { _contacts.Remove(tween); if (Active()) action(); };
    }
    public static bool Reduced => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();

    public void Bind(Control art, Func<int>? state = null)
    {
        if (_visuals.Any(v => v.Art == art)) return;
        _visuals.Add(new Visual { Art = art, Rest = art.Scale, State = state ?? (() => 0) });
    }

    public override void _Process(double delta)
    {
        if (!Active() || Reduced) { Reset(); return; }
        _visuals.RemoveAll(v => !GodotObject.IsInstanceValid(v.Art));
        foreach (var visual in _visuals)
        {
            if (!GodotObject.IsInstanceValid(visual.Art)) continue;
            int state = visual.Art.IsVisibleInTree() ? visual.State() : 0;
            if (state == visual.Last) continue;
            visual.Last = state;
            visual.Tween?.Kill();
            visual.Art.PivotOffset = new Vector2(visual.Art.Size.X / 2, visual.Art.Size.Y);
            visual.Tween = CreateTween().SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
            Vector2 factor = state == 2 ? new(1.025f, .9756f) : state == 1 ? new(1.02f, 1.02f) : Vector2.One;
            visual.Tween.TweenProperty(visual.Art, "scale", visual.Rest * factor, state == 2 ? .05 : .10);
        }
    }

    public void Land(Control art, float strength = .07f)
    {
        Bind(art);
        var visual = _visuals.First(v => v.Art == art);
        visual.Tween?.Kill();
        if (Reduced || !Active()) { art.Scale = visual.Rest; return; }
        visual.Last = visual.State();
        art.PivotOffset = new Vector2(art.Size.X / 2, art.Size.Y);
        float width = 1 + strength;
        float rebound = 1 - strength * .6f;
        visual.Tween = CreateTween().SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        visual.Tween.TweenProperty(art, "scale", visual.Rest * new Vector2(width, 1 / width), .055);
        visual.Tween.TweenProperty(art, "scale", visual.Rest * new Vector2(rebound, 1 / rebound), .085);
        visual.Tween.TweenProperty(art, "scale", visual.Rest, .14);
    }

    public void Fly(Control parent, Texture2D texture, Vector2 from, Vector2 to, Vector2 size, Action contact)
    {
        if (!Active()) return;
        if (Reduced) { contact(); return; }
        var art = new TextureRect { Name = "IngredientFlight", Texture = texture,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            MouseFilter = Control.MouseFilterEnum.Ignore, ZIndex = 85, Size = size };
        parent.AddChild(art);
        art.Size = size;
        art.Position = parent.GetGlobalTransform().AffineInverse() * from - size / 2;
        var tween = CreateTween().SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
        tween.TweenProperty(art, "position", parent.GetGlobalTransform().AffineInverse() * to - size / 2, .11);
        _flights.Add((art, tween));
        tween.Finished += () => { _flights.RemoveAll(f => f.Art == art); art.QueueFree(); if (Active()) contact(); };
        if (_flights.Count > 6) { var old = _flights[0]; old.Tween.Kill(); old.Art.QueueFree(); _flights.RemoveAt(0); }
    }

    public void Reset()
    {
        foreach (var visual in _visuals)
        {
            visual.Tween?.Kill(); visual.Tween = null; visual.Last = -1;
            if (GodotObject.IsInstanceValid(visual.Art)) visual.Art.Scale = visual.Rest;
        }
        foreach (var flight in _flights) { flight.Tween.Kill(); flight.Art.QueueFree(); }
        _flights.Clear();
        foreach (var contact in _contacts) contact.Kill();
        _contacts.Clear();
    }
    public void CrackEgg(Control parent, Texture2D egg, Texture2D shell, Vector2 from, Vector2 to, Action contact)
    {
        if (!Active()) return;
        if (Reduced) { contact(); return; }
        var root = new Control { Name = "EggCrack", MouseFilter = Control.MouseFilterEnum.Ignore, ZIndex = 85 };
        parent.AddChild(root);
        Transform2D inverse = parent.GetGlobalTransform().AffineInverse();
        root.Position = inverse * from;
        TextureRect Art(Texture2D texture, Vector2 size)
        {
            var art = new TextureRect { Texture = texture, Position = -size / 2,
                PivotOffset = size / 2, ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, MouseFilter = Control.MouseFilterEnum.Ignore, Size = size };
            root.AddChild(art); art.Size = size; return art;
        }
        var whole = Art(egg, new(36, 44));
        var left = Art(shell, new(27, 26)); left.Hide();
        var right = Art(shell, new(27, 26)); right.FlipH = true; right.Hide();
        Vector2 above = inverse * to - new Vector2(0, 35);
        var tween = CreateTween();
        _flights.Add((root, tween));
        tween.TweenProperty(root, "position", above, .14).SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
        tween.TweenCallback(Callable.From(() => { whole.Hide(); left.Show(); right.Show(); }));
        tween.TweenProperty(left, "position", left.Position + new Vector2(-13, -8), .10);
        tween.Parallel().TweenProperty(right, "position", right.Position + new Vector2(13, -8), .10);
        tween.Parallel().TweenProperty(left, "rotation_degrees", -15f, .10);
        tween.Parallel().TweenProperty(right, "rotation_degrees", 15f, .10);
        tween.TweenProperty(root, "modulate:a", 0f, .08);
        Contact(contact, .20);
        tween.Finished += () => { _flights.RemoveAll(f => f.Art == root); root.QueueFree(); };
    }
    public override void _ExitTree() => Reset();
}
