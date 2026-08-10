extends SceneTree

const SOY_SCENE := preload("res://scenes/gameplay/fresh_soy_milk_station.tscn")
const OUTPUT_DIR := "res://tmp/validation/fresh_soy_milk_station"
const STATION_ORIGIN := Vector2(100, 100)
const STATION_SIZE := Vector2i(430, 270)
const RECIPES := [
	&"recipe.fresh_soy_milk.yellow_bean",
	&"recipe.fresh_soy_milk.black_bean",
	&"recipe.fresh_soy_milk.red_bean",
	&"recipe.fresh_soy_milk.multigrain",
]
const AUTO_RACK := &"automation.fresh_soy_milk.auto_cup_rack"

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fresh soy GPU preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var view := SOY_SCENE.instantiate()
	root.add_child(view)
	view.position = STATION_ORIGIN
	view.size = Vector2(STATION_SIZE)
	view.set_locked(false)
	view.set_interaction_enabled(true)
	for _frame in range(4):
		await process_frame

	view.apply_snapshot(_snapshot(0, &"idle"))
	await _capture("tier_1_idle.png")
	var load_center: Vector2 = view.load_button.get_global_rect().get_center()
	_move_at(load_center)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	_press_at(load_center)
	await process_frame
	_release_at(load_center)
	await create_timer(0.24).timeout
	_check(hovered == view.load_button, "real pointer reaches the load button")
	_check(bool(view.get("_animation_busy")), "real pointer starts open-and-load feedback")
	await _capture("tier_1_open_loading.png")
	await create_timer(0.45).timeout

	view.apply_snapshot(_snapshot(1, &"grinding", &"recipe.fresh_soy_milk.black_bean", 2))
	await create_timer(0.15).timeout
	await _capture("tier_2_grinding.png")
	view.apply_snapshot(_snapshot(1, &"ready_safe", &"recipe.fresh_soy_milk.red_bean", 2))
	await _capture("tier_2_ready_two_cups.png")

	var full_rack := [
		_rack_cup(RECIPES[0]), _rack_cup(RECIPES[1]),
		_rack_cup(RECIPES[2]), _rack_cup(RECIPES[3]),
	]
	view.apply_snapshot(_snapshot(2, &"blocked", RECIPES[3], 4, [AUTO_RACK], full_rack))
	await _capture("tier_3_blocked_four_cups.png")
	view.apply_snapshot(_snapshot(2, &"spoiled", RECIPES[0], 4, [AUTO_RACK], full_rack))
	await _capture("tier_3_spoiled.png")

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
	_check(image.get_size() == STATION_SIZE, "%s uses exact station size" % file_name)


func _snapshot(tier: int, state: StringName, recipe_id: StringName = &"", quantity: int = 0, automations: Array = [], rack: Array = [{}, {}, {}, {}]) -> Dictionary:
	return {
		"owned": true,
		"tier": tier,
		"capacity": [2, 2, 4][tier],
		"state": state,
		"recipe_id": recipe_id,
		"quantity": quantity,
		"quality": 0.0 if state == &"spoiled" else 100.0,
		"output_rack": rack,
		"unlocked_recipe_ids": RECIPES,
		"unlocked_automation_ids": automations,
	}


func _rack_cup(recipe_id: StringName) -> Dictionary:
	return {"recipe_id": recipe_id, "state": &"ready_safe", "quality": 100.0}


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
		print("FRESH_SOY_MILK_STATION_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("FRESH_SOY_MILK_STATION_GPU_PREVIEW_FAIL\n" + "\n".join(failures))
	quit(1)
