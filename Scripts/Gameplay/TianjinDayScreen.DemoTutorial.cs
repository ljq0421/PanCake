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
    private bool _demoLessonReplay;
    private string _demoLessonSaveError = "";
    private string _demoLessonLayout = "";
    private int _demoBusinessDay;
    private int _demoTeachingDay;
    private bool _demoPartialSeeded;
    private readonly HashSet<string> _demoLearned = new(StringComparer.Ordinal);
    private BusinessBookModel? _demoPendingResult;
    internal bool DemoLessonVisible => _demoLesson?.Visible == true;
    internal bool DemoLessonComplete => _demoLessonComplete;
    internal string DemoLessonHint => _demoLessonHint?.Text ?? "";

    private bool BeginDemoLesson(bool retry = false)
    {
        bool replay = retry ? _demoLessonReplay : ForceDemoTutorial;
        if (!replay) return false;
        _demoBusinessDay = _controller.CurrentConfig!.Day;
        _demoTeachingDay = 1;
        ForceDemoTutorial = false;
        _demoLessonReplay = replay;
        if (!_controller.TryPrepareTutorial(StableIds.Cities.Tianjin, _demoTeachingDay, _catalog, out string error)) { ShowFeedback(error, true); return true; }
        _workstation.Initialize(_catalog, 1, 1, _demoTeachingDay >= 4 ? 1 : 0, _controller.CurrentConfig!, _art);
        _workstation.ConfigureTutorial(replay ? null : _save.Data.Tianjin.LearnedWorkbenchActions);
        _workstation.ResetForDay();
        if (_demoTeachingDay == 1 && _demoBusinessDay == 1)
            _workstation.ConfigureFirstPancakeEggLesson(1);
        _workstation.Tutorial = _controller.Tutorial;
        GetNode<TextureRect>("ShopBackground").Texture = _art.LivingWorkbenchBackground(_controller.CurrentConfig!.AvailableProductKinds);
        _demoLessonComplete = false; _demoPartialSeeded = false; _demoLessonSaveError = ""; _demoLearned.Clear();
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
        _demoLessonAction = new Button { Text = "跳过教学", FocusMode = Control.FocusModeEnum.All };
        _demoLessonActionFrame = TianjinTeachingUi.ActionFrame(_demoLessonAction, new(285, 46), new(160, 58));
        _demoLesson.AddChild(_demoLessonActionFrame);
        _demoLessonAction.Pressed += () => { if (_controller.TutorialActive) FinishDemoLesson(); else _demoLesson.Hide(); };
    }

    private void UpdateDemoLesson()
    {
        if (_demoLesson?.Visible != true || !_controller.TutorialActive) return;
        if (_demoTeachingDay == 6 && !_demoPartialSeeded && _controller.CustomerQueue!.Slots.FirstOrDefault(c => c.State == ProjectCake.Customers.CustomerState.Happy) is { } example)
        {
            example.WaitSeconds = example.LeaveAtSeconds * .4; example.Tick(0); _demoPartialSeeded = true;
        }
        _demoLessonAction!.Disabled = _manualPaused || _focusPaused || _detailsPaused;
        _demoLessonTitle!.Text = _demoLessonComplete ? "第一份早餐，做好了！" : "第一张煎饼";
        _demoLessonAction.Text = _demoLessonSaveError.Length > 0 ? "重试保存" : _demoLessonComplete ? "开始营业" : "跳过教学";
        _demoLessonHint!.Text = _demoLessonSaveError.Length > 0 ? _demoLessonSaveError
            : _demoLessonComplete ? "接下来自己试试。营业时留意火候，并按订单添加配料。"
            : "";
        _demoLessonHint.Visible = _demoLessonHint.Text.Length > 0;
        // Operation copy comes only from the focus resolver, which respects learned actions.
        TeachingFocus.Refresh();
        LayoutDemoLesson();
        if (_demoLessonComplete) RestDemoLesson();
    }

    internal void FinishDemoLesson()
    {
        if (!_controller.TutorialActive || _manualPaused || _focusPaused || _detailsPaused) return;
        var oldActions = _save.Data.Tianjin.LearnedWorkbenchActions.ToHashSet();
        if (_demoLessonComplete) _save.Data.Tianjin.LearnedWorkbenchActions.UnionWith(_demoLearned);
        bool saved = _save.TrySave(out _);
        if (!saved)
        {
            _save.Data.Tianjin.LearnedWorkbenchActions = oldActions;
            _demoLessonSaveError = "教学记录未保存，请重试。";
            UpdateDemoLesson(); return;
        }
        int? remainingLessonEggs = _demoLessonComplete && _demoTeachingDay == 1 && _demoBusinessDay == 1
            ? _workstation.Inventory.GetQuantity(StableIds.Ingredients.Egg) : null;
        _demoLesson!.Hide(); _workstation.Tutorial = TutorialProtection.None;
        _workstation.CancelInput(); _sceneFeedback.Clear(); ClearCoinFlights();
        _controller.AbandonDay();
        if (!Initialize(_catalog, _save, _controller, _demoBusinessDay)) return;
        if (remainingLessonEggs is int eggs) _workstation.ConfigureFirstPancakeEggLesson(eggs);
        BeginDay();
    }

    private void RestDemoLesson()
    {
        // Context/completion cards must not inherit a previous operation's placement.
        _demoLesson!.Position = new(40, Mathf.Min(635, 1080 - _demoLesson.Size.Y - 24));
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
        bool soyLessonCompleted = _demoTeachingDay == 6 && deliveredKind == ProductKind.SoyMilk && evaluation.ItemAccepted;
        bool completedObjective = evaluation.CompletesOrder || soyLessonCompleted;
        if (!_controller.TutorialActive || !completedObjective) return;
        if (evaluation.Grade is DeliveryGrade.Correct or DeliveryGrade.Perfect || soyLessonCompleted)
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
                BeginDemoLesson(retry: true); _demoBusinessDay = businessDay;
            }).CallDeferred();
        }
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
