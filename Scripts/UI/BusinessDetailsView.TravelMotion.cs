using Godot;
using ProjectCake.Gameplay;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
    private enum TravelMotionGroup { Reception, Evaluation, Review, Income, Sales, Tips }
    private readonly Dictionary<TravelMotionGroup, List<Control>> _travelGroups = new();
    private readonly Dictionary<Control, (Color Color, Vector2 Position, Vector2 Scale, Vector2 Pivot)> _travelRest = new();
    private readonly List<Control> _fallingCoins = new();
    private TextureRect? _incomeCoins;
    private ProgressBar? _completionProgress;
    private bool _travelAnimating, _skipSpaceRelease;

    // Register only newly created content, leaving section paper and headings visible.
    // Keep controls in their original parents so layout, tooltips and hit targets stay unchanged.
    private void CaptureTravelMotion(TravelMotionGroup group, Control parent, Action build)
    {
        int first = parent.GetChildCount();
        build();
        if (!_travelGroups.TryGetValue(group, out var items))
            _travelGroups[group] = items = new();
        items.AddRange(parent.GetChildren().Skip(first).OfType<Control>());
    }

    private void ResetTravelMotion()
    {
        RestoreTravelMotion();
        _travelGroups.Clear();
        _incomeCoins = null; _completionProgress = null;
    }

    private void StartTravelAnimation()
    {
        const double opening = .52; // Match the existing opaque paper-turn entrance.
        _travelAnimating = true;
        _book.Modulate = Colors.White;
        foreach (var item in _travelGroups.Values.SelectMany(items => items).Append(_stamp).Append(_note).Distinct())
        {
            _travelRest[item] = (item.Modulate, item.Position, item.Scale, item.PivotOffset);
            item.Modulate = new Color(item.Modulate, 0);
        }
        _income.Text = "¥0";
        _income.PivotOffset = new(0, _income.Size.Y / 2);
        _note.Position += new Vector2(0, 8);
        if (_completionProgress is not null) _completionProgress.Value = 0;
        _entrance = CreateTween().SetParallel();

        void Reveal(Control item, double start, double duration)
            => _entrance.TweenProperty(item, "modulate", _travelRest[item].Color, duration).SetDelay(opening + start);
        void Group(TravelMotionGroup group, double start, double duration)
        {
            if (_travelGroups.TryGetValue(group, out var items))
                foreach (var item in items) Reveal(item, start, duration);
        }
        void At(double time, Action action)
            => _entrance.TweenCallback(Callable.From(action)).SetDelay(opening + time);
        void Count(int from, int to, double start, double duration)
        {
            _entrance.TweenMethod(Callable.From<double>(value =>
                _income.Text = $"¥{(int)Math.Round(value, MidpointRounding.AwayFromZero)}"),
                (double)from, (double)to, duration).SetDelay(opening + start)
                .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
            At(start + duration, () => _income.Text = $"¥{to}");
        }

        Group(TravelMotionGroup.Reception, .15, .35);
        if (_completionProgress is not null)
            _entrance.TweenProperty(_completionProgress, "value", _model.CompletionRate ?? 0, .35)
                .SetDelay(opening + .15).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        Group(TravelMotionGroup.Evaluation, .50, .22);
        Reveal(_stamp, .68, .12);
        if (_model.Result.PerfectOrders > 0)
        {
            _stamp.Scale = Vector2.One * 1.13f;
            At(.68, () => _audio.Play(PancakeSound.BookStamp));
            _entrance.TweenProperty(_stamp, "scale", Vector2.One, .22).SetDelay(opening + .68)
                .SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
        }
        Group(TravelMotionGroup.Review, .90, .25);
        Group(TravelMotionGroup.Income, 1.15, .12);
        Group(TravelMotionGroup.Sales, 1.15, .15);
        var result = _model.Result;
        Count(0, result.SaleRevenue, 1.15, .60);
        bool tips = result.Tips > 0;
        Group(TravelMotionGroup.Tips, tips ? 1.75 : 1.15, .15);
        if (tips) Count(result.SaleRevenue, result.TotalRevenue, 1.75, .20);
        double landing = tips ? 1.95 : 1.75;
        if (result.TotalRevenue > 0)
        {
            _entrance.TweenProperty(_income, "scale", Vector2.One * 1.05f, .06).SetDelay(opening + landing);
            _entrance.TweenProperty(_income, "scale", Vector2.One, .09).From(Vector2.One * 1.05f)
                .SetDelay(opening + landing + .06);
            BuildFallingCoins(opening + landing);
        }
        Reveal(_note, landing + .30, .25);
        if (_note.GetNodeOrNull<Control>("WuhanUnlockTag") is { } tag)
        {
            _travelRest[tag] = (Colors.White, tag.Position, Vector2.One, Vector2.Zero);
            tag.Modulate = new(1, 1, 1, 0); tag.Position += new Vector2(26, 0);
            Reveal(tag, landing + .85, .18);
            _entrance.TweenProperty(tag, "position", _travelRest[tag].Position, .35)
                .SetDelay(opening + landing + .85).SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        }
        _entrance.TweenProperty(_note, "position", _travelRest[_note].Position, .25)
            .SetDelay(opening + landing + .30).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _entrance.Chain().TweenCallback(Callable.From(() =>
        {
            _income.Text = $"¥{_model.Result.TotalRevenue}";
            RestoreTravelMotion();
        }));
    }

    private void BuildFallingCoins(double start)
    {
        if (_incomeCoins is null || _entrance is null) return;
        _art ??= new TianjinArtCatalog();
        for (int i = 0; i < 3; i++)
        {
            Vector2 end = _incomeCoins.Position + new Vector2(23 + i * 22, 32 + (i % 2) * 8);
            var coin = Picture(_summary, _art.Coin, new(end - new Vector2(0, 32), new(28, 28)));
            coin.Name = "SettlementFallingCoin" + i;
            coin.Modulate = new Color(1, 1, 1, 0);
            _fallingCoins.Add(coin);
            double delay = start + i * .02;
            _entrance.TweenProperty(coin, "modulate:a", 1f, .02).SetDelay(delay);
            _entrance.TweenProperty(coin, "position", end, .10).SetDelay(delay)
                .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
            _entrance.TweenProperty(coin, "modulate:a", 0f, .03).From(1f).SetDelay(delay + .08);
        }
    }

    private void RestoreTravelMotion()
    {
        _travelAnimating = false;
        foreach (var (item, rest) in _travelRest)
            if (IsInstanceValid(item))
            {
                item.Modulate = rest.Color; item.Position = rest.Position;
                item.Scale = rest.Scale; item.PivotOffset = rest.Pivot;
            }
        _travelRest.Clear();
        if (IsInstanceValid(_completionProgress)) _completionProgress!.Value = _model.CompletionRate ?? 0;
        foreach (var coin in _fallingCoins)
            if (IsInstanceValid(coin)) { coin.Hide(); coin.QueueFree(); }
        _fallingCoins.Clear();
    }

    public override void _ExitTree()
    {
        FinishAnimation();
        _skipSpaceRelease = false;
    }
}
