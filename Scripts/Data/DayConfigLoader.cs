using System.Text.Json;
using System.Text.Json.Serialization;
using Godot;

namespace ProjectCake.Data;

public sealed class DayConfigLoader
{
    private static readonly JsonSerializerOptions SerializerOptions = CreateSerializerOptions();

    public DayConfigLoadResult LoadFile(string path)
    {
        var issues = new List<ValidationIssue>();

        if (!Godot.FileAccess.FileExists(path))
        {
            issues.Add(new ValidationIssue(path, "$", "配置文件不存在。"));
            return new DayConfigLoadResult(path, null, issues);
        }

        string json = Godot.FileAccess.GetFileAsString(path);
        Error readError = Godot.FileAccess.GetOpenError();
        if (readError != Error.Ok)
        {
            issues.Add(new ValidationIssue(path, "$", $"读取配置失败：{readError}。"));
            return new DayConfigLoadResult(path, null, issues);
        }

        try
        {
            DayConfig? config = JsonSerializer.Deserialize<DayConfig>(json, SerializerOptions);
            if (config is null)
            {
                issues.Add(new ValidationIssue(path, "$", "配置内容为空。"));
                return new DayConfigLoadResult(path, null, issues);
            }

            config.SourcePath = path;
            return new DayConfigLoadResult(path, config, issues);
        }
        catch (JsonException exception)
        {
            string field = string.IsNullOrWhiteSpace(exception.Path) ? "$" : exception.Path;
            string location = exception.LineNumber is null
                ? string.Empty
                : $"（第 {exception.LineNumber + 1} 行，第 {exception.BytePositionInLine + 1} 字节）";
            issues.Add(new ValidationIssue(path, field, $"JSON 解析失败{location}：{exception.Message}"));
            return new DayConfigLoadResult(path, null, issues);
        }
    }

    public IReadOnlyList<DayConfigLoadResult> LoadDirectory(string directoryPath)
    {
        var results = new List<DayConfigLoadResult>();

        if (!DirAccess.DirExistsAbsolute(directoryPath))
        {
            var issue = new ValidationIssue(directoryPath, "$", "每日配置目录不存在。");
            results.Add(new DayConfigLoadResult(directoryPath, null, new[] { issue }));
            return results;
        }

        string[] files = DirAccess.GetFilesAt(directoryPath)
            .Where(fileName => fileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
            .OrderBy(fileName => fileName, StringComparer.Ordinal)
            .ToArray();

        if (files.Length == 0)
        {
            var issue = new ValidationIssue(directoryPath, "$", "每日配置目录中没有 JSON 文件。");
            results.Add(new DayConfigLoadResult(directoryPath, null, new[] { issue }));
            return results;
        }

        foreach (string fileName in files)
        {
            results.Add(LoadFile($"{directoryPath.TrimEnd('/')}/{fileName}"));
        }

        return results;
    }

    private static JsonSerializerOptions CreateSerializerOptions()
    {
        var options = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = false,
            ReadCommentHandling = JsonCommentHandling.Disallow,
            AllowTrailingCommas = false,
            UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        };
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
        return options;
    }
}

