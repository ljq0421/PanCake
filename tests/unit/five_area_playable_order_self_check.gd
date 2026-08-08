extends SceneTree

const GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")
const ORDER_SERVICE := preload("res://scripts/services/five_area_order_service.gd")
const PROGRESSION_SERVICE := preload("res://scripts/services/five_area_progression_service.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := _fully_playable_progression()
	var empty_inventory := _inventory(0)
	var first: Dictionary = GENERATOR.generate(progression, empty_inventory, 24680, 7, 8, 0)
	var repeated: Dictionary = GENERATOR.generate(progression, empty_inventory, 24680, 7, 8, 0)
	_check(first == repeated, "fixed seed and sequence generate an identical playable order")
	_check(bool(first.get("success", false)) and Array(first.get("items", [])).size() == 1, "the three-area slice always generates a single-item order")
	_check(_is_supported_area(_area_id(first)), "normal generation excludes soy-milk and steamer even when their data is unlocked")
	_check(bool(first.get("success", false)), "normal generation ignores zero physical stock")

	var seen := {}
	var heated_count := 0
	var sampled_only_supported := true
	for sequence in range(1, 401):
		var generated: Dictionary = GENERATOR.generate(progression, empty_inventory, 24680, sequence, 8, 0)
		var area_id := _area_id(generated)
		seen[area_id] = true
		sampled_only_supported = sampled_only_supported and _is_supported_area(area_id)
		var item := _item(generated)
		if area_id == &"area.packaged_drink" and StringName(item.get("temperature_mode", &"")) == &"heated":
			heated_count += 1
	_check(seen.has(&"area.pancake") and seen.has(&"area.packaged_drink") and seen.has(&"area.youtiao"), "deterministic weighted sampling can reach all three playable areas")
	_check(sampled_only_supported, "sampled normal orders stay inside the playable area allowlist")
	_check(heated_count > 0, "completed drink training enables deterministic heated-drink orders")

	var teaching_progression := progression.duplicate(true)
	teaching_progression["tutorial"] = {
		"completed_area_ids": [&"area.pancake"],
		"active_kind": &"area",
		"active_id": &"area.packaged_drink",
	}
	var blocked: Dictionary = GENERATOR.generate(teaching_progression, empty_inventory, 9, 1, 3, 0)
	_check(StringName(blocked.get("reason", &"")) == &"tutorial_restock_required" and Array(blocked.get("missing_stock_ids", [])).has("stock.packaged_drink.milk"), "drink teaching waits for one real unit of starter stock")
	var stocked_inventory := _inventory(0)
	stocked_inventory["stock.packaged_drink.milk"] = 1
	var teaching: Dictionary = GENERATOR.generate(teaching_progression, stocked_inventory, 9, 1, 3, 0)
	_check(_area_id(teaching) == &"area.packaged_drink" and StringName(_item(teaching).get("temperature_mode", &"")) == &"room_temperature", "starter drink teaching is a room-temperature single item")
	_check(is_equal_approx(float(Dictionary(teaching.get("metadata", {})).get("patience_seconds", 0.0)), 36.0), "drink teaching receives the specified 1.5x patience")

	var service: RefCounted = ORDER_SERVICE.new()
	var opened: Dictionary = service.call("ensure_queue", 1, teaching)
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	var refusal_preview: Dictionary = service.call("preview_refusal", order_id)
	_check(int(refusal_preview.get("reputation_delta", 0)) == -1, "unstarted refusal previews the smaller reputation loss")
	service.call("mark_production_started", order_id, &"device.packaged_drink_heater.slot.0")
	refusal_preview = service.call("preview_refusal", order_id)
	_check(int(refusal_preview.get("reputation_delta", 0)) == -2, "started production upgrades refusal to the wrong-order loss")
	var refused: Dictionary = service.call("refuse_order", order_id)
	var refused_retry: Dictionary = service.call("refuse_order", order_id)
	_check(StringName(refused.get("terminal_state", &"")) == &"refused" and bool(refused_retry.get("already_settled", false)), "refusal reaches one idempotent terminal result")

	service = ORDER_SERVICE.new()
	opened = service.call("ensure_queue", 1, teaching)
	service.call("advance_patience", 10.0)
	var restored: RefCounted = ORDER_SERVICE.new(service.call("snapshot"))
	var restored_order: Dictionary = restored.call("current_order")
	_check(is_equal_approx(float(restored_order.get("remaining_patience_seconds", 0.0)), 26.0), "remaining patience survives snapshot restore")
	var expired: Dictionary = restored.call("advance_patience", 30.0)
	_check(StringName(expired.get("terminal_state", &"")) == &"expired" and int(expired.get("reputation_delta", 0)) == -2, "patience exhaustion produces the formal expired loss")
	_check(Array(restored.call("waiting_orders")).is_empty(), "the current slice exposes no waiting orders")
	_check(StringName(Dictionary(restored.call("ensure_queue", 4, teaching)).get("reason", &"")) == &"waiting_queue_deferred", "four-order queue activation remains explicitly deferred")

	var progression_service: RefCounted = PROGRESSION_SERVICE.new()
	var first_failure: Dictionary = progression_service.call("record_tutorial_failure", &"area", &"area.pancake")
	var second_failure: Dictionary = progression_service.call("record_tutorial_failure", &"area", &"area.pancake")
	_check(int(first_failure.get("failure_count", 0)) == 1 and not bool(first_failure.get("tutorial_ended", false)), "the first teaching failure keeps the tutorial queued")
	_check(bool(second_failure.get("tutorial_ended", false)) and Array(Dictionary(progression_service.call("tutorial_snapshot")).get("completed_area_ids", [])).has("area.pancake"), "two consecutive teaching failures end training without a mastery award")

	_finish()


func _fully_playable_progression() -> Dictionary:
	return {
		"unlocked_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"],
		"unlocked_recipe_ids": [
			&"recipe.pancake.base", &"recipe.packaged_drink.milk", &"recipe.youtiao.plain",
			&"recipe.fresh_soy_milk.yellow_bean", &"recipe.steamer.mantou",
		],
		"unlocked_product_ids": [
			&"product.pancake.custom", &"product.packaged_drink.milk", &"product.youtiao.plain",
			&"product.fresh_soy_milk.yellow_bean", &"product.steamer.mantou",
		],
		"unlocked_stock_ids": [
			&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour",
			&"stock.packaged_drink.milk", &"stock.youtiao.plain_dough", &"stock.fresh_soy_milk.yellow_bean", &"stock.steamer.mantou",
		],
		"device_tiers": {
			&"device.pancake_griddle": 1, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0,
			&"device.fresh_soy_milk_machine": 1, &"device.steamer": 1,
		},
		"area_mastery_details": {
			&"area.packaged_drink": {"correct_temperature": 8},
			&"area.youtiao": {"qualified": 8},
		},
		"tutorial": {
			"completed_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"],
			"active_kind": &"",
			"active_id": &"",
		},
	}


func _inventory(value: int) -> Dictionary:
	var result := {}
	for stock_id in [
		"stock.pancake.batter", "stock.pancake.egg", "stock.pancake.baocui", "stock.pancake.scallion", "stock.pancake.sauce.sweet_flour",
		"stock.packaged_drink.milk", "stock.youtiao.plain_dough",
	]:
		result[stock_id] = value
	return result


func _item(result: Dictionary) -> Dictionary:
	var items: Array = Array(result.get("items", []))
	return {} if items.is_empty() else Dictionary(items[0])


func _area_id(result: Dictionary) -> StringName:
	return StringName(_item(result).get("area_id", &""))


func _is_supported_area(area_id: StringName) -> bool:
	return GENERATOR.PLAYABLE_AREA_IDS.has(area_id)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_PLAYABLE_ORDER_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
