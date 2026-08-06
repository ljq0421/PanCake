extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/initial_unlock_workstation_gpu_1920x1080.png"
const REFILL_SCREENSHOT_PATH := "res://tmp/validation/workstation_hold_refill_gpu_1920x1080.png"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null:
		game_session.call("begin_new_game")
		game_session.call("credit_coins", 20)
		var initial_inventory: Dictionary = game_session.call("inventory_snapshot")
		initial_inventory["stock.pancake.egg"] = 2
		initial_inventory["stock.pancake.baocui"] = 2
		initial_inventory["stock.pancake.scallion"] = 2
		game_session.call("save_inventory", initial_inventory)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var controller := workstation.get_node("SafeArea/PancakeWorkstationInteractionController")
	await process_frame
	await process_frame
	var locked_click_layers := workstation.get_node("SafeArea/FiveAreaStationClickLayers") as Control
	for click_layer_name in [&"FreshSoyMilkLockedClickLayer", &"YoutiaoLockedClickLayer", &"PackagedDrinkLockedClickLayer", &"SteamerLockedClickLayer"]:
		var click_layer := locked_click_layers.get_node(NodePath(str(click_layer_name))) as Button
		_click_control(click_layer)
		await process_frame
		_check(not str(click_layer.get_meta(&"unlock_condition", "")).is_empty(), "real pointer click reaches %s and preserves its explicit lock condition" % click_layer_name)
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var initial_image := root.get_texture().get_image()
	var save_error := initial_image.save_png(output_absolute)
	_check(save_error == OK and initial_image.get_size() == Vector2i(1920, 1080), "captured the untouched opening-day workstation in a real 1920x1080 GPU frame")
	var ladle := workstation.get_node("SafeArea/LeftRack/LadleButton") as Button
	var scraper := workstation.get_node("SafeArea/LeftRack/ScraperButton") as Button
	var egg := workstation.get_node("SafeArea/IngredientRack/EggButton") as Button
	var baocui := workstation.get_node("SafeArea/IngredientRack/BaocuiButton") as Button
	var surface := workstation.get_node("SafeArea/PanBase/PancakeSurface") as Control
	var outside_pan_press := InputEventMouseButton.new()
	outside_pan_press.button_index = MOUSE_BUTTON_LEFT
	outside_pan_press.pressed = true
	outside_pan_press.position = Vector2(surface.size.x * 0.05, surface.size.y * 0.05)
	surface.call("_gui_input", outside_pan_press)
	_check(not bool(surface.get("pointer_pressed")), "the interactive pancake surface rejects a local click outside the elliptical cooking face")
	_click_control(ladle)
	await process_frame
	_click_at(surface.get_global_rect().get_center())
	await process_frame
	_check(bool(workstation.get("pour_used")), "real GUI click pours batter through the scaled surface")
	_click_control(scraper)
	await process_frame
	var edge_global := surface.global_position + Vector2(surface.size.x * 0.10, surface.size.y * 0.50)
	var inner_global := surface.global_position + Vector2(surface.size.x * 0.22, surface.size.y * 0.50)
	await _slow_drag(edge_global, inner_global, 18)
	await process_frame
	var pointer_local: Vector2 = surface.get("pointer_local_position")
	_check(pointer_local.distance_to(Vector2(surface.size.x * 0.22, surface.size.y * 0.50)) < 3.0, "GPU pointer path reaches the scaled griddle edge and maps into local space")
	_drag(egg.get_global_rect().get_center(), surface.get_global_rect().get_center())
	await process_frame
	var ingredient_model: RefCounted = workstation.get("ingredient_model")
	_check(bool(ingredient_model.call("has_type", &"egg")), "real GUI drag places a direct ingredient on the scaled surface")
	var stock_model: RefCounted = workstation.get("ingredient_stock_model")
	_check(int(stock_model.call("current", &"egg")) == 1, "short real GUI drag consumes exactly one visible egg portion")

	_check(bool(egg.get_meta(&"refill_enabled", false)), "the real main-game egg tray supports direct hold refill")
	_check(is_equal_approx(float(egg.get("hold_threshold_seconds")), 0.1), "the real main-game egg tray uses the 0.1-second hold threshold")
	_check(workstation.get_node_or_null("SafeArea/ExpansionLayout/RightZone/RefillDrawer") == null, "the real main-game workstation has no refill drawer")
	var egg_stock := &"stock.pancake.egg"
	var egg_unit_seconds := float(controller.get("_restock").call("status", egg_stock).unit_seconds)
	_check(is_equal_approx(egg_unit_seconds, 0.20), "real main-game egg refill uses the six-times-speed 0.20-second per-unit duration")
	var refill_service: RefCounted = controller.get("_restock")
	var egg_tray_center := egg.get_global_rect().get_center()
	_press_at(egg_tray_center)
	await process_frame
	var first_hold_started := await _wait_until(func() -> bool: return StringName(controller.get("_active_refill_stock_id")) == egg_stock, 0.50)
	_check(first_hold_started, "an unmoved real GUI press starts refill directly on the egg tray")
	var first_unit_completed := await _wait_until(func() -> bool: return int(stock_model.call("current", &"egg")) >= 2, 0.10 + egg_unit_seconds + 0.50)
	_release_at(egg_tray_center)
	await process_frame
	_check(first_unit_completed and int(stock_model.call("current", &"egg")) == 2, "continuous real-time hold adds exactly the first completed stock portion")

	_press_at(egg_tray_center)
	await process_frame
	var partial_hold_started := await _wait_until(func() -> bool: return StringName(controller.get("_active_refill_stock_id")) == egg_stock, 0.50)
	var partial_progress_reached := await _wait_until(
		func() -> bool: return float(refill_service.call("status", egg_stock).progress_seconds) >= egg_unit_seconds * 0.30,
		egg_unit_seconds,
	)
	var outside_tray := egg_tray_center + Vector2(-180.0, 0.0)
	_move_at(outside_tray)
	await process_frame
	_release_at(outside_tray)
	await process_frame
	var saved_progress := float(refill_service.call("status", egg_stock).progress_seconds)
	_check(partial_hold_started and partial_progress_reached and StringName(controller.get("_active_refill_stock_id")) == &"" and int(stock_model.call("current", &"egg")) == 2 and saved_progress >= egg_unit_seconds * 0.30 and saved_progress < egg_unit_seconds, "real GUI release outside the tray still stops refill and keeps unfinished time internally")
	_press_at(egg_tray_center)
	await process_frame
	var resumed_hold_started := await _wait_until(func() -> bool: return StringName(controller.get("_active_refill_stock_id")) == egg_stock, 0.50)
	var resumed_unit_completed := await _wait_until(func() -> bool: return int(stock_model.call("current", &"egg")) >= 3, egg_unit_seconds + 0.50)
	_release_at(egg_tray_center)
	await process_frame
	_check(resumed_hold_started and resumed_unit_completed and int(stock_model.call("current", &"egg")) == 3, "a later real GUI hold resumes the saved partial portion")
	var progression: Dictionary = game_session.call("five_area_progression_snapshot")
	_check(int(progression.get("coins", 0)) == 18, "two completed real-time portions deduct exactly two formal coins")
	var egg_artwork := egg.get_node("Artwork") as TextureRect
	_check(egg_artwork.texture != null and egg_artwork.texture.resource_path.ends_with("egg_stock_3_v1.png"), "the clickable egg well updates to the third real stock artwork after refill")

	await _slow_drag(baocui.get_global_rect().get_center(), surface.get_global_rect().get_center() + Vector2(40.0, 20.0), 24)
	await process_frame
	_check(bool(ingredient_model.call("has_type", &"baocui")), "slow real GUI drag still reaches the established griddle placement path")
	_check(not (egg.get_node("Label") as CanvasItem).visible and not (egg.get_node("EmptyLabel") as CanvasItem).visible, "direct ingredient container keeps player-visible text labels hidden")
	var refill_help := str(egg.get_meta(&"refill_help_text", ""))
	_check(refill_help.contains("每份") and refill_help.contains("当前") and not refill_help.contains("%") and not refill_help.contains("进度") and egg.tooltip_text.is_empty(), "tray hover help uses the off-worktop instruction strip for price, time, and capacity without refill progress")
	_check(_material_rail_has_eighteen_positions(workstation), "runtime material rail has exactly one fixed row of 18 wells")
	_check(_opening_day_material_controls_align(workstation), "opening-day controls occupy Slots07-Slot09")
	_move_at(egg_tray_center)
	await create_timer(0.25).timeout
	var instructions := workstation.get_node("SafeArea/BottomStrip/Instructions") as Label
	_check(instructions.text == refill_help, "real pointer hover displays refill help above the workstation")
	await RenderingServer.frame_post_draw
	var refill_output_absolute := ProjectSettings.globalize_path(REFILL_SCREENSHOT_PATH)
	var refill_image := root.get_texture().get_image()
	var refill_save_error := refill_image.save_png(refill_output_absolute)
	_check(refill_save_error == OK and refill_image.get_size() == Vector2i(1920, 1080), "captured the real main-game refill result in a 1920x1080 GPU frame")
	var session_progression: RefCounted = game_session.call("progression_service")
	var owned_growth: Dictionary = Dictionary(session_progression.get("owned_growth_ids")).duplicate(true)
	owned_growth[&"growth.capacity.pancake_holding_tray.two_slots"] = true
	session_progression.set("owned_growth_ids", owned_growth)
	var active_formal_order: Dictionary = game_session.call("active_formal_order")
	var active_item: Dictionary = Dictionary(Array(active_formal_order.get("items", []))[0])
	var tray_product := {
		"product_instance_id": &"gpu.route.pancake.1",
		"product_id": active_item.get("product_id", &"product.pancake.custom"),
		"heat_preference": active_item.get("heat_preference", &""),
		"ingredient_ids": Array(active_item.get("ingredient_ids", [])),
		"sauce_ids": Array(active_item.get("sauce_ids", [])),
		"score": 88.0,
	}
	var stored_for_route: Dictionary = game_session.call("store_pancake_product", tray_product)
	workstation.call("reset_pancake")
	workstation.call("_refresh_pancake_holding_tray")
	var holding_slot := workstation.get_node("SafeArea/PancakeHoldingTray/PancakeHoldingSlot01") as Button
	_check(bool(stored_for_route.get("success", false)) and holding_slot.visible and not holding_slot.disabled, "formal tray displays a stored pancake for the active formal order")
	_click_control(holding_slot)
	await process_frame
	_check(game_session.call("active_formal_order").is_empty() and Dictionary(game_session.call("pancake_holding_tray_snapshot")).get("slots", [])[0].is_empty(), "real tray click routes the product into and settles the active formal order")
	game.queue_free()
	await process_frame
	_finish(output_absolute, refill_output_absolute)


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var started_msec := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started_msec) / 1000.0 < timeout_seconds:
		if bool(condition.call()):
			return true
		await process_frame
	return bool(condition.call())


func _click_control(control: Control) -> void:
	_click_at(control.get_global_rect().get_center())


func _click_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)


func _press_at(position: Vector2) -> void:
	_move_at(position)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)


func _move_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)


func _release_at(position: Vector2) -> void:
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)


func _drag(from: Vector2, to: Vector2) -> void:
	var move_start := InputEventMouseMotion.new()
	move_start.position = from
	move_start.global_position = from
	root.push_input(move_start)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = from
	pressed.global_position = from
	root.push_input(pressed)
	for index in 9:
		var ratio := float(index + 1) / 9.0
		var point := from.lerp(to, ratio)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = to
	released.global_position = to
	root.push_input(released)


func _slow_drag(from: Vector2, to: Vector2, frames: int) -> void:
	var move_start := InputEventMouseMotion.new()
	move_start.position = from
	move_start.global_position = from
	root.push_input(move_start)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = from
	pressed.global_position = from
	root.push_input(pressed)
	await process_frame
	for index in frames:
		var ratio := float(index + 1) / float(frames)
		var point := from.lerp(to, ratio)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion)
		await process_frame
	_release_at(to)


func _material_rail_has_eighteen_positions(workstation: Node) -> bool:
	var dock := workstation.get_node_or_null("SafeArea/MaterialDock") as Control
	if dock == null or dock.get_child_count() != 18 or int(dock.get_meta(&"slot_count", 0)) != 18:
		return false
	for index in 18:
		var slot := dock.get_node_or_null("Slot%02d" % (index + 1)) as Control
		if slot == null or int(slot.get_meta(&"slot_index", 0)) != index + 1:
			return false
	return true


func _opening_day_material_controls_align(workstation: Node) -> bool:
	var rack := workstation.get_node_or_null("SafeArea/IngredientRack") as Control
	if rack == null or rack.position.distance_to(Vector2(648.0, 925.0)) > 1.0 or rack.size.distance_to(Vector2(305.0, 120.0)) > 1.0:
		return false
	var expected_positions := {
		"EggButton": Vector2(6.0, 0.0),
		"BaocuiButton": Vector2(111.0, 0.0),
		"ScallionButton": Vector2(216.0, 0.0),
	}
	for button_name in expected_positions:
		var ingredient := workstation.get_node_or_null("SafeArea/IngredientRack/%s" % button_name) as Control
		if ingredient == null or ingredient.position.distance_to(expected_positions[button_name]) > 1.0 or ingredient.size.distance_to(Vector2(89.0, 120.0)) > 1.0:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish(output_absolute: String, refill_output_absolute: String) -> void:
	if _failures.is_empty():
		print("INITIAL_UNLOCK_WORKSTATION_GPU_SMOKE_PASS")
		print("INITIAL_SCREENSHOT=%s" % output_absolute)
		print("REFILL_SCREENSHOT=%s" % refill_output_absolute)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
