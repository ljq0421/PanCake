extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/direct_youtiao_station.tscn")
const FLOW_SCREENSHOT := "res://tmp/validation/youtiao_station_tier1_flow_gpu_1920x1080.png"
const TIER_SCREENSHOT := "res://tmp/validation/youtiao_station_three_tiers_gpu_1280x720.png"
const RECIPE_ID := &"recipe.youtiao.plain"

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("YOUTIAO_STATION_OPERATIONS_GPU_PREVIEW_FAIL\nGPU preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var flow_canvas := _canvas(Vector2(1920, 1080), Color("efe0bd"))
	root.add_child(flow_canvas)
	var states: Array[StringName] = [&"idle", &"loaded", &"frying", &"ready_safe", &"overcooking", &"burnt", &"draining", &"ready_to_collect"]
	for index in range(states.size()):
		var station := STATION_SCENE.instantiate()
		station.position = Vector2(306 + (index % 4) * 326, 150 + (index / 4) * 380)
		flow_canvas.add_child(station)
		await process_frame
		var state := states[index]
		var cooking := 5.0 if state == &"frying" else 10.0 if state in [&"ready_safe", &"overcooking", &"burnt", &"draining", &"ready_to_collect"] else 0.0
		var quality := 72.0 if state == &"overcooking" else 0.0 if state == &"burnt" else 100.0
		station.apply_visual_snapshot(_snapshot(0, state, RECIPE_ID, 0 if state == &"idle" else 4, cooking, quality), _inventory())
	await _save_viewport(FLOW_SCREENSHOT, Vector2i(1920, 1080))
	flow_canvas.queue_free()
	await process_frame

	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 4:
		await process_frame
	# The project keeps a 1920×1080 logical canvas and scales it into the
	# 1280×720 window, so the preview canvas must retain those logical bounds.
	var tier_canvas := _canvas(Vector2(1920, 1080), Color("efe0bd"))
	root.add_child(tier_canvas)
	for tier in range(3):
		var station := STATION_SCENE.instantiate()
		station.position = Vector2(330 + tier * 477, 330)
		tier_canvas.add_child(station)
		await process_frame
		var tier_capacity: int = int([4, 6, 8][tier])
		station.apply_visual_snapshot(_snapshot(tier, &"ready_to_collect", RECIPE_ID, tier_capacity, [10.0, 8.0, 6.0][tier], 100.0), _inventory())
		station.prepared_slots[0].configure_count(tier_capacity, true, tier_capacity)
	await _save_viewport(TIER_SCREENSHOT, Vector2i(1280, 720))
	tier_canvas.queue_free()
	await process_frame
	_finish()


func _canvas(canvas_size: Vector2, color: Color) -> Control:
	var canvas := Control.new()
	canvas.size = canvas_size
	var background := ColorRect.new()
	background.color = color
	background.size = canvas_size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	return canvas


func _snapshot(tier: int, state: StringName, recipe_id: StringName, quantity: int, cooking: float, quality: float) -> Dictionary:
	return {
		"owned": true,
		"tier": tier,
		"capacity": [4, 6, 8][tier],
		"state": state,
		"recipe_id": recipe_id,
		"quantity": quantity,
		"cooking_elapsed_seconds": cooking,
		"completed_elapsed_seconds": 8.0 if state == &"overcooking" else 15.0 if state == &"burnt" else 0.0,
		"draining_elapsed_seconds": 1.0 if state == &"draining" else 2.0 if state == &"ready_to_collect" else 0.0,
		"quality": quality,
		"unlocked_recipe_ids": [RECIPE_ID],
		"unlocked_automation_ids": [],
		"owned_assist_ids": [],
	}


static func _inventory() -> Dictionary:
	return {
		"stock.youtiao.plain_dough": 8,
	}


func _save_viewport(path: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var saved := image.save_png(absolute)
	if saved != OK or image.get_size() != expected_size:
		failures.append("%s was not captured at %s" % [path, expected_size])


func _finish() -> void:
	if failures.is_empty():
		print("YOUTIAO_STATION_OPERATIONS_GPU_PREVIEW_PASS")
		print("YOUTIAO_FLOW_SCREENSHOT=%s" % ProjectSettings.globalize_path(FLOW_SCREENSHOT))
		print("YOUTIAO_TIER_SCREENSHOT=%s" % ProjectSettings.globalize_path(TIER_SCREENSHOT))
		quit(0)
		return
	printerr("YOUTIAO_STATION_OPERATIONS_GPU_PREVIEW_FAIL\n" + "\n".join(failures))
	quit(1)
