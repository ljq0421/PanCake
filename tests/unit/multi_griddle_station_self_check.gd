extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")
const PRODUCTION_SERVICE := preload("res://scripts/services/five_area_production_service.gd")

class FakeProgression:
	extends RefCounted
	var stock_capacity := 6
	var owned_growth_ids := PackedStringArray()

	func owns_stock(_stock_id: StringName) -> bool:
		return true

	func owns_growth(growth_id: StringName) -> bool:
		return owned_growth_ids.has(str(growth_id))


class FakeSession:
	extends Node
	var progression := FakeProgression.new()
	var inventory := {"stock.pancake.batter": 0}

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array) -> Dictionary:
		for stock_id in stock_ids:
			var key := str(stock_id)
			if int(inventory.get(key, 0)) <= 0:
				return {"success": false, "reason": &"insufficient_stock"}
		for stock_id in stock_ids:
			var key := str(stock_id)
			inventory[key] = int(inventory.get(key, 0)) - 1
		return {"success": true}


var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := FakeSession.new()
	root.add_child(session)
	var station := STATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	station.bind_session(session)
	var shared_tool_tray := station.get_node("SharedToolTray") as SharedPancakeToolTray
	_check(station.units.size() == 1, "single-stall scene authors exactly one griddle unit")
	_check(not shared_tool_tray._press_spreader_button.visible, "the press icon stays hidden before its upgrade activates")
	_check(station.get_node_or_null("Griddle01") != null and station.get_node_or_null("Griddle02") == null and station.get_node_or_null("Griddle03") == null, "secondary griddle nodes are absent")
	station.set_griddle_count(3)
	_check(station.griddle_count() == 1, "legacy count requests cannot expand the single stall")
	var unit: Node = station.units[0]
	_check(unit.position.is_equal_approx(Vector2(405.0, 36.0)), "the sole griddle remains centered in the operation area")
	station.call("_on_main_action", 0)
	_check(int(session.inventory["stock.pancake.batter"]) == 0 and unit.state == CompactGriddleUnit.State.BATTER, "the visible griddle starts with unlimited batter and does not consume inventory")
	_check(unit.pancake_surface.visible and unit.pancake_surface._has_point(unit.pancake_surface.size * 0.5), "the single griddle keeps its elliptical interactive pancake surface")
	var locked_press := Dictionary(station.select_worktop_tool(&"tool.pancake.press_once"))
	_check(not bool(locked_press.get("success", false)) and StringName(locked_press.get("reason", &"")) == &"tool_locked", "the press tool stays unavailable before its growth unlock")
	session.progression.owned_growth_ids.append("growth.automation.pancake.press_once")
	shared_tool_tray.refresh_from_session()
	_check(shared_tool_tray._press_spreader_button.visible, "the press icon appears in the shared workstation tray after activation")
	var press_result := Dictionary(station.select_worktop_tool(&"tool.pancake.press_once"))
	_check(bool(press_result.get("success", false)) and unit.state == CompactGriddleUnit.State.FIRST_SIDE, "the unlocked press tool converts batter into a ready first-side pancake")
	unit.reset_unit()
	station.call("_on_main_action", 0)
	var legacy_slot := Dictionary(unit.snapshot())
	var legacy_snapshot := {"version": 1, "griddle_count": 3, "active_index": 2, "product_sequence": 7, "slots": [legacy_slot, {}, {}]}
	unit.reset_unit()
	var migration := Dictionary(station.load_snapshot(legacy_snapshot))
	_check(bool(migration.get("success", false)) and station.griddle_count() == 1 and station.units[0].state == CompactGriddleUnit.State.BATTER, "legacy multi-griddle snapshot restores only its primary slot")
	var production: RefCounted = PRODUCTION_SERVICE.new()
	var saved := Dictionary(production.call("set_pancake_griddles_snapshot", legacy_snapshot))
	var normalized := Dictionary(production.call("pancake_griddles_snapshot"))
	_check(bool(saved.get("success", false)) and int(normalized.get("griddle_count", 0)) == 1 and Array(normalized.get("slots", [])).size() == 1 and int(normalized.get("active_index", -1)) == 0, "production persistence normalizes old multi-griddle snapshots")
	station.queue_free()
	session.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SINGLE_GRIDDLE_STATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("SINGLE_GRIDDLE_STATION_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
