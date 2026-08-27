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
	session.call("set_business_paused", true)
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
