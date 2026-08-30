extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT := "res://tmp/validation/single_jianbing_stall_gpu_1920x1080.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("SINGLE_JIANBING_STALL_GPU_SMOKE_FAIL\nGPU smoke must run with a display")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish("")
		return
	session.call("begin_new_game")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.pancake.batter"] = 2
	session.call("save_inventory", inventory)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation: Node = game.get_node("Workstation")
	var multi: Control = workstation.multi_griddle_station
	multi.set_griddle_count(3)
	_check(multi.griddle_count() == 1 and multi.units.size() == 1, "single artwork stall keeps exactly one logical and visible griddle")
	var artwork := workstation.get_node_or_null("SafeArea/JianbingStallArtwork") as Control
	_check(artwork != null and artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative stall artwork is nonblocking")
	var unit: Node = multi.units[0]
	unit.main_action.pressed.emit()
	await process_frame
	_check(unit.state == CompactGriddleUnit.State.BATTER and unit.pancake_surface.visible, "adding batter activates the rendered pancake surface")
	var center: Vector2 = unit.pancake_surface.get_global_rect().get_center()
	_press(center)
	for step in 96:
		var progress := float(step + 1) / 96.0
		var angle := progress * TAU * 3.0
		var radius := lerpf(18.0, 102.0, progress)
		_move(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.70), MOUSE_BUTTON_MASK_LEFT)
		await process_frame
	_release(center + Vector2(102.0, 0.0))
	await process_frame
	_check(unit.pancake_model.covered_cell_count() > 1, "a real held circular stroke spreads batter on the lone griddle")
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path(SCREENSHOT)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output)
	_check(save_error == OK and image.get_size() == Vector2i(1920, 1080), "captured the composed single-stall workbench screenshot")
	game.queue_free()
	await process_frame
	_finish(output)


func _press(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	root.push_input(event)


func _move(position: Vector2, button_mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.button_mask = button_mask
	root.push_input(event)


func _release(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	event.global_position = position
	root.push_input(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(output: String) -> void:
	if failures.is_empty():
		print("SINGLE_JIANBING_STALL_GPU_SMOKE_PASS")
		print("SINGLE_JIANBING_STALL_SCREENSHOT=%s" % output)
		quit(0)
		return
	printerr("SINGLE_JIANBING_STALL_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
