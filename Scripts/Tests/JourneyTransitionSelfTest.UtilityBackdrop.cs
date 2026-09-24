using Godot;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class JourneyTransitionSelfTest
{
    private async Task UtilityBackdropChecks()
    {
        Check(DisplayServer.GetName() != "headless", "backdrop regression requires a rendered viewport");
        FindButton("Settings").EmitSignal(BaseButton.SignalName.Pressed);
        CheckEffect(JourneyTransition.Effect.SpreadOpen, "settings opens from home");
        await Complete();
        await Capture("utility-settings-before");
        using var baseline = GetViewport().GetTexture().GetImage();
        foreach (string destination in new[] { "Help", "Settings" })
        {
            _home.GetNode<Button>("Canvas/Modal/ModalUtilities/" + destination).EmitSignal(BaseButton.SignalName.Pressed);
            CheckEffect(JourneyTransition.Effect.BookPage, destination + " retains book motion");
            foreach (float progress in new[] { 0f, .25f, .5f, .9f, .99f })
            {
                await Sample($"utility-{destination}-{progress:0.00}", progress);
                using var frame = GetViewport().GetTexture().GetImage();
                CheckBackdropPixels(baseline, frame, destination + " at " + progress);
            }
            _motion.Finish();
            await Capture("utility-" + destination + "-complete");
            using var complete = GetViewport().GetTexture().GetImage();
            CheckBackdropPixels(baseline, complete, destination + " complete");
        }
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
        CheckEffect(JourneyTransition.Effect.SpreadClose, "settings still folds closed");
        await Complete();
        Check(!_home.ModalOpen && !_motion.Active, "closing restores home navigation");
        await Capture("utility-home-after");
        FindButton("Help").EmitSignal(BaseButton.SignalName.Pressed);
        await Complete();
        _home.PresentCity(ProjectCake.Data.StableIds.Cities.Tianjin, fromHome: true);
        CheckEffect(JourneyTransition.Effect.BookPage, "utility book to journey book turns once");
        await Complete();
        _home.PresentHome(); await Complete();
        _home.PresentCity(ProjectCake.Data.StableIds.Cities.Tianjin);
        await Complete();
        FindButton("Settings").EmitSignal(BaseButton.SignalName.Pressed);
        CheckEffect(JourneyTransition.Effect.BookPage, "chapter to settings turns once");
        await Complete();
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
        CheckEffect(JourneyTransition.Effect.BookPage, "settings returns to chapter with one turn");
        await Complete();
        Check(!_home.ModalOpen && !_motion.Active, "chapter return releases transition");
    }

    private void CheckBackdropPixels(Image expected, Image actual, string state)
    {
        // Sample both outer margins, away from the book, navigation and moving home decorations.
        float largestDifference = 0;
        foreach (int x in new[] { 20, 40, expected.GetWidth() - 40, expected.GetWidth() - 20 })
            for (int y = expected.GetHeight() * 2 / 3; y < expected.GetHeight() * 5 / 6; y += 8)
            {
                Color a = expected.GetPixel(x, y), b = actual.GetPixel(x, y);
                largestDifference = Math.Max(largestDifference,
                    Math.Max(Math.Abs(a.R - b.R), Math.Max(Math.Abs(a.G - b.G), Math.Abs(a.B - b.B))));
            }
        Check(largestDifference <= 2f / 255f, $"{state}: outer backdrop stays constant (max delta={largestDifference:0.0000})");
    }
}
