extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/direct_soy_station.tscn")
const DUAL_OUTLET_TEXTURE_PATH := "res://assets/jianbing-stall/automatic-soy-milk-dispenser-two-outlets-transparent.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available for the soy station")
	var station := STATION_SCENE.instantiate() as DirectSoyStation
	root.add_child(station)
	await process_frame
	station.set_workshop_preview(true)
	await process_frame
	var dispenser := station.get_node_or_null("SoyMilkDispenser") as TextureRect
	_check(dispenser != null, "direct soy station includes the dispenser visual")
	_check(dispenser != null and dispenser.texture != null and dispenser.texture.resource_path == DUAL_OUTLET_TEXTURE_PATH, "workshop automatic-soy preview uses the dual-outlet dispenser asset")
	_check(station.visible and dispenser != null and dispenser.visible, "locked soy upgrade remains visible as a workshop preview")
	station.queue_free()
	await process_frame
	if session != null:
		session.call("begin_new_game")
		var progression: RefCounted = session.call("progression_service")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
		var production: RefCounted = session.call("production_service")
		production.call("_sync_ownership")
		var workshop_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(workshop_station)
		await process_frame
		workshop_station.set_workshop_preview(true)
		await process_frame
		var workshop_dispenser := workshop_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(workshop_dispenser != null and is_equal_approx(workshop_dispenser.self_modulate.a, 0.42), "unowned automatic soy machine is translucent in the workshop after the manual machine unlocks")
		workshop_station.queue_free()
		progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_fill": true})
		production.call("_sync_ownership")
		var live_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(live_station)
		await process_frame
		var live_dispenser := live_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(live_station.visible, "unlocked soy machine appears on the main workstation")
		_check(live_dispenser != null and live_dispenser.texture != null and live_dispenser.texture.resource_path == DUAL_OUTLET_TEXTURE_PATH, "unlocked automatic soy machine uses the dual-outlet asset on the main workstation")
		live_station.queue_free()
	if failures.is_empty():
		print("DIRECT_SOY_STATION_DUAL_OUTLET_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DIRECT_SOY_STATION_DUAL_OUTLET_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
