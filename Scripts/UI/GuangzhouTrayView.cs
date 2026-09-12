using Godot;
using ProjectCake.Guangzhou;
using ProjectCake.Interaction;

namespace ProjectCake.UI;

public partial class GuangzhouTrayView : Control
{
    private readonly RiceRollGesture _gesture = new();
    public bool HasGesture => _gesture.Mode != RiceRollGestureMode.None;
    private bool _movingHandle;
    public RiceRollStateMachine Tray { get; set; } = null!;
    public Func<bool> CanInteract { get; set; } = () => false;
    public Func<bool> SauceSelected { get; set; } = () => false;
    public Action? SauceRequested { get; set; }
    public Action<string>? IngredientDropped { get; set; }
    public Action? Selected { get; set; }
    public Action<string>? Feedback { get; set; }
    public Func<string, bool>? IngredientAllowed { get; set; }
    public int Index { get; set; }
    public bool Active { get; set; }
    public Rect2 Plate => new(24, 76, Size.X - 48, Size.Y - 174);
    public Rect2 Handle => new(Size.X * .3f, Size.Y - 82, Size.X * .4f, 48);
    public void CancelGesture() { _gesture.Cancel(); _movingHandle = false; }
    public override void _GuiInput(InputEvent input)
    {
        if (!CanInteract() || Tray is null) { CancelGesture(); return; }
        if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left } button)
        {
            if (!button.Pressed) { CancelGesture(); AcceptEvent(); return; }
            Selected?.Invoke();
            var mode = RiceRollGestureMode.None;
            _movingHandle = Handle.HasPoint(button.Position);
            if (_movingHandle) mode = Tray.State == RiceRollState.Spreading ? RiceRollGestureMode.Push
                : Tray.State == RiceRollState.Steaming ? RiceRollGestureMode.Pull : RiceRollGestureMode.None;
            else if (Plate.HasPoint(button.Position)) mode = Tray.State switch
            {
                RiceRollState.Spreading => RiceRollGestureMode.Spread,
                RiceRollState.Rolling => RiceRollGestureMode.Roll,
                RiceRollState.Cut when SauceSelected() => RiceRollGestureMode.Sauce,
                _ => RiceRollGestureMode.None,
            };
            if (!_gesture.Begin(mode, Normalize(button.Position), Tray.RollProgress) && mode == RiceRollGestureMode.Roll)
                Feedback?.Invoke("从米皮左边或右边开始，顺着一个方向刮卷。");
            AcceptEvent();
        }
        if (input is InputEventMouseMotion motion && _gesture.Mode != RiceRollGestureMode.None)
        {
            var mode = _gesture.Mode; double progress = _gesture.Move(Normalize(motion.Position));
            if (mode == RiceRollGestureMode.Spread) Tray.Spread(progress);
            else if (mode == RiceRollGestureMode.Roll) Tray.Roll(progress);
            else if (mode == RiceRollGestureMode.Sauce && progress >= .12) { SauceRequested?.Invoke(); CancelGesture(); }
            else if (mode == RiceRollGestureMode.Push && progress >= .18)
            { if (!Tray.TryPush()) Feedback?.Invoke("先把米浆铺至至少65%。"); CancelGesture(); }
            else if (mode == RiceRollGestureMode.Pull && progress >= .18)
            { if (!Tray.TryPull()) Feedback?.Invoke("还未蒸熟，请稍等。"); CancelGesture(); }
            QueueRedraw(); AcceptEvent();
        }
    }
    private Vector2 Normalize(Vector2 p) => (p - Plate.Position) / Plate.Size;
    public override bool _CanDropData(Vector2 atPosition, Variant data)
    {
        // The whole visible tray is a generous drop target; stroke input remains confined to Plate.
        return CanInteract() && data.VariantType == Variant.Type.String && IngredientAllowed?.Invoke(data.AsString()) == true;
    }
    public override void _DropData(Vector2 atPosition, Variant data) { Selected?.Invoke(); IngredientDropped?.Invoke(data.AsString()); }
    public override void _Notification(int what)
    {
        if (what == NotificationDragBegin && _movingHandle) GetViewport().GuiCancelDrag();
    }
    public override void _Draw()
    {
        if (Tray is null) return;
        DrawStyleBox(GuangzhouUi.Style(Active ? new Color("#EFF4E8") : GuangzhouUi.Paper, Active ? 3 : 1), new Rect2(Vector2.Zero, Size));
        var font = GetThemeDefaultFont();
        DrawString(font, new Vector2(24, 38), $"{(Index == 0 ? "左" : "右")}蒸屉", HorizontalAlignment.Left, -1, 26, GuangzhouUi.Ink);
        var plate = Plate;
        DrawStyleBox(GuangzhouUi.Style(new Color("#CDD8CF"), 2), plate);
        if (Tray.State == RiceRollState.Steaming)
        {
            DrawStyleBox(GuangzhouUi.Style(new Color("#ABC1B2")), plate.Grow(-9));
            DrawString(font, plate.Position + new Vector2(22, 65), Tray.Cooked ? "已蒸熟 · 拉下手柄" : $"蒸制中  {Tray.SteamSeconds:0.0}s", HorizontalAlignment.Left, -1, 24, GuangzhouUi.Ink);
            DrawString(font, plate.Position + new Vector2(22, 104), Tray.Quality switch { RiceRollQuality.Dry => "干裂 · 仍可出售", RiceRollQuality.Normal => "轻微过蒸", _ => Tray.Cooked ? "最佳熟度" : "可先处理另一条生产线" }, HorizontalAlignment.Left, -1, 20, GuangzhouUi.Muted);
            // Steam uses plain strokes and follows the running clock, including pauses.
            for (int i = 0; i < 3; i++)
            {
                float x = plate.Position.X + 90 + i * 60;
                DrawPolyline(new[] { new Vector2(x, plate.End.Y - 35), new Vector2(x - 8, plate.End.Y - 60), new Vector2(x + 5, plate.End.Y - 85) }, GuangzhouUi.Paper, 5, true);
            }
        }
        else if (Tray.State != RiceRollState.Empty)
        {
            Color skin = Tray.Quality == RiceRollQuality.Dry ? new("#E9DFCA") : new("#FFFDF2");
            if (Tray.State == RiceRollState.Spreading)
            {
                float coverage = (float)Math.Max(.12, Tray.SpreadProgress);
                var batter = new Rect2(plate.Position + plate.Size * (1 - coverage) * .5f, plate.Size * coverage);
                DrawStyleBox(GuangzhouUi.Style(skin, 0), batter.Grow(-10));
            }
            else
            {
                float roll = Tray.State == RiceRollState.Rolling ? (float)Tray.RollProgress : 1;
                var sheet = plate.Grow(-14); sheet.Size = new Vector2(sheet.Size.X * (1 - roll), sheet.Size.Y);
                if (sheet.Size.X > 1) DrawRect(sheet, skin);
                var rolled = new Rect2(plate.Position + new Vector2(30 + (plate.Size.X - 100) * roll, 25), new Vector2(52, plate.Size.Y - 50));
                DrawStyleBox(GuangzhouUi.Style(skin, 1), rolled);
                if (Tray.Broken || Tray.Quality == RiceRollQuality.Dry) DrawLine(rolled.Position + new Vector2(0, 55), rolled.Position + new Vector2(52, 67), GuangzhouUi.Gold, 5);
                if (Tray.State is RiceRollState.Cut or RiceRollState.Ready)
                    for (int i = 1; i <= 3; i++) DrawLine(rolled.Position + new Vector2(0, rolled.Size.Y * i / 4), rolled.Position + new Vector2(52, rolled.Size.Y * i / 4), GuangzhouUi.Line, 3);
                if (Tray.SauceApplied) DrawLine(rolled.Position + new Vector2(23, 8), rolled.End - new Vector2(21, 8), new Color("#98603C"), 7, true);
            }
            int n = 0;
            foreach (var id in Tray.Ingredients)
            {
                DrawCircle(plate.Position + new Vector2(42 + n * 76, 45), 12, id == GuangzhouRules.Egg ? new("#E9BD5A") : id == GuangzhouRules.Shrimp ? new("#DD9480") : new("#B07D6A"));
                DrawString(font, plate.Position + new Vector2(24 + n++ * 76, 82), GuangzhouRules.Name(id), HorizontalAlignment.Left, -1, 18, GuangzhouUi.Ink);
            }
        }
        else DrawString(font, plate.Position + new Vector2(24, 100), "将米浆拖到这里", HorizontalAlignment.Left, -1, 25, GuangzhouUi.Muted);
        var handle = Handle;
        if (Tray.PoppedOut) handle.Position += new Vector2(0, 12);
        DrawStyleBox(GuangzhouUi.Style(GuangzhouUi.Green), handle);
        DrawString(font, handle.Position + new Vector2(12, 32), Tray.State == RiceRollState.Steaming ? "向下拉出 ↓" : "向上推进 ↑", HorizontalAlignment.Left, -1, 20, GuangzhouUi.Paper);
        string progressText = Tray.State switch
        {
            RiceRollState.Spreading => $"铺浆 {Tray.SpreadProgress:P0} · 65%可加料",
            RiceRollState.Rolling => $"刮卷 {Tray.RollProgress:P0} · 75%可切段",
            RiceRollState.Cut => "选择豉油壶，在米皮上短划",
            RiceRollState.Ready => "已装盘 · 可以交付", _ => "",
        };
        DrawString(font, new Vector2(24, Size.Y - 10), progressText, HorizontalAlignment.Left, Size.X - 40, 19, GuangzhouUi.Muted);
    }
}
