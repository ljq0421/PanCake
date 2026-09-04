using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class VisualCapture : Node
{
    public override async void _Ready()
    {
        string[] args = OS.GetCmdlineUserArgs();
        bool captureRunning = OS.GetCmdlineUserArgs().Contains("--capture-running", StringComparer.Ordinal);
        bool captureDay = captureRunning || OS.GetCmdlineUserArgs().Contains("--capture-day", StringComparer.Ordinal);
        int phase4Day = args.Contains("--capture-day5", StringComparer.Ordinal) ? 5
            : args.Contains("--capture-day9", StringComparer.Ordinal) ? 9
            : args.Contains("--capture-day15", StringComparer.Ordinal) ? 15 : 0;
        bool captureMap = args.Contains("--capture-map", StringComparer.Ordinal);
        string? temporarySave = null;
        if (phase4Day > 0 || captureMap)
        {
            temporarySave = $"user://visual-capture-{Guid.NewGuid():N}.json";
            GetNode<SaveService>("/root/SaveService").UsePathForTests(temporarySave);
        }

        if (captureDay || phase4Day > 0)
        {
            Node main = GetNode("../Main");
            var dayScreen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            var controller = main.GetNode<DayController>("DayController");
            int day = phase4Day > 0 ? phase4Day : 1;
            var captureSave = GetNode<SaveService>("/root/SaveService");
            if (day == 15)
            {
                captureSave.Data.PurchasedStoveLevel = 3;
                captureSave.Data.PurchasedIngredientStationLevel = 3;
                captureSave.Data.PurchasedFryerLevel = 3;
            }
            dayScreen.Initialize(GetNode<DataCatalog>("/root/DataCatalog"), captureSave, controller, day);
            foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Visible = screen == dayScreen;
            if (captureRunning || phase4Day > 0)
            {
                controller.TryStartDay(out _);
                controller.Tick(3);
                int steps = phase4Day == 15 ? 420 : 30;
                for (int step = 0; step < steps; step++) controller.Tick(.1);
            }
        }
        else if (captureMap)
        {
            Node main = GetNode("../Main");
            var save = GetNode<SaveService>("/root/SaveService");
            DataCatalog catalog = GetNode<DataCatalog>("/root/DataCatalog");
            DayConfig config = catalog.DaysByNumber[15];
            DayPlan plan = new OrderGenerator().Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
            save.CommitDay(new DayResult { Day = 15, PlannedCustomers = 26, CompletedCustomers = 24, PerfectOrders = 15, Satisfaction = 90 }, plan, config);
            var map = main.GetNode<TianjinMapScreen>("UI/TianjinMapScreen");
            foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Visible = screen == map;
        }
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree().CreateTimer(0.25), SceneTreeTimer.SignalName.Timeout);
        Image image = GetViewport().GetTexture().GetImage();
        string output = phase4Day > 0 ? $"res://.godot/phase4_day{phase4Day}.png"
            : captureMap ? "res://.godot/phase4_map.png"
            : captureRunning ? "res://.godot/phase3_running.png" : captureDay ? "res://.godot/phase3_day.png" : "res://.godot/phase4_hub.png";
        Error error = image.SavePng(ProjectSettings.GlobalizePath(output));
        if (error != Error.Ok)
        {
            GD.PushError($"视觉录帧保存失败：{error}");
            GetTree().Quit(1);
            return;
        }

        GD.Print($"视觉录帧已保存：{output}");
        if (temporarySave is not null)
        {
            string absolute = ProjectSettings.GlobalizePath(temporarySave);
            if (File.Exists(absolute)) File.Delete(absolute);
        }
        GetTree().Quit(0);
    }
}
