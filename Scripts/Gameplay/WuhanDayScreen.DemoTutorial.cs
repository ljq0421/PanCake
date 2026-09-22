using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.UI;
using ProjectCake.Wuhan;
namespace ProjectCake.Gameplay;

public partial class WuhanDayScreen
{
    public bool ForceDemoTutorial { get; set; }
    private Panel? _demoLesson;
    private Label? _demoLessonTitle;
    private Button? _demoLessonAction;
    private bool _demoLessonComplete;
    private string _demoLessonFailure = "", _demoLessonSaveError = "";
    private string _demoLessonLocale = "";
    private string _demoLessonLayout = "";
    private Label? _demoLessonHint;
    private Button? _demoLessonSkip;
    private Panel? _demoLessonSkipFrame;
    internal bool DemoLessonFailed => _demoLessonFailure.Length > 0;
    private bool DemoLessonControlsEnabled => _focused && !_controller.IsPaused && !_abandon.Visible;
    private int _demoBusinessDay, _demoTeachingDay;
    private bool _beefLessonHandled;
    private readonly HashSet<string> _demoLearned = new(StringComparer.Ordinal);
    private BusinessBookModel? _demoPendingResult;
    private bool BeginWuhanDemoLesson(int? retryTeachingDay = null)
    {
        bool introduceBeef = _controller.CurrentConfig?.Day == 3 && !_beefLessonHandled
            && !_save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:" + StableIds.Ingredients.WuhanBraisedBeef);
        if (!ForceDemoTutorial && !introduceBeef && retryTeachingDay is null) return false;
        _demoBusinessDay = _controller.CurrentConfig!.Day;
        _demoTeachingDay = retryTeachingDay ?? (ForceDemoTutorial ? 1 : 3);
        ForceDemoTutorial = false;
        if (!_controller.TryPrepareTutorial(StableIds.Cities.Wuhan, _demoTeachingDay, _catalog, out var error))
        { Feedback(error, true); return true; }
        Workstation.CancelAnimations();
        _cooker = new(_catalog.NoodleCookersByLevel[1]) { ProtectTeachingHeat = true };
        _bowl = new(); _ingredients = new(_catalog.WuhanIngredientStationsByLevel[1]); _doupiStock = new();
        _doupi = _demoTeachingDay >= 4 ? new(_catalog.DoupiGriddlesByLevel[1]) { ProtectTeachingHeat = true } : null;
        Workstation.Bind(_art, _cooker, _bowl, _doupi, _doupiStock, _ingredients, 1, _doupi is null ? 0 : 1);
        _demoLessonFailure = _demoLessonSaveError = "";
        _demoLessonComplete = false; _demoLearned.Clear(); TeachingFocus.ResetSession();
        if (_demoLesson is null)
        {
            _demoLesson = new Panel { Name = "DemoLesson", Position = new(38, 870), Size = new(510, 165), ZIndex = 90, MouseFilter = MouseFilterEnum.Ignore };
            AddChild(_demoLesson); WuhanTeachingUi.ApplyPanel(_demoLesson);
            _demoLessonTitle = new Label { Position = new(54, 45), Size = new(390, 44), MouseFilter = MouseFilterEnum.Ignore,
                AutowrapMode = TextServer.AutowrapMode.WordSmart };
            _demoLessonTitle.AddThemeFontSizeOverride("font_size", 22); _demoLesson.AddChild(_demoLessonTitle);
            _demoLessonHint = new Label { AutowrapMode = TextServer.AutowrapMode.WordSmart, MouseFilter = MouseFilterEnum.Ignore };
            _demoLessonHint.AddThemeFontSizeOverride("font_size", 21);
            _demoLessonHint.AddThemeColorOverride("font_color", WuhanUi.Text);
            _demoLesson.AddChild(_demoLessonHint);
            TeachingEmphasis.Attach(_demoLessonHint);
            _demoLessonAction = new Button { Name = "LessonAction", Text = "开始营业" };
            _demoLesson.AddChild(WuhanTeachingUi.ActionFrame(_demoLessonAction, new(160, 98), new(200, 52)));
            _demoLessonAction.Pressed += () =>
            {
                if (_demoLessonSaveError.Length > 0) FinishWuhanDemoLesson();
                else if (DemoLessonFailed) RetryWuhanDemoLesson();
                else FinishWuhanDemoLesson();
            };
            _demoLessonSkip = new Button { Name = "SkipLesson", Text = "跳过教学" };
            _demoLessonSkipFrame = WuhanTeachingUi.ActionFrame(_demoLessonSkip, new(1620, 28), new(196, 56));
            _demoLessonSkipFrame.ZIndex = 90;
            AddChild(_demoLessonSkipFrame);
            _demoLessonSkip.Pressed += FinishWuhanDemoLesson;
        }
        Workstation.AllowedIngredients = _controller.CurrentConfig!.AvailableRecipeIds.SelectMany(id => _catalog.RecipesById[id].ExtraIngredients)
            .Append(StableIds.Ingredients.WuhanBaseSeasoning).ToHashSet();
        RefreshWorkbenchBackground();
        _demoLesson.Show();
        LayoutWuhanDemoLesson();
        _controller.TryStartDay(out _); _controller.Tick(3); _controller.Tick(.01); Render();
        return true;
    }
    internal void FinishWuhanDemoLesson()
    {
        if (!_controller.TutorialActive || !DemoLessonControlsEnabled) return;
        var old = _save.Data.Wuhan.LearnedWorkbenchActions.ToHashSet();
        if (_demoLessonComplete) _save.Data.Wuhan.LearnedWorkbenchActions.UnionWith(_demoLearned);
        bool saved = _save.TrySave(out _);
        if (!saved)
        {
            _save.Data.Wuhan.LearnedWorkbenchActions = old;
            _demoLessonSaveError = "教学记录未保存，请重试。"; LayoutWuhanDemoLesson(); return;
        }
        _demoLesson!.Hide(); _demoLessonSkipFrame!.Hide(); _sceneFeedback.Clear(); _paymentFeedback.Clear(); Workstation.CancelAnimations();
        if (_demoTeachingDay == 3) _beefLessonHandled = true;
        _controller.AbandonDay();
        if (Initialize(_catalog, _save, _controller, _demoBusinessDay)) BeginDay();
    }
    private void DemoLessonDelivered(DeliveryEvaluation result)
    {
        if (!_controller.TutorialActive || _demoLessonComplete || DemoLessonFailed || _demoLesson?.Visible != true || !result.CompletesOrder) return;
        if (result.Grade is DeliveryGrade.Correct or DeliveryGrade.Perfect)
        {
            _demoLessonComplete = true;
            _demoLessonTitle!.Text = "教学完成，准备营业！"; _demoLessonAction!.Text = "开始营业";
            LayoutWuhanDemoLesson();
            Workstation.CancelInput();
        }
        else
        {
            _demoLessonFailure = string.IsNullOrWhiteSpace(result.Message) ? "交付的商品未达到订单要求。" : result.Message.Split('，')[0];
            Workstation.CancelInput(); Workstation.CancelAnimations();
            _sceneFeedback.Clear();
            TeachingFocus.Refresh(); LayoutWuhanDemoLesson();
        }
    }
    internal void RetryWuhanDemoLesson()
    {
        if (!DemoLessonFailed || !DemoLessonControlsEnabled) return;
        int day = _demoBusinessDay;
        BeginWuhanDemoLesson(_demoTeachingDay); _demoBusinessDay = day;
    }
    private void RetryWuhanDemoSettlement()
    {
        if (_demoPendingResult is null) return;
        BusinessBookSettlement.Commit(_demoPendingResult, _save, _controller.CurrentPlan!, _controller.CurrentConfig!, _catalog);
        if (_demoPendingResult.CanRetry) _demoPendingResult.SaveMessage = "保存失败：请检查写入权限和可用空间。原有进度已保留。";
        BusinessDetails.Open(_demoPendingResult);
    }

    private void LayoutWuhanDemoLesson(TutorialFocusStep? step = null)
    {
        _demoLessonLocale = TranslationServer.GetLocale();
        _demoLessonTitle!.Text = DemoLessonFailed ? "本次教学未通过" : _demoLessonComplete ? "教学完成，准备营业！"
            : _demoTeachingDay == 3 ? "牛肉热干面 · 先拌后加" : "第一碗热干面";
        _demoLessonAction!.Text = _demoLessonSaveError.Length > 0 ? "重试保存" : DemoLessonFailed ? "重新练习" : "开始营业";
        _demoLessonHint!.Text = _demoLessonSaveError.Length > 0 ? _demoLessonSaveError
            : DemoLessonFailed ? $"{_demoLessonFailure}\n请按订单要求重新制作并交付。"
            : _demoLessonComplete ? "" : step?.Text ?? "";
        _demoLessonHint.Visible = _demoLessonHint.Text.Length > 0;
        _demoLesson!.MouseFilter = DemoLessonFailed ? MouseFilterEnum.Stop : MouseFilterEnum.Ignore;
        _demoLessonAction.Visible = _demoLessonComplete || DemoLessonFailed || _demoLessonSaveError.Length > 0;
        _demoLessonAction.GetParent<Panel>().Visible = _demoLessonAction.Visible;
        _demoLessonSkipFrame!.Visible = !_demoLessonComplete;
        _demoLessonAction.Disabled = _demoLessonSkip!.Disabled = !DemoLessonControlsEnabled;
        string content = $"{_demoLessonTitle.Tr(_demoLessonTitle.Text)}|{_demoLessonHint.Visible}|{_demoLessonHint.Tr(_demoLessonHint.Text)}|{_demoLessonAction.Visible}|{_demoLessonAction.Tr(_demoLessonAction.Text)}";
        if (_demoLessonLayout != content)
        {
            _demoLessonLayout = content;
            TeachingCardLayout.Lesson(_demoLesson!, _demoLessonTitle!, _demoLessonHint, _demoLessonAction!, 510);
        }
        if (step is null) _demoLesson!.Position = new(38, 1035 - _demoLesson.Size.Y);
    }
}
