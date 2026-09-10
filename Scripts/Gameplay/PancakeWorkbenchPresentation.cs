using Godot;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private void ConfigureTianjinPresentation()
    {
        _canvas.UseTableContact = true;
        _fryerVisual.UseTableContact = true;
        foreach ((string id, IngredientStockSlotView slot) in _ingredientSlots)
        {
            bool bowl = id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce;
            Texture2D tray = id == StableIds.Ingredients.Batter ? _art.BatterContainer
                : id == StableIds.Ingredients.Sauce ? _art.SauceContainer : _art.WorkbenchTray;
            slot.ConfigureStock(tray, _art.Ingredient(id), IngredientName(id), TianjinWorkbenchLayout.IngredientSlot(id),
                bowl ? IngredientVisualMode.Single : id == StableIds.Ingredients.Scallion
                    ? IngredientVisualMode.LooseStock : IngredientVisualMode.HybridStock);
            slot.ShowStockNumbers = false;
            slot.HideNameplate();
        }
        // All three trays share the same rear contact line. The cash tray has
        // its own darker finish and a coin inlay, keeping it visually distinct.
        foreach (string name in new[] { "CoinTrayArt", "FinishedTrayArt", "SoyMilkTrayArt" })
        {
            if (FindChild(name, true, false) is not TextureRect tray) continue;
            tray.Texture = _art.WorkbenchTray;
            tray.CustomMinimumSize = Vector2.Zero;
            tray.Position = TianjinWorkbenchLayout.RearTrayVisual.Position;
            tray.Size = TianjinWorkbenchLayout.RearTrayVisual.Size;
            tray.StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered;
            if (name == "CoinTrayArt")
            {
                tray.SelfModulate = new Color(.70f, .68f, .64f);
                tray.GetNode<TextureRect>("CoinTrayInlay").Texture = _art.Coin;
            }
        }
        if (_rawYoutiaoInput.GetParent().GetParent() is WorkstationSlotView raw)
        {
            raw.Configure(_art.WorkbenchTray, _art.RawYoutiao, "", TianjinWorkbenchLayout.RawYoutiaoSlot(), IngredientVisualMode.WideSingle);
            raw.GetNode<TextureRect>("VisualLayer/Tray").FlipH = true;
            raw.HideNameplate();
        }
        _finishedYoutiaoSlot.Configure(_art.WorkbenchRack, _art.Ingredient(StableIds.Ingredients.Youtiao), "熟油条",
            TianjinWorkbenchLayout.FinishedYoutiaoTableSlot(), IngredientVisualMode.WideStock);
        _trashZone.HitPadding = 0;
    }
}
