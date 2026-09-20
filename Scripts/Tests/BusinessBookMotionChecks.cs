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
            Check(Income().Text == $"¥{view.Model.Result.TotalRevenue}" && Income().Modulate.A == 1
                && Income().Scale == Vector2.One && Note().Modulate.A == 1
                && Note().Position == new Vector2(923, 378), context + " restores exact final values and transforms");
            Check(Math.Abs(view.Descendants<ProgressBar>().Single().Value - (view.Model.CompletionRate ?? 0)) < .001,
                context + " restores completion bar");
            Check(!view.Descendants<Control>().Any(c => c.Name.ToString().StartsWith("SettlementFallingCoin") && c.Visible),
                context + " clears temporary coins");
        }
        try
        {
            foreach (string city in new[] { "tianjin", "wuhan" })
            {
                var fixture = Fixture(city);
                var model = new BusinessBookModel
                {
                    CityId = city, Closing = true, Orders = fixture.Orders,
                    Result = new() { Day = 3, SaleRevenue = 40, Tips = 5, CompletedCustomers = 4,
                        LostCustomers = 1, PerfectOrders = 2, Satisfaction = 93 }
                };
                foreach (var size in Capture ? CaptureSizes : CaptureSizes.Take(1))
                {
                    GetWindow().ContentScaleAspect = Window.ContentScaleAspectEnum.Expand;
                    GetWindow().Size = size; await Frames(5);
                    view.Open(model);
                    var tween = PauseMotion(view);
                    var incomePosition = Income().Position;
                    Check(Income().Modulate.A == 0 && Caption("菜品销售").Modulate.A == 0
                        && Caption("顾客小费").Modulate.A == 0 && Note().Modulate.A == 0, "income and note hidden before first frame");
                    Check(Caption("今日收入").Modulate.A == 1 && Caption("今日接待").Modulate.A == 1
                        && !view.CloseButton.Disabled, "headings and actions are available from opening");
                    if (Capture) await Shot($"motion-{city}-{size.X}-0-open");
                    StepMotion(tween, .52 + .51);
                    Check(Caption("完成").Modulate.A == 1 && Caption("93%").Modulate.A < .1
                        && Income().Modulate.A == 0, "reception precedes evaluation and income");
                    if (Capture) await Shot($"motion-{city}-{size.X}-1-reception");
                    StepMotion(tween, .40);
                    Check(Caption("93%").Modulate.A == 1 && MotionField<Control>(view, "_stamp").Scale == Vector2.One
                        && Income().Modulate.A == 0, "evaluation settles before income");
                    if (Capture) await Shot($"motion-{city}-{size.X}-2-evaluation");
                    StepMotion(tween, .25);
                    Check(Caption("收获小费").GetParent<Control>().Modulate.A == 1
                        && Caption("顾客小费").Modulate.A == 0, "review does not disclose tip amount");
                    if (Capture) await Shot($"motion-{city}-{size.X}-3-review");
                    StepMotion(tween, .59);
                    Check(Income().Text == "¥40" && Income().Position == incomePosition, "sales counts to subtotal without layout drift");
                    if (Capture) await Shot($"motion-{city}-{size.X}-4-sales");
                    StepMotion(tween, .25);
                    Check(Income().Text == "¥45" && Note().Modulate.A == 0, "tips add only once before quiet note");
                    if (Capture) await Shot($"motion-{city}-{size.X}-5-coins");
                    StepMotion(tween, .60);
                    Complete(city + " natural completion");
                    if (Capture) await Shot($"motion-{city}-{size.X}-6-note");

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
                foreach (double moment in new[] { .1, .85, 1.2, 1.6, 2.3, 2.9 })
                {
                    view.Open(model); var tween = PauseMotion(view); StepMotion(tween, moment);
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
                    Check(MotionField<Control>(view, "_stamp").Scale == Vector2.One, "no Perfect does not stamp");
                    if (result.TotalRevenue == 0)
                        Check(!view.Descendants<Control>().Any(c => c.Name.ToString().StartsWith("SettlementFallingCoin") && !c.IsQueuedForDeletion()), "zero income has no falling coins");
                    StepMotion(tween, result.Tips == 0 ? 2.83 : 3.03);
                    Complete("edge revenue " + result.TotalRevenue);
                    Check(!MotionField<bool>(view, "_travelAnimating"), "no-tip timeline ends 0.2s earlier");
                    await Frames();
                }
                model.Closing = false; view.Open(model); Complete("live summary");
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
            Check(TranslationServer.Translate("今日收入") == "Today's income" && TranslationServer.Translate("收获小费") == "Tips earned", "new captions localized");
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
        Rect2 rect = label.GetGlobalRect();
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
