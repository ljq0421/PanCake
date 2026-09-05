using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Pancake;

namespace ProjectCake.Tests;

public partial class PancakeSpreadCapture : Node
{
    public override async void _Ready()
    {
        string[] args = OS.GetCmdlineUserArgs();
        int level = args.Contains("--level3", StringComparer.Ordinal) ? 3
            : args.Contains("--level2", StringComparer.Ordinal) ? 2 : 1;
        bool complete = args.Contains("--complete", StringComparer.Ordinal);
        bool showTool = args.Contains("--tool", StringComparer.Ordinal);

        var background = new ColorRect { Color = new Color("#F2B25B") };
        background.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        AddChild(background);

        var workstation = new PancakeWorkstation();
        workstation.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        AddChild(workstation);
        workstation.Initialize(GetNode<DataCatalog>("/root/DataCatalog"), level, 1);
        workstation.Machine.TryExecute(PancakeCommand.PlaceBatter);
        workstation.Machine.TryExecute(PancakeCommand.BeginSpread);
        workstation.Machine.SetSpreadCoverage(complete ? 1.0 : 0.58);
        if (complete)
        {
            workstation.Machine.TryExecute(PancakeCommand.CompleteSpread);
        }

        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        if (showTool)
        {
            StrokeInteractor stroke = FindDescendant<StrokeInteractor>(workstation)
                ?? throw new InvalidOperationException("未找到摊饼轨迹交互层。");
            stroke.EmitSignal(Control.SignalName.MouseEntered);
            stroke._GuiInput(new InputEventMouseMotion { Position = stroke.Size * 0.5f + new Vector2(145, -25) });
        }
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree().CreateTimer(0.25), SceneTreeTimer.SignalName.Timeout);

        Image image = GetViewport().GetTexture().GetImage();
        string state = complete ? "complete" : showTool ? "tool" : "progress";
        string output = $"res://.godot/pancake_spread_lv{level}_{state}_{image.GetWidth()}x{image.GetHeight()}.png";
        Error error = image.SavePng(ProjectSettings.GlobalizePath(output));
        if (error != Error.Ok)
        {
            GD.PushError($"摊饼视觉录帧失败：{error}");
            GetTree().Quit(1);
            return;
        }
        GD.Print($"摊饼视觉录帧已保存：{output}");
        GetTree().Quit(0);
    }

    private static T? FindDescendant<T>(Node parent) where T : Node
    {
        foreach (Node child in parent.GetChildren())
        {
            if (child is T match) return match;
            T? nested = FindDescendant<T>(child);
            if (nested is not null) return nested;
        }
        return null;
    }
}
