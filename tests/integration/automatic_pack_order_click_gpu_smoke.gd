extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/automatic_pack_order_click_gpu.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("AUTOMATIC_PACK_ORDER_CLICK_GPU_SMOKE_FAIL\nGPU smoke must run without --headless")
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
	await _click_control(fold_unit.main_action)
	_check(
		fold_unit.fold_model.is_region_folded(PancakeFoldModel.REGION_LEFT)
		and fold_unit.fold_steps == 1
		and StringName(fold_unit.get("_automatic_fold_pending_region")) == PancakeFoldModel.REGION_RIGHT,
		"one real package click commits the first fold and arms automatic continuation",
	)
	await create_timer(1.25).timeout
	_check(
		fold_unit.fold_model.is_region_folded(PancakeFoldModel.REGION_RIGHT)
		and fold_unit.state == CompactGriddleUnit.State.READY,
		"the opposite side folds automatically and packages after one real pointer click",
	)
	_press_and_release_r()
	await process_frame
	_check(fold_unit.state == CompactGriddleUnit.State.IDLE, "real R key clears the single active griddle")

	var ready_unit: Node = multi.units[0]
	ready_unit.mark_ready({
		"product_instance_id": &"test.gpu.click_delivery",
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"heat_is_suitable": true,
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
	var delivery_source_center: Vector2 = ready_unit.package_visual.get_global_rect().get_center()
	var delivery_source_size: Vector2 = ready_unit.package_visual.get_global_rect().size
	var delivery_target_center: Vector2 = item_button.get_global_rect().get_center() if item_button != null else Vector2.ZERO
	if item_button != null:
		await _click_control(item_button)
	var delivery_ghosts := workstation.get_children().filter(func(child: Node) -> bool: return child.has_meta(&"spatial_flight_effect"))
	var delivery_ghost := delivery_ghosts[0] as TextureRect if not delivery_ghosts.is_empty() else null
	_check(delivery_ghost != null and delivery_ghost.size.is_equal_approx(delivery_source_size) and delivery_ghost.get_node_or_null("PancakePackageIngredientGrid") is PancakePackageIngredientGrid, "click delivery keeps the pancake at its source size and carries its ingredient grid")
	await create_timer(0.34).timeout
	await process_frame
	if delivery_ghost != null and is_instance_valid(delivery_ghost):
		var flight_center: Vector2 = delivery_ghost.get_global_rect().get_center()
		_check(
			flight_center.distance_to(delivery_source_center) > 20.0
			and flight_center.distance_to(delivery_target_center) > 8.0,
			"the delivered product passes through an intermediate arc instead of teleporting",
		)
	_check(StringName(Dictionary(session.call("formal_order", second_id)).get("state", &"")) == &"settled", "one real order-item click delivers the sole ready pancake to that exact customer")
	_check(StringName(Dictionary(session.call("formal_order", first_id)).get("state", &"")) in [&"active", &"serving"], "real click does not deliver to the previously focused customer")
	await create_timer(0.50).timeout
	_check(workstation.get_children().all(func(child: Node) -> bool: return not child.has_meta(&"spatial_flight_effect")), "the delivery handoff visual cleans itself up after arrival")

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
	unit.pancake_model.flip(false)
	unit.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	unit.state = CompactGriddleUnit.State.GARNISH
	unit.pancake_model.changed.emit()
	unit.call("_refresh_ui")


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	_move_at(position)
	await process_frame
	_press_at(position)
	await process_frame
	_release_at(position)
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
		print("AUTOMATIC_PACK_ORDER_CLICK_GPU_SMOKE_PASS")
		print("AUTOMATIC_PACK_ORDER_CLICK_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("AUTOMATIC_PACK_ORDER_CLICK_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
