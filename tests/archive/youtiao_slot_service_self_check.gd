extends SceneTree

const PRODUCTION := preload("res://scripts/services/five_area_production_service.gd")
const PROGRESSION := preload("res://scripts/services/five_area_progression_service.gd")

class StubSession extends Node:
	var progression := PROGRESSION.new({
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao"],
		"device_tiers": {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0},
		"unlocked_recipe_ids": [&"recipe.youtiao.plain"],
		"unlocked_product_ids": [&"product.youtiao.plain"],
		"unlocked_stock_ids": [&"stock.youtiao.plain_dough"],
	})
	var inventory := {"stock.youtiao.plain_dough": 4}

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array[StringName]) -> Dictionary:
		for stock_id in stock_ids:
			var key := str(stock_id)
			if int(inventory.get(key, 0)) <= 0:
				return {"success": false, "reason": &"insufficient_stock"}
		for stock_id in stock_ids:
			var key := str(stock_id)
			inventory[key] = int(inventory.get(key, 0)) - 1
		return {"success": true}


func _initialize() -> void:
	var stub := StubSession.new()
	root.add_child(stub)
	var production := PRODUCTION.new(stub)
	var loaded := Dictionary(production.call("load_batch", &"device.youtiao_fryer", &"recipe.youtiao.plain", 2))
	var discarded := Dictionary(production.call("discard_ready_youtiao", 0))
	var snapshot := Dictionary(production.call("machine_snapshot", &"device.youtiao_fryer"))
	var all_passed := bool(loaded.get("success", false)) and bool(discarded.get("success", false))
	all_passed = all_passed and Array(snapshot.get("occupied_slot_indices", [])).hash() == [1].hash()
	all_passed = all_passed and int(Dictionary(discarded.get("waste", {})).get("quantity", 0)) == 1
	var restored := PRODUCTION.new(stub, production.call("snapshot"))
	var restored_snapshot := Dictionary(restored.call("machine_snapshot", &"device.youtiao_fryer"))
	all_passed = all_passed and Array(restored_snapshot.get("occupied_slot_indices", [])).hash() == [1].hash()
	restored.call("perform_action", &"device.youtiao_fryer", &"start")
	restored.call("advance_time", 12.0)
	restored.call("perform_action", &"device.youtiao_fryer", &"lift")
	restored.call("advance_time", 2.0)
	var preview := Dictionary(restored.call("preview_collect_batch", &"device.youtiao_fryer", 1, 1))
	var collected := Dictionary(restored.call("collect_batch", &"device.youtiao_fryer", 1, 1))
	all_passed = all_passed and bool(preview.get("success", false)) and int(preview.get("source_index", -1)) == 1
	all_passed = all_passed and bool(collected.get("success", false)) and StringName(restored.call("machine_snapshot", &"device.youtiao_fryer").get("state", &"")) == &"idle"
	stub.queue_free()
	if all_passed:
		print("YOUTIAO_SLOT_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("YOUTIAO_SLOT_SERVICE_SELF_CHECK_FAIL")
	quit(1)
