extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Pancake press pointer smoke must run with a display")
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
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var station: Control = workstation.multi_griddle_station
	var unit: Node = station.units[0]
	var progression: RefCounted = session.call("progression_service")
	var owned_growth: Dictionary = Dictionary(progression.get("owned_growth_ids")).duplicate(true)
	owned_growth[&"growth.automation.pancake.press_once"] = true
	progression.set("owned_growth_ids", owned_growth)
	var worktop := workstation.get_node("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as PancakeWorktopHotspots
	worktop.refresh_from_session()
	var press_hit := worktop.get_node("SpreaderSource/HitButton") as Button
	_check(press_hit != null, "the rendered press has a native button hit target")
	station.clear_held_tool()
	unit.reset_unit()
	var batter_started := Dictionary(station.take_batter_from_ladle())
	if press_hit != null:
		await _hover_control(press_hit)
		_check(root.gui_get_hovered_control() == press_hit, "the visible press owns its image hit area")
		await _click_control(press_hit)
	_check(bool(batter_started.get("success", false)) and unit.state == CompactGriddleUnit.State.FIRST_SIDE, "a real pointer click on the press advances batter to first-side cooking")
	game.queue_free()
	await process_frame
	_finish()


func _hover_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	await _hover_control(control)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
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
		print("PANCAKE_PRESS_POINTER_GPU_SMOKE_PASS")
		quit(0)
		return
	printerr("PANCAKE_PRESS_POINTER_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
