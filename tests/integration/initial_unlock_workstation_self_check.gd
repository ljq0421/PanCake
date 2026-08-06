extends SceneTree

const SCENE_PATH := "res://scenes/gameplay/initial_unlock_workstation.tscn"
const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const CENTRAL_PAN_BAY := Rect2(640.0, 500.0, 620.0, 420.0)
const STARTER_SLOT_RECTS := {
	&"egg": Rect2(654.0, 925.0, 89.0, 120.0),
	&"scallion": Rect2(759.0, 925.0, 89.0, 120.0),
	&"baocui": Rect2(864.0, 925.0, 89.0, 120.0),
}

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "initial-unlock workstation loads with its scene-owned art")
	if packed == null:
		_finish()
		return
	var workstation := packed.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	_check_five_zone_layout(workstation)
	_check_material_grid(workstation)
	_check_opening_day_controls(workstation)
	_check_no_egg_waffle_data(workstation)
	workstation.queue_free()
	await process_frame
	_finish()


func _check_five_zone_layout(workstation: Node) -> void:
	var background := workstation.get_node_or_null("SafeArea/BackgroundArtwork") as TextureRect
	_check(background != null and background.texture != null and background.texture.get_size() == Vector2(1920.0, 1080.0), "the 1920x1080 single-row background is the active workstation map")
	var retired_stations := workstation.get_node_or_null("SafeArea/FiveZoneStations") as CanvasItem
	var retired_material_dock := workstation.get_node_or_null("SafeArea/MaterialDock") as CanvasItem
	_check(retired_stations != null and not retired_stations.visible and retired_material_dock != null and not retired_material_dock.visible, "legacy panel and text overlays are not drawn over the map")
	var station_art := workstation.get_node_or_null("SafeArea/PhysicalStationArtwork") as Control
	var station_hits := workstation.get_node_or_null("SafeArea/PhysicalStationInteractions") as Control
	_check(station_art != null and station_hits != null, "five-bay map uses scene-owned artwork and separate hit areas")
	for art_name in [&"SoyMilkMachine", &"SoyMilkLock", &"YoutiaoFryer", &"YoutiaoLock", &"FinishedDrinkLock", &"SteamerLock"]:
		var art := workstation.get_node_or_null("SafeArea/PhysicalStationArtwork/%s" % art_name) as TextureRect
		_check(art != null and art.texture != null, "%s is a real workstation artwork layer" % art_name)
	for button_name in [&"SoyMilkLockedButton", &"YoutiaoLockedButton", &"FinishedDrinkLockedButton", &"SteamerLockedButton"]:
		var button := workstation.get_node_or_null("SafeArea/PhysicalStationInteractions/%s" % button_name) as Button
		_check(button != null and not button.disabled and button.get_meta(&"locked_art_path", NodePath()) != NodePath(), "%s remains click-targetable while locked" % button_name)
	var soy_lock_button := workstation.get_node_or_null("SafeArea/PhysicalStationInteractions/SoyMilkLockedButton") as Button
	var soy_lock_art := workstation.get_node_or_null("SafeArea/PhysicalStationArtwork/SoyMilkLock") as Control
	if soy_lock_button != null:
		soy_lock_button.emit_signal("pressed")
	_check(soy_lock_art != null and soy_lock_art.scale.x < 1.0, "clicking a locked station produces physical lock-art feedback without a UI overlay")
	var pan_base := workstation.get_node_or_null("SafeArea/PanBase") as Control
	var pancake_surface := workstation.get_node_or_null("SafeArea/PanBase/PancakeSurface") as Control
	var griddle := workstation.get_node_or_null("SafeArea/PanBase/GriddleArtwork") as Sprite2D
	_check(pan_base != null and pancake_surface != null and Rect2(pan_base.position, pan_base.size).intersects(CENTRAL_PAN_BAY) and _rect_matches(pan_base, Rect2(750.0, 562.0, 420.0, 382.0)) and _rect_matches(pancake_surface, Rect2(40.0, 40.0, 340.0, 340.0)) and griddle != null and griddle.texture != null and griddle.texture.resource_path.ends_with("griddle_base_angled_ellipse_v3.png") and griddle.scale == Vector2(0.41, 0.41), "the pancake ellipse matches the griddle's black inner cooking face")
	var customer := workstation.get_node_or_null("SafeArea/CustomerPortrait") as Control
	var order_card := workstation.get_node_or_null("SafeArea/OrderCard") as Control
	_check(_rect_matches(customer, Rect2(800.0, 222.0, 270.0, 406.0)), "customer remains close while ending above the countertop edge")
	_check(_rect_matches(order_card, Rect2(1082.0, 250.0, 270.0, 270.0)), "order card is positioned beside the customer")
	for icon_name in [&"EggOrderIcon", &"ScallionOrderIcon", &"BaocuiOrderIcon"]:
		var icon := workstation.get_node_or_null("SafeArea/OrderCard/%s" % icon_name) as TextureRect
		_check(icon != null and icon.texture != null, "%s uses a real ingredient artwork thumbnail" % icon_name)


func _check_material_grid(workstation: Node) -> void:
	var artwork := workstation.get_node_or_null("SafeArea/LockedIngredientArtwork") as Control
	var hit_areas := workstation.get_node_or_null("SafeArea/LockedIngredientInteractions") as Control
	_check(artwork != null and hit_areas != null, "ingredient row has dedicated artwork and click layers")
	if artwork == null or hit_areas == null:
		return
	_check(artwork.get_child_count() == 15 and hit_areas.get_child_count() == 15, "18 physical ingredient wells resolve to 6 left locks, 3 starters, and 9 right locks")
	for locked_index in [1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15, 16, 17, 18]:
		var art := artwork.get_node_or_null("Slot%02d" % locked_index) as TextureRect
		var hit := hit_areas.get_node_or_null("Slot%02dLockedButton" % locked_index) as Button
		_check(art != null and art.texture != null and hit != null and not hit.disabled, "locked ingredient slot %02d has art and a click target" % locked_index)


func _check_opening_day_controls(workstation: Node) -> void:
	var rack := workstation.get_node_or_null("SafeArea/IngredientRack") as Control
	_check(_rect_matches(rack, Rect2(648.0, 925.0, 305.0, 120.0)), "the three starter controls occupy the center of the 18-well row")
	var controls := {
		&"egg": workstation.get_node_or_null("SafeArea/IngredientRack/EggButton") as Control,
		&"scallion": workstation.get_node_or_null("SafeArea/IngredientRack/ScallionButton") as Control,
		&"baocui": workstation.get_node_or_null("SafeArea/IngredientRack/BaocuiButton") as Control,
	}
	var local_slot_positions := {
		&"egg": Rect2(6.0, 0.0, 89.0, 120.0),
		&"scallion": Rect2(111.0, 0.0, 89.0, 120.0),
		&"baocui": Rect2(216.0, 0.0, 89.0, 120.0),
	}
	for ingredient_id in STARTER_SLOT_RECTS:
		var control: Control = controls[ingredient_id]
		_check(control != null and control.visible and _rect_matches(control, local_slot_positions[ingredient_id]), "%s occupies its central opening-day material well" % ingredient_id)
	var unlocked: Array = workstation.get_meta("unlocked_ingredient_ids", [])
	_check(unlocked == [&"egg", &"baocui", &"scallion"], "only egg, baocui, and scallion are ingredient unlocks on day one")
	var chili := workstation.get_node_or_null("SafeArea/RightRack/ChiliSauceRefillButton") as CanvasItem
	_check(chili != null and not chili.visible, "chili sauce remains unavailable on day one")


func _check_no_egg_waffle_data(workstation: Node) -> void:
	_check(not CATALOG.DEVICE_DEFINITIONS.has(&"egg_waffle_machine"), "egg-waffle device has been removed from the expansion catalog")
	_check(workstation.get_node_or_null("SafeArea/ExpansionLayout/DeviceSlots/EggWaffleMachineSlot") == null, "scene has no egg-waffle device slot")


func _rect_matches(control: Control, expected: Rect2) -> bool:
	return control != null and control.position.distance_to(expected.position) <= 0.05 and control.size.distance_to(expected.size) <= 0.05


func _global_rects_match(first: Control, second: Control) -> bool:
	return first != null and second != null \
		and first.get_global_rect().position.distance_to(second.get_global_rect().position) <= 1.0 \
		and first.get_global_rect().size.distance_to(second.get_global_rect().size) <= 1.0


func _global_rect_matches(control: Control, expected: Rect2) -> bool:
	return control != null and control.get_global_rect().position.distance_to(expected.position) <= 0.05 \
		and control.get_global_rect().size.distance_to(expected.size) <= 0.05


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
