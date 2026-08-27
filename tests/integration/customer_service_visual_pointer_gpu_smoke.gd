extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_1920 := "res://tmp/validation/tutorial_customer_center_v5_gpu_1920x1080.png"
const SCREENSHOT_1280 := "res://tmp/validation/tutorial_customer_center_v5_gpu_1280x720.png"

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
	# End the authored five-second stocking phase explicitly so the first real
	# day-one tutorial order exists before the workstation scene binds to it.
	session.call("advance_customer_arrivals", 5.1)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 4:
		await process_frame
	var workstation := game.get_node("Workstation")
	var center := workstation.get_node("SafeArea/ServiceCustomer3") as CustomerServiceSlot
	var active_orders: Array = Array(session.call("active_formal_orders"))
	var tutorial := Dictionary(active_orders[0]) if active_orders.size() == 1 else {}
	# Keep the live business clock from replacing the tutorial while the two GPU
	# frames are captured. The production restore path gives the card its exact
	# authored resting geometry without replaying the entrance animation.
	session.set_process(false)
	workstation.set_process(false)
	workstation.set("_restore_customer_layout_without_entrance", true)
	workstation.set("_customer_service_slot_signatures", {})
	workstation.call("_refresh_customer_service_slots", [tutorial])
	await process_frame
	var portrait := center.get_node("Portrait") as TextureRect
	var item_button := center.get_node("OrderPanel/ItemButton1") as Button
	var card_background := center.get_node("OrderPanel/CardBackground") as TextureRect
	var card_focus_button := center.get_node("OrderPanel/CardFocusButton") as Button
	_check(
		bool(tutorial.get("tutorial_no_countdown", false))
		and int(tutorial.get("service_slot", -1)) == 0
		and center.visible
		and _only_center_service_slot_is_visible(workstation),
		"the semantic slot-zero tutorial renders only in the center of five service slots",
	)
	_check(card_background.has_method("set_card_layout") and card_background.size == Vector2(264.0, 186.0), "the centered tutorial uses the 1.5× variable-height order card")
	_check(center.get_node_or_null("FocusFrame") == null and portrait.modulate == Color.WHITE and card_background.modulate == Color.WHITE, "the tutorial customer and order card have no frame or selection tint")
	_check(center.get_node_or_null("PortraitButton") == null, "the portrait has no click target")
	await _move_at(_card_header_point(card_focus_button))
	_check(root.gui_get_hovered_control() == card_focus_button, "the order card owns its real focus target")
	await _click_at(_card_header_point(card_focus_button))
	_check(
		StringName(workstation.get("_formal_order_id")) == StringName(tutorial.get("order_id", &"")),
		"clicking the centered order card focuses its unchanged tutorial order_id",
	)
	_check(center.get_node_or_null("FocusFrame") == null and portrait.modulate == Color.WHITE and card_background.modulate == Color.WHITE, "clicking an order card changes the delivery target without adding visual highlighting")
	await _move_at(_screen_point(item_button))
	_check(root.gui_get_hovered_control() == item_button and not item_button.disabled, "the centered v5 order item owns its real pointer target")
	await _move_at(Vector2(12.0, 700.0))
	await _capture(SCREENSHOT_1920, Vector2i(1920, 1080))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 8:
		await process_frame
	await _move_at(_screen_point(item_button))
	_check(root.gui_get_hovered_control() == item_button, "the centered tutorial item remains reachable at 1280x720")
	await _move_at(Vector2(12.0, 700.0))
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


func _click_at(position: Vector2) -> void:
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


func _card_header_point(control: Control) -> Vector2:
	var local_point := Vector2(control.size.x - 18.0, 18.0)
	return root.get_screen_transform() * (control.get_global_transform() * local_point)


func _capture(path: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(path)
	var save_error := image.save_png(absolute)
	_check(save_error == OK and image.get_size() == expected_size, "captured %s centered tutorial frame" % expected_size)


func _only_center_service_slot_is_visible(workstation: Node) -> bool:
	for slot_number in range(1, 6):
		var slot := workstation.get_node("SafeArea/ServiceCustomer%d" % slot_number) as Control
		if slot.visible != (slot_number == 3):
			return false
	return true


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
