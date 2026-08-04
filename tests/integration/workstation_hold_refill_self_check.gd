extends SceneTree

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const PREVIEW_SCENE := preload("res://scenes/main/initial_unlock_preview.tscn")
const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null:
		game_session.call("begin_new_game")
	var preview := PREVIEW_SCENE.instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame
	var workstation := preview.get_node("Workstation")
	var adapter := workstation.get_node("SafeArea/InitialUnlockAdapter")
	adapter.call("apply_progression_snapshot", {
		"coins": 20,
		"ingredient_stock": {"egg": 0, "baocui": 0, "ham_sausage": 0, "scallion": 0},
	})
	await process_frame

	_check(adapter.get("progression").get("inventory") == workstation.get("ingredient_stock_model"), "HoldRefillService and the live workstation share one ingredient inventory object")
	_check(_fixed_tray_contract(workstation), "the scene keeps exactly twelve fixed 4x3 tray hit regions and only the first three are unlocked")
	_check(not (workstation.get_node("SafeArea/RestockRack") as CanvasItem).visible, "the legacy one-click restock rack is not player-visible")
	_check(_direct_refill_contract(workstation), "the first three serving trays own the direct hold-to-refill gesture and no drawer exists")
	_check(_has_no_refill_progress_ui(workstation), "ingredient trays contain no ring, bar, percentage, or permanent text")
	_check(_small_ingredient_refill_times_are_fast(), "tray ingredients use the six-times-speed 0.167-to-0.267-second per-unit refill tuning")

	var egg_slot := workstation.get_node("SafeArea/IngredientRack/EggButton")
	_check(egg_slot.has_method("begin_gesture") and egg_slot.has_method("update_gesture"), "unlocked tray keeps deterministic movement-threshold drag hooks")
	_check(bool(egg_slot.get_meta(&"refill_enabled", false)), "the serving tray is the refill hold target")
	if egg_slot.has_method("begin_gesture") and egg_slot.has_method("advance_gesture") and egg_slot.has_method("update_gesture"):
		_check_gesture_thresholds(workstation, adapter, egg_slot)

	_check_refill_accounting(workstation, adapter, egg_slot)
	_check_refill_stops(workstation, adapter, egg_slot)

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var main_workstation := main.get_node("Workstation")
	_check(main_workstation.scene_file_path.ends_with("initial_unlock_workstation.tscn"), "the real main-game path uses the adapted initial-unlock workstation")
	_check(main_workstation.get_node_or_null("SafeArea/InitialUnlockAdapter") != null, "the real main-game path owns the same refill adapter as the isolated preview")
	_check(main_workstation.get_node_or_null("SafeArea/ExpansionLayout/RightZone/RefillDrawer") == null, "the real main-game path has no refill drawer")
	_check(bool(main_workstation.get_node("SafeArea/IngredientRack/EggButton").get_meta(&"refill_enabled", false)), "the real main-game egg tray supports direct hold refill")

	main.queue_free()
	preview.queue_free()
	await process_frame
	_finish()


func _check_gesture_thresholds(workstation: Node, adapter: Node, slot: Control) -> void:
	var inventory: RefCounted = workstation.get("ingredient_stock_model")
	inventory.call("set_current", CATALOG.STOCK_EGG, 1)
	adapter.get("progression").set("coins", 20)
	_fill_product_base(workstation.get("pancake_model"))
	workstation.set("pour_used", true)
	workstation.call("_select_scraper")
	workstation.call("_on_pointer_ended", Vector2(300.0, 300.0))
	workstation.call("_refresh_p1_ui")
	var drag_state := [false]
	if slot.has_signal("drag_requested"):
		slot.connect("drag_requested", func(_ingredient_type: StringName, _press_position: Vector2) -> void: drag_state[0] = true, CONNECT_ONE_SHOT)
	slot.call("begin_gesture", Vector2(20.0, 20.0))
	slot.call("advance_gesture", 0.09)
	_check(not bool(slot.call("is_hold_active")), "a press shorter than 0.1 seconds does not start refill")
	slot.call("update_gesture", Vector2(29.9, 20.0))
	_check(not bool(drag_state[0]), "movement below 10px stays pending")
	slot.call("update_gesture", Vector2(30.1, 20.0))
	_check(bool(drag_state[0]), "movement beyond 10px enters the established ingredient drag path")
	_check(StringName(workstation.get("_ingredient_drag_type")) == CATALOG.STOCK_EGG, "movement-threshold drag reaches the real workstation ingredient controller")
	workstation.set("_ingredient_drag_type", &"")


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


func _check_refill_accounting(workstation: Node, adapter: Node, slot: Button) -> void:
	var inventory: RefCounted = workstation.get("ingredient_stock_model")
	var progression: RefCounted = adapter.get("progression")
	var refill: RefCounted = adapter.call("refill_service")
	var unit_seconds := float(CATALOG.refill_definition(CATALOG.STOCK_EGG).unit_seconds)
	var unit_cost := int(CATALOG.refill_definition(CATALOG.STOCK_EGG).unit_cost)
	inventory.call("set_current", CATALOG.STOCK_EGG, 0)
	progression.set("coins", 20)
	progression.call("set_refill_progress", CATALOG.STOCK_EGG, 0.0)
	slot.call("begin_gesture", Vector2(20.0, 20.0))
	slot.call("advance_gesture", 0.10)
	_check(bool(slot.call("is_hold_active")) and StringName(adapter.get("_active_refill_stock_id")) == CATALOG.STOCK_EGG, "an unmoved 0.1-second hold on the egg tray starts refill")
	var coins_before := int(progression.get("coins"))
	slot.call("advance_gesture", unit_seconds)
	_check(int(inventory.call("current", CATALOG.STOCK_EGG)) == 1, "each completed unit immediately adds one visible stock portion")
	_check(int(progression.get("coins")) == coins_before - unit_cost, "each completed unit immediately charges exactly its unit cost")
	slot.call("advance_gesture", unit_seconds * 0.35)
	var partial_before_release := float(refill.call("status", CATALOG.STOCK_EGG).progress_seconds)
	slot.call("end_gesture")
	_check(is_equal_approx(float(refill.call("status", CATALOG.STOCK_EGG).progress_seconds), partial_before_release), "release preserves unfinished internal progress without displaying it")
	slot.call("begin_gesture", Vector2(20.0, 20.0))
	slot.call("advance_gesture", 0.10)
	slot.call("advance_gesture", unit_seconds * 0.65)
	_check(int(inventory.call("current", CATALOG.STOCK_EGG)) == 2, "a later hold resumes the saved partial unit")
	slot.call("end_gesture")


func _check_refill_stops(workstation: Node, adapter: Node, slot: Button) -> void:
	var inventory: RefCounted = workstation.get("ingredient_stock_model")
	var progression: RefCounted = adapter.get("progression")
	var capacity := int(inventory.call("capacity", CATALOG.STOCK_EGG))
	inventory.call("set_current", CATALOG.STOCK_EGG, capacity)
	progression.set("coins", 20)
	slot.call("begin_gesture", Vector2(20.0, 20.0))
	slot.call("advance_gesture", 0.10)
	_check(StringName(adapter.get("_active_refill_stock_id")) == &"", "a full tray never starts refill")
	_check(not bool(slot.call("is_hold_active")), "a full tray rejects the hold gesture")

	inventory.call("set_current", CATALOG.STOCK_EGG, 0)
	progression.set("coins", 0)
	slot.call("begin_gesture", Vector2(20.0, 20.0))
	slot.call("advance_gesture", 0.10)
	_check(StringName(adapter.get("_active_refill_stock_id")) == &"", "a tray never starts refill when the next unit is unaffordable")
	_check(not bool(slot.call("is_hold_active")), "an unaffordable tray rejects the hold gesture")


func _fixed_tray_contract(workstation: Node) -> bool:
	var grid := workstation.get_node("SafeArea/ExpansionLayout/RightZone/IngredientTrayGrid") as GridContainer
	if grid.columns != 4 or grid.get_child_count() != 12:
		return false
	for index in grid.get_child_count():
		var tray := grid.get_child(index) as BaseButton
		if tray == null:
			return false
		if index < 3:
			if not bool(tray.get_meta(&"day_one_occupied", false)):
				return false
		else:
			if not tray.disabled or tray.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				return false
	return true


func _direct_refill_contract(workstation: Node) -> bool:
	if workstation.get_node_or_null("SafeArea/ExpansionLayout/RightZone/RefillDrawerHandle") != null:
		return false
	if workstation.get_node_or_null("SafeArea/ExpansionLayout/RightZone/RefillDrawer") != null:
		return false
	for slot_name in [&"EggButton", &"BaocuiButton", &"ScallionButton"]:
		var slot := workstation.get_node_or_null("SafeArea/IngredientRack/%s" % slot_name) as Button
		if slot == null or not bool(slot.get_meta(&"refill_enabled", false)):
			return false
		if not slot.has_signal("drag_requested") or not slot.has_signal("hold_requested"):
			return false
	return true


func _has_no_refill_progress_ui(workstation: Node) -> bool:
	var ingredient_rack := workstation.get_node("SafeArea/IngredientRack")
	var tray_grid := workstation.get_node("SafeArea/ExpansionLayout/RightZone/IngredientTrayGrid")
	for root_node in [ingredient_rack, tray_grid]:
		if not root_node.find_children("*", "ProgressBar", true, false).is_empty():
			return false
		if not root_node.find_children("*", "TextureProgressBar", true, false).is_empty():
			return false
		for label in root_node.find_children("*", "Label", true, false):
			var text := str((label as Label).text)
			if "%" in text or "补货进度" in text:
				return false
	return true


func _small_ingredient_refill_times_are_fast() -> bool:
	var expected := {
		CATALOG.STOCK_EGG: 1.20 / 6.0,
		CATALOG.STOCK_BAOCUI: 1.35 / 6.0,
		CATALOG.STOCK_HAM_SAUSAGE: 1.60 / 6.0,
		CATALOG.STOCK_SCALLION: 1.00 / 6.0,
	}
	for stock_id: StringName in expected:
		var definition := CATALOG.refill_definition(stock_id)
		if not is_equal_approx(float(definition.get("unit_seconds", 0.0)), float(expected[stock_id])):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WORKSTATION_HOLD_REFILL_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
