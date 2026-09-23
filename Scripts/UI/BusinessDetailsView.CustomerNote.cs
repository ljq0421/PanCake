using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
    private WuhanArtCatalog? _notePortraitArt;

    private void AddNewCustomerNote(Control note, Vector2 firstPortrait, float portraitSize, Rect2 collectionButtonBounds,
        Rect2 overflowBounds, int actionFontSize)
    {
        var cards = _model.NewCustomerIds.Select(CustomerCollection.Find).Where(card => card is not null)
            .Select(card => card!).ToArray();
        if (cards.Length == 0) return;

        note.MouseFilter = MouseFilterEnum.Stop;
        _notePortraitArt ??= new WuhanArtCatalog();
        const int visibleLimit = 5;
        float gap = portraitSize + 3;
        foreach (var (card, index) in cards.Take(visibleLimit).Select((card, index) => (card, index)))
        {
            var bounds = new Rect2(firstPortrait + new Vector2(index * gap, 0), Vector2.One * portraitSize);
            Panel(note, bounds, new("#F8EACF"), Mathf.RoundToInt(portraitSize / 2), 1);
            var head = _notePortraitArt.CustomerPortrait(card.Id, CustomerExpression.Normal).Head;
            using var pixels = head.GetImage();
            var used = pixels.GetUsedRect();
            var portrait = Picture(note, new AtlasTexture { Atlas = head, Region = new Rect2(used.Position, used.Size) },
                new(bounds.Position + new Vector2(3, 1.5f), bounds.Size - new Vector2(6, 3)));
            portrait.Name = "NewCustomerPortrait_" + card.Id;
        }

        if (cards.Length > visibleLimit)
            Text(note, $"等 {cards.Length} 位", overflowBounds, Math.Max(14, actionFontSize), Muted, HorizontalAlignment.Center);

        var open = ButtonAt(note, "查看旅途收藏", collectionButtonBounds, OpenCustomerCollection);
        open.Name = "OpenCustomerCollection";
        open.TooltipText = "前往旅途收藏中的顾客图鉴";
        open.AddThemeFontSizeOverride("font_size", actionFontSize);
    }

    private void OpenCustomerCollection()
    {
        if (_model.NewCustomerIds.Length > 0 && _model.Closing)
            CustomerCollectionRequested?.Invoke();
    }
}
