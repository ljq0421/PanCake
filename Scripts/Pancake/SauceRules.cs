namespace ProjectCake.Pancake;

public enum SaucePreference
{
    Normal,
    Light,
    Extra,
}

public static class SauceRules
{
    public const double MaximumAmount = 1.5;

    // Both boundary values (50% and 100%) belong to normal sauce.
    public static SaucePreference Classify(double amount) => amount < .5
        ? SaucePreference.Light : amount <= 1 ? SaucePreference.Normal : SaucePreference.Extra;

    public static bool Matches(SaucePreference preference, double amount) =>
        double.IsFinite(amount) && amount >= 0 && amount <= MaximumAmount && Classify(amount) == preference;

    public static string Name(SaucePreference preference) => preference switch
    {
        SaucePreference.Light => "少酱",
        SaucePreference.Extra => "多酱",
        _ => "正常",
    };

    public static string Range(SaucePreference preference) => preference switch
    {
        SaucePreference.Light => "0%≤酱量<50%",
        SaucePreference.Extra => "100%<酱量≤150%",
        _ => "50%≤酱量≤100%",
    };

    public static string Describe(double amount) => $"{amount * 100:0}% · {Name(Classify(amount))}";
}
