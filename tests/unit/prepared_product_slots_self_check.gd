extends SceneTree

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
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.youtiao.oil_cake": true, &"recipe.youtiao.sugar_oil_cake": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.youtiao.oil_cake": true, &"product.youtiao.sugar_oil_cake": true})
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true})

	var plain_a := _product(&"plain.a", &"product.youtiao.plain", 88.0, &"A", 2)
	var plain_b := _product(&"plain.b", &"product.youtiao.plain", 72.0, &"B", 2)
	_check(bool(session.call("_append_prepared_product", &"slot.04", plain_a).get("success", false)) and bool(session.call("_append_prepared_product", &"slot.04", plain_b).get("success", false)), "Slot04 accepts plain-youtiao product instances")
	_check(session.call("_append_prepared_product", &"slot.05", plain_a).get("reason") == &"prepared_product_slot_mismatch" and int(Dictionary(session.call("prepared_product_slot_status", &"slot.05")).get("count", -1)) == 0, "wrong prepared-product slot rejects without changing inventory")
	var first_take: Dictionary = session.call("take_prepared_product", &"slot.04")
	_check(StringName(Dictionary(first_take.get("product", {})).get("product_instance_id", &"")) == &"plain.a" and is_equal_approx(float(Dictionary(first_take.get("product", {})).get("quality", 0.0)), 88.0), "prepared-product slot takes FIFO and preserves product quality")
	session.call("clear_prepared_product_slots")
	for index in 6:
		session.call("_append_prepared_product", &"slot.04", _product(StringName("capacity.%d" % index), &"product.youtiao.plain", 80.0, &"A", 2))
	var overflow: Dictionary = session.call("_append_prepared_product", &"slot.04", plain_a)
	_check(overflow.get("reason") == &"prepared_product_slot_full" and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 6, "prepared-product slot capacity six rolls back overflow")
	session.call("clear_prepared_product_slots")

	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.youtiao.plain_dough"] = 1
	session.call("save_inventory", inventory)
	_check(bool(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1).get("success", false)), "plain youtiao dough loads for atomic slot transfer")
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 12.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var mismatch := Dictionary(session.call("store_ready_youtiao_in_prepared_slot", &"slot.05"))
	_check(mismatch.get("reason") == &"prepared_product_slot_mismatch" and int(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("quantity", 0)) == 1, "mismatched fryer transfer leaves the ready product in the basket")
	var stored := Dictionary(session.call("store_ready_youtiao_in_prepared_slot", &"slot.04"))
	var stored_product := Dictionary(stored.get("product", {}))
	_check(bool(stored.get("success", false)) and int(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("quantity", -1)) == 0 and not StringName(stored_product.get("product_instance_id", &"")).is_empty() and stored_product.has("grade"), "matching fryer transfer atomically preserves the product instance and releases the basket")

	var opened := Dictionary(session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1}]))
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	var staged := Dictionary(session.call("stage_product_to_order", {"source_kind": &"prepared_product_slot", "source_slot_id": &"slot.04", "source_index": -1, "product_id": &"product.youtiao.plain"}, order_id, 0))
	_check(bool(staged.get("success", false)) and StringName(Dictionary(staged.get("product", {})).get("product_instance_id", &"")) == StringName(stored_product.get("product_instance_id", &"")) and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 0, "formal order consumes the FIFO prepared-slot source instead of the fryer")

	var save_data := Dictionary(session.get("_save_data")).duplicate(true)
	save_data.erase("prepared_product_slots")
	session.set("_save_data", save_data)
	session.call("_ensure_save_shape")
	var legacy_slots := Dictionary(session.call("prepared_product_slots_snapshot"))
	_check(Array(legacy_slots.get("slot.04", [])).is_empty() and Array(legacy_slots.get("slot.05", [])).is_empty() and Array(legacy_slots.get("slot.06", [])).is_empty(), "old save without prepared_product_slots initializes empty without a version bump")

	session.call("_append_prepared_product", &"slot.04", plain_a)
	session.call("_append_prepared_product", &"slot.05", _product(&"oil.day_end", &"product.youtiao.oil_cake", 70.0, &"B", 3))
	var bill := Dictionary(session.call("end_business_day"))
	var waste := Array(bill.get("prepared_product_slot_waste", []))
	_check(waste.size() == 2 and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 0 and int(Dictionary(session.call("prepared_product_slot_status", &"slot.05")).get("count", -1)) == 0, "day end clears all fried-product slots and exposes waste details")
	_finish()


static func _product(instance_id: StringName, product_id: StringName, quality: float, grade: StringName, cost: int) -> Dictionary:
	return {
		"product_instance_id": instance_id,
		"area_id": &"area.youtiao",
		"product_id": product_id,
		"quality": quality,
		"grade": grade,
		"temperature_mode": &"room_temperature",
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"material_cost": cost,
		"status": &"available",
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PREPARED_PRODUCT_SLOTS_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PREPARED_PRODUCT_SLOTS_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
