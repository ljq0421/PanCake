using ProjectCake.Pancake;

namespace ProjectCake.Inventory;

/// <summary>Finished pancakes remain independent of the next pancake on the stove.</summary>
public sealed class PancakeTrayInventory
{
    private readonly List<PreparedPancake> _items = new();
    public int Count => _items.Count;
    public int SelectedIndex { get; private set; }
    public PreparedPancake? Selected => Count == 0 ? null : _items[SelectedIndex];

    public void Add(PreparedPancake pancake) => _items.Add(pancake);

    public void SelectNext(int direction)
    {
        if (Count > 0) SelectedIndex = ((SelectedIndex + direction) % Count + Count) % Count;
    }

    public bool TryTake(PreparedPancake expected)
    {
        if (!ReferenceEquals(Selected, expected)) return false;
        _items.RemoveAt(SelectedIndex);
        SelectedIndex = Math.Min(SelectedIndex, Math.Max(0, Count - 1));
        return true;
    }

    public void Clear()
    {
        _items.Clear();
        SelectedIndex = 0;
    }
}
