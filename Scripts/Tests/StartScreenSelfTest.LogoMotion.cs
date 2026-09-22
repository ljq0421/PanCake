using Godot;
using ProjectCake.UI;
using ProjectCake.Core;

namespace ProjectCake.Tests;

public partial class StartScreenSelfTest
{
    private async Task LogoMotionChecks()
    {
        GetWindow().GrabFocus(); await MotionWait(1);
        var motion = _screen.Descendants<HomeLogoMotion>().Single();
        var logo = Find<TextureRect>("HomeLogo");
        var steam = Find<TextureRect>("LogoSteam");
        Check(logo.Position.IsEqualApprox(new(80, 150)) && logo.Scale == Vector2.One, "entrance settles exactly");
        Check(logo.FindChildren("*", "TextureRect", true, false).Count == 2, "only original backplate and steam remain");
        Vector2 before = steam.Position; await MotionWait(.3);
        Check(steam.Position != before, "original painted steam rises");
        Vector2 center = logo.GetGlobalTransformWithCanvas() * new Vector2(560, 280);
        GetViewport().WarpMouse(center); await MotionWait(.4);
        Check(logo.Scale == Vector2.One && logo.Position == new Vector2(80, 150)
            && Find<TextureRect>("LogoBackplate").Scale == Vector2.One, "hover and idle do not transform the logo");
        GetViewport().WarpMouse(new(12, 12));

        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        foreach (string locale in new[] { "zh_CN", "en" })
        {
            settings.SetLanguage(locale); await Frames();
            using var original = ((AtlasTexture)logo.Texture).Atlas.GetImage();
            using var backplate = Find<TextureRect>("LogoBackplate").Texture.GetImage();
            using var extracted = steam.Texture.GetImage();
            original.Convert(Image.Format.Rgba8); backplate.Convert(Image.Format.Rgba8); extracted.Convert(Image.Format.Rgba8);
            byte[] source = original.GetData(), rest = backplate.GetData(), puff = extracted.GetData();
            bool exact = true, outsideUnchanged = true; int count = 0;
            for (int i = 0; i < source.Length; i += 4)
            {
                int pixel = i / 4, x = pixel % original.GetWidth(), y = pixel / original.GetWidth();
                if (puff[i + 3] > 0) count++;
                exact &= puff[i + 3] + rest[i + 3] == source[i + 3];
                for (int c = 0; c < 3; c++)
                    exact &= rest[i + c] == source[i + c] && (puff[i + 3] == 0 || puff[i + c] == source[i + c]);
                if (x < 280 || x >= 528 || y < 80 || y >= 386)
                    for (int c = 0; c < 4; c++) outsideUnchanged &= rest[i + c] == source[i + c];
            }
            Check(exact && outsideUnchanged && count is > 20000 and < 80000,
                $"{locale}: split preserves original pixels and changes only steam (pixels={count})");
            await Capture("logo-steam-" + locale, .2);
        }
        await MotionClick(Find<Button>("Settings"));
        double clock = motion.MotionTime; before = steam.Position; await MotionWait(.2);
        Check(clock == motion.MotionTime && before == steam.Position, "modal freezes steam");
        KeyPress(Key.Escape); GetWindow().GrabFocus(); await Frames();
        motion.Notification((int)NotificationApplicationFocusOut);
        clock = motion.MotionTime; await MotionWait(.2);
        Check(clock == motion.MotionTime, "focus loss freezes steam");
        motion.Notification((int)NotificationApplicationFocusIn); await MotionWait(.2);
        Check(motion.MotionTime > clock, "focus restore resumes steam");
        ProjectSettings.SetSetting("accessibility/reduce_motion", true); await Frames();
        Check(logo.SelfModulate.A == 1 && !logo.GetNode<Control>("LogoCanvas").Visible,
            "reduced motion shows the untouched original logo");
        await Capture("logo-steam-reduced", 0);
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
        settings.SetLanguage("zh_CN"); await Frames();
        _screen.Hide(); clock = motion.MotionTime; await MotionWait(.2);
        Check(clock == motion.MotionTime, "hidden home freezes steam");
        _screen.PresentHome(); await Frames(); _screen.PresentMap(); await Frames();
        Check(!_screen.Descendants<HomeLogoMotion>().Any(), "leaving home removes steam controller");
        _screen.PresentHome(); await Frames();
        Check(_screen.Descendants<HomeLogoMotion>().Count() == 1 && !_screen.Descendants<HomeEntranceMotion>().Any(),
            "returning restores one steam controller without replaying entrance");
        await Capture("logo-steam-final", .4);
    }
}
