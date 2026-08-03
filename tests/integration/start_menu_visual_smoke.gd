extends SceneTree

const START_MENU_SCENE := preload("res://scenes/main/start_menu.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := START_MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	await process_frame

	var capture_directory := ProjectSettings.globalize_path("res://tmp/validation")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	var menu_path := capture_directory.path_join("start_menu_latest.png")
	if root.get_texture().get_image().save_png(menu_path) != OK:
		_fail("Failed to save start-menu capture")
		return

	menu.call("_open_settings")
	await process_frame
	await process_frame
	var settings_path := capture_directory.path_join("start_menu_settings_latest.png")
	if root.get_texture().get_image().save_png(settings_path) != OK:
		_fail("Failed to save start-menu settings capture")
		return
	menu.call("_close_settings")
	menu.call("_request_new_game")
	await process_frame
	await process_frame
	var confirmation_path := capture_directory.path_join("start_menu_new_game_confirm_latest.png")
	if root.get_texture().get_image().save_png(confirmation_path) != OK:
		_fail("Failed to save new-game confirmation capture")
		return

	print("START MENU VISUAL SMOKE PASS")
	print("Validation captures: %s, %s, %s" % [menu_path, settings_path, confirmation_path])
	menu.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
