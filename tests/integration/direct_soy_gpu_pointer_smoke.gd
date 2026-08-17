extends SceneTree

## Real-pointer acceptance for the serving-only soy station.  This intentionally
## runs with a GPU window: synthetic mouse events must reach the actual controls
## in the formal workstation rather than calling service methods directly.

const WORKSTATION := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("DIRECT_SOY_GPU_POINTER_SMOKE_FAIL\nGPU pointer smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	_setup_soy_session(session)
	var workstation := WORKSTATION.instantiate()
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	var soy_station := workstation.fresh_soy_station as DirectSoyStation
	_check(soy_station != null, "formal workstation exposes the soy serving station")
	if soy_station == null:
		workstation.queue_free()
		_finish()
		return
	for resolution in [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		for _frame in 3:
			await process_frame
		await _hover_control(soy_station.machine_output)
		_check(root.gui_get_hovered_control() == soy_station.machine_output, "%dx%d pointer reaches the empty-cup control (actual: %s)" % [resolution.x, resolution.y, _hovered_path()])
		await _hover_control(soy_station.nozzle_button)
		_check(root.gui_get_hovered_control() == soy_station.nozzle_button, "%dx%d pointer reaches the dispensing nozzle (actual: %s)" % [resolution.x, resolution.y, _hovered_path()])
		await _hover_control(soy_station.sugar_jar)
		_check(root.gui_get_hovered_control() == soy_station.sugar_jar, "%dx%d pointer reaches the sugar jar" % [resolution.x, resolution.y])

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 3:
		await process_frame
	var order_id := await _open_normal_sugar_order(session, workstation)
	_check(not order_id.is_empty(), "soy delivery order opens in a visible customer slot")
	await _click_control(soy_station.machine_output)
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("cup_state", &"")) == &"held_empty", "mouse click takes an empty cup")
	await _hold_control(soy_station.nozzle_button, 0.85)
	var filled := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(StringName(filled.get("cup_state", &"")) == &"filled" and is_equal_approx(float(Dictionary(filled.get("cup", {})).get("fill_ratio", 0.0)), 1.0), "holding the nozzle for 0.8 seconds fills the cup")
	await _click_control(soy_station.sugar_jar)
	_check(int(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("cup", {}).get("sugar_servings", 0)) == 1, "mouse click adds normal sugar")
	var target := workstation.call("_tutorial_delivery_target", session, &"area.fresh_soy_milk") as Control
	_check(target != null and not (target as Button).disabled, "soy order exposes an enabled drop target")
	if target != null:
		await _drag_control(soy_station.machine_output, target)
	var settled := Dictionary(session.call("formal_order", order_id))
	_check(StringName(settled.get("state", &"")) == &"settled", "dragging the sweetened cup completes delivery")
	workstation.queue_free()
	_finish()


func _setup_soy_session(session: Node) -> void:
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 100)
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.fresh_soy_milk.yellow_bean": true})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	var order_service: RefCounted = session.call("order_service")
	order_service.call("abandon_all_open_orders", &"gpu_setup")


func _open_normal_sugar_order(session: Node, workstation: Node) -> StringName:
	# The workstation creates a default playable order during its ready phase.
	# Remove it so the test has one deterministic, visible soy order and one
	# unambiguous drop target.
	var order_service: RefCounted = session.call("order_service")
	order_service.call("abandon_all_open_orders", &"gpu_pointer_soy_order")
	var opened := Dictionary(session.call("open_formal_order", [{
		"area_id": &"area.fresh_soy_milk",
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"quantity": 1,
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"sugar_servings": 1,
	}], {"patience_seconds": 30.0, "base_coins": 7}))
	workstation.call("_refresh_customer_queue")
	await process_frame
	return StringName(Dictionary(opened.get("order", {})).get("order_id", &""))


func _hover_control(control: Control) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame


func _click_control(control: Control) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await process_frame
	var released := pressed.duplicate()
	released.pressed = false
	root.push_input(released)
	await process_frame


func _hold_control(control: Control, seconds: float) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await create_timer(seconds).timeout
	var released := pressed.duplicate()
	released.pressed = false
	root.push_input(released)
	await process_frame


func _drag_control(source: Control, target: Control) -> void:
	var from := _pointer_position(source)
	var to := _pointer_position(target)
	Input.warp_mouse(from)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = from
	pressed.global_position = from
	root.push_input(pressed)
	await process_frame
	for ratio in [0.2, 0.45, 0.72, 1.0]:
		var position := from.lerp(to, ratio)
		Input.warp_mouse(position)
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		motion.relative = (to - from) * 0.25
		Input.parse_input_event(motion)
		await process_frame
	var released := pressed.duplicate()
	released.pressed = false
	released.position = to
	released.global_position = to
	root.push_input(released)
	await process_frame


func _pointer_position(control: Control) -> Vector2:
	return root.get_final_transform() * control.get_global_rect().get_center()


func _hovered_path() -> String:
	var hovered := root.gui_get_hovered_control()
	return str(hovered.get_path()) if hovered != null else "none"


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DIRECT_SOY_GPU_POINTER_SMOKE_PASS")
		quit(0)
		return
	printerr("DIRECT_SOY_GPU_POINTER_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
