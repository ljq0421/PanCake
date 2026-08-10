extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const OUTPUT_DIR := "res://tmp/validation/soy_steamer_workbench"
const SOY_TEXTURES: Array[Texture2D] = [
	preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_v2.png"),
	preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_v2.png"),
	preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_3_v2.png"),
]
const STEAMER_TEXTURES: Array[Texture2D] = [
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_1_five_area_v2.png"),
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_2_five_area_v2.png"),
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_3_five_area_v2.png"),
]

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Workbench art preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var workstation := WORKSTATION_SCENE.instantiate()
	workstation.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(workstation)
	for _frame in range(5):
		await process_frame

	var soy_art := workstation.get_node("SafeArea/FiveAreaStationArtwork/FreshSoyMilkMachine") as TextureRect
	var steamer_panel := workstation.get_node("SafeArea/FiveAreaStationArtwork/SteamerPlaceholder") as Control
	var steamer_art := steamer_panel.get_node("SteamerArtwork") as TextureRect
	soy_art.visible = true
	steamer_panel.visible = true
	for optional_path in [
		"SafeArea/FiveAreaStationArtwork/FreshSoyMilkLock",
		"SafeArea/FiveAreaStationArtwork/SteamerLock",
		"SafeArea/FiveAreaStationClickLayers/FreshSoyMilkLockedClickLayer",
		"SafeArea/FiveAreaStationClickLayers/SteamerLockedClickLayer",
	]:
		var overlay := workstation.get_node_or_null(optional_path) as CanvasItem
		if overlay != null:
			overlay.visible = false

	_check(Vector2i(soy_art.size).x >= 280 and Vector2i(soy_art.size).y >= 280, "soy main-workbench slot remains approximately 280x280")
	_check(Vector2i(steamer_panel.size).x >= 280 and Vector2i(steamer_panel.size).y >= 250, "steamer main-workbench slot remains approximately 280x280")
	for tier in range(3):
		soy_art.texture = SOY_TEXTURES[tier]
		steamer_art.texture = STEAMER_TEXTURES[tier]
		await _capture_control(soy_art, "soy_tier_%d_workbench.png" % [tier + 1])
		await _capture_control(steamer_panel, "steamer_tier_%d_workbench.png" % [tier + 1])

	workstation.queue_free()
	await process_frame
	_finish()


func _capture_control(control: Control, file_name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var rect := control.get_global_rect()
	var capture_rect := Rect2i(Vector2i(rect.position.round()), Vector2i(rect.size.round()))
	var image := root.get_texture().get_image().get_region(capture_rect)
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	_check(image.save_png(output_path) == OK, "saved %s" % file_name)
	_check(image.get_size() == capture_rect.size, "%s keeps the real slot dimensions" % file_name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SOY_STEAMER_WORKBENCH_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("SOY_STEAMER_WORKBENCH_GPU_PREVIEW_FAIL\n" + "\n".join(failures))
	quit(1)
