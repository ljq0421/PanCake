extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_1920 := "res://tmp/validation/tutorial_customer_center_v4_gpu_1920x1080.png"
const SCREENSHOT_1280 := "res://tmp/validation/tutorial_customer_center_v4_gpu_1280x720.png"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Customer-service visual pointer smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for the centered tutorial customer")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 14:
		await process_frame
	var workstation := game.get_node("Workstation")
	var active_orders: Array = Array(session.call("active_formal_orders"))
	var tutorial := Dictionary(active_orders[0]) if active_orders.size() == 1 else {}
	var left := workstation.get_node("SafeArea/ServiceCustomer1") as Control
	var center := workstation.get_node("SafeArea/ServiceCustomer2") as Control
	var right := workstation.get_node("SafeArea/ServiceCustomer3") as Control
	var portrait_button := center.get_node("PortraitButton") as Button
	var item_button := center.get_node("OrderPanel/ItemButton1") as Button
	var card_background := center.get_node("OrderPanel/CardBackground") as TextureRect
	_check(
		bool(tutorial.get("tutorial_no_countdown", false))
		and int(tutorial.get("service_slot", -1)) == 0
		and not left.visible
		and center.visible
		and not right.visible,
		"the semantic slot-zero tutorial renders only in the center service slot",
	)
	_check(
		card_background.texture != null
		and card_background.texture.resource_path.ends_with("order_card_multi_dish_v4_chinese_ui.png"),
		"the centered tutorial uses the approved v4 Chinese order-card texture",
	)
	await _move_at(portrait_button.get_global_rect().get_center())
	_check(root.gui_get_hovered_control() == portrait_button, "the lowered center portrait owns its real pointer target")
	await _click_control(portrait_button)
	_check(
		StringName(workstation.get("_formal_order_id")) == StringName(tutorial.get("order_id", &"")),
		"clicking the centered portrait focuses its unchanged tutorial order_id",
	)
	await _move_at(item_button.get_global_rect().get_center())
	_check(root.gui_get_hovered_control() == item_button and not item_button.disabled, "the centered v4 order item owns its real pointer target")
	await _capture(SCREENSHOT_1920, Vector2i(1920, 1080))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 8:
		await process_frame
	await _move_at(_screen_point(item_button))
	_check(root.gui_get_hovered_control() == item_button, "the centered tutorial item remains reachable at 1280x720")
	await _capture(SCREENSHOT_1280, Vector2i(1280, 720))
	game.queue_free()
	await process_frame
	_finish()


func _move_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	await _move_at(position)
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


func _screen_point(control: Control) -> Vector2:
	return root.get_screen_transform() * control.get_global_rect().get_center()


func _capture(path: String, expected_size: Vector2i) -> void:
	var image := root.get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(path)
	var save_error := image.save_png(absolute)
	_check(save_error == OK and image.get_size() == expected_size, "captured %s centered tutorial frame" % expected_size)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_SERVICE_VISUAL_POINTER_GPU_SMOKE_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
