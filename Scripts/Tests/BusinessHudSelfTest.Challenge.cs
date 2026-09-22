using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class BusinessHudSelfTest
{
    private async Task CheckChallengePendant(Control screen, BusinessHud hud, DayController controller,
        SubViewport viewport, string city, int width, bool capture)
    {
        var pendant = hud.GetNode<DailyChallengePendant>("DailyChallengePendant");
        if (controller.CurrentPlan?.Challenge is not { } challenge)
        {
            Require(!pendant.IsVisibleInTree(), "cities without challenges keep pendant hidden"); return;
        }
        Require(pendant.IsVisibleInTree(), "active challenge visible");
        Require(pendant.GetGlobalRect().End.X < hud.GetNode<Control>("HudArtwork").GetGlobalRect().Position.X,
            "challenge sits left of centered HUD");
        foreach (var order in screen.Descendants<OrderBubbleView>().Where(o => o.IsVisibleInTree()))
            Require(!order.GetGlobalRect().Intersects(pendant.GetGlobalRect()), "challenge does not cover orders");
        Require(pendant.Descendants<Control>().All(c => c.MouseFilter == Control.MouseFilterEnum.Ignore), "pendant never intercepts input");
        Require(pendant.GetNodeOrNull<Label>("DailyChallengeProgress") is null, "numeric progress removed");
        var name = pendant.GetNode<Label>("ChallengeName");
        var requirement = pendant.GetNode<Label>("ChallengeRequirement");
        Require(requirement.Position.X >= name.GetRect().End.X && requirement.Position.Y == name.Position.Y,
            "requirement sits to the right of challenge name");
        var stamp = pendant.GetNode<Label>("ChallengeCompletionStamp");
        int celebrations = 0;
        pendant.CompletionPresented += () => celebrations++;
        var stars = pendant.GetChildren().OfType<TextureRect>().Where(c => c.Name.ToString().StartsWith("ChallengeStar")).ToArray();
        Require(stars.Length == challenge.Target && !stamp.Visible, "one uncompleted star per target");
        void Advance() => controller.Ledger!.RecordDelivery(new DeliveryEvaluation(DeliveryGrade.Perfect, 0, 0, 100, "challenge fixture"));
        screen._Notification((int)NotificationApplicationFocusIn);
        pendant._Notification((int)NotificationApplicationFocusIn);
        pendant.Render(controller, true, false);
        Advance(); pendant.Render(controller, true, false);
        await Frames();
        Require(stars.Count(s => s.Modulate == Colors.White) == 1, "progress lights first star");
        controller.SetPauseReason("challenge-check", true); await Frames();
        Require(stars[0].Scale == Vector2.One, "pause stops animation");
        controller.SetPauseReason("challenge-check", false);
        for (int i = 1; i < challenge.Target - 1; i++) Advance();
        pendant.Render(controller, false, false);
        Require(requirement.Text.Contains("1 单"), "last order reminder is explicit");
        if (capture) await Shot(viewport, $"{city}-{width}-challenge-nearly");
        screen._Notification((int)NotificationApplicationFocusIn);
        pendant._Notification((int)NotificationApplicationFocusIn);
        Advance(); pendant.Render(controller, true, false);
        Require(celebrations == 1 && pendant.CompletionCoins.Count == 3,
            $"completion emits one celebration and three coins (events={celebrations}, coins={pendant.CompletionCoins.Count}, paused={controller.IsPaused})");
        Require(pendant.GetNode<AudioStreamPlayer>("ChallengeCompletedSound").Playing, "completion sound plays on effects bus");
        pendant.Render(controller, true, false);
        Require(celebrations == 1 && pendant.CompletionCoins.Count == 3, "repeated render does not replay celebration");
        await ToSignal(GetTree().CreateTimer(.35), SceneTreeTimer.SignalName.Timeout);
        if (capture) await Shot(viewport, $"{city}-{width}-challenge-flight");
        await ToSignal(GetTree().CreateTimer(.7), SceneTreeTimer.SignalName.Timeout);
        Require(pendant.CompletionCoins.Count == 0, "coins finish and clean up");
        Require(!stamp.Visible, "completion does not show a pending-reward status box");
        var banner = pendant.GetNode<Control>("ChallengeCompletionBanner");
        Require(banner.Visible, "celebration remains readable for two seconds");
        foreach (var order in screen.Descendants<OrderBubbleView>().Where(o => o.IsVisibleInTree()))
            Require(!order.GetGlobalRect().Intersects(banner.GetGlobalRect()), "completion banner does not cover orders");
        Require(stars.All(s => s.Modulate == Colors.White), "completion lights all stars");
        Require(controller.Ledger!.Build().TotalRevenue == 0, "completion does not add challenge reward to business revenue");
        foreach (var label in pendant.Descendants<Label>().Where(l => l.Visible))
            Require(label.GetThemeFont("font").GetStringSize(label.Text, fontSize: label.GetThemeFontSize("font_size")).X <= label.Size.X,
                $"challenge text fits: {label.Name}");
        if (capture) await Shot(viewport, $"{city}-{width}-challenge-complete");
        await ToSignal(GetTree().CreateTimer(1.2), SceneTreeTimer.SignalName.Timeout);
        Require(!banner.Visible, "banner retires automatically without a click");
        if (capture) await Shot(viewport, $"{city}-{width}-challenge-resting");
        pendant.Render(controller, false, true);
        Require(stamp.Text == "奖励已领取", "claimed reward state");
        if (capture && width == 1280) await Shot(viewport, $"{city}-{width}-challenge-claimed");
        Require(controller.TryPrepareDay(controller.CurrentConfig!.CityId, challenge.Day, GetNode<DataCatalog>("/root/DataCatalog"), out _), "replay prepares");
        pendant.Render(controller, true, false);
        Require(!pendant.GetChildren().OfType<TextureRect>().Any(s => s.Name.ToString().StartsWith("ChallengeStar") && s.Modulate == Colors.White) && !stamp.Visible,
            "same-day replay clears completion and animation");
        string cityId = controller.CurrentConfig!.CityId;
        foreach (int day in new[] { 2, 3, 4 })
        {
            Require(controller.TryPrepareDay(cityId, day, GetNode<DataCatalog>("/root/DataCatalog"), out _), "challenge variant prepares");
            var variant = controller.CurrentPlan!.Challenge!;
            pendant.Render(controller, false, false);
            controller.Ledger!.RecordDelivery(new DeliveryEvaluation(DeliveryGrade.Correct, 0, 0, 100, "variant fixture"));
            pendant.Render(controller, false, false);
            int expected = variant.Kind == DailyChallengeKind.Perfect ? 0 : 1;
            Require(pendant.GetChildren().OfType<TextureRect>().Count(s => s.Name.ToString().StartsWith("ChallengeStar") && s.Modulate == Colors.White) == expected,
                "each challenge uses its own progress rule");
            if (variant.Kind == DailyChallengeKind.Streak)
            {
                for (int i = 1; i < variant.Target - 1; i++) Advance();
                pendant.Render(controller, true, false);
                Require(requirement.Text == "再完成 1 单！", "current streak approaching target prompts once");
                controller.Ledger.RecordLost(); pendant.Render(controller, true, false);
                Require(requirement.Text == variant.Requirement, "broken streak clears last-order reminder despite best streak");
            }
        }
        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        try
        {
            Advance(); pendant.Render(controller, true, false); await Frames();
            Require(pendant.GetChildren().OfType<TextureRect>().All(s => s.Scale == Vector2.One), "reduced motion keeps updated progress static");
            var current = controller.CurrentPlan!.Challenge!;
            while (!current.Achieved(controller.Ledger!.Build())) Advance();
            pendant.Render(controller, true, false);
            Require(pendant.CompletionCoins.Count == 0 && pendant.GetNode<AudioStreamPlayer>("ChallengeCompletedSound").Playing,
                "reduced motion retains completion sound without flying coins");
            Require(banner.Visible && banner.Scale == Vector2.One, "reduced motion retains a static readable banner");
        }
        finally { ProjectSettings.SetSetting("accessibility/reduce_motion", false); }
        Require(controller.TryPrepareDay(cityId, 4, GetNode<DataCatalog>("/root/DataCatalog"), out _), "feedback cancellation run prepares");
        pendant.Render(controller, true, false);
        var cancelChallenge = controller.CurrentPlan!.Challenge!;
        while (!cancelChallenge.Achieved(controller.Ledger!.Build())) Advance();
        pendant.Render(controller, true, false);
        int beforePause = celebrations;
        Require(pendant.CompletionCoins.Count == 3, "new run can celebrate again");
        controller.SetPauseReason("challenge-check", true); await Frames();
        Require(pendant.CompletionCoins.Count == 0 && !pendant.GetNode<AudioStreamPlayer>("ChallengeCompletedSound").Playing,
            "pause clears flights and stops completion sound");
        Require(!banner.Visible, "pause cancels completion banner");
        controller.SetPauseReason("challenge-check", false); pendant.Render(controller, true, false);
        Require(celebrations == beforePause && pendant.CompletionCoins.Count == 0, "resume does not replay completion");
        Require(controller.TryPrepareDay(cityId, 4, GetNode<DataCatalog>("/root/DataCatalog"), out _), "claimed replay prepares");
        pendant.Render(controller, true, true);
        while (!controller.CurrentPlan!.Challenge!.Achieved(controller.Ledger!.Build())) Advance();
        pendant.Render(controller, true, true);
        Require(celebrations == beforePause && !banner.Visible && stamp.Text == "奖励已领取", "claimed replay never promises or celebrates another reward");
        GD.Print($"CHALLENGE_PENDANT_PASS {city} {width}");
    }
}
