namespace ProjectCake.Orders;

public static class TipCalculator
{
    // Convert the configured rate before multiplication so float storage cannot
    // move an exact half (for example 25 * 0.7) below the rounding boundary.
    public static int Calculate(int price, float rate) => Round(price * (decimal)rate);
    public static int Calculate(int price, double rate) => Round(price * (decimal)rate);

    private static int Round(decimal amount) => (int)Math.Round(amount, 0, MidpointRounding.AwayFromZero);
}
