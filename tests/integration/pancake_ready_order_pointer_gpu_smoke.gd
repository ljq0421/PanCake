extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Ready-pancake pointer smoke must run without --headless")
		quit(1)
		return
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for the ready-pancake pointer route")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	workstation._process(5.0)
	# Let the authored first-customer entrance finish so the item button is at
	# its real resting hit rectangle before sending pointer input.
	await create_timer(1.25).timeout
	var order := Dictionary(session.call("active_formal_order"))
	var order_id := StringName(order.get("order_id", &""))
	var customer_id := StringName(order.get("customer_id", &""))
	var station: Control = workstation.multi_griddle_station
	var unit: Control = station.units[0]
	var order_item := Dictionary(Array(order.get("items", []))[0])
	var source_product := {
		"product_instance_id": &"test.tutorial.ready.pointer",
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"temperature_mode": order_item.get("temperature_mode", &"hot"),
		"heat_preference": order_item.get("heat_preference", &"golden"),
		"ingredient_ids": Array(order_item.get("ingredient_ids", [])).duplicate(),
		"sauce_ids": Array(order_item.get("sauce_ids", [])).duplicate(),
		"score": 100.0,
		"feedback": "current-baseline pointer delivery",
		"status": &"available",
	}
	unit.mark_ready(source_product)
	station.call("_sync_snapshot_to_session")
	workstation.call("_refresh_pancake_drag_sources")
	workstation.call("_refresh_formal_shell")
	await process_frame
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.pancake.batter"] = 0
	for sauce_id_variant in Array(source_product.get("sauce_ids", [])):
		inventory[str(StringName(sauce_id_variant))] = 1
	session.call("save_inventory", inventory)
	var batter_before := int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.batter", 0))
	var target_slot := _service_slot_for_order(workstation, order_id)
	var order_target := target_slot.get_node("OrderPanel/ItemButton1") as Button if target_slot != null else null
	_check(
		unit.state == CompactGriddleUnit.State.READY
		and station.ready_source_refs().size() == 1,
		"finishing the package creates one authoritative ready-pancake source"
	)
	_check(order_target != null and not order_target.disabled and order_target.mouse_filter == Control.MOUSE_FILTER_STOP, "tutorial customer item remains a real pointer target")
	if order_target != null:
		await _click_control(order_target)
	await process_frame
	await process_frame
	var settled := Dictionary(session.call("formal_order", order_id))
	var next_order := Dictionary(session.call("active_formal_order"))
	var tutorial := Dictionary(Dictionary(session.call("five_area_progression_snapshot")).get("tutorial", {}))
	var batter_after := int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.batter", 0))
	_check(
		StringName(settled.get("state", &"")) == &"settled"
		and batter_after == batter_before
		and unit.state == CompactGriddleUnit.State.IDLE
		and station.ready_source_refs().is_empty(),
		"one real pointer click consumes and clears exactly one packaged pancake"
	)
	_check(
		Array(tutorial.get("completed_area_ids", [])).has("area.pancake")
		and (
			next_order.is_empty()
			or (
				StringName(next_order.get("order_id", &"")) != order_id
				and StringName(next_order.get("customer_id", &"")) != customer_id
			)
		),
		"tutorial settlement clears its customer and returns control to the normal arrival scheduler"
	)
	game.queue_free()
	await process_frame
	_finish()


func _service_slot_for_order(workstation: Node, order_id: StringName) -> Control:
	for slot_index in 5:
		var slot := workstation.get_node("SafeArea/ServiceCustomer%d" % (slot_index + 1)) as Control
		if slot.visible and StringName(slot.get("_order_id")) == order_id:
			return slot
	return null


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PANCAKE_READY_ORDER_POINTER_GPU_SMOKE_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
