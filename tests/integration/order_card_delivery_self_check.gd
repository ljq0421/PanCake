extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for clickable order-card integration")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	_unlock_juice(session)
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.packaged_drink.juice"] = 0
	session.call("save_inventory", inventory)
	var item := {
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.juice",
		"quantity": 1,
		"temperature_mode": &"room_temperature",
	}
	var opened: Dictionary = session.call("open_formal_order", [item, item.duplicate(true)], {"source": &"click_order_card_test", "tutorial_no_countdown": true})
	var order := Dictionary(opened.get("order", {}))
	var order_id := StringName(order.get("order_id", &""))
	_check(bool(opened.get("success", false)) and not order_id.is_empty(), "test opens one two-item formal order")

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	workstation.call("_focus_formal_order", order, false)
	workstation.call("_refresh_customer_queue")
	await create_timer(1.2).timeout
	var service_slot := _service_slot_for_order(workstation, order_id)
	_check(service_slot != null, "the formal order is bound to a current multi-customer service slot")
	if service_slot == null:
		workstation.queue_free()
		_finish()
		return
	var first_target := service_slot.item_buttons[0] as Button
	var second_target := service_slot.item_buttons[1] as Button
	var empty_target := service_slot.item_buttons[2] as Button
	_check(not first_target.disabled and first_target.mouse_filter == Control.MOUSE_FILTER_STOP, "first incomplete order item is a real delivery target")
	_check(not second_target.disabled and second_target.mouse_filter == Control.MOUSE_FILTER_STOP, "second incomplete order item is a real delivery target")
	_check(not empty_target.visible and service_slot.delivery_target(order_id, 2) == null, "empty service-card item stays hidden and cannot become a delivery target")

	var inventory_before := Dictionary(session.call("inventory_snapshot"))
	workstation.call("_on_customer_service_delivery_requested", order_id, 0)
	var after_missing_click := Dictionary(session.call("formal_order", order_id))
	_check(_attached_count(after_missing_click, 0) == 0 and Dictionary(session.call("inventory_snapshot")) == inventory_before, "click with no available product does not mutate order or inventory")
	_check("长按果汁货位补货" in workstation.tool_status_label.text, "missing product click gives a concrete player-facing restock reason")

	inventory = Dictionary(session.call("inventory_snapshot"))
	inventory["stock.packaged_drink.juice"] = 2
	session.call("save_inventory", inventory)
	workstation.call("_on_customer_service_delivery_requested", order_id, 0)
	var after_first := Dictionary(session.call("formal_order", order_id))
	_check(_attached_count(after_first, 0) == 1 and _attached_count(after_first, 1) == 0 and StringName(after_first.get("state", &"")) == &"active", "one click consumes and attaches exactly one matching product without settling a multi-item order early")
	_check(first_target.disabled and not second_target.disabled, "completed item disables while the remaining item stays clickable")
	var inventory_after_first := Dictionary(session.call("inventory_snapshot"))
	workstation.call("_on_customer_service_delivery_requested", order_id, 0)
	_check(Dictionary(session.call("inventory_snapshot")) == inventory_after_first and _attached_count(Dictionary(session.call("formal_order", order_id)), 0) == 1, "repeated click on a completed item cannot consume a second product")

	var coins_before := int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0))
	workstation.call("_on_customer_service_delivery_requested", order_id, 1)
	var settled_order := Dictionary(session.call("formal_order", order_id))
	var pending: Array = Array(session.call("pending_order_payments"))
	var pending_total := 0
	for payment_value in pending:
		pending_total += int(Dictionary(payment_value).get("amount", 0))
	_check(StringName(settled_order.get("state", &"")) == &"settled" and _attached_count(settled_order, 1) == 1, "clicking the last item settles the complete order")
	_check(StringName(workstation.get("_formal_order_id")) != order_id and workstation.p1_session.phase == P1Session.Phase.SPREAD, "next customer becomes actionable before payment collection")
	_check(pending_total > 0 and not Array(workstation.get("_formal_payment_coin_sprites")).is_empty(), "successful order leaves visible, clickable payment coins")
	var repeated_completion := Dictionary(session.call("complete_order_delivery", order_id))
	_check(not bool(repeated_completion.get("success", false)) and Array(session.call("pending_order_payments")).size() == pending.size(), "repeated completion cannot duplicate settlement or payment")

	inventory = Dictionary(session.call("inventory_snapshot"))
	inventory["stock.packaged_drink.juice"] = 1
	session.call("save_inventory", inventory)
	for queued_order_value in Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders")):
		var queued_order_id := StringName(Dictionary(queued_order_value).get("order_id", &""))
		if not queued_order_id.is_empty():
			session.call("abandon_formal_order", queued_order_id, &"test_fixture_replaced")
	_check(Array(session.call("active_formal_orders")).is_empty() and Array(session.call("waiting_formal_orders")).is_empty(), "payment fixture releases every automatically routed customer before replacing the queue")
	var second_opened := Dictionary(session.call("open_formal_order", [item.duplicate(true)], {"source": &"payment_accumulation_test", "tutorial_no_countdown": true}))
	var second_order := Dictionary(second_opened.get("order", {}))
	var second_order_id := StringName(second_order.get("order_id", &""))
	_check(bool(second_opened.get("success", false)) and not second_order_id.is_empty(), "test opens a second order before collecting the first payment")
	workstation.call("_focus_formal_order", second_order, false)
	workstation.call("_refresh_customer_queue")
	workstation.call("_on_customer_service_delivery_requested", second_order_id, 0)
	var second_settled := Dictionary(session.call("formal_order", second_order_id))
	_check(StringName(second_settled.get("state", &"")) == &"settled", "the second order settles while the first payment remains pending")
	pending = Array(session.call("pending_order_payments"))
	pending_total = 0
	for payment_value in pending:
		pending_total += int(Dictionary(payment_value).get("amount", 0))
	_check(pending.size() == 2 and pending_total > 0 and Array(workstation.get("_formal_payment_coin_sprites")).size() > 1, "payments from consecutive orders accumulate as clickable coin sprites")

	workstation.queue_free()
	await process_frame
	workstation = WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	_check(not Array(workstation.get("_formal_payment_coin_sprites")).is_empty(), "reloading the workstation restores all durable pending payment coins")

	var payment_coins: Array = Array(workstation.get("_formal_payment_coin_sprites"))
	var clicked_coin := payment_coins[0] as TextureRect
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	clicked_coin.gui_input.emit(click_event)
	_check(Array(session.call("pending_order_payments")).is_empty() and int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) == coins_before + pending_total and Array(workstation.get("_formal_payment_coin_sprites")).is_empty(), "one coin click collects all pending coins exactly once")
	var collected_again := Dictionary(session.call("collect_all_pending_order_payments"))
	_check(bool(collected_again.get("already_collected", false)) and int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) == coins_before + pending_total, "repeated aggregate collection cannot duplicate coins")

	# Exact-frame business cutoff and overtime rejection are covered by the
	# dedicated business_day_cutoff_self_check fixture. Keeping them there avoids
	# coupling this delivery test to the opening-restock/tutorial clock state.

	workstation.queue_free()
	_finish()


func _unlock_juice(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	var areas := Dictionary(progression.get("unlocked_area_ids"))
	areas[&"area.packaged_drink"] = true
	progression.set("unlocked_area_ids", areas)
	var products := Dictionary(progression.get("unlocked_product_ids"))
	products[&"product.packaged_drink.juice"] = true
	progression.set("unlocked_product_ids", products)
	var stocks := Dictionary(progression.get("unlocked_stock_ids"))
	stocks[&"stock.packaged_drink.juice"] = true
	progression.set("unlocked_stock_ids", stocks)
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")


func _attached_count(order: Dictionary, item_index: int) -> int:
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return 0
	return Array(Dictionary(items[item_index]).get("attached_products", [])).size()


func _service_slot_for_order(workstation: Node, order_id: StringName) -> CustomerServiceSlot:
	for slot_value in workstation.customer_service_slots:
		var slot := slot_value as CustomerServiceSlot
		if slot != null and StringName(slot.get("_order_id")) == order_id:
			return slot
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ORDER_CARD_DELIVERY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("ORDER_CARD_DELIVERY_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
