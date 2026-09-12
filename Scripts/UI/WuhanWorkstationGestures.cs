using Godot;
using ProjectCake.Data;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    public event Action<string>? GestureRejected;
    public Func<int, bool>? RaiseRequested, PourRequested;
    public Func<DoupiCutLine, bool>? CutRequested;
    private string _gesture = "";
    private Vector2 _gestureStart, _gesturePoint, _gesturePrevious;
    private DoupiCutStroke? _cutStroke;
    private bool _fillingDeposited;
    private float _flipLift;
    private float _gestureTravel, _maximumExcursion;
    private int _gestureBasket;
    private Vector2? _rawDropOrigin;
    private bool _cutCommitted;
    private Vector2 _pointer = new(-1000, -1000);
    public bool HasProductionGesture => _gesture.Length > 0;

    private bool TryBeginGesture(string hit, Vector2 point)
    {
        string gesture = "";
        if (hit == "raw" && _ingredients.CanUse(StableIds.Ingredients.WuhanNoodles)) gesture = "raw";
        else if (hit.StartsWith("basket"))
        {
            _gestureBasket = int.Parse(hit[^1..]);
            if (Busy(hit) || _cooker.PendingPourBasket == _gestureBasket) return false;
            if (_cooker.Baskets[_gestureBasket].State is NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked
                or NoodleBasketState.Raised or NoodleBasketState.Draining or NoodleBasketState.Drained) gesture = "basket";
        }
        else if (hit == "batter" && _doupi is not null && !Busy("pan")) gesture = "batter";
        else if (hit == "filling" && _doupi is not null && !Busy("pan")) gesture = "filling";
        else if (hit == "pan" && NearPan(point) && !Busy("pan")) gesture = _doupi?.State switch {
            DoupiState.Spreading => "spread", DoupiState.ReadyToFlip => "flip", DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting => "cut", _ => "" };
        if (gesture.Length == 0) return false;
        EndMix(); _gesture = gesture; _gestureStart = _gesturePoint = _gesturePrevious = point;
        _gestureTravel = _maximumExcursion = 0; _cutCommitted = false;
        _cutStroke = gesture == "cut" ? new DoupiCutStroke(SurfacePoint(point)) : null;
        _fillingDeposited = gesture == "spread";
        if (gesture == "spread") SpreadRequested?.Invoke(SurfacePoint(point), SurfacePoint(point));
        QueueRedraw(); return true;
    }

    public override void _Input(InputEvent input)
    {
        if (input is InputEventKey { Pressed: true, Keycode: Key.Escape })
        {
            bool active = _trashPressed || _drag?.IsDragging == true || HasProductionGesture || _mixHeld || _cooker?.PendingPourBasket is not null;
            CancelInput(); if (active) GetViewport().SetInputAsHandled(); return;
        }
        if (CanInteract?.Invoke() != true) { CancelInput(); return; }
        if (HandleTrashInput(input)) { GetViewport().SetInputAsHandled(); return; }
        if (_drag?.IsDragging == true) return;
        if (_mixHeld) { HandleMixInput(input); return; }
        if (!HasProductionGesture) return;
        if (input is InputEventMouseMotion motion)
        {
            if ((motion.ButtonMask & MouseButtonMask.Left) == 0) { CancelGesture(); return; }
            UpdateGesture(GetGlobalTransformWithCanvas().AffineInverse() * motion.Position);
            GetViewport().SetInputAsHandled();
        }
        else if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false } button)
        {
            Vector2 point = GetGlobalTransformWithCanvas().AffineInverse() * button.Position;
            UpdateGesture(point); FinishGesture(point); GetViewport().SetInputAsHandled();
        }
    }

    private void UpdateGesture(Vector2 point)
    {
        _gesturePoint = point;
        Vector2 step = point - _gesturePrevious;
        _gestureTravel += step.Length();
        _maximumExcursion = Math.Max(_maximumExcursion, point.DistanceTo(_gestureStart));
        if (_gesture == "basket" && point.Y - _gestureStart.Y <= -38
            && _cooker.Baskets[_gestureBasket].State is NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked)
            RaiseRequested?.Invoke(_gestureBasket);
        if (_gesture == "filling" && !_fillingDeposited && OnPan(point))
            _fillingDeposited = FillingRequested?.Invoke() == true;
        if ((_gesture == "filling" && _fillingDeposited) || _gesture == "spread")
        {
            Vector2 from = _gesturePrevious;
            // Entering with a new portion starts at the entry point, with no trail from the bowl.
            if (!OnPan(from) && OnPan(point)) from = point;
            SpreadRequested?.Invoke(SurfacePoint(from), SurfacePoint(point));
        }
        if (_gesture == "flip" && _doupi?.State == DoupiState.ReadyToFlip)
            _flipLift = Math.Clamp((_gestureStart.Y - point.Y) / DoupiInteraction.FlipDistance, 0, 1);
        if (_gesture == "cut" && !_cutCommitted && _cutStroke?.Move(SurfacePoint(point)) == true)
            _cutCommitted = CutRequested?.Invoke(_cutStroke.Line!.Value) == true;
        _gesturePrevious = point; QueueRedraw();
    }

    private void CancelGesture()
    {
        if (_gesture == "flip" && _flipLift > 0 && _doupi?.State == DoupiState.ReadyToFlip && !Busy("pan"))
            PlayFlipReturn(_flipLift);
        _flipLift = 0; _gesture = ""; _gestureTravel = 0; _cutStroke = null; QueueRedraw();
    }
    private Vector2 SurfacePoint(Vector2 point) => DoupiInteraction.ToSurface(PanCorners, point);
    private bool OnPan(Vector2 point) => DoupiInteraction.Inside(SurfacePoint(point));
    private bool NearPan(Vector2 point)
    {
        Vector2[] corners = PanCorners;
        if (OnPan(point)) return true;
        for (int i = 0; i < corners.Length; i++)
            if (Geometry2D.GetClosestPointToSegment(point, corners[i], corners[(i + 1) % corners.Length]).DistanceTo(point) <= 12) return true;
        return false;
    }
    private void FinishGesture(Vector2 point)
    {
        string gesture = _gesture; Vector2 movement = point - _gestureStart;
        bool committed = _cutCommitted;
        bool deposited = _fillingDeposited;
        float lift = _flipLift;
        // Complete the flip before cancelling, so its motion inherits the held pose.
        bool flipped = gesture == "flip" && !Busy("pan") && movement.Y <= -DoupiInteraction.FlipDistance
            && Math.Abs(movement.X) < DoupiInteraction.FlipSideTolerance && FlipRequested?.Invoke() == true;
        if (flipped && Find("pan") is Motion flip) flip.Lift = lift;
        CancelGesture();
        if (CanInteract?.Invoke() != true) return;
        bool accepted = false;
        if (gesture == "raw")
        {
            for (int i = 0; i < _cooker.Baskets.Count; i++)
                if (BasketRect(i).Grow(22).HasPoint(point) && _cooker.Baskets[i].State == NoodleBasketState.Empty && !Busy($"basket{i}"))
                { _rawDropOrigin = point; BasketPressed?.Invoke(i); _rawDropOrigin = null; accepted = true; break; }
        }
        else if (gesture == "basket")
        {
            bool raised = IsRaised(_cooker.Baskets[_gestureBasket].State);
            if (BowlRect.Grow(20).HasPoint(point)) accepted = raised && PourRequested?.Invoke(_gestureBasket) == true;
            else accepted = raised; // Parking an already raised basket is a valid interruption.
        }
        else if (gesture == "batter")
        {
            accepted = OnPan(point) && BatterRequested?.Invoke() == true;
            if (accepted && Find("pan") is Motion batter) batter.Origin = point;
        }
        else if (gesture is "filling" or "spread") accepted = deposited;
        else if (gesture == "flip") accepted = flipped;
        else if (gesture == "cut") accepted = committed;
        if (!accepted) GestureRejected?.Invoke(gesture switch {
            "raw" => "把生面拖进空漏勺。", "basket" => "向上提篮后拖到空碗；也可先放下等待沥干。",
            "batter" => "从浆碗拖一勺浆到空锅再松手。", "filling" => "翻面后从馅碗取馅，按住锅面铺开。",
            "flip" => "按住锅面向上划动翻面。", "cut" => "沿虚线横划一次、竖划一次；一竖自动切三条。", _ => "请在对应食物区域完成操作。" });
    }

    private void DrawGesture()
    {
        void Target(Rect2 rect) => DrawStyleBox(WuhanUi.Box(new Color(WuhanUi.Paper, .62f), 12, 2, false), rect);
        if (_cooker.PendingPourBasket is int pending)
        {
            Vector2 waiting = BowlFood.GetCenter() + new Vector2(-32, -105);
            DrawLoadedBasket(At(waiting, BasketSize));
            Drips(waiting + new Vector2(0, 30), 4); Target(BowlRect.Grow(10));
        }
        if (!HasProductionGesture) return;
        if (_gesture == "raw") for (int i = 0; i < _cooker.Baskets.Count; i++) if (_cooker.Baskets[i].State == NoodleBasketState.Empty) Target(BasketRect(i).Grow(12));
        if (_gesture == "basket" && _bowl.State == NoodleBowlState.Empty && !_cooker.PendingPourBasket.HasValue) Target(BowlRect.Grow(10));
        if ((_gesture == "batter" && _doupi?.State == DoupiState.Empty) || (_gesture == "filling" && _doupi?.State == DoupiState.Flipped))
            DrawPolyline(PanCorners.Concat(new[] { PanCorners[0] }).ToArray(), new Color("#ADBD7B"), 3, true);
        if (_gesture is "spread" || (_gesture == "filling" && _fillingDeposited))
        {
            if (_doupi?.State == DoupiState.Spreading && OnPan(_gesturePoint))
                Sprite("cut_tool", At(_gesturePoint + new Vector2(28, -20), new Vector2(90, 65)), .85f);
            return;
        }
        if (_gesture == "cut" && !_cutCommitted && _cutStroke?.Line is DoupiCutLine line)
        {
            foreach (DoupiCutLine preview in Enum.GetValues<DoupiCutLine>())
            {
                if ((preview == DoupiCutLine.Horizontal) != (line == DoupiCutLine.Horizontal)) continue;
                var (from, to) = CutLine((int)preview);
                for (int i = 0; i < _cutStroke.SampleCount; i++)
                    if (_cutStroke.Covered(i)) DrawLine(from.Lerp(to, (float)i / _cutStroke.SampleCount), from.Lerp(to, (float)(i + 1) / _cutStroke.SampleCount), WuhanUi.Ink, 3, true);
            }
        }
        string sprite = _gesture switch { "raw" => "raw_noodles", "flip" => "flip_tool", "cut" => "cut_tool", "batter" => "doupi_ladle", "filling" => "doupi_filling_overlay", _ => "basket" };
        Vector2 size = _gesture switch { "raw" => BasketFoodRect(At(Vector2.Zero, BasketSize)).Size, "basket" => BasketSize, _ => new Vector2(100, 100) };
        if (_gesture == "basket") DrawLoadedBasket(At(_gesturePoint, size));
        else if (_gesture != "cut" || !_cutCommitted) Sprite(sprite, At(_gesturePoint, size), .9f);
    }

    // Retain the serialized node so existing scenes still bind, but it has no action.
    private void BindRefillControls() => RefreshRefillControls();
    public void RefreshRefillControls()
    {
        foreach (Button button in GetChildren().OfType<Button>().Where(b => b.HasMeta("ingredient_id")))
        {
            button.Hide(); button.Disabled = true; button.FocusMode = FocusModeEnum.None;
            button.MouseFilter = MouseFilterEnum.Ignore; button.TooltipText = "";
        }
    }
    private void DrawSupplyLabels()
    {
        void LabelAt(Vector2 point, string text)
        {
            DrawStringOutline(ThemeDB.FallbackFont, point, text, fontSize:18, size:4, modulate:WuhanUi.Paper);
            DrawString(ThemeDB.FallbackFont, point, text, fontSize:18, modulate:WuhanUi.Ink);
        }
        LabelAt(new Vector2(RawTrayRect.Position.X + 12, RawTrayRect.End.Y + 30), "生面 · 无限供应");
        if (_doupi is not null) LabelAt(new Vector2(StockRect.Position.X + 14, StockRect.End.Y + 22), $"豆皮 {_stock.Count}/{DoupiInventory.Capacity}");
        if (_doupi is not null && DoupiSupplyHint.Length > 0)
            LabelAt(new Vector2(StockRect.Position.X + 14, StockRect.End.Y + 44), DoupiSupplyHint);
    }
}
