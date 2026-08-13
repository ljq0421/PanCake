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
	var fryer_inventory := Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 2
	session.call("save_inventory", fryer_inventory)
	var loaded_batch := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 2))
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 12.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var discarded_output := Dictionary(session.call("discard_product_source", {"source_kind": &"youtiao_output", "source_index": -1, "product_id": &"product.youtiao.plain", "discardable": true}))
	var fryer_after_discard := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(bool(loaded_batch.get("success", false)) and bool(discarded_output.get("success", false)) and int(discarded_output.get("remaining_quantity", -1)) == 1 and int(fryer_after_discard.get("quantity", 0)) == 1 and StringName(fryer_after_discard.get("state", &"")) == &"ready_to_collect" and int(Dictionary(discarded_output.get("waste", {})).get("quantity", 0)) == 1, "drag-discarding the fryer output removes and records exactly one ready product")

	var plain_a := _product(&"plain.a", &"product.youtiao.plain", 88.0, &"A", 2)
	var plain_b := _product(&"plain.b", &"product.youtiao.plain", 72.0, &"B", 2)
	_check(bool(session.call("_append_prepared_product", &"slot.04", plain_a).get("success", false)) and bool(session.call("_append_prepared_product", &"slot.04", plain_b).get("success", false)), "legacy Slot04 save data accepts plain-youtiao product instances")
	_check(session.call("_append_prepared_product", &"slot.05", plain_a).get("reason") == &"prepared_product_slot_mismatch" and int(Dictionary(session.call("prepared_product_slot_status", &"slot.05")).get("count", -1)) == 0, "legacy compatibility normalization rejects a mismatched product")
	var first_take: Dictionary = session.call("take_prepared_product", &"slot.04")
	_check(StringName(Dictionary(first_take.get("product", {})).get("product_instance_id", &"")) == &"plain.a" and is_equal_approx(float(Dictionary(first_take.get("product", {})).get("quality", 0.0)), 88.0), "prepared-product slot takes FIFO and preserves product quality")
	session.call("clear_prepared_product_slots")
	for index in 6:
		session.call("_append_prepared_product", &"slot.04", _product(StringName("capacity.%d" % index), &"product.youtiao.plain", 80.0, &"A", 2))
	var overflow: Dictionary = session.call("_append_prepared_product", &"slot.04", plain_a)
	_check(overflow.get("reason") == &"prepared_product_slot_full" and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 6, "legacy prepared-product capacity remains bounded during migration")
	session.call("clear_prepared_product_slots")
	var stored_product := plain_a.duplicate(true)
	session.call("_append_prepared_product", &"slot.04", stored_product)
	session.call("_append_prepared_product", &"slot.04", plain_b)
	var discarded_one := Dictionary(session.call("discard_prepared_product", &"slot.04"))
	_check(bool(discarded_one.get("success", false)) and int(discarded_one.get("count", -1)) == 1 and int(Dictionary(discarded_one.get("waste", {})).get("attributed_cost", 0)) == 2, "drag-discarding a prepared fryer slot removes one FIFO product and records its actual material cost")
	stored_product = plain_b.duplicate(true)

	var opened := Dictionary(session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1}]))
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	var staged := Dictionary(session.call("stage_product_to_order", {"source_kind": &"prepared_product_slot", "source_slot_id": &"slot.04", "source_index": -1, "product_id": &"product.youtiao.plain"}, order_id, 0))
	_check(bool(staged.get("success", false)) and StringName(Dictionary(staged.get("product", {})).get("product_instance_id", &"")) == StringName(stored_product.get("product_instance_id", &"")) and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 0, "formal order can consume an invisible legacy prepared-slot source")

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
