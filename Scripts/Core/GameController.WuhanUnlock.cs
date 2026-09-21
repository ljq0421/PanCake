using Godot;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Core;

public partial class GameController
{
    private void PresentWuhanUnlock(BusinessDetailsView book)
    {
        var presentation = new WuhanUnlockPresentation { Name = "WuhanUnlockPresentation" };
        if (DisplayServer.GetName() != "headless")
        {
            using var frame = GetViewport().GetTexture().GetImage();
            if (frame is not null && !frame.IsEmpty()) presentation.SourceFrame = ImageTexture.CreateFromImage(frame);
        }
        book.SetProcessInput(false);
        presentation.TreeExited += () => { if (IsInstanceValid(book)) book.SetProcessInput(true); };
        AddChild(presentation);
        presentation.Begin(_save, city =>
        {
            if (city == StableIds.Cities.Wuhan)
            {
                if (!StartCityBusiness(city, 1)) return "武汉开张失败，请检查配置或存档写入权限后重试。";
                book.Hide();
                return "";
            }
            // Prepare the destination behind the opaque paper, then persist the selected city.
            _startScreen.PresentCity(city);
            _startScreen.PresentLedger();
            JourneyTransition.For(this).Finish();
            if (!_save.TryRecordCityVisit(city, out string error)) return error;
            book.Hide();
            foreach (Control page in GetNode("UI").GetChildren().OfType<Control>())
                page.Visible = page == _startScreen;
            GetNode<Node2D>("ShopRoot").Visible = false;
            return "";
        });
    }
}
