extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const LOCKED_STATIONS := {
	&"area.fresh_soy_milk": "FreshSoyMilkStation",
	&"area.youtiao": "YoutiaoStation",
	&"area.packaged_drink": "PackagedDrinkStation",
	&"area.steamer": "SteamerStation",
}
const LOCK_CLICK_LAYERS := {
	&"area.fresh_soy_milk": "FreshSoyMilkLockedClickLayer",
	&"area.youtiao": "YoutiaoLockedClickLayer",
	&"area.packaged_drink": "PackagedDrinkLockedClickLayer",
	&"area.steamer": "SteamerLockedClickLayer",
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for locked-area visual rendering")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	var fixed_slot_names := ["SoyFullYellow", "SoyFullBlack", "SoyFullRed", "YoutiaoDoughPlain"]
	for index in fixed_slot_names.size():
		var slot_number := index + 1
		var source := workstation.get_node("SafeArea/%s" % fixed_slot_names[index]) as TextureButton
		var lock_art := workstation.get_node("SafeArea/LockedIngredientArtwork/Slot%02d" % slot_number) as TextureRect
		var lock_button := workstation.get_node("SafeArea/LockedIngredientInteractions/Slot%02dLockedButton" % slot_number) as Button
		_check(source.texture_normal == null, "locked Slot%02d does not load or reveal its material texture" % slot_number)
		_check(lock_art.visible, "locked Slot%02d shows the shared opaque lock artwork" % slot_number)
		_check(lock_button.visible and lock_button.mouse_filter == Control.MOUSE_FILTER_STOP, "locked Slot%02d blocks material drag and restock input" % slot_number)

	for area_id in LOCKED_STATIONS:
		var station := _station(workstation, LOCKED_STATIONS[area_id])
		var lock_cover := station.get_node("LockCover") as Button
		var lock_click_layer := workstation.get_node("SafeArea/FiveAreaStationClickLayers/%s" % LOCK_CLICK_LAYERS[area_id]) as Button
		_check(lock_cover.visible, "%s starts behind its lock card in a new game" % area_id)
		_check(lock_cover.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s visual lock card delegates input instead of covering adjacent workstation controls" % area_id)
		_check(lock_click_layer.visible and lock_click_layer.mouse_filter == Control.MOUSE_FILTER_STOP, "%s keeps a scoped authored lock interaction layer" % area_id)
		_check(_rect_matches(lock_cover.get_global_rect(), station.get_global_rect()), "%s lock card fully covers the authored station footprint" % area_id)
		for style_name in [&"normal", &"hover", &"pressed"]:
			var style := lock_cover.get_theme_stylebox(style_name) as StyleBoxFlat
			_check(style != null and is_equal_approx(style.bg_color.a, 1.0), "%s %s lock style is fully opaque" % [area_id, style_name])
		for color_name in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
			_check(lock_cover.get_theme_color(color_name).is_equal_approx(Color(0.34, 0.18, 0.06, 1.0)), "%s %s keeps readable dark lock text" % [area_id, color_name])

	var progression: RefCounted = session.call("progression_service")
	var unlocked_areas := Dictionary(progression.get("unlocked_area_ids"))
	unlocked_areas[&"area.packaged_drink"] = true
	unlocked_areas[&"area.fresh_soy_milk"] = true
	unlocked_areas[&"area.youtiao"] = true
	progression.set("unlocked_area_ids", unlocked_areas)
	var unlocked_recipes := Dictionary(progression.get("unlocked_recipe_ids"))
	unlocked_recipes[&"recipe.fresh_soy_milk.yellow_bean"] = true
	unlocked_recipes[&"recipe.youtiao.plain"] = true
	progression.set("unlocked_recipe_ids", unlocked_recipes)
	session.call("_sync_progression_to_save")
	workstation.call("_refresh_material_slots")
	for station_name in LOCKED_STATIONS.values():
		_station(workstation, station_name).call("refresh_from_session")
	await process_frame
	for unlocked_slot_number in [1, 4]:
		var source := workstation.get_node("SafeArea/%s" % fixed_slot_names[unlocked_slot_number - 1]) as TextureButton
		var lock_art := workstation.get_node("SafeArea/LockedIngredientArtwork/Slot%02d" % unlocked_slot_number) as TextureRect
		var lock_button := workstation.get_node("SafeArea/LockedIngredientInteractions/Slot%02dLockedButton" % unlocked_slot_number) as Button
		_check(source.texture_normal != null, "unlocked Slot%02d restores its material texture" % unlocked_slot_number)
		_check(not lock_art.visible and not lock_button.visible, "unlocked Slot%02d removes its lock layers" % unlocked_slot_number)
	for locked_slot_number in [2, 3, 5, 6]:
		var source := workstation.get_node("SafeArea/%s" % fixed_slot_names[locked_slot_number - 1]) as TextureButton
		var lock_art := workstation.get_node("SafeArea/LockedIngredientArtwork/Slot%02d" % locked_slot_number) as TextureRect
		_check(source.texture_normal == null and lock_art.visible, "Slot%02d remains fully locked until its own recipe is available" % locked_slot_number)

	var drink_station := _station(workstation, "PackagedDrinkStation")
	_check(not (drink_station.get_node("LockCover") as Button).visible, "unlocking packaged drinks reveals its authored station content immediately")
	_check(
		(drink_station.get_node("Cabinet") as TextureRect).visible
		and not (drink_station.get_node("HeaterArtwork") as TextureRect).visible
		and (drink_station.get_node("HeaterLockCover") as Button).visible,
		"unlocking the cabinet reveals room-temperature stock while the heater keeps its own opaque lock"
	)
	var device_tiers := Dictionary(progression.get("device_tiers"))
	device_tiers[&"device.packaged_drink_heater"] = 0
	progression.set("device_tiers", device_tiers)
	session.call("_sync_progression_to_save")
	drink_station.call("refresh_from_session")
	_check((drink_station.get_node("HeaterArtwork") as TextureRect).visible and not (drink_station.get_node("HeaterLockCover") as Button).visible, "installing the base heater reveals only the separate heating section")
	var steamer_lock_cover := _station(workstation, LOCKED_STATIONS[&"area.steamer"]).get_node("LockCover") as Button
	_check(steamer_lock_cover.visible, "an unrelated station stays locked while material and drink areas are unlocked")

	workstation.queue_free()
	_finish()


func _station(workstation: Node, station_name: String) -> Control:
	return workstation.get_node("FiveAreaInfrastructure/Stations/%s" % station_name) as Control


func _rect_matches(left: Rect2, right: Rect2) -> bool:
	return left.position.distance_to(right.position) <= 0.05 and left.size.distance_to(right.size) <= 0.05


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_LOCKED_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_LOCKED_VISUAL_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
