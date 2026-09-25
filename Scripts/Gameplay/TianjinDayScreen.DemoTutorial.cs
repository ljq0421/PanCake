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
    private Panel? _demoLessonActionFrame;
    private bool _demoLessonComplete;
    private string _demoLessonFailure = "";
    private Button? _demoLessonSkip;
    private Panel? _demoLessonSkipFrame;
    internal bool DemoLessonFailed => _demoLessonFailure.Length > 0;
    private bool DemoLessonControlsEnabled => _focused && !_manualPaused && !_focusPaused && !_detailsPaused
        && !_abandonDialog.Visible && !_controller.IsPaused;
    private bool _demoLessonReplay;
    private string _demoLessonSaveError = "";
    private string _demoLessonLayout = "";
    private int _demoBusinessDay;
    private int _demoTeachingDay;
    private bool _resumeBusinessAfterLesson;
    private readonly HashSet<string> _demoLearned = new(StringComparer.Ordinal);
    private BusinessBookModel? _demoPendingResult;
    internal bool DemoLessonVisible => _demoLesson?.Visible == true;
    internal bool DemoLessonComplete => _demoLessonComplete;
    internal string DemoLessonHint => _demoLessonHint?.Text ?? "";

    private bool BeginDemoLesson(bool retry = false)
    {
        bool replay = retry ? _demoLessonReplay : ForceDemoTutorial;
        var unlock = TutorialOrders.UnlockFor(_controller.CurrentConfig!);
        bool firstLesson = _controller.CurrentConfig!.Day == 1
            && !_save.Data.Tianjin.LearnedWorkbenchActions.Contains("deliver:finished_pancake");
        if (!retry && !replay && (_resumeBusinessAfterLesson
            || !firstLesson && (unlock is null || unlock.IsLearned(_save.Data.Tianjin.LearnedWorkbenchActions)))) return false;
        _demoBusinessDay = _controller.CurrentConfig!.Day;
        _demoTeachingDay = retry ? _demoTeachingDay : replay ? 1 : _demoBusinessDay;
        ForceDemoTutorial = false;
        _demoLessonReplay = replay;
        if (!_controller.TryPrepareTutorial(StableIds.Cities.Tianjin, _demoTeachingDay, _catalog, _save.Data.Tianjin, out string error)) { ShowFeedback(error, true); return true; }
        _workstation.Initialize(_catalog, 1, 1, _controller.CurrentConfig!.AvailableProductKinds.Contains(ProductKind.Youtiao) ? 1 : 0, _controller.CurrentConfig!, _art);
        // 新配料只练习新增的操作；薄脆、葱花和火腿沿用已有的单项提示。
        bool extendsKnownPancakeFlow = unlock?.DefinitionId is StableIds.Recipes.ScallionCrispy or StableIds.Recipes.Ham;
        IEnumerable<string>? learnedForLesson = extendsKnownPancakeFlow
            ? PancakeWorkstation.AllWorkbenchActions.Except(unlock!.Actions, StringComparer.Ordinal)
            : null;
        _workstation.ConfigureTutorial(learnedForLesson);
        _workstation.ResetForDay();
        if (_demoTeachingDay == 1 && _demoBusinessDay == 1)
            _workstation.ConfigureFirstPancakeEggLesson(1);
        _workstation.Tutorial = _controller.Tutorial;
        GetNode<TextureRect>("ShopBackground").Texture = _art.LivingWorkbenchBackground(_controller.CurrentConfig!.AvailableProductKinds);
        _demoLessonFailure = ""; _demoLessonComplete = false; _demoLessonSaveError = ""; _demoLearned.Clear();
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
            MouseFilter = MouseFilterEnum.Ignore, Visible = false };
        TianjinTeachingUi.ApplyPanel(_demoLesson);
        AddChild(_demoLesson);
        _demoLessonTitle = new Label { Position = new(68, 29), Size = new(205, 82), AutowrapMode = TextServer.AutowrapMode.WordSmart, VerticalAlignment = VerticalAlignment.Center, MouseFilter = MouseFilterEnum.Ignore };
        _demoLessonTitle.AddThemeFontSizeOverride("font_size", 22);
        _demoLessonTitle.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        _demoLesson.AddChild(_demoLessonTitle);
        _demoLessonHint = new Label { Position = new(68, 90), Size = new(340, 82), AutowrapMode = TextServer.AutowrapMode.WordSmart,
            MouseFilter = MouseFilterEnum.Ignore };
        _demoLessonHint.AddThemeFontSizeOverride("font_size", 21);
        _demoLessonHint.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        _demoLesson.AddChild(_demoLessonHint);
        TeachingEmphasis.Attach(_demoLessonHint);
        _demoLessonAction = new Button { Name = "LessonAction", Text = "开始营业", FocusMode = Control.FocusModeEnum.All };
        _demoLessonActionFrame = TianjinTeachingUi.ActionFrame(_demoLessonAction, new(285, 46), new(160, 58));
        _demoLesson.AddChild(_demoLessonActionFrame);
        _demoLessonAction.Pressed += () =>
        {
            if (_demoLessonSaveError.Length > 0) FinishDemoLesson();
            else if (DemoLessonFailed) RetryDemoLesson();
            else FinishDemoLesson();
        };
        _demoLessonSkip = new Button { Name = "SkipLesson", Text = "跳过教学" };
        _demoLessonSkipFrame = TianjinTeachingUi.ActionFrame(_demoLessonSkip, new(1620, 28), new(196, 56));
        _demoLessonSkipFrame.ZIndex = 90;
        AddChild(_demoLessonSkipFrame);
        _demoLessonSkip.Pressed += FinishDemoLesson;
    }

    private void UpdateDemoLesson()
    {
        if (_demoLesson?.Visible != true || !_controller.TutorialActive) return;
        if (_workstation.LessonSupplyActive && !_demoLessonComplete
            && _workstation.LearnedWorkbenchActions.Contains(PancakeWorkstation.SupplyIntroductionAction)
            && _workstation.Inventory.GetQuantity(StableIds.Ingredients.Egg) == _workstation.Inventory.GetCapacity(StableIds.Ingredients.Egg))
        {
            _demoLessonComplete = true;
            _workstation.InteractionEnabled = false;
        }
        _demoLessonAction!.Disabled = _demoLessonSkip!.Disabled = !DemoLessonControlsEnabled;
        _demoLessonSkipFrame!.Visible = !_demoLessonComplete;
        _demoLessonAction.Visible = _demoLessonComplete || DemoLessonFailed || _demoLessonSaveError.Length > 0;
        _demoLessonActionFrame!.Visible = _demoLessonAction.Visible;
        _demoLesson.MouseFilter = DemoLessonFailed ? MouseFilterEnum.Stop : MouseFilterEnum.Ignore;
        _demoLessonTitle!.Text = DemoLessonFailed ? "本次教学未通过" : _demoLessonComplete ? "教学完成，准备营业！"
            : TutorialOrders.UnlockFor(_controller.CurrentConfig!)?.Title ?? "第一张煎饼";
        _demoLessonAction.Text = _demoLessonSaveError.Length > 0 ? "重试保存" : DemoLessonFailed ? "重新练习" : "开始营业";
        _demoLessonHint!.Text = _demoLessonSaveError.Length > 0 ? _demoLessonSaveError
            : DemoLessonFailed ? $"{_demoLessonFailure}\n请按订单要求重新制作并交付。"
            : _demoLessonComplete ? "接下来自己试试。营业时留意火候，并按订单添加配料。"
            : "";
        _demoLessonHint.Visible = _demoLessonHint.Text.Length > 0;
        // Operation copy comes only from the focus resolver, which respects learned actions.
        TeachingFocus.Refresh();
        LayoutDemoLesson();
        if (_demoLessonComplete || DemoLessonFailed) RestDemoLesson();
    }

    internal void FinishDemoLesson()
    {
        if (!_controller.TutorialActive || !DemoLessonControlsEnabled) return;
        var oldActions = _save.Data.Tianjin.LearnedWorkbenchActions.ToHashSet();
        if (_demoLessonComplete)
        {
            _save.Data.Tianjin.LearnedWorkbenchActions.UnionWith(_demoLearned);
            if (TutorialOrders.UnlockFor(_controller.CurrentConfig!) is { } lesson)
                _save.Data.Tianjin.LearnedWorkbenchActions.UnionWith(lesson.Actions);
        }
        bool saved = _save.TrySave(out _);
        if (!saved)
        {
            _save.Data.Tianjin.LearnedWorkbenchActions = oldActions;
            _demoLessonSaveError = "教学记录未保存，请重试。";
            UpdateDemoLesson(); return;
        }
        int? remainingLessonEggs = (_demoLessonComplete || _workstation.LessonSupplyActive) && _demoTeachingDay == 1 && _demoBusinessDay == 1
            ? _workstation.Inventory.GetQuantity(StableIds.Ingredients.Egg) : null;
        bool completed = _demoLessonComplete;
        _demoLesson!.Hide(); _demoLessonSkipFrame!.Hide(); _workstation.Tutorial = TutorialProtection.None;
        _workstation.CancelInput(); _sceneFeedback.Clear(); ClearCoinFlights();
        _controller.AbandonDay();
        if (!Initialize(_catalog, _save, _controller, _demoBusinessDay)) return;
        if (remainingLessonEggs is int eggs) _workstation.ConfigureFirstPancakeEggLesson(eggs);
        _resumeBusinessAfterLesson = !completed;
        try { if (completed) BeginAfterUnlocks(); else BeginDay(); } finally { _resumeBusinessAfterLesson = false; }
    }

    private void RestDemoLesson()
    {
        // Context/completion cards must not inherit a previous operation's placement.
        _demoLesson!.Position = _demoLessonComplete || DemoLessonFailed
            ? (GetViewportRect().Size - _demoLesson.Size) / 2
            : new(40, Mathf.Min(635, 1080 - _demoLesson.Size.Y - 24));
    }

    private void LayoutDemoLesson()
    {
        string content = $"{_demoLessonTitle!.Tr(_demoLessonTitle.Text)}|{_demoLessonHint!.Visible}|{_demoLessonHint.Tr(_demoLessonHint.Text)}|{_demoLessonAction!.Tr(_demoLessonAction.Text)}";
        if (_demoLessonLayout == content) return;
        _demoLessonLayout = content;
        TeachingCardLayout.Lesson(_demoLesson!, _demoLessonTitle, _demoLessonHint, _demoLessonAction, 475);
    }

    private void DemoLessonDelivery(DeliveryEvaluation evaluation, string customerId, ProductKind? deliveredKind)
    {
        bool completedObjective = evaluation.CompletesOrder;
        if (!_controller.TutorialActive || _demoLessonComplete || DemoLessonFailed || !completedObjective) return;
        if (evaluation.Grade is DeliveryGrade.Correct or DeliveryGrade.Perfect)
        {
            if (_demoTeachingDay == 1)
            {
                _workstation.BeginLessonSupply();
                _workstation.InteractionEnabled = true;
            }
            else
            {
                _demoLessonComplete = true;
                _workstation.InteractionEnabled = false;
            }
            UpdateDemoLesson();
        }
        else
        {
            _demoLessonFailure = string.IsNullOrWhiteSpace(evaluation.Message) ? "交付的商品未达到订单要求。" : evaluation.Message.Split('，')[0];
            _workstation.CancelInput(); _workstation.InteractionEnabled = false;
            _sceneFeedback.Clear();
            UpdateDemoLesson();
        }
    }

    internal void RetryDemoLesson()
    {
        if (!DemoLessonFailed || !DemoLessonControlsEnabled) return;
        int businessDay = _demoBusinessDay;
        BeginDemoLesson(retry: true); _demoBusinessDay = businessDay;
    }

    private void RetryDemoSettlement()
    {
        if (_demoPendingResult is null) return;
        BusinessBookSettlement.Commit(_demoPendingResult, _save, _controller.CurrentPlan!, _controller.CurrentConfig!, _catalog);
        _committed = !_demoPendingResult.CanRetry;
        if (!_committed) _demoPendingResult.SaveMessage = "保存失败：请检查写入权限和可用空间。原有进度已保留。";
        BusinessDetails.Open(_demoPendingResult);
    }
}
