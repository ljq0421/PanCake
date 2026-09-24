using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

// Reproducible engine movie: controlled initial cooked pancake, then real input events.
public partial class TianjinDirectFoodCapture : Node
{
    private PancakeWorkstation? _station;
    private PancakeCanvas _canvas = null!;
    private TianjinDayScreen _screen = null!;
    private CapturePointer _pointer = null!;
    private Label _caption = null!;
    private Vector2 _mouse;
    private bool _down;
    public override void _Process(double delta) => _station?.Tick(delta);
    private async Task Wait(int frames)
    {
        for (int i = 0; i < frames; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    private Vector2 Food(float x, float y = .5f) => _canvas.GetGlobalTransformWithCanvas()
        * (_canvas.GetSurfaceRect().Position + _canvas.GetSurfaceRect().Size * new Vector2(x, y));
    private void Move(Vector2 point)
    {
        Input.ParseInputEvent(new InputEventMouseMotion { Position = GetViewport().GetFinalTransform() * point, Relative = point - _mouse,
            ButtonMask = _down ? MouseButtonMask.Left : 0 });
        Input.FlushBufferedEvents(); _mouse = point; _pointer.Position = point; _pointer.QueueRedraw();
    }
    private void Press(bool down)
    {
        // The recorder is offscreen; restore application focus before synthetic input.
        if (down) _screen._Notification((int)NotificationApplicationFocusIn);
        _down = down; _pointer.Held = down; _pointer.QueueRedraw();
        Input.ParseInputEvent(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = down, Position = GetViewport().GetFinalTransform() * _mouse });
        Input.FlushBufferedEvents();
    }
    private async Task Travel(Vector2 target, int frames)
    {
        Vector2 from = _mouse;
        for (int i = 1; i <= frames; i++) { Move(from.Lerp(target, Mathf.SmoothStep(0, 1, (float)i / frames))); await Wait(1); }
    }
    private void Require(PancakeState state)
    {
        if (_station!.Machine.Runtime.State != state) throw new Exception($"Capture expected {state}, got {_station.Machine.Runtime.State}");
    }
    public override async void _Ready()
    {
        try
        {
            GetWindow().Position = new Vector2I(-10000, -10000);
            GetWindow().Size = new Vector2I(1920, 1080);
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests("res://artifacts/tianjin-direct-food-video/settings.cfg"); InterfaceLessons.MarkAllSeen(settings);
            var save = new SaveService(); save.UsePathForTests("res://artifacts/tianjin-direct-food-video/save.json"); AddChild(save);
            save.Data.PurchasedStoveLevel = 3;
            var controller = new DayController(); AddChild(controller);
            var screen = GD.Load<PackedScene>("res://Scenes/Gameplay/TianjinDayScreen.tscn").Instantiate<TianjinDayScreen>();
            _screen = screen;
            AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller);
            screen.Initialize(GetNode<DataCatalog>("/root/DataCatalog"), save, controller, 1);
            screen.BeginDay(); controller.Tick(3.1); screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
            _station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
            _station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions);
            _canvas = _station.Descendants<PancakeCanvas>().Single();
            _station.Machine.Runtime.State = PancakeState.SideAReady;
            _station.Machine.Runtime.HasEgg = true; _station.RefreshForCapture();
            var overlay = new CanvasLayer { Layer = 100 }; AddChild(overlay);
            var panel = new Panel { Position = new Vector2(28, 26), Size = new Vector2(650, 92), MouseFilter = Control.MouseFilterEnum.Ignore };
            panel.AddThemeStyleboxOverride("panel", new StyleBoxFlat { BgColor = new Color(.16f, .085f, .04f, .93f),
                CornerRadiusTopLeft = 16, CornerRadiusTopRight = 16, CornerRadiusBottomLeft = 16, CornerRadiusBottomRight = 16 });
            overlay.AddChild(panel);
            _caption = new Label { Position = new Vector2(22, 12), Size = new Vector2(610, 68), MouseFilter = Control.MouseFilterEnum.Ignore };
            _caption.AddThemeFontSizeOverride("font_size", 26); panel.AddChild(_caption);
            _pointer = new CapturePointer(); overlay.AddChild(_pointer);
            _caption.Text = "天津煎饼 · 实际操作演示\n光圈表示鼠标位置，实心表示按住左键";
            Move(Food(.5f)); await Wait(100);
            _caption.Text = "① 翻面：点击饼皮\n铲子托起，软饼翻转落回";
            Press(true); Press(false); await Wait(80); Require(PancakeState.SideBReady);
            if (OS.GetCmdlineUserArgs().Contains("--flip-only"))
            {
                _caption.Text = "新版翻面：饼边先起，中间自然下垂\n落锅时中间先接触，边缘随后回落";
                await Wait(90);
                GD.Print("DIRECT_FOOD_CAPTURE_OK"); GetTree().Quit(); return;
            }
            _caption.Text = "接着刷酱，为折叠做准备\n按住鼠标划动，按 F 收刷";
            var sauce = (Button)_station.FindChild("IngredientInput_sauce", true, false);
            await Travel(sauce.GetGlobalRect().GetCenter(), 35); Press(true); await Wait(4); Press(false); await Wait(15);
            Require(PancakeState.Saucing);
            await Travel(Food(.2f, .35f), 28); Press(true);
            await Travel(Food(.8f, .35f), 45); await Travel(Food(.8f, .6f), 12);
            await Travel(Food(.2f, .6f), 45); Press(false);
            Input.ParseInputEvent(new InputEventKey { Keycode = Key.F, Pressed = true }); Input.FlushBufferedEvents();
            Input.ParseInputEvent(new InputEventKey { Keycode = Key.F, Pressed = false }); Input.FlushBufferedEvents();
            await Wait(45); Require(PancakeState.Sauced);
            _caption.Text = "② 折叠：抓住一侧饼边，向对侧拖\n饼皮随手弯曲，松手贴合";
            await Travel(Food(.1f), 28); Press(true); await Travel(Food(.64f), 90); await Wait(20); Press(false);
            await Wait(65); Require(PancakeState.Folded);
            _caption.Text = "③ 套袋：从左侧纸袋叠取出一张\n未拖到煎饼上，纸袋会回到原位";
            Vector2 stack = _station.GetGlobalTransformWithCanvas() * _station.BagStackBounds.GetCenter();
            await Travel(stack, 35); Press(true); await Travel(stack + new Vector2(-80, -80), 45); await Wait(20); Press(false); await Wait(65);
            Require(PancakeState.Folded);
            _caption.Text = "把纸袋拖到炉面煎饼上\n松手后从下端套入，露出饼的上沿";
            await Travel(stack, 30); Press(true);
            Vector2 mouth = Food(.5f, .45f);
            await Travel(mouth, 85); await Wait(35); Press(false); await Wait(65);
            Require(PancakeState.Bagged);
            _caption.Text = "套袋完成，从炉面拖给顾客\n翻面、折叠、装袋也都保留 F 键辅助";
            await Travel(mouth + new Vector2(-80, -60), 30); await Wait(110);
            GD.Print("DIRECT_FOOD_CAPTURE_OK"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }

    private partial class CapturePointer : Node2D
    {
        public bool Held;
        public override void _Draw()
        {
            DrawCircle(Vector2.Zero, 16, new Color(0, 0, 0, .3f));
            if (Held) DrawCircle(Vector2.Zero, 10, new Color("#ffcc58"));
            DrawArc(Vector2.Zero, 13, 0, Mathf.Tau, 48, Colors.White, 2.5f, true);
            DrawLine(new Vector2(-5, 0), new Vector2(5, 0), Colors.White, 2, true);
            DrawLine(new Vector2(0, -5), new Vector2(0, 5), Colors.White, 2, true);
        }
    }
}
