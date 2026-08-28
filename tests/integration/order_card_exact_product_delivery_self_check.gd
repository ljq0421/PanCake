extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for exact-product delivery")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	_clear_orders(session)
	_enable_youtiao_and_chicken(session)
	var stored_youtiao := Dictionary(session.call("_append_prepared_product", &"slot.04", {
		"product_instance_id": &"test.exact_delivery.youtiao",
		"area_id": &"area.youtiao",
		"product_id": &"product.youtiao.plain",
		"quality": 100.0,
		"status": &"available",
	}))
	var chicken_opened := Dictionary(session.call("open_formal_order", [{
		"area_id": &"area.youtiao",
		"product_id": &"product.chicken.cutlet",
		"quantity": 1,
	}], {"source": &"exact_product_delivery", "patience_seconds": 120.0}))
	var chicken_order := Dictionary(chicken_opened.get("order", {}))
	var chicken_order_id := StringName(chicken_order.get("order_id", &""))
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	var chosen := Dictionary(workstation.call("_delivery_source_for_item", session, chicken_order_id, chicken_order, 0))
	_check(
		bool(stored_youtiao.get("success", false))
		and not chicken_order_id.is_empty()
		and chosen.is_empty()
		and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", 0)) == 1,
		"a chicken-card click does not substitute or consume a ready youtiao"
	)
	workstation.queue_free()
	_finish()


func _enable_youtiao_and_chicken(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 2})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.chicken.cutlet": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.chicken.cutlet": true})
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true, &"stock.chicken.cutlet_raw": true})
	progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true, &"growth.equipment.youtiao.dual_basket": true, &"growth.capacity.chicken_finished_tray": true})
	session.call("_sync_progression_to_save")


func _clear_orders(session: Node) -> void:
	for order_value in Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders")):
		var order_id := StringName(Dictionary(order_value).get("order_id", &""))
		if not order_id.is_empty():
			session.call("abandon_formal_order", order_id, &"exact_product_delivery_fixture")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ORDER_CARD_EXACT_PRODUCT_DELIVERY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("ORDER_CARD_EXACT_PRODUCT_DELIVERY_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
