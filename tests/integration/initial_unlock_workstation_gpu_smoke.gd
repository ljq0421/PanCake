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
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var adapter := workstation.get_node("SafeArea/InitialUnlockAdapter")
	adapter.call("apply_progression_snapshot", {
		"coins": 20,
		"ingredient_stock": {"egg": 2, "baocui": 2, "ham_sausage": 0, "scallion": 2},
	})
	await process_frame
	await process_frame
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
	var egg_unit_seconds := float(adapter.call("refill_service").call("status", &"egg").unit_seconds)
	_check(is_equal_approx(egg_unit_seconds, 0.20), "real main-game egg refill uses the six-times-speed 0.20-second per-unit duration")
	var refill_service: RefCounted = adapter.call("refill_service")
	var egg_tray_center := egg.get_global_rect().get_center()
	_press_at(egg_tray_center)
	await process_frame
	var first_hold_started := await _wait_until(func() -> bool: return StringName(adapter.get("_active_refill_stock_id")) == &"egg", 0.50)
	_check(first_hold_started, "an unmoved real GUI press starts refill directly on the egg tray")
	var first_unit_completed := await _wait_until(func() -> bool: return int(stock_model.call("current", &"egg")) >= 2, 0.10 + egg_unit_seconds + 0.50)
	_release_at(egg_tray_center)
	await process_frame
	_check(first_unit_completed and int(stock_model.call("current", &"egg")) == 2, "continuous real-time hold adds exactly the first completed stock portion")

	_press_at(egg_tray_center)
	await process_frame
	var partial_hold_started := await _wait_until(func() -> bool: return StringName(adapter.get("_active_refill_stock_id")) == &"egg", 0.50)
	var partial_progress_reached := await _wait_until(
		func() -> bool: return float(refill_service.call("status", &"egg").progress_seconds) >= egg_unit_seconds * 0.30,
		egg_unit_seconds,
	)
	var outside_tray := egg_tray_center + Vector2(-180.0, 0.0)
	_move_at(outside_tray)
	await process_frame
	_release_at(outside_tray)
	await process_frame
	var saved_progress := float(refill_service.call("status", &"egg").progress_seconds)
	_check(partial_hold_started and partial_progress_reached and StringName(adapter.get("_active_refill_stock_id")) == &"" and int(stock_model.call("current", &"egg")) == 2 and saved_progress >= egg_unit_seconds * 0.30 and saved_progress < egg_unit_seconds, "real GUI release outside the tray still stops refill and keeps unfinished time internally")
	_press_at(egg_tray_center)
	await process_frame
	var resumed_hold_started := await _wait_until(func() -> bool: return StringName(adapter.get("_active_refill_stock_id")) == &"egg", 0.50)
	var resumed_unit_completed := await _wait_until(func() -> bool: return int(stock_model.call("current", &"egg")) >= 3, egg_unit_seconds + 0.50)
	_release_at(egg_tray_center)
	await process_frame
	_check(resumed_hold_started and resumed_unit_completed and int(stock_model.call("current", &"egg")) == 3, "a later real GUI hold resumes the saved partial portion")
	var progression: RefCounted = adapter.get("progression")
	_check(int(progression.get("coins")) == 18, "two completed real-time portions deduct exactly two unit costs")
	var egg_artwork := egg.get_node("Artwork") as TextureRect
	_check(egg_artwork.texture.resource_path.ends_with("egg_stock_3_v1.png"), "the pan itself shows the third stock image after refill")

	await _slow_drag(baocui.get_global_rect().get_center(), surface.get_global_rect().get_center() + Vector2(40.0, 20.0), 24)
	await process_frame
	_check(bool(ingredient_model.call("has_type", &"baocui")), "slow real GUI drag still reaches the established griddle placement path")
	_check(not (egg.get_node("Label") as CanvasItem).visible and not (egg.get_node("EmptyLabel") as CanvasItem).visible, "direct ingredient container keeps player-visible text labels hidden")
	var refill_help := str(egg.get_meta(&"refill_help_text", ""))
	_check(refill_help.contains("每份") and refill_help.contains("当前") and not refill_help.contains("%") and not refill_help.contains("进度") and egg.tooltip_text.is_empty(), "tray hover help uses the off-worktop instruction strip for price, time, and capacity without refill progress")
	_check(_tray_grid_is_four_by_three(workstation), "runtime tray geometry is a visible 4x3 grid")
	_check(_day_one_ingredients_align_with_trays(workstation), "day-one ingredient controls remain inside the first three physical trays")
	_move_at(egg_tray_center)
	await create_timer(0.25).timeout
	var instructions := workstation.get_node("SafeArea/BottomStrip/Instructions") as Label
	_check(instructions.text == refill_help, "real pointer hover displays refill help above the workstation")
	await RenderingServer.frame_post_draw
	var refill_output_absolute := ProjectSettings.globalize_path(REFILL_SCREENSHOT_PATH)
	var refill_image := root.get_texture().get_image()
	var refill_save_error := refill_image.save_png(refill_output_absolute)
	_check(refill_save_error == OK and refill_image.get_size() == Vector2i(1920, 1080), "captured the real main-game refill result in a 1920x1080 GPU frame")
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


func _tray_grid_is_four_by_three(workstation: Node) -> bool:
	var grid := workstation.get_node("SafeArea/ExpansionLayout/RightZone/IngredientTrayGrid") as GridContainer
	if grid.columns != 4 or grid.get_child_count() != 12:
		return false
	var first := grid.get_child(0) as Control
	var fourth := grid.get_child(3) as Control
	var fifth := grid.get_child(4) as Control
	return absf(first.position.y - fourth.position.y) < 1.0 and fifth.position.y > first.position.y + first.size.y


func _day_one_ingredients_align_with_trays(workstation: Node) -> bool:
	var grid := workstation.get_node("SafeArea/ExpansionLayout/RightZone/IngredientTrayGrid") as GridContainer
	var button_names := ["EggButton", "BaocuiButton", "ScallionButton"]
	for index in button_names.size():
		var tray := grid.get_child(index) as Control
		var ingredient := workstation.get_node("SafeArea/IngredientRack/%s" % button_names[index]) as Control
		if ingredient.get_global_rect().position.distance_to(tray.get_global_rect().position) > 1.0:
			return false
		if ingredient.get_global_rect().size.distance_to(tray.get_global_rect().size) > 1.0:
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
