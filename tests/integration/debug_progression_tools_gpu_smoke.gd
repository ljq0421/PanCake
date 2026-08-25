extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/debug_progression_tools_gpu_1920x1080.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("DEBUG_PROGRESSION_TOOLS_GPU_SMOKE_FAIL\nGPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for debug progression GPU smoke")
	if session == null:
		_finish("")
		return
	session.call("begin_new_game")
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _frame in 8:
		await process_frame
	var overlay := main.get_node("DebugOverlay")
	var debug_panel := overlay.get_node("%DebugPanel") as Control
	var add_coins_button := overlay.get_node("%AddCoinsButton") as Button
	var quick_end_button := overlay.get_node("%QuickEndBusinessDayButton") as Button
	var pancake_tier_one_button := overlay.get_node("%PancakeTier1Button") as Button
	await _press_f3()
	_check(debug_panel.visible, "F3 opens the debug-only progression panel")
	await _click_control(add_coins_button)
	_check(int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) == 1000, "real pointer click grants and persists debug coins")
	await _click_control(quick_end_button)
	_check(main.workstation.daily_bill_panel.visible, "real pointer quick-end opens the formal daily bill")
	await _press_f3()
	_check(not debug_panel.visible, "F3 closes the panel so the underlying daily-bill control is reachable")
	await _press_f3()
	_check(debug_panel.visible and not pancake_tier_one_button.visible, "single-stall debug panel hides retired pancake capacity checkpoints")
	var progressed := Dictionary(session.call("five_area_progression_snapshot"))
	var device_tiers := Dictionary(progressed.get("device_tiers", {}))
	_check(int(device_tiers.get("device.pancake_griddle", 0)) == 0 and main.workstation.daily_bill_panel.visible, "single-stall debug state preserves pancake T0 without closing the daily bill")
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output_absolute)
	_check(save_error == OK and image.get_size() == Vector2i(1920, 1080), "GPU debug panel screenshot is captured at 1920x1080")
	main.queue_free()
	await process_frame
	session.call("reset_incompatible_development_save")
	_finish(output_absolute)


func _press_f3() -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_F3
	pressed.pressed = true
	root.push_input(pressed, true)
	await process_frame
	var released := InputEventKey.new()
	released.physical_keycode = KEY_F3
	released.pressed = false
	root.push_input(released, true)
	await process_frame


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	Input.warp_mouse(position)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed, true)
	await process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released, true)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish(output_absolute: String) -> void:
	if failures.is_empty():
		print("DEBUG_PROGRESSION_TOOLS_GPU_SMOKE_PASS")
		print("DEBUG_PROGRESSION_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("DEBUG_PROGRESSION_TOOLS_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
