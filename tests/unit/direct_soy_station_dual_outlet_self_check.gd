extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/direct_soy_station.tscn")
const MANUAL_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/soy-milk-dispenser.png"
const AUTO_FILL_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/automatic-soy-milk-dispenser-transparent.png"
const DUAL_OUTLET_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/automatic-soy-milk-dispenser-two-outlets-transparent.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available for the soy station")
	if session != null:
		session.call("begin_new_game")
		var progression: RefCounted = session.call("progression_service")
		var production: RefCounted = session.call("production_service")
		var locked_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(locked_station)
		await process_frame
		locked_station.set_workshop_preview(true)
		await process_frame
		var locked_dispenser := locked_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(locked_dispenser != null, "direct soy station includes the dispenser visual")
		_check(locked_dispenser != null and locked_dispenser.texture != null and locked_dispenser.texture.resource_path == MANUAL_TEXTURE_PATH, "locked soy area previews the basic soy machine")
		_check(locked_station.visible and is_equal_approx(locked_station.modulate.a, 0.42), "locked basic soy machine is translucent in the workshop")
		locked_station.queue_free()
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
		production.call("_sync_ownership")
		var workshop_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(workshop_station)
		await process_frame
		workshop_station.set_workshop_preview(true)
		await process_frame
		var workshop_dispenser := workshop_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(workshop_dispenser != null and workshop_dispenser.texture != null and workshop_dispenser.texture.resource_path == AUTO_FILL_TEXTURE_PATH, "after the basic machine unlocks, the workshop previews the intermediate machine")
		_check(workshop_dispenser != null and is_equal_approx(workshop_dispenser.self_modulate.a, 0.42), "unowned intermediate soy machine is translucent in the workshop")
		workshop_station.queue_free()
		progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_fill": true})
		production.call("_sync_ownership")
		var intermediate_workshop_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(intermediate_workshop_station)
		await process_frame
		intermediate_workshop_station.set_workshop_preview(true)
		await process_frame
		var intermediate_workshop_dispenser := intermediate_workshop_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(intermediate_workshop_dispenser != null and intermediate_workshop_dispenser.texture != null and intermediate_workshop_dispenser.texture.resource_path == DUAL_OUTLET_TEXTURE_PATH, "after the intermediate machine unlocks, the workshop previews the advanced machine")
		_check(intermediate_workshop_dispenser != null and is_equal_approx(intermediate_workshop_dispenser.self_modulate.a, 0.42), "unowned advanced soy machine is translucent in the workshop")
		intermediate_workshop_station.queue_free()
		var live_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(live_station)
		await process_frame
		var live_dispenser := live_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(live_station.visible, "unlocked soy machine appears on the main workstation")
		_check(live_dispenser != null and live_dispenser.texture != null and live_dispenser.texture.resource_path == AUTO_FILL_TEXTURE_PATH, "automatic full-cup upgrade uses the single-outlet asset on the main workstation")
		live_station.queue_free()
		progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_fill": true, &"automation.fresh_soy_milk.double_fill": true})
		production.call("_sync_ownership")
		var advanced_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(advanced_station)
		await process_frame
		var advanced_dispenser := advanced_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(advanced_dispenser != null and advanced_dispenser.texture != null and advanced_dispenser.texture.resource_path == DUAL_OUTLET_TEXTURE_PATH, "advanced soy machine uses the dual-outlet asset on the main workstation")
		advanced_station.queue_free()
	if failures.is_empty():
		print("DIRECT_SOY_STATION_DUAL_OUTLET_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DIRECT_SOY_STATION_DUAL_OUTLET_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
