extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
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
	progression.set("unlocked_area_ids", unlocked_areas)
	session.call("_sync_progression_to_save")
	for station_name in LOCKED_STATIONS.values():
		_station(workstation, station_name).call("refresh_from_session")
	await process_frame

	var drink_station := _station(workstation, "PackagedDrinkStation")
	_check(not (drink_station.get_node("LockCover") as Button).visible, "unlocking packaged drinks reveals its authored station content immediately")
	_check((drink_station.get_node("Cabinet") as TextureRect).visible and (drink_station.get_node("HeaterArtwork") as TextureRect).visible, "unlocked packaged-drink tools and equipment become visible")
	for area_id in LOCKED_STATIONS:
		if area_id == &"area.packaged_drink":
			continue
		var lock_cover := _station(workstation, LOCKED_STATIONS[area_id]).get_node("LockCover") as Button
		_check(lock_cover.visible, "%s stays locked when another area is unlocked" % area_id)

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
