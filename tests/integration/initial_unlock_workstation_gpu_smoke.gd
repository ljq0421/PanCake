extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/main/initial_unlock_preview.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/initial_unlock_workstation_gpu_1920x1080.png"

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
	var preview := PREVIEW_SCENE.instantiate()
	root.add_child(preview)
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var initial_image := root.get_texture().get_image()
	var save_error := initial_image.save_png(output_absolute)
	_check(save_error == OK and initial_image.get_size() == Vector2i(1920, 1080), "captured the untouched opening-day workstation in a real 1920x1080 GPU frame")
	var workstation := preview.get_node("Workstation")
	var ladle := workstation.get_node("SafeArea/LeftRack/LadleButton") as Button
	var scraper := workstation.get_node("SafeArea/LeftRack/ScraperButton") as Button
	var egg := workstation.get_node("SafeArea/IngredientRack/EggButton") as Button
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
	_drag(edge_global, inner_global)
	await process_frame
	var pointer_local: Vector2 = surface.get("pointer_local_position")
	_check(pointer_local.distance_to(Vector2(surface.size.x * 0.22, surface.size.y * 0.50)) < 3.0, "GPU pointer path reaches the scaled griddle edge and maps into local space")
	_drag(egg.get_global_rect().get_center(), surface.get_global_rect().get_center())
	await process_frame
	var ingredient_model: RefCounted = workstation.get("ingredient_model")
	_check(bool(ingredient_model.call("has_type", &"egg")), "real GUI drag places a direct ingredient on the scaled surface")
	_check(not (egg.get_node("Label") as CanvasItem).visible and not (egg.get_node("EmptyLabel") as CanvasItem).visible, "direct ingredient container keeps player-visible text labels hidden")
	_check(_tray_grid_is_four_by_three(workstation), "runtime tray geometry is a visible 4x3 grid")
	_check(_day_one_ingredients_align_with_trays(workstation), "day-one ingredient controls remain inside the first three physical trays")
	preview.queue_free()
	await process_frame
	_finish(output_absolute)


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


func _finish(output_absolute: String) -> void:
	if _failures.is_empty():
		print("INITIAL_UNLOCK_WORKSTATION_GPU_SMOKE_PASS")
		print("SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
