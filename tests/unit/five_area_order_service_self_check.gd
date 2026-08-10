extends SceneTree
const ORDERS = preload("res://scripts/services/five_area_order_service.gd")
var _failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var service: RefCounted = ORDERS.new()
	var template := {"id": &"order.pancake.classic", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"]}
	var opened: Dictionary = service.call("open_pancake_order", template)
	var order_id: StringName = Dictionary(opened.get("order", {})).get("order_id", &"")
	var product := {"product_instance_id": &"product.1", "product_id": &"product.pancake.custom", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"]}
	_check(bool(service.call("preview_attach_product", order_id, 0, product).get("will_match", false)), "formal order previews matching tray product")
	_check(bool(service.call("attach_product", order_id, 0, product).get("success", false)), "formal order reserves matched product")
	var settled: Dictionary = service.call("settle_order", order_id)
	var repeated_settlement: Dictionary = service.call("settle_order", order_id)
	_check(bool(settled.get("order_success", false)) and bool(repeated_settlement.get("success", false)) and bool(repeated_settlement.get("already_settled", false)), "formal order settles once and safely accepts a retry")
	var multi: Dictionary = service.call("open_order", [
		{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [], "heat_preference": &"golden"},
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 1},
	])
	var multi_id: StringName = Dictionary(multi.get("order", {})).get("order_id", &"")
	var pancake_product := {"product_instance_id": &"product.2", "product_id": &"product.pancake.custom", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": []}
	var drink_product := {"product_instance_id": &"product.3", "product_id": &"product.packaged_drink.milk"}
	_check(int(service.call("best_delivery_item_index", multi_id, drink_product)) == 1, "delivery prefers the matching unfinished item instead of binding production in advance")
	var partial_attach: Dictionary = service.call("attach_product", multi_id, 0, pancake_product)
	var partial_settle: Dictionary = service.call("settle_order", multi_id)
	_check(bool(partial_attach.get("success", false)) and not bool(partial_settle.get("success", true)) and partial_settle.get("reason", &"") == &"missing_order_item", "multi-item order preserves a valid partial delivery without settling early")
	_check(bool(service.call("attach_product", multi_id, 1, drink_product).get("success", false)), "formal order routes the later product to its remaining multi-item entry")
	var sauce_contract: RefCounted = ORDERS.new()
	var double_sauce: Dictionary = sauce_contract.call("open_pancake_order", {"id": &"order.pancake.double_sauce", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili"]})
	_check(bool(double_sauce.get("success", false)), "formal pancake order accepts the confirmed two-sauce maximum")
	var over_sauce_contract: RefCounted = ORDERS.new()
	var over_sauced: Dictionary = over_sauce_contract.call("open_order", [{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "sauce_ids": [&"sauce.one", &"sauce.two", &"sauce.three"]}])
	_check(not bool(over_sauced.get("success", true)) and over_sauced.get("reason", &"") == &"too_many_sauce_requirements", "formal order rejects a third sauce requirement")
	var restored: RefCounted = ORDERS.new(service.call("snapshot"))
	_check(Dictionary(restored.call("active_order")).get("order_id", &"") == multi_id and bool(restored.call("settle_order", multi_id).get("order_success", false)), "active multi-item formal order survives snapshot restore")
	var wrong: RefCounted = ORDERS.new()
	var wrong_open: Dictionary = wrong.call("open_pancake_order", template)
	var wrong_id: StringName = Dictionary(wrong_open.get("order", {})).get("order_id", &"")
	var wrong_product := product.duplicate(true)
	wrong_product["ingredient_ids"] = []
	_check(bool(wrong.call("attach_product", wrong_id, 0, wrong_product).get("success", false)) and not bool(wrong.call("settle_order", wrong_id).get("order_success", true)), "wrong manually produced product settles as an order mismatch instead of blocking the day")
	var patience: RefCounted = ORDERS.new()
	patience.call("open_order", [{"area_id": &"area.pancake", "product_id": &"product.pancake.custom"}], {"patience_seconds": 10.0})
	patience.call("open_order", [{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk"}], {"patience_seconds": 24.0})
	patience.call("open_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain"}], {"patience_seconds": 30.0})
	patience.call("open_order", [{"area_id": &"area.steamer", "product_id": &"product.steamer.bun"}], {"patience_seconds": 40.0})
	patience.call("advance_patience", 2.0)
	var active_patience: Array = Array(patience.call("active_orders"))
	_check(active_patience.size() == 3 and Array(patience.call("waiting_orders")).size() == 1, "formal queue exposes three active customers and one hidden candidate")
	_check(is_equal_approx(float(Dictionary(active_patience[0]).get("remaining_patience_seconds", 0.0)), 8.0) and is_equal_approx(float(Dictionary(active_patience[1]).get("remaining_patience_seconds", 0.0)), 22.0) and is_equal_approx(float(Dictionary(active_patience[2]).get("remaining_patience_seconds", 0.0)), 28.0), "all three active customer patience timers advance together")
	_check(is_equal_approx(float(Dictionary(Array(patience.call("waiting_orders"))[0]).get("remaining_patience_seconds", 0.0)), 40.0), "hidden candidate remains frozen until activation")
	var serving_id := StringName(Dictionary(active_patience[1]).get("order_id", &""))
	patience.call("begin_serving", serving_id)
	patience.call("advance_patience", 3.0)
	var after_serving: Array = Array(patience.call("active_orders"))
	_check(is_equal_approx(float(Dictionary(after_serving[0]).get("remaining_patience_seconds", 0.0)), 5.0) and is_equal_approx(float(Dictionary(after_serving[1]).get("remaining_patience_seconds", 0.0)), 22.0) and is_equal_approx(float(Dictionary(after_serving[2]).get("remaining_patience_seconds", 0.0)), 25.0), "serving freezes only the accepting customer")
	var expiry: Dictionary = patience.call("advance_patience", 6.0)
	_check(Array(expiry.get("expired_results", [])).size() == 1 and Array(patience.call("active_orders")).size() == 3 and Array(patience.call("waiting_orders")).is_empty(), "one expired customer is replaced in the same service capacity without interrupting the others")
	var patience_restored: RefCounted = ORDERS.new(patience.call("snapshot"))
	_check(Array(patience_restored.call("active_orders")).size() == 3 and Array(patience_restored.call("active_orders")).all(func(order): return int(Dictionary(order).get("service_slot", -1)) >= 0 and not StringName(Dictionary(order).get("customer_id", &"")).is_empty()), "three service slots, customer identities, and serving state survive snapshot restore")
	var tutorial: RefCounted = ORDERS.new()
	var tutorial_opened: Dictionary = tutorial.call("open_order", [{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk"}], {"teaching_area_id": &"area.packaged_drink", "patience_seconds": 24.0})
	for index in 3:
		tutorial.call("open_order", [{"area_id": &"area.pancake", "product_id": &"product.pancake.custom"}], {"patience_seconds": 30.0 + index})
	tutorial.call("advance_patience", 20.0)
	var tutorial_order: Dictionary = Dictionary(tutorial.call("active_order"))
	_check(bool(Dictionary(tutorial_opened.get("order", {})).get("tutorial_no_countdown", false)) and is_equal_approx(float(tutorial_order.get("remaining_patience_seconds", 0.0)), 24.0) and Array(tutorial.call("active_orders")).size() == 1 and Array(tutorial.call("waiting_orders")).size() == 3, "teaching order is unlimited and exclusively occupies the store")
	var legacy_snapshot: Dictionary = Dictionary(tutorial.call("snapshot"))
	var legacy_order_id: String = str(tutorial_order.get("order_id", &""))
	var legacy_orders: Dictionary = Dictionary(legacy_snapshot.get("orders", {}))
	var legacy_order: Dictionary = Dictionary(legacy_orders.get(legacy_order_id, {}))
	legacy_order.erase("tutorial_no_countdown")
	legacy_order["remaining_patience_seconds"] = 3.0
	legacy_orders[legacy_order_id] = legacy_order
	legacy_snapshot["orders"] = legacy_orders
	var normalized_legacy: RefCounted = ORDERS.new(legacy_snapshot)
	var normalized_order: Dictionary = Dictionary(normalized_legacy.call("active_order"))
	_check(bool(normalized_order.get("tutorial_no_countdown", false)) and is_equal_approx(float(normalized_order.get("remaining_patience_seconds", 0.0)), 24.0), "old teaching snapshot gains the unlimited flag without a save-version migration")
	var legacy_normal: RefCounted = ORDERS.new()
	for index in 4:
		legacy_normal.call("open_order", [{"area_id": &"area.pancake", "product_id": &"product.pancake.custom"}], {"patience_seconds": 20.0 + index})
	var version_three := Dictionary(legacy_normal.call("snapshot"))
	var legacy_active_ids := Array(version_three.get("active_order_ids", []))
	version_three["version"] = 3
	version_three["active_order_id"] = str(legacy_active_ids[0])
	version_three.erase("active_order_ids")
	var migrated: RefCounted = ORDERS.new(version_three)
	_check(Array(migrated.call("active_orders")).size() == 3 and Array(migrated.call("waiting_orders")).size() == 1, "version-three single-active snapshot migrates in queue order to three active slots plus one candidate")
	var rotation_ids := PackedStringArray()
	for sequence in range(1, 12):
		rotation_ids.append(str(ORDERS.customer_id_for_sequence(sequence)))
	_check(rotation_ids.slice(0, 10) == PackedStringArray(["customer_01", "customer_02", "customer_03", "customer_04", "customer_05", "customer_06", "customer_07", "customer_08", "customer_09", "customer_10"]) and rotation_ids[10] == "customer_01", "customer identity rotates deterministically across all ten portraits")
	var refill: RefCounted = ORDERS.new()
	var refill_orders: Array[Dictionary] = []
	for index in 4:
		var refill_opened: Dictionary = refill.call("open_order", [{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1}])
		refill_orders.append(Dictionary(refill_opened.get("order", {})))
	var first_refill_id := StringName(refill_orders[0].get("order_id", &""))
	refill.call("attach_product", first_refill_id, 0, {"product_instance_id": &"rotation.product.1", "product_id": &"product.pancake.custom"})
	refill.call("settle_order", first_refill_id)
	var refilled_customer := {}
	for active_variant in Array(refill.call("active_orders")):
		var active_candidate := Dictionary(active_variant)
		if int(active_candidate.get("service_slot", -1)) == 0:
			refilled_customer = active_candidate
			break
	_check(StringName(refilled_customer.get("customer_id", &"")) == &"customer_04", "a customer filling service slot zero keeps its own identity instead of becoming customer one")
	var version_four: Dictionary = Dictionary(refill.call("snapshot"))
	_check(int(version_four.get("version", 0)) == 6, "formal order snapshots now write version six for multi-product tray slots")
	version_four["version"] = 4
	var version_four_orders: Dictionary = Dictionary(version_four.get("orders", {}))
	for raw_order_id in version_four_orders:
		var old_order := Dictionary(version_four_orders[raw_order_id])
		old_order["customer_id"] = &"customer_01"
		version_four_orders[raw_order_id] = old_order
	version_four["orders"] = version_four_orders
	var migrated_v5: RefCounted = ORDERS.new(version_four)
	var migrated_identity_ok := true
	for refill_order in refill_orders:
		var refill_id := StringName(refill_order.get("order_id", &""))
		var migrated_order: Dictionary = migrated_v5.call("order_by_id", refill_id)
		migrated_identity_ok = migrated_identity_ok and StringName(migrated_order.get("customer_id", &"")) == ORDERS.customer_id_for_sequence(int(migrated_order.get("sequence", 1)))
	_check(migrated_identity_ok, "version-four snapshots migrate customer identity from the stable order sequence")
	var preserved_snapshot: Dictionary = Dictionary(refill.call("snapshot"))
	var preserved_orders: Dictionary = Dictionary(preserved_snapshot.get("orders", {}))
	var preserved_order_id := str(refill_orders[1].get("order_id", &""))
	var preserved_order := Dictionary(preserved_orders[preserved_order_id])
	preserved_order["customer_id"] = &"customer_10"
	preserved_orders[preserved_order_id] = preserved_order
	preserved_snapshot["orders"] = preserved_orders
	var preserved_restore: RefCounted = ORDERS.new(preserved_snapshot)
	_check(StringName(Dictionary(preserved_restore.call("order_by_id", StringName(preserved_order_id))).get("customer_id", &"")) == &"customer_10", "version-six restore preserves the customer identity stored on the order")
	var stacked: RefCounted = ORDERS.new()
	var stacked_open: Dictionary = stacked.call("open_order", [{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 2, "temperature_mode": &"room_temperature"}])
	var stacked_id := StringName(Dictionary(stacked_open.get("order", {})).get("order_id", &""))
	var stacked_product_a := {"product_instance_id": &"stacked.a", "area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "temperature_mode": &"room_temperature", "return_policy": &"return_stock"}
	var stacked_product_b := stacked_product_a.duplicate(true)
	stacked_product_b["product_instance_id"] = &"stacked.b"
	_check(bool(stacked.call("attach_product", stacked_id, 0, stacked_product_a).get("success", false)) and bool(stacked.call("attach_product", stacked_id, 0, stacked_product_b).get("success", false)), "one tray slot stacks the requested quantity as separate product instances")
	_check(StringName(stacked.call("attach_product", stacked_id, 0, stacked_product_b).get("reason", &"")) == &"capacity_full", "a full tray slot rejects a structural overfill without changing attached products")
	var removed: Dictionary = stacked.call("remove_attached_product", stacked_id, 0)
	var after_remove: Dictionary = stacked.call("order_by_id", stacked_id)
	_check(StringName(Dictionary(removed.get("product", {})).get("product_instance_id", &"")) == &"stacked.b" and Array(Dictionary(Array(after_remove.get("items", []))[0]).get("attached_products", [])).size() == 1, "pre-handoff removal takes back exactly one stacked product")
	var legacy_tray_snapshot: Dictionary = stacked.call("snapshot")
	var legacy_tray_orders := Dictionary(legacy_tray_snapshot.get("orders", {}))
	var legacy_tray_order := Dictionary(legacy_tray_orders[str(stacked_id)])
	var legacy_tray_items := Array(legacy_tray_order.get("items", [])).duplicate(true)
	var legacy_tray_item := Dictionary(legacy_tray_items[0])
	var legacy_product := Dictionary(legacy_tray_item.get("attached_product", {}))
	legacy_product.erase("reservation_origin")
	legacy_product.erase("return_policy")
	legacy_tray_item.erase("attached_products")
	legacy_tray_item["attached_product"] = legacy_product
	legacy_tray_items[0] = legacy_tray_item
	legacy_tray_order["items"] = legacy_tray_items
	legacy_tray_orders[str(stacked_id)] = legacy_tray_order
	legacy_tray_snapshot["orders"] = legacy_tray_orders
	var restored_legacy_tray: RefCounted = ORDERS.new(legacy_tray_snapshot)
	var restored_legacy_item := Dictionary(Array(Dictionary(restored_legacy_tray.call("order_by_id", stacked_id)).get("items", []))[0])
	var restored_legacy_product := Dictionary(Array(restored_legacy_item.get("attached_products", []))[0])
	_check(StringName(restored_legacy_product.get("return_policy", &"")) == &"waste_only" and StringName(Dictionary(restored_legacy_product.get("reservation_origin", {})).get("source_kind", &"")) == &"legacy", "historic staged products restore safely as waste-only without clearing the save")
	_finish()
func _check(condition: bool, message: String) -> void:
	if condition: print("PASS: %s" % message)
	else: _failures.append(message)
func _finish() -> void:
	if _failures.is_empty(): print("FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS"); quit(0); return
	printerr("FIVE_AREA_ORDER_SERVICE_SELF_CHECK_FAIL\n" + "\n".join(_failures)); quit(1)
