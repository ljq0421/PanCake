extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const RUNTIME_CAPTURE := "res://tmp/validation/pancake_holding_tray_single_plate_runtime_gpu.png"
const WORKSHOP_CAPTURE := "res://tmp/validation/pancake_holding_tray_single_plate_workshop_gpu.png"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("PANCAKE_HOLDING_TRAY_SINGLE_PLATE_GPU_SMOKE_FAIL\nGPU mode required")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists")
	if session == null:
		_finish(PackedStringArray())
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("owned_growth_ids", {&"growth.capacity.pancake_holding_tray.first_slot": true})
	for product_index in range(4):
		var stored := Dictionary(session.call("store_pancake_product", {
			"product_instance_id": StringName("gpu.tray.pancake.%d" % product_index),
			"product_id": &"product.pancake.custom",
			"ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.baocui"],
			"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
			"score": 90.0,
		}))
		_check(bool(stored.get("success", false)), "fixture stores pancake %d" % (product_index + 1))
	var station := WORKSTATION_SCENE.instantiate()
	root.add_child(station)
	for _frame in 8:
		await process_frame
	var tray := station.get_node("FiveAreaInfrastructure/PancakeHoldingTray") as TextureButton
	var visible_sources: Array[Control] = []
	for source_index in range(1, 5):
		var source := station.get_node("FiveAreaInfrastructure/PancakeHoldingTray/PancakeHoldingSource%02d" % source_index) as Control
		if source.visible:
			visible_sources.append(source)
	_check(tray.visible and tray.texture_normal != null and tray.texture_normal.resource_path.ends_with("orange_juice/yinpin-v1.png"), "runtime uses one requested tray texture")
	_check(visible_sources.size() == 4 and visible_sources.all(func(source): return tray.get_global_rect().encloses(source.get_global_rect())), "all four stored pancakes remain readable inside the single tray")
	var output_paths := PackedStringArray()
	output_paths.append(await _capture(RUNTIME_CAPTURE))
	station.call("_open_upgrade_workshop")
	for _frame in 6:
		await process_frame
	var workshop := station.get("_upgrade_workshop") as UpgradeWorkshopOverlay
	var workshop_preview := workshop.get_node("UpgradeProps/PancakeHoldingTrayPreview") as TextureRect if workshop != null else null
	_check(workshop != null and workshop.visible, "upgrade workshop opens")
	_check(workshop != null and workshop.get_node_or_null("UpgradeProps/WorkshopProp_growth_capacity_pancake_holding_tray_second_slot") == null, "workshop has no second tray purchase")
	_check(workshop_preview != null and workshop_preview.texture != null and workshop_preview.texture.resource_path.ends_with("orange_juice/yinpin-v1.png"), "workshop previews the same single tray")
	output_paths.append(await _capture(WORKSHOP_CAPTURE))
	station.queue_free()
	await process_frame
	_finish(output_paths)


func _capture(path: String) -> String:
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := root.get_texture().get_image()
	_check(image.save_png(absolute) == OK and image.get_size() == Vector2i(1920, 1080), "captured %s" % path)
	return absolute


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(output_paths: PackedStringArray) -> void:
	if _failures.is_empty():
		print("PANCAKE_HOLDING_TRAY_SINGLE_PLATE_GPU_SMOKE_PASS")
		for output_path in output_paths:
			print("PANCAKE_HOLDING_TRAY_SINGLE_PLATE_GPU_SCREENSHOT=%s" % output_path)
		quit(0)
		return
	printerr("PANCAKE_HOLDING_TRAY_SINGLE_PLATE_GPU_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
