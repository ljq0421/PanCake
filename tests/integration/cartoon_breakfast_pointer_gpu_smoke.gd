extends SceneTree

const WORKSTATION := preload("res://scenes/gameplay/cartoon_breakfast_workstation.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CARTOON_BREAKFAST_POINTER_GPU_SMOKE_FAIL\nGPU pointer smoke must run without --headless")
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
	session.call("begin_new_game")
	var progression := session.call("progression_service") as RefCounted
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true})
	progression.set("unlocked_stock_ids", {&"stock.pancake.batter": true, &"stock.youtiao.plain_dough": true})
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	var workstation := WORKSTATION.instantiate() as CartoonBreakfastWorkstation
	root.add_child(workstation)
	for _frame in 8:
		await process_frame

	await _click_control(workstation.contextual_tool_button)
	_check(StringName(workstation.multi_griddle_station.get("_selected_tool")) == &"tool.pancake.ladle", "real pointer click on the baked-in spatula prepares the batter ladle")

	await _begin_hold_control(workstation.fryer_hotspot_button)
	await create_timer(0.55).timeout
	await _release_control(workstation.fryer_hotspot_button)
	var loaded := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(StringName(loaded.get("state", &"")) == &"loaded" and int(loaded.get("quantity", 0)) == 4, "real pointer hold on the empty fryer loads four dough blanks")

	await _click_control(workstation.fryer_hotspot_button)
	var frying := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(StringName(frying.get("state", &"")) == &"frying", "real pointer click starts the loaded fryer")

	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 4:
		await process_frame
	await _hover_control(workstation.contextual_tool_button)
	_check(root.gui_get_hovered_control() == workstation.contextual_tool_button, "scaled 1280x720 pointer still reaches the spatula hotspot")
	workstation.queue_free()
	await process_frame
	_finish()


func _hover_control(control: Control) -> void:
	for _attempt in range(3):
		var position := _pointer_position(control)
		Input.warp_mouse(position)
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		Input.parse_input_event(motion)
		await process_frame
		if root.gui_get_hovered_control() == control:
			return


func _click_control(control: Control) -> void:
	await _begin_hold_control(control)
	await _release_control(control)


func _begin_hold_control(control: Control) -> void:
	await _hover_control(control)
	var position := _pointer_position(control)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	root.push_input(event)
	await process_frame


func _release_control(control: Control) -> void:
	var position := _pointer_position(control)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	event.global_position = position
	root.push_input(event)
	await process_frame


func _pointer_position(control: Control) -> Vector2:
	return root.get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARTOON_BREAKFAST_POINTER_GPU_SMOKE_PASS")
		quit(0)
		return
	printerr("CARTOON_BREAKFAST_POINTER_GPU_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
