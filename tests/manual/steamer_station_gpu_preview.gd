extends SceneTree

const STEAMER_SCENE := preload("res://scenes/gameplay/steamer_station.tscn")
const OUTPUT_DIR := "res://tmp/validation/steamer_station"
const STATION_ORIGIN := Vector2(100, 100)
const STATION_SIZE := Vector2i(430, 250)

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Steamer GPU preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var view := STEAMER_SCENE.instantiate()
	root.add_child(view)
	view.position = STATION_ORIGIN
	view.size = Vector2(STATION_SIZE)
	view.set_locked(false)
	view.set_interaction_enabled(true)
	for _frame in range(4):
		await process_frame
	var station_rect := Rect2(STATION_ORIGIN, Vector2(STATION_SIZE))
	for button: Button in view.layer_buttons:
		_check(station_rect.encloses(button.get_global_rect()), "all four layer status buttons stay inside the 430x250 station area")

	view.apply_snapshot(_snapshot(0, [_layer(&"empty")]))
	await _capture("tier_1_empty.png")
	var layer_button := view.layer_hit_buttons[0] as Button
	var button_center := layer_button.get_global_rect().get_center()
	_move_at(button_center)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	_press_at(button_center)
	await process_frame
	_release_at(button_center)
	await create_timer(0.34).timeout
	_check(hovered == layer_button, "real pointer reaches the first basket's direct hit region")
	_check(bool(view.get("_animation_busy")), "real pointer starts the open-load-close presentation")
	await _capture("tier_1_open_loading.png")
	await create_timer(0.60).timeout

	view.apply_snapshot(_snapshot(1, [
		_layer(&"loaded", &"recipe.steamer.mantou"),
		_layer(&"steaming", &"recipe.steamer.vegetable_bun", 100.0, 4.0, 10.0),
	]))
	await _capture("tier_2_loaded_steaming.png")

	view.apply_snapshot(_snapshot(2, [
		_layer(&"ready_safe", &"recipe.steamer.mantou", 100.0, 8.0, 8.0),
		_layer(&"overcooking", &"recipe.steamer.vegetable_bun", 62.0, 8.0, 8.0),
		_layer(&"spoiled", &"recipe.steamer.meat_bun", 0.0, 8.0, 8.0),
		_layer(&"empty"),
	]))
	await _capture("tier_3_ready_overcooked_spoiled_empty.png")

	var ready_button := view.layer_hit_buttons[0] as Button
	var ready_center := ready_button.get_global_rect().get_center()
	_move_at(ready_center)
	await process_frame
	_press_at(ready_center)
	await process_frame
	_release_at(ready_center)
	await create_timer(0.32).timeout
	_check(bool(view.get("_animation_busy")), "real pointer starts the mature-food collection presentation")
	await _capture("tier_3_open_collecting.png")
	await create_timer(0.55).timeout

	view.queue_free()
	await process_frame
	_finish()


func _capture(file_name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var full_frame := root.get_texture().get_image()
	var image := full_frame.get_region(Rect2i(Vector2i(STATION_ORIGIN), STATION_SIZE))
	var error := image.save_png(output_path)
	_check(error == OK, "saved GPU screenshot %s" % file_name)
	_check(image.get_size() == STATION_SIZE, "%s uses the exact station size" % file_name)


func _snapshot(tier: int, layers: Array) -> Dictionary:
	return {
		"owned": true,
		"tier": tier,
		"layer_capacity": [1, 2, 4][tier],
		"layers": layers,
		"unlocked_recipe_ids": [&"recipe.steamer.mantou", &"recipe.steamer.vegetable_bun", &"recipe.steamer.meat_bun"],
	}


func _layer(state: StringName, recipe_id: StringName = &"", quality: float = 100.0, elapsed: float = 0.0, duration: float = 8.0) -> Dictionary:
	return {
		"state": state,
		"recipe_id": recipe_id,
		"quantity": 0 if state in [&"empty", &"locked"] else 1,
		"quality": quality,
		"elapsed_seconds": elapsed,
		"duration_seconds": duration,
		"completed_elapsed_seconds": 0.0,
	}


func _move_at(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _press_at(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)


func _release_at(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("STEAMER_STATION_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("STEAMER_STATION_GPU_PREVIEW_FAIL\n" + "\n".join(failures))
	quit(1)
