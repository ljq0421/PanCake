extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()
var _product_sequence := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for customer-card click delivery")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	_complete_initial_pancake_tutorial(session)
	_clear_orders(session)
	var item := {
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"heat_preference": &"golden",
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
	}
	var first_opened := Dictionary(session.call("open_formal_order", [item.duplicate(true)], {"source": &"click_delivery_first", "patience_seconds": 120.0}))
	var different_item := item.duplicate(true)
	different_item["heat_preference"] = &"well_done"
	different_item["ingredient_ids"] = PackedStringArray(["stock.pancake.egg"])
	var second_opened := Dictionary(session.call("open_formal_order", [different_item], {"source": &"click_delivery_second", "patience_seconds": 120.0}))
	var first_order := Dictionary(first_opened.get("order", {}))
	var second_order := Dictionary(second_opened.get("order", {}))
	var first_order_id := StringName(first_order.get("order_id", &""))
	var second_order_id := StringName(second_order.get("order_id", &""))
	_check(not first_order_id.is_empty() and not second_order_id.is_empty(), "two independent pancake orders open")

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	workstation.call("_on_customer_service_focus_requested", first_order_id)
	_check(StringName(workstation.get("_formal_order_id")) == first_order_id, "the first customer is focused before clicking another card")

	_prepare_ready_pancake(workstation, item)
	_check(workstation.multi_griddle_station.griddle_count() == 1 and workstation.multi_griddle_station.units.size() == 1, "click delivery operates from the permanent single griddle")
	var second_slot := _service_slot_for_order(workstation, second_order_id)
	var second_button := second_slot.get_node("OrderPanel/ItemButton1") as Button if second_slot != null else null
	_check(second_button != null and second_button.visible and not second_button.disabled, "the non-focused customer's real item button is clickable")
	if second_button != null:
		second_button.pressed.emit()
	var second_after := Dictionary(session.call("formal_order", second_order_id))
	var first_after := Dictionary(session.call("formal_order", first_order_id))
	_check(StringName(second_after.get("state", &"")) == &"settled", "clicking the non-focused customer card settles that exact order_id")
	_check(StringName(first_after.get("state", &"")) in [&"active", &"serving"], "click delivery does not bind the product to the previously focused customer")
	_check(workstation.multi_griddle_station.ready_source_refs().is_empty(), "successful click delivery consumes the ready griddle product")

	var first_slot := _service_slot_for_order(workstation, first_order_id)
	var first_button := first_slot.get_node("OrderPanel/ItemButton1") as Button if first_slot != null else null
	if first_button != null:
		first_button.pressed.emit()
	_check(StringName(Dictionary(session.call("formal_order", first_order_id)).get("state", &"")) in [&"active", &"serving"], "clicking without an available product leaves the order unchanged")
	_prepare_ready_pancake(workstation, item)
	first_slot = _service_slot_for_order(workstation, first_order_id)
	first_button = first_slot.get_node("OrderPanel/ItemButton1") as Button if first_slot != null else null
	if first_button != null:
		first_button.pressed.emit()
	_check(StringName(Dictionary(session.call("formal_order", first_order_id)).get("state", &"")) == &"settled", "the remaining customer is delivered by one item-icon click without dragging")
	var settled_first := Dictionary(session.call("formal_order", first_order_id))
	var settled_second := Dictionary(session.call("formal_order", second_order_id))
	var first_product := Dictionary(Array(Dictionary(Array(settled_first.get("items", []))[0]).get("attached_products", []))[0])
	var second_product := Dictionary(Array(Dictionary(Array(settled_second.get("items", []))[0]).get("attached_products", []))[0])
	_check(float(first_product.get("score", 0.0)) > float(second_product.get("score", 100.0)), "identical unbound pancakes are scored against the customer that actually receives them")
	_check(StringName(first_product.get("grade", &"")) == &"A" and StringName(second_product.get("grade", &"")) != &"A", "delivery-time order differences flow into the final pancake grade")

	_clear_orders(session)
	_unlock_youtiao_finished_tray(session)
	session.call("clear_prepared_product_slots")
	session.call("_append_prepared_product", &"slot.04", _youtiao_product(&"test.mixed.sesame", &"product.youtiao.sesame"))
	session.call("_append_prepared_product", &"slot.04", _youtiao_product(&"test.mixed.plain_1", &"product.youtiao.plain"))
	session.call("_append_prepared_product", &"slot.04", _youtiao_product(&"test.mixed.plain_2", &"product.youtiao.plain"))
	var youtiao_opened := Dictionary(session.call("open_formal_order", [{
		"area_id": &"area.youtiao",
		"product_id": &"product.youtiao.plain",
		"quantity": 2,
	}], {"source": &"mixed_youtiao_click_delivery", "patience_seconds": 120.0}))
	var youtiao_order_id := StringName(Dictionary(youtiao_opened.get("order", {})).get("order_id", &""))
	await process_frame
	await process_frame
	var youtiao_slot := _service_slot_for_order(workstation, youtiao_order_id)
	var youtiao_button := youtiao_slot.get_node("OrderPanel/ItemButton1") as Button if youtiao_slot != null else null
	var youtiao_icon := youtiao_slot.get_node("OrderPanel/ItemButton1/ItemIcon1") as TextureRect if youtiao_slot != null else null
	_check(youtiao_button != null and not youtiao_button.disabled, "mixed-tray plain-youtiao order exposes an enabled customer-card button")
	_check(youtiao_button != null and youtiao_icon != null and youtiao_button.get_global_rect().encloses(youtiao_icon.get_global_rect()), "the first order-item drop target covers its visible icon")
	if youtiao_button != null:
		youtiao_button.pressed.emit()
	var youtiao_after_first := Dictionary(session.call("formal_order", youtiao_order_id))
	var tray_after_first := Array(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("products", []))
	_check(
		_attached_count(youtiao_after_first, 0) == 1
		and StringName(Dictionary(Array(Dictionary(Array(youtiao_after_first.get("items", []))[0]).get("attached_products", []))[0]).get("product_id", &"")) == &"product.youtiao.plain"
		and tray_after_first.size() == 2
		and StringName(Dictionary(tray_after_first[0]).get("product_id", &"")) == &"product.youtiao.sesame",
		"click delivery skips a leading sesame youtiao and consumes the first matching plain youtiao"
	)
	youtiao_slot = _service_slot_for_order(workstation, youtiao_order_id)
	youtiao_button = youtiao_slot.get_node("OrderPanel/ItemButton1") as Button if youtiao_slot != null else null
	if youtiao_button != null:
		youtiao_button.pressed.emit()
	var youtiao_after_second := Dictionary(session.call("formal_order", youtiao_order_id))
	var tray_after_second := Array(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("products", []))
	_check(
		StringName(youtiao_after_second.get("state", &"")) == &"settled"
		and _attached_count(youtiao_after_second, 0) == 2
		and tray_after_second.size() == 1
		and StringName(Dictionary(tray_after_second[0]).get("product_id", &"")) == &"product.youtiao.sesame",
		"two click deliveries fulfill a plain-youtiao x2 order without consuming the leading sesame youtiao"
	)

	_clear_orders(session)
	session.call("clear_prepared_product_slots")
	var youtiao_inventory := Dictionary(session.call("inventory_snapshot"))
	youtiao_inventory["stock.youtiao.plain_dough"] = 1
	session.call("save_inventory", youtiao_inventory)
	var direct_load := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1))
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var fryer_delivery_opened := Dictionary(session.call("open_formal_order", [{
		"area_id": &"area.youtiao",
		"product_id": &"product.youtiao.plain",
		"quantity": 1,
	}], {"source": &"fryer_youtiao_click_delivery", "patience_seconds": 120.0}))
	var fryer_delivery_order_id := StringName(Dictionary(fryer_delivery_opened.get("order", {})).get("order_id", &""))
	await process_frame
	await process_frame
	var fryer_delivery_slot := _service_slot_for_order(workstation, fryer_delivery_order_id)
	var fryer_delivery_button := fryer_delivery_slot.get_node("OrderPanel/ItemButton1") as Button if fryer_delivery_slot != null else null
	if fryer_delivery_button != null:
		fryer_delivery_button.pressed.emit()
	var fryer_after_click := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(
		bool(direct_load.get("success", false))
		and StringName(Dictionary(session.call("formal_order", fryer_delivery_order_id)).get("state", &"")) == &"settled"
		and StringName(fryer_after_click.get("state", &"")) == &"idle",
		"click delivery can take a completed youtiao directly from the fryer",
	)

	workstation.queue_free()
	_finish()


func _prepare_ready_pancake(workstation: Node, item: Dictionary) -> void:
	_product_sequence += 1
	var unit: Node = workstation.multi_griddle_station.units[0]
	unit.mark_ready({
		"product_instance_id": StringName("test.click_delivery.%d" % _product_sequence),
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"heat_preference": StringName(item.get("heat_preference", &"golden")),
		"ingredient_ids": PackedStringArray(Array(item.get("ingredient_ids", []))),
		"sauce_ids": PackedStringArray(Array(item.get("sauce_ids", []))),
		"score": 100.0,
		"feedback": "test ready pancake",
		"serving_score_basis": {
			"version": 2,
			"intrinsic_dimensions": {"integrity": 100.0, "thickness": 100.0, "egg": 100.0, "fold": 100.0},
			"heat_moments": {"mean_front": 0.64, "mean_back": 0.64, "mean_front_squared": 0.4096, "mean_back_squared": 0.4096},
			"sauce_results": {},
			"sauce_profiles": {},
			"ingredient_distribution_score": 100.0,
			"ingredient_distribution_tags": [],
			"applied_ingredient_ids": [],
			"applied_ingredient_quantities": {},
			"applied_sauce_ids": [],
			"repair_tags": [],
			"score_caps": {},
		},
		"status": &"available",
	})
	workstation.multi_griddle_station.call("_sync_snapshot_to_session")


func _service_slot_for_order(workstation: Node, order_id: StringName) -> Control:
	for slot_index in 3:
		var slot := workstation.get_node("SafeArea/ServiceCustomer%d" % (slot_index + 1)) as Control
		if slot.visible and StringName(slot.get("_order_id")) == order_id:
			return slot
	return null


func _clear_orders(session: Node) -> void:
	for order_value in Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders")):
		var order_id := StringName(Dictionary(order_value).get("order_id", &""))
		if not order_id.is_empty():
			session.call("abandon_formal_order", order_id, &"click_delivery_fixture")


func _complete_initial_pancake_tutorial(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"")
	progression.set("tutorial_active_id", &"")
	session.call("_sync_progression_to_save")


func _unlock_youtiao_finished_tray(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	var areas := Dictionary(progression.get("unlocked_area_ids"))
	areas[&"area.youtiao"] = true
	progression.set("unlocked_area_ids", areas)
	var recipes := Dictionary(progression.get("unlocked_recipe_ids"))
	recipes[&"recipe.youtiao.plain"] = true
	recipes[&"recipe.youtiao.sesame"] = true
	progression.set("unlocked_recipe_ids", recipes)
	var products := Dictionary(progression.get("unlocked_product_ids"))
	products[&"product.youtiao.plain"] = true
	products[&"product.youtiao.sesame"] = true
	progression.set("unlocked_product_ids", products)
	var stocks := Dictionary(progression.get("unlocked_stock_ids"))
	stocks[&"stock.youtiao.plain_dough"] = true
	progression.set("unlocked_stock_ids", stocks)
	var device_tiers := Dictionary(progression.get("device_tiers"))
	device_tiers[&"device.youtiao_fryer"] = 0
	progression.set("device_tiers", device_tiers)
	var growth := Dictionary(progression.get("owned_growth_ids"))
	growth[&"growth.capacity.youtiao_finished_tray"] = true
	progression.set("owned_growth_ids", growth)
	session.call("_sync_progression_to_save")


func _youtiao_product(instance_id: StringName, product_id: StringName) -> Dictionary:
	return {
		"product_instance_id": instance_id,
		"area_id": &"area.youtiao",
		"product_id": product_id,
		"quality": 100.0,
		"grade": &"A",
		"temperature_mode": &"room_temperature",
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"material_cost": 2,
		"status": &"available",
	}


func _attached_count(order: Dictionary, item_index: int) -> int:
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return 0
	return Array(Dictionary(items[item_index]).get("attached_products", [])).size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CUSTOMER_ORDER_CARD_CLICK_DELIVERY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_ORDER_CARD_CLICK_DELIVERY_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
