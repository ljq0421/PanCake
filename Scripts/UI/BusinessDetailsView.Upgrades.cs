using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
    private Control? _upgradeModal;
    private Button? _upgradeEntry;
    private bool _buying;
    private bool CanUpgrade => _model.Closing && !_model.Practice && _model.Upgrades is not null;
    private void RefreshUpgradeCaptions()
    {
        if (_model.Upgrades is null) return;
        var stickers = _model.Stickers.Where(s => !s.Contains("升级")).ToList();
        var offers = CanUpgrade ? _model.Upgrades.Offers : Array.Empty<BookUpgradeOffer>();
        if (offers.Count > 0) stickers.Add($"可升级：{offers[0].Name} Lv{offers[0].TargetLevel}" + (offers.Count > 1 ? $"等{offers.Count}项" : ""));
        _model.Stickers = stickers.ToArray();
    }
    private void AddPlainUpgradeEntry()
    {
        if (!CanUpgrade || _model.Upgrades!.Offers.Count == 0) return;
        _upgradeEntry = ButtonAt(_summary, "可升级 · 查看效果", new(1130, 605, 350, 58), OpenUpgrades);
        _upgradeEntry.Name = "UpgradeSticker";
    }
    private void OpenUpgrades()
    {
        if (!CanUpgrade || _upgradeModal is not null) return;
        FinishAnimation(); RenderUpgradeModal("");
    }
    private void RenderUpgradeModal(string message)
    {
        RemoveUpgradeModal();
        var source = _model.Upgrades!;
        var modal = new Control { Name = "BookUpgradeModal", Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Stop };
        _upgradeModal = modal; _canvas.AddChild(modal);
        Line(modal, new(0, 0, 1920, 1080), new Color(.12f, .08f, .04f, .55f));
        Panel(modal, new(460, 170, 1000, 740), CitySettlementTheme.Paper, 20, 3);
        Text(modal, "设备升级", new(505, 204, 540, 50), 34, Accent);
        Text(modal, $"当前余额 ¥{source.Coins}", new(1065, 210, 350, 40), 26, Ink, HorizontalAlignment.Right);
        var scroll = new ScrollContainer { Name = "UpgradeScroll", Position = new(505, 282), Size = new(910, 460), HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        modal.AddChild(scroll);
        var rows = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; rows.AddThemeConstantOverride("separation", 26); scroll.AddChild(rows);
        var offers = source.Offers;
        if (offers.Count == 0) Text(rows, "暂无可购买升级", new(0, 0, 850, 60), 26, Muted);
        foreach (var offer in offers)
        {
            string effects = source.Effects(offer);
            float h = WrappedHeight(effects, 865, 24);
            var row = new Control { Name = "Upgrade_" + offer.EquipmentId, CustomMinimumSize = new(0, h + 137), MouseFilter = MouseFilterEnum.Ignore }; rows.AddChild(row);
            Text(row, $"{offer.Name}  Lv{offer.CurrentLevel} → Lv{offer.TargetLevel}", new(0, 0, 865, 42), 28, Accent);
            Text(row, effects, new(0, 52, 865, h), 24, Ink, wrap: true);
            var buy = ButtonAt(row, $"升级 ¥{offer.Price}", new(635, h + 66, 230, 56), () => BuyUpgrade(offer));
            buy.Name = "Buy_" + offer.EquipmentId;
            buy.FocusEntered += () => scroll.EnsureControlVisible(buy);
            Line(row, new(0, h + 134, 865, 2), CityTheme.Divider);
        }
        var feedback = Text(modal, message.Length == 0 ? "升级后，下次营业生效。" : message, new(505, 760, 910, 62), 23, Muted, wrap: true);
        feedback.Name = "UpgradeFeedback";
        feedback.MaxLinesVisible = 2; feedback.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
        feedback.TooltipText = feedback.Text; feedback.MouseFilter = MouseFilterEnum.Pass;
        var close = ButtonAt(modal, "返回账本", new(1185, 830, 230, 56), CloseUpgrades); close.Name = "CloseUpgrades";
        close.GrabFocus();
    }
    private void BuyUpgrade(BookUpgradeOffer offer)
    {
        if (_buying || !CanUpgrade || _upgradeModal is null) return;
        _buying = true;
        try
        {
            bool ok = _model.Upgrades!.Purchase(offer, out string error);
            RefreshUpgradeCaptions(); BuildSummary(); RefreshRows();
            RenderUpgradeModal(ok ? "升级成功，下次营业生效。" : error);
        }
        finally { _buying = false; }
    }
    private void RemoveUpgradeModal()
    {
        if (_upgradeModal is null) return;
        _upgradeModal.GetParent().RemoveChild(_upgradeModal); _upgradeModal.QueueFree(); _upgradeModal = null;
    }
    private void CloseUpgrades()
    {
        RemoveUpgradeModal();
        if (IsInstanceValid(_upgradeEntry) && _upgradeEntry!.IsVisibleInTree()) _upgradeEntry.GrabFocus();
        else CloseButton.GrabFocus();
    }
}
