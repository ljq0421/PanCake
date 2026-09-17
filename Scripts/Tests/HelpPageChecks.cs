using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Shared targeted checks, invoked by both existing UI test scenes with --help-only.</summary>
internal static class HelpPageChecks
{
    internal static async Task Run(StartScreen screen, SaveService save, JourneySettings settings, Func<string, Task> capture)
    {
        void Check(bool value, string message)
        {
            if (!value) throw new InvalidOperationException(message);
            GD.Print("PASS help: " + message);
        }
        async Task Frames(int count = 4)
        {
            for (int i = 0; i < count; i++) await screen.ToSignal(screen.GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        T Find<T>(string name) where T : Control => screen.Descendants<T>().First(c => c.Name == name && c.IsVisibleInTree());
        async Task Click(Control target)
        {
            Vector2 p = target.GetGlobalTransformWithCanvas() * (target.Size / 2);
            screen.GetViewport().PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
            screen.GetViewport().PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = true }, true);
            await Frames(1);
            screen.GetViewport().PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = false }, true);
            await Frames();
        }
        async Task KeyPress(Key key)
        {
            screen.GetViewport().PushInput(new InputEventKey { Keycode = key, Pressed = true }, true);
            screen.GetViewport().PushInput(new InputEventKey { Keycode = key, Pressed = false }, true);
            await Frames();
        }
        void CheckText(bool english)
        {
            foreach (var label in Find<Control>("HelpContent").Descendants<Label>())
            {
                string translated = label.Tr(label.Text).ToString();
                if (english && translated.Any(c => c >= '\u4e00' && c <= '\u9fff'))
                    throw new InvalidOperationException("Untranslated help text: " + label.Name);
                if (label.HasMeta("help_text_size"))
                {
                    Vector2 bounds = label.GetMeta("help_text_size").AsVector2();
                    if (label.Size.X > bounds.X + 1 || label.Size.Y > bounds.Y + 1)
                        throw new InvalidOperationException($"Help text overflow: {label.Name} {label.Size} exceeds {bounds}");
                }
            }
            Check(true, "all help labels fit and resolve selected language");
        }

        screen.PresentHome(); await Frames();
        await Click(Find<Button>("Help"));
        await capture("help-home");
        await KeyPress(Key.Escape);
        if (!save.CanContinue)
        {
            await Click(Find<Button>("Help"));
            Check(Find<Panel>("HelpCityTips").GetMeta("city_id").AsString() == StableIds.Cities.Tianjin, "missing save uses Tianjin");
            await KeyPress(Key.Escape);
            Check(save.ResetProgress(out _), "isolated test save created");
        }
        var cities = JourneyModel.Cities.Where(c => !save.IsDemo || save.ChapterLength(c.Id) > 0).ToArray();
        foreach (var city in cities) save.Data.UnlockedCityIds.Add(city.Id);
        foreach (bool english in new[] { false, true })
        {
            settings.SetLanguage(english ? "en" : "zh_CN");
            foreach (var city in cities)
            {
                screen.PresentCity(city.Id); await Frames();
                string before = JsonSerializer.Serialize(save.Data);
                var previousFocus = Find<Button>("Help");
                await Click(previousFocus);
                Check(Find<Panel>("HelpCityTips").GetMeta("city_id").AsString() == city.Id, "city context " + city.Id);
                Check(Find<Label>("HelpTitle").Text == "一本早餐旅行手册", "shared guide title");
                Check(Find<Button>("Close").HasFocus(), "close initially focused");
                Check(screen.Descendants<Button>().Any(b => b.Name == "MusicCredits" && b.IsVisibleInTree()), "both profiles expose music credits");
                CheckText(english);
                await capture("help-" + city.Id.Replace(':', '-') + (english ? "-en" : "-zh"));
                await Click(Find<Panel>("HelpJourneyNew"));
                Check(screen.ModalOpen && !screen.ConfirmationOpen, "journey card is informational");
                await KeyPress(Key.Tab);
                Check(screen.GetNode<Control>("Canvas/Modal").IsAncestorOf(screen.GetViewport().GuiGetFocusOwner()), "Tab stays in modal");
                Find<Button>("Close").GrabFocus(); await KeyPress(Key.Enter);
                Check(!screen.ModalOpen && screen.GetViewport().GuiGetFocusOwner() == previousFocus, "Enter closes and restores page focus");
                Check(JsonSerializer.Serialize(save.Data) == before, "help never mutates save");
            }
        }
        // A stale selected city must not win over the resume city on Home.
        save.Data.LastVisitedCityId = StableIds.Cities.Wuhan;
        screen.PresentHome(); await Frames();
        await Click(Find<Button>("Help"));
        Check(Find<Panel>("HelpCityTips").GetMeta("city_id").AsString() == StableIds.Cities.Wuhan, "home follows resume city");
        {
            await Click(Find<Button>("MusicCredits"));
            Check(Find<Label>("CreditsTitle").Text == "配乐与署名", "credits remain reachable");
            await KeyPress(Key.Escape);
            await Click(Find<Button>("Help"));
        }
        await KeyPress(Key.Escape);
        Check(!screen.ModalOpen && Find<Button>("Help").HasFocus(), "Escape restores page focus");
        await Click(Find<Button>("Help")); await Click(Find<Button>("Close"));
        Check(!screen.ModalOpen, "mouse closes guide");
    }
}
