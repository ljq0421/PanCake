extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")
const HOTSPOTS_SCRIPT := preload("res://scripts/ui/pancake_worktop_hotspots.gd")
const DRAG_SOURCE_SCRIPT := preload("res://scripts/ui/product_drag_source.gd")


class FakeProgression:
	extends RefCounted

	var locked := {}
	var stock_capacity := 6

	func owns_stock(stock_id: StringName) -> bool:
		return not locked.has(stock_id)

	func owns_growth(_growth_id: StringName) -> bool:
		return false

class FakeSession:
	extends Node

	var progression := FakeProgression.new()
	var inventory := {
		"stock.pancake.batter": 2,
		"stock.pancake.egg": 2,
		"stock.pancake.baocui": 2,
		"stock.pancake.scallion": 2,
		"stock.pancake.coriander": 2,
		"stock.pancake.sauce.sweet_flour": 2,
		"stock.pancake.sauce.red_chili": 2,
	}

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array) -> Dictionary:
		for stock_id in stock_ids:
			if int(inventory.get(str(stock_id), 0)) <= 0:
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
	var unit: Node = station.units[0]
	_test_egg_on_both_sides(station, unit, session)
	_test_sauce_selection_and_first_stroke(station, unit, session)
	_test_sauce_guards_second_side_and_restore(station, unit, session)
	_test_worktop_hotspot_mapping(station, unit, session)
	station.queue_free()
	session.queue_free()
	_finish()


func _test_egg_on_both_sides(station: Node, unit: Node, session: FakeSession) -> void:
	var source := {"source_kind": &"pancake_shared_ingredient", "stock_id": &"stock.pancake.egg"}
	var center: Vector2 = unit.pancake_surface.size * 0.5
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	var first_validation := Dictionary(unit.validate_ingredient_drop(source, center))
	_check(bool(first_validation.get("success", false)), "egg can be dropped on the first side")
	unit.reset_unit()
	unit.begin_order({})
	unit.pancake_model.flip(true)
	unit.state = CompactGriddleUnit.State.SECOND_SIDE
	var second_validation := Dictionary(unit.validate_ingredient_drop(source, center))
	_check(bool(second_validation.get("success", false)), "egg can be dropped on the second side")
	var placed := Dictionary(station.drop_on_unit(0, source, center))
	_check(bool(placed.get("success", false)) and unit.pancake_model.has_egg(), "second-side egg placement records the egg")
	_check(int(session.inventory["stock.pancake.egg"]) == 1, "egg placement consumes exactly one inventory unit")
	_check(not bool(unit.validate_ingredient_drop(source, center).get("success", false)), "a second egg is rejected as a duplicate")


func _test_sauce_selection_and_first_stroke(station: Node, unit: Node, session: FakeSession) -> void:
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	var center: Vector2 = unit.pancake_surface.size * 0.5
	var before := int(session.inventory["stock.pancake.sauce.sweet_flour"])
	var selected := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	var primed_total := float(unit.pancake_model.total_sauce())
	_check(bool(selected.get("success", false)), "sweet sauce jar primes the direct-brush tool")
	_check(int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before - 1, "sauce jar click consumes exactly one inventory unit")
	_check(primed_total > 0.0 and unit.applied_sauce_ids.has("stock.pancake.sauce.sweet_flour"), "sauce jar click places a central dollop and records its recipe identifier")
	_check(unit.pancake_surface.cursor_is_sauce_brush and unit.state == CompactGriddleUnit.State.GARNISH, "sauce jar click enters garnish flow and automatically arms the brush")
	unit._on_surface_pointer_started(center)
	unit._on_surface_pointer_ended(center)
	_check(int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before - 1, "drag brushing does not consume a second inventory unit")
	_check(float(unit.pancake_model.total_sauce()) >= primed_total, "drag brushing preserves and spreads the primed sauce")
	var before_duplicate := int(session.inventory["stock.pancake.sauce.sweet_flour"])
	var duplicate := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	_check(not bool(duplicate.get("success", false)) and int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before_duplicate, "duplicate sauce jar click is rejected without consuming inventory")


func _test_sauce_guards_second_side_and_restore(station: Node, unit: Node, session: FakeSession) -> void:
	station.clear_held_tool()
	unit.reset_unit()
	unit.begin_order({})
	unit.pancake_model.flip(true)
	unit.state = CompactGriddleUnit.State.SECOND_SIDE
	unit.p1_session.phase = P1Session.Phase.SECOND_SIDE
	var initial_chili := int(session.inventory["stock.pancake.sauce.red_chili"])
	session.progression.locked[&"stock.pancake.sauce.red_chili"] = true
	var locked := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.red_chili"))
	_check(not bool(locked.get("success", false)) and int(session.inventory["stock.pancake.sauce.red_chili"]) == initial_chili, "locked chili sauce cannot prime or consume inventory")
	session.progression.locked.erase(&"stock.pancake.sauce.red_chili")
	session.inventory["stock.pancake.sauce.red_chili"] = 0
	var depleted := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.red_chili"))
	_check(not bool(depleted.get("success", false)) and is_zero_approx(float(unit.pancake_model.total_sauce())), "depleted chili sauce cannot create a dollop")
	session.inventory["stock.pancake.sauce.red_chili"] = initial_chili
	var primed := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.red_chili"))
	_check(bool(primed.get("success", false)) and unit.state == CompactGriddleUnit.State.GARNISH, "chili sauce can prime on the second side")
	_check(int(session.inventory["stock.pancake.sauce.red_chili"]) == initial_chili - 1 and unit.applied_sauce_ids.has("stock.pancake.sauce.red_chili"), "second-side chili prime consumes and records exactly once")
	var saved := Dictionary(unit.snapshot())
	var saved_sauce_total := float(unit.pancake_model.total_sauce())
	unit.reset_unit()
	var restored := Dictionary(unit.load_snapshot(saved))
	_check(bool(restored.get("success", false)) and unit.applied_sauce_ids.has("stock.pancake.sauce.red_chili") and is_equal_approx(float(unit.pancake_model.total_sauce()), saved_sauce_total), "primed sauce and recipe identifier survive snapshot restore")
	_check(not unit.pancake_surface.cursor_is_sauce_brush, "snapshot restore does not restore the temporary held brush")
	station.clear_held_tool()
	unit.reset_unit()
	var before_wrong_stage := int(session.inventory["stock.pancake.sauce.red_chili"])
	var wrong_stage := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.red_chili"))
	_check(not bool(wrong_stage.get("success", false)) and int(session.inventory["stock.pancake.sauce.red_chili"]) == before_wrong_stage, "wrong-stage sauce click does not consume inventory")


func _test_worktop_hotspot_mapping(station: Node, unit: Node, session: FakeSession) -> void:
	var hotspots := HOTSPOTS_SCRIPT.new()
	hotspots.griddle_station_path = NodePath("../MultiGriddleStation")
	for hotspot_name in [&"ScallionHotspot", &"CorianderHotspot", &"BaocuiHotspot", &"EggHotspot", &"SweetSauceHotspot", &"ChiliSauceHotspot"]:
		var source := DRAG_SOURCE_SCRIPT.new()
		source.name = hotspot_name
		hotspots.add_child(source)
	var spreader := TextureButton.new()
	spreader.name = &"SpreaderHotspot"
	hotspots.add_child(spreader)
	root.add_child(hotspots)
	await process_frame
	session.progression.locked[&"stock.pancake.sauce.red_chili"] = true
	hotspots.bind_session(session)
	_check(StringName(hotspots.get_node("ScallionHotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.scallion", "left worktop bowl maps to scallion stock")
	_check(StringName(hotspots.get_node("CorianderHotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.coriander", "coriander tray maps to coriander stock")
	_check(StringName(hotspots.get_node("BaocuiHotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.baocui", "middle worktop basket maps to baocui stock")
	_check(StringName(hotspots.get_node("EggHotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.egg", "right worktop basket maps to egg stock")
	_check(bool(hotspots.get_node("ScallionHotspot").native_drag_enabled), "ingredient bowls use drag placement")
	_check(bool(hotspots.get_node("CorianderHotspot").native_drag_enabled), "coriander tray uses drag placement")
	_check(not bool(hotspots.get_node("SweetSauceHotspot").native_drag_enabled), "sauce jars select direct brushing instead of drag placement")
	_check(bool(hotspots.get_node("ChiliSauceHotspot").disabled), "locked chili sauce hotspot cannot be used")
	session.progression.locked.erase(&"stock.pancake.sauce.red_chili")
	hotspots.refresh_from_session()
	_check(not bool(hotspots.get_node("ChiliSauceHotspot").disabled), "unlocked chili sauce hotspot becomes usable")
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	var sweet := hotspots.get_node("SweetSauceHotspot") as ProductDragSource
	sweet.begin_gesture(Vector2.ZERO)
	sweet.end_gesture()
	var brush_start := Dictionary(station.begin_surface_action(0, unit.pancake_surface.size * 0.5))
	_check(bool(brush_start.get("success", false)) and StringName(brush_start.get("action", &"")) == CompactGriddleUnit.SURFACE_ACTION_BRUSH_SAUCE, "sweet sauce hotspot short click routes to direct brushing")
	hotspots.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PANCAKE_WORKTOP_HOTSPOTS_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_WORKTOP_HOTSPOTS_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
