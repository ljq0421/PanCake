using ProjectCake.Fryer;

namespace ProjectCake.Pancake;

public enum PancakeState
{
    Empty,
    BatterPlaced,
    Spreading,
    Spread,
    SideACooking,
    SideAReady,
    SideAOverdone,
    SideBCooking,
    SideBReady,
    Saucing,
    Sauced,
    Toppings,
    Folded,
    Bagged,
    Delivered,
    Burnt,
}

public enum PancakeQuality
{
    Perfect,
    Overdone,
    Burnt,
}

public enum PancakeCommand
{
    PlaceBatter,
    BeginSpread,
    CompleteSpread,
    AddEgg,
    Flip,
    BeginSauce,
    CompleteSauce,
    AddIngredient,
    Fold,
    Bag,
    Discard,
}

public enum PancakeActionError
{
    None,
    InvalidState,
    MissingIngredient,
    DuplicateIngredient,
    UnsupportedIngredient,
    RecipeMismatch,
    Burnt,
}

public sealed class PancakeActionResult
{
    private PancakeActionResult(bool success, PancakeActionError error, string message, string? consumedIngredient)
    {
        Success = success;
        Error = error;
        Message = message;
        ConsumedIngredient = consumedIngredient;
    }

    public bool Success { get; }
    public PancakeActionError Error { get; }
    public string Message { get; }
    public string? ConsumedIngredient { get; }

    public static PancakeActionResult Ok(string message, string? consumedIngredient = null) =>
        new(true, PancakeActionError.None, message, consumedIngredient);

    public static PancakeActionResult Fail(PancakeActionError error, string message) =>
        new(false, error, message, null);
}

public sealed class PancakeDeliveryResult
{
    public PancakeDeliveryResult(bool success, PancakeActionError error, string message, PancakeQuality quality)
    {
        Success = success;
        Error = error;
        Message = message;
        Quality = quality;
    }

    public bool Success { get; }
    public PancakeActionError Error { get; }
    public string Message { get; }
    public PancakeQuality Quality { get; }
}

public sealed record PreparedPancake(
    PancakeQuality Quality,
    IReadOnlySet<string> ExtraIngredients,
    YoutiaoQuality? InternalYoutiaoQuality = null);
