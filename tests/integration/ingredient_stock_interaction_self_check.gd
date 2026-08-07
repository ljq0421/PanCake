extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null:
		game_session.call("begin_new_game")
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var workstation := main.get_node("Workstation") as Workstation
	workstation.set_process(false)

	_check(workstation.ingredient_stock_model.current(IngredientModel.EGG) == 6, "new game starts the egg tray at the sixth image state")
	_check(workstation.egg_button.stock_textures.size() == 6, "egg tray owns six scene-backed stock textures")
	_check(workstation.egg_button.artwork.texture.resource_path.ends_with("egg_stock_6_v1.png"), "full tray renders the sixth stock image without a number")
	_check(workstation.egg_restock_button != null and workstation.baocui_restock_button != null and workstation.ham_restock_button != null and workstation.scallion_restock_button != null, "four matching physical restock controls are stable scene content")
	var background_artwork := workstation.get_node("SafeArea/BackgroundArtwork") as TextureRect
	_check(background_artwork.texture.resource_path.ends_with("workstation_backplate_morning_mobile_cart_v1.png"), "initial mobile-cart backplate keeps the refill-container shelf clear")
	_check(workstation.ingredient_layer.baocui_texture.resource_path.ends_with("baocui_broken_v1.png"), "placed baocui uses the visibly broken sheet artwork")
	_check(_ingredient_rack_has_no_digits(workstation), "ingredient rack uses pictures and words instead of numeric stock labels")

	_fill_product_base(workstation.pancake_model)
	workstation.pour_used = true
	workstation._select_scraper()
	workstation._on_pointer_ended(Vector2(300, 300))
	workstation._refresh_p1_ui()

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	workstation._on_ingredient_gui_input(press, IngredientModel.EGG)
	_check(workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE, "the egg intent implicitly reaches the guarded egg phase")
	workstation._finish_ingredient_drag(Vector2(-400.0, -400.0))
	_check(workstation.ingredient_stock_model.current(IngredientModel.EGG) == 5, "failed off-griddle placement still consumes one egg")
	_check(not workstation.ingredient_model.has_type(IngredientModel.EGG), "failed placement does not create pancake ingredient data")
	_check(workstation.egg_button.artwork.texture.resource_path.ends_with("egg_stock_5_v1.png"), "failed placement immediately switches to the fifth stock image")

	var surface_center := workstation.pancake_surface.get_global_transform_with_canvas() * (workstation.pancake_surface.size * 0.5)
	workstation._on_ingredient_gui_input(press, IngredientModel.EGG)
	workstation._finish_ingredient_drag(surface_center)
	_check(workstation.ingredient_stock_model.current(IngredientModel.EGG) == 4, "successful placement also consumes exactly one egg")
	_check(workstation.ingredient_model.has_type(IngredientModel.EGG), "successful placement still creates ingredient business data")
	workstation._on_ingredient_gui_input(press, IngredientModel.EGG)
	workstation._finish_ingredient_drag(surface_center + Vector2(80.0, 0.0))
	_check(workstation.ingredient_stock_model.current(IngredientModel.EGG) == 3, "a second egg consumes another real portion")
	_check(workstation.ingredient_model.count_type(IngredientModel.EGG) == 2, "the same pancake accepts more than one egg")
	workstation.reset_pancake()
	_check(workstation.ingredient_stock_model.current(IngredientModel.EGG) == 3, "resetting a failed pancake does not refund consumed ingredients")

	while workstation.ingredient_stock_model.has_stock(IngredientModel.EGG):
		workstation.ingredient_stock_model.consume(IngredientModel.EGG)
	_check(not workstation.egg_button.empty_label.visible and not workstation.egg_button.artwork.visible, "empty stock leaves the pan visibly empty without permanent text")
	_check(workstation.egg_restock_button.disabled and not workstation.egg_restock_button.get_parent().visible, "empty tray does not expose the legacy one-click restock container")
	game_session.call("credit_coins", 20)
	var refill: RefCounted = workstation.get_node("SafeArea/PancakeWorkstationInteractionController").get("_restock")
	var egg_stock := &"stock.pancake.egg"
	var unit_seconds := float(refill.call("status", egg_stock).unit_seconds)
	refill.call("advance_hold", egg_stock, unit_seconds * 6.0)
	_check(workstation.ingredient_stock_model.current(IngredientModel.EGG) == 6, "the formal hold-refill service restores six visible portions one unit at a time")
	_check(workstation.egg_button.artwork.texture.resource_path.ends_with("egg_stock_6_v1.png"), "restock restores the sixth image state")
	_check(workstation.egg_restock_button.disabled, "the hidden legacy restock control remains disabled at full stock")

	if game_session != null:
		_check(int(game_session.call("inventory_snapshot").get("stock.pancake.egg", -1)) == 6, "restocked quantity persists through the formal save service")

	main.queue_free()
	if _failures.is_empty():
		print("INGREDIENT_STOCK_INTERACTION_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _fill_product_base(model: PancakeModel) -> void:
	for y in model.grid_size:
		for x in model.grid_size:
			if not model.is_inside_pan(Vector2(x, y), 0.84):
				continue
			var index := y * model.grid_size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.42
			model.wetness[index] = 0.20
	model.revision += 1
	model.changed.emit()


func _ingredient_rack_has_no_digits(workstation: Workstation) -> bool:
	var labels := workstation.get_node("SafeArea/IngredientRack").find_children("*", "Label", true, false)
	for label in labels:
		for character in str((label as Label).text):
			if character >= "0" and character <= "9":
				return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
