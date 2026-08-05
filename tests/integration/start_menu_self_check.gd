extends SceneTree

const START_MENU_SCENE := preload("res://scenes/main/start_menu.tscn")
const GAME_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return

	var previous_settings: Dictionary = session.get_settings()
	var menu := START_MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	var background := menu.get_node("Background") as TextureRect
	var continue_button := menu.get_node("Content/Layout/MenuPanel/Menu/ContinueButton") as Button
	var new_game_button := menu.get_node("Content/Layout/MenuPanel/Menu/NewGameButton") as Button
	var settings_button := menu.get_node("Content/Layout/MenuPanel/Menu/SettingsButton") as Button
	var quit_button := menu.get_node("Content/Layout/MenuPanel/Menu/QuitButton") as Button
	_check(background.texture != null and background.texture.resource_path == "res://resources/art/ui/start_menu/start_menu_background_morning_mobile_cart_v1.png", "start menu uses the morning mobile-cart background")
	_check(background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "background covers wider and taller aspect ratios")
	_check(continue_button.text == "继续游戏" and new_game_button.text == "新游戏", "primary start actions are present")
	_check(settings_button.text == "设置" and quit_button.text == "退出游戏", "settings and desktop quit actions are present")
	_check(continue_button.disabled == not session.has_save(), "continue availability mirrors persistent session state")

	session.begin_new_game()
	menu.call("_refresh_save_state")
	_check(session.has_save() and not continue_button.disabled, "new game creates a resumable session")
	_check("已完成 0 单" in session.resume_summary(), "new session summary is player-readable")

	menu.call("_open_settings")
	var settings_overlay := menu.get_node("SettingsOverlay") as Control
	_check(settings_overlay.visible, "settings opens as a modal overlay")
	var master_slider := menu.get_node("SettingsOverlay/Center/Dialog/Rows/MasterRow/MasterSlider") as HSlider
	var sfx_slider := menu.get_node("SettingsOverlay/Center/Dialog/Rows/SfxRow/SfxSlider") as HSlider
	var fullscreen_check := menu.get_node("SettingsOverlay/Center/Dialog/Rows/FullscreenCheck") as CheckButton
	master_slider.value = 41.0
	sfx_slider.value = 73.0
	fullscreen_check.button_pressed = false
	menu.call("_save_settings")
	var changed_settings: Dictionary = session.get_settings()
	_check(is_equal_approx(float(changed_settings.master_volume), 41.0), "master volume persists from settings")
	_check(is_equal_approx(float(changed_settings.sfx_volume), 73.0), "SFX volume persists from settings")
	_check(AudioServer.get_bus_index(&"SFX") >= 0, "dedicated SFX audio bus is configured")

	menu.call("_request_new_game")
	_check((menu.get_node("NewGameOverlay") as Control).visible, "existing progress requires new-game confirmation")
	menu.call("_close_new_game_confirmation")
	_check(not (menu.get_node("NewGameOverlay") as Control).visible, "new-game confirmation can be cancelled")

	menu.queue_free()
	await process_frame
	await process_frame

	var gameplay := GAME_SCENE.instantiate()
	root.add_child(gameplay)
	await process_frame
	await process_frame
	gameplay.call("_set_paused", true)
	var pause_panel := gameplay.get_node("PausePanel") as Control
	var workstation := gameplay.get_node("Workstation") as Control
	_check(paused and pause_panel.visible, "gameplay pause exposes navigation controls")
	_check(
		pause_panel.z_index > _maximum_effective_z_index(workstation),
		"pause overlay renders above every workstation surface"
	)
	_check(gameplay.has_node("PausePanel/Content/ResumeButton"), "pause overlay provides continue game")
	_check(gameplay.has_node("PausePanel/Content/EndBusinessButton"), "pause overlay provides end business and daily bill entry")
	_check(gameplay.has_node("PausePanel/Content/MainMenuButton"), "pause overlay provides return to start page")
	gameplay.call("_set_paused", false)
	_check(not paused and not (gameplay.get_node("PausePanel") as Control).visible, "resume closes the pause overlay")
	gameplay.queue_free()
	await process_frame
	await process_frame

	session.save_settings(
		float(previous_settings.master_volume),
		float(previous_settings.sfx_volume),
		bool(previous_settings.fullscreen)
	)
	_finish()


func _maximum_effective_z_index(item: CanvasItem, parent_z := 0) -> int:
	var effective_z := item.z_index + parent_z if item.z_as_relative else item.z_index
	var maximum := effective_z
	for child in item.get_children():
		if child is CanvasItem:
			maximum = maxi(maximum, _maximum_effective_z_index(child as CanvasItem, effective_z))
	return maximum


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("START MENU SELF-CHECK PASS")
		quit(0)
	else:
		print("START MENU SELF-CHECK FAIL (%d)" % _failures.size())
		quit(1)
