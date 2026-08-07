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
	station.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	station._refresh_p1_ui()
	_check(not station.step_action_button.visible and station.step_action_button.text.is_empty(), "the redundant Start Folding step action is removed")
	station.tool_controller.clear_tool()
	var fold_edge := Vector2(station.pancake_surface.size.x * 0.12, station.pancake_surface.size.y * 0.5)
	station._on_pointer_started(fold_edge)
	_check(station.p1_session.phase == P1Session.Phase.FOLD and station.tool_controller.current_tool == ToolController.Tool.FOLD and station.fold_model.active_region != PancakeFoldModel.REGION_NONE, "pointer-down on an exposed edge enters and begins folding without selecting FoldButton")
	station._on_cancel_requested()
	station.queue_free()
	await process_frame
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 40)
	progression.set("current_day", 8)
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.coriander").get("success", false)), "coriander purchase is accepted")
	session.call("end_business_day")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "coriander purchase activates")
	var refreshed_station = WORKSTATION_SCENE.instantiate()
	root.add_child(refreshed_station)
	await process_frame
	await process_frame
	var coriander_button := refreshed_station.get_node("SafeArea/IngredientRack/CorianderButton") as Button
	var slot_lock := refreshed_station.get_node("SafeArea/LockedIngredientArtwork/Slot06") as CanvasItem
	var slot_interaction := refreshed_station.get_node("SafeArea/LockedIngredientInteractions/Slot06LockedButton") as Button
	_check(coriander_button.visible and not coriander_button.disabled, "activated coriander appears in its direct ingredient tray")
	_check(not slot_lock.visible and slot_interaction.disabled, "activated coriander removes the stale lock from material slot 06")
	_check((coriander_button.get_node("EmptyLabel") as Label).text.contains("6份"), "activated coriander begins with usable stock instead of an empty tray")
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
