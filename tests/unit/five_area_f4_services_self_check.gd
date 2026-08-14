extends SceneTree

const SOY := preload("res://scripts/gameplay/fresh_soy_milk_machine_model.gd")
const PRODUCTION := preload("res://scripts/services/five_area_production_service.gd")
const PROGRESSION := preload("res://scripts/services/five_area_progression_service.gd")

class StubSession extends Node:
	var progression: RefCounted
	var inventory := {
		"stock.youtiao.dough": 6,
		"stock.fresh_soy_milk.yellow_bean": 6,
	}

	func _init() -> void:
		progression = PROGRESSION.new({
			"unlocked_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"],
			"device_tiers": {
				&"device.pancake_griddle": 2,
				&"device.youtiao_fryer": 0,
				&"device.fresh_soy_milk_machine": 1,
			},
			"unlocked_recipe_ids": [
				&"recipe.pancake.base",
				&"recipe.youtiao.classic",
				&"recipe.fresh_soy_milk.yellow_bean",
			],
			"unlocked_product_ids": [
				&"product.pancake.custom",
				&"product.youtiao.classic",
				&"product.fresh_soy_milk.yellow_bean",
			],
			"unlocked_stock_ids": [
				&"stock.youtiao.dough",
				&"stock.fresh_soy_milk.yellow_bean",
			],
		})

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array[StringName]) -> Dictionary:
		var required := {}
		for stock_id in stock_ids:
			required[str(stock_id)] = int(required.get(str(stock_id), 0)) + 1
		for key in required:
			if int(inventory.get(key, 0)) < int(required[key]):
				return {"success": false, "reason": &"insufficient_stock"}
		for key in required:
			inventory[key] = int(inventory.get(key, 0)) - int(required[key])
		return {"success": true}

var failures := PackedStringArray()


func _initialize() -> void:
	var soy: RefCounted = SOY.new(0, true)
	_check(soy.call("capacity") == 2, "base soy machine exposes two cups")
	_check(bool(soy.call("load_recipe", &"recipe.fresh_soy_milk.yellow_bean", 2).get("success", false)), "soy machine accepts a two-cup bean batch")
	_check(bool(soy.call("add_water").get("success", false)) and bool(soy.call("start").get("success", false)), "soy machine keeps the direct add-water and grind actions")
	soy.call("advance_time", 5.0, false)
	_check(StringName(soy.call("snapshot").get("state", &"")) == &"ready_safe", "base soy batch completes with an automatic cup")
	_check(int(soy.call("collect", 1).get("remaining_quantity", -1)) == 1, "automatic soy output releases one cup at a time")
	var soy_restored: RefCounted = SOY.new()
	soy_restored.call("load_snapshot", soy.call("snapshot"))
	_check(int(soy_restored.call("snapshot").get("quantity", 0)) == 1, "soy machine batch survives snapshot restore")

	var stub := StubSession.new()
	root.add_child(stub)
	var production: RefCounted = PRODUCTION.new(stub)
	_check(bool(production.call("load_soy_batch", &"recipe.fresh_soy_milk.yellow_bean", 2).get("success", false)) and int(stub.inventory["stock.fresh_soy_milk.yellow_bean"]) == 4, "soy production starts without any customer-order provider and consumes inventory atomically")
	production.call("perform_soy_action", &"add_water")
	production.call("perform_soy_action", &"start")
	production.call("advance_time", 4.0)
	var first_result: Dictionary = production.call("collect_soy", 1)
	var second_result: Dictionary = production.call("collect_soy", 1)
	var first_product := Dictionary(first_result.get("product", {}))
	var second_product := Dictionary(second_result.get("product", {}))
	_check(StringName(first_product.get("product_id", &"")) == &"product.fresh_soy_milk.yellow_bean" and StringName(first_product.get("product_instance_id", &"")) != StringName(second_product.get("product_instance_id", &"")), "soy service creates distinct product instances through repeated cups")

	var ready_product := {
		"product_instance_id": &"product_instance.pancake_griddle.2.7",
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"grade": &"A",
	}
	var griddle_snapshot := {
		"version": 1,
		"griddle_count": 3,
		"active_index": 1,
		"product_sequence": 7,
		"slots": [
			{"state": 0, "order": {}, "ready_product": {}},
			{"state": 6, "order": {"product_id": &"product.pancake.custom"}, "ready_product": ready_product},
			{"state": 2, "order": {"product_id": &"product.pancake.custom"}, "ready_product": {}},
		],
	}
	_check(bool(production.call("set_pancake_griddles_snapshot", griddle_snapshot).get("success", false)), "production service accepts three independent griddle slots")
	var preview: Dictionary = production.call("preview_pancake_griddle_ready", 1)
	_check(bool(preview.get("success", false)) and StringName(Dictionary(preview.get("product", {})).get("product_instance_id", &"")) == &"product_instance.pancake_griddle.2.7", "ready pancake can be previewed without consuming it")

	var restored: RefCounted = PRODUCTION.new(stub, production.call("snapshot"))
	var restored_griddles: Dictionary = restored.call("pancake_griddles_snapshot")
	_check(int(restored_griddles.get("griddle_count", 0)) == 3 and int(restored_griddles.get("active_index", -1)) == 1 and int(restored_griddles.get("product_sequence", 0)) == 7, "griddle count, focus and product sequence survive service restore")
	_check(bool(restored.call("take_pancake_griddle_ready", 1).get("success", false)), "delivery atomically consumes the selected ready pancake")
	_check(StringName(restored.call("preview_pancake_griddle_ready", 1).get("reason", &"")) == &"pancake_not_ready", "consumed pancake cannot be delivered twice")
	_check(StringName(restored.call("machine_snapshot", &"device.steamer").get("state", &"")) == &"unsupported", "retired steamer is not exposed as a production machine")
	_check(StringName(restored.call("machine_snapshot", &"device.packaged_drink_heater").get("state", &"")) == &"unsupported", "retired packaged-drink heater is not exposed as a production machine")
	var all_machines: Dictionary = restored.call("all_machine_snapshots")
	_check(all_machines.size() == 2 and all_machines.has(&"device.youtiao_fryer") and all_machines.has(&"device.fresh_soy_milk_machine"), "machine registry contains only youtiao and soy devices")
	stub.queue_free()

	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("THREE_AREA_PRODUCTION_SERVICES_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_AREA_PRODUCTION_SERVICES_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
