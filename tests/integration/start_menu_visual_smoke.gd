extends SceneTree

const START_MENU_SCENE := preload("res://scenes/main/start_menu.tscn")
const GAME_SCENE := preload("res://scenes/main/main.tscn")


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
	menu.queue_free()
	await process_frame
	await process_frame

	var game_session := root.get_node_or_null("GameSession")
	if game_session != null and game_session.has_method("begin_new_game"):
		game_session.call("begin_new_game")
	var gameplay := GAME_SCENE.instantiate()
	root.add_child(gameplay)
	await process_frame
	await process_frame
	var gameplay_path := capture_directory.path_join("gameplay_ui_latest.png")
	if root.get_texture().get_image().save_png(gameplay_path) != OK:
		_fail("Failed to save gameplay UI capture")
		return
	gameplay.call("_set_paused", true)
	await process_frame
	await process_frame
	var pause_path := capture_directory.path_join("pause_overlay_latest.png")
	if root.get_texture().get_image().save_png(pause_path) != OK:
		_fail("Failed to save pause-overlay capture")
		return
	gameplay.call("_set_paused", false)

	print("START MENU VISUAL SMOKE PASS")
	print("Validation captures: %s, %s, %s, %s, %s" % [menu_path, settings_path, confirmation_path, gameplay_path, pause_path])
	gameplay.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
