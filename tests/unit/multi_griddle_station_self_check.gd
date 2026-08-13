extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")

class FakeSession:
	extends Node
	var inventory := {
		"stock.pancake.batter": 3,
		"stock.pancake.egg": 3,
		"stock.pancake.baocui": 3,
		"stock.pancake.sauce.sweet_flour": 3,
	}

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array) -> Dictionary:
		for value in stock_ids:
			var key := str(value)
			if int(inventory.get(key, 0)) <= 0:
				return {"success": false, "reason": &"insufficient_stock", "stock_id": StringName(value)}
		for value in stock_ids:
			var key := str(value)
			inventory[key] = int(inventory.get(key, 0)) - 1
		return {"success": true}

	func take_prepared_product(_slot_id: StringName) -> Dictionary:
		return {"success": false, "reason": &"empty"}


var failures := PackedStringArray()
var target_order := {
	"product_id": &"product.pancake.custom",
	"heat_preference": &"golden",
	"ingredient_ids": PackedStringArray(["stock.pancake.egg", "stock.pancake.baocui"]),
	"sauce_ids": PackedStringArray(["stock.pancake.sauce.sweet_flour"]),
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := FakeSession.new()
	root.add_child(session)
	var station := STATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	station.bind_session(session, Callable(self, "_order"))
	station.set_griddle_count(3)
	_check(station.griddle_count() == 3, "advanced station exposes three griddles")
	for unit_index in 3:
		station.call("_on_main_action", unit_index)
	_check(int(session.inventory["stock.pancake.batter"]) == 0, "starting three griddles immediately consumes three portions of batter")
	for unit_index in 3:
		var unit: Node = station.units[unit_index]
		unit.pancake_model.add_batter(Vector2(31.5, 31.5), 1.2, 27.0)
		unit.p1_session.confirm_spread(unit.pancake_model)
		unit.state = 2
		unit.first_side_seconds = 2.5
		unit.pancake_model.advance_cooking(2.5, unit.p1_session.heat_level)
		station.call("_on_main_action", unit_index)
		unit.second_side_seconds = 2.6
		unit.pancake_model.advance_cooking(2.6, unit.p1_session.heat_level)
		station.call("_on_main_action", unit_index)
	station.call("_on_sauce_action", 0)
	station.call("_on_ingredient_action", 0)
	station.call("_on_ingredient_action", 0)
	station.call("_on_fold_action", 0)
	station.call("_on_fold_action", 0)
	var ready_refs: Array = station.ready_source_refs()
	_check(ready_refs.size() == 1, "one independently completed griddle exposes one delivery source")
	var product := Dictionary(Dictionary(ready_refs[0]).get("product", {})) if not ready_refs.is_empty() else {}
	var completed_summary: Dictionary = station.units[0].pancake_model.calculate_summary()
	var completed_heat := (float(completed_summary.get("mean_doneness", 0.0)) + float(completed_summary.get("mean_back_doneness", 0.0))) * 0.5
	var expected_heat: StringName = &"light" if completed_heat < 0.34 else (&"golden" if completed_heat < 0.62 else &"well_done")
	_check(StringName(product.get("heat_preference", &"")) == expected_heat, "ready product preserves the heat calculated from both cooked surfaces")
	_check(PackedStringArray(product.get("ingredient_ids", [])) == target_order.ingredient_ids, "product carries exactly the manually added ingredients")
	_check(PackedStringArray(product.get("sauce_ids", [])) == target_order.sauce_ids, "product carries exactly the manually added sauce")
	_check(int(session.inventory["stock.pancake.egg"]) == 2 and int(session.inventory["stock.pancake.baocui"]) == 2, "ingredient actions consume physical stock immediately")
	var persisted: Dictionary = station.snapshot()
	_check(int(persisted.get("product_sequence", 0)) == 1 and Array(persisted.get("slots", [])).size() == 3, "three-griddle snapshot preserves the ready product sequence and all independent surfaces")
	_check(station.consume_ready(0), "delivered griddle can be consumed by source index")
	_check(station.ready_source_refs().is_empty(), "consumed griddle returns to an empty work surface")
	station.queue_free()
	session.queue_free()
	_finish()


func _order() -> Dictionary:
	return target_order.duplicate(true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MULTI_GRIDDLE_STATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("MULTI_GRIDDLE_STATION_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
