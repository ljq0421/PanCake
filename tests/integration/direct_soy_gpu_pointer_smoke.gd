extends SceneTree

const WORKSTATION := preload("res://scenes/gameplay/five_area_workstation.tscn")
const YELLOW := &"stock.fresh_soy_milk.yellow_bean"
const SCREENSHOT_1920 := "res://tmp/validation/direct_soy_v5_1920x1080.png"
const SCREENSHOT_1366 := "res://tmp/validation/direct_soy_v5_1366x768.png"
const SCREENSHOT_1280 := "res://tmp/validation/direct_soy_v5_1280x720.png"

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
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 100)
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.fresh_soy_milk.yellow_bean": true, &"recipe.fresh_soy_milk.black_bean": true, &"recipe.fresh_soy_milk.red_bean": true, &"recipe.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.fresh_soy_milk.yellow_bean": true, &"product.fresh_soy_milk.black_bean": true, &"product.fresh_soy_milk.red_bean": true, &"product.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_stock_ids", {&"stock.pancake.batter": true, &"stock.pancake.egg": true, &"stock.pancake.baocui": true, &"stock.pancake.scallion": true, &"stock.pancake.sauce.sweet_flour": true, &"stock.youtiao.plain_dough": true, YELLOW: true, &"stock.fresh_soy_milk.black_bean": true, &"stock.fresh_soy_milk.red_bean": true})
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory[str(YELLOW)] = 1
	session.call("save_inventory", inventory)

	var workstation := WORKSTATION.instantiate()
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	workstation.set_process(false)
	var soy_station := workstation.fresh_soy_station as DirectSoyStation
	var yellow_source := workstation.soy_full_slots[0] as Control
	var red_source := workstation.soy_full_slots[2] as Control
	_check(soy_station != null and yellow_source.visible and red_source.visible, "v5 soy station exposes three fixed bean sources")

	for resolution in [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		for _frame in 4:
			await process_frame
		await _hover_control(yellow_source)
		_check(root.gui_get_hovered_control() == yellow_source, "%dx%d pointer resolves the yellow-bean source" % [resolution.x, resolution.y])
		await _hover_control(red_source)
		_check(root.gui_get_hovered_control() == red_source, "%dx%d pointer resolves the red-bean source" % [resolution.x, resolution.y])
		await _save_viewport({1920: SCREENSHOT_1920, 1366: SCREENSHOT_1366, 1280: SCREENSHOT_1280}[resolution.x], resolution)

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 4:
		await process_frame
	await _hold_control(yellow_source, 0.55)
	_check(int(session.call("inventory_snapshot").get(str(YELLOW), 0)) == 2 and int(progression.get("coins")) == 98, "real stationary hold buys one yellow bean after the shared threshold")
	await _drag_control(yellow_source, soy_station)
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"loaded", "real pointer drag adds a bean to the hopper")
	await _click_control(soy_station.clear_hopper_button)
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"idle", "real clear-hopper click records waste and releases the machine")

	inventory = Dictionary(session.call("inventory_snapshot"))
	inventory[str(YELLOW)] = 4
	session.call("save_inventory", inventory)
	var order_service: RefCounted = session.call("order_service")
	order_service.call("abandon_all_open_orders", &"gpu_setup")
	var order_item := {"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "ingredient_ids": PackedStringArray(), "sauce_ids": PackedStringArray()}
	var first_open := Dictionary(session.call("open_formal_order", [order_item], {"patience_seconds": 30.0, "base_coins": 7}))
	var second_open := Dictionary(session.call("open_formal_order", [order_item], {"patience_seconds": 32.0, "base_coins": 7}))
	var first_id := StringName(Dictionary(first_open.get("order", {})).get("order_id", &""))
	var second_id := StringName(Dictionary(second_open.get("order", {})).get("order_id", &""))
	workstation.call("_refresh_customer_queue")
	await process_frame
	await _drag_control(yellow_source, soy_station)
	await _drag_control(yellow_source, soy_station)
	_check(int(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("quantity", 0)) == 2, "two real drags form a two-cup batch")
	await _click_control(soy_station.water_button)
	session.call("advance_f3_production", 1.0)
	soy_station.refresh_from_session()
	await _click_control(soy_station.water_button)
	await _click_control(soy_station.start_button)
	session.call("advance_f3_production", 5.0)
	soy_station.refresh_from_session()
	await process_frame
	_check(soy_station.machine_output.visible, "two-click green-zone water and production expose the first automatic cup")
	var first_slot := int(Dictionary(session.call("formal_order", first_id)).get("service_slot", 0)) + 1
	var first_target := workstation.get_node("SafeArea/ServiceCustomer%d/OrderPanel/ItemButton1" % first_slot) as Control
	_check(not (first_target as Button).disabled, "first customer item is an enabled drop target")
	await _drag_control(soy_station.machine_output, first_target)
	soy_station.refresh_from_session()
	await process_frame
	var second_slot := int(Dictionary(session.call("formal_order", second_id)).get("service_slot", 1)) + 1
	var second_target := workstation.get_node("SafeArea/ServiceCustomer%d/OrderPanel/ItemButton1" % second_slot) as Control
	_check(not (second_target as Button).disabled and soy_station.machine_output.visible, "second customer and second automatic cup remain available after the first delivery")
	await _drag_control(soy_station.machine_output, second_target)
	var first_state := StringName(Dictionary(session.call("formal_order", first_id)).get("state", &""))
	var second_state := StringName(Dictionary(session.call("formal_order", second_id)).get("state", &""))
	_check(first_state == &"settled" and second_state == &"settled", "two automatic cups can be dragged to two different customer orders (first=%s second=%s)" % [first_state, second_state])
	workstation.queue_free()
	_finish()


func _hover_control(control: Control) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame


func _click_control(control: Control) -> void:
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


func _hold_control(control: Control, seconds: float) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await create_timer(seconds).timeout
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
	return root.get_final_transform() * control.get_global_rect().get_center()


func _save_viewport(path: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := root.get_texture().get_image()
	_check(image.save_png(absolute) == OK and image.get_size() == expected_size, "%s GPU viewport capture" % path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DIRECT_SOY_GPU_POINTER_SMOKE_PASS")
		print("DIRECT_SOY_SCREENSHOT_1920=%s" % ProjectSettings.globalize_path(SCREENSHOT_1920))
		print("DIRECT_SOY_SCREENSHOT_1366=%s" % ProjectSettings.globalize_path(SCREENSHOT_1366))
		print("DIRECT_SOY_SCREENSHOT_1280=%s" % ProjectSettings.globalize_path(SCREENSHOT_1280))
		quit(0)
		return
	printerr("DIRECT_SOY_GPU_POINTER_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
