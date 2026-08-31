extends SceneTree

const START_MENU_SCENE := preload("res://scenes/main/start_menu.tscn")
const CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/special_customer_reputation_ui_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/special_customer_reputation_ui_1280x720.png"},
]

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("SPECIAL_CUSTOMER_REPUTATION_UI_GPU_SMOKE_FAIL\nGPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "campaign session exists for reputation UI smoke")
	if session == null:
		_finish(PackedStringArray())
		return
	session.set("_active_save_path", "user://special_customer_reputation_ui_gpu_smoke.json")
	session.call("begin_new_game")
	var menu := START_MENU_SCENE.instantiate()
	root.add_child(menu)
	for _frame in 5:
		await process_frame
	menu.call("_refresh_save_state")
	menu.call("_open_chapter_select")
	for _frame in 3:
		await process_frame
	var overlay := menu.get_node("ChapterOverlay") as Control
	var panel := menu.get_node("ChapterOverlay/Panel") as Control
	var breakfast_card := menu.get_node("ChapterOverlay/Panel/Layout/Cards/BreakfastCard") as Control
	var status := menu.get_node("ChapterOverlay/Panel/Layout/Cards/BreakfastCard/Content/BreakfastShopStatus") as Label
	_check(overlay.visible and "早餐特殊顾客 0/3" in status.text and "20" in status.text, "shop selector visibly explains the first reputation milestone")
	var output_paths := PackedStringArray()
	for capture_value in CAPTURES:
		var capture := Dictionary(capture_value)
		var capture_size := Vector2i(capture.get("size", Vector2i.ZERO))
		DisplayServer.window_set_size(capture_size)
		for _frame in 5:
			await process_frame
		var visible_rect := root.get_visible_rect()
		_check(visible_rect.encloses(panel.get_global_rect()), "chapter panel stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		_check(breakfast_card.get_global_rect().encloses(status.get_global_rect()), "reputation milestone stays inside the breakfast card at %dx%d" % [capture_size.x, capture_size.y])
		var output_absolute := ProjectSettings.globalize_path(str(capture.get("path", "")))
		DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
		var image := root.get_texture().get_image()
		var save_error := image.save_png(output_absolute)
		_check(save_error == OK and image.get_size() == capture_size, "reputation UI captures at %dx%d" % [capture_size.x, capture_size.y])
		output_paths.append(output_absolute)
	menu.queue_free()
	await process_frame
	_finish(output_paths)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(output_paths: PackedStringArray) -> void:
	if failures.is_empty():
		print("SPECIAL_CUSTOMER_REPUTATION_UI_GPU_SMOKE_PASS")
		for output_path in output_paths:
			print("SPECIAL_CUSTOMER_REPUTATION_SCREENSHOT=%s" % output_path)
		quit(0)
		return
	printerr("SPECIAL_CUSTOMER_REPUTATION_UI_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
