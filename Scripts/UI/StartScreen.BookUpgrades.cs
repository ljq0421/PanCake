using Godot;

namespace ProjectCake.UI;

public partial class StartScreen
{
    // The settlement book hosts the real start-screen scene, but owns navigation and input.
    internal bool HostedByBook { get; set; }
    private BookUpgradeSource? _bookUpgradeSource;
    private Action<string>? _bookUpgradeSelection;
    private Action<CityEquipmentView>? _bookUpgradePurchase;
    private Action? _bookUpgradeContinue;
    private Action? _bookUpgradeClose;
    private CityEquipmentView? _purchasedEquipment;
    internal void ShowUpgradeSuccess(string equipmentId, CityEquipmentView? previous = null)
    {
        _body.GetNodeOrNull<EquipmentUpgradeView>("UpgradeView")?.PlayPurchaseSuccess(equipmentId, previous ?? _purchasedEquipment);
        _purchasedEquipment = null;
    }

    internal void PresentBookUpgrades(BookUpgradeSource source, string? selected,
        Action<string> selection, Action<CityEquipmentView> purchase, Action? continueBusiness, Action close, string message)
    {
        _bookUpgradeSource = source; _city = source.CityId;
        _equipmentCity = _city; _selectedEquipment = selected;
        _bookUpgradeSelection = selection; _bookUpgradePurchase = purchase; _bookUpgradeContinue = continueBusiness;
        _bookUpgradeClose = close;
        RenderUpgradePage();
        if (source.SupportsContinue && message.Length > 0)
        {
            var plate = new Panel { Name = "UpgradeFeedbackPaper", Position = new(340, 866), Size = new(1220, 75), MouseFilter = MouseFilterEnum.Ignore };
            var paper = new StyleBoxFlat { BgColor = new("#FFF4D8"), BorderColor = new("#A98559"), CornerRadiusTopLeft = 10, CornerRadiusTopRight = 10, CornerRadiusBottomLeft = 10, CornerRadiusBottomRight = 10 };
            paper.SetBorderWidthAll(1); plate.AddThemeStyleboxOverride("panel", paper); _body.AddChild(plate);
        }
        if (message.Length == 0) return;
        var feedback = Text(_body, "UpgradeFeedback", message, new(356, 872, 1188, 62), 23, true);
        feedback.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        feedback.MaxLinesVisible = 2;
        feedback.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
    }

}
