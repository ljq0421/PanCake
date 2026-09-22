using Godot;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StartScreenSelfTest
{
    private async Task MotionWait(double seconds = .55)
        => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);

    private async Task MotionClick(Control control)
    {
        // Deliver one complete native click before OS cursor events can interleave with it.
        Vector2 point = control.GetGlobalTransformWithCanvas() * (control.Size * .5f);
        GetViewport().PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point }, true);
        foreach (bool pressed in new[] { true, false })
            GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left,
                Pressed = pressed, Position = point, GlobalPosition = point }, true);
        await Frames();
    }

    private async Task HomeMotionChecks()
    {
        // Launch uses isolated save/settings paths. Never touch the player's progress.
        GetWindow().GrabFocus();
        var entrance = _screen.Descendants<HomeEntranceMotion>().Single();
        Check(Find<Button>("NewGame").Position.IsEqualApprox(new(940, 835)) && !Find<Button>("NewGame").Disabled,
            "entrance keeps actions immediately available at their final hit regions");
        await Capture("motion-entrance", 0);
        await MotionClick(Find<Button>("Settings"));
        Check(_screen.ModalOpen && entrance.Finished && Find<TextureRect>("HomeLogo").Position.IsEqualApprox(new(80, 150)),
            "immediate input interrupts entrance and settles the logo");
        KeyPress(Key.Escape); GetWindow().GrabFocus(); await Frames();
        await MotionWait();
        // Pick the newest wisp so the sample cannot straddle the invisible cycle wrap.
        var steam = Enumerable.Range(1, 3).Select(i => Find<TextureRect>("HomeSteam" + i))
            .OrderByDescending(puff => puff.Position.Y).First();
        Vector2 before = steam.Position;
        await MotionWait(.2);
        Check(steam.Position.Y < before.Y, "steam rises continuously");
        await Capture("motion-first-run");
        Check(Find<Button>("Continue").Disabled, "empty save keeps Continue disabled");
        var disabledIcon = Find<Button>("Continue").GetNode<TextureRect>("ActionIcon");
        Check(disabledIcon.Position.IsEqualApprox(new(18, -34)), "disabled icon stays at rest");

        _save.ResetProgress(out _); _screen.PresentHome(); await Frames();
        Check(!_screen.Descendants<HomeEntranceMotion>().Any(), "save refresh and home rebuild do not replay entrance");
        var sign = Find<TextureRect>("HomeHangingSign");
        var mapDecoration = Find<TextureRect>("HomeMapDecoration");
        Check(sign.GetIndex() > mapDecoration.GetIndex(), "hanging sign stays in front of the home map");
        Check(Find<TextureRect>("HomeSignBackdrop").Size.IsEqualApprox(new(111f / 1672 * 1920, 189f / 941 * 1080)),
            "sign clean plate is confined to its original local region");
        var light = (ShaderMaterial)Find<ColorRect>("HomeWindowLight").Material;
        float signBefore = sign.Rotation, lightBefore = light.GetShaderParameter("phase").AsSingle();
        await MotionWait(.3);
        Check(!Mathf.IsEqualApprox(sign.Rotation, signBefore) && light.GetShaderParameter("phase").AsSingle() != lightBefore,
            "hanging sign and local window light advance");
        var button = Find<Button>("Continue");
        var icon = button.GetNode<TextureRect>("ActionIcon");
        GetViewport().PushInput(new InputEventMouseMotion { Position = new(10, 10) }, true);
        await MotionWait();
        Vector2 defaultCenter = button.GetGlobalTransformWithCanvas() * (button.Size * .5f);
        GetViewport().PushInput(new InputEventMouseMotion { Position = defaultCenter, GlobalPosition = defaultCenter }, true);
        await MotionWait(.1);
        Check(button.HasFocus() && icon.Position.X > 18, "default keyboard focus does not suppress pointer entry");
        GetViewport().PushInput(new InputEventMouseMotion { Position = new(10, 10) }, true);
        // Leave the default focus, then enter with native keyboard navigation.
        KeyPress(Key.Tab); await MotionWait();
        KeyPress(Key.Left); await MotionWait(.10);
        Check(button.HasFocus() && icon.Position.X > 18, "keyboard focus starts the train gesture");
        await Capture("motion-train", 0);
        await MotionWait();
        Check(icon.Position.IsEqualApprox(new(18, -34)), "held focus does not loop the gesture");

        KeyPress(Key.Tab); await MotionWait();
        Vector2 center = button.GetGlobalTransformWithCanvas() * (button.Size * .5f);
        GetViewport().PushInput(new InputEventMouseMotion { Position = center, GlobalPosition = center }, true);
        await MotionWait(.10);
        Check(button.IsHovered() && icon.Position.X > 18, "pointer entry starts the train gesture");
        for (int i = 0; i < 4; i++)
        {
            GetViewport().PushInput(new InputEventMouseMotion { Position = new(10, 10) }, true);
            await Frames();
            GetViewport().PushInput(new InputEventMouseMotion { Position = center }, true);
            await Frames();
        }
        GetViewport().PushInput(new InputEventMouseMotion { Position = new(10, 10) }, true);
        await MotionWait();
        Check(icon.Position.IsEqualApprox(new(18, -34)) && Mathf.IsZeroApprox(icon.Rotation), "rapid pointer changes settle without drift");

        steam = Find<TextureRect>("HomeSteam2");
        await Capture("motion-steam-a"); await MotionWait(.7); await Capture("motion-steam-b");
        await MotionClick(Find<Button>("Settings"));
        Check(_screen.ModalOpen, "native click opens settings");
        signBefore = sign.Rotation; lightBefore = light.GetShaderParameter("phase").AsSingle();
        before = steam.Position; await MotionWait(.2);
        Check(steam.Position.IsEqualApprox(before), "modal pauses home steam");
        Check(Mathf.IsEqualApprox(sign.Rotation, signBefore) && light.GetShaderParameter("phase").AsSingle() == lightBefore,
            "modal freezes sign and shader phase");
        KeyPress(Key.Escape); GetWindow().GrabFocus(); await Frames(); before = steam.Position;
        await MotionWait(.2); Check(!steam.Position.IsEqualApprox(before),
            $"steam resumes after modal closes (modal={_screen.ModalOpen}, focused={GetWindow().HasFocus()}, page={_screen.Page})");

        var ambient = _screen.Descendants<HomeAmbientMotion>().Single();
        ambient.Notification((int)NotificationApplicationFocusOut);
        signBefore = sign.Rotation; lightBefore = light.GetShaderParameter("phase").AsSingle();
        before = steam.Position; await MotionWait(.2);
        Check(steam.Position.IsEqualApprox(before), "focus loss freezes ambient motion");
        Check(Mathf.IsEqualApprox(sign.Rotation, signBefore) && light.GetShaderParameter("phase").AsSingle() == lightBefore,
            "focus loss freezes sign and local light");
        ambient.Notification((int)NotificationApplicationFocusIn);
        await MotionWait(.2); Check(!steam.Position.IsEqualApprox(before), "focus restore resumes ambient motion");

        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        await Frames(); before = steam.Position;
        KeyPress(Key.Left); await MotionWait(.2);
        Check(steam.Position.IsEqualApprox(before) && icon.Position.IsEqualApprox(new(18, -34)), "reduced motion leaves steam and icons still");
        Check(Mathf.IsZeroApprox(sign.Rotation) && light.GetShaderParameter("phase").AsSingle() == 0,
            "reduced motion rests sign and sunlight");
        await Capture("motion-reduced");
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);

        var map = Find<Button>("WorldMap");
        Vector2 mapCenter = map.GetGlobalTransformWithCanvas() * (map.Size * .5f);
        GetViewport().PushInput(new InputEventMouseMotion { Position = mapCenter, GlobalPosition = mapCenter }, true);
        Check(map.IsHovered(), "map receives pointer at the scaled viewport position");
        await MotionClick(map);
        Check(_screen.Page == JourneyPage.Map && !_screen.Descendants<HomeAmbientMotion>().Any(),
            $"leaving home removes its motion controller (page={_screen.Page}, modal={_screen.ModalOpen})");
        KeyPress(Key.Escape); await Frames();
        Check(_screen.Descendants<HomeAmbientMotion>().Count() == 1 && _screen.Descendants<HomeActionMotion>().Count() == 4,
            "returning home creates exactly one set of controllers");
        Check(!_screen.Descendants<HomeEntranceMotion>().Any(), "returning from map does not replay entrance");
        steam = Find<TextureRect>("HomeSteam2");
        _screen.Hide(); before = steam.Position;
        await MotionWait(.2);
        Check(steam.Position.IsEqualApprox(before), "hidden home stops moving");
        _screen.PresentHome(); await MotionWait(); await Capture("motion-home-final");
    }
}
