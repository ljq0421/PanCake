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
    private int _demoBusinessDay, _demoTeachingDay;
    private readonly HashSet<string> _demoLearned = new(StringComparer.Ordinal);
    private BusinessBookModel? _demoPendingResult;
    private bool BeginWuhanDemoLesson()
    {
        if (!_save.IsDemo && !ForceDemoTutorial) return false;
        _demoBusinessDay = _controller.CurrentConfig!.Day;
        var stage = _save.IsDemo ? _save.DemoContent!.Stage(StableIds.Cities.Wuhan, _demoBusinessDay) : null;
        _demoTeachingDay = !_save.IsDemo ? 1 : ForceDemoTutorial && stage!.Tutorial.Length == 0 ? (_demoBusinessDay >= 4 ? 4 : 1) : _demoBusinessDay;
        var lesson = _save.IsDemo ? _save.DemoContent!.Stage(StableIds.Cities.Wuhan, _demoTeachingDay) : null;
        bool requested = ForceDemoTutorial || lesson is { Tutorial.Length: > 0 }
            && !_save.DemoProgress.CompletedTutorials.Contains(lesson.Id) && !_save.DemoProgress.SkippedTutorials.Contains(lesson.Id);
        ForceDemoTutorial = false;
        if (!requested) return false;
        if (!_controller.TryPrepareTutorial(StableIds.Cities.Wuhan, _demoTeachingDay, _catalog, out var error))
        { Feedback(error, true); return true; }
        Workstation.CancelAnimations();
        _cooker = new(_catalog.NoodleCookersByLevel[1]) { ProtectTeachingHeat = true };
        _bowl = new(); _ingredients = new(_catalog.WuhanIngredientStationsByLevel[1]); _doupiStock = new();
        _doupi = _demoTeachingDay >= 4 ? new(_catalog.DoupiGriddlesByLevel[1]) { ProtectTeachingHeat = true } : null;
        Workstation.Bind(_art, _cooker, _bowl, _doupi, _doupiStock, false, _ingredients, 1, _doupi is null ? 0 : 1);
        _demoLessonComplete = false; _demoLearned.Clear(); TeachingFocus.ResetSession();
        if (_demoLesson is null)
        {
            _demoLesson = new Panel { Name = "DemoLesson", Position = new(38, 870), Size = new(510, 165), ZIndex = 90, MouseFilter = MouseFilterEnum.Ignore };
            AddChild(_demoLesson); WuhanTeachingUi.ApplyPanel(_demoLesson);
            _demoLessonTitle = new Label { Position = new(54, 45), Size = new(390, 44), MouseFilter = MouseFilterEnum.Ignore,
                AutowrapMode = TextServer.AutowrapMode.WordSmart };
            _demoLessonTitle.AddThemeFontSizeOverride("font_size", 22); _demoLesson.AddChild(_demoLessonTitle);
            _demoLessonAction = new Button { Text = "跳过教学" };
            _demoLesson.AddChild(WuhanTeachingUi.ActionFrame(_demoLessonAction, new(160, 98), new(200, 52)));
            _demoLessonAction.Pressed += FinishWuhanDemoLesson;
        }
        Workstation.AllowedIngredients = _controller.CurrentConfig!.AvailableRecipeIds.SelectMany(id => _catalog.RecipesById[id].ExtraIngredients)
            .Append(StableIds.Ingredients.WuhanBaseSeasoning).ToHashSet();
        GetNode<TextureRect>("WorkbenchBackground").Texture = _art.WorkbenchBackground(_doupi is not null);
        _demoLessonTitle!.Text = lesson?.TitleZh ?? "第一碗热干面"; _demoLessonAction!.Text = "跳过教学"; _demoLesson.Show();
        LayoutWuhanDemoLesson();
        _controller.TryStartDay(out _); _controller.Tick(3); _controller.Tick(.01); Render();
        return true;
    }
    internal void FinishWuhanDemoLesson()
    {
        if (!_controller.TutorialActive || !_focused || _controller.IsPaused || _abandon.Visible) return;
        var old = _save.Data.Wuhan.LearnedWorkbenchActions.ToHashSet();
        if (_demoLessonComplete) _save.Data.Wuhan.LearnedWorkbenchActions.UnionWith(_demoLearned);
        bool saved = _save.IsDemo
            ? _save.SaveDemoTutorial(_save.DemoContent!.Stage(StableIds.Cities.Wuhan, _demoTeachingDay)!.Id, !_demoLessonComplete, out _)
            : _save.TrySave(out _);
        if (!saved)
        {
            _save.Data.Wuhan.LearnedWorkbenchActions = old;
            _demoLessonTitle!.Text = "教学记录未保存，请重试。"; _demoLessonAction!.Text = "重试保存"; LayoutWuhanDemoLesson(); return;
        }
        _demoLesson!.Hide(); _sceneFeedback.Clear(); _paymentFeedback.Clear(); Workstation.CancelAnimations();
        _controller.AbandonDay();
        if (Initialize(_catalog, _save, _controller, _demoBusinessDay)) BeginDay();
    }
    private void DemoLessonDelivered(DeliveryEvaluation result)
    {
        if (!_controller.TutorialActive || _demoLesson?.Visible != true || !result.CompletesOrder) return;
        if (result.Grade is DeliveryGrade.Correct or DeliveryGrade.Perfect)
        {
            _demoLessonComplete = true;
            _demoLessonTitle!.Text = "教学完成，准备营业！"; _demoLessonAction!.Text = "开始营业";
            LayoutWuhanDemoLesson();
            Workstation.CancelInput();
        }
        else Callable.From(() => { int day = _demoBusinessDay; ForceDemoTutorial = true; BeginWuhanDemoLesson(); _demoBusinessDay = day; }).CallDeferred();
    }
    private void RetryWuhanDemoSettlement()
    {
        if (_demoPendingResult is null || !_save.IsDemo) return;
        BusinessBookSettlement.Commit(_demoPendingResult, _save, _controller.CurrentPlan!, _controller.CurrentConfig!, _catalog);
        if (_demoPendingResult.CanRetry) _demoPendingResult.SaveMessage = "保存失败：请检查写入权限和可用空间。原有进度已保留。";
        BusinessDetails.Open(_demoPendingResult);
    }

    private void LayoutWuhanDemoLesson()
    {
        TeachingCardLayout.Lesson(_demoLesson!, _demoLessonTitle!, null, _demoLessonAction!, 510);
        _demoLesson!.Position = new(38, 1035 - _demoLesson.Size.Y);
    }
}
