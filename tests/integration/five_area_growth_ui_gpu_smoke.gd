extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const DAILY_BILL_CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/five_area_growth_ui_gpu_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/five_area_growth_ui_gpu_1280x720.png"},
	{"size": Vector2i(1366, 768), "path": "res://tmp/validation/five_area_growth_ui_gpu_1366x768.png"},
]
const WORKSHOP_CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/five_area_upgrade_workshop_gpu_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/five_area_upgrade_workshop_gpu_1280x720.png"},
	{"size": Vector2i(1366, 768), "path": "res://tmp/validation/five_area_upgrade_workshop_gpu_1366x768.png"},
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
	var growth_tickets := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets") as Control
	var stale_growth_cards_hidden := true
	for child in growth_tickets.get_children():
		if child is Control and (child as Control).visible:
			stale_growth_cards_hidden = false
	var unlock_progress_button := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthActions/UnlockProgressButton") as Button
	var daily_bill_close_button := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthActions/DailyBillCloseButton") as Button
	var five_area_infrastructure := station.get_node("FiveAreaInfrastructure") as Control
	var youtiao_station := station.get_node("FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer") as Control
	_check(stale_growth_cards_hidden, "day-end bill routes upgrades through the dedicated workshop instead of stale growth cards")
	_check(unlock_progress_button.text == "打开升级工坊" and not unlock_progress_button.disabled, "day-end bill exposes the workshop as a clear secondary action")
	_check(five_area_infrastructure.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED and youtiao_station.get_mouse_filter_with_override() == Control.MOUSE_FILTER_IGNORE, "daily bill recursively disables five-area workstation mouse input")
	var output_paths := PackedStringArray()
	var daily_bill := station.get_node("SafeArea/DailyBillPanel") as Control
	for capture_variant in DAILY_BILL_CAPTURES:
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
	await _click_control(unlock_progress_button)
	var workshop := station.get_node_or_null("SafeArea/UpgradeWorkshopOverlay") as UpgradeWorkshopOverlay
	_check(workshop != null and workshop.visible and not daily_bill.visible, "workshop opens as the exclusive day-end growth surface")
	var workshop_header := workshop.get_node("HeaderPanel") as Control if workshop != null else null
	var workshop_detail := workshop.get_node("DetailPanel") as Control if workshop != null else null
	var baocui_prop := workshop.get_node("UpgradeProps/WorkshopProp_growth_add_on_pancake_baocui") as Button if workshop != null else null
	var youtiao_fryer_prop := workshop.get_node("UpgradeProps/WorkshopProp_growth_area_youtiao") as Button if workshop != null else null
	var youtiao_finished_tray_prop := workshop.get_node("UpgradeProps/WorkshopProp_growth_capacity_youtiao_finished_tray") as Button if workshop != null else null
	var chicken_finished_tray_prop := workshop.get_node("UpgradeProps/WorkshopProp_growth_capacity_chicken_finished_tray") as Button if workshop != null else null
	var baocui_tag := baocui_prop.get_node("ConditionTag") as Label if baocui_prop != null else null
	_check(baocui_prop != null and baocui_prop.visible and baocui_tag != null and baocui_tag.text == "薄脆\n30 金币", "workshop renders concise equipment tags with name and price")
	_check(
		workshop_detail != null
		and youtiao_fryer_prop != null
		and youtiao_finished_tray_prop != null
		and chicken_finished_tray_prop != null
		and not workshop_detail.get_global_rect().intersects(youtiao_fryer_prop.get_global_rect())
		and not workshop_detail.get_global_rect().intersects(youtiao_finished_tray_prop.get_global_rect())
		and not workshop_detail.get_global_rect().intersects(chicken_finished_tray_prop.get_global_rect()),
		"workshop detail bar leaves the lower-left fryer and finished-tray information unobstructed"
	)
	if baocui_prop != null:
		var hovered := await _hover_control(baocui_prop, Vector2(0.5, 0.5))
		_check(hovered == baocui_prop, "workshop tag owns its complete pointer target")
		await _click_control(baocui_prop)
	var detail_text := workshop.get_node("DetailPanel/DetailText") as RichTextLabel if workshop != null else null
	var buy_button := workshop.get_node("DetailPanel/BuyButton") as Button if workshop != null else null
	_check(detail_text != null and "薄脆" in detail_text.text and buy_button != null and not buy_button.disabled, "selecting an available tag exposes a purchasable detail state")
	if workshop != null:
		(workshop.get_node("HoverHint") as Control).visible = false
	for capture_variant in WORKSHOP_CAPTURES:
		var capture: Dictionary = capture_variant
		var capture_size: Vector2i = capture.get("size", Vector2i.ZERO)
		DisplayServer.window_set_size(capture_size)
		for _frame in 4:
			await process_frame
		var visible_rect := root.get_visible_rect()
		_check(workshop_header != null and visible_rect.encloses(workshop_header.get_global_rect()), "workshop header remains inside the %dx%d stretched viewport" % [capture_size.x, capture_size.y])
		_check(workshop_detail != null and visible_rect.encloses(workshop_detail.get_global_rect()), "workshop detail panel remains inside the %dx%d stretched viewport" % [capture_size.x, capture_size.y])
		var output_absolute := ProjectSettings.globalize_path(str(capture.get("path", "")))
		var image := root.get_texture().get_image()
		var save_error := image.save_png(output_absolute)
		_check(save_error == OK and image.get_size() == capture_size, "GPU workshop captures at %dx%d" % [capture_size.x, capture_size.y])
		output_paths.append(output_absolute)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 4:
		await process_frame
	var workshop_back_button := workshop.get_node("DetailPanel/BackButton") as Button if workshop != null else null
	if workshop_back_button != null:
		await _click_control(workshop_back_button)
	_check(workshop != null and not workshop.visible and daily_bill.visible, "returning from the workshop restores the daily bill")
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
