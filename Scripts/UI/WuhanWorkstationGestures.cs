using Godot;
using ProjectCake.Data;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    public event Action<string>? RefillRequested, GestureRejected;
    public Func<int, bool>? RaiseRequested, PourRequested;
    public Func<DoupiCutDirection, bool>? CutRequested;
    private string _gesture = "";
    private Vector2 _gestureStart, _gesturePoint, _gesturePrevious, _cutDisplacement;
    private float _gestureTravel, _cutTravel, _maximumExcursion;
    private int _gestureBasket;
    private bool _cutCommitted;
    private readonly Dictionary<string, Button> _refillButtons = new();
    private Vector2 _pointer = new(-1000, -1000);
    public bool HasProductionGesture => _gesture.Length > 0;

    private bool TryBeginGesture(string hit, Vector2 point)
    {
        string gesture = "";
        if (hit == "raw" && _ingredients.Count(StableIds.Ingredients.WuhanNoodles) > 0) gesture = "raw";
        else if (hit.StartsWith("basket"))
        {
            _gestureBasket = int.Parse(hit[^1..]);
            if (Busy(hit) || _cooker.PendingPourBasket == _gestureBasket) return false;
            if (_cooker.Baskets[_gestureBasket].State is NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked
                or NoodleBasketState.Raised or NoodleBasketState.Draining or NoodleBasketState.Drained) gesture = "basket";
        }
        else if (hit == "pan" && NearPan(point) && !Busy("pan")) gesture = _doupi?.State switch {
            DoupiState.ReadyToFlip => "flip", DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting => "cut", _ => "" };
        if (gesture.Length == 0) return false;
        EndMix(); _gesture = gesture; _gestureStart = _gesturePoint = _gesturePrevious = point;
        _gestureTravel = _cutTravel = _maximumExcursion = 0; _cutDisplacement = Vector2.Zero; _cutCommitted = false;
        QueueRedraw(); return true;
    }

    public override void _Input(InputEvent input)
    {
        if (input is InputEventKey { Pressed: true, Keycode: Key.Escape })
        {
            bool active = HasProductionGesture || _mixHeld || _cooker?.PendingPourBasket is not null;
            CancelInput(); if (active) GetViewport().SetInputAsHandled(); return;
        }
        if (CanInteract?.Invoke() != true) { CancelInput(); return; }
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
        if (_gesture == "cut" && !_cutCommitted)
        {
            Vector2 inside = PanSegment(_gesturePrevious, point);
            _cutTravel += inside.Length(); _cutDisplacement += inside;
            float x = Math.Abs(_cutDisplacement.X), y = Math.Abs(_cutDisplacement.Y);
            if (_cutTravel >= 42 && _cutDisplacement.Length() >= 42 && Math.Max(x, y) >= Math.Min(x, y) * 1.25f)
            {
                var direction = x > y ? DoupiCutDirection.Horizontal : DoupiCutDirection.Vertical;
                _cutCommitted = CutRequested?.Invoke(direction) == true;
            }
        }
        _gesturePrevious = point; QueueRedraw();
    }

    private void CancelGesture() { _gesture = ""; _gestureTravel = 0; QueueRedraw(); }
    private bool OnPan(Vector2 point) => Geometry2D.IsPointInPolygon(point, PanCorners);
    // Clip input to the convex pan so fast strokes may end outside it.
    private Vector2 PanSegment(Vector2 from, Vector2 to)
    {
        Vector2 delta = to - from; float enter = 0, leave = 1;
        Vector2[] corners = PanCorners; Vector2 center = PanCenter;
        for (int i = 0; i < corners.Length; i++)
        {
            Vector2 a = corners[i], edge = corners[(i + 1) % corners.Length] - a;
            float sign = Math.Sign(edge.Cross(center - a));
            float distance = sign * edge.Cross(from - a), velocity = sign * edge.Cross(delta);
            if (Math.Abs(velocity) < .0001f) { if (distance < 0) return Vector2.Zero; continue; }
            float t = -distance / velocity;
            if (velocity > 0) enter = Math.Max(enter, t); else leave = Math.Min(leave, t);
        }
        return leave > enter ? delta * (leave - enter) : Vector2.Zero;
    }
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
        bool committed = _cutCommitted; CancelGesture();
        if (CanInteract?.Invoke() != true) return;
        bool accepted = false;
        if (gesture == "raw")
        {
            for (int i = 0; i < _cooker.Baskets.Count; i++)
                if (BasketRect(i).Grow(22).HasPoint(point) && _cooker.Baskets[i].State == NoodleBasketState.Empty && !Busy($"basket{i}"))
                { BasketPressed?.Invoke(i); accepted = true; break; }
        }
        else if (gesture == "basket")
        {
            bool raised = IsRaised(_cooker.Baskets[_gestureBasket].State);
            if (BowlRect.Grow(20).HasPoint(point)) accepted = raised && PourRequested?.Invoke(_gestureBasket) == true;
            else accepted = raised; // Parking an already raised basket is a valid interruption.
        }
        else if (gesture == "flip")
        {
            accepted = !Busy("pan") && movement.Y <= -40 && Math.Abs(movement.X) < 150 && _doupi?.State == DoupiState.ReadyToFlip;
            if (accepted) DoupiPressed?.Invoke();
        }
        else if (gesture == "cut") accepted = committed;
        if (!accepted) GestureRejected?.Invoke(gesture switch {
            "raw" => "把生面拖进空漏勺。", "basket" => "向上提篮后拖到空碗；也可先放下等待沥干。",
            "flip" => "按住锅面向上划动翻面。", "cut" => "横、竖各划一次；已完成方向无需重复。", _ => "请在对应食物区域完成操作。" });
    }

    private void DrawGesture()
    {
        void Target(Rect2 rect) => DrawStyleBox(WuhanUi.Box(new Color(WuhanUi.Paper, .62f), 12, 2, false), rect);
        if (_cooker.PendingPourBasket is int pending)
        {
            Vector2 waiting = BowlFood.GetCenter() + new Vector2(-32, -105);
            Sprite("basket", At(waiting, BasketSize));
            Sprite("cooked_basket", At(waiting + new Vector2(-8, 12), new Vector2(55, 30)));
            Drips(waiting + new Vector2(0, 30), 4); Target(BowlRect.Grow(10));
        }
        if (!HasProductionGesture) return;
        if (_gesture == "raw") for (int i = 0; i < _cooker.Baskets.Count; i++) if (_cooker.Baskets[i].State == NoodleBasketState.Empty) Target(BasketRect(i).Grow(12));
        if (_gesture == "basket" && _bowl.State == NoodleBowlState.Empty && !_cooker.PendingPourBasket.HasValue) Target(BowlRect.Grow(10));
        if (_gesture is "flip" or "cut") DrawLine(_gestureStart, _gesturePoint, WuhanUi.Ink, 3, true);
        string sprite = _gesture switch { "raw" => "raw_noodles", "flip" => "flip_tool", "cut" => "cut_tool", _ => "basket" };
        Vector2 size = _gesture switch { "raw" => RawRect.Size, "basket" => BasketSize, _ => new Vector2(100, 100) };
        Sprite(sprite, At(_gesturePoint, size), .9f);
        if (_gesture == "basket") Sprite("cooked_basket", At(_gesturePoint + new Vector2(-8, 12), new Vector2(55, 30)));
    }

    private void BindRefillControls()
    {
        if(_refillButtons.Count>0)return;
        foreach(Button button in GetChildren().OfType<Button>().Where(candidate => candidate.HasMeta("ingredient_id"))) {
            string id=button.GetMeta("ingredient_id").AsString();
            button.Pressed+=()=>RefillRequested?.Invoke(id);
            button.Text = "";
            foreach (string state in new[] { "normal", "hover", "pressed", "disabled", "focus" })
                button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
            button.Draw += () =>
            {
                Color ink = button.Disabled ? WuhanUi.Muted : WuhanUi.Ink;
                button.DrawCircle(new Vector2(24, 24), 17, button.IsHovered() || button.HasFocus() ? WuhanUi.Surface : WuhanUi.Paper);
                if (button.HasFocus()) button.DrawArc(new Vector2(24, 24), 21, 0, Mathf.Tau, 32, ink, 2, true);
                if (button.GetMeta("refilling", false).AsBool())
                    for (int dot = 0; dot < 3; dot++) button.DrawCircle(new Vector2(17 + dot * 7, 24), 2, ink);
                else
                {
                    button.DrawLine(new Vector2(16, 24), new Vector2(32, 24), ink, 3, true);
                    button.DrawLine(new Vector2(24, 16), new Vector2(24, 32), ink, 3, true);
                }
            };
            _refillButtons[id]=button;
        }
    }
    public void RefreshRefillControls()
    {
        foreach (var (id, button) in _refillButtons)
        {
            button.Position = new Vector2(RawTrayRect.End.X - 56, RawTrayRect.End.Y + 4);
            button.Size = new Vector2(48, 48);
            int count = _ingredients.Count(id), capacity = _ingredients.Capacity(id);
            bool working = NoodlesRefilling?.Invoke() == true;
            bool nearby = RawTrayRect.Grow(18).HasPoint(_pointer) || button.GetRect().Grow(18).HasPoint(_pointer) || button.IsHovered() || button.HasFocus();
            bool low = count <= _ingredients.LowStockThreshold;
            button.Visible = working || low || nearby;
            button.SetMeta("refilling", working);
            button.TooltipText = working ? "正在补面；剩余面条仍可下锅" : $"{count}/{capacity} · " + (count >= capacity ? "面条已满" : "补满面条");
            button.Disabled = CanInteract?.Invoke() != true || working || count >= capacity;
            button.Modulate = low && !working ? new Color("#FFD49B") : Colors.White;
            button.QueueRedraw();
        }
    }
    private void DrawSupplyLabels()
    {
        void LabelAt(Vector2 point, string text)
        {
            DrawStringOutline(ThemeDB.FallbackFont, point, text, fontSize:18, size:4, modulate:WuhanUi.Paper);
            DrawString(ThemeDB.FallbackFont, point, text, fontSize:18, modulate:WuhanUi.Ink);
        }
        for (int i = 0; i < 4; i++)
        {
            string id = IngredientIds[i];
            bool added = i == 0 ? _bowl.State is NoodleBowlState.Seasoned or NoodleBowlState.Mixing or NoodleBowlState.Ready : _bowl.Toppings.Contains(id);
            if (added)
            {
                Vector2 mark = IngredientRect(i).Position + new Vector2(70, -8);
                DrawLine(mark, mark + new Vector2(5, 5), WuhanUi.Ink, 3, true);
                DrawLine(mark + new Vector2(5, 5), mark + new Vector2(15, -7), WuhanUi.Ink, 3, true);
            }
        }
        int noodles = _ingredients.Count(StableIds.Ingredients.WuhanNoodles);
        string supply = NoodlesRefilling?.Invoke() == true ? " · 补货中" : noodles == 0 ? " · 请补面" : "";
        LabelAt(new Vector2(RawTrayRect.Position.X + 12, RawTrayRect.End.Y + 30), $"生面 {noodles}/{_ingredients.Capacity(StableIds.Ingredients.WuhanNoodles)}{supply}");
        if (_doupi is not null) LabelAt(new Vector2(StockRect.Position.X + 14, StockRect.End.Y + 30), $"豆皮 {_stock.Count}/{DoupiInventory.Capacity}");
        if (_doupi is not null && DoupiSupplyHint.Length > 0)
            LabelAt(new Vector2(PanRect.Position.X + 18, StockRect.End.Y + 30), DoupiSupplyHint);
    }
}
