extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/manual_fold_order_click_gpu.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("MANUAL_FOLD_ORDER_CLICK_GPU_SMOKE_FAIL\nGPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish("")
		return
	session.call("begin_new_game")
	_complete_initial_tutorial(session)
	_clear_orders(session)
	var item := {
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"heat_preference": &"golden",
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
	}
	var first := Dictionary(Dictionary(session.call("open_formal_order", [item.duplicate(true)], {"source": &"gpu_click_first", "patience_seconds": 120.0})).get("order", {}))
	var second := Dictionary(Dictionary(session.call("open_formal_order", [item.duplicate(true)], {"source": &"gpu_click_second", "patience_seconds": 120.0})).get("order", {}))
	var first_id := StringName(first.get("order_id", &""))
	var second_id := StringName(second.get("order_id", &""))

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 10:
		await process_frame
	var workstation: Node = game.get_node("Workstation")
	var multi: Node = workstation.multi_griddle_station
	multi.set_griddle_count(1)
	var fold_unit: Node = multi.units[0]
	_prepare_fold_surface(fold_unit, item)
	var surface_rect: Rect2 = fold_unit.pancake_surface.get_global_rect()
	await _drag(surface_rect.position + Vector2(24.0, surface_rect.size.y * 0.5), surface_rect.position + Vector2(224.0, surface_rect.size.y * 0.5))
	_check(fold_unit.fold_model.is_region_folded(PancakeFoldModel.REGION_LEFT) and fold_unit.fold_steps == 1, "real pointer drag commits the left fold")
	await _drag(surface_rect.position + Vector2(surface_rect.size.x - 24.0, surface_rect.size.y * 0.5), surface_rect.position + Vector2(54.0, surface_rect.size.y * 0.5))
	_check(fold_unit.fold_model.is_region_folded(PancakeFoldModel.REGION_RIGHT) and fold_unit.state == CompactGriddleUnit.State.READY, "real pointer drag commits the right fold and packages")
	_press_and_release_r()
	await process_frame
	_check(fold_unit.state == CompactGriddleUnit.State.IDLE, "real R key clears the single active griddle")

	var ready_unit: Node = multi.units[0]
	ready_unit.mark_ready({
		"product_instance_id": &"test.gpu.click_delivery",
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"heat_preference": &"golden",
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"score": 100.0,
		"feedback": "gpu click test",
		"status": &"available",
	})
	multi.call("_sync_snapshot_to_session")
	workstation.call("_on_customer_service_focus_requested", first_id)
	var target_slot := _service_slot_for_order(workstation, second_id)
	var item_button := target_slot.get_node("OrderPanel/ItemButton1") as Button if target_slot != null else null
	_check(item_button != null and item_button.visible and not item_button.disabled, "non-focused customer item has a real pointer target")
	if item_button != null:
		var click_position := item_button.get_global_rect().get_center()
		_move_at(click_position)
		_press_at(click_position)
		_release_at(click_position)
		await process_frame
	_check(StringName(Dictionary(session.call("formal_order", second_id)).get("state", &"")) == &"settled", "real item-icon click settles its own order without dragging")
	_check(StringName(Dictionary(session.call("formal_order", first_id)).get("state", &"")) in [&"active", &"serving"], "real click does not deliver to the previously focused customer")

	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var screenshot := root.get_texture().get_image()
	var save_error := screenshot.save_png(output_absolute)
	_check(save_error == OK and screenshot.get_size() == Vector2i(1920, 1080), "final GPU frame is captured")
	game.queue_free()
	await process_frame
	_finish(output_absolute)


func _prepare_fold_surface(unit: Node, order: Dictionary) -> void:
	unit.begin_order(order)
	unit.pancake_model.coverage.fill(1.0)
	unit.pancake_model.thickness.fill(0.55)
	unit.pancake_model.wetness.fill(0.18)
	unit.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	unit.state = CompactGriddleUnit.State.GARNISH
	unit.pancake_model.changed.emit()
	unit.call("_refresh_ui")


func _drag(from_position: Vector2, to_position: Vector2) -> void:
	_move_at(from_position)
	_press_at(from_position)
	_move_at(to_position, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_release_at(to_position)
	await process_frame


func _service_slot_for_order(workstation: Node, order_id: StringName) -> Control:
	for slot_index in 3:
		var slot := workstation.get_node("SafeArea/ServiceCustomer%d" % (slot_index + 1)) as Control
		if slot.visible and StringName(slot.get("_order_id")) == order_id:
			return slot
	return null


func _complete_initial_tutorial(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"")
	progression.set("tutorial_active_id", &"")
	var device_tiers := Dictionary(progression.get("device_tiers"))
	device_tiers[&"device.pancake_griddle"] = 2
	progression.set("device_tiers", device_tiers)
	session.call("_sync_progression_to_save")


func _clear_orders(session: Node) -> void:
	for order_value in Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders")):
		var order_id := StringName(Dictionary(order_value).get("order_id", &""))
		if not order_id.is_empty():
			session.call("abandon_formal_order", order_id, &"gpu_click_fixture")


func _move_at(position: Vector2, button_mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.button_mask = button_mask
	root.push_input(motion)


func _press_at(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	root.push_input(event)


func _release_at(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	event.global_position = position
	root.push_input(event)


func _press_and_release_r() -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_R
	pressed.keycode = KEY_R
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_R
	released.keycode = KEY_R
	released.pressed = false
	root.push_input(released)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(output_absolute: String) -> void:
	if failures.is_empty():
		print("MANUAL_FOLD_ORDER_CLICK_GPU_SMOKE_PASS")
		print("MANUAL_FOLD_ORDER_CLICK_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("MANUAL_FOLD_ORDER_CLICK_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
