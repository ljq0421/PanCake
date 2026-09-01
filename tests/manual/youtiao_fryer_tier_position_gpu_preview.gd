extends SceneTree

const SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const OUTPUT_DIR := "res://tmp/validation/youtiao_fryer_tier_positions"
const SINGLE_BASKET_OFFSET := Vector2(180.0, 0.0)

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("YOUTIAO_FRYER_TIER_POSITION_GPU_PREVIEW_FAIL\nGPU preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var workstation := SCENE.instantiate() as FiveAreaWorkstation
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	var fryer := workstation.cartoon_youtiao_fryer as CartoonYoutiaoFryerToggle
	var authored_position := fryer.position
	for tier in [0, 1, 2]:
		fryer._machine = {
			"owned": true,
			"tier": tier,
			"state": &"ready_to_collect",
			"capacity": 2 if tier < 2 else 4,
			"quantity": 2,
			"occupied_slot_indices": [0, 1],
		}
		fryer._chicken_unlocked = false
		fryer._workshop_preview = false
		fryer.call("_apply_snapshot")
		fryer.set_process(false)
		var expected_position := authored_position + SINGLE_BASKET_OFFSET if tier < 2 else authored_position
		_check(fryer.position.is_equal_approx(expected_position), "tier %d uses the expected fryer station position" % tier)
		for _frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var output_path := ProjectSettings.globalize_path("%s/tier_%d_1920x1080.png" % [OUTPUT_DIR, tier])
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		var image := root.get_texture().get_image()
		_check(image.get_size() == Vector2i(1920, 1080) and image.save_png(output_path) == OK, "tier %d captured a 1920x1080 workstation frame" % tier)
	workstation.queue_free()
	await process_frame
	if failures.is_empty():
		print("YOUTIAO_FRYER_TIER_POSITION_GPU_PREVIEW_PASS")
		quit(0)
	else:
		printerr("YOUTIAO_FRYER_TIER_POSITION_GPU_PREVIEW_FAIL\n" + "\n".join(failures))
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
