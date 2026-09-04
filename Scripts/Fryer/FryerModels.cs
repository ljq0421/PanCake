namespace ProjectCake.Fryer;

public enum FryerState
{
    Empty,
    Loaded,
    Frying,
    Raised,
    Draining,
    Stored,
    Burnt,
}

public enum YoutiaoQuality
{
    Light,
    Golden,
    Deep,
    Burnt,
}

public enum FryerCommand
{
    LoadOne,
    LowerBasket,
    RaiseBasket,
    Discard,
}

public enum FryerActionError
{
    None,
    InvalidState,
    BasketFull,
    BasketEmpty,
    Burnt,
}

public sealed record FryerActionResult(bool Success, FryerActionError Error, string Message)
{
    public static FryerActionResult Ok(string message) => new(true, FryerActionError.None, message);
    public static FryerActionResult Fail(FryerActionError error, string message) => new(false, error, message);
}

public sealed class FryerBatchRuntime
{
    public FryerState State { get; internal set; } = FryerState.Empty;
    public int Quantity { get; internal set; }
    public double FrySeconds { get; internal set; }
    public double DrainSeconds { get; internal set; }
    public YoutiaoQuality Quality { get; internal set; } = YoutiaoQuality.Light;

    internal void Reset()
    {
        State = FryerState.Empty;
        Quantity = 0;
        FrySeconds = 0;
        DrainSeconds = 0;
        Quality = YoutiaoQuality.Light;
    }
}
