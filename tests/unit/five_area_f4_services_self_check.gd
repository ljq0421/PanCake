extends SceneTree

const SOY := preload("res://scripts/gameplay/fresh_soy_milk_machine_model.gd")
const STEAMER := preload("res://scripts/gameplay/steamer_layers_model.gd")
const PRODUCTION := preload("res://scripts/services/five_area_production_service.gd")
const PROGRESSION := preload("res://scripts/services/five_area_progression_service.gd")

class StubSession extends Node:
	var progression: RefCounted
	var inventory := {
		"stock.fresh_soy_milk.yellow_bean": 6,
		"stock.steamer.mantou": 6,
		"stock.steamer.vegetable_bun": 6,
	}

	func _init() -> void:
		progression = PROGRESSION.new({
			"unlocked_area_ids": [&"area.pancake", &"area.fresh_soy_milk", &"area.steamer"],
			"device_tiers": {&"device.pancake_griddle": 0, &"device.fresh_soy_milk_machine": 1, &"device.steamer": 1},
			"unlocked_recipe_ids": [&"recipe.pancake.base", &"recipe.fresh_soy_milk.yellow_bean", &"recipe.steamer.mantou", &"recipe.steamer.vegetable_bun"],
			"unlocked_product_ids": [&"product.pancake.custom", &"product.fresh_soy_milk.yellow_bean", &"product.steamer.mantou", &"product.steamer.vegetable_bun"],
			"unlocked_stock_ids": [&"stock.fresh_soy_milk.yellow_bean", &"stock.steamer.mantou", &"stock.steamer.vegetable_bun"],
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
	_check(bool(soy.call("add_water").get("success", false)) and bool(soy.call("start").get("success", false)), "soy machine requires water before grinding")
	soy.call("advance_time", 5.0, false)
	_check(StringName(soy.call("snapshot").get("state", &"")) == &"ready_safe", "base soy batch completes in five seconds")
	_check(int(soy.call("collect", 1).get("remaining_quantity", -1)) == 1, "manual soy collection releases one cup at a time")
	var soy_restored: RefCounted = SOY.new()
	soy_restored.call("load_snapshot", soy.call("snapshot"))
	_check(int(soy_restored.call("snapshot").get("quantity", 0)) == 1, "soy machine batch survives snapshot restore")

	var auto_soy: RefCounted = SOY.new(2, true)
	for batch in range(2):
		auto_soy.call("load_recipe", &"recipe.fresh_soy_milk.yellow_bean", 4)
		auto_soy.call("add_water")
		auto_soy.call("start")
		auto_soy.call("advance_time", 3.0, true)
		if batch == 0:
			_check(StringName(auto_soy.call("snapshot").get("state", &"")) == &"idle", "auto cup rack releases a completed batch when four slots are free")
	_check(StringName(auto_soy.call("snapshot").get("state", &"")) == &"blocked", "a full soy output rack keeps the second batch inside the machine")
	auto_soy.call("collect_output", 0)
	_check(StringName(auto_soy.call("snapshot").get("state", &"")) == &"blocked", "one free output slot is insufficient for a blocked four-cup batch")
	for slot_index in range(1, 4):
		auto_soy.call("collect_output", slot_index)
	_check(StringName(auto_soy.call("snapshot").get("state", &"")) == &"idle", "blocked soy batch releases only after all required rack slots are free")

	var steamer: RefCounted = STEAMER.new(1, true)
	_check(steamer.call("layer_capacity") == 2, "intermediate steamer opens exactly two layers")
	_check(bool(steamer.call("load_layer", 0, &"recipe.steamer.mantou", 1).get("success", false)), "first steamer layer accepts mantou")
	_check(bool(steamer.call("load_layer", 1, &"recipe.steamer.vegetable_bun", 1).get("success", false)), "second steamer layer accepts an independent recipe")
	_check(StringName(steamer.call("load_layer", 2, &"recipe.steamer.mantou", 1).get("reason", &"")) == &"layer_locked", "third layer remains locked at intermediate tier")
	steamer.call("start_layer", 0)
	steamer.call("start_layer", 1)
	steamer.call("advance_time", 7.5)
	var layers: Array = Array(steamer.call("snapshot").get("layers", []))
	_check(StringName(Dictionary(layers[0]).get("state", &"")) == &"ready_safe" and StringName(Dictionary(layers[1]).get("state", &"")) == &"steaming", "steamer layers advance independently by recipe duration")
	var steamer_restored: RefCounted = STEAMER.new()
	steamer_restored.call("load_snapshot", steamer.call("snapshot"))
	_check(StringName(Dictionary(Array(steamer_restored.call("snapshot").get("layers", []))[1]).get("recipe_id", &"")) == &"recipe.steamer.vegetable_bun", "all steamer layer recipe state survives restore")

	var stub := StubSession.new()
	root.add_child(stub)
	var production: RefCounted = PRODUCTION.new(stub)
	_check(bool(production.call("load_soy_batch", &"recipe.fresh_soy_milk.yellow_bean", 2).get("success", false)) and int(stub.inventory["stock.fresh_soy_milk.yellow_bean"]) == 4, "soy production consumes inventory atomically")
	production.call("perform_soy_action", &"add_water")
	production.call("perform_soy_action", &"start")
	production.call("advance_time", 3.0)
	var soy_products: Dictionary = production.call("collect_soy", 2)
	_check(Array(soy_products.get("products", [])).size() == 2 and StringName(Dictionary(soy_products.get("product", {})).get("product_id", &"")) == &"product.fresh_soy_milk.yellow_bean", "soy service creates stable order product instances")
	production.call("load_steamer_layer", 0, &"recipe.steamer.mantou", 1)
	production.call("load_steamer_layer", 1, &"recipe.steamer.vegetable_bun", 1)
	production.call("perform_steamer_action", 0, &"start")
	production.call("perform_steamer_action", 1, &"start")
	production.call("advance_time", 7.5)
	var production_restored: RefCounted = PRODUCTION.new(stub, production.call("snapshot"))
	var restored_machine: Dictionary = production_restored.call("machine_snapshot", &"device.steamer")
	_check(StringName(Dictionary(Array(restored_machine.get("layers", []))[0]).get("state", &"")) == &"ready_safe" and StringName(Dictionary(Array(restored_machine.get("layers", []))[1]).get("state", &"")) == &"steaming", "production service restores concurrent steamer layer timers")
	stub.queue_free()

	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FIVE_AREA_F4_SERVICES_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_F4_SERVICES_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
