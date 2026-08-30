extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Single-griddle pointer smoke must run with a display")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.pancake.batter"] = 0
	session.call("save_inventory", inventory)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var station: Control = workstation.multi_griddle_station
	station.set_griddle_count(3)
	_check(station.griddle_count() == 1 and station.units.size() == 1, "runtime exposes one griddle even with legacy tier requests")
	var unit: Control = station.units[0]
	var worktop := workstation.get_node("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as PancakeWorktopHotspots
	var ladle_hit := worktop.get_node("BatterLadleSource/HitButton") as Button
	await _click_control(ladle_hit)
	_check(station.is_batter_ladle_selected() and unit.pancake_surface.visible, "the rendered ladle click arms the empty griddle")
	await _hold_control(unit.pancake_surface, 24)
	_check(unit.state == CompactGriddleUnit.State.BATTER, "the sole visible pointer target starts a pancake without a customer order")
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.batter", 0)) == 0, "one pointer start uses the unlimited batter source without consuming inventory")
	game.queue_free()
	await process_frame
	_finish()


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
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


func _hold_control(control: Control, frame_count: int) -> void:
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
	for _frame in frame_count:
		await process_frame
	var released := pressed.duplicate() as InputEventMouseButton
	released.pressed = false
	root.push_input(released)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SINGLE_GRIDDLE_NO_ORDER_POINTER_GPU_SMOKE_PASS")
		quit(0)
		return
	printerr("SINGLE_GRIDDLE_NO_ORDER_POINTER_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
