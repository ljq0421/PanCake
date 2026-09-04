namespace ProjectCake.Data;

public sealed class ValidationIssue
{
    public ValidationIssue(string source, string field, string message)
    {
        Source = source;
        Field = field;
        Message = message;
    }

    public string Source { get; }

    public string Field { get; }

    public string Message { get; }

    public override string ToString() => $"{Source} [{Field}]: {Message}";
}

public sealed class DayConfigLoadResult
{
    public DayConfigLoadResult(string source, DayConfig? config, IReadOnlyList<ValidationIssue> issues)
    {
        Source = source;
        Config = config;
        Issues = issues;
    }

    public string Source { get; }

    public DayConfig? Config { get; }

    public IReadOnlyList<ValidationIssue> Issues { get; }

    public bool IsSuccess => Config is not null && Issues.Count == 0;
}
