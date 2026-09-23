using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using System.Reflection;

namespace ProjectCake.Tests;

public partial class BusinessBookSelfTest
{
    // Run with --fixed-fps 30 and Godot's --write-movie to record the real viewport timeline.
    private async Task PreviewTravelMotion(string city)
    {
        if (city is not ("tianjin" or "wuhan")) throw new ArgumentException("Unsupported preview city", nameof(city));
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
        GetWindow().ContentScaleAspect = Window.ContentScaleAspectEnum.Expand;
        GetWindow().Size = new(1280, 720);
        var view = new BusinessDetailsView(); AddChild(view);
        var fixture = Fixture(city);
        await Frames(8);
        view.Open(new BusinessBookModel
        {
            CityId = city, Closing = true, Orders = fixture.Orders,
            Result = new() { Day = 3, SaleRevenue = 40, Tips = 5, CompletedCustomers = 4,
                LostCustomers = 1, PerfectOrders = 2, Satisfaction = 93 }
        });
        await Frames(140);
        view.QueueFree();
    }

    private static T MotionField<T>(BusinessDetailsView view, string name) =>
        (T)typeof(BusinessDetailsView).GetField(name, BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(view)!;

    private static Tween PauseMotion(BusinessDetailsView view)
    {
        var tween = MotionField<Tween>(view, "_entrance");
        tween.Pause();
        JourneyTransition.For(view).Finish();
        return tween;
    }

    private static void StepMotion(Tween tween, double seconds)
    {
        // Advance actual Godot tweeners in small increments, independent of machine speed.
        while (seconds > .000001)
        {
            double step = Math.Min(.01, seconds);
            if (!tween.CustomStep(step)) break;
            seconds -= step;
        }
    }

    private async Task CheckTravelMotion(DataCatalog catalog)
    {
        bool reduced = ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();
        string locale = TranslationServer.GetLocale();
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
        var view = new BusinessDetailsView(); AddChild(view);
        Label Income() => MotionField<Label>(view, "_income");
        Control Note() => MotionField<Control>(view, "_note");
        Label Caption(string text) => view.Descendants<Label>().Single(l => l.Text == text);
        void Complete(string context)
        {
            Check(Income().Text == $"¥{view.Model.Result.TotalRevenue + view.Model.ChallengeReward}" && Income().Modulate.A == 1
                && Income().Scale == Vector2.One && Note().Modulate.A == 1
                && Note().Position == new Vector2(230, 424), context + " restores exact final values and transforms");
        }
        try
        {
            foreach (string city in new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" })
            {
                bool travel = city is "tianjin" or "wuhan";
                var soundModel = new BusinessBookModel
                {
                    CityId = city, Closing = true,
                    Result = new() { SaleRevenue = 40, CompletedCustomers = 1 },
                    ChallengeReward = travel ? 20 : 0
                };
                view.Open(soundModel);
                var soundTween = PauseMotion(view);
                var sound = view.GetNodeOrNull<AudioStreamPlayer>("IncomeCountAudio");
                Check(sound?.Playing != true, city + " silent before income count");
                StepMotion(soundTween, travel ? 1.60 : .75);
                sound = view.GetNodeOrNull<AudioStreamPlayer>("IncomeCountAudio");
                Check(sound?.Playing == true && sound.Bus == JourneySettings.EffectsBus,
                    city + " income count plays on effects bus");
                if (travel)
                {
                    StepMotion(soundTween, .25);
                    Check(!sound!.Playing, city + " base income sound ends with count");
                    StepMotion(soundTween, .16);
                    Check(sound.Playing, city + " challenge reward count plays sound");
                }
                view._Notification((int)NotificationApplicationFocusOut);
                Check(!sound!.Playing, city + " focus loss stops counting sound");
                StepMotion(soundTween, .03);
                Check(!sound.Playing, city + " unfocused count stays silent");
                view._Notification((int)NotificationApplicationFocusIn);
                view.FinishAnimation();
                Check(!sound.Playing, city + " skip stops counting sound");

                view.Open(soundModel); soundTween = PauseMotion(view);
                StepMotion(soundTween, travel ? 1.60 : .75);
                view.Hide();
                Check(!sound.Playing, city + " closing stops counting sound");
                view.Open(new() { CityId = city, Closing = true });
                soundTween = PauseMotion(view);
                StepMotion(soundTween, travel ? 1.60 : .75);
                Check(!sound.Playing, city + " zero income stays silent");
                view.FinishAnimation();
                ProjectSettings.SetSetting("accessibility/reduce_motion", true);
                view.Open(soundModel);
                Check(!sound.Playing, city + " static income stays silent");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            }
            foreach (string city in new[] { "tianjin", "wuhan" })
            {
                var fixture = Fixture(city);
                var model = new BusinessBookModel
                {
                    CityId = city, Closing = true, Orders = fixture.Orders,
                    Result = new() { Day = 3, SaleRevenue = 40, Tips = 5, CompletedCustomers = 4,
                        LostCustomers = 1, PerfectOrders = 2, Satisfaction = 93 },
                    Challenge = new DailyChallenge(city, 3, DailyChallengeKind.Perfect, 1, 20),
                    ChallengeReward = 20
                };
                foreach (var size in Capture ? CaptureSizes : CaptureSizes.Take(1))
                {
                    GetWindow().ContentScaleAspect = Window.ContentScaleAspectEnum.Expand;
                    GetWindow().Size = size; await Frames(5);
                    view.Open(model);
                    var tween = PauseMotion(view);
                    var incomePosition = Income().Position;
                    Check(Income().Modulate.A == 0 && Note().Modulate.A == 0
                        && view.Descendants<Label>().Single(l => l.Name == "ChallengeSettlement").Modulate.A == 0, "results hidden before first frame");
                    Check(Caption("今日收入").Modulate.A == 1 && Caption("今日接待").Modulate.A == 1
                        && !view.CloseButton.Disabled, "headings and actions are available from opening");
                    Check(view.Descendants<Label>().Any(l => l.Text == "挑战奖金")
                        && view.Descendants<Label>().Any(l => l.Text == "+¥20"), "income detail includes challenge reward");
                    if (Capture) await Shot($"motion-{city}-{size.X}-0-open");
                    StepMotion(tween, .52 + .62);
                    Check(Caption("今日接待").Modulate.A == 1 && Caption("93%").Modulate.A == 1
                        && Income().Modulate.A == 0, "reception and satisfaction precede income");
                    if (Capture) await Shot($"motion-{city}-{size.X}-1-reception");
                    StepMotion(tween, .45);
                    Check(Income().Modulate.A == 1 && Income().Text != "¥0", "income follows service reflection");
                    if (Capture) await Shot($"motion-{city}-{size.X}-2-evaluation");
                    StepMotion(tween, .25);
                    Check(view.Descendants<Label>().Single(l => l.Name == "ChallengeSettlement").Modulate.A == 1
                        && Note().Modulate.A <= 1, "challenge result follows income");
                    if (Capture) await Shot($"motion-{city}-{size.X}-3-review");
                    Check(Income().Scale == Vector2.One, "counting amount stays at resting scale");
                    StepMotion(tween, .62);
                    Check(Income().Text == "¥65" && Income().Scale.X > 1.17f
                        && Note().Modulate.A == 0, "exact final income is enlarged before the note appears");
                    if (Capture) await Shot($"motion-{city}-{size.X}-income-emphasis");
                    StepMotion(tween, .70);
                    Complete(city + " natural completion");
                    Check(Income().Position == incomePosition, "income count leaves its layout fixed");
                    if (Capture) await Shot($"motion-{city}-{size.X}-4-complete");

                    if (Capture)
                    {
                        // Also run uninterrupted, using the actual frame clock and opening transition.
                        view.Hide(); await Frames(); view.Open(model);
                        await ToSignal(GetTree().CreateTimer(3.25), SceneTreeTimer.SignalName.Timeout);
                        Complete(city + " realtime playback");
                        await Shot($"motion-{city}-{size.X}-realtime");
                        CheckMotionInk(Caption("93%"));
                        CheckMotionInk(Caption("今日接待"));
                    }
                }
                // Include interruption during the final-income emphasis and its return.
                foreach (double moment in new[] { .1, .7, 1.1, 1.6, 2.3, 2.6 })
                {
                    view.Open(model); var tween = PauseMotion(view); StepMotion(tween, moment);
                    Check(MotionField<bool>(view, "_travelAnimating"), "skip input occurs during reveal");
                    bool closed = false;
                    void Closed() => closed = true;
                    view.CloseRequested += Closed;
                    view.CloseButton.GrabFocus();
                    foreach (bool pressed in new[] { true, false })
                        GetViewport().PushInput(new InputEventKey { Keycode = Key.Space, Pressed = pressed }, true);
                    Complete("Space at " + moment);
                    Check(!tween.IsValid(), "skip kills pending tween callbacks");
                    Check(!closed && view.Visible, "skip Space never activates focused close button");
                    view.CloseRequested -= Closed;
                    await Frames(); Complete("skip remains stable");
                }
                view.Open(model); PauseMotion(view);
                foreach (bool pressed in new[] { true, false })
                    GetViewport().PushInput(new InputEventMouseButton { Position = new(10, 10), GlobalPosition = new(10, 10),
                        ButtonIndex = MouseButton.Left, Pressed = pressed }, true);
                Complete("blank click");
                view.Open(model); PauseMotion(view);
                Click(view.Descendants<Button>().Single(b => b.Name == "NextBookPage"));
                Check(view.DetailVisible, "navigation works during reveal");
                view.SelectPage(false, false); Complete("return from details does not replay");
                view.Open(model); PauseMotion(view); view.Hide(); Complete("hide cleanup");
                await Frames(); view.Open(model); PauseMotion(view); view.FinishAnimation(); Complete("reopen cleanup");

                foreach (var result in new[]
                {
                    new DayResult { SaleRevenue = 40, CompletedCustomers = 1 },
                    new DayResult(),
                    new DayResult { SaleRevenue = 1000000000, Tips = 1000000000, CompletedCustomers = 1 }
                })
                {
                    view.Open(new() { CityId = city, Closing = true, Result = result });
                    var tween = PauseMotion(view);
                    StepMotion(tween, 3.1);
                    Complete("edge revenue " + result.TotalRevenue);
                    Check(!MotionField<bool>(view, "_travelAnimating"), "result timeline completes");
                    await Frames();
                }
                model.Closing = false;
                model.ChallengeReward = 0;
                view.Open(model);
                var liveTween = PauseMotion(view);
                Check(Income().Modulate.A == 0 && Note().Modulate.A == 0,
                    "live summary starts with results hidden");
                StepMotion(liveTween, 1.14);
                Check(Caption("93%").Modulate.A == 1 && Income().Modulate.A == 0,
                    "live summary reveals reception and evaluation before income");
                if (Capture) await Shot($"motion-{city}-live-reception");
                StepMotion(liveTween, .45);
                Check(Income().Modulate.A == 1 && Income().Text != "¥0" && Note().Modulate.A == 0,
                    "live summary counts income before revealing note");
                if (Capture) await Shot($"motion-{city}-live-income");
                StepMotion(liveTween, 1.6);
                Complete("live summary natural completion");
                if (Capture) await Shot($"motion-{city}-live-complete");
                view.Hide(); await Frames(); view.Open(model); PauseMotion(view);
                Check(Income().Modulate.A == 0, "reopening live summary replays reveal");
                foreach (bool pressed in new[] { true, false })
                    GetViewport().PushInput(new InputEventKey { Keycode = Key.Space, Pressed = pressed }, true);
                Complete("live summary Space skip");
                view.Open(model); PauseMotion(view);
                Click(view.Descendants<Button>().Single(b => b.Name == "NextBookPage"));
                Check(view.DetailVisible, "live summary navigation works during reveal");
                view.SelectPage(false, false); Complete("live summary return from details");
                ProjectSettings.SetSetting("accessibility/reduce_motion", true);
                view.Open(model); Complete("live summary reduced motion");
                model.Closing = true;
                ProjectSettings.SetSetting("accessibility/reduce_motion", true);
                view.Open(model); Complete("reduced motion");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);

                var save = new SaveService(); save.UsePathForTests("res://.tmp/book-tests/motion-" + city + ".json"); AddChild(save);
                var upgradeModel = new BusinessBookModel { CityId = city, Closing = true, Result = model.Result,
                    Upgrades = new BookUpgradeSource(save, catalog, "city:" + city) };
                view.Open(upgradeModel); PauseMotion(view);
                Click(view.Descendants<Button>().Single(b => b.Name == "OpenBookUpgrades"));
                Check(view.Descendants<Control>().Any(c => c.Name == "BookUpgradeModal"), "equipment opens during reveal");
                Complete("equipment navigation");
                view.Hide(); save.QueueFree(); await Frames();
            }
            TranslationServer.SetLocale("en");
            Check(TranslationServer.Translate("今日收入") == "Today's income" && TranslationServer.Translate("挑战结果") == "Challenge result", "summary captions localized");
        }
        finally
        {
            TranslationServer.SetLocale(locale);
            ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
            view.QueueFree(); await Frames();
        }
    }

    private void CheckMotionInk(Label label)
    {
        using var frame = GetViewport().GetTexture().GetImage();
        Rect2 rect = label.GetViewportTransform() * label.GetGlobalRect();
        int ink = 0;
        for (int y = Math.Max(0, (int)rect.Position.Y); y < Math.Min(frame.GetHeight(), (int)rect.End.Y); y++)
        for (int x = Math.Max(0, (int)rect.Position.X); x < Math.Min(frame.GetWidth(), (int)rect.End.X); x++)
        {
            var color = frame.GetPixel(x, y);
            if (color.R < .55f && color.G < .45f && color.B < .35f) ink++;
        }
        Check(ink > 40, $"rendered ink for {label.Text}: {ink} pixels in {rect}");
    }
}
