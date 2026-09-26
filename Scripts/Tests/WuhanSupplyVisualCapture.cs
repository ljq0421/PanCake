using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class WuhanSupplyVisualCapture : Node
{
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--720");
            bool basic = OS.GetCmdlineUserArgs().Contains("--basic");
            GetWindow().Size = small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService();
            save.UsePathForTests($"user://wuhan-supply-capture-{Guid.NewGuid():N}.json");
            AddChild(save);
            save.Data.Wuhan.HighestUnlockedDay = 12;
            if (!basic) save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 1;
            foreach (string action in new[] { "take:noodles", "raise:noodles", "pour:noodles", "mix:noodles",
                "deliver:hot_dry_noodles", "deliver:doupi", "doupi:batter", "doupi:egg", "doupi:flip",
                "doupi:filling", "doupi:cut", "discard" }.Concat(WuhanWorkstationView.IngredientIds.Select(id => "take:" + id)))
                save.Data.Wuhan.LearnedWorkbenchActions.Add(action);
            var controller = new DayController(); AddChild(controller);
            var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
            AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
            if (!screen.Initialize(catalog, save, controller, basic ? 1 : 8)) throw new InvalidOperationException("Wuhan supply capture initialization failed");
            if (!controller.TryStartDay(out string startError)) throw new InvalidOperationException(startError);
            screen._Process(3.1);
            var bellView = screen.Workstation.GetNode<Button>("SupplyBell");
            var npcView = screen.Workstation.GetNode<Sprite2D>("SupplyHelper");
            GD.Print($"WUHAN_SUPPLY_GEOMETRY bell={bellView.Size} artScale={bellView.GetNode<Sprite2D>("BellArtwork").Scale} npcScale={npcView.Scale} source={npcView.Texture.GetSize()}");
            bool npcOnly = OS.GetCmdlineUserArgs().Contains("--npc-only");
            string? outputDirectory = OS.GetCmdlineUserArgs().FirstOrDefault(arg => arg.StartsWith("--output-dir=", StringComparison.Ordinal));
            string directory = outputDirectory is not null ? outputDirectory["--output-dir=".Length..] : ProjectSettings.GlobalizePath(npcOnly
                ? "res://wuhan-supply-check/npc-align-capture" : "res://wuhan-supply-check/continuous-capture");
            Directory.CreateDirectory(directory);
            async Task Shot(string name)
            {
                GetViewport().PushInput(new InputEventMouseMotion { Position = new Vector2(1200, 300) }, true);
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                if (!screen.Workstation.StockArtworkReady) throw new InvalidOperationException($"Stock artwork is incomplete in {name}");
                string path = Path.Combine(directory, $"{(small ? 720 : 1080)}-{(basic ? "basic" : "doupi")}-{name}.png");
                Error error = GetViewport().GetTexture().GetImage().SavePng(path);
                if (error != Error.Ok) throw new IOException($"Capture failed: {path}: {error}");
                using Image viewport = GetViewport().GetTexture().GetImage();
                float scale = viewport.GetWidth() / 1920f;
                using Image detail = viewport.GetRegion(new Rect2I((int)(480 * scale), (int)(790 * scale),
                    (int)(710 * scale), (int)(215 * scale)));
                string detailPath = Path.Combine(directory, $"{(small ? 720 : 1080)}-{(basic ? "basic" : "doupi")}-{name}-detail.png");
                if (detail.SavePng(detailPath) != Error.Ok) throw new IOException($"Detail capture failed: {detailPath}");
                GD.Print($"WUHAN_SUPPLY_CAPTURE {path}");
            }
            if (npcOnly)
            {
                GetWindow().GrabFocus();
                screen._Notification((int)NotificationApplicationFocusIn);
                Button npcClick = screen.Workstation.GetNode<Button>("SupplyNpcButton");
                void Click(Control control, MouseButton button = MouseButton.Left)
                {
                    Vector2 point = control.GetGlobalTransformWithCanvas() * (control.Size / 2);
                    GetViewport().PushInput(new InputEventMouseMotion { Position = point }, true);
                    GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = button, Pressed = true, Position = point }, true);
                    GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = button, Pressed = false, Position = point }, true);
                }
                void Require(bool valid, string message)
                {
                    if (!valid) throw new InvalidOperationException(message);
                }
                await Shot("idle");
                Click(bellView); screen.Workstation.Tick(.3);
                Require(npcClick.Visible, "Full-stock bell must summon NPC through real input");
                await Shot("full-called");
                Click(bellView); screen.Workstation.Tick(.08);
                Require(npcClick.Visible, "Repeated bell must keep NPC visible");
                await Shot("repeated-bell");
                Click(npcClick, MouseButton.Right);
                Require(npcClick.Visible, "Right click must not dismiss NPC");
                GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
                GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = false }, true);
                Require(!npcClick.Visible, "Esc must dismiss NPC");
                string[] active = WuhanWorkstationView.IngredientIds
                    .Where(id => screen.Workstation.AllowedIngredients?.Contains(id) != false).ToArray();
                foreach (string id in active) screen.Ingredients.TryConsume(id);
                screen.Workstation.RefreshRefillControls();
                Click(bellView); screen.Workstation.Tick(.3);
                await Shot("missing-called");
                foreach (string _ in active) Click(npcClick);
                Require(active.All(id => screen.Ingredients.Count(id) == 8), "Real NPC clicks must refill each ingredient exactly once");
                screen.Workstation.Tick(.16);
                Require(npcClick.Visible, "NPC must remain while food drops");
                await Shot("drops");
                screen.Workstation.Tick(.83);
                Require(npcClick.Visible, "NPC must stay for one full second");
                screen.Workstation.Tick(.02);
                Require(!npcClick.Visible, "NPC must leave after one second");
                await Shot("finished");
                screen.Ingredients.TryConsume(active[0]);
                Click(bellView); Click(npcClick);
                screen._Notification((int)NotificationApplicationFocusOut);
                Require(!npcClick.Visible && screen.Ingredients.Count(active[0]) == 8,
                    "Focus loss must clean presentation without losing supplied stock");
                Require(!screen.Workstation.GetChildren().OfType<TextureRect>().Any(node => node.Name.ToString().StartsWith("SupplyDrop_") && node.Visible),
                    "Focus loss must remove food drops");
                GD.Print("WUHAN_SUPPLY_NPC_CAPTURE_RESULT failed=0");
                GetTree().Quit();
                return;
            }
            await Shot("full");
            foreach (int remaining in new[] { 6, 4, 2, 0 })
            {
                foreach (string id in WuhanWorkstationView.IngredientIds)
                    while (screen.Ingredients.Count(id) > remaining) screen.Ingredients.TryConsume(id);
                screen.Workstation.RefreshRefillControls();
                await Shot($"stock-{remaining}");
            }
            // Visual order is base / chili / scallion / beef, while IngredientIds
            // uses base / scallion / chili / beef. Exercise independent states.
            int[] mixed = { 0, 6, 2, 8 };
            for (int i = 0; i < mixed.Length; i++)
            {
                string id = WuhanWorkstationView.IngredientIds[i];
                for (int portion = 0; portion < mixed[i]; portion++) screen.Ingredients.TryRefillOne(id);
            }
            screen.Workstation.RefreshRefillControls();
            await Shot("mixed");
            string seasoning = StableIds.Ingredients.WuhanBaseSeasoning;
            screen.Workstation.GetNode<Button>("SupplyBell").EmitSignal(Button.SignalName.Pressed);
            screen.Workstation.Tick(.3);
            await ToSignal(GetTree().CreateTimer(.3), SceneTreeTimer.SignalName.Timeout);
            await Shot("npc");
            Button npcButton = screen.Workstation.GetNode<Button>("SupplyNpcButton");
            // Other desktop test windows may steal focus during GPU capture.
            // Establish the focused state before exercising this window's input.
            GetWindow().GrabFocus();
            screen._Notification((int)NotificationApplicationFocusIn);
            if (!screen.Workstation.SupplySelecting)
                screen.Workstation.GetNode<Button>("SupplyBell").EmitSignal(Button.SignalName.Pressed);
            Vector2 target = npcButton.GetGlobalTransformWithCanvas() * (npcButton.Size / 2);
            // Push viewport coordinates directly, bypassing the OS/window stretch transform.
            GetViewport().PushInput(new InputEventMouseMotion { Position = target }, true);
            GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = target }, true);
            GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = target }, true);
            if (screen.Ingredients.Count(seasoning) != 1) throw new InvalidOperationException($"Real NPC click did not add exactly one portion: count={screen.Ingredients.Count(seasoning)}, visible={npcButton.Visible}, canInteract={screen.Workstation.CanInteract?.Invoke()}");
            for (int i = 1; i < mixed.Length; i++)
                if (screen.Ingredients.Count(WuhanWorkstationView.IngredientIds[i]) != mixed[i])
                    throw new InvalidOperationException("Replenishing base seasoning changed another ingredient");
            await Shot("one-portion");
            GD.Print("WUHAN_SUPPLY_CAPTURE_RESULT passed=8 failed=0");
            GetTree().Quit();
        }
        catch (Exception exception)
        {
            GD.PushError(exception.ToString());
            GD.Print("WUHAN_SUPPLY_CAPTURE_RESULT passed=0 failed=1");
            GetTree().Quit(1);
        }
    }
}
