extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/main/initial_unlock_preview.tscn")
const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const EGG_STOCK := &"stock.pancake.egg"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	session.call("credit_coins", 20)
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory[str(EGG_STOCK)] = 0
	session.call("save_inventory", inventory)

	var preview := PREVIEW_SCENE.instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame
	var workstation := preview.get_node("Workstation")
	var controller := workstation.get_node("SafeArea/PancakeWorkstationInteractionController")
	var egg_slot := workstation.get_node("SafeArea/IngredientRack/EggButton") as Button
	_check(controller != null, "the scene uses the formal pancake interaction controller")
	_check(workstation.get_node_or_null("SafeArea/InitialUnlockAdapter") == null, "the retired workstation adapter is absent")
	_check(_direct_refill_contract(workstation), "the first three serving trays own the direct hold-to-refill gesture")
	_check(_has_no_refill_progress_ui(workstation), "ingredient trays contain no ring, bar, percentage, or permanent text")
	_check(bool(egg_slot.get_meta(&"refill_enabled", false)), "the serving tray remains the refill hold target")

	if controller == null:
		preview.queue_free()
		await process_frame
		_finish()
		return
	var formal_status: Dictionary = session.call("five_area_restock_status", EGG_STOCK)
	_check(bool(formal_status.get("success", false)) and int(formal_status.get("current_stock", -1)) == 0, "formal five-area inventory is the restock source")
	var unit_seconds := float(formal_status.get("unit_seconds", 0.0))
	egg_slot.call("begin_gesture", Vector2(20.0, 20.0))
	egg_slot.call("advance_gesture", 0.10)
	_check(bool(egg_slot.call("is_hold_active")) and StringName(controller.get("_active_refill_stock_id")) == EGG_STOCK, "an unmoved 0.1-second hold starts formal restock")
	var coins_before := int(session.call("five_area_progression_snapshot").get("coins", 0))
	egg_slot.call("advance_gesture", unit_seconds)
	var after_one: Dictionary = session.call("five_area_restock_status", EGG_STOCK)
	_check(int(after_one.get("current_stock", 0)) == 1 and int(after_one.get("coins", 0)) == coins_before - 1, "one completed unit atomically updates formal inventory and formal coins")
	_check(int(workstation.get("ingredient_stock_model").call("current", &"egg")) == 1, "the visible egg tray mirrors the formal inventory result")
	egg_slot.call("advance_gesture", unit_seconds * 0.35)
	egg_slot.call("end_gesture")
	var partial_progress := float(session.call("five_area_restock_status", EGG_STOCK).get("progress_seconds", 0.0))
	_check(partial_progress > 0.0 and partial_progress < unit_seconds, "release preserves formal partial-restock time")
	egg_slot.call("begin_gesture", Vector2(20.0, 20.0))
	egg_slot.call("advance_gesture", 0.10)
	egg_slot.call("advance_gesture", unit_seconds * 0.65)
	egg_slot.call("end_gesture")
	_check(int(session.call("five_area_restock_status", EGG_STOCK).get("current_stock", 0)) == 2, "a later hold resumes the saved formal partial unit")

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var main_workstation := main.get_node("Workstation")
	_check(main_workstation.get_node_or_null("SafeArea/PancakeWorkstationInteractionController") != null, "the real main-game route uses the formal restock controller")
	main.queue_free()
	preview.queue_free()
	await process_frame
	_finish()


func _direct_refill_contract(workstation: Node) -> bool:
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
	for root_node in [workstation.get_node_or_null("SafeArea/IngredientRack"), workstation.get_node_or_null("SafeArea/ExpansionLayout/RightZone/IngredientTrayGrid")]:
		if root_node == null:
			continue
		if not root_node.find_children("*", "ProgressBar", true, false).is_empty():
			return false
		if not root_node.find_children("*", "TextureProgressBar", true, false).is_empty():
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
