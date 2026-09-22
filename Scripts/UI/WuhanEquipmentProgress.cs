using Godot;
using ProjectCake.Data;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private readonly List<EquipmentProgressView> _basketProgress = new();
    private EquipmentProgressView? _doupiProgress;
    private EquipmentProgressView? _mixProgress;
    private HotDryNoodlesStateMachine? _progressBowl;
    private long _progressGeneration = -1;
    private double _mixReadySeconds;

    private void ConfigureEquipmentProgress()
    {
        while (_basketProgress.Count < _cooker.Baskets.Count)
        {
            int index = _basketProgress.Count;
            _basketProgress.Add(EquipmentProgressView.Attach(this, $"BasketCookingProgress{index}", new Rect2(0, 0, 140, 42),
                () => EquipmentProgressPresentation.Noodles(_cooker, index), showCaption: false));
        }
        for (int i = 0; i < _basketProgress.Count; i++)
        {
            _basketProgress[i].Position = new Vector2(BasketHome(i).X - 70, _layout.Cooker.End.Y - 53);
            _basketProgress[i].Refresh();
        }
        _doupiProgress ??= EquipmentProgressView.Attach(this, "DoupiCookingProgress", new Rect2(0, 0, 260, 42),
            () => EquipmentProgressPresentation.Doupi(_doupi), showCaption: false);
        _doupiProgress.Position = new Vector2(_layout.Pan.GetCenter().X - 130, _layout.Pan.End.Y - 53);
        _doupiProgress.Refresh();
        // Follow the opening, not the full bowl silhouette (which includes its foot).
        Rect2 mixRing = BowlFood.Grow(29);
        _mixProgress ??= EquipmentProgressView.Attach(this, "BowlMixProgress", mixRing, ReadMixProgress, showCaption: false, ring: true);
        _mixProgress.Position = mixRing.Position;
        _mixProgress.Size = mixRing.Size;
        _mixProgress.Refresh();
    }

    private EquipmentProgressState ReadMixProgress()
    {
        if (_progressBowl != _bowl || _progressGeneration != _bowl.Generation)
        {
            _progressBowl = _bowl;
            _progressGeneration = _bowl.Generation;
            _mixReadySeconds = 0;
        }
        if (_bowl.State != NoodleBowlState.Ready) _mixReadySeconds = 0;
        if (_mixProgress is not null)
            _mixProgress.Modulate = new Color(1, 1, 1, (float)Math.Clamp((1.5 - _mixReadySeconds) / .3, 0, 1));
        if (_draggedProduct == ProductKind.HotDryNoodles) return default;
        return _bowl.State switch
        {
            NoodleBowlState.Seasoned => new(true, 0, ""),
            NoodleBowlState.Mixing => EquipmentProgressState.Working(_bowl.MixProgress,
                HotDryNoodlesStateMachine.MixCompletionProgress, ""),
            NoodleBowlState.Ready when _mixReadySeconds < 1.5 => EquipmentProgressState.Done(""),
            _ => default,
        };
    }

    private void TickMixProgress(double delta)
    {
        ReadMixProgress();
        if (_bowl.State == NoodleBowlState.Ready) _mixReadySeconds += delta;
        _mixProgress?.Refresh();
    }
}
