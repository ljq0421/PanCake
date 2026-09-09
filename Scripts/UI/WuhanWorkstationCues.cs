using Godot;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private string HoverDescription(string target)
    {
        if (target.StartsWith("ingredient"))
        {
            int index = int.Parse(target[^1..]);
            string id = IngredientIds[index];
            return $"{new[] { "基础调味", "葱花", "辣油", "牛肉" }[index]} · {_ingredients.Count(id)}/{_ingredients.Capacity(id)}\n点击加入面碗；＋补货";
        }
        if (target.StartsWith("basket"))
        {
            var state = _cooker.Baskets[int.Parse(target[^1..])].State;
            return state switch
            {
                NoodleBasketState.Empty => "拖入生面",
                NoodleBasketState.Cooking => "正在烫面；出现上箭头后提篮",
                NoodleBasketState.Soft => "面条偏软；向上提篮后拖到空碗",
                NoodleBasketState.Overcooked => "面条过熟；向上提篮后拖到空碗",
                NoodleBasketState.Raised or NoodleBasketState.Draining => "沥水中；可拖到空碗上方自动等待",
                NoodleBasketState.Drained => "已沥干；拖到空碗",
                _ => "最佳火候；向上提篮后拖到空碗",
            };
        }
        return target switch
        {
            "raw" => "生面拖进空漏勺；＋补货",
            "bowl" => "加入基础调味后在碗内划动拌匀；成品拖给顾客",
            "stock" => "豆皮拖给顾客，按订单所需数量出餐",
            "pan" when _doupi is null => "豆皮锅 · Day 4 解锁",
            "pan" when _doupi.State == DoupiState.Burnt => "豆皮焦糊；点击清理",
            "pan" => "点击加浆、加蛋和铺馅；上划翻面，横竖各划一次切块",
            "egg" when _egg is null => "蛋酒 · Day 6 解锁",
            "egg" => "成品蛋酒直接拖给顾客；＋补货",
            _ => "",
        };
    }

    // Cues describe the next action; food layers continue to own cooking quality.
    // Drawn strokes avoid font-dependent symbols and remain visible with reduced motion.
    private void Cue(Vector2 p, string kind, Color? color = null, float progress = 1)
    {
        Color ink = color ?? WuhanUi.Ink;
        DrawCircle(p, 18, new Color(WuhanUi.Paper, .94f));
        void Line(Vector2 a, Vector2 b) => DrawLine(p + a, p + b, ink, 3, true);
        if (kind == "up") { Line(new(0, 10), new(0, -10)); Line(new(0, -10), new(-7, -3)); Line(new(0, -10), new(7, -3)); }
        else if (kind == "right") { Line(new(-10, 0), new(10, 0)); Line(new(10, 0), new(3, -7)); Line(new(10, 0), new(3, 7)); }
        else if (kind == "done") { Line(new(-9, 0), new(-2, 7)); Line(new(-2, 7), new(10, -8)); }
        else if (kind == "cross") { Line(new(-8, -8), new(8, 8)); Line(new(-8, 8), new(8, -8)); }
        else if (kind == "cut")
        {
            if (_doupi?.CutDirections.Contains(DoupiCutDirection.Horizontal) != true) Line(new(-11, 0), new(11, 0));
            if (_doupi?.CutDirections.Contains(DoupiCutDirection.Vertical) != true) Line(new(0, -11), new(0, 11));
        }
        else
        {
            DrawArc(p, 11, -Mathf.Pi / 2, -Mathf.Pi / 2 + Mathf.Tau * Math.Clamp(progress, .03f, 1), 32, ink, 3, true);
            if (kind == "mix") { Line(new(10, -7), new(11, 1)); Line(new(11, 1), new(4, -2)); }
            else { Line(Vector2.Zero, new(0, -6)); Line(Vector2.Zero, new(5, 0)); }
        }
    }

    private void DrawProductionCues()
    {
        for (int i = 0; i < _cooker.Baskets.Count; i++)
        {
            var basket = _cooker.Baskets[i];
            if (basket.State == NoodleBasketState.Empty || (_gesture == "basket" && _gestureBasket == i)) continue;
            Vector2 p = BasketRect(i).Position + new Vector2(16, -12);
            bool warning = basket.Quality is NoodleQuality.Soft or NoodleQuality.Overcooked;
            Color ink = warning ? new Color("#A64A24") : WuhanUi.Ink;
            string cue = basket.State switch
            {
                NoodleBasketState.Cooking => "clock",
                NoodleBasketState.Raised or NoodleBasketState.Draining => "clock",
                NoodleBasketState.Drained => "right",
                _ => "up",
            };
            Cue(p, cue, ink);
            if (warning) DrawArc(p, 20, 0, Mathf.Tau, 32, ink, 2, true);
        }
        Vector2 bowlCue = new(BowlRect.GetCenter().X, BowlRect.End.Y + 22);
        if (_bowl.State == NoodleBowlState.Noodles)
            Sprite(_art.Ingredient(IngredientIds[0]), At(bowlCue, new Vector2(38, 38)));
        else if (_bowl.State is NoodleBowlState.Seasoned or NoodleBowlState.Mixing)
            Cue(bowlCue, "mix", progress: (float)_bowl.MixProgress / 100);
        else if (_bowl.State == NoodleBowlState.Ready) Cue(bowlCue, "done");

        if (_doupi is null) return;
        Vector2 panCue = new(PanRect.Position.X - 24, PanRect.End.Y - 12);
        switch (_doupi.State)
        {
            case DoupiState.Empty: break;
            case DoupiState.Batter:
                Sprite(_art.Shared.Ingredient(ProjectCake.Data.StableIds.Ingredients.Egg), At(panCue, new Vector2(36, 36))); break;
            case DoupiState.Flipped: Sprite("doupi_filling", At(panCue, new Vector2(38, 38))); break;
            case DoupiState.ReadyToFlip: Cue(panCue, "up"); break;
            case DoupiState.ReadyToCut:
            case DoupiState.Cutting: Cue(panCue, "cut"); break;
            case DoupiState.Overbrowned: Cue(panCue, "cut", new Color("#A64A24")); break;
            case DoupiState.Burnt: Cue(panCue, "cross", new Color("#A64A24")); break;
            case DoupiState.Cut: Sprite("doupi_stock", At(panCue, new Vector2(38, 30))); break;
            default: Cue(panCue, "clock"); break;
        }
    }
}
