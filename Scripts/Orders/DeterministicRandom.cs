namespace ProjectCake.Orders;

public sealed class DeterministicRandom
{
    private ulong _state;

    public DeterministicRandom(int seed)
    {
        _state = unchecked((uint)seed) + 0x9E3779B97F4A7C15UL;
        NextUInt();
    }

    public uint NextUInt()
    {
        _state += 0x9E3779B97F4A7C15UL;
        ulong value = _state;
        value = (value ^ (value >> 30)) * 0xBF58476D1CE4E5B9UL;
        value = (value ^ (value >> 27)) * 0x94D049BB133111EBUL;
        return (uint)((value ^ (value >> 31)) >> 32);
    }

    public double NextDouble() => NextUInt() / ((double)uint.MaxValue + 1.0);

    public int NextInt(int exclusiveMaximum)
    {
        if (exclusiveMaximum <= 0) throw new ArgumentOutOfRangeException(nameof(exclusiveMaximum));
        return (int)(NextDouble() * exclusiveMaximum);
    }

    public double Range(double minimum, double maximum) => minimum + (maximum - minimum) * NextDouble();
}
