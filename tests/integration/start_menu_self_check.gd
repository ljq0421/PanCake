extends SceneTree

const START_MENU_SCENE := preload("res://scenes/main/start_menu.tscn")

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
	var shops_button := menu.get_node("Content/Layout/MenuPanel/Menu/ShopsButton") as Button
	var settings_button := menu.get_node("Content/Layout/MenuPanel/Menu/SettingsButton") as Button
	var quit_button := menu.get_node("Content/Layout/MenuPanel/Menu/QuitButton") as Button
	var loading_overlay := menu.get_node("LoadingOverlay") as Control
	var loading_progress := menu.get_node("LoadingOverlay/Center/Dialog/Rows/LoadingProgress") as ProgressBar
	_check(background.texture != null and background.texture.resource_path == "res://resources/art/ui/start_menu/start_menu_background_morning_mobile_cart_v4_bold_chinese.png", "start menu uses the current Chinese-style morning mobile-cart background")
	_check(background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "background covers wider and taller aspect ratios")
	_check(continue_button.text == "继续游戏" and new_game_button.text == "新游戏" and shops_button.text == "选择铺子", "primary start actions are present")
	_check(settings_button.text == "设置" and quit_button.text == "退出游戏", "settings and desktop quit actions are present")
	_check(continue_button.disabled == not session.has_save(), "continue availability mirrors persistent session state")
	_check(not loading_overlay.visible and is_zero_approx(loading_progress.value), "threaded loading overlay starts hidden and empty")

	session.begin_new_game()
	menu.call("_refresh_save_state")
	_check(session.has_save() and not continue_button.disabled, "new game creates a resumable session")
	menu.call("_open_chapter_select")
	var chapter_overlay := menu.get_node("ChapterOverlay") as Control
	var noodle_chapter_button := menu.get_node("ChapterOverlay/Panel/Layout/Cards/NoodleCard/Content/NoodleShopButton") as Button
	var noodle_chapter_status := menu.get_node("ChapterOverlay/Panel/Layout/Cards/NoodleCard/Content/NoodleShopStatus") as Label
	_check(chapter_overlay.visible and noodle_chapter_button.disabled and "未解锁" in noodle_chapter_status.text, "shop selector presents the locked second chapter and its unlock progress")
	menu.call("_close_chapter_select")
	_check("已完成 0 单" in session.resume_summary(), "new session summary is player-readable")
	session.call("mark_session_left")
	_check(session.call("is_business_paused"), "returning to the start page persists a paused business session")
	_check(session.call("continue_game") and session.call("is_business_paused"), "continue keeps timers paused until the gameplay scene finishes binding")

	menu.call("_open_settings")
	var settings_overlay := menu.get("_shared_settings_panel") as GameSettingsPanel
	_check(settings_overlay != null and settings_overlay.visible and settings_overlay.get("_scroll") is ScrollContainer, "shared settings opens as a scrollable modal overlay")
	var master_slider := settings_overlay.get("_master_slider") as HSlider
	var sfx_slider := settings_overlay.get("_sfx_slider") as HSlider
	var fullscreen_check := settings_overlay.get("_fullscreen_check") as CheckButton
	master_slider.value = 41.0
	sfx_slider.value = 73.0
	fullscreen_check.button_pressed = false
	settings_overlay.call("_save")
	var changed_settings: Dictionary = session.get_settings()
	_check(is_equal_approx(float(changed_settings.master_volume), 41.0), "master volume persists from settings")
	_check(is_equal_approx(float(changed_settings.sfx_volume), 73.0), "SFX volume persists from settings")
	_check(AudioServer.get_bus_index(&"SFX") >= 0, "dedicated SFX audio bus is configured")
	menu.call("_close_settings")

	menu.call("_request_new_game")
	_check((menu.get_node("NewGameOverlay") as Control).visible, "existing progress requires new-game confirmation")
	menu.call("_close_new_game_confirmation")
	_check(not (menu.get_node("NewGameOverlay") as Control).visible, "new-game confirmation can be cancelled")

	menu.call("_begin_game_load", false, "res://missing/threaded_game_scene.tscn")
	_check(loading_overlay.visible and continue_button.disabled and new_game_button.disabled, "loading overlay appears immediately and blocks duplicate menu actions")
	menu.call("_begin_game_load", true)
	_check(not bool(menu.get("_pending_new_game")), "a second click cannot replace the in-flight transition mode")
	for _frame in 4:
		await process_frame
	_check(not loading_overlay.visible and not continue_button.disabled, "threaded load failure restores the start menu actions")
	_check("失败" in menu.get_node("Content/Layout/MenuPanel/Menu/SessionStatus/StatusLayout/ResumeLabel").text, "threaded load failure exposes a retry message")
	_check(bool(session.call("has_save")) and bool(session.call("is_business_paused")), "failed loading leaves the existing paused save untouched")

	current_scene = menu
	var continue_write_count := int(session.get("_save_write_count"))
	continue_button.emit_signal("pressed")
	_check(loading_overlay.visible and continue_button.disabled, "continue enters visible loading state before scene work starts")
	await process_frame
	_check(loading_overlay.visible, "loading feedback survives through the first rendered frame")
	for _frame in 600:
		if current_scene != menu:
			break
		await process_frame
	var gameplay := current_scene as Control
	_check(gameplay != null and gameplay.name == "Main", "threaded continue load switches to the gameplay scene")
	if gameplay == null:
		_finish()
		return
	var continue_write_delta := int(session.get("_save_write_count")) - continue_write_count
	_check(continue_write_delta == 1, "continue persists exactly once after gameplay binding (actual %d)" % continue_write_delta)
	_check(not session.call("is_business_paused"), "gameplay scene resumes business only after workstation binding completes")
	gameplay.call("_set_paused", true)
	var pause_panel := gameplay.get_node("PausePanel") as Control
	var workstation := gameplay.get_node("Workstation") as Control
	var restored_customer_count := 0
	var all_restored_customers_standing := true
	for service_slot_variant in Array(workstation.get("customer_service_slots")):
		var service_slot := service_slot_variant as Control
		if service_slot == null or not service_slot.visible:
			continue
		restored_customer_count += 1
		all_restored_customers_standing = all_restored_customers_standing \
			and not bool(service_slot.call("is_presentation_transitioning")) \
			and service_slot.portrait.position == Vector2(12.0, 380.0) \
			and service_slot.get_node("OrderPanel").visible
	_check(
		(restored_customer_count > 0 and all_restored_customers_standing)
		or (restored_customer_count == 0 and bool(session.call("is_opening_restock_active"))),
		"continue preserves either saved customers in place or the saved opening-restock state without replaying arrival"
	)
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
	current_scene = null

	var new_menu := START_MENU_SCENE.instantiate()
	root.add_child(new_menu)
	current_scene = new_menu
	await process_frame
	new_menu.call("_request_new_game")
	_check((new_menu.get_node("NewGameOverlay") as Control).visible, "existing save still requires confirmation before threaded new-game loading")
	var new_game_write_count := int(session.get("_save_write_count"))
	new_menu.call("_start_new_game")
	_check((new_menu.get_node("LoadingOverlay") as Control).visible, "confirmed new game uses the same visible loading flow")
	for _frame in 600:
		if current_scene != new_menu:
			break
		await process_frame
	var new_gameplay := current_scene as Control
	_check(new_gameplay != null and int(Dictionary(session.get("_save_data")).get("orders_completed", -1)) == 0, "new-game state resets only after threaded scene loading succeeds")
	var new_game_write_delta := int(session.get("_save_write_count")) - new_game_write_count
	_check(new_game_write_delta == 1, "new game persists exactly once after threaded loading (actual %d)" % new_game_write_delta)
	if new_gameplay != null:
		new_gameplay.queue_free()
		await process_frame
	current_scene = null

	session.save_settings(
		float(previous_settings.master_volume),
		float(previous_settings.sfx_volume),
		bool(previous_settings.fullscreen),
		float(previous_settings.get("ui_scale", 100.0)),
		float(previous_settings.get("drag_sensitivity", 100.0)),
		Dictionary(previous_settings.get("key_bindings", session.call("default_key_bindings")))
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
