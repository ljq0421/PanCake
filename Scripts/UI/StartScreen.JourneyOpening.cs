using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

public enum FirstJourneyStage { None, Map, Marker, Book, Content, Ready, Departing }

public partial class StartScreen
{
    public event Action? FirstStationDepartureRequested;
    public FirstJourneyStage JourneyStage { get; private set; }
    private Tween? _openingTween;
    private OpeningAudio? _openingAudio;
    private bool _openingActive, _openingPaused, _journeyInputPending;
    private int _releasedFrames;
    private float _openingTime;
    private Control? _openingSource, _openingMap, _openingMarker, _openingHalo, _openingCover, _openingSheet;
    private readonly Dictionary<Control, Vector2> _introPositions = new();
    private readonly Dictionary<Control, Color> _introColors = new();
    private readonly HashSet<OpeningCue> _openingCues = new();

    public void PresentNewJourney()
    {
        // Keep the actual outgoing controls so the home map can take over without a page cut.
        bool fromHome = Page == JourneyPage.Home;
        var source = new Control { Name = "OpeningSource", Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Ignore };
        foreach (Control child in _body.GetChildren().OfType<Control>().ToArray())
        {
            _body.RemoveChild(child); source.AddChild(child);
            if (fromHome && (child.Name == "HomeMap" || child is TextureRect && child.Position.IsEqualApprox(new(445, 100))))
                child.Hide();
        }
        foreach (var button in source.Descendants<Button>()) button.Disabled = true;
        _city = StableIds.Cities.Tianjin;
        Show();
        RenderTianjinIntroduction(opening: true);
        _openingSource = source; _body.AddChild(source);
        _introPositions.Clear();
        foreach (var control in _body.GetChildren().OfType<Control>())
            if (control != source && control.Name != "Status")
            { _introPositions[control] = control.Position; _introColors[control] = control.Modulate; }
        BuildOpeningMap();
        _body.MoveChild(_openingMap!, 0);
        _openingCover = HomeArt(_body, "闭合旅行手账封面｜新旅程入口", new(685, 210, 540, 690));
        _openingSheet = new ColorRect { Name = "OpeningPaper", Position = new(900, 225), Size = new(32, 625),
            Color = new Color("#FFF5DF"), MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(_openingSheet);
        Button(_body, "SkipOpening", "跳过演出", new(1515, 55, 290, 64), () => CompleteJourneyOpening(true));
        Button(_body, "OpeningHome", "返回首页", new(72, 48, 220, 64), RenderHome, bare: true);
        _openingCues.Clear(); _openingActive = true; _openingPaused = false; _openingTime = 0;
        _journeyInputPending = false; JourneyStage = FirstJourneyStage.Map;
        OpeningSound(OpeningCue.Click);
        if (JourneyTransition.Reduced)
        {
            CompleteJourneyOpening(true);
            _body.Modulate = new(1, 1, 1, 0);
            var fade = CreateTween(); _tweens.Add(fade); fade.TweenProperty(_body, "modulate:a", 1f, .2);
            return;
        }
        ApplyOpeningTime(0);
        _openingTween = CreateTween();
        // Stretch the shared timeline so visuals, cues and input unlock stay synchronized.
        _openingTween.TweenMethod(Callable.From<float>(ApplyOpeningTime), 0f, 2.8f, 4.2);
        _openingTween.TweenCallback(Callable.From(() => CompleteJourneyOpening(false)));
        Focus("SkipOpening");
    }

    private void BuildOpeningMap()
    {
        _openingMap = new Control { Name = "FirstStationMap", Size = new(1080, 640), Position = new(445, 100), MouseFilter = MouseFilterEnum.Ignore };
        _body.AddChild(_openingMap);
        HomeArt(_openingMap, "世界地图墙挂底板", new(0, 0, 1080, 640), stretch: true);
        HomeArt(_openingMap, "卡通世界地图母版", new(45, 105, 990, 470), stretch: true).Name = "OpeningWorldMapArt";
        _openingMarker = new Control { Name = "FirstStationMarker", Position = new(752, 160), Size = new(130, 145),
            PivotOffset = new(65, 70), MouseFilter = MouseFilterEnum.Ignore };
        _openingMap.AddChild(_openingMarker);
        _openingHalo = HomeArt(_openingMarker, "城市节点悬停高亮环", new(-8, -12, 146, 118));
        _openingHalo.PivotOffset = _openingHalo.Size / 2;
        HomeArt(_openingMarker, "第一站天津节点专属素材", new(18, 0, 94, 90));
        var title = Text(_openingMarker, "FirstStationTitle", "第一站 · 天津", new(-55, 96, 240, 40), 25, true);
        title.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
        title.AddThemeConstantOverride("outline_size", 4);
    }

    private static float Beat(float time, float start, float duration) => Mathf.Clamp((time - start) / duration, 0, 1);
    private static float Ease(float value) => 1 - Mathf.Pow(1 - value, 3);
    private static void Opacity(Control control, float alpha) => control.Modulate = new(1, 1, 1, alpha);

    private void ApplyOpeningTime(float time)
    {
        _openingTime = time;
        float move = Ease(Beat(time, .1f, .8f));
        _openingMap!.Position = new Vector2(445, 100).Lerp(new(247, 130), move);
        _openingMap.Scale = Vector2.One * Mathf.Lerp(1, 1.32f, move);
        Opacity(_openingMap, 1 - Beat(time, 1.4f, .6f));
        if (_openingSource is not null)
        {
            Opacity(_openingSource, 1 - Beat(time, .1f, .55f));
            var pressed = _openingSource.FindChild("NewGame", true, false) as Control;
            if (pressed is not null)
            {
                pressed.PivotOffset = pressed.Size / 2;
                pressed.Scale = time < .1f ? Vector2.One.Lerp(new(1.02f, .96f), Beat(time, 0, .1f))
                    : time < .18f ? new Vector2(1.02f, .96f).Lerp(new(.99f, 1.02f), Beat(time, .1f, .08f))
                    : new Vector2(.99f, 1.02f).Lerp(Vector2.One, Beat(time, .18f, .07f));
            }
        }
        float drop = Ease(Beat(time, .8f, .3f));
        _openingMarker!.Position = new(752, 160 - 24 * (1 - drop));
        Opacity(_openingMarker, Beat(time, .8f, .15f));
        float squash = Mathf.Sin(Beat(time, 1.08f, .22f) * Mathf.Pi);
        _openingMarker.Scale = new(1 + .035f * squash, 1 - .055f * squash);
        _openingHalo!.Scale = Vector2.One * (1 + .45f * Beat(time, 1.05f, .35f));
        Opacity(_openingHalo, Beat(time, .95f, .1f) * (1 - Beat(time, 1.05f, .35f)));
        float book = Ease(Beat(time, 1.3f, .7f));
        foreach (var (control, position) in _introPositions)
        {
            string name = control.Name;
            bool isBook = name == "SharedBook";
            bool postcard = name is "JourneyPostcard" or "StationTitle" or "IntroductionTitleBacking";
            bool depart = name == "Depart";
            float progress = isBook ? book : Ease(Beat(time, postcard ? 1.9f : depart ? 2.3f : 2.05f, depart ? .4f : .5f));
            var color = _introColors[control];
            control.Modulate = new(color.R, color.G, color.B, color.A * progress);
            control.Position = position + new Vector2(0, isBook ? 32 * (1 - book) : postcard ? -18 * (1 - progress) : 10 * (1 - progress));
            if (name == "JourneyPostcard") { control.PivotOffset = control.Size / 2; control.RotationDegrees = (_save?.IsDemo == true ? -3 : 0) - 2 * (1 - progress); }
            if (control is Button button) button.Disabled = time < 2.5f;
        }
        _openingCover!.Position = new(685, 210 + 32 * (1 - book));
        Opacity(_openingCover, Beat(time, 1.3f, .15f) * (1 - Beat(time, 1.5f, .35f)));
        _openingSheet!.Position = new(1510 - 1150 * Ease(Beat(time, 1.5f, .45f)), 225);
        Opacity(_openingSheet, Mathf.Sin(Beat(time, 1.5f, .45f) * Mathf.Pi) * .8f);
        if (time >= .8f) CueOnce(OpeningCue.Locate);
        if (time >= 1.3f) CueOnce(OpeningCue.Paper);
        if (time >= 1.9f) CueOnce(OpeningCue.Postcard);
        JourneyStage = time < .8f ? FirstJourneyStage.Map : time < 1.3f ? FirstJourneyStage.Marker
            : time < 1.9f ? FirstJourneyStage.Book : time < 2.5f ? FirstJourneyStage.Content : FirstJourneyStage.Ready;
        if (time >= 2.5f) EnableJourneyReading();
    }

    private void EnableJourneyReading()
    {
        if (Page == JourneyPage.NewJourney) return;
        Page = JourneyPage.NewJourney;
        foreach (string name in new[] { "SkipOpening", "OpeningHome" }) _body.GetNodeOrNull<Control>(name)?.Hide();
        NavigationUtilities(includeHome: true);
        _journeyInputPending = true; _releasedFrames = 0;
        Focus("Depart");
    }

    private void CompleteJourneyOpening(bool skipped)
    {
        if (!_openingActive) return;
        _openingTween?.Kill(); _openingTween = null;
        if (skipped)
        {
            _openingAudio?.Stop();
            foreach (OpeningCue cue in Enum.GetValues<OpeningCue>()) _openingCues.Add(cue);
        }
        ApplyOpeningTime(2.8f);
        _openingActive = false;
        _openingSource?.QueueFree(); _openingSource = null;
        _openingMap?.Hide(); _openingCover?.Hide(); _openingSheet?.Hide();
        _introPositions.Clear(); _introColors.Clear();
    }

    private void RenderNewJourneyMap()
    {
        Begin(JourneyPage.NewJourneyMap);
        Chrome(RenderHome, showBack: false);
        BuildOpeningMap();
        _openingMap!.Position = new(247, 130); _openingMap.Scale = new(1.32f, 1.32f);
        _openingHalo!.Hide();
        var node = Button(_openingMap, "FirstStationTianjin", "", new(727, 150, 180, 165), () => RenderTianjinIntroduction(), bare: true);
        Focus("FirstStationTianjin");
    }

    private void CueOnce(OpeningCue cue) { if (_openingCues.Add(cue)) OpeningSound(cue); }
    private void OpeningSound(OpeningCue cue)
    {
        if (_openingPaused) return;
        if (_openingAudio is null) { _openingAudio = new OpeningAudio { Name = "OpeningAudio" }; AddChild(_openingAudio); }
        _openingAudio.Play(cue);
    }
    private void CancelJourneyOpening()
    {
        _openingTween?.Kill(); _openingTween = null; _openingActive = false;
        _openingAudio?.Stop(); _introPositions.Clear(); _introColors.Clear(); _openingSource = null;
        _journeyInputPending = false; JourneyStage = FirstJourneyStage.None;
    }
    public override void _Process(double delta)
    {
        if (_journeyInputPending && !Input.IsAnythingPressed()) { if (++_releasedFrames >= 2) _journeyInputPending = false; }
        else if (_journeyInputPending) _releasedFrames = 0;
        if (_openingActive && JourneyTransition.Reduced) CompleteJourneyOpening(true);
    }
    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut)
        { _openingPaused = true; _openingTween?.Pause(); _openingAudio?.Stop(); }
        else if (what == NotificationApplicationFocusIn)
        { _openingPaused = false; if (_openingActive) _openingTween?.Play(); }
    }
}
