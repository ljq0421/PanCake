namespace ProjectCake.Customers;

/// <summary>Choose a vacant physical position from the center out, preferring the left on ties.</summary>
public static class CustomerSlotPlacement
{
    public static int FindAvailable(int capacity, Func<int, bool> isOccupied) =>
        Enumerable.Range(0, capacity)
            .OrderBy(index => Math.Abs(2 * index - (capacity - 1)))
            .ThenBy(index => index)
            .First(index => !isOccupied(index));
}
