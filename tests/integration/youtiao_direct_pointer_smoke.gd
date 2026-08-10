extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const RECIPE := &"recipe.youtiao.plain"
const AUTO_LIFT := &"automation.youtiao.auto_lift"
const AUTO_LOAD := &"automation.youtiao.auto_load"
const SCREENSHOT_1920 := "res://tmp/validation/youtiao_station_formal_1920x1080.png"
const SCREENSHOT_1280 := "res://tmp/validation/youtiao_station_formal_1280x720.png"

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("YOUTIAO_DIRECT_POINTER_SMOKE_FAIL\nGPU pointer smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0})
	progression.set("unlocked_recipe_ids", {RECIPE: true})
	progression.set("unlocked_product_ids", {&"product.youtiao.plain": true})
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true})
	progression.set("unlocked_automation_ids", {AUTO_LOAD: true})
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.youtiao.plain_dough"] = 5
	session.call("save_inventory", inventory)
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	var station := workstation.get_node("FiveAreaInfrastructure/Stations/YoutiaoStation") as DirectYoutiaoStation
	var tray := workstation.get_node("FiveAreaInfrastructure/CustomerHandoffTray") as CustomerHandoffTray
	_check(station != null and tray != null, "the formal same-screen scene exposes the direct fryer and physical tray")
	if station == null or tray == null:
		workstation.queue_free()
		await process_frame
		_finish()
		return
	workstation.set_process(false)
	_clear_formal_orders(session)
	var opened: Dictionary = session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "temperature_mode": &"room_temperature"}])
	_check(bool(opened.get("success", false)), "a formal youtiao order opens")
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	session.call("begin_formal_order_serving", order_id)
	var focused_order := Dictionary(session.call("formal_order", order_id))
	_check(StringName(focused_order.get("state", &"")) in [&"active", &"serving"], "the pointer test focuses a currently active formal order")
	tray.focus_order(focused_order)
	await process_frame
	_check(station.auto_load_panel.visible and station.auto_load_visual.visible, "owned auto-load hardware is visible in the formal station")

	await _drag_control(station.dough_sources[0], station.machine_stage)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"loaded", "real pointer drag moves one dough portion into the physical basket")
	await _click_control(station.start_button)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"frying", "real start-button click begins the unchanged frying model")
	session.call("advance_f3_production", 12.05)
	station.refresh_from_session()
	await process_frame
	await _click_control(station.lift_button)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"draining", "real lift-button click enters draining")
	session.call("advance_f3_production", 2.05)
	station.refresh_from_session()
	await process_frame
	var collectible := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(StringName(collectible.get("state", &"")) == &"ready_to_collect" and station.output_source.visible and not station.output_source.disabled, "the drained output exposes an enabled physical drag source")
	_check(not tray.focused_order_id().is_empty() and tray.slots[0].visible, "the matching physical tray slot is focused and visible")
	await _hover_control(station.output_source)
	_check(root.gui_get_hovered_control() == station.output_source, "the GPU pointer resolves the modular output hit area above the basket art")
	await _hover_control(tray.slots[0])
	_check(root.gui_get_hovered_control() == tray.slots[0], "the GPU pointer resolves the requested tray slot as the drop target")
	var output_drag_events: Array[Dictionary] = []
	var tray_drop_events: Array[Dictionary] = []
	var tray_messages := PackedStringArray()
	station.output_source.drag_started.connect(func(source_ref: Dictionary): output_drag_events.append(source_ref.duplicate(true)))
	tray.slots[0].product_source_dropped.connect(func(source_ref: Dictionary, _item_index: int): tray_drop_events.append(source_ref.duplicate(true)))
	tray.status_message.connect(func(message: String): tray_messages.append(message))
	_check(StringName(station.output_source.source_ref().get("product_id", &"")) == &"product.youtiao.plain", "the physical output source carries the current product identity")
	await _drag_control(station.output_source, tray.slots[0])
	await process_frame
	_check(output_drag_events.size() == 1, "the output source starts exactly one real GUI drag")
	_check(tray_drop_events.size() == 1, "the requested tray slot receives exactly one product-source drop")
	var post_drop_state := StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &""))
	if post_drop_state != &"idle":
		print("YOUTIAO_TRAY_DROP_STATUS=%s" % " | ".join(tray_messages))
	_check(post_drop_state == &"idle", "real output drag removes the final portion and resets the low basket")
	var order := Dictionary(session.call("active_formal_order"))
	var item := Dictionary(Array(order.get("items", []))[0]) if not Array(order.get("items", [])).is_empty() else {}
	_check(Array(item.get("prepared_product_instance_ids", [])).size() == 1, "the physical tray receives the drained youtiao")

	await _click_control(station.dough_sources[0])
	await _click_control(station.auto_plus_button)
	await _click_control(station.auto_confirm_button)
	await process_frame
	var auto_loaded := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(StringName(auto_loaded.get("state", &"")) == &"loaded" and int(auto_loaded.get("quantity", 0)) == 2, "real recipe, plus, and confirm clicks run one two-serving automatic load")
	progression.set("unlocked_automation_ids", {AUTO_LOAD: true, AUTO_LIFT: true})
	station.refresh_from_session()
	await _click_control(station.start_button)
	session.call("advance_f3_production", 12.05)
	station.refresh_from_session()
	for _frame in 3:
		await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"draining", "the purchased auto-lift reaches the same draining state without a manual click")
	_check(station.auto_lift_visual.visible and station.raised_basket_visual.visible and station.oil_drips_visual.visible, "the auto-lift attachment, high basket, and drips agree with the business state")
	await _save_viewport(SCREENSHOT_1920, Vector2i(1920, 1080))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 4:
		await process_frame
	await _save_viewport(SCREENSHOT_1280, Vector2i(1280, 720))
	workstation.queue_free()
	await process_frame
	_finish()


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


func _hover_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame


func _drag_control(source: Control, target: Control) -> void:
	var from := source.get_global_rect().get_center()
	var to := target.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = from
	hover.global_position = from
	root.push_input(hover)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = from
	pressed.global_position = from
	root.push_input(pressed)
	await process_frame
	for ratio in [0.18, 0.42, 0.72, 1.0]:
		var position := from.lerp(to, ratio)
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		motion.relative = (to - from) * 0.24
		root.push_input(motion)
		await process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = to
	released.global_position = to
	root.push_input(released)
	await process_frame


func _save_viewport(path: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var saved := image.save_png(absolute)
	_check(saved == OK and image.get_size() == expected_size, "%s is captured from the real GPU viewport" % path)


func _clear_formal_orders(session: Node) -> void:
	for _round in range(8):
		var queued: Array = Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders"))
		if queued.is_empty():
			return
		for order_value in queued:
			var order_id := StringName(Dictionary(order_value).get("order_id", &""))
			if not order_id.is_empty():
				session.call("abandon_formal_order", order_id, &"pointer_test_setup")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("YOUTIAO_DIRECT_POINTER_SMOKE_PASS")
		print("YOUTIAO_FORMAL_SCREENSHOT_1920=%s" % ProjectSettings.globalize_path(SCREENSHOT_1920))
		print("YOUTIAO_FORMAL_SCREENSHOT_1280=%s" % ProjectSettings.globalize_path(SCREENSHOT_1280))
		quit(0)
		return
	printerr("YOUTIAO_DIRECT_POINTER_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
