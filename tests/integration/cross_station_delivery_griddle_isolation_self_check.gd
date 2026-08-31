extends SceneTree

## Guards the transaction boundary between the oil-strip / soy stations and the
## live pancake griddle.  Each case uses the actual customer-card button path,
## then waits through the griddle's one-second safety save interval.

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")

var _failures := PackedStringArray()
var _sequence := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for cross-station delivery isolation")
	if session == null:
		_finish()
		return
	_setup_session(session)
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 4:
		await process_frame
	session.call("set_business_paused", true)
	for case_value in [
		{"pancake_state": &"in_progress", "delivery_product_id": &"product.youtiao.plain", "queue_next_pancake_order": true},
		{"pancake_state": &"ready", "delivery_product_id": &"product.youtiao.plain", "queue_next_pancake_order": true},
		{"pancake_state": &"in_progress", "delivery_product_id": &"product.fresh_soy_milk.yellow_bean", "queue_next_pancake_order": true},
		{"pancake_state": &"ready", "delivery_product_id": &"product.fresh_soy_milk.yellow_bean", "queue_next_pancake_order": true},
	]:
		await _run_delivery_case(session, workstation, Dictionary(case_value))
	workstation.queue_free()
	_finish()


func _setup_session(session: Node) -> void:
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 1, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true})
	progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true})
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	_clear_orders(session)


func _run_delivery_case(session: Node, workstation: Node, case_value: Dictionary) -> void:
	_clear_orders(session)
	_sequence += 1
	var pancake_state := StringName(case_value.get("pancake_state", &""))
	var product_id := StringName(case_value.get("delivery_product_id", &""))
	_prepare_pancake(workstation, pancake_state)
	_prepare_delivery_product(session, product_id)
	var soy_station := workstation.get("fresh_soy_station") as Node
	if soy_station != null:
		soy_station.call("refresh_from_session")
	workstation.call("_on_formal_shell_changed")
	for _frame in 2:
		await process_frame
	var station: Node = workstation.get("multi_griddle_station") as Node
	_check(station != null, "workstation exposes the multi-griddle station for %s/%s" % [pancake_state, product_id])
	if station == null:
		return
	var before_local := Dictionary(station.call("snapshot")).duplicate(true)
	var before_session := Dictionary(session.call("five_area_pancake_griddles_snapshot")).duplicate(true)
	var item := _order_item_for_product(product_id)
	var opened := Dictionary(session.call("open_formal_order", [item], {"source": &"cross_station_griddle_isolation", "patience_seconds": 120.0}))
	var order := Dictionary(opened.get("order", {}))
	var order_id := StringName(order.get("order_id", &""))
	if bool(case_value.get("queue_next_pancake_order", false)):
		var follow_up := Dictionary(session.call("open_formal_order", [_pancake_order_item()], {"source": &"cross_station_griddle_follow_up", "patience_seconds": 120.0}))
		_check(not StringName(Dictionary(follow_up.get("order", {})).get("order_id", &"")).is_empty(), "%s/%s queues a following pancake order" % [pancake_state, product_id])
	var service_slot := _service_slot_for_order(workstation, order_id)
	var button := service_slot.get_node_or_null("OrderPanel/ItemButton1") as Button if service_slot != null else null
	_check(button != null and button.visible and not button.disabled, "%s/%s exposes an enabled customer-card delivery button" % [pancake_state, product_id])
	if button != null:
		button.pressed.emit()
	for _frame in 3:
		await process_frame
	# The station normally performs this on a one-second cadence. Force one
	# immediate sync as well, so a regression is deterministic even on a slow CI.
	station.call("_sync_snapshot_to_session")
	await create_timer(1.05, true).timeout
	for _frame in 2:
		await process_frame
	var settled := Dictionary(session.call("formal_order", order_id))
	var after_local := Dictionary(station.call("snapshot"))
	var after_session := Dictionary(session.call("five_area_pancake_griddles_snapshot"))
	var label := "%s pancake + %s delivery" % [pancake_state, product_id]
	_check(StringName(settled.get("state", &"")) == &"settled", "%s settles the non-pancake order through the real card click" % label)
	_check(after_local == before_local, "%s leaves the visual griddle snapshot unchanged\nbefore=%s\nafter=%s" % [label, JSON.stringify(before_local), JSON.stringify(after_local)])
	_check(after_session == before_session, "%s leaves the authoritative griddle snapshot unchanged\nbefore=%s\nafter=%s" % [label, JSON.stringify(before_session), JSON.stringify(after_session)])


func _prepare_pancake(workstation: Node, pancake_state: StringName) -> void:
	var station: Node = workstation.get("multi_griddle_station") as Node
	if station == null:
		_check(false, "workstation exposes the multi-griddle station")
		return
	var units: Array = Array(station.get("units"))
	if units.is_empty():
		_check(false, "multi-griddle station exposes its primary unit")
		return
	var unit := units[0] as Node
	unit.reset_unit()
	if pancake_state == &"ready":
		unit.mark_ready({
			"product_instance_id": StringName("test.cross_station.ready.%d" % _sequence),
			"area_id": &"area.pancake",
			"product_id": &"product.pancake.custom",
			"status": &"available",
		})
	else:
		unit.begin_order({"id": StringName("test.cross_station.in_progress.%d" % _sequence)})
	station.call("_sync_snapshot_to_session")


func _prepare_delivery_product(session: Node, product_id: StringName) -> void:
	if product_id == &"product.youtiao.plain":
		session.call("clear_prepared_product_slots")
		session.call("_append_prepared_product", &"slot.04", {
			"product_instance_id": StringName("test.cross_station.youtiao.%d" % _sequence),
			"area_id": &"area.youtiao",
			"product_id": product_id,
			"material_cost": 2,
			"status": &"available",
		})
		return
	var empty_cup := Dictionary(session.call("take_f4_soy_empty_cup"))
	var filled_cup := Dictionary(session.call("fill_f4_soy_empty_cup", 1.0)) if bool(empty_cup.get("success", false)) else {}
	_check(bool(empty_cup.get("success", false)) and bool(filled_cup.get("success", false)), "soy fixture prepares one filled cup")


func _order_item_for_product(product_id: StringName) -> Dictionary:
	if product_id == &"product.youtiao.plain":
		return {"area_id": &"area.youtiao", "product_id": product_id, "quantity": 1}
	return {"area_id": &"area.fresh_soy_milk", "product_id": product_id, "quantity": 1}


func _pancake_order_item() -> Dictionary:
	return {
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
	}


func _service_slot_for_order(workstation: Node, order_id: StringName) -> Control:
	for slot in workstation.customer_service_slots:
		if StringName(slot.get("_order_id")) == order_id:
			return slot
	return null


func _clear_orders(session: Node) -> void:
	var orders: Array = Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders"))
	for order_value in orders:
		var order_id := StringName(Dictionary(order_value).get("order_id", &""))
		if not order_id.is_empty():
			session.call("abandon_formal_order", order_id, &"cross_station_griddle_isolation")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CROSS_STATION_DELIVERY_GRIDDLE_ISOLATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CROSS_STATION_DELIVERY_GRIDDLE_ISOLATION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
