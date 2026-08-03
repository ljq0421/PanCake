extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const WORKSTATION_SCENE := preload("res://scenes/gameplay/workstation.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_project_contract()
	_check_coordinate_contract()
	await _check_scene_contract()
	await _check_aspect_ratio_contract()
	_finish()


func _check_project_contract() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main/start_menu.tscn", "start menu is configured as the project entry")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920, "logical viewport width is 1920")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "logical viewport height is 1080")
	_check(ProjectSettings.get_setting("display/window/size/window_width_override") == 1920, "desktop window width is 1920")
	_check(ProjectSettings.get_setting("display/window/size/window_height_override") == 1080, "desktop window height is 1080")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile", "Mobile renderer remains selected")
	_check(ProjectSettings.has_setting("input/toggle_debug"), "debug toggle input action exists")
	_check(ProjectSettings.has_setting("input/reset_pancake"), "grid reset input action exists")
	_check(ProjectSettings.has_setting("input/pause_game"), "pause input action exists")
	_check(_first_key_for_action("toggle_debug") == KEY_F3, "debug toggle is mapped to F3")
	_check(_first_key_for_action("reset_pancake") == KEY_R, "grid reset is mapped to R")
	_check(_first_key_for_action("pause_game") == KEY_ESCAPE, "pause is mapped to Escape")


func _first_key_for_action(action_name: String) -> Key:
	var action: Dictionary = ProjectSettings.get_setting("input/%s" % action_name, {})
	var events: Array = action.get("events", [])
	if events.is_empty() or not events[0] is InputEventKey:
		return KEY_NONE
	var event := events[0] as InputEventKey
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


func _check_coordinate_contract() -> void:
	var sizes := [Vector2(600, 600), Vector2(650, 650), Vector2(800, 800)]
	for view_size in sizes:
		_check(PancakeSpace.local_to_grid(Vector2.ZERO, view_size, 256) == Vector2i.ZERO, "origin maps to grid origin at %s" % view_size)
		_check(PancakeSpace.local_to_grid(view_size * 0.5, view_size, 256) == Vector2i(128, 128), "center maps to grid center at %s" % view_size)
		_check(PancakeSpace.local_to_grid(view_size, view_size, 256) == Vector2i(255, 255), "far edge clamps to grid at %s" % view_size)
		var round_trip := PancakeSpace.grid_to_local(Vector2i(128, 128), view_size, 256)
		_check(round_trip.distance_to(view_size * (128.5 / 256.0)) < 0.001, "grid-to-local round trip is stable at %s" % view_size)
	_check(PancakeSpace.is_inside_pan(Vector2(300, 300), Vector2(600, 600), 0.694), "griddle center is interactive")
	_check(PancakeSpace.is_inside_pan(Vector2(10, 300), Vector2(600, 600), 0.694), "wide horizontal griddle edge remains interactive")
	_check(not PancakeSpace.is_inside_pan(Vector2(300, 80), Vector2(600, 600), 0.694), "area above the visible elliptical griddle is not interactive")
	_check(not PancakeSpace.is_inside_pan(Vector2.ZERO, Vector2(600, 600), 0.694), "square corner is outside the elliptical griddle")


func _check_scene_contract() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var workstation := main.get_node("Workstation") as Workstation
	_check(workstation != null, "main scene owns workstation scene")
	_check(main.has_node("DebugOverlay"), "main scene owns independently toggleable debug overlay")
	_check(main.has_node("PausePanel"), "main scene owns pause feedback")
	_check(workstation.pancake_model != null, "workstation owns business model")
	_check(workstation.pancake_model.grid_size == 128, "workstation loads simplified 128x128 parameter resource")
	_check(workstation.pancake_surface.model == workstation.pancake_model, "heatmap reads the same model instance")
	_check(workstation.pancake_surface.heatmap_field == PancakeHeatmap.VIEW_APPEARANCE, "intuitive pancake appearance is the default view")
	var safe_area := workstation.get_node("SafeArea") as Control
	_check(safe_area.size == Vector2(1920, 1080), "central safe area is fixed at baseline canvas")
	var surface := workstation.pancake_surface
	_check(surface.size == Vector2(600, 555), "pan logic view matches the reference griddle perspective")
	var background_artwork := workstation.get_node("SafeArea/BackgroundArtwork") as TextureRect
	var left_rack := workstation.get_node("SafeArea/LeftRack") as Panel
	var right_rack := workstation.get_node("SafeArea/RightRack") as Panel
	var ingredient_rack := workstation.get_node("SafeArea/IngredientRack") as Panel
	var ladle_button := workstation.get_node("SafeArea/LeftRack/LadleButton") as Button
	var spreader_button := workstation.get_node("SafeArea/LeftRack/ScraperButton") as Button
	var fold_button := workstation.get_node("SafeArea/LeftRack/FoldButton") as Button
	var sauce_brush_button := workstation.get_node("SafeArea/LeftRack/SauceBrushButton") as Button
	var ladle_artwork := workstation.get_node("SafeArea/LeftRack/LadleButton/Artwork") as TextureRect
	var spreader_button_artwork := workstation.get_node("SafeArea/LeftRack/ScraperButton/Artwork") as TextureRect
	var fold_tool_artwork := workstation.get_node("SafeArea/LeftRack/FoldButton/Artwork") as TextureRect
	var sauce_brush_artwork := workstation.get_node("SafeArea/LeftRack/SauceBrushButton/Artwork") as TextureRect
	var sauce_refill_button := workstation.get_node("SafeArea/RightRack/SauceRefillButton") as Button
	var egg_button := workstation.get_node("SafeArea/IngredientRack/EggButton") as Button
	var baocui_button := workstation.get_node("SafeArea/IngredientRack/BaocuiButton") as Button
	var ham_button := workstation.get_node("SafeArea/IngredientRack/HamButton") as Button
	var scallion_button := workstation.get_node("SafeArea/IngredientRack/ScallionButton") as Button
	var reserve_ingredient_1 := workstation.get_node("SafeArea/IngredientRack/ReserveIngredientSlot1") as Button
	var reserve_ingredient_2 := workstation.get_node("SafeArea/IngredientRack/ReserveIngredientSlot2") as Button
	var pan_base := workstation.get_node("SafeArea/PanBase") as Control
	var griddle_artwork := workstation.get_node("SafeArea/PanBase/GriddleArtwork") as Sprite2D
	var spreader_artwork := workstation.get_node("SafeArea/PanBase/PancakeSurface/SpreaderArtwork") as Sprite2D
	var pancake_visual := workstation.get_node("SafeArea/PanBase/PancakeSurface/PancakeVisual") as TextureRect
	var sauce_blob_overlay := workstation.get_node("SafeArea/PanBase/PancakeSurface/SauceBlobOverlay") as Control
	var ingredient_layer := workstation.get_node("SafeArea/PanBase/PancakeSurface/IngredientLayer") as Control
	var fold_overlay := workstation.get_node("SafeArea/PanBase/PancakeSurface/PancakeFoldOverlay") as Control
	var foreground_lip := workstation.get_node("SafeArea/ForegroundLip") as TextureRect
	var bottom_strip := workstation.get_node("SafeArea/BottomStrip") as Control
	var step_action_button := workstation.get_node("SafeArea/P1ControlBar/StepActionButton") as Button
	_check(background_artwork.texture.resource_path == "res://resources/art/workstation/background/workstation_backplate_v2.png", "background artwork uses the cleared refill-container backplate")
	_check(background_artwork.get_index() < pan_base.get_index(), "background artwork renders behind interactive content")
	_check((left_rack.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a <= 0.01, "left tool rack no longer draws a floating panel")
	_check((ingredient_rack.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a <= 0.01, "right ingredient rack no longer draws a floating panel")
	_check(left_rack.mouse_filter == Control.MOUSE_FILTER_IGNORE and right_rack.mouse_filter == Control.MOUSE_FILTER_IGNORE and ingredient_rack.mouse_filter == Control.MOUSE_FILTER_IGNORE, "overlapping rack panels do not intercept their child or sibling controls")
	_check(left_rack.position.x <= 120.0 and ingredient_rack.position.x >= 1300.0, "tool rack is left and the six-slot ingredient rack is right")
	_check(ladle_button.size == Vector2(190, 105) and spreader_button.size == Vector2(190, 105), "top-row tray cells are the ladle and spreader click regions")
	_check(fold_button.size == Vector2(190, 108) and sauce_brush_button.size == Vector2(190, 108), "middle-row tray cells are the fold spatula and sauce brush click regions")
	_check(ladle_button.global_position.x < 600.0 and spreader_button.global_position.x < 600.0 and fold_button.global_position.x < 600.0 and sauce_brush_button.global_position.x < 600.0, "all four tools are hosted by the left tool rack")
	_check(egg_button.global_position.x >= 1340.0 and baocui_button.global_position.x >= 1540.0 and ham_button.global_position.x >= 1340.0 and scallion_button.global_position.x >= 1540.0, "four active ingredients occupy the first four right-hand slots")
	_check(reserve_ingredient_1.disabled and reserve_ingredient_2.disabled and reserve_ingredient_1.global_position.x >= 1340.0 and reserve_ingredient_2.global_position.x >= 1540.0, "the remaining two right-hand slots are reserved for future ingredients")
	_check(ladle_artwork.texture.resource_path == "res://resources/art/workstation/tools/batter_ladle_v1.png", "automatic pour uses the approved tabletop ladle artwork")
	_check(spreader_button_artwork.texture.resource_path == "res://resources/art/workstation/tools/batter_spreader_v1.png", "spreader selection uses the approved tabletop artwork")
	_check(fold_tool_artwork.texture.resource_path == "res://resources/art/workstation/tools/folding_spatula_v1.png", "fold selection uses the approved tabletop spatula artwork")
	_check(sauce_brush_artwork.texture.resource_path == "res://resources/art/workstation/tools/sauce_brush_v1.png", "sauce selection uses the approved tabletop brush artwork")
	_check(sauce_refill_button.position.x >= 230.0 and sauce_refill_button.position.y <= 10.0, "sauce refill hit area overlays the backplate bottles")
	_check(griddle_artwork.texture.resource_path == "res://resources/art/workstation/griddle/griddle_base_v1.png", "griddle artwork uses the approved layered asset")
	_check(griddle_artwork.get_index() < surface.get_index(), "griddle artwork renders behind the pancake interaction surface")
	_check(
		is_equal_approx(griddle_artwork.scale.x, 0.616114) and is_equal_approx(griddle_artwork.scale.y, 0.55),
		"griddle artwork uses the controlled reference-perspective scale"
	)
	_check(spreader_artwork.texture.resource_path == "res://resources/art/workstation/tools/batter_spreader_v1.png", "spreader scene node uses the approved T-shaped artwork")
	_check(is_equal_approx(spreader_artwork.scale.x, spreader_artwork.scale.y), "spreader artwork preserves its source aspect ratio")
	_check(spreader_artwork.get_index() > pancake_visual.get_index() and spreader_artwork.get_index() < fold_overlay.get_index(), "spreader artwork renders over the pancake and below fold overlays")
	_check(sauce_blob_overlay.get_index() > pancake_visual.get_index() and sauce_blob_overlay.get_index() < ingredient_layer.get_index(), "unspread sauce blobs render over the pancake and below solid fillings")
	_check(pan_base.size == Vector2(650, 585), "griddle host fits the 600x555 interaction surface")
	_check(pan_base.position.y == 455.0 and pan_base.position.y + pan_base.size.y == 1040.0, "griddle keeps the reference slot gap and worktop bottom edge")
	var usable_pan_bottom := surface.global_position.y + surface.size.y * (0.5 + workstation.pancake_model.parameters.pan_height_ratio * 0.5)
	_check(usable_pan_bottom <= bottom_strip.global_position.y, "bottom HUD does not cover the usable elliptical pancake interaction area")
	_check(foreground_lip.texture.resource_path == "res://resources/art/workstation/foreground/workstation_front_lip_v1.png", "foreground lip uses the approved occlusion asset")
	_check(foreground_lip.get_index() > pan_base.get_index() and foreground_lip.get_index() < bottom_strip.get_index(), "foreground lip renders above dynamic content and below engine UI")
	_check(foreground_lip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "foreground lip ignores mouse input")
	_check(not step_action_button.visible and step_action_button.text != "确认面饼", "spreading has no manual confirm-pancake action")
	main.queue_free()
	await process_frame
	await process_frame


func _check_aspect_ratio_contract() -> void:
	var viewport_sizes := [Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1080)]
	for viewport_size in viewport_sizes:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var host := Control.new()
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport.add_child(host)
		var workstation := WORKSTATION_SCENE.instantiate() as Workstation
		host.add_child(workstation)
		await process_frame
		var safe_area := workstation.get_node("SafeArea") as Control
		var expected_center := Vector2(viewport_size) * 0.5
		var actual_center := safe_area.position + safe_area.size * 0.5
		_check(actual_center.distance_to(expected_center) < 0.01, "1920x1080 safe area stays centered in %dx%d" % [viewport_size.x, viewport_size.y])
		_check(safe_area.size == Vector2(1920, 1080), "baseline safe area size is unchanged in %dx%d" % [viewport_size.x, viewport_size.y])
		viewport.queue_free()
		await process_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("M0 integration self-check PASS")
		quit(0)
	else:
		print("M0 integration self-check FAIL (%d)" % _failures.size())
		quit(1)
