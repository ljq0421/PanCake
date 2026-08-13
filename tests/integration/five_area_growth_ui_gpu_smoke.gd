extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const SCREENSHOT_CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/five_area_growth_ui_gpu_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/five_area_growth_ui_gpu_1280x720.png"},
	{"size": Vector2i(1366, 768), "path": "res://tmp/validation/five_area_growth_ui_gpu_1366x768.png"},
]

var _failures := PackedStringArray()
var _daily_bill_closed_count := 0


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
	progression.set("coins", 100)
	progression.set("reputation", 20)
	progression.set("current_day", 2)
	progression.set("area_mastery", {&"area.pancake": 6})
	progression.set("area_mastery_details", {&"area.pancake": {"qualified": 6, "a_grade": 1}})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
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
	var unlock_progress_button := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthActions/UnlockProgressButton") as Button
	var unlock_progress_panel := station.get_node("SafeArea/UnlockProgressPanel") as Control
	var daily_bill_close_button := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthActions/DailyBillCloseButton") as Button
	var five_area_infrastructure := station.get_node("FiveAreaInfrastructure") as Control
	var youtiao_station := station.get_node("FiveAreaInfrastructure/Stations/YoutiaoStation") as Control
	_check(station.get_node_or_null("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket4") == null, "GPU day-end scene has exactly three growth cards")
	_check("宽幅摊饼器" in ticket_1.text and "辣椒酱" in ticket_2.text and "成品饮品柜" in ticket_3.text, "GPU day-end scene renders the intended first-day growth path")
	_check(not ticket_1.disabled and not ticket_2.disabled and not ticket_3.disabled, "GPU day-end scene reflects the real ready state of all three cards")
	_check("[安装位]" in ticket_1.text and "可预订，明日生效" in ticket_1.text and ticket_1.tooltip_text == "可预订，明日生效", "GPU growth card uses the ordinary strict purchase presentation")
	_check(five_area_infrastructure.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED and youtiao_station.get_mouse_filter_with_override() == Control.MOUSE_FILTER_IGNORE, "daily bill recursively disables five-area workstation mouse input")
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
		for ticket in [ticket_1, ticket_2, ticket_3]:
			for ratio in [Vector2(0.02, 0.02), Vector2(0.5, 0.02), Vector2(0.98, 0.02), Vector2(0.02, 0.5), Vector2(0.5, 0.5), Vector2(0.98, 0.5), Vector2(0.02, 0.98), Vector2(0.5, 0.98), Vector2(0.98, 0.98)]:
				var hovered := await _hover_control(ticket, ratio)
				var hovered_path := str(hovered.get_path()) if hovered != null else "<none>"
				_check(hovered == ticket, "growth card %s owns point %.2f,%.2f at %dx%d (hovered %s)" % [ticket.name, ratio.x, ratio.y, capture_size.x, capture_size.y, hovered_path])
		var first_gap := Vector2(ticket_1.get_global_rect().end.x + (ticket_2.get_global_rect().position.x - ticket_1.get_global_rect().end.x) * 0.5, ticket_1.get_global_rect().get_center().y)
		var second_gap := Vector2(ticket_2.get_global_rect().end.x + (ticket_3.get_global_rect().position.x - ticket_2.get_global_rect().end.x) * 0.5, ticket_2.get_global_rect().get_center().y)
		for gap_position in [first_gap, second_gap]:
			await _move_pointer(gap_position)
			_check(root.gui_get_hovered_control() not in [ticket_1, ticket_2, ticket_3], "card gap does not hover a growth card at %dx%d" % [capture_size.x, capture_size.y])
		await _click_control(unlock_progress_button, 0.25)
		_check(unlock_progress_panel.visible, "unlock progress opens from the left side at %dx%d" % [capture_size.x, capture_size.y])
		station.call("_close_unlock_progress")
		await process_frame
		await _click_control(unlock_progress_button, 0.75)
		_check(unlock_progress_panel.visible, "unlock progress opens from the right side at %dx%d" % [capture_size.x, capture_size.y])
		station.call("_close_unlock_progress")
		await process_frame
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 4:
		await process_frame
	await _click_control(ticket_1)
	var pending: Dictionary = session.call("five_area_progression_snapshot")
	_check(str(pending.get("pending_install_purchase", "")) == "growth.tool.pancake.wide_spreader" and int(pending.get("coins", 0)) == 88, "real GPU pointer click charges and reserves a strictly eligible install")
	station.daily_bill_closed.connect(_on_daily_bill_closed)
	await _click_control(daily_bill_close_button)
	_check(_daily_bill_closed_count == 1 and not daily_bill.visible, "return-to-start button receives the real pointer click above the youtiao station")
	_check(five_area_infrastructure.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED, "closing the bill restores the authored five-area mouse behavior")
	station.queue_free()
	await process_frame
	_finish(output_paths)


func _click_control(control: Control, horizontal_ratio: float = 0.5) -> void:
	var local_position := Vector2(control.size.x * horizontal_ratio, control.size.y * 0.5)
	var position := control.get_global_transform_with_canvas() * local_position
	await _move_pointer(position)
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


func _hover_control(control: Control, local_ratio: Vector2) -> Control:
	var local_position := Vector2(control.size.x * local_ratio.x, control.size.y * local_ratio.y)
	await _move_pointer(control.get_global_transform_with_canvas() * local_position)
	return root.gui_get_hovered_control()


func _move_pointer(position: Vector2) -> void:
	var logical_size := root.get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	var window_position := position
	if logical_size.x > 0.0 and logical_size.y > 0.0:
		window_position *= window_size / logical_size
	Input.warp_mouse(window_position)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame


func _on_daily_bill_closed() -> void:
	_daily_bill_closed_count += 1


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
