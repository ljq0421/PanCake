using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Shared Main-scene subscribers must not intercept another city's settlement.</summary>
public partial class WuhanClosingSelfTest : Node
{
    public override void _Ready()
    {
        string path = $"res://.tmp/wuhan-closing-{Guid.NewGuid():N}.json";
        Node? main = null;
        try
        {
            var save = GetNode<SaveService>("/root/SaveService");
            save.UsePathForTests(path);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate();
            AddChild(main);
            var controller = main.GetNode<DayController>("DayController");
            var wuhan = main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen");
            var tianjin = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Hide();

            // Direct Wuhan entry leaves Tianjin's save reference uninitialized.
            wuhan.Initialize(catalog, save, controller, 7);
            wuhan.Show();
            wuhan.BeginDay();
            controller.Tick(DayController.OpeningDurationSeconds);
            controller.Ledger!.RecordDelivery(new DeliveryEvaluation(DeliveryGrade.Correct, 13, 0, 80, "test"));
            wuhan.RefreshForCapture();
            Check(wuhan.CoinTray.PendingAmount == 13, "uncollected 13 yuan fixture");
            Finish(controller);
            Check(wuhan.FindButton("收好收入 · 返回武汉经营首页").IsVisibleInTree(), "Wuhan results visible");
            Check(save.Data.Wuhan.DayBestRecords[7].TotalRevenue == 13 && save.Data.Coins == 13,
                "uncollected revenue committed once");
            Check(save.Data.Tianjin.DayBestRecords.Count == 0, "Tianjin progress untouched");
            bool returned = false;
            wuhan.HubRequested += () => returned = true;
            wuhan.FindButton("收好收入 · 返回武汉经营首页").EmitSignal(Button.SignalName.Pressed);
            Check(returned && main.GetNode<WuhanHub>("UI/WuhanHub").IsVisibleInTree(), "return to Wuhan hub");

            // A later Tianjin day must still settle normally (no poisoned _committed flag).
            tianjin.Initialize(catalog, save, controller, 1);
            tianjin.Show();
            tianjin.BeginDay();
            controller.Tick(DayController.OpeningDurationSeconds);
            Finish(controller);
            Check(save.Data.Tianjin.DayBestRecords.ContainsKey(1), "Tianjin can still settle");

            // Also cover a previously initialized, abandoned Tianjin day before Wuhan.
            tianjin.Initialize(catalog, save, controller, 1);
            tianjin.BeginDay();
            controller.AbandonDay();
            tianjin.Hide();
            wuhan.Initialize(catalog, save, controller, 7);
            wuhan.Show();
            wuhan.BeginDay();
            controller.Tick(DayController.OpeningDurationSeconds);
            controller.Ledger!.RecordDelivery(new DeliveryEvaluation(DeliveryGrade.Correct, 20, 0, 80, "test"));
            Finish(controller);
            Check(wuhan.FindButton("收好收入 · 返回武汉经营首页").IsVisibleInTree(), "repeat Wuhan results visible");
            var resultText = wuhan.FindChildren("*", "RichTextLabel", true, false).OfType<RichTextLabel>();
            Check(resultText.Any(label => label.Text.Contains("永久金币增加 ¥7")), "Wuhan owns the best-record gain");
            Check(save.Data.Coins == 20, "only best-record difference awarded");
            GD.Print("WUHAN_CLOSING_RESULT passed=true");
            GetTree().Quit();
        }
        catch (Exception e)
        {
            GD.PushError(e.ToString());
            GD.Print("WUHAN_CLOSING_RESULT passed=false");
            GetTree().Quit(1);
        }
        finally
        {
            main?.Free();
            string absolute = ProjectSettings.GlobalizePath(path);
            if (File.Exists(absolute)) File.Delete(absolute);
        }
    }

    private static void Finish(DayController controller)
    {
        controller.Tick(controller.CurrentConfig!.DurationSeconds);
        controller.Tick(DayController.ClosingDurationSeconds);
        Check(controller.State == DayState.Results, "day reaches Results");
        controller.Tick(1);
    }

    private static void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        GD.Print($"PASS {message}");
    }
}
