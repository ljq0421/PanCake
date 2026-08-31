extends SceneTree

const SCENE := preload("res://scenes/main/night_market_main.tscn")
const BREAKFAST_CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const NOODLE_CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")
const NIGHT_CATALOG := preload("res://scripts/data/night_market_catalog.gd")

const CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/night_market_twin_fire_gpu_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/night_market_twin_fire_gpu_1280x720.png"},
]
const READINESS_CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/night_market_ready_windows_gpu_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/night_market_ready_windows_gpu_1280x720.png"},
]
const RESULT_CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/night_market_result_feedback_gpu_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/night_market_result_feedback_gpu_1280x720.png"},
]

var _failures: Array[String] = []
var _session: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("NIGHT_MARKET_GPU_SMOKE_FAIL\nGPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	_session = root.get_node_or_null("GameSession")
	_check(_session != null, "campaign session exists for night-market GPU smoke")
	if _session == null:
		_finish(PackedStringArray())
		return
	_session.set("_active_save_path", "user://night_market_gpu_smoke.json")
	_session.call("begin_new_game")
	_unlock_noodle_chapter()
	_session.call("select_chapter", _session.NOODLE_CHAPTER_ID)
	_session.call("noodle_end_day", &"manual")
	var noodle_session: RefCounted = _session.get("_noodle_session")
	var owned_growth_ids := {}
	for growth_id in NOODLE_CATALOG.GROWTH_DISPLAY_ORDER:
		owned_growth_ids[growth_id] = true
	noodle_session.set("owned_growth_ids", owned_growth_ids)
	_session.call("_sync_noodle_session_to_save")
	_session.call("_refresh_campaign_unlocks")
	_session.call("select_chapter", _session.NIGHT_MARKET_CHAPTER_ID)
	var scene := SCENE.instantiate()
	root.add_child(scene)
	for _frame in 8:
		await process_frame
	var station := scene.get_node("Workstation") as NightMarketWorkstation
	var background := station.get_node("Background") as TextureRect
	var grill_art := station.get_node("ArtLayer/GrillArt") as TextureRect
	var plating_art := station.get_node("ArtLayer/PlatingArt") as TextureRect
	var fryer_art := station.get_node("ArtLayer/FryerBaseArt") as TextureRect
	_check(background.texture.resource_path == "res://resources/art/night_market/background/night_market_empty_stall-v1.png", "runtime uses the empty-stall background behind formal layers")
	_check(grill_art.texture.resource_path == "res://resources/art/night_market/layers/charcoal_grill-rgba-v1.png", "grill is an independent formal art layer")
	_check(plating_art.texture.resource_path == "res://resources/art/night_market/layers/plating_station-rgba-v1.png", "plating station is an independent formal art layer")
	_check(fryer_art.texture.resource_path == "res://resources/art/night_market/layers/twin_fryer_base-rgba-v1.png", "fryer is an independent formal art layer")
	_check(
		(station.get_node("StatsPanel/Layout/DetailReadoutButton") as Button).text == "显示详细数值"
		and not (station.get_node("FryerPanel/Layout/FryerStatusLabel") as Label).text.contains("℃")
		and is_zero_approx((station.get_node("FryerPanel/Layout/Hint") as Label).modulate.a)
		and is_zero_approx((station.get_node("PlatePanel/Layout/SeasoningTitle") as Label).modulate.a),
		"first viewport favors qualitative cooking states and suppresses secondary instructions until focus",
	)
	station.call("_add_grill", NIGHT_CATALOG.ITEM_LAMB)
	_session.call("night_market_advance", 1.5)
	station.call("_add_fryer", NIGHT_CATALOG.ITEM_LOTUS)
	station.call("_lower_fryer")
	_session.call("night_market_advance", 2.0)
	station.call("_refresh", true)
	await process_frame
	var grill_food := station.get_node("ArtLayer/GrillFood2") as TextureRect
	var fryer_food := station.get_node("ArtLayer/FryerFoodArt") as TextureRect
	var fryer_basket := station.get_node("ArtLayer/FryerBasketArt") as TextureRect
	var fryer_effect := station.get_node("ArtLayer/FryerEffectArt") as TextureRect
	_check(grill_food.visible and grill_food.texture is AtlasTexture, "grill food switches to a doneness atlas frame during cooking")
	_check(fryer_food.visible and fryer_food.texture is AtlasTexture, "fryer food switches to a doneness atlas frame during cooking")
	_check(fryer_basket.visible and fryer_basket.texture is AtlasTexture, "fryer basket switches to its lowered state layer")
	_check(fryer_effect.visible and fryer_effect.texture is AtlasTexture, "oil-bubble effect appears while the basket is lowered")
	var output_paths := PackedStringArray()
	for capture_value in CAPTURES:
		var capture := Dictionary(capture_value)
		var capture_size := Vector2i(capture.get("size", Vector2i.ZERO))
		DisplayServer.window_set_size(capture_size)
		for _frame in 6:
			await process_frame
		var visible_rect := root.get_visible_rect()
		_check(visible_rect.encloses((station.get_node("GrillPanel") as Control).get_global_rect()), "grill wing stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		_check(visible_rect.encloses((station.get_node("FryerPanel") as Control).get_global_rect()), "fryer wing stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		_check(visible_rect.encloses((station.get_node("PlatePanel") as Control).get_global_rect()), "shared plate stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		var output_absolute := ProjectSettings.globalize_path(str(capture.get("path", "")))
		DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
		var image := root.get_texture().get_image()
		var save_error := image.save_png(output_absolute)
		_check(save_error == OK and image.get_size() == capture_size, "night-market first viewport captures at %dx%d" % [capture_size.x, capture_size.y])
		output_paths.append(output_absolute)
	_session.call("night_market_advance", 3.5)
	station.call("_refresh", true)
	var grill_slot := station.get_node("GrillPanel/Layout/Slots/Medium/GrillSlot2") as Button
	var lift_fryer_button := station.get_node("FryerPanel/Layout/ActionRow/LiftFryerButton") as Button
	var status_label := station.get_node("StatusPanel/StatusLabel") as Label
	_check(
		grill_slot.text.contains("★翻面")
		and lift_fryer_button.text.contains("★")
		and status_label.text.contains("现在翻面")
		and status_label.text.contains("现在提篮"),
		"simultaneous best-action windows visibly identify both required controls",
	)
	_session.call("set_business_paused", true)
	for capture_value in READINESS_CAPTURES:
		var capture := Dictionary(capture_value)
		var capture_size := Vector2i(capture.get("size", Vector2i.ZERO))
		DisplayServer.window_set_size(capture_size)
		for _frame in 6:
			await process_frame
		var visible_rect := root.get_visible_rect()
		_check(visible_rect.encloses(grill_slot.get_global_rect()), "ready grill control stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		_check(visible_rect.encloses(lift_fryer_button.get_global_rect()), "ready fryer control stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		var output_absolute := ProjectSettings.globalize_path(str(capture.get("path", "")))
		DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
		var image := root.get_texture().get_image()
		var save_error := image.save_png(output_absolute)
		_check(save_error == OK and image.get_size() == capture_size, "night-market ready windows capture at %dx%d" % [capture_size.x, capture_size.y])
		output_paths.append(output_absolute)
	_session.call("set_business_paused", false)
	station.call("_flip_grill_slot", 2)
	station.call("_lift_fryer")
	_session.call("night_market_advance", 1.2)
	station.call("_plate_fryer")
	station.call("_season", NIGHT_CATALOG.SEASONING_SALT_PEPPER)
	_session.call("night_market_advance", 5.8)
	station.call("_plate_selected_grill")
	station.call("_season", NIGHT_CATALOG.SEASONING_CUMIN)
	station.call("_serve_plate")
	await process_frame
	var result_panel := station.get_node("ResultPanel") as Control
	var result_details := station.get_node("ResultPanel/Layout/ResultDetails") as Label
	_check(
		result_panel.visible
		and result_details.text.contains("羊肉串")
		and result_details.text.contains("炸藕片")
		and result_details.text.count("•") == 2,
		"night-market result presents one concise diagnostic for each completed item",
	)
	for capture_value in RESULT_CAPTURES:
		var capture := Dictionary(capture_value)
		var capture_size := Vector2i(capture.get("size", Vector2i.ZERO))
		DisplayServer.window_set_size(capture_size)
		for _frame in 6:
			await process_frame
		var visible_rect := root.get_visible_rect()
		_check(visible_rect.encloses(result_panel.get_global_rect()), "result feedback stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		var output_absolute := ProjectSettings.globalize_path(str(capture.get("path", "")))
		DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
		var image := root.get_texture().get_image()
		var save_error := image.save_png(output_absolute)
		_check(save_error == OK and image.get_size() == capture_size, "night-market result feedback captures at %dx%d" % [capture_size.x, capture_size.y])
		output_paths.append(output_absolute)
	scene.queue_free()
	await process_frame
	_finish(output_paths)


func _unlock_noodle_chapter() -> void:
	var progression: RefCounted = _session.call("progression_service")
	var unlocked_areas := {}
	var mastery := {}
	var mastery_details := {}
	var tutorials := {}
	for area_id in BREAKFAST_CATALOG.AREA_IDS:
		unlocked_areas[area_id] = true
		tutorials[area_id] = true
		var qualified := 8 if area_id == &"area.pancake" else 4
		var a_grade := 2 if area_id == &"area.pancake" else 1
		mastery[area_id] = qualified
		mastery_details[area_id] = {"qualified": qualified, "a_grade": a_grade}
	progression.set("unlocked_area_ids", unlocked_areas)
	progression.set("tutorial_completed_area_ids", tutorials)
	progression.set("area_mastery", mastery)
	progression.set("area_mastery_details", mastery_details)
	progression.set("day_open", false)
	_session.set("_save_data", Dictionary(_session.get("_save_data")).merged({"day_open": false}, true))
	_session.call("_sync_progression_to_save")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish(output_paths: PackedStringArray) -> void:
	for path in output_paths:
		print("CAPTURE: %s" % path)
	if _failures.is_empty():
		print("NIGHT_MARKET_GPU_SMOKE_PASS")
		quit(0)
		return
	printerr("NIGHT_MARKET_GPU_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
