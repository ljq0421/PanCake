extends SceneTree

var _failures: Array[String] = []
var _production_change_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	_check(Array(session.call("active_formal_orders")).is_empty(), "youtiao production fixture starts with no customer orders")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.youtiao.sesame": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.youtiao.sesame": true})
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true})
	progression.set("unlocked_automation_ids", {&"automation.youtiao.auto_lift": true})
	_check(StringName(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("reason", &"")) == &"finished_tray_locked", "finished youtiao cannot leave the filter basket before the tray is unlocked")
	progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true})
	var initial_slot_status := Dictionary(session.call("prepared_product_slot_status", &"slot.04"))
	_check(int(initial_slot_status.get("capacity", 0)) == 8 and int(initial_slot_status.get("capacity_per_product", 0)) == 4, "plain and sesame serving trays each retain four prepared-product spaces")

	var fryer_inventory := Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 8
	session.call("save_inventory", fryer_inventory)
	_check(bool(session.call("youtiao_auto_lift_enabled")), "purchased auto-lift defaults to enabled")
	var disabled_auto := Dictionary(session.call("set_youtiao_auto_lift_enabled", false))
	var no_order_load := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1))
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	_check(bool(no_order_load.get("success", false)) and bool(disabled_auto.get("success", false)) and not bool(session.call("youtiao_auto_lift_enabled")) and StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"ready_safe", "youtiao loads and cooks without a customer order while preserving the manual lift window")
	var enabled_auto := Dictionary(session.call("set_youtiao_auto_lift_enabled", true))
	session.call("advance_f3_production", 0.001)
	_check(bool(enabled_auto.get("success", false)) and StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"draining", "re-enabled auto-lift immediately replaces only the lift action")
	session.call("advance_f3_production", 2.0)
	session.call("discard_product_source", {"source_kind": &"youtiao_batch", "product_id": &"product.youtiao.plain", "discardable": true})
	var loaded_two := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 2))
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("advance_f3_production", 2.0)
	var fryer_before_two_store := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_production_change_count = 0
	var production_change_callback := Callable(self, "_on_production_changed")
	session.production_changed.connect(production_change_callback)
	for _tick in 30:
		session.call("advance_f3_production", 1.0 / 60.0)
	session.production_changed.disconnect(production_change_callback)
	var fryer_after_static_ticks := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(
		_production_change_count == 0 and fryer_after_static_ticks == fryer_before_two_store,
		"ready-to-collect production ticks stay silent so native youtiao dragging does not rebuild unrelated UI"
	)
	var stored_two := Dictionary(session.call("store_ready_youtiao_batch", &"slot.04"))
	var fryer_after_two_store := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(
		bool(loaded_two.get("success", false))
		and int(loaded_two.get("loaded_quantity", 0)) == 2
		and Array(fryer_before_two_store.get("occupied_slot_indices", [])).hash() == [0, 1].hash()
		and bool(stored_two.get("success", false))
		and int(stored_two.get("stored_quantity", 0)) == 2
		and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", 0)) == 2
		and StringName(fryer_after_two_store.get("state", &"")) == &"idle",
		"two dough portions occupy two fryer slots and store exactly two products"
	)
	session.call("clear_prepared_product_slots")
	fryer_inventory = Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 4
	session.call("save_inventory", fryer_inventory)
	var loaded_single := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 2))
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var stored_single := Dictionary(session.call("store_ready_youtiao_slot", &"slot.04", 0))
	var fryer_after_single_store := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(
		bool(loaded_single.get("success", false))
		and bool(stored_single.get("success", false))
		and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", 0)) == 1
		and Array(fryer_after_single_store.get("occupied_slot_indices", [])).hash() == [1].hash(),
		"storing one finished fryer slot moves exactly one oil strip to the serving plate"
	)
	session.call("discard_product_source", {"source_kind": &"youtiao_batch", "product_id": &"product.youtiao.plain", "discardable": true})
	session.call("clear_prepared_product_slots")
	fryer_inventory = Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 2
	session.call("save_inventory", fryer_inventory)
	var loaded_for_sesame := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1))
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var sesame_result := Dictionary(session.call("store_ready_youtiao_slot", &"slot.04", 0, &"product.youtiao.sesame"))
	var sesame_products := Array(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("products", []))
	_check(
		bool(loaded_for_sesame.get("success", false))
		and bool(sesame_result.get("success", false))
		and sesame_products.size() == 1
		and StringName(Dictionary(sesame_products[0]).get("product_id", &"")) == &"product.youtiao.sesame",
		"a finished fryer slot can become a sesame youtiao in the prepared-product slot"
	)
	session.call("discard_product_source", {"source_kind": &"youtiao_batch", "product_id": &"product.youtiao.plain", "discardable": true})
	session.call("clear_prepared_product_slots")
	fryer_inventory = Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 4
	session.call("save_inventory", fryer_inventory)
	var loaded_batch := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 4))
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var stored_batch := Dictionary(session.call("store_ready_youtiao_batch", &"slot.04"))
	var fryer_after_store := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(bool(loaded_batch.get("success", false)) and bool(stored_batch.get("success", false)) and int(stored_batch.get("stored_quantity", 0)) == 4 and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", 0)) == 4 and StringName(fryer_after_store.get("state", &"")) == &"idle", "one batch action stores all four ready products")

	var plain_a := _product(&"plain.a", &"product.youtiao.plain", 88.0, &"A", 2)
	var plain_b := _product(&"plain.b", &"product.youtiao.plain", 72.0, &"B", 2)
	_check(StringName(Dictionary(session.call("prepared_product_slot_status", &"slot.05")).get("reason", &"")) == &"unknown_prepared_product_slot", "removed prepared slots are not retained")
	var first_take: Dictionary = session.call("take_prepared_product", &"slot.04")
	_check(bool(first_take.get("success", false)) and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 3, "prepared-product slot takes one product at a time")
	session.call("clear_prepared_product_slots")
	for index in 3:
		session.call("_append_prepared_product", &"slot.04", _product(StringName("plain.capacity.%d" % index), &"product.youtiao.plain", 80.0, &"A", 2))
	session.call("_append_prepared_product", &"slot.04", _product(&"sesame.capacity.0", &"product.youtiao.sesame", 80.0, &"A", 2))
	fryer_inventory = Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 1
	session.call("save_inventory", fryer_inventory)
	session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1)
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var mixed_tray_store := Dictionary(session.call("store_ready_youtiao_slot", &"slot.04", 0))
	var mixed_tray_products := Array(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("products", []))
	_check(
		bool(mixed_tray_store.get("success", false))
		and mixed_tray_products.size() == 5
		and mixed_tray_products.filter(func(product: Dictionary) -> bool: return StringName(product.get("product_id", &"")) == &"product.youtiao.plain").size() == 4
		and mixed_tray_products.filter(func(product: Dictionary) -> bool: return StringName(product.get("product_id", &"")) == &"product.youtiao.sesame").size() == 1,
		"three plain and one sesame product still leave room for the fryer stick on the plain serving tray",
	)
	var plain_overflow: Dictionary = session.call("_append_prepared_product", &"slot.04", plain_a)
	for index in range(1, 3):
		session.call("_append_prepared_product", &"slot.04", _product(StringName("sesame.capacity.%d" % index), &"product.youtiao.sesame", 80.0, &"A", 2))
	fryer_inventory = Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 1
	session.call("save_inventory", fryer_inventory)
	session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1)
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var sesame_tray_store := Dictionary(session.call("store_ready_youtiao_slot", &"slot.04", 0, &"product.youtiao.sesame"))
	var sesame_overflow: Dictionary = session.call("_append_prepared_product", &"slot.04", _product(&"sesame.capacity.4", &"product.youtiao.sesame", 80.0, &"A", 2))
	var full_mixed_status := Dictionary(session.call("prepared_product_slot_status", &"slot.04"))
	_check(
		StringName(plain_overflow.get("reason", &"")) == &"prepared_product_slot_full"
		and bool(sesame_tray_store.get("success", false))
		and StringName(sesame_overflow.get("reason", &"")) == &"prepared_product_slot_full"
		and int(full_mixed_status.get("count", -1)) == 8,
		"a full plain tray does not block the fourth sesame product, while each tray remains independently bounded at four",
	)

	session.call("clear_prepared_product_slots")
	session.call("_append_prepared_product", &"slot.04", plain_a)
	fryer_inventory = Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 4
	session.call("save_inventory", fryer_inventory)
	session.call("load_f3_youtiao", &"recipe.youtiao.plain", 4)
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var blocked := Dictionary(session.call("store_ready_youtiao_batch", &"slot.04"))
	var blocked_machine := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(blocked.get("reason") == &"prepared_product_slot_full" and int(blocked.get("missing_capacity", 0)) == 1 and int(blocked_machine.get("quantity", 0)) == 4 and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", 0)) == 1, "insufficient prepared space rejects the whole batch without partial movement")
	session.call("discard_product_source", {"source_kind": &"youtiao_batch", "product_id": &"product.youtiao.plain", "discardable": true})

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

	fryer_inventory = Dictionary(session.call("inventory_snapshot"))
	fryer_inventory["stock.youtiao.plain_dough"] = 2
	session.call("save_inventory", fryer_inventory)
	var loaded_for_direct_delivery := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 2))
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var direct_order := Dictionary(session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1}]))
	var direct_order_id := StringName(Dictionary(direct_order.get("order", {})).get("order_id", &""))
	var direct_source := {"source_kind": &"youtiao_fryer_slot", "source_index": 1, "product_id": &"product.youtiao.plain"}
	var direct_preview := Dictionary(session.call("preview_stage_product_to_order", direct_source, direct_order_id, 0))
	var direct_stage := Dictionary(session.call("stage_product_to_order", direct_source, direct_order_id, 0))
	var fryer_after_direct_delivery := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(
		bool(loaded_for_direct_delivery.get("success", false))
		and bool(direct_preview.get("success", false))
		and bool(direct_preview.get("will_match", false))
		and bool(direct_stage.get("success", false))
		and Array(fryer_after_direct_delivery.get("occupied_slot_indices", [])).hash() == [0].hash(),
		"a completed fryer slot previews and stages directly to an order while preserving the other basket slot",
	)
	session.call("discard_product_source", {"source_kind": &"youtiao_batch", "product_id": &"product.youtiao.plain", "discardable": true})

	var save_data := Dictionary(session.get("_save_data")).duplicate(true)
	save_data.erase("prepared_product_slots")
	session.set("_save_data", save_data)
	session.call("_ensure_save_shape")
	var fresh_slots := Dictionary(session.call("prepared_product_slots_snapshot"))
	_check(Array(fresh_slots.get("slot.04", [])).is_empty() and not fresh_slots.has("slot.05") and not fresh_slots.has("slot.06"), "new save shape contains only the oil-strip prepared slot")

	session.call("_append_prepared_product", &"slot.04", plain_a)
	var bill := Dictionary(session.call("end_business_day"))
	var waste := Array(bill.get("prepared_product_slot_waste", []))
	_check(waste.size() == 1 and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 0, "day end clears the oil-strip prepared slot and exposes waste details")
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


func _on_production_changed(_snapshot: Dictionary) -> void:
	_production_change_count += 1


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
