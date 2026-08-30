extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/automatic_pack_pointer_gpu.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("AUTOMATIC_PACK_POINTER_GPU_SMOKE_FAIL\nGPU mode required")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish("")
		return
	session.call("begin_new_game")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var station: Control = workstation.multi_griddle_station
	var unit: CompactGriddleUnit = station.units[0]
	_prepare_pack_surface(unit)
	var feedbacks := PackedStringArray()
	unit.fold_feedback_requested.connect(func(_unit_index: int, feedback_kind: StringName) -> void: feedbacks.append(str(feedback_kind)))

	_check(unit.main_action.visible and not unit.main_action.disabled, "the current baseline exposes one explicit package action")
	await _click_control(unit.main_action)
	_check(
		unit.fold_model.is_region_folded(PancakeFoldModel.REGION_LEFT)
		and unit.fold_steps == 1
		and StringName(unit.get("_automatic_fold_pending_region")) == PancakeFoldModel.REGION_RIGHT,
		"one real package click commits the first automatic fold and arms the opposite side",
	)
	await create_timer(1.20).timeout
	_check(
		unit.fold_model.completed_fold_count() == 2
		and unit.fold_model.package_result == PancakeFoldModel.PACKAGE_BAG
		and unit.state == CompactGriddleUnit.State.READY,
		"the opposite side folds automatically and reaches the packaged ready state",
	)
	_check(feedbacks.count("automatic_fold") >= 2, "both automatic folds emit non-color feedback cues")

	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var screenshot := root.get_texture().get_image()
	_check(screenshot.save_png(output_absolute) == OK, "the final automatic-package frame is captured")
	game.queue_free()
	await process_frame
	_finish(output_absolute)


func _prepare_pack_surface(unit: CompactGriddleUnit) -> void:
	unit.begin_order({"time_limit": 72.0})
	unit.pancake_model.coverage.fill(1.0)
	unit.pancake_model.thickness.fill(0.55)
	unit.pancake_model.wetness.fill(0.18)
	unit.pancake_model.doneness.fill(0.62)
	unit.pancake_model.flip(false)
	unit.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	unit.state = CompactGriddleUnit.State.GARNISH
	unit.pancake_model.changed.emit()
	unit.call("_refresh_ui")


func _click_control(control: Control) -> void:
	var position: Vector2 = root.get_screen_transform() * control.get_global_rect().get_center()
	# A window resize can swallow the first synthetic hover. Match the production
	# pointer fixtures by warping and retrying before sending the click.
	for _attempt in 3:
		Input.warp_mouse(position)
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		Input.parse_input_event(motion)
		await process_frame
		if root.gui_get_hovered_control() == control:
			break
	var hovered := root.gui_get_hovered_control()
	_check(
		hovered == control,
		"the visible package button owns its pointer hit area (hovered=%s)" % [hovered.get_path() if hovered != null else "none"],
	)
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
		print("AUTOMATIC_PACK_POINTER_GPU_SMOKE_PASS")
		print("AUTOMATIC_PACK_POINTER_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("AUTOMATIC_PACK_POINTER_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
