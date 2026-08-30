extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/current_baseline_initial_workstation_gpu.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("INITIAL_UNLOCK_WORKSTATION_GPU_SMOKE_FAIL\nGPU mode required")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish("")
		return
	var begun := Dictionary(session.call("begin_new_game"))
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	_check(bool(begun.get("success", false)), "new game starts successfully")
	_check(
		int(progression.get("current_day", 0)) == 1
		and Array(progression.get("unlocked_area_ids", [])).has("area.pancake")
		and not Array(progression.get("unlocked_stock_ids", [])).has("stock.pancake.egg"),
		"current baseline starts on day one with the pancake area and no egg unlock"
	)

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var station: Control = workstation.multi_griddle_station
	var unit: Control = station.units[0]
	var worktop := workstation.get_node("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as PancakeWorktopHotspots
	var ladle_hit := worktop.get_node("BatterLadleSource/HitButton") as Button
	var spreader_hit := worktop.get_node("SpreaderSource/HitButton") as Button
	var sweet_sauce := worktop.get_node("SecretSauceSource/Hotspot") as ProductDragSource
	var egg := worktop.get_node("EggCarton/Hotspot") as ProductDragSource

	_check(station.griddle_count() == 1 and station.units.size() == 1, "current four-area baseline exposes one pancake griddle")
	_check(ladle_hit.visible and not ladle_hit.disabled, "the authored batter ladle is available on a new game")
	_check(spreader_hit.visible and not spreader_hit.disabled, "the authored manual spreader is available on a new game")
	_check(not sweet_sauce.disabled and not sweet_sauce.native_drag_enabled, "sweet sauce uses the current click-to-prime interaction")
	_check(egg.disabled and not egg.native_drag_enabled, "egg remains locked and never exposes the removed raw-ingredient drag grammar")

	await _hover_control(ladle_hit)
	_check(root.gui_get_hovered_control() == ladle_hit, "the rendered ladle owns its pointer hit area")
	await _click_control(ladle_hit)
	_check(
		station.is_batter_ladle_selected()
		and unit.state == CompactGriddleUnit.State.IDLE
		and unit.pancake_surface.visible,
		"one real ladle click arms the empty griddle without creating hidden batter"
	)

	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var screenshot := root.get_texture().get_image()
	_check(screenshot.save_png(output_absolute) == OK, "the current initial workstation frame is captured")
	game.queue_free()
	await process_frame
	_finish(output_absolute)


func _hover_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame


func _click_control(control: Control) -> void:
	await _hover_control(control)
	var position := control.get_global_rect().get_center()
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


func _finish(output_absolute: String) -> void:
	if failures.is_empty():
		print("INITIAL_UNLOCK_WORKSTATION_GPU_SMOKE_PASS")
		print("INITIAL_UNLOCK_WORKSTATION_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("INITIAL_UNLOCK_WORKSTATION_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
