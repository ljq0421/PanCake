extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for three-customer delivery")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	_unlock_milk(session)
	var item := {
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.milk",
		"quantity": 1,
		"temperature_mode": &"room_temperature",
	}
	for index in 6:
		var opened := Dictionary(session.call("open_formal_order", [item.duplicate(true)], {
			"source": &"three_customer_delivery_test",
			"patience_seconds": 60.0 + index,
			"base_coins": 3,
		}))
		_check(bool(opened.get("success", false)), "normal customer %d enters the six-order queue" % (index + 1))
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.packaged_drink.milk"] = 6
	session.call("save_inventory", inventory)

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	var initial_active: Array = Array(session.call("active_formal_orders"))
	var initial_waiting: Array = Array(session.call("waiting_formal_orders"))
	_check(initial_active.size() == 3 and initial_waiting.size() == 3, "normal business displays three customers with three waiting candidates")
	_check(_service_slot_scene_contract(workstation), "all service slots keep the v4 order card above a contained background-level portrait")
	var tutorial_layout_order := {
		"order_id": &"tutorial.layout",
		"service_slot": 0,
		"customer_id": &"customer_01",
		"tutorial_no_countdown": true,
		"patience_seconds": 60.0,
		"remaining_patience_seconds": 60.0,
		"base_coins": 3,
		"items": [item.duplicate(true)],
	}
	# Reproduce the first tutorial render, before any service-slot cache exists.
	workstation.set("_customer_service_slot_signatures", {})
	workstation.call("_refresh_customer_service_slots", [tutorial_layout_order])
	var tutorial_left := workstation.get_node("SafeArea/ServiceCustomer1") as Control
	var tutorial_center := workstation.get_node("SafeArea/ServiceCustomer2") as Control
	var tutorial_right := workstation.get_node("SafeArea/ServiceCustomer3") as Control
	var tutorial_item_button := tutorial_center.get_node("OrderPanel/ItemButton1") as Button
	_check(
		int(tutorial_layout_order.get("service_slot", -1)) == 0
		and not tutorial_left.visible
		and tutorial_center.visible
		and not tutorial_right.visible
		and StringName(tutorial_center.get("_order_id")) == &"tutorial.layout"
		and tutorial_item_button.visible
		and not tutorial_item_button.disabled,
		"the exclusive tutorial keeps semantic slot zero but renders as a clickable center customer",
	)
	workstation.call("_refresh_customer_service_slots", initial_active)
	var original_ids_by_slot: Dictionary = {}
	for order_value in initial_active:
		var order := Dictionary(order_value)
		original_ids_by_slot[int(order.get("service_slot", -1))] = StringName(order.get("order_id", &""))
	for slot_index in 3:
		var service_slot := workstation.get_node("SafeArea/ServiceCustomer%d" % (slot_index + 1)) as Control
		var card_button := service_slot.get_node("OrderPanel/CardFocusButton") as Button
		var item_button := service_slot.get_node("OrderPanel/ItemButton1") as Button
		_check(service_slot.visible and service_slot.get_node_or_null("PortraitButton") == null and not card_button.disabled and item_button.visible and not item_button.disabled, "order card and item in service slot %d are independently clickable without a portrait target" % (slot_index + 1))
	var waiting_strip := workstation.get_node("SafeArea/CustomerStrip") as Control
	_check(not waiting_strip.visible, "waiting customers are not shown in the shop UI")

	var first_target_id := StringName(original_ids_by_slot.get(2, &""))
	workstation.call("_on_customer_service_focus_requested", StringName(original_ids_by_slot.get(0, &"")))
	_check(StringName(workstation.get("_formal_order_id")) == StringName(original_ids_by_slot.get(0, &"")), "clicking a service customer or its card focuses that exact order_id")
	workstation.call("_on_customer_service_delivery_requested", first_target_id, 0)
	_check(StringName(Dictionary(session.call("formal_order", first_target_id)).get("state", &"")) == &"settled", "the third card's item carries its own order_id and delivers correctly even while another customer was focused")
	var after_first: Array = Array(session.call("active_formal_orders"))
	_check(after_first.size() == 3 and Array(session.call("waiting_formal_orders")).size() == 3, "completing one order refills only the empty customer slot and restores three waiting candidates")
	_check(_active_contains(after_first, StringName(original_ids_by_slot.get(0, &""))) and _active_contains(after_first, StringName(original_ids_by_slot.get(1, &""))), "refilling the third slot preserves the other two original customers")

	for slot_index in [0, 1]:
		var target_id := StringName(original_ids_by_slot.get(slot_index, &""))
		workstation.call("_on_customer_slot_pressed", slot_index)
		_check(StringName(workstation.get("_formal_order_id")) == target_id, "customer slot %d keeps its own order_id after another slot refills" % (slot_index + 1))
		workstation.call("_on_order_dish_pressed", 0)
		_check(StringName(Dictionary(session.call("formal_order", target_id)).get("state", &"")) == &"settled", "customer slot %d can still receive its own finished drink" % (slot_index + 1))

	var settled_originals := 0
	for target_id_value in original_ids_by_slot.values():
		if StringName(Dictionary(session.call("formal_order", StringName(target_id_value))).get("state", &"")) == &"settled":
			settled_originals += 1
	_check(settled_originals == 3, "all three initially visible customer orders settle independently")
	workstation.queue_free()
	_finish()


func _unlock_milk(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	var areas := Dictionary(progression.get("unlocked_area_ids"))
	areas[&"area.packaged_drink"] = true
	progression.set("unlocked_area_ids", areas)
	var products := Dictionary(progression.get("unlocked_product_ids"))
	products[&"product.packaged_drink.milk"] = true
	progression.set("unlocked_product_ids", products)
	var stocks := Dictionary(progression.get("unlocked_stock_ids"))
	stocks[&"stock.packaged_drink.milk"] = true
	progression.set("unlocked_stock_ids", stocks)
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.packaged_drink": true})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"")
	progression.set("tutorial_active_id", &"")
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")


func _active_contains(orders: Array, expected_id: StringName) -> bool:
	for order_value in orders:
		if StringName(Dictionary(order_value).get("order_id", &"")) == expected_id:
			return true
	return false


func _service_slot_scene_contract(workstation: Node) -> bool:
	for slot_index in 3:
		var service_slot := workstation.get_node("SafeArea/ServiceCustomer%d" % (slot_index + 1)) as Control
		var portrait := service_slot.get_node("Portrait") as TextureRect
		var order_panel := service_slot.get_node("OrderPanel") as Control
		var card_focus_button := order_panel.get_node("CardFocusButton") as Button
		var card_background := order_panel.get_node("CardBackground") as TextureRect
		var first_item := order_panel.get_node("ItemButton1") as Button
		var last_dynamic_requirement := order_panel.get_node("IngredientSlot3_8") as Control
		if not _rect_matches(service_slot, Rect2(service_slot.position.x, 150.0, 540.0, 490.0)):
			return false
		var slot_rect := Rect2(Vector2.ZERO, service_slot.size)
		if not slot_rect.encloses(Rect2(portrait.position, portrait.size)):
			return false
		if not slot_rect.encloses(Rect2(order_panel.position, order_panel.size)):
			return false
		if service_slot.mouse_filter != Control.MOUSE_FILTER_IGNORE or portrait.z_index >= order_panel.z_index or service_slot.has_node("PortraitButton"):
			return false
		if card_focus_button.mouse_filter != Control.MOUSE_FILTER_STOP:
			return false
		if not card_background.has_method("set_card_layout") or card_background.size.x != 264.0:
			return false
		if not _rect_matches(first_item, Rect2(18.0, 64.5, 63.0, 63.0)):
			return false
		if order_panel.has_node("Requirement8") or last_dynamic_requirement == null:
			return false
	return true


func _rect_matches(control: Control, expected: Rect2) -> bool:
	return control.position.distance_to(expected.position) <= 0.05 and control.size.distance_to(expected.size) <= 0.05


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("THREE_CUSTOMER_DELIVERY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_CUSTOMER_DELIVERY_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
