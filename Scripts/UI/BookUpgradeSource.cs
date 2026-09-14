using ProjectCake.Core;
using ProjectCake.Yangzhou;

namespace ProjectCake.UI;

/// <summary>Queries and purchases upgrades without recommitting the day's immutable result.</summary>
public sealed class BookUpgradeSource
{
    private readonly SaveService _save;
    private readonly DataCatalog? _catalog;
    private readonly YangzhouCatalog? _yangzhou;
    private readonly string _city;
    public CityEquipmentView[] Equipment => new CityPageModel(_catalog, _save, _yangzhou).Equipment(_city);
    public int Coins => _save.Data.Coins;
    public BookUpgradeSource(SaveService save, DataCatalog catalog, string city) { _save = save; _catalog = catalog; _city = city; }
    public BookUpgradeSource(SaveService save, YangzhouCatalog catalog) { _save = save; _yangzhou = catalog; _city = YangzhouCatalog.CityId; }
    public IReadOnlyList<BookUpgradeOffer> Offers => _yangzhou is not null ? _save.BookOffers(_yangzhou) : _save.BookOffers(_city, _catalog!);
    public string Effects(BookUpgradeOffer offer) => BookUpgradeEffects.Describe(offer, _catalog, _yangzhou);
    public bool Purchase(BookUpgradeOffer offer, out string error)
    {
        // Compare target as well as ID: Yangzhou purchases otherwise mean "buy the next level".
        if (!Offers.Contains(offer)) { error = "该升级已购买或当前金币不足，请查看最新升级列表。"; return false; }
        return _yangzhou is not null ? _save.PurchaseYangzhou(offer.PurchaseId, _yangzhou, out error)
            : _save.TryPurchase(_city, offer.PurchaseId, _catalog!, out error);
    }
}
