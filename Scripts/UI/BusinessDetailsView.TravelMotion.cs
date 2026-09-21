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
        _income.PivotOffset = new(0, _income.Size.Y / 2);
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
                _income.Text = $"¥{(int)Math.Round(value, MidpointRounding.AwayFromZero)}"),
                (double)from, (double)to, duration).SetDelay(opening + start)
                .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
            At(start + duration, () => _income.Text = $"¥{to}");
        }

        Group(TravelMotionGroup.Reception, .15, .25);
        Group(TravelMotionGroup.Evaluation, .40, .20);
        Group(TravelMotionGroup.Income, .65, .16);
        var result = _model.Result;
        Count(0, result.TotalRevenue, .65, .45);
        Group(TravelMotionGroup.Challenge, .86, .18);
        Group(TravelMotionGroup.Note, 1.04, .25);
        _entrance.TweenProperty(_note, "position", _travelRest[_note].Position, .25)
            .SetDelay(opening + 1.04).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        _entrance.Chain().TweenCallback(Callable.From(() =>
        {
            _income.Text = $"¥{_model.Result.TotalRevenue}";
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
