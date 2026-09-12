using Godot;
using ProjectCake.Orders;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;

namespace ProjectCake.UI;

/// <summary>Owns only the book's pause reason, never the caller's other pause sources.</summary>
public sealed class BusinessBookSession
{
    public BusinessDetailsView View { get; }
    public Button Entry { get; }
    public bool IsOpen => View.Visible;
    private readonly Control _owner;
    private readonly Func<bool> _canOpen;
    private readonly Func<BusinessBookModel> _snapshot;
    private readonly Action<bool> _pause;
    private readonly Action _return;
    private Control? _focus;
    private bool _live;
    public BusinessBookSession(Control owner, Control canvas, Vector2 position, Func<bool> canOpen,
        Func<BusinessBookModel> snapshot, Action<bool> pause, Action returnHome, Action retry)
    {
        _owner = owner; _canOpen = canOpen; _snapshot = snapshot; _pause = pause; _return = returnHome;
        Entry = TianjinUi.Button("营业账本", minimumSize: new(150, 48)); Entry.Name = "OpenBusinessBook";
        Entry.Position = position; canvas.AddChild(Entry); Entry.Pressed += OpenLive;
        View = new BusinessDetailsView { Name = "BusinessDetails" }; owner.AddChild(View);
        View.CloseRequested += Close; View.RetryRequested += retry;
        owner.VisibilityChanged += () => { if (!owner.IsVisibleInTree()) Reset(); };
    }
    public void OpenLive()
    {
        if (!_canOpen() || IsOpen || _owner.GetViewport().GuiIsDragging()) return;
        _focus = _owner.GetViewport().GuiGetFocusOwner(); _live = true; _pause(true); View.Open(_snapshot());
    }
    public void ShowResult(BusinessBookModel model) { _live = false; _pause(false); model.Closing = true; View.Open(model); }
    public void Close()
    {
        if (!View.Model.CanClose) return;
        if (!_live) { View.Hide(); _return(); return; }
        Reset(); if (GodotObject.IsInstanceValid(_focus) && _focus!.IsVisibleInTree()) _focus.GrabFocus(); else Entry.GrabFocus();
    }
    public void Reset() { View.Hide(); _pause(false); _live = false; }
}

public static class BusinessBookSettlement
{
    public static BusinessBookModel Commit(BusinessBookModel model, SaveService save, DayPlan plan, DayConfig config, DataCatalog catalog, bool practice = false, bool allowFailedReturn = false)
    {
        model.Closing = true; model.Practice = practice; model.Stickers = Array.Empty<string>(); model.CanClose = true; model.CanRetry = false;
        var before = save.Data.GetCity(config.CityId).UnlockedContentIds.ToHashSet(StringComparer.Ordinal);
        try
        {
            var commit = practice ? new DayCommitResult(0, false, SaveService.EvaluateStars(model.Result, config)) : save.CommitDay(model.Result, plan, config);
            model.SaveMessage = practice ? "练习结束 · 本次不保存收入、设备或章节进度" : $"已入账 ¥{commit.PermanentCoinGain} · 历史最佳收入差额" + (commit.NewBest ? " · 新纪录" : "");
            var stickers = new List<string>();
            if (commit.EarnedStars > 0) stickers.Add($"本次评级 {new string('★', commit.EarnedStars)}");
            if (!practice)
            {
                if (commit.NewChapterCompletion) stickers.Add($"{model.CityName}章节已点亮");
                int unlocked = save.Data.GetCity(config.CityId).UnlockedContentIds.Count(id => !before.Contains(id));
                if (unlocked > 0) stickers.Add($"新开放 {unlocked} 项内容 · 回店查看");
                string[] upgrades = save.AvailableBookUpgrades(config.CityId, catalog);
                if (upgrades.Length > 0) stickers.Add($"可升级：{upgrades[0]}" + (upgrades.Length > 1 ? $"等{upgrades.Length}项" : ""));
            }
            model.Stickers = stickers.ToArray();
        }
        catch (IOException e) { model.SaveMessage = "未保存 · " + e.Message + "；本次金币与进度已回退。"; model.CanRetry = !allowFailedReturn; model.CanClose = allowFailedReturn; }
        return model;
    }
}
