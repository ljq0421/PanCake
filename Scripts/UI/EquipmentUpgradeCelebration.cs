using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>A short, non-blocking opening cue, shared by the two supported cities.</summary>
public partial class EquipmentUpgradeCelebration : Control
{
    private sealed record Target(string Id, string Caption, Rect2 Bounds, bool Unlock = false);
    private bool _focused = true;
    private SaveService? _save;
    private DayController? _controller;
    private string _city = "";
    private readonly Dictionary<string, Target> _targets = new();
    private readonly Queue<Target> _queue = new();
    private Target? _current;
    private float _elapsed;
    private Func<bool> _active = () => false;
    private Label _caption = null!;
    private AudioStreamPlayer _audio = null!;
    private static AudioStreamWav? _chime;
    internal bool IsPlaying => _current is not null || _queue.Count > 0;
    internal string CurrentCaption => _caption.Text;
    internal int PlayedCount { get; private set; }
    internal bool AudioPlaying => _audio.Playing;
    private const float Duration = 3f;

    public static EquipmentUpgradeCelebration Attach(Control owner, Func<bool> active)
    {
        var effect = owner.GetNodeOrNull<EquipmentUpgradeCelebration>("UpgradeCelebration");
        if (effect is null)
        {
            effect = new() { Name = "UpgradeCelebration", MouseFilter = MouseFilterEnum.Ignore,
                Size = new(1920, 1080), ZIndex = 90 };
            owner.AddChild(effect);
            owner.VisibilityChanged += () => { if (!owner.IsVisibleInTree()) effect.Clear(); };
        }
        effect.Clear(); effect._active = active; effect.PlayedCount = 0;
        return effect;
    }

    public override void _Ready()
    {
        _caption = new Label { MouseFilter = MouseFilterEnum.Ignore, Size = new(620, 62),
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        _caption.AddThemeFontSizeOverride("font_size", 30);
        _caption.AddThemeColorOverride("font_color", new Color("fff0bd"));
        _caption.AddThemeColorOverride("font_outline_color", new Color("51351e"));
        _caption.AddThemeConstantOverride("outline_size", 8);
        AddChild(_caption);
        _audio = new AudioStreamPlayer { Bus = JourneySettings.EffectsBus, VolumeDb = -13,
            Stream = _chime ??= MakeChime() };
        AddChild(_audio); Hide();
    }

    public bool Begin(SaveService save, DayController controller, out string error)
    {
        Clear(); error = ""; _save = save; _controller = controller; _targets.Clear();
        if (controller.TutorialActive || controller.State != DayState.Running) return true;
        string city = controller.CurrentConfig!.CityId; _city = city;
        var targets = new List<Target>();
        if (city == StableIds.Cities.Tianjin)
        {
            targets.Add(new("pancake_stove", "煎饼炉", TianjinWorkbenchLayout.EmbeddedSurface));
            targets.Add(new("ingredient_station", "配料台", TianjinWorkbenchLayout.FromSource(953, 542, 522, 266)));
            if (controller.CurrentConfig.AvailableProductKinds.Contains(ProductKind.Youtiao))
                targets.Add(new("fryer", "油条锅", TianjinWorkbenchLayout.EmbeddedOpening));
        }
        else if (city == StableIds.Cities.Wuhan)
        {
            bool doupi = save.Data.Wuhan.EquipmentLevels.GetValueOrDefault("doupi_griddle") > 0;
            var layout = WuhanWorkbenchLayout.ForStage(doupi);
            targets.Add(new("noodle_cooker", "煮面锅", layout.Cooker));
            if (doupi) targets.Add(new("doupi_griddle", "豆皮锅", layout.Pan));
        }
        foreach (var target in targets) _targets[target.Id] = target;
        foreach (var item in DayUnlockPresentation.ForDay(GetNode<DataCatalog>("/root/DataCatalog"), controller.CurrentConfig!))
            _queue.Enqueue(new(item.Id, "新解锁：" + item.Name, item.Bounds, true));
        return true;
    }

    /// <summary>Called only after an accepted gameplay operation. Opening a shift never consumes a cue.</summary>
    public void NotifyUse(string equipmentId, Rect2? bounds = null)
    {
        if (!_active() || _controller?.TutorialActive != false || _save is null
            || !_targets.TryGetValue(equipmentId, out var target)
            || !_save.Data.GetCity(_city).PendingUpgradeCelebrations.ContainsKey(equipmentId)
            || (_current is { Unlock: false } && _current.Id == equipmentId)
            || _queue.Any(t => !t.Unlock && t.Id == equipmentId)) return;
        _queue.Enqueue(target with { Bounds = bounds ?? target.Bounds });
    }

    public override void _Process(double delta)
    {
        if (!IsPlaying) return;
        if (_controller?.CurrentConfig?.CityId != _city || _controller.State != DayState.Running) { Clear(); return; }
        if (!_focused || !_active()) { _audio.Stop(); Hide(); return; }
        if (_current is not null) Show();
        if (_current is null)
        {
            var target = _queue.Dequeue();
            string caption = target.Caption;
            if (!target.Unlock)
            {
                if (_save is null || !_save.TryConsumeUpgradeCelebrations(_city, new[] { target.Id }, out var upgrades, out _)
                    || !upgrades.TryGetValue(target.Id, out int level)) return;
                caption = EquipmentUpgradePresentation.FirstUse(target.Id, level);
            }
            _current = target; _elapsed = 0;
            _caption.Text = caption; Show();
            _audio.Play(); PlayedCount++;
        }
        _elapsed += (float)delta;
        if (_elapsed >= Duration)
        {
            _current = null; Hide(); QueueRedraw(); return;
        }
        float alpha = Mathf.Min(1, _elapsed / .12f) * Mathf.Clamp((Duration - _elapsed) / .35f, 0, 1);
        _caption.Modulate = new(1, 1, 1, alpha);
        var rect = _current.Bounds;
        _caption.Position = new(Mathf.Clamp(rect.GetCenter().X - 310, 20, 1280),
            Math.Max(8, rect.Position.Y - 62 - (ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool() ? 0 : 18 * (1 - Mathf.Exp(-_elapsed * 4)))));
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_current is null) return;
        float p = ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool() ? 1 : _elapsed / Duration;
        float alpha = Mathf.Min(1, _elapsed / .12f) * Mathf.Clamp((Duration - _elapsed) / .4f, 0, 1);
        var rect = _current.Bounds;
        Vector2 center = rect.GetCenter();
        Vector2 radius = rect.Size * (.48f + .06f * (1 - Mathf.Exp(-p * 7)));
        var points = Enumerable.Range(0, 81).Select(i => center + new Vector2(
            Mathf.Cos(i * Mathf.Tau / 80) * radius.X, Mathf.Sin(i * Mathf.Tau / 80) * radius.Y)).ToArray();
        DrawPolyline(points, new Color(1, .69f, .22f, alpha * .12f), 18, true);
        DrawPolyline(points, new Color(1, .77f, .32f, alpha * .35f), 8, true);
        DrawPolyline(points, new Color(1, .89f, .55f, alpha * .95f), 2.5f, true);
        if (ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool()) return;
        for (int i = 0; i < 9; i++)
        {
            float angle = i * Mathf.Tau / 9 - .3f;
            Vector2 at = center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius * (1 + p * .13f);
            float size = (5 + 4 * Mathf.Pow(Mathf.Sin(p * Mathf.Pi), 2)) * (i % 2 == 0 ? 1 : .7f);
            Vector2[] star = { at + new Vector2(0, -size), at + new Vector2(size * .26f, -size * .26f),
                at + new Vector2(size, 0), at + new Vector2(size * .26f, size * .26f), at + new Vector2(0, size),
                at + new Vector2(-size * .26f, size * .26f), at + new Vector2(-size, 0), at + new Vector2(-size * .26f, -size * .26f) };
            DrawColoredPolygon(star, new Color(1, .91f, .62f, alpha));
        }
    }

    public void Clear()
    {
        _queue.Clear(); _current = null; _audio?.Stop(); Hide(); QueueRedraw();
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) { _focused = false; _audio?.Stop(); Hide(); }
        if (what == NotificationApplicationFocusIn) _focused = true;
    }
    public override void _ExitTree() => _audio?.Stop();

    internal static AudioStreamWav MakeChime()
    {
        const int rate = 22050;
        double[] notes = { 783.99, 987.77, 1174.66, 1567.98 };
        byte[] data = new byte[(int)(rate * .62) * 2];
        for (int i = 0; i < data.Length / 2; i++)
        {
            double value = 0, t = i / (double)rate;
            for (int n = 0; n < notes.Length; n++)
            {
                double local = t - n * .075;
                if (local < 0 || local > .38) continue;
                double envelope = Math.Min(1, local / .006) * Math.Exp(-local * 15) * Math.Min(1, (.38 - local) / .035);
                double phase = Math.Tau * notes[n] * local;
                value += (Math.Sin(phase) + .18 * Math.Sin(phase * 2)) * envelope * .25;
            }
            short sample = (short)(Math.Clamp(value, -1, 1) * short.MaxValue);
            data[i * 2] = (byte)(sample & 255); data[i * 2 + 1] = (byte)(sample >> 8);
        }
        return new() { Format = AudioStreamWav.FormatEnum.Format16Bits, MixRate = rate, Data = data };
    }
}
