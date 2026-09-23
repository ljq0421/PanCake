using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StartScreenSelfTest
{
    private async Task NewJourneyChecks(string directory)
    {
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        _save.UseSlotsForTests(Path.Combine(directory, "new-journey-slots"), ExperienceProfile.IsDemo);
        settings.SetReduceMotion(false);
        _screen.PresentHome(); await Frames();
        var newGame = Find<Button>("NewGame");
        newGame.EmitSignal(Button.SignalName.Pressed); newGame.EmitSignal(Button.SignalName.Pressed);
        await Frames();
        Check(_save.GetSlots().Count(s => s.Exists) == 1 && _screen.JourneyStage == FirstJourneyStage.Map, "new journey creates one slot and starts automatic map");
        Check(Find<Button>("SkipOpening").HasFocus(), "opening focuses skip");
        Check(!_screen.FindChildren("FirstStationTianjin", "Button", true, false).Any(), "automatic opening requires no Tianjin click");
        var cues = new List<OpeningCue>();
        _screen.GetNode<OpeningAudio>("OpeningAudio").Played += cue => cues.Add(cue);
        await JourneyCapture("opening-map");
        await Until(() => _screen.JourneyStage == FirstJourneyStage.Marker);
        await JourneyCapture("opening-marker");
        await Until(() => _screen.JourneyStage == FirstJourneyStage.Book);
        await JourneyCapture("opening-book");
        await Until(() => _screen.JourneyStage == FirstJourneyStage.Content);
        await JourneyCapture("opening-postcard");
        await Until(() => _screen.JourneyStage == FirstJourneyStage.Ready);
        await Delay(.5);
        Check(_screen.Page == JourneyPage.NewJourney && Find<Button>("Depart").HasFocus(), "automatic show ends ready to depart");
        Check(Find<BookFoodIcon>("BreakfastFood1").Size == new Vector2(118, 112)
            && Find<BookFoodIcon>("BreakfastFood2").Size == new Vector2(118, 112),
            "Tianjin youtiao and soy milk use the enlarged journey-page food scale");
        Check(Find<TextureRect>("BreakfastFood1Backing").Size.DistanceTo(new Vector2(208, 203)) < .01f
            && Find<TextureRect>("BreakfastFood2Backing").Size.DistanceTo(Find<TextureRect>("BreakfastFood0Backing").Size) < .01f,
            "Tianjin breakfast backings share the pancake illustration field in both editions");
        Check(Find<ColorRect>("NewJourneyBackdropShade").Color == new Color(.16f, .09f, .04f, .46f)
            && Find<ColorRect>("NewJourneyBackdropShade").GetIndex() < Find<Control>("SharedBook").GetIndex(),
            "Tianjin first-station book dims the restaurant backdrop beneath all page controls");
        Check(cues.SequenceEqual(new[] { OpeningCue.Locate, OpeningCue.Paper, OpeningCue.Postcard }), "material sounds play once in order");
        for (int i = 0; i < 3; i++)
        {
            Check(!string.IsNullOrWhiteSpace(Find<Label>("BreakfastStory" + i).Text), "culture copy visible " + i);
        }
        Check(!_screen.Descendants<Label>().Any(l => l.Name.ToString() is "BreakfastAvailability0" or "BreakfastPreviewHeading" or "DepartureHint"),
            "Tianjin entry omits day and preview copy");
        Check(Find<Label>("PostcardCity").Text == "天津" && Find<TextureRect>("TianjinSkyline").Texture is not null, "Tianjin destination and skyline visible");
        await JourneyCapture("new-journey-tianjin");
        settings.SetLanguage("en"); await Frames(); await JourneyCapture("new-journey-tianjin-en");
        settings.SetLanguage("zh_CN"); await Frames();
        KeyPress(Key.Escape); await Frames();
        Check(_screen.Page == JourneyPage.NewJourneyMap, "Escape opens static map");
        KeyPress(Key.Enter); await Frames();
        Check(_screen.Page == JourneyPage.NewJourney, "Enter reopens introduction without replay");
        KeyPress(Key.Tab); await Frames();
        Check(GetViewport().GuiGetFocusOwner() is Button focus && focus.Name != "Depart", "Tab moves focus");
        KeyPress(Key.Escape); await Frames();
        Check(_screen.Page == JourneyPage.NewJourneyMap, "Escape returns to static map");
        KeyPress(Key.Escape); await Frames();
        Check(_screen.Page == JourneyPage.Home, "map Escape returns home");
        await Click(Find<Button>("Continue"));
        Check(_screen.Page == JourneyPage.City, "continue retains latest city landing");

        foreach (float time in new[] { .225f, 1.425f, 2.325f, 3.225f })
        {
            _screen.PresentNewJourney(); await Delay(time);
            var skip = Find<Button>("SkipOpening");
            int beforeSkip = cues.Count;
            skip.EmitSignal(Button.SignalName.Pressed);
            Find<Button>("Depart").EmitSignal(Button.SignalName.Pressed);
            Check(_screen.Visible && _screen.JourneyStage == FirstJourneyStage.Ready, "skip cannot click through to business at " + time);
            await Delay(.7);
            Check(cues.Count == beforeSkip, "skip never replays omitted sounds at " + time);
            Check(_screen.Page == JourneyPage.NewJourney && _save.GetSlots().Count(s => s.Exists) == 1, "skip finishes layout without another save at " + time);
        }
        _screen.PresentNewJourney(); await Delay(.2);
        _screen.Notification((int)Node.NotificationApplicationFocusOut);
        var stage = _screen.JourneyStage;
        await Delay(.9);
        Check(_screen.JourneyStage == stage, "focus loss freezes opening");
        _screen.Notification((int)Node.NotificationApplicationFocusIn);
        Find<Button>("OpeningHome").EmitSignal(Button.SignalName.Pressed); await Delay(4.5);
        Check(_screen.Page == JourneyPage.Home, "leaving cancels all delayed opening steps");

        await Click(Find<Button>("Settings"));
        await Click(Find<Button>("ReduceMotion"));
        Check(settings.ReduceMotion && JourneyTransition.Reduced, "settings switch controls shared reduced motion");
        await JourneyCapture("new-journey-settings");
        KeyPress(Key.Escape); await Frames();
        settings.LoadPreferences();
        Check(settings.ReduceMotion, "reduced motion preference persists");
        _screen.PresentNewJourney(); await Delay(.3);
        Check(_screen.JourneyStage == FirstJourneyStage.Ready && _screen.Page == JourneyPage.NewJourney, "reduced opening goes directly to readable page");
        int sounds = 0;
        _screen.GetNode<OpeningAudio>("OpeningAudio").Played += _ => sounds++;
        settings.ToggleMute(); _screen.PresentNewJourney(); await Delay(.3);
        Check(sounds == 0, "muted opening produces no sound events");
        settings.ToggleMute(); settings.SetReduceMotion(false);

        _save.Data.UnlockedCityIds.Remove(StableIds.Cities.Tianjin);
        await Click(Find<Button>("Depart"));
        Check(_screen.Visible && _screen.JourneyStage == FirstJourneyStage.Ready && Find<Label>("Status").Text.Length > 0, "failed preparation remains retryable");
        _save.Data.UnlockedCityIds.Add(StableIds.Cities.Tianjin);
        var day = _main.GetNode<DayController>("DayController");
        var depart = Find<Button>("Depart");
        depart.EmitSignal(Button.SignalName.Pressed); depart.EmitSignal(Button.SignalName.Pressed);
        var transition = JourneyTransition.For(this);
        Check(transition.PaperDepartureActive && day.State == DayState.Preparing && day.IsPaused, "paper departure locks prepared business");
        day.SetPauseReason("departure-test-external", true);
        double openingClock = day.OpeningRemainingSeconds;
        await Delay(.22); await JourneyCapture("departure-covering");
        Check(day.State == DayState.Preparing && day.DayElapsedSeconds == 0 && day.OpeningRemainingSeconds == openingClock, "business and customers do not advance behind paper");
        transition.Notification((int)Node.NotificationApplicationFocusOut);
        await Delay(.7);
        Check(transition.PaperDepartureActive && day.State == DayState.Preparing, "departure waits while unfocused");
        transition.Notification((int)Node.NotificationApplicationFocusIn);
        await Delay(.35); await JourneyCapture("departure-revealing");
        Check(day.State == DayState.Preparing, "teaching waits until reveal completes");
        GetWindow().Size = new(_width - 32, (_width == 1280 ? 720 : 1080) - 18);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check(transition.PaperDepartureActive && day.State == DayState.Preparing, "resize does not prematurely start business");
        GetWindow().Size = new(_width, _width == 1280 ? 720 : 1080);
        await Until(() => !transition.Active);
        Check(!_screen.Visible && _main.GetNode<Control>("UI/TianjinDayScreen").Visible, "departure shows actual day one");
        Check(day.State != DayState.Preparing || day.TutorialActive, "day or first-day tutorial starts after reveal");
        Check(day.IsPaused, "departure retains other pause owners");
        day.SetPauseReason("departure-test-external", false);
        Check(_save.GetSlots().Count(s => s.Exists) == 1, "departure does not create a second save");
        await JourneyCapture("departure-workbench");
        Check(_main.OpenCity(StableIds.Cities.Tianjin), "return to isolated city for reduced departure");
        settings.SetReduceMotion(true);
        _screen.PresentNewJourney(); await Delay(.3);
        Find<Button>("Depart").EmitSignal(Button.SignalName.Pressed);
        Check(transition.PaperDepartureActive && day.State == DayState.Preparing, "reduced departure still protects preparation");
        await Until(() => !transition.Active);
        Check(!_screen.Visible && day.State != DayState.Preparing, "reduced departure starts after short fade");
        settings.SetReduceMotion(false);
        foreach (OpeningCue cue in Enum.GetValues<OpeningCue>())
        {
            var sound = OpeningAudio.Make(cue);
            var bytes = sound.Data;
            if (cue != OpeningCue.Locate)
            {
                string path = cue == OpeningCue.Click ? OpeningAudio.ClickPath : OpeningAudio.PaperPath;
                using var original = Godot.FileAccess.Open(path, Godot.FileAccess.ModeFlags.Read);
                original.Seek(44);
                Check(sound.ResourcePath == path && sound.MixRate == 44100
                    && sound.LoopMode == AudioStreamWav.LoopModeEnum.Disabled
                    && bytes.SequenceEqual(original.GetBuffer((long)original.GetLength() - 44)), cue + " preserves approved PCM without looping");
            }
            Check(bytes.Length > 0 && sound.GetLength() <= .60 && Enumerable.Range(0, bytes.Length / 2)
                .All(i => Math.Abs((int)BitConverter.ToInt16(bytes, i * 2)) < 32760), "sound is bounded and unclipped " + cue);
            if (_capture)
            {
                string audioRoot = ProjectSettings.GlobalizePath("res://.tmp/journey-opening/audio");
                Directory.CreateDirectory(audioRoot);
                Check(sound.SaveToWav(Path.Combine(audioRoot, cue + ".wav")) == Error.Ok, "export sound preview " + cue);
            }
            if (cue == OpeningCue.Locate) sound.Dispose();
        }
        _screen.PresentHome(); await Frames();
        cues.Clear(); _screen.PresentBreakfastCollection();
        Check(cues.SequenceEqual(new[] { OpeningCue.Paper }), "home book opens with one unified paper cue");
        _screen.PresentHome(); await Frames(); cues.Clear();
        _screen.PresentMap();
        Check(cues.SequenceEqual(new[] { OpeningCue.Paper }), "home page turn uses one unified paper cue");
        _screen.Hide();
        Check(_screen.GetNode<OpeningAudio>("OpeningAudio").GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing), "hiding home stops paper tail");

        async Task Delay(double seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
        async Task Until(Func<bool> condition)
        {
            ulong deadline = Time.GetTicksMsec() + 7000;
            while (!condition())
            {
                if (Time.GetTicksMsec() > deadline) throw new InvalidOperationException("new journey stage timed out: " + _screen.JourneyStage);
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            }
        }
    }

    private async Task JourneyCapture(string name)
    {
        if (!_capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string root = ProjectSettings.GlobalizePath($"res://.tmp/journey-opening/{_width}");
        Directory.CreateDirectory(root);
        Check(GetViewport().GetTexture().GetImage().SavePng(Path.Combine(root, name + ".png")) == Error.Ok, "capture " + name);
    }
}
