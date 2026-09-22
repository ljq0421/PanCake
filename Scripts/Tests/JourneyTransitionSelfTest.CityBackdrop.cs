using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class JourneyTransitionSelfTest
{
    private async Task CityBackdropChecks(SaveService save)
    {
        string[] cities = ExperienceProfile.IsDemo ? new[] { "tianjin", "wuhan" }
            : new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" };
        foreach (string city in cities)
        {
            string id = "city:" + city;
            save.Data.UnlockedCityIds.Add(id);
            save.Data.GetCity(id).HighestUnlockedDay = 12;
            Check(_main.StartCityBusiness(id, 11), city + " starts day 11");
            await Complete();
            var screen = _main.GetNode("UI").GetChildren().OfType<Control>()
                .Single(c => c.Visible && c != _home);
            var originalMode = screen.ProcessMode;
            var controller = _main.GetNode<DayController>("DayController");
            if (screen is YangzhouDayScreen yangzhou) { yangzhou.Session.Tick(1000); yangzhou._Process(0); }
            else { controller.Tick(1000); controller.Tick(1000); }
            await Complete();
            var book = screen.Descendants<BusinessDetailsView>().Single();
            Check(book.Visible && book.Model.Closing && book.Model.CanClose, city + " actual settlement saved");
            await Capture("backdrop-" + city + "-settlement");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            await Complete();
            Check(_home.Page == JourneyPage.City && !book.Visible, city + " Escape returns to chapter");
            Check(screen.Visible && screen.ProcessMode == ProcessModeEnum.Disabled, city + " scene stays visible and inactive");
            Check(screen.MouseBehaviorRecursive == Control.MouseBehaviorRecursiveEnum.Disabled
                && screen.FocusBehaviorRecursive == Control.FocusBehaviorRecursiveEnum.Disabled, city + " scene cannot receive input");
            Check(!_home.GetNode<Control>("Canvas/Background").Visible && !_home.GetNode<Control>("Letterbox").Visible,
                city + " home artwork hidden");
            await Capture("backdrop-" + city + "-chapter");
            _home.PresentLedger(); await Complete();
            Check(screen.Visible && !_home.GetNode<Control>("Canvas/Background").Visible, city + " ledger retains scene");
            _home.PresentUpgrades(); await Complete();
            Check(screen.Visible && !_home.GetNode<Control>("Canvas/Background").Visible, city + " upgrades retain scene");
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            await Complete();
            if (city == "wuhan")
            {
                GetWindow().Size = new(1920, 1080); await Frames();
                await Capture("backdrop-wuhan-chapter-1920");
                GetWindow().Size = new(1280, 720); await Frames();
            }
            FindButton("OpenBusiness").EmitSignal(BaseButton.SignalName.Pressed);
            await Complete();
            Check(screen.Visible && screen.ProcessMode == originalMode && !_home.Visible, city + " gameplay processing restored");
            if (screen is YangzhouDayScreen nextYangzhou) { nextYangzhou.Session.Tick(1000); nextYangzhou._Process(0); }
            else { controller.Tick(1000); controller.Tick(1000); }
            await Complete();
            // This day may queue a first chapter completion. Both exits must retain the same scene.
            if (city == "wuhan") save.QueueJourneyCompletion(id);
            GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
            await Complete();
            if (_home.Page == JourneyPage.Completion)
            {
                Check(screen.Visible && !_home.GetNode<Control>("Canvas/Background").Visible, city + " completion retains scene");
                GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
                await Complete();
            }
            if (city == "wuhan")
            {
                _home.PresentCity(StableIds.Cities.Tianjin); await Complete();
                Check(!screen.Visible && _home.GetNode<Control>("Canvas/Background").Visible, "changing cities releases Wuhan backdrop");
            }
            _home.PresentHome(); await Complete();
            Check(!screen.Visible && screen.ProcessMode == originalMode && _home.GetNode<Control>("Canvas/Background").Visible,
                city + " home releases scene and restores home background");
        }
    }
}
