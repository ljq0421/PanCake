extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("No-order griddle pointer smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for no-order griddle pointer smoke")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	var device_tiers := Dictionary(progression.get("device_tiers")).duplicate(true)
	device_tiers[&"device.pancake_griddle"] = 2
	progression.set("device_tiers", device_tiers)
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.pancake.batter"] = 3
	session.call("save_inventory", inventory)

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var station: Control = workstation.multi_griddle_station
	_clear_orders(session)
	workstation.set("_formal_order_id", &"")
	station.set_griddle_count(3)
	await process_frame
	_check(Array(session.call("active_formal_orders")).is_empty(), "the real workstation has no active customer before production")
	_check(station.griddle_count() == 3, "the real workstation exposes all three unlocked griddles")
	var batter_before := int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.batter", 0))
	await _click_griddle(station, 0, "without a customer order")
	var youtiao_opened := Dictionary(session.call("open_formal_order", [{
		"area_id": &"area.youtiao",
		"product_id": &"product.youtiao.plain",
		"quantity": 1,
	}], {"patience_seconds": 60.0}))
	var youtiao_order_id := StringName(Dictionary(youtiao_opened.get("order", {})).get("order_id", &""))
	workstation.call("_on_customer_service_focus_requested", youtiao_order_id)
	await _click_griddle(station, 1, "while a youtiao-only customer is focused")
	var pancake_opened := Dictionary(session.call("open_formal_order", [{
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"heat_preference": &"golden",
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
	}], {"patience_seconds": 60.0}))
	var pancake_order_id := StringName(Dictionary(pancake_opened.get("order", {})).get("order_id", &""))
	workstation.call("_on_customer_service_focus_requested", pancake_order_id)
	await _click_griddle(station, 2, "while a pancake customer is focused")
	var batter_after := int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.batter", 0))
	_check(batter_after == batter_before - 3, "three real pointer starts consume exactly three batter portions")
	_check(not workstation.tool_status_label.text.contains("选择一位含煎饼商品的顾客"), "runtime feedback no longer asks the player to select a pancake customer")
	game.queue_free()
	await process_frame
	_finish()


func _clear_orders(session: Node) -> void:
	for order_value in Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders")):
		var order_id := StringName(Dictionary(order_value).get("order_id", &""))
		if not order_id.is_empty():
			session.call("abandon_formal_order", order_id, &"no_order_pointer_fixture")


func _click_griddle(station: Control, unit_index: int, context: String) -> void:
	var unit: Control = station.units[unit_index]
	await _click_control(unit.main_action)
	_check(unit.state == CompactGriddleUnit.State.BATTER, "real pointer starts griddle %d %s" % [unit_index + 1, context])


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame
	_check(root.gui_get_hovered_control() == control, "%s owns its visible pointer target" % control.get_parent().name)
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
		print("MULTI_GRIDDLE_NO_ORDER_POINTER_GPU_SMOKE_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
