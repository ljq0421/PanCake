using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Settings-only checks shared by full and Demo entrypoints; callers isolate persistence.</summary>
internal static class SettingsPageChecks
{
    private static async Task Frames(Node node, int count = 3)
    {
        for (int i = 0; i < count; i++) await node.ToSignal(node.GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    private static T Find<T>(StartScreen screen, string name) where T : Node => screen.FindChildren(name, typeof(T).Name, true, false)
        .OfType<T>().First(n => n is not Control control || control.IsVisibleInTree());
    private static async Task Click(Control control)
    {
        Vector2 point = control.GetGlobalTransformWithCanvas() * (control.Size / 2);
        var viewport = control.GetViewport();
        viewport.PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point }, true);
        viewport.PushInput(new InputEventMouseButton { Position = point, GlobalPosition = point, ButtonIndex = MouseButton.Left, Pressed = true }, true);
        viewport.PushInput(new InputEventMouseButton { Position = point, GlobalPosition = point, ButtonIndex = MouseButton.Left, Pressed = false }, true);
        await Frames(control);
    }
    private static async Task KeyPress(Viewport viewport, Key key)
    {
        // Route through the engine's window input path, before PopupMenu's viewport dispatch.
        if (viewport is PopupMenu popup)
        {
            Input.ParseInputEvent(new InputEventKey { WindowId = popup.GetWindowId(), Keycode = key, Pressed = true });
            Input.ParseInputEvent(new InputEventKey { WindowId = popup.GetWindowId(), Keycode = key, Pressed = false });
        }
        else
        {
            Input.ParseInputEvent(new InputEventKey { WindowId = viewport.GetWindow().GetWindowId(), Keycode = key, Pressed = true });
            Input.ParseInputEvent(new InputEventKey { WindowId = viewport.GetWindow().GetWindowId(), Keycode = key, Pressed = false });
        }
        await Frames(viewport);
    }
    internal static async Task SelectLanguage(StartScreen screen, int index) => await Select(Find<OptionButton>(screen, "Language"), index);
    private static async Task Select(OptionButton choice, int index)
    {
        await Click(choice);
        var popup = choice.GetPopup();
        popup.SetFocusedItem(index);
        await KeyPress(popup, Key.Enter);
    }

    internal static async Task Run(StartScreen screen, SaveService save, JourneySettings settings, Func<string, Task> capture)
    {
        int passed = 0;
        void Check(bool ok, string detail)
        {
            if (!ok) throw new InvalidOperationException("Settings: " + detail);
            passed++; GD.Print("PASS settings " + detail);
        }
        var window = screen.GetWindow();
        var originalSize = window.Size;
        bool graphical = DisplayServer.GetName() != "headless";
        string path = settings.SettingsPath;
        string slotRoot = Path.Combine(Path.GetDirectoryName(path)!, "save-slots");
        save.UseSlotsForTests(slotRoot);
        save.TryCreateSlot(1, out _); save.Data.Coins = 111; save.TrySave(out _);
        save.TryCreateSlot(2, out _); save.Data.Coins = 222; save.TrySave(out _);
        save.TryLoadSlot(1, out _);
        Check(JourneySettings.SizesForArea(new(4000, 2300)).Contains(new Vector2I(3840, 2160)), "4K included on a fitting display");
        Check(JourneySettings.SizesForArea(new(2700, 1500)).Contains(new Vector2I(2560, 1440)), "1440p included on a fitting display");
        Check(JourneySettings.SizesForArea(new(1920, 1040)).SequenceEqual(new[] { new Vector2I(1280, 720), new Vector2I(1600, 900) }), "window presets fit usable client area");
        var fallback = JourneySettings.SizesForArea(new(1000, 600)).Single();
        Check(fallback.X <= 1000 && fallback.Y <= 600 && fallback.X * 9 == fallback.Y * 16, "small screens have a fitting 16:9 fallback");
        settings.SetLanguage("zh_CN"); settings.SetVolume("master", 100); settings.SetVolume("music", 61); settings.SetVolume("effects", 100);
        if (settings.Muted) settings.ToggleMute();
        screen.PresentHome(); await Frames(screen);
        await Click(Find<Button>(screen, "Settings"));
        Check(Find<TextureRect>(screen, "SettingsBook").GetRect() == StartScreen.BookBounds, "book size and position unchanged");
        Check(Find<Button>(screen, "Windowed").HasFocus(), "first display option initially focused");
        if (!graphical)
        {
            foreach (string name in new[] { "Fullscreen", "Resolution", "VSync", "Language", "SaveSlot", "Volumemaster", "Volumemusic", "Volumeeffects", "Mute", "ReduceMotion", "Close", "Windowed" })
            {
                await KeyPress(screen.GetViewport(), Key.Tab);
                string actual = screen.GetViewport().GuiGetFocusOwner()?.Name.ToString() ?? "none";
                Check(actual == name, $"Tab reaches {name} (actual {actual})");
            }
        }
        var saveSlot = Find<OptionButton>(screen, "SaveSlot");
        Check(saveSlot.ItemCount == SaveService.SlotCount && !saveSlot.IsItemDisabled(0) && !saveSlot.IsItemDisabled(1)
            && saveSlot.IsItemDisabled(2), "save selector lists five slots and disables empty ones");
        Check(!saveSlot.GetItemText(0).Contains("存档位") && saveSlot.GetRect().Position.X >= 340
            && saveSlot.GetRect().End.X <= 893 && saveSlot.GetPopup().MaxSize.X == (int)saveSlot.Size.X,
            "save selector omits slot prefix and its menu stays within the left page");
        var close = Find<Button>(screen, "Close");
        Check(close.GetThemeStylebox("normal") is StyleBoxTexture { Texture.ResourcePath: "res://resource/art/TianJin/DialogUI/button-secondary-v1.png" },
            "close uses the specified secondary button texture");
        if (graphical && OS.GetCmdlineUserArgs().Contains("--capture"))
        {
            await capture("settings-new-zh");
            saveSlot.ShowPopup(); await Frames(screen);
            await capture("settings-save-slot-menu");
            saveSlot.GetPopup().Hide();
            settings.SetLanguage("en"); await Frames(screen);
            await capture("settings-new-en");
            settings.SetLanguage("zh_CN");
            GD.Print("SETTINGS_VISUAL_CAPTURE_OK");
            return;
        }
        saveSlot.EmitSignal(OptionButton.SignalName.ItemSelected, 1);
        await Frames(screen);
        Check(save.ActiveSlotId == 2 && save.Data.Coins == 222 && screen.Page == JourneyPage.Home && screen.ModalOpen
            && !JourneyTransition.For(screen).Active,
            "save selector directly switches the active save without reopening the book");
        string beforeSave = JsonSerializer.Serialize(save.Data);
        Check(Find<Label>(screen, "Labelmusic").Text == "音乐", "music label has no playback-status copy");
        Check(Find<Button>(screen, "Mute").ToggleMode && !Find<Button>(screen, "Mute").ButtonPressed, "mute is an explicit state switch");
        Check(Find<HSlider>(screen, "Volumemusic").GetThemeStylebox("slider") is StyleBoxFlat, "slider uses local paper theme");
        await capture("settings-new-zh");
        await Click(Find<OptionButton>(screen, "Resolution"));
        await capture("settings-resolution-menu");
        await KeyPress(Find<OptionButton>(screen, "Resolution").GetPopup(), Key.Escape);
        Check(screen.ModalOpen && !Find<OptionButton>(screen, "Resolution").GetPopup().Visible, "Escape closes only dropdown");
        await SelectLanguage(screen, 1);
        Check(settings.Language == "en", "language menu keyboard selection applies English");
        Check(Find<Label>(screen, "LanguageLabel").Tr("语言") == "Language", "language row translated");
        await capture("settings-new-en");
        var fullButton = Find<Button>(screen, "Fullscreen");
        Check(fullButton.GetRect().End.X <= 893 && fullButton.GetThemeFont("font").GetStringSize(fullButton.Tr(fullButton.Text), fontSize: fullButton.GetThemeFontSize("font_size")).X <= fullButton.Size.X - 24, "English mode text fits its button and left page");
        await SelectLanguage(screen, 0);
        Check(settings.Language == "zh_CN", "Chinese restored without English fallback");
        var music = Find<HSlider>(screen, "Volumemusic");
        music.GrabFocus(); double previousVolume = settings.Music;
        await KeyPress(screen.GetViewport(), Key.Left);
        Check(settings.Music < previousVolume && music.HasFocus(), "arrow key adjusts slider without moving focus");
        await Click(music);
        Check(settings.Music > 40 && settings.Music < 60, "track click changes real volume");
        settings.SetVolume("master", 63); settings.SetVolume("music", 28); settings.SetVolume("effects", 41);
        await Click(Find<Button>(screen, "Mute"));
        Check(settings.Muted && AudioServer.IsBusMute(0), "mute applies to master bus");
        music.Value = 61;
        Check(settings.Muted && settings.Master == 63 && settings.Music == 61, "slider editing preserves mute and other levels");
        await capture("settings-muted");
        await Click(Find<Button>(screen, "Mute"));
        Check(!settings.Muted && settings.Music == 61, "unmute restores configured levels");
        await Click(Find<Button>(screen, "VSync"));
        Check(Find<Button>(screen, "VSync").ButtonPressed == settings.VSyncEnabled, "V-Sync switch reflects accepted state");
        if (graphical) Check(settings.VSyncEnabled == (DisplayServer.WindowGetVsyncMode() != DisplayServer.VSyncMode.Disabled), "V-Sync matches driver readback");
        var cfg = new ConfigFile();
        Check(cfg.Load(path) == Error.Ok && cfg.GetValue("display", "vsync").AsBool() == settings.VSyncEnabled, "V-Sync persisted");
        settings.SetVSync(true);
        Vector2I confirmed = JourneySettings.ResolveWindowedSize(originalSize);
        // Headless DisplayServer has no physical window mode/size. Exercise these with the graphical runs.
        if (graphical)
        {
        var resolution = Find<OptionButton>(screen, "Resolution");
        int target = Enumerable.Range(0, resolution.ItemCount).First(i => resolution.GetItemText(i) != $"{window.Size.X} × {window.Size.Y}");
        var oldSize = window.Size;
        await Select(resolution, target);
        Check(settings.DisplayPending, "resolution starts confirmation");
        Check(Find<Button>(screen, "RevertDisplay").HasFocus(), "confirmation defaults to recovery");
        await capture("settings-display-confirmation");
        settings.SetVolume("effects", 42); cfg.Load(path);
        Check(cfg.GetValue("display", "window_width").AsInt32() == oldSize.X, "saving audio during preview retains confirmed display");
        await KeyPress(screen.GetViewport(), Key.Escape);
        Check(!settings.DisplayPending && window.Size == oldSize && resolution.HasFocus(), "Escape reverts display and restores focus");
        await Select(resolution, target);
        settings._Process(16); await Frames(screen);
        Check(!settings.DisplayPending && window.Size == oldSize, "timeout restores display");
        await Select(resolution, target);
        await Click(Find<Button>(screen, "KeepDisplay"));
        confirmed = window.Size;
        Check(!settings.DisplayPending && settings.WindowedSize == confirmed, "confirmed window size remembered");
        settings.PreviewDisplay(false, confirmed);
        Check(!settings.DisplayPending, "choosing current display does not prompt");
        await Click(Find<Button>(screen, "Fullscreen"));
        Check(settings.DisplayPending, "fullscreen starts confirmation");
        if (graphical) Check(Find<OptionButton>(screen, "Resolution").Disabled, "fullscreen disables resolution");
        // OS fullscreen transitions and canvas resize notifications settle asynchronously.
        await screen.ToSignal(screen.GetTree().CreateTimer(.35), SceneTreeTimer.SignalName.Timeout);
        await Click(Find<Button>(screen, "KeepDisplay"));
        Check(!settings.DisplayPending, "fullscreen confirmation accepted by viewport click");
        if (graphical)
        {
            await capture("settings-fullscreen");
            Check(window.Size == DisplayServer.ScreenGetSize(window.CurrentScreen), "borderless fullscreen follows desktop");
            settings.SetVolume("master", 64); cfg.Load(path);
            Check(cfg.GetValue("display", "window_width").AsInt32() == confirmed.X, "fullscreen saving retains window size");
            settings.LoadPreferences(); await Frames(screen);
            Check(settings.Fullscreen && settings.WindowedSize == confirmed, "fullscreen reload retains window size");
            Check(settings.Master == 64 && settings.Music == 61 && settings.Effects == 42 && !settings.Muted, "audio preferences survive reload");
            await Click(Find<Button>(screen, "Windowed"));
            await screen.ToSignal(screen.GetTree().CreateTimer(.35), SceneTreeTimer.SignalName.Timeout);
            Check(window.Size == confirmed, $"return to windowed restores size (actual={window.Size}, expected={confirmed}, mode={window.Mode}, pending={settings.DisplayPending})");
            await Click(Find<Button>(screen, "KeepDisplay"));
        }
        settings.PreviewDisplay(false, JourneySettings.AvailableSizes().First(s => s != confirmed));
        screen.PresentHome(); await Frames(screen);
        Check(!settings.DisplayPending && window.Size == confirmed, "leaving settings reverts pending display");
        }
        else { screen.PresentHome(); await Frames(screen); }

        string legacyPath = Path.Combine(Path.GetDirectoryName(path)!, "legacy-settings.cfg");
        var legacy = new ConfigFile();
        legacy.SetValue("display", "width", confirmed.X); legacy.SetValue("display", "height", confirmed.Y);
        legacy.SetValue("audio", "master", 73); legacy.SetValue("language", "locale", "en"); legacy.Save(legacyPath);
        settings.UsePathForTests(legacyPath);
        Check(settings.VSyncEnabled && settings.WindowedSize == confirmed && settings.Master == 73 && settings.Language == "en", "legacy config loads with V-Sync on");
        string blocked = Path.Combine(Path.GetDirectoryName(path)!, "blocked-settings"); Directory.CreateDirectory(blocked);
        settings.UsePathForTests(blocked); settings.SetVolume("effects", 44);
        await Click(Find<Button>(screen, "Settings"));
        Check(Find<Label>(screen, "SettingsMessage").Text.Contains("未能保存"), "write failure visible");
        await KeyPress(screen.GetViewport(), Key.Escape);
        Check(!screen.ModalOpen && Find<Button>(screen, "Settings").HasFocus(), "closing restores navigation focus");
        Check(JsonSerializer.Serialize(save.Data) == beforeSave, "gameplay data unchanged");
        settings.UsePathForTests(path); settings.SetLanguage("zh_CN"); settings.SetVSync(true);
        window.Mode = Window.ModeEnum.Windowed; window.Size = originalSize;
        await Frames(screen);
        GD.Print($"SETTINGS_CHECKS_OK passed={passed} graphical={graphical}");
    }
}
