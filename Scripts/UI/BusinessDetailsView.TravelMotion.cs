using Godot;
using ProjectCake.Gameplay;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
    private enum TravelMotionGroup { Reception, Evaluation, Income, Challenge, Note }
    private readonly Dictionary<TravelMotionGroup, List<Control>> _travelGroups = new();
    private readonly Dictionary<Control, (Color Color, Vector2 Position, Vector2 Scale, Vector2 Pivot)> _travelRest = new();
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
    }

    private void StartTravelAnimation()
    {
        const double opening = .52; // Match the existing opaque paper-turn entrance.
        _travelAnimating = true;
        _book.Modulate = Colors.White;
        foreach (var item in _travelGroups.Values.SelectMany(items => items).Distinct())
        {
            _travelRest[item] = (item.Modulate, item.Position, item.Scale, item.PivotOffset);
            item.Modulate = new Color(item.Modulate, 0);
        }
        _income.Text = "¥0";
        _income.PivotOffset = _income.Size / 2;
        _income.Scale = Vector2.One * .84f;
        _note.Position += new Vector2(0, 8);
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
                SetCountingIncome((int)Math.Round(value, MidpointRounding.AwayFromZero))),
                (double)from, (double)to, duration).SetDelay(opening + start)
                .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
            At(start + duration, () => { _income.Text = $"¥{to}"; _incomeAudio?.Stop(); _lastIncomeSound = null; });
        }

        Group(TravelMotionGroup.Reception, .15, .25);
        Group(TravelMotionGroup.Evaluation, .40, .20);
        Group(TravelMotionGroup.Challenge, .65, .18);
        const double incomeStart = .86;
        Group(TravelMotionGroup.Income, incomeStart, .18);
        int totalIncome = _model.Result.TotalRevenue + _model.ChallengeReward;
        if (_model.ChallengeReward > 0)
        {
            Count(0, _model.Result.TotalRevenue, incomeStart, .46);
            Count(_model.Result.TotalRevenue, totalIncome, incomeStart + .50, .30);
            var bonus = _summary.GetNode<Label>("ChallengeRewardAmount");
            bonus.PivotOffset = bonus.Size / 2;
            _entrance.TweenProperty(bonus, "scale", Vector2.One * 1.18f, .16).SetDelay(opening + incomeStart + .30);
            _entrance.TweenProperty(bonus, "position", _income.Position + new Vector2(0, 40), .30)
                .SetDelay(opening + incomeStart + .50).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.In);
            _entrance.TweenProperty(bonus, "modulate:a", 0f, .12).SetDelay(opening + incomeStart + .68);
            At(incomeStart + .81, () =>
            {
                bonus.Position = _travelRest[bonus].Position;
                bonus.Scale = _travelRest[bonus].Scale;
                bonus.Modulate = _travelRest[bonus].Color;
            });
        }
        else Count(0, totalIncome, incomeStart, .80);
        _entrance.TweenProperty(_income, "scale", Vector2.One, .22)
            .SetDelay(opening + incomeStart).SetTrans(Tween.TransitionType.Expo).SetEase(Tween.EaseType.Out);
        // Emphasize the settled amount, after the counter has reached its exact total.
        const double incomeComplete = incomeStart + .80;
        // The final pop marks that the displayed coins have settled, distinct from the tally ticks.
        At(incomeComplete, () => _audio.Play(PancakeSound.CoinCollect));
        _entrance.TweenProperty(_income, "scale", Vector2.One * 1.35f, .20)
            .SetDelay(opening + incomeComplete).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _entrance.TweenProperty(_income, "scale", Vector2.One, .28)
            .SetDelay(opening + incomeComplete + .32).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        const double noteStart = incomeComplete + .60;
        Group(TravelMotionGroup.Note, noteStart, .25);
        _entrance.TweenProperty(_note, "position", _travelRest[_note].Position, .25)
            .SetDelay(opening + noteStart).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        // A single invitation after the summary finishes; shared restoration also
        // resets this card when the player skips, turns the page or closes the book.
        if (_summary.GetNodeOrNull<Button>("NewCityUnlock") is { } unlock)
        {
            _travelRest[unlock] = (unlock.Modulate, unlock.Position, unlock.Scale, unlock.PivotOffset);
            // Keep the right edge clear of the adjacent page-turn button.
            At(noteStart + .35, () => unlock.PivotOffset = new(unlock.Size.X, unlock.Size.Y / 2));
            At(noteStart + .35, PlayNewCityCelebration);
            double unlockStart = opening + noteStart + .35;
            _entrance.TweenProperty(unlock, "scale", Vector2.One * 1.075f, .20)
                .SetDelay(unlockStart).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
            _entrance.TweenProperty(unlock, "scale", Vector2.One, .34)
                .SetDelay(unlockStart + .20).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        }
        _entrance.Chain().TweenCallback(Callable.From(() =>
        {
            _income.Text = $"¥{totalIncome}";
            RestoreTravelMotion();
        }));
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
    }

    public override void _ExitTree()
    {
        FinishAnimation();
        _skipSpaceRelease = false;
    }
}
