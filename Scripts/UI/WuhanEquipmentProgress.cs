using Godot;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private readonly List<EquipmentProgressView> _basketProgress = new();
    private EquipmentProgressView? _doupiProgress;

    private void ConfigureEquipmentProgress()
    {
        while (_basketProgress.Count < _cooker.Baskets.Count)
        {
            int index = _basketProgress.Count;
            _basketProgress.Add(EquipmentProgressView.Attach(this, $"BasketCookingProgress{index}", new Rect2(0, 0, 140, 42),
                () => EquipmentProgressPresentation.Noodles(_cooker, index)));
        }
        for (int i = 0; i < _basketProgress.Count; i++)
        {
            _basketProgress[i].Position = new Vector2(BasketHome(i).X - 70, _layout.Cooker.End.Y - 53);
            _basketProgress[i].Refresh();
        }
        _doupiProgress ??= EquipmentProgressView.Attach(this, "DoupiCookingProgress", new Rect2(0, 0, 260, 42),
            () => EquipmentProgressPresentation.Doupi(_doupi));
        _doupiProgress.Position = new Vector2(_layout.Pan.GetCenter().X - 130, _layout.Pan.End.Y - 53);
        _doupiProgress.Refresh();
    }
}
