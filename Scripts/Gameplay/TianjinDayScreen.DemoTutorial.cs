using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class TianjinDayScreen
{
    public bool ForceDemoTutorial { get; set; }
    private Panel? _demoLesson;
    private Label? _demoLessonTitle, _demoLessonHint;
    private Button? _demoLessonAction;
    private Panel? _demoGesture;
    private Label? _demoGestureLabel;
    private ProgressBar? _demoGestureBar;
    private bool _demoLessonComplete;
    private string _demoLessonSaveError = "";
    private int _demoBusinessDay;
    private readonly HashSet<string> _demoLearned = new(StringComparer.Ordinal);
    private BusinessBookModel? _demoPendingResult;
    internal bool DemoLessonVisible => _demoLesson?.Visible == true;
    internal bool DemoLessonComplete => _demoLessonComplete;
    internal string DemoLessonHint => _demoLessonHint?.Text ?? "";

    private bool BeginDemoLesson()
    {
        if (!_save.IsDemo) return false;
        _demoBusinessDay = _controller.CurrentConfig!.Day;
        string first = _save.DemoContent!.Stages[0].Id;
        bool requested = ForceDemoTutorial || _demoBusinessDay == 1
            && !_save.DemoProgress.CompletedTutorials.Contains(first) && !_save.DemoProgress.SkippedTutorials.Contains(first);
        ForceDemoTutorial = false;
        if (!requested) return false;
        if (!_controller.TryPrepareTutorial(StableIds.Cities.Tianjin, 1, _catalog, out string error)) { ShowFeedback(error, true); return true; }
        _workstation.Initialize(_catalog, 1, 1, 0, _controller.CurrentConfig!, _art);
        _workstation.ConfigureTutorial(null);
        _workstation.ResetForDay();
        _workstation.Tutorial = _controller.Tutorial;
        _demoLessonComplete = false; _demoLessonSaveError = ""; _demoLearned.Clear();
        EnsureDemoLesson();
        _demoLesson!.Show(); _demoLessonAction!.Disabled = false;
        _controller.TryStartDay(out _);
        _controller.Tick(DayController.OpeningDurationSeconds);
        _controller.Tick(.01);
        UpdateDemoLesson(); Render();
        return true;
    }

    private void EnsureDemoLesson()
    {
        if (_demoLesson is not null) return;
        _demoLesson = new Panel { Name = "DemoLesson", Position = new(40, 635), Size = new(475, 270), ZIndex = 90,
            MouseFilter = MouseFilterEnum.Ignore };
        _demoLesson.AddThemeStyleboxOverride("panel", TianjinUi.Box(TianjinUi.Paper, 16, 3, true));
        AddChild(_demoLesson);
        _demoLessonTitle = new Label { Position = new(24, 18), Size = new(427, 45), MouseFilter = MouseFilterEnum.Ignore };
        _demoLessonTitle.AddThemeFontSizeOverride("font_size", 28);
        _demoLesson.AddChild(_demoLessonTitle);
        _demoLessonHint = new Label { Position = new(24, 77), Size = new(427, 105), AutowrapMode = TextServer.AutowrapMode.WordSmart,
            MouseFilter = MouseFilterEnum.Ignore };
        _demoLessonHint.AddThemeFontSizeOverride("font_size", 25);
        _demoLesson.AddChild(_demoLessonHint);
        _demoLessonAction = TianjinUi.Button("跳过教学", minimumSize: new(240, 56));
        _demoLessonAction.Position = new(24, 195); _demoLesson.AddChild(_demoLessonAction);
        _demoLessonAction.Pressed += () => { if (_controller.TutorialActive) FinishDemoLesson(); else _demoLesson.Hide(); };
        _demoGesture = new Panel { Name = "DemoGestureProgress", Position = new(40, 940), Size = new(475, 76), MouseFilter = MouseFilterEnum.Ignore };
        _demoGesture.AddThemeStyleboxOverride("panel", TianjinUi.Box(TianjinUi.Paper, 12, 2, false)); AddChild(_demoGesture);
        _demoGestureLabel = new Label { Position = new(16, 5), Size = new(443, 36), MouseFilter = MouseFilterEnum.Ignore };
        _demoGestureLabel.AddThemeFontSizeOverride("font_size", 22); _demoGesture.AddChild(_demoGestureLabel);
        _demoGestureBar = new ProgressBar { Position = new(16, 46), Size = new(443, 14), MinValue = 0, MaxValue = 1, ShowPercentage = false, MouseFilter = MouseFilterEnum.Ignore };
        _demoGesture.AddChild(_demoGestureBar); _demoGesture.Hide();
    }

    private void UpdateDemoLesson()
    {
        if (_demoGesture is not null)
        {
            var runtime = _workstation.Machine.Runtime;
            bool spreading = runtime.State is PancakeState.BatterPlaced or PancakeState.Spreading;
            _demoGesture.Visible = _save.IsDemo && _controller.State == DayState.Running && (spreading || runtime.State == PancakeState.Saucing);
            if (_demoGesture.Visible)
            {
                _demoGestureBar!.MaxValue = spreading ? 1 : SauceRules.MaximumAmount;
                _demoGestureBar.Value = spreading ? runtime.SpreadCoverage : runtime.SauceCoverage;
                _demoGestureLabel!.Text = spreading ? $"摊饼进度 {runtime.SpreadCoverage:P0}" : $"酱量 {runtime.SauceCoverage:P0} · {SauceRules.Name(SauceRules.Classify(runtime.SauceCoverage))}";
            }
        }
        if (_demoLesson?.Visible != true || !_controller.TutorialActive) return;
        _demoLessonAction!.Disabled = _manualPaused || _focusPaused || _detailsPaused;
        _demoLessonTitle!.Text = _demoLessonComplete ? "第一份早餐，做好了！" : "跟着做一份煎饼";
        _demoLessonAction.Text = _demoLessonSaveError.Length > 0 ? "重试保存" : _demoLessonComplete ? "开始营业" : "跳过教学";
        bool showSummary = _demoLessonComplete || _demoLessonSaveError.Length > 0;
        _demoLessonHint!.Visible = showSummary;
        _demoLesson.Size = new Vector2(475, showSummary ? 270 : 150);
        _demoLessonAction.Position = new Vector2(24, showSummary ? 195 : 78);
        var r = _workstation.Machine.Runtime;
        _demoLessonHint!.Text = _demoLessonSaveError.Length > 0 ? _demoLessonSaveError
            : _demoLessonComplete ? "接下来自己试试。营业时留意火候，并按订单添加配料。"
            : _workstation.PancakeTray.Count > 0 ? "把装袋的煎饼拖给上方顾客。"
            : r.State switch
            {
                PancakeState.Empty => "把右侧碗里的面糊拖到中间饼炉。",
                PancakeState.BatterPlaced or PancakeState.Spreading => "按住左键在面糊上划动，用刮板摊成一张饼。",
                PancakeState.SideACooking when !r.HasEgg => "点击右侧鸡蛋，把蛋打到饼上。",
                PancakeState.SideACooking => "等第一面成熟。教学时会停在合适的火候。",
                PancakeState.SideAReady => "点击“翻面”（或按 F），煎熟另一面。",
                PancakeState.SideBCooking => "等第二面成熟，再刷酱。",
                PancakeState.SideBReady => "点击右侧酱碗拿刷子，在煎饼上刷酱。",
                PancakeState.Saucing => "刷至正常酱量，再短按右键收刷（或按 F）。",
                PancakeState.Sauced or PancakeState.Toppings => "基础煎饼不用额外配料。点击“折叠”（或按 F）。",
                PancakeState.Folded => "点击“装袋”（或按 F），把煎饼装好。",
                PancakeState.Bagged => "把装袋的煎饼拖给上方顾客。",
                _ => "完成手上的动作；需要时可跳过教学后重试。",
            };
    }

    internal void FinishDemoLesson()
    {
        if (!_controller.TutorialActive || _manualPaused || _focusPaused || _detailsPaused) return;
        string stageId = _save.DemoContent!.Stages[0].Id;
        var oldActions = _save.Data.Tianjin.LearnedWorkbenchActions.ToHashSet();
        if (_demoLessonComplete) _save.Data.Tianjin.LearnedWorkbenchActions.UnionWith(_demoLearned);
        if (!_save.SaveDemoTutorial(stageId, !_demoLessonComplete, out string error))
        {
            _save.Data.Tianjin.LearnedWorkbenchActions = oldActions;
            _demoLessonSaveError = "教学记录未保存，请重试。";
            UpdateDemoLesson(); return;
        }
        _demoLesson!.Hide(); _workstation.Tutorial = TutorialProtection.None;
        _workstation.CancelInput(); _sceneFeedback.Clear(); ClearCoinFlights();
        _controller.AbandonDay();
        if (!Initialize(_catalog, _save, _controller, _demoBusinessDay)) return;
        BeginDay();
    }

    private void ShowDemoContextHint()
    {
        if (!_save.IsDemo) return;
        EnsureDemoLesson();
        if (_controller.CurrentConfig!.Day == 1) return;
        var stage = _save.DemoContent!.Stage(_controller.CurrentConfig.Day)!;
        if (_save.DemoProgress.CompletedTutorials.Contains(stage.Id)) return;
        EnsureDemoLesson(); _demoLesson!.Show(); _demoLessonAction!.Disabled = false;
        _demoLessonTitle!.Text = stage.TitleZh; _demoLessonAction.Text = "收起提示";
        _demoLessonHint!.Text = stage.Day == 2
            ? "看清订单里的薄脆图标。刷完酱后，将薄脆拖进煎饼，再折叠装袋。"
            : "订单需要葱时，刷完酱再点击香葱。料盒不足时可长按补货，留意空档。";
    }

    private void DemoLessonDelivery(DeliveryEvaluation evaluation, string customerId)
    {
        if (!_controller.TutorialActive && _save.IsDemo && evaluation.Grade is DeliveryGrade.Correct or DeliveryGrade.Perfect)
        {
            var stage = _save.DemoContent!.Stage(_controller.CurrentConfig!.Day)!;
            string recipe = _controller.CustomerQueue!.Slots.FirstOrDefault(c => c.Id == customerId)?.Order.PancakeRecipeId ?? "";
            if (stage.Day == 2 && recipe.Contains("crispy") || stage.Day == 3 && recipe.Contains("scallion"))
            {
                if (_save.SaveDemoTutorial(stage.Id, false, out string error)) _demoLesson?.Hide();
                else ShowFeedback("教学记录未保存，请重试。\n" + error, true);
            }
        }
        if (!_controller.TutorialActive || !evaluation.CompletesOrder) return;
        if (evaluation.Grade is DeliveryGrade.Correct or DeliveryGrade.Perfect)
        {
            _demoLessonComplete = true; _workstation.InteractionEnabled = false;
            UpdateDemoLesson();
        }
        else
        {
            // A wrong example is consumed by the real delivery flow. Start a clean example.
            Callable.From(() =>
            {
                int businessDay = _demoBusinessDay;
                ForceDemoTutorial = true; BeginDemoLesson(); _demoBusinessDay = businessDay;
            }).CallDeferred();
        }
    }

    private void RetryDemoSettlement()
    {
        if (_demoPendingResult is null || !_save.IsDemo) return;
        BusinessBookSettlement.Commit(_demoPendingResult, _save, _controller.CurrentPlan!, _controller.CurrentConfig!, _catalog);
        _committed = !_demoPendingResult.CanRetry;
        if (!_committed) _demoPendingResult.SaveMessage = "保存失败：请检查写入权限和可用空间。原有进度已保留。";
        if (_committed && _demoPendingResult.Result.CompletedCustomers == 0)
            _demoPendingResult.SaveMessage += " · 本次未完成订单，可免费重试";
        BusinessDetails.Open(_demoPendingResult);
    }
}
