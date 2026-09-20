using Godot;
using ProjectCake.Data;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private TianjinLoopMotion? _loopMotion;
    private TextureRect? _bagArt;
    private long _loopGeneration = -1;
    private static Vector2 IngredientOffset(string id) => id switch
    {
        StableIds.Ingredients.Crispy => new(-.13f, 0),
        StableIds.Ingredients.Scallion => new(.13f, -.22f),
        StableIds.Ingredients.Ham => new(.14f, .14f),
        StableIds.Ingredients.Youtiao or StoredYoutiaoPayload => new(-.03f, .1f),
        _ => Vector2.Zero,
    };
    private void SyncLoopGeneration()
    {
        if (_loopGeneration == Machine.Runtime.Generation) return;
        _loopGeneration = Machine.Runtime.Generation;
        _loopMotion?.Reset();
        _drag.ClearAcceptedVisuals();
        _canvas.ResetIngredientMotion();
        _canvas.EndSauceStroke();
    }

    private void ConfigureLoopMotion()
    {
        _loopMotion = new TianjinLoopMotion { Name = "TianjinLoopMotion",
            Active = () => _initialized && IsVisibleInTree() && InteractionEnabled && !Paused };
        AddChild(_loopMotion);
        _canvas.EnableIngredientDetail(_art);
        _stroke.SaucePainted = _canvas.PaintSauce;
        _stroke.StrokeEnded = _canvas.EndSauceStroke;
        _stroke.GentleSauceTool = true;
        foreach (var (id, slot) in _ingredientSlots)
        {
            // One representative portion, never the tray or its hit area.
            if (id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce) continue;
            foreach (TextureRect art in slot.IngredientVisuals)
                _loopMotion.Bind(art, () => slot.IngredientVisuals.FirstOrDefault(v => v.Visible) == art
                    && CanUse(id) && !_drag.IsDragging && slot.GetGlobalRect().HasPoint(slot.GetGlobalMousePosition())
                    ? Input.IsMouseButtonPressed(MouseButton.Left) ? 2 : 1 : 0);
        }
        _bagArt = (TextureRect)_finished.FindChild("FinishedPancakeArt", true, false);
        _loopMotion.Bind(_bagArt, () => CanDeliverProduct("finished_pancake") && !_drag.IsDragging
            && _finished.GetGlobalRect().HasPoint(_finished.GetGlobalMousePosition()) ? 1 : 0);
        _drag.DragStarted += payload => { if (payload == "finished_pancake") _loopMotion.Reset(); };
    }

    private void PlayLoopAction(PancakeCommand command, string? ingredient)
    {
        if (_loopMotion is null) return;
        SyncLoopGeneration();
        if (command == PancakeCommand.Bag && _bagArt is not null)
        {
            // Bagged is already deliverable before this purely visual tail starts.
            _loopMotion.Land(_bagArt);
            _loopMotion.Contact(() => _audio.Play(PancakeSound.PaperBag), .055);
            return;
        }
        if (command == PancakeCommand.Fold)
        {
            _loopMotion.Reset();
            _drag.ClearAcceptedVisuals();
            _canvas.ResetIngredientMotion();
            _canvas.LandIngredient("fold", 0, .045f);
            return;
        }
        if (command == PancakeCommand.Flip && ReducedMotion) _audio.Play(PancakeSound.Sizzle);
        if (command != PancakeCommand.AddIngredient && command != PancakeCommand.AddEgg) return;
        string id = command == PancakeCommand.AddEgg ? StableIds.Ingredients.Egg : ingredient!;
        bool crisp = id is StableIds.Ingredients.Crispy or StableIds.Ingredients.Youtiao;
        _canvas.LandIngredient(id, ReducedMotion ? 0 : id == StableIds.Ingredients.Egg ? .20f : .11f,
            id == StableIds.Ingredients.Crispy ? 0 : crisp ? .02f : id == StableIds.Ingredients.Scallion ? 0 : .045f);
        Rect2 surface = _canvas.GetSurfaceRect();
        Vector2 offset = IngredientOffset(id);
        Vector2 center = _canvas.GetGlobalTransform() * (surface.GetCenter() + surface.Size * offset);
        Vector2 from = _ingredientSlots.TryGetValue(id, out var slot) ? slot.GetGlobalRect().GetCenter() : GetGlobalMousePosition();
        // DragService owns the moving image on drag drops; clicks need their own portion.
        void Contact() => _audio.Play(id == StableIds.Ingredients.Egg ? PancakeSound.Sizzle
            : crisp ? PancakeSound.CrispDrop : PancakeSound.SoftDrop);
        if (id == StableIds.Ingredients.Egg) _loopMotion.CrackEgg(this, _art.Ingredient(id), _art.EggShell, from, center, Contact);
        else if (_drag.IsDragging) _loopMotion.Contact(Contact);
        else _loopMotion.Fly(this, _art.Ingredient(id), from, center, crisp ? new(95, 60) : new(58, 48), Contact);
    }
}
