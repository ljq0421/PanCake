extends SceneTree

const SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const OUTPUT_1920 := "res://tmp/validation/cooking_progress_1920x1080.png"
const OUTPUT_1280 := "res://tmp/validation/cooking_progress_1280x720.png"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("COOKING_PROGRESS_GPU_PREVIEW_FAIL\nGPU preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var workstation := SCENE.instantiate() as FiveAreaWorkstation
	root.add_child(workstation)
	for _frame in 8:
		await process_frame

	var griddle := workstation.multi_griddle_station.units[0] as CompactGriddleUnit
	griddle.pancake_model.coverage.fill(1.0)
	griddle.pancake_model.doneness.fill(0.64)
	griddle.pancake_model.cooking_exposure_seconds.fill(0.0)
	griddle.state = CompactGriddleUnit.State.FIRST_SIDE
	griddle.first_side_seconds = 6.0
	griddle.call("_refresh_ui")

	var fryer := workstation.cartoon_youtiao_fryer as CartoonYoutiaoFryerToggle
	var left := _lane(&"recipe.youtiao.plain", &"overcooking", 10.0, 6.5, 94.0)
	var right := _lane(&"recipe.chicken.cutlet", &"ready_safe", 12.0, 2.0, 100.0)
	var machine := left.duplicate(true)
	machine.merge({"owned": true, "tier": 2, "capacity": 4, "quantity": 1, "occupied_slot_indices": [0], "lanes": {&"left": left, &"right": right}}, true)
	fryer._machine = machine
	fryer._chicken_unlocked = true
	fryer._workshop_preview = false
	fryer.call("_apply_snapshot")
	fryer.set_process(false)

	_check(griddle.heat_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE and fryer.youtiao_progress_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE and fryer.chicken_progress_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "cooking bars never intercept griddle or fryer input")
	_check(griddle.heat_status_label.get_global_rect().end.y < griddle.main_action.get_global_rect().position.y and griddle.main_action.get_global_rect().end.y < griddle.heat_bar.get_global_rect().position.y, "pancake status, flip action and progress track keep separate vertical rows")
	_check(fryer.youtiao_progress_label.get_global_rect().end.y < fryer.youtiao_progress_bar.get_global_rect().position.y and fryer.chicken_progress_label.get_global_rect().end.y < fryer.chicken_progress_bar.get_global_rect().position.y, "fryer status copy does not overlap either progress track")

	await _capture(Vector2i(1920, 1080), OUTPUT_1920)
	await _capture(Vector2i(1280, 720), OUTPUT_1280)
	workstation.queue_free()
	await process_frame
	if _failures.is_empty():
		print("COOKING_PROGRESS_GPU_PREVIEW_PASS")
		quit(0)
	else:
		printerr("COOKING_PROGRESS_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
		quit(1)


func _capture(resolution: Vector2i, output_path: String) -> void:
	DisplayServer.window_set_size(resolution)
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := root.get_texture().get_image()
	_check(image.get_size() == resolution and image.save_png(absolute) == OK, "captured cooking progress at %dx%d" % [resolution.x, resolution.y])


func _lane(recipe_id: StringName, state: StringName, cooking: float, completed: float, quality: float) -> Dictionary:
	return {"owned": true, "capacity": 4, "state": state, "recipe_id": recipe_id, "quantity": 1, "occupied_slot_indices": [0], "cooking_elapsed_seconds": cooking, "completed_elapsed_seconds": completed, "draining_elapsed_seconds": 0.0, "quality": quality}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
