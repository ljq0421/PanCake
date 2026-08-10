extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const SCREENSHOT_CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/five_area_growth_ui_gpu_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/five_area_growth_ui_gpu_1280x720.png"},
]

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FIVE_AREA_GROWTH_UI_GPU_SMOKE_FAIL\nGPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for GPU growth smoke")
	if session == null:
		_finish(PackedStringArray())
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 20)
	progression.set("reputation", 0)
	progression.set("area_mastery", {&"area.pancake": 0})
	progression.set("area_mastery_details", {&"area.pancake": {"qualified": 0, "a_grade": 0}})
	progression.set("tutorial_completed_area_ids", {})
	var station := WORKSTATION_SCENE.instantiate()
	root.add_child(station)
	for _frame in 8:
		await process_frame
	station.call("end_business_day")
	for _frame in 4:
		await process_frame
	var ticket_1 := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket1") as Button
	var ticket_2 := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket2") as Button
	var ticket_3 := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket3") as Button
	_check(station.get_node_or_null("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket4") == null, "GPU day-end scene has exactly three growth cards")
	_check("宽幅摊饼器" in ticket_1.text and "辣椒酱" in ticket_2.text and "成品饮品柜" in ticket_3.text, "GPU day-end scene renders the intended first-day growth path")
	_check(not ticket_1.disabled and ticket_2.disabled and ticket_3.disabled, "GPU day-end scene exposes exactly one clickable coin guarantee")
	_check("[安装位 · 金币保底]" in ticket_1.text and "金币 20/12" in ticket_1.text, "GPU guarantee card visibly identifies its slot and catalog price")
	var output_paths := PackedStringArray()
	var daily_bill := station.get_node("SafeArea/DailyBillPanel") as Control
	for capture_variant in SCREENSHOT_CAPTURES:
		var capture: Dictionary = capture_variant
		var capture_size: Vector2i = capture.get("size", Vector2i.ZERO)
		DisplayServer.window_set_size(capture_size)
		for _frame in 4:
			await process_frame
		_check(root.get_visible_rect().encloses(daily_bill.get_global_rect()), "daily bill remains inside the %dx%d stretched viewport" % [capture_size.x, capture_size.y])
		var output_absolute := ProjectSettings.globalize_path(str(capture.get("path", "")))
		var image := root.get_texture().get_image()
		var save_error := image.save_png(output_absolute)
		_check(save_error == OK and image.get_size() == capture_size, "GPU day-end scene captures at %dx%d" % [capture_size.x, capture_size.y])
		output_paths.append(output_absolute)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 4:
		await process_frame
	await _click_control(ticket_1)
	var pending: Dictionary = session.call("five_area_progression_snapshot")
	_check(str(pending.get("pending_install_purchase", "")) == "growth.tool.pancake.wide_spreader" and int(pending.get("coins", 0)) == 8, "real GPU pointer click charges and reserves the guaranteed install")
	station.queue_free()
	await process_frame
	_finish(output_paths)


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


func _finish(output_paths: PackedStringArray) -> void:
	if _failures.is_empty():
		print("FIVE_AREA_GROWTH_UI_GPU_SMOKE_PASS")
		for output_absolute in output_paths:
			print("GROWTH_UI_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("FIVE_AREA_GROWTH_UI_GPU_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
