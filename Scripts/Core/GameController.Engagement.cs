using ProjectCake.UI;

namespace ProjectCake.Core;

public partial class GameController
{
    private void ConnectBusinessContinuation(BusinessDetailsView book, string city)
    {
        book.WuhanUnlockRequested += () => PresentWuhanUnlock(book);
        book.WuhanUnlockStayRequested += () =>
        {
            book.Hide(); ShowOnly(_startScreen); _startScreen.PresentCity(city); _startScreen.PresentLedger();
        };
        book.ContinueRequested += () =>
        {
            void StartNext()
            {
                int next = _save.Data.GetCity(city).HighestUnlockedDay;
                if (StartCityBusiness(city, next)) book.Hide();
                else
                {
                    book.Model.SaveMessage = "无法开始下一天，请返回店铺检查存档后重试。";
                    book.RestoreContinueAfterFailure();
                    if (_startScreen.Visible) { _startScreen.PresentCity(city); _startScreen.ShowError(book.Model.SaveMessage); }
                    else book.Open(book.Model);
                }
            }
            if (_save.TakeJourneyCompletion() is { } completed)
            {
                book.Hide();
                ShowOnly(_startScreen);
                _startScreen.PresentCompletion(completed, StartNext, continueBusiness: StartNext);
            }
            else StartNext();
        };
    }
}
