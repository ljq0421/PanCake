extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for read-only order-card integration")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	_unlock_milk(session)
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.packaged_drink.milk"] = 1
	session.call("save_inventory", inventory)
	var opened: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.milk",
		"quantity": 1,
		"temperature_mode": &"room_temperature",
	}], {"source": &"read_only_order_card_test", "tutorial_no_countdown": true})
	var order := Dictionary(opened.get("order", {}))
	var order_id := StringName(order.get("order_id", &""))
	_check(bool(opened.get("success", false)) and not order_id.is_empty(), "test opens one formal order")

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	workstation.call("_focus_formal_order", order, false)
	for item_index in range(3):
		var target := workstation.get_node("SafeArea/OrderCard/OrderDishTarget%d" % (item_index + 1)) as Button
		_check(target.disabled and target.mouse_filter == Control.MOUSE_FILTER_IGNORE, "order-card item %d is a read-only point-of-sale hint" % (item_index + 1))

	var inventory_before := Dictionary(session.call("inventory_snapshot"))
	workstation.call("_on_order_dish_pressed", 0)
	var after_compatibility_call := Dictionary(session.call("formal_order", order_id))
	_check(_attached_count(after_compatibility_call, 0) == 0 and Dictionary(session.call("inventory_snapshot")) == inventory_before, "legacy order-card callback cannot deliver or consume a product")
	_check("托盘" in workstation.tool_status_label.text, "legacy callback directs the player to physical tray interaction")

	var staged: Dictionary = session.call("stage_product_to_order", {
		"source_kind": &"inventory",
		"source_index": 0,
		"product_id": &"product.packaged_drink.milk",
	}, order_id, 0)
	var staged_order := Dictionary(session.call("formal_order", order_id))
	_check(bool(staged.get("success", false)) and _attached_count(staged_order, 0) == 1 and StringName(staged_order.get("state", &"")) == &"active", "physical tray staging attaches to the exact item without settling early")
	var handed_off: Dictionary = session.call("handoff_order_tray", order_id)
	_check(bool(handed_off.get("success", false)) and StringName(Dictionary(session.call("formal_order", order_id)).get("state", &"")) == &"settled", "only complete whole-tray handoff settles the order")

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
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")


func _attached_count(order: Dictionary, item_index: int) -> int:
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return 0
	return Array(Dictionary(items[item_index]).get("attached_products", [])).size()


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
