extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/youtiao_fryer_unlocked_gpu_1920x1080.png"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("YOUTIAO_FRYER_GPU_PREVIEW_FAIL\nGPU preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available for the youtiao artwork preview")
	if session == null:
		_finish("")
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0})
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	var controller := workstation.get_node("SafeArea/PancakeWorkstationInteractionController")
	controller.call("_refresh_formal_five_area_state")
	for _frame in 4:
		await process_frame
	var fryer := workstation.get_node("SafeArea/FiveAreaStationArtwork/YoutiaoFryer") as TextureRect
	var lock := workstation.get_node("SafeArea/FiveAreaStationArtwork/YoutiaoLock") as TextureRect
	_check(fryer.visible and not lock.visible, "the unlocked youtiao bay shows equipment instead of lock artwork")
	_check(fryer.texture != null and fryer.texture.resource_path.ends_with("youtiao_fryer_tier_1_five_area_v3.png"), "the GPU frame uses the simplified beginner fryer texture")
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output_absolute)
	_check(save_error == OK and image.get_size() == Vector2i(1920, 1080), "the unlocked youtiao artwork is captured in a real 1920x1080 GPU frame")
	workstation.queue_free()
	await process_frame
	_finish(output_absolute)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish(output_absolute: String) -> void:
	if _failures.is_empty():
		print("YOUTIAO_FRYER_GPU_PREVIEW_PASS")
		print("YOUTIAO_FRYER_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("YOUTIAO_FRYER_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
