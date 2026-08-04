extends SceneTree

const SCENE_PATH := "res://scenes/gameplay/initial_unlock_workstation.tscn"
const PANCAKE_SPACE := preload("res://scripts/simulation/pancake_space.gd")
const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")

const EXPECTED_LEFT_RECT := Rect2(100.0, 455.0, 620.0, 540.0)
const EXPECTED_CENTER_RECT := Rect2(740.0, 455.0, 520.0, 540.0)
const EXPECTED_RIGHT_RECT := Rect2(1280.0, 455.0, 540.0, 540.0)
const OLD_SURFACE_SIZE := Vector2(600.0, 555.0)
const EXPECTED_SURFACE_SIZE := Vector2(480.0, 450.0)
const EXPECTED_WORKTOP_RECT := Rect2(0.0, 565.0, 1920.0, 515.0)
const EXPECTED_WORKTOP_ATLAS_REGION := Rect2(0.0, 290.0, 1672.0, 651.0)
const EXPECTED_TOOL_HOLDER_FRAME_RECT := Rect2(-70.0, -35.0, 330.0, 145.0)
const EXPECTED_TOOL_HOLDER_ART_RECT := Rect2(0.0, 0.0, 330.0, 145.0)
const EXPECTED_TOOL_HOLDER_ATLAS_REGION := Rect2(335.0, 131.0, 1248.0, 527.0)
const EXPECTED_TOOL_INPUT_RECT := Rect2(30.0, 420.0, 330.0, 145.0)
const EXPECTED_INGREDIENT_RACK_RECT := Rect2(1286.0, 582.0, 528.0, 185.0)
const EXPECTED_TRAY_GRID_RECT := Rect2(6.0, 127.0, 528.0, 185.0)
const EXPECTED_TOOL_DISPLAY_Y := 18.0
const EXPECTED_BOTTOM_STRIP_RECT := Rect2(100.0, 145.0, 600.0, 110.0)
const GRIDDLE_ALPHA_BOTTOM := 998.0
const GRIDDLE_SOURCE_CENTER_Y := 627.0

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "initial-unlock workstation scene loads without missing resources")
	if packed == null:
		_finish()
		return
	var workstation := packed.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	_check_layout(workstation)
	_check_locked_slots(workstation)
	_check_tools(workstation)
	_check_input_mapping(workstation)
	workstation.queue_free()
	await process_frame
	_finish()


func _check_layout(workstation: Node) -> void:
	var safe_area := workstation.get_node_or_null("SafeArea") as Control
	_check(safe_area != null and _near(safe_area.size, Vector2(1920.0, 1080.0)), "workstation keeps a 1920x1080 scene-first safe area")
	var left_zone := workstation.get_node_or_null("SafeArea/ExpansionLayout/LeftZone") as Control
	var center_zone := workstation.get_node_or_null("SafeArea/ExpansionLayout/CenterZone") as Control
	var right_zone := workstation.get_node_or_null("SafeArea/ExpansionLayout/RightZone") as Control
	_check(_rect_matches(left_zone, EXPECTED_LEFT_RECT), "left zone is 620px wide at the planned workstation origin")
	_check(_rect_matches(center_zone, EXPECTED_CENTER_RECT), "center zone is 520px wide with a 20px left gap")
	_check(_rect_matches(right_zone, EXPECTED_RIGHT_RECT), "right zone is 540px wide with a 20px center gap")
	var pan_base := workstation.get_node_or_null("SafeArea/PanBase") as Control
	var surface := workstation.get_node_or_null("SafeArea/PanBase/PancakeSurface") as Control
	_check(pan_base != null and _near(pan_base.size, Vector2(520.0, 468.0)), "PanBase is reduced by exactly twenty percent to 520x468")
	_check(surface != null and _near(surface.size, EXPECTED_SURFACE_SIZE), "PancakeSurface matches the redrawn griddle footprint without entering the front cabinet")
	_check(surface != null and _near(surface.position, Vector2(20.0, 0.0)), "griddle input surface starts below the payment controls")
	var griddle := workstation.get_node_or_null("SafeArea/PanBase/GriddleArtwork") as Sprite2D
	_check(griddle != null and _near(griddle.position, Vector2(260.0, 220.0)), "griddle artwork is vertically centered inside the redrawn mounting area")
	_check(griddle != null and _near(griddle.scale, Vector2(0.492891, 0.49)), "griddle artwork preserves width while staying above the front cabinet")
	var visible_griddle_bottom := INF
	if pan_base != null and griddle != null:
		visible_griddle_bottom = pan_base.position.y + griddle.position.y + (GRIDDLE_ALPHA_BOTTOM - GRIDDLE_SOURCE_CENTER_Y) * griddle.scale.y
	_check(visible_griddle_bottom <= 930.0, "visible griddle bottom remains inside the physical worktop boundary")
	var worktop := workstation.get_node_or_null("SafeArea/ExpansionLayout/WorktopArtwork") as TextureRect
	_check(_rect_matches(worktop, EXPECTED_WORKTOP_RECT), "one redrawn physical counter reaches both screen edges without a left seam")
	_check(_uses_atlas_crop(worktop, "workstation_initial_unlock_redraw_v4.png", EXPECTED_WORKTOP_ATLAS_REGION), "workstation uses the continuous worktop with the physical 4x3 pans shifted fully into the right zone")
	_check(_worktop_center_clear_of_dark_trays(worktop), "the physical right-side tray artwork leaves a clean gap beside the griddle")
	var tool_frame := workstation.get_node_or_null("SafeArea/ExpansionLayout/LeftZone/ToolRackFrame") as Control
	_check(_rect_matches(tool_frame, EXPECTED_TOOL_HOLDER_FRAME_RECT), "three tool holders sit in the narrow counter area left of the payment slot")
	var tool_rack := workstation.get_node_or_null("SafeArea/ExpansionLayout/LeftZone/ToolRackFrame/Artwork") as TextureRect
	_check(_rect_matches(tool_rack, EXPECTED_TOOL_HOLDER_ART_RECT), "three cylindrical holders fill the payment-slot-left tool zone")
	_check(_uses_atlas_crop(tool_rack, "payment_slot_tool_cups_initial_v5.png", EXPECTED_TOOL_HOLDER_ATLAS_REGION), "tool holders use the redrawn payment-slot metal language")
	var tool_input_rack := workstation.get_node_or_null("SafeArea/LeftRack") as Control
	_check(_rect_matches(tool_input_rack, EXPECTED_TOOL_INPUT_RECT), "tool input rack follows the three holders left of the payment slot")
	_check(tool_input_rack != null and tool_input_rack.position.x + tool_input_rack.size.x <= 360.0, "tool holders do not overlap the payment slot")
	var ingredient_rack := workstation.get_node_or_null("SafeArea/IngredientRack") as Control
	_check(_rect_matches(ingredient_rack, EXPECTED_INGREDIENT_RACK_RECT), "day-one ingredients overlay the physical right-side tray grid instead of the payment shelf")
	var bottom_strip := workstation.get_node_or_null("SafeArea/BottomStrip") as Control
	_check(_rect_matches(bottom_strip, EXPECTED_BOTTOM_STRIP_RECT), "status and instruction strip is relocated above the workstation")
	_check(bottom_strip != null and bottom_strip.position.y + bottom_strip.size.y < 405.0, "status strip no longer covers any worktop edge")


func _check_locked_slots(workstation: Node) -> void:
	var tray_grid := workstation.get_node_or_null("SafeArea/ExpansionLayout/RightZone/IngredientTrayGrid")
	_check(tray_grid != null and tray_grid.get_child_count() == 12, "all twelve fixed 4x3 tray positions exist in the scene")
	_check(_rect_matches(tray_grid as Control, EXPECTED_TRAY_GRID_RECT), "tray input grid matches the measured physical 4x3 metal-pan artwork")
	if tray_grid != null:
		for index in tray_grid.get_child_count():
			var child := tray_grid.get_child(index)
			var slot := child as BaseButton
			_check(slot != null and slot.disabled and slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s remains a non-intercepting physical tray underlay" % child.name)
			_check(slot != null and _button_is_visually_clear(slot), "%s leaves the physical metal pan artwork visible" % child.name)
			_check(bool(slot.get_meta(&"day_one_occupied", false)) == (index < 3), "%s has the correct opening-day occupied state" % child.name)
		var day_one_buttons := ["EggButton", "BaocuiButton", "ScallionButton"]
		var day_one_ids := [&"egg", &"baocui", &"scallion"]
		for index in day_one_buttons.size():
			var tray := tray_grid.get_child(index) as Control
			var ingredient := workstation.get_node_or_null("SafeArea/IngredientRack/%s" % day_one_buttons[index]) as BaseButton
			_check(ingredient != null and ingredient.visible, "%s remains a stable day-one ingredient control" % day_one_buttons[index])
			_check(StringName(str(tray.get_meta(&"ingredient_id", ""))) == day_one_ids[index], "%s identifies its day-one ingredient" % tray.name)
			_check(_global_rects_match(ingredient, tray), "%s is physically contained by %s" % [day_one_buttons[index], tray.name])
	var device_slots := workstation.get_node_or_null("SafeArea/ExpansionLayout/DeviceSlots")
	_check(device_slots != null and device_slots.get_child_count() == 3, "exactly three expansion-device slots exist")
	if device_slots != null:
		var ids := PackedStringArray()
		for child in device_slots.get_children():
			ids.append(str(child.get_meta(&"device_id", "")))
			var hit_area := child.get_node_or_null("InteractionArea") as BaseButton
			_check(hit_area != null and hit_area.disabled and hit_area.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s starts non-interactive" % child.name)
			var locked_cover := child.get_node_or_null("LockedCover") as Panel
			_check(locked_cover != null and _panel_is_visually_clear(locked_cover), "%s keeps UI framing transparent" % child.name)
			if child.name == &"YoutiaoFryerSlot":
				_check(locked_cover.visible, "the right fryer bay keeps a clear locked-equipment state")
			else:
				_check(not locked_cover.visible and not bool(child.get_meta(&"show_locked_cover", true)), "%s leaves a flat tabletop for its future countertop machine" % child.name)
		_check(ids.has(str(CATALOG.DEVICE_SOY_MILK)), "soy-milk machine keeps its fixed opening-day slot")
		_check(ids.has(str(CATALOG.DEVICE_YOUTIAO)), "youtiao fryer keeps its fixed opening-day slot")
		_check(ids.has(str(CATALOG.DEVICE_EGG_WAFFLE)), "egg-waffle machine keeps its fixed opening-day slot")
		_check(not ids.has("steamer") and not ids.has("bao_steamer"), "no steamer device is present")


func _check_tools(workstation: Node) -> void:
	for path in ["SafeArea/LeftRack/ScraperButton", "SafeArea/LeftRack/SauceBrushButton"]:
		var tool := workstation.get_node_or_null(path) as BaseButton
		_check(tool != null and bool(tool.get_meta(&"progression_owned", false)) and tool.visible, "%s is owned on day one and remains in its stable cylindrical holder" % path.get_file())
	var display_pairs := {
		"LadleButton": "LadleDisplay",
		"ScraperButton": "SpreaderDisplay",
		"SauceBrushButton": "BrushDisplay",
	}
	var expected_input_rects := {
		"LadleButton": Rect2(0.0, 0.0, 105.0, 145.0),
		"ScraperButton": Rect2(112.0, 0.0, 106.0, 145.0),
		"SauceBrushButton": Rect2(225.0, 0.0, 105.0, 145.0),
	}
	for button_name: String in display_pairs:
		var button := workstation.get_node_or_null("SafeArea/LeftRack/%s" % button_name) as Control
		var display := workstation.get_node_or_null("SafeArea/ExpansionLayout/LeftZone/ToolRackFrame/%s" % display_pairs[button_name]) as Sprite2D
		_check(display != null and display.visible and display.texture != null, "%s has a stable visible scene-backed display" % button_name)
		_check(_rect_matches(button, expected_input_rects[button_name]), "%s input covers its complete physical holder" % button_name)
		_check(button != null and display != null and absf(button.position.x + button.size.x * 0.5 - display.position.x) < 1.0, "%s display is centered over its input region" % button_name)
		_check(display != null and absf(display.position.y - EXPECTED_TOOL_DISPLAY_Y) < 1.0, "%s is lowered into the dark cylinder interior" % button_name)
	var fold_button := workstation.get_node_or_null("SafeArea/LeftRack/FoldButton") as BaseButton
	_check(fold_button != null and not fold_button.visible and fold_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "folding state remains wired without drawing a fourth spatula holder or hot zone")
	_check(workstation.get_node_or_null("SafeArea/ExpansionLayout/LeftZone/ToolRackFrame/FoldDisplay") == null, "no fourth spatula sprite is present")
	_check(workstation.get_node_or_null("SafeArea/ExpansionLayout/LeftZone/ToolRackFrame/Hook4") == null, "tool-holder scene contains exactly three physical positions")
	var front_occlusion := workstation.get_node_or_null("SafeArea/ExpansionLayout/LeftZone/ToolRackFrame/FrontOcclusion") as TextureRect
	_check(front_occlusion != null and front_occlusion.z_index > 2 and front_occlusion.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the cylinder front wall occludes tool handles without intercepting input")
	var scraper := workstation.get_node_or_null("SafeArea/LeftRack/ScraperButton") as BaseButton
	_check(scraper != null and not scraper.disabled, "the basic spreader is immediately operable in the opening spread phase")
	var upgrade_rack := workstation.get_node_or_null("SafeArea/ExpansionLayout/LeftZone/UpgradeToolHooks")
	_check(upgrade_rack != null and upgrade_rack.get_child_count() == 3, "three upgrade-tool hooks are reserved in the scene")
	if upgrade_rack != null:
		for child in upgrade_rack.get_children():
			var tool := child as BaseButton
			_check(tool != null and tool.disabled and tool.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s is unavailable on day one" % child.name)
			_check(tool != null and not tool.visible, "%s has no misleading empty hook in the opening-day scene" % child.name)
			var cover := child.get_node_or_null("LockedCover") as CanvasItem
			_check(cover == null or not cover.visible, "%s draws no upgrade-tool UI tile" % child.name)


func _check_input_mapping(workstation: Node) -> void:
	var surface := workstation.get_node_or_null("SafeArea/PanBase/PancakeSurface") as Control
	if surface == null:
		_check(false, "scaled surface exists for mapping checks")
		return
	var grid_size := 128
	for normalized: Vector2 in [Vector2(0.12, 0.21), Vector2(0.50, 0.50), Vector2(0.84, 0.68)]:
		var old_local: Vector2 = normalized * OLD_SURFACE_SIZE
		var new_local: Vector2 = normalized * surface.size
		var old_grid: Vector2 = PANCAKE_SPACE.local_to_grid_position(old_local, OLD_SURFACE_SIZE, grid_size)
		var new_grid: Vector2 = PANCAKE_SPACE.local_to_grid_position(new_local, surface.size, grid_size)
		_check(_near(old_grid, new_grid), "scaled pointer sample %s maps to the same simulation coordinate" % normalized)
		var cell := PANCAKE_SPACE.local_to_grid(old_local, OLD_SURFACE_SIZE, grid_size)
		var placed_new: Vector2 = PANCAKE_SPACE.grid_to_local(cell, surface.size, grid_size)
		var old_placement: Vector2 = PANCAKE_SPACE.grid_to_local(cell, OLD_SURFACE_SIZE, grid_size)
		var expected_new := Vector2(old_placement.x * 0.8, old_placement.y * EXPECTED_SURFACE_SIZE.y / OLD_SURFACE_SIZE.y)
		_check(_near(placed_new, expected_new), "ingredient placement for %s follows the independent horizontal and vertical scale" % normalized)
	var left_fold_old := Vector2(OLD_SURFACE_SIZE.x * 0.38, OLD_SURFACE_SIZE.y * 0.5)
	var left_fold_new := Vector2(surface.size.x * 0.38, surface.size.y * 0.5)
	_check(_near(
		PANCAKE_SPACE.local_to_grid_position(left_fold_old, OLD_SURFACE_SIZE, grid_size),
		PANCAKE_SPACE.local_to_grid_position(left_fold_new, surface.size, grid_size)
	), "left fold path remains on the same simulation fold line")
	var edge_old := Vector2(OLD_SURFACE_SIZE.x * 0.02, OLD_SURFACE_SIZE.y * 0.5)
	var edge_new := Vector2(surface.size.x * 0.02, surface.size.y * 0.5)
	_check(
		PANCAKE_SPACE.is_inside_pan(edge_old, OLD_SURFACE_SIZE, 0.694) == PANCAKE_SPACE.is_inside_pan(edge_new, surface.size, 0.694),
		"scaled griddle edge preserves the inside-pan decision"
	)


func _rect_matches(control: Control, expected: Rect2) -> bool:
	return control != null and _near(control.position, expected.position) and _near(control.size, expected.size)


func _global_rects_match(first: Control, second: Control) -> bool:
	return first != null and second != null and first.get_global_rect().position.distance_to(second.get_global_rect().position) <= 1.0 and first.get_global_rect().size.distance_to(second.get_global_rect().size) <= 1.0


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= 0.05


func _uses_atlas_crop(control: TextureRect, filename: String, expected_region: Rect2) -> bool:
	if control == null:
		return false
	var crop := control.texture as AtlasTexture
	return crop != null \
		and crop.atlas != null \
		and crop.atlas.resource_path.ends_with(filename) \
		and crop.region == expected_region


func _uses_texture(control: TextureRect, filename: String) -> bool:
	return control != null and control.texture != null and control.texture.resource_path.ends_with(filename)


func _uses_atlas_named(control: TextureRect, filename: String) -> bool:
	if control == null:
		return false
	var crop := control.texture as AtlasTexture
	return crop != null and crop.atlas != null and crop.atlas.resource_path.ends_with(filename)


func _worktop_center_clear_of_dark_trays(control: TextureRect) -> bool:
	if control == null:
		return false
	var crop := control.texture as AtlasTexture
	if crop == null or crop.atlas == null:
		return false
	var image := crop.atlas.get_image()
	if image == null or image.is_empty():
		return false
	var sample := Rect2i(1035, 320, 70, 220)
	var dark_pixels := 0
	for y in range(sample.position.y, sample.end.y):
		for x in range(sample.position.x, sample.end.x):
			var color := image.get_pixel(x, y)
			if color.get_luminance() < 0.42:
				dark_pixels += 1
	return float(dark_pixels) / float(sample.size.x * sample.size.y) < 0.08


func _button_is_visually_clear(button: BaseButton) -> bool:
	var normal := button.get_theme_stylebox(&"normal")
	var disabled := button.get_theme_stylebox(&"disabled")
	return normal is StyleBoxEmpty and disabled is StyleBoxEmpty


func _panel_is_visually_clear(panel: Panel) -> bool:
	return panel.get_theme_stylebox(&"panel") is StyleBoxEmpty


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("INITIAL_UNLOCK_WORKSTATION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
