extends SceneTree

## Real-pointer acceptance for the serving-only soy station.  This intentionally
## runs with a GPU window: synthetic mouse events must reach the actual controls
## in the formal workstation rather than calling service methods directly.

const WORKSTATION := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("DIRECT_SOY_GPU_POINTER_SMOKE_FAIL\nGPU pointer smoke must run without --headless")
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
	_setup_soy_session(session)
	var workstation := WORKSTATION.instantiate()
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	var soy_station := workstation.fresh_soy_station as DirectSoyStation
	_check(soy_station != null, "formal workstation exposes the soy serving station")
	if soy_station == null:
		workstation.queue_free()
		_finish()
		return
	for resolution in [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		for _frame in 3:
			await process_frame
		await _hover_control(soy_station.cup_stack)
		_check(root.gui_get_hovered_control() == soy_station.cup_stack, "%dx%d pointer reaches the cup-stack control (actual: %s)" % [resolution.x, resolution.y, _hovered_path()])
		await _hover_control(soy_station.nozzle_button)
		_check(root.gui_get_hovered_control() == soy_station.nozzle_button, "%dx%d pointer reaches the dispensing nozzle (actual: %s)" % [resolution.x, resolution.y, _hovered_path()])
		await _hover_control(soy_station.sugar_jar)
		_check(root.gui_get_hovered_control() == soy_station.sugar_jar, "%dx%d pointer reaches the sugar jar" % [resolution.x, resolution.y])

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 3:
		await process_frame
	var order_id := await _open_normal_sugar_order(session, workstation)
	_check(not order_id.is_empty(), "soy delivery order opens in a visible customer slot")
	_check(int(soy_station.get("_cup_stack_count")) == 8, "cup stack starts with eight cups")
	await _click_control(soy_station.cup_stack)
	_check(int(soy_station.get("_cup_stack_count")) == 7, "taking a cup changes the stack to seven cups")
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("cup_state", &"")) == &"held_empty", "mouse click takes an empty cup")
	var nozzle_press := await _begin_hold_control(soy_station.nozzle_button)
	await create_timer(0.20).timeout
	_check(soy_station.dispense_effect.visible, "holding the nozzle shows the soy stream and cup-fill effect")
	_check(float(soy_station.dispense_effect.get("_fill_ratio")) > 0.10, "holding the nozzle raises the cup liquid level")
	await create_timer(0.76).timeout
	_check(float(soy_station.dispense_effect.get("_fill_ratio")) >= 0.999, "holding through the full mark fills the cup")
	_check(bool(soy_station.dispense_effect.get("_dispensing")), "the stream remains active while the pointer is still held")
	_check(soy_station.dispense_effect.is_overflowing(), "holding a full cup activates the overflow animation")
	await _release_hold_control(nozzle_press)
	_check(not bool(soy_station.dispense_effect.get("_dispensing")), "releasing the nozzle stops the live soy stream")
	_check(soy_station.dispense_effect.visible and is_equal_approx(float(soy_station.dispense_effect.get("_fill_ratio")), 1.0), "the transparent cup keeps the final fill level visible")
	var filled := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(StringName(filled.get("cup_state", &"")) == &"filled" and is_equal_approx(float(Dictionary(filled.get("cup", {})).get("fill_ratio", 0.0)), 1.0), "holding the nozzle for 0.8 seconds fills the cup")
	await _click_control(soy_station.sugar_jar)
	_check(int(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("cup", {}).get("sugar_servings", 0)) == 1, "mouse click adds normal sugar")
	_check(float(soy_station.dispense_effect.get("_sugar_animation_time")) >= 0.0, "adding sugar starts the visible jar-to-cup action")
	var target := workstation.call("_tutorial_delivery_target", session, &"area.fresh_soy_milk") as Control
	_check(target != null and not (target as Button).disabled, "soy order exposes an enabled drop target")
	if target != null:
		await _drag_control(soy_station.machine_output, target)
	var settled := Dictionary(session.call("formal_order", order_id))
	_check(StringName(settled.get("state", &"")) == &"settled", "dragging the sweetened cup completes delivery")
	soy_station.set("_cup_stack_count", 0)
	soy_station.refresh_from_session()
	await _hover_control(soy_station.cup_stack)
	_check(is_zero_approx(soy_station.cup_stack.self_modulate.a), "an empty cup stack is visually transparent")
	var restock_press := await _begin_hold_control(soy_station.cup_stack)
	await create_timer(0.60).timeout
	await _release_hold_control(restock_press)
	_check(int(soy_station.get("_cup_stack_count")) == 1, "one long press restocks exactly one cup")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_fill": true, &"automation.fresh_soy_milk.double_fill": true})
	# Progression changes are persisted before the production service is rebuilt,
	# matching the in-game upgrade path.  Otherwise this already-created machine
	# would still expose the prior single-outlet configuration.
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	soy_station.refresh_from_session()
	await _click_control(soy_station.cup_stack)
	_check(int(soy_station.get("_cup_stack_count")) == 0, "taking the first advanced-machine cup returns the stack to empty")
	_check(int(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("held_empty_cup_count", 0)) == 1, "first advanced-machine click places one cup at the first outlet")
	await _hover_control(soy_station.cup_stack)
	_check(root.gui_get_hovered_control() == soy_station.cup_stack, "the empty cup-stack restock slot remains pointer-accessible while the first advanced cup is placed (actual: %s)" % _hovered_path())
	var second_restock_press := await _begin_hold_control(soy_station.cup_stack)
	await create_timer(0.60).timeout
	await _release_hold_control(second_restock_press)
	_check(int(soy_station.get("_cup_stack_count")) == 1, "one additional hold restocks one second cup")
	await _click_control(soy_station.cup_stack)
	_check(int(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("held_empty_cup_count", 0)) == 2, "second advanced-machine click places a cup at the second outlet")
	_check(not soy_station.nozzle_button.disabled and not soy_station.second_nozzle_button.disabled and not soy_station.dual_nozzle_button.disabled, "both outlets and the separate dual-outlet control are actionable with two empty cups")
	await _click_control(soy_station.dual_nozzle_button)
	_check(soy_station.queued_cup_output.visible, "dual-outlet fill exposes a separately selectable second cup")
	await _click_control(soy_station.queued_cup_output)
	_check(int(soy_station.get("_selected_cup_index")) == 1, "clicking the second cup selects it for ingredients")
	await _click_control(soy_station.sugar_jar)
	var dual_snapshot := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	var primary_cup := Dictionary(dual_snapshot.get("cup", {}))
	var selected_queued_cup := Dictionary(Array(dual_snapshot.get("queued_cups", [])).front())
	_check(int(primary_cup.get("sugar_servings", 0)) == 0 and int(selected_queued_cup.get("sugar_servings", 0)) == 1, "adding sugar affects only the selected second cup")
	var waste_target := workstation.waste_area as StagedProductDropTarget
	_check(waste_target != null, "formal workstation exposes the shared waste basket")
	if waste_target != null:
		await _drag_control(soy_station.queued_cup_output, waste_target)
		await process_frame
		var after_discard := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
		_check(Array(after_discard.get("queued_cups", [])).is_empty() and not Dictionary(after_discard.get("cup", {})).is_empty(), "discarding the second soy cup removes only that cup")
		_check(not soy_station.queued_cup_output.visible, "a soy cup disappears from its outlet immediately after shared-basket disposal")
	workstation.queue_free()
	_finish()


func _setup_soy_session(session: Node) -> void:
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 100)
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
	progression.set("owned_assist_ids", {&"assist.fresh_soy_milk.sugar": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.fresh_soy_milk.yellow_bean": true})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	var order_service: RefCounted = session.call("order_service")
	order_service.call("abandon_all_open_orders", &"gpu_setup")


func _open_normal_sugar_order(session: Node, workstation: Node) -> StringName:
	# The workstation creates a default playable order during its ready phase.
	# Remove it so the test has one deterministic, visible soy order and one
	# unambiguous drop target.
	var order_service: RefCounted = session.call("order_service")
	order_service.call("abandon_all_open_orders", &"gpu_pointer_soy_order")
	var opened := Dictionary(session.call("open_formal_order", [{
		"area_id": &"area.fresh_soy_milk",
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"quantity": 1,
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"sugar_servings": 1,
	}], {"patience_seconds": 30.0, "base_coins": 7}))
	workstation.call("_refresh_customer_queue")
	await process_frame
	return StringName(Dictionary(opened.get("order", {})).get("order_id", &""))


func _hover_control(control: Control) -> void:
	# Window focus can swallow the first synthetic motion after a resolution
	# change.  Retry the same real-pointer hover before reporting a UI failure.
	for _attempt in range(3):
		var position := _pointer_position(control)
		Input.warp_mouse(position)
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		Input.parse_input_event(motion)
		await process_frame
		if root.gui_get_hovered_control() == control:
			return


func _click_control(control: Control) -> void:
	await _hover_control(control)
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await process_frame
	var released := pressed.duplicate()
	released.pressed = false
	root.push_input(released)
	await process_frame


func _begin_hold_control(control: Control) -> InputEventMouseButton:
	await _hover_control(control)
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await process_frame
	return pressed


func _release_hold_control(pressed: InputEventMouseButton) -> void:
	var released := pressed.duplicate()
	released.pressed = false
	root.push_input(released)
	await process_frame


func _drag_control(source: Control, target: Control) -> void:
	var from := _pointer_position(source)
	var to := _pointer_position(target)
	Input.warp_mouse(from)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = from
	pressed.global_position = from
	root.push_input(pressed)
	await process_frame
	for ratio in [0.2, 0.45, 0.72, 1.0]:
		var position := from.lerp(to, ratio)
		Input.warp_mouse(position)
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		motion.relative = (to - from) * 0.25
		Input.parse_input_event(motion)
		await process_frame
	var released := pressed.duplicate()
	released.pressed = false
	released.position = to
	released.global_position = to
	root.push_input(released)
	await process_frame


func _pointer_position(control: Control) -> Vector2:
	var local_position := control.size * 0.5
	if control is ProductDragSource:
		var source := control as ProductDragSource
		for region in source._alpha_hit_regions:
			var image := region.get("image") as Image
			var rect := region.get("rect", Rect2()) as Rect2
			if image == null or image.is_empty():
				continue
			var used_rect := image.get_used_rect()
			if used_rect.size.x <= 0 or used_rect.size.y <= 0:
				continue
			for pixel_y in range(used_rect.position.y, used_rect.end.y, 8):
				for pixel_x in range(used_rect.position.x, used_rect.end.x, 8):
					if image.get_pixel(pixel_x, pixel_y).a <= 0.05:
						continue
					local_position = rect.position + Vector2(
						(float(pixel_x) + 0.5) / image.get_width() * rect.size.x,
						(float(pixel_y) + 0.5) / image.get_height() * rect.size.y,
					)
					return root.get_final_transform() * (control.get_global_transform_with_canvas() * local_position)
	return root.get_final_transform() * (control.get_global_transform_with_canvas() * local_position)


func _hovered_path() -> String:
	var hovered := root.gui_get_hovered_control()
	return str(hovered.get_path()) if hovered != null else "none"


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DIRECT_SOY_GPU_POINTER_SMOKE_PASS")
		quit(0)
		return
	printerr("DIRECT_SOY_GPU_POINTER_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
