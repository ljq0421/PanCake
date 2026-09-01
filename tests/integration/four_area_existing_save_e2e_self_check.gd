extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession public service is available after process restart")
	if session == null:
		_finish()
		return

	_check(bool(session.is_four_area_save_active()) and not Array(session.active_formal_orders()).is_empty(), "the separate Godot process restores the saved customer and order")
	_check(bool(session.continue_game()) and bool(session.is_business_paused()), "continue game keeps persisted business state paused until scene binding")
	var day_end := Dictionary(session.end_business_day({"reason": &"p0_existing_save"}))
	_check(bool(day_end.get("success", false)) and Array(session.active_formal_orders()).is_empty(), "day end clears the restored open order")
	_check(Dictionary(session.inventory_snapshot()).values().all(func(value): return int(value) == 0), "day end clears all remaining stock")
	_check_empty_single_griddle(session)

	var next_day := Dictionary(session.begin_next_business_day())
	var progression := Dictionary(session.four_area_progression_snapshot())
	var inventory := Dictionary(session.inventory_snapshot())
	_check(bool(next_day.get("success", false)) and bool(session.is_opening_restock_active()), "next day returns to a fresh restock window")
	_check(Array(progression.get("owned_growth_ids", [])).has("growth.add_on.pancake.meat_floss") and Array(next_day.get("restock_required_ids", [])).has("stock.pancake.meat_floss") and int(inventory.get("stock.pancake.meat_floss", -1)) == 0, "reserved meat-floss growth activates next day and starts empty for player restock")
	_finish()


func _check_empty_single_griddle(session: Node) -> void:
	var griddles := Dictionary(session.pancake_griddles_snapshot())
	_check(int(griddles.get("griddle_count", 0)) == 1 and Array(griddles.get("slots", [])).is_empty(), "day end clears the permanent single griddle")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FOUR_AREA_EXISTING_SAVE_E2E_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FOUR_AREA_EXISTING_SAVE_E2E_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
