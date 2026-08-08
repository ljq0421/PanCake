extends SceneTree

const WORKSTATION_SCENE = preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var station = WORKSTATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	await process_frame
	station.pancake_model.coverage.fill(0.4)
	station.pancake_model.is_flipped = true
	station.pancake_model.crack_egg(Vector2(station.pancake_model.grid_size, station.pancake_model.grid_size) * 0.5)
	station.egg_crack_artwork.visible = true
	station.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	station._refresh_p1_ui()
	_check(not station.step_action_button.visible and station.step_action_button.text.is_empty(), "the redundant Start Folding step action is removed")
	station.tool_controller.clear_tool()
	var fold_edge := Vector2(station.pancake_surface.size.x * 0.12, station.pancake_surface.size.y * 0.5)
	station._on_pointer_started(fold_edge)
	_check(station.p1_session.phase == P1Session.Phase.FOLD and station.tool_controller.current_tool == ToolController.Tool.FOLD and station.fold_model.active_region != PancakeFoldModel.REGION_NONE, "pointer-down on an exposed edge enters and begins folding without selecting FoldButton")
	_check(not station.fold_button.visible and not station.egg_crack_artwork.visible, "folding uses the pancake edge directly and encloses the post-flip egg artwork without a folding spatula")
	station._on_cancel_requested()
	station.queue_free()
	await process_frame
	var progression: RefCounted = session.call("progression_service")
	var unlocked_stock_ids: Dictionary = Dictionary(progression.get("unlocked_stock_ids")).duplicate(true)
	unlocked_stock_ids[&"stock.pancake.ham_sausage"] = true
	unlocked_stock_ids[&"stock.pancake.meat_floss"] = true
	unlocked_stock_ids[&"stock.pancake.pork_tenderloin"] = true
	unlocked_stock_ids[&"stock.pancake.preserved_mustard"] = true
	progression.set("unlocked_stock_ids", unlocked_stock_ids)
	progression.set("coins", 40)
	progression.set("current_day", 8)
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.coriander").get("success", false)), "coriander purchase is accepted")
	session.call("end_business_day")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "coriander purchase activates")
	progression.set("coins", 100)
	var refill_inventory: Dictionary = session.call("inventory_snapshot")
	for stock_id in [&"stock.pancake.ham_sausage", &"stock.pancake.meat_floss", &"stock.pancake.coriander", &"stock.pancake.preserved_mustard", &"stock.pancake.pork_tenderloin"]:
		refill_inventory[str(stock_id)] = 0
	session.call("save_inventory", refill_inventory)
	var refreshed_station = WORKSTATION_SCENE.instantiate()
	root.add_child(refreshed_station)
	await process_frame
	await process_frame
	var coriander_button := refreshed_station.get_node("SafeArea/IngredientRack/CorianderButton") as Button
	var slot_lock := refreshed_station.get_node("SafeArea/LockedIngredientArtwork/Slot06") as CanvasItem
	var slot_interaction := refreshed_station.get_node("SafeArea/LockedIngredientInteractions/Slot06LockedButton") as Button
	var ham_button := refreshed_station.get_node("SafeArea/IngredientRack/HamButton") as Button
	var meat_floss_button := refreshed_station.get_node("SafeArea/IngredientRack/MeatFlossButton") as Button
	var preserved_button := refreshed_station.get_node("SafeArea/IngredientRack/PreservedMustardButton") as Button
	var tenderloin_button := refreshed_station.get_node("SafeArea/IngredientRack/PorkTenderloinButton") as Button
	_check(coriander_button.visible and not coriander_button.disabled, "activated coriander appears in its direct ingredient tray")
	_check(not slot_lock.visible and not slot_interaction.visible and slot_interaction.disabled, "the fourth unlocked later add-on occupies Slot06 and removes its lock")
	_check(StringName(ham_button.get_meta(&"material_slot_id", &"")) == &"slot.10" and StringName(meat_floss_button.get_meta(&"material_slot_id", &"")) == &"slot.11", "later add-ons begin compacting at Slot10-Slot11")
	_check(StringName(coriander_button.get_meta(&"material_slot_id", &"")) == &"slot.12" and StringName(preserved_button.get_meta(&"material_slot_id", &"")) == &"slot.06" and StringName(tenderloin_button.get_meta(&"material_slot_id", &"")) == &"slot.13", "later unlocked add-ons continue through the confirmed priority wells")
	var coriander_empty_text := (coriander_button.get_node("EmptyLabel") as Label).text
	_check(coriander_empty_text.contains("缺货") and not coriander_empty_text.contains("待解锁"), "activated coriander is shown as unlocked stock that now needs refilling")
	var refill_sources := {
		&"stock.pancake.ham_sausage": ham_button,
		&"stock.pancake.meat_floss": meat_floss_button,
		&"stock.pancake.coriander": coriander_button,
		&"stock.pancake.preserved_mustard": preserved_button,
		&"stock.pancake.pork_tenderloin": tenderloin_button,
	}
	var expected_charge := 0
	var interaction_controller := refreshed_station.get_node("SafeArea/PancakeWorkstationInteractionController")
	for stock_id in refill_sources:
		var source: Button = refill_sources[stock_id]
		_check(bool(source.get_meta(&"refill_enabled", false)) and is_equal_approx(float(source.get("hold_threshold_seconds")), 0.1), "%s supports the shared 0.1-second hold-to-restock gesture" % stock_id)
		var refill_status: Dictionary = interaction_controller.get("_restock").call("status", stock_id)
		expected_charge += int(refill_status.get("unit_cost", 0)) * 2
		source.call("begin_gesture", source.get_global_rect().get_center())
		source.call("advance_gesture", 0.1)
		source.call("advance_gesture", float(refill_status.get("unit_seconds", 0.25)) * 2.0)
		source.call("end_gesture")
	await process_frame
	var inventory_after_refill: Dictionary = session.call("inventory_snapshot")
	for stock_id in refill_sources:
		_check(int(inventory_after_refill.get(str(stock_id), 0)) == 2, "holding %s continuously adds two stock portions" % stock_id)
	_check(int(progression.get("coins")) == 100 - expected_charge, "continuous add-on restocking charges each completed portion exactly once")
	refreshed_station.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FOLD_AND_CORIANDER_UNLOCK_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FOLD_AND_CORIANDER_UNLOCK_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
